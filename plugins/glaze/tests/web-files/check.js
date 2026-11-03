#!/usr/bin/env node
//
// Browser check of deliberate deviation DEV-019 in headless Chromium
// (Playwright, no window): the web build of this project (project/web) is
// served on 127.0.0.1 and driven by mouse clicks (trusted events, so the
// page gets user activation like with a real click):
//
// - a prompt asked from a timer (no gesture) fails and opens no chooser;
// - a click on the save zone gives a download path and its write starts a
//   download (the `download` event: name and content);
// - a click on the files zone opens the file chooser (`filechooser` event,
//   multiple), `setInputFiles` gives it two files and the app reads them;
// - a click on the folder zone opens a folder chooser, `setInputFiles` gives
//   it a folder and the app reads the files under the picked folder.
//
// Usage: node check.js   (PLAYWRIGHT_DIR: a folder with node_modules/playwright)
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');

function requirePlaywright() {
    const dirs = [process.env.PLAYWRIGHT_DIR, __dirname].filter(Boolean);
    for (const dir of dirs) {
        try { return require(path.join(dir, 'node_modules', 'playwright')); } catch (e) {}
    }
    return require('playwright');
}

const root = path.join(__dirname, 'project', 'web');
if (!fs.existsSync(path.join(root, 'index.html'))) {
    console.error('no web build: run `ceramic clay build web --setup --assets --allow-multiple` first');
    process.exit(1);
}

const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png' };
const server = http.createServer((req, res) => {
    const file = path.join(root, decodeURIComponent(req.url.split('?')[0]).replace(/^\/+/, '') || 'index.html');
    if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
        res.writeHead(404); res.end(); return;
    }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    fs.createReadStream(file).pipe(res);
});

let failures = 0;
const lines = [];
function check(ok, message) {
    console.log((ok ? 'ok   ' : 'FAIL ') + message);
    if (!ok) failures++;
}

(async () => {
    await new Promise(r => server.listen(0, '127.0.0.1', r));
    const url = `http://127.0.0.1:${server.address().port}/index.html`;
    const { chromium } = requirePlaywright();
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({ viewport: { width: 640, height: 480 }, acceptDownloads: true });
    const page = await context.newPage();
    const waiters = [];
    page.on('console', msg => {
        const text = msg.text();
        const at = text.indexOf('WEBFILES ');
        if (at < 0) return;
        const line = text.slice(at + 9).trim();
        lines.push(line);
        for (const w of waiters.slice()) if (w.test(line)) { waiters.splice(waiters.indexOf(w), 1); w.resolve(line); }
    });
    function waitLine(re, ms = 20000) {
        const found = lines.find(l => re.test(l));
        if (found) return Promise.resolve(found);
        return new Promise((resolve, reject) => {
            const w = { test: l => re.test(l), resolve };
            waiters.push(w);
            setTimeout(() => reject(new Error('timeout waiting for ' + re)), ms);
        });
    }
    let choosers = 0;
    page.on('filechooser', () => { choosers++; });

    await page.goto(url);
    await waitLine(/^ready$/);

    // 1. A prompt outside of a gesture fails without opening a chooser
    const outside = await waitLine(/^outside /);
    check(/^outside error .*user gesture/.test(outside), `prompt outside of a gesture fails: "${outside}"`);
    check(choosers === 0, 'no file chooser opened outside of a gesture');

    // 2. Save: a download path, written as a download
    const [download] = await Promise.all([
        page.waitForEvent('download', { timeout: 20000 }),
        page.mouse.click(160, 120),
    ]);
    const saved = await waitLine(/^save path /);
    check(saved === 'save path download:export.csv', `save prompt answers a download path: "${saved}"`);
    check(download.suggestedFilename() === 'export.csv', `download named export.csv: "${download.suggestedFilename()}"`);
    const content = fs.readFileSync(await download.path(), 'utf8');
    check(content === 'Name,Price\nA,1\n', `download content: ${JSON.stringify(content)}`);

    // 3. Open files: the chooser, two files, read by the app
    const [chooser] = await Promise.all([
        page.waitForEvent('filechooser', { timeout: 20000 }),
        page.mouse.click(480, 120),
    ]);
    check(chooser.isMultiple(), 'files chooser allows several files');
    await chooser.setFiles([
        { name: 'b.txt', mimeType: 'text/plain', buffer: Buffer.from('second') },
        { name: 'a.txt', mimeType: 'text/plain', buffer: Buffer.from('first') },
    ]);
    const a = await waitLine(/^files file .*a\.txt /);
    const b = await waitLine(/^files file .*b\.txt /);
    check(/^files file picked:\d+\/a\.txt first$/.test(a), `picked a.txt read: "${a}"`);
    check(/^files file picked:\d+\/b\.txt second$/.test(b), `picked b.txt read: "${b}"`);

    // 4. Open a folder
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'webfiles-'));
    const folder = path.join(tmp, 'data');
    fs.mkdirSync(path.join(folder, 'sub'), { recursive: true });
    fs.writeFileSync(path.join(folder, 'one.txt'), 'uno');
    fs.writeFileSync(path.join(folder, 'sub', 'two.txt'), 'dos');
    const [folderChooser] = await Promise.all([
        page.waitForEvent('filechooser', { timeout: 20000 }),
        page.mouse.click(320, 360),
    ]);
    const isDirectory = await folderChooser.element().evaluate(el => el.hasAttribute('webkitdirectory'));
    check(isDirectory, 'folder chooser has webkitdirectory');
    await folderChooser.setFiles(folder);
    const one = await waitLine(/^folder dir .* one\.txt /);
    const two = await waitLine(/^folder dir .* sub\/two\.txt /);
    check(/^folder dir picked:\d+\/data one\.txt uno$/.test(one), `picked folder file read: "${one}"`);
    check(/^folder dir picked:\d+\/data sub\/two\.txt dos$/.test(two), `picked folder nested file read: "${two}"`);
    if (path.basename(tmp).startsWith('webfiles-') && tmp.startsWith(os.tmpdir())) fs.rmSync(tmp, { recursive: true });

    await browser.close();
    server.close();
    console.log(failures === 0 ? 'All web file checks passed.' : `${failures} web file check(s) failed.`);
    process.exit(failures === 0 ? 0 : 1);
})().catch(error => {
    console.error(error);
    console.log('WEBFILES lines: ' + JSON.stringify(lines));
    process.exit(1);
});
