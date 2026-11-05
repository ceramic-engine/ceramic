#!/usr/bin/env node
//
// Browser check of the notifications plugin in headless Chromium (Playwright,
// no window, nothing shown): the web build of this project (project/web) is
// served on 127.0.0.1. The page's Notification constructor is replaced by a
// recorder (nothing reaches the system) that also plays a click.
//
// - a request outside of a user gesture (at start): answered at once
//   without asking the browser (AUTHORIZED when granted, NOT_DETERMINED
//   otherwise, Notification.requestPermission not called);
// - notifications granted: a click asks (user gesture) and gets AUTHORIZED,
//   two notifications are posted (title, body, tag), the second one is closed
//   by dismiss, a click on the first one is the response with no action id;
// - not granted: the answer is not AUTHORIZED and nothing is posted.
//
// Usage: node check-web.js   (PLAYWRIGHT_DIR: a folder with node_modules/playwright)
'use strict';

const fs = require('fs');
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
function check(ok, message) {
    console.log((ok ? 'ok   ' : 'FAIL ') + message);
    if (!ok) failures++;
}

// Records the notifications the page creates and closes. Nothing reaches the
// system: the constructor is replaced by a recorder (the permission and its
// request stay the browser's own)
const recorder = () => {
    const Real = window.Notification;
    if (!Real) return;
    window.__posted = [];
    window.__closed = [];
    window.__requests = 0;
    function Recorded(title, options) {
        if (Real.permission !== 'granted') throw new TypeError('permission not granted');
        const notification = { onclick: null, onclose: null, onerror: null, onshow: null };
        notification.close = () => {
            window.__closed.push(options && options.tag);
            if (notification.onclose) notification.onclose({});
        };
        window.__posted.push({ title, body: options && options.body, tag: options && options.tag, notification });
        return notification;
    }
    Object.defineProperty(Recorded, 'permission', { get: () => Real.permission });
    Recorded.requestPermission = (...args) => {
        window.__requests++;
        return Real.requestPermission(...args);
    };
    window.Notification = Recorded;
};

async function run(browser, url, granted) {
    const context = await browser.newContext({ viewport: { width: 320, height: 240 } });
    if (granted) await context.grantPermissions(['notifications'], { origin: new URL(url).origin });
    const page = await context.newPage();
    await page.addInitScript(recorder);
    const lines = [];
    const waiters = [];
    page.on('console', msg => {
        const text = msg.text();
        const at = text.indexOf('NOTIFICATIONS ');
        if (at < 0) return;
        const line = text.slice(at + 14).trim();
        lines.push(line);
        for (const w of waiters.slice()) if (w.test(line)) { waiters.splice(waiters.indexOf(w), 1); w.resolve(line); }
    });
    function waitLine(re, ms = 20000) {
        const found = lines.find(l => re.test(l));
        if (found) return Promise.resolve(found);
        return new Promise((resolve, reject) => {
            waiters.push({ test: l => re.test(l), resolve });
            setTimeout(() => reject(new Error('timeout waiting for ' + re + ' (got: ' + lines.join(' | ') + ')')), ms);
        });
    }

    await page.goto(url);
    const ready = await waitLine(/^ready /);
    const label = granted ? 'granted' : 'not granted';
    check(ready === (granted ? 'ready available=true read=AUTHORIZED' : 'ready available=true read=NOT_DETERMINED'), `${label}: ${ready}`);
    const outside = await waitLine(/^outside /);
    check(outside === (granted ? 'outside AUTHORIZED' : 'outside NOT_DETERMINED'), `${label}: request outside of a gesture: ${outside}`);
    check(await page.evaluate(() => window.__requests) === 0, `${label}: the browser was not asked outside of a gesture`);

    await page.mouse.click(160, 120);
    const answer = await waitLine(/^authorization /);
    await waitLine(/^posted$/);
    const posted = await page.evaluate(() => window.__posted.map(p => `${p.tag}:${p.title}:${p.body}`).join(','));
    const closed = await page.evaluate(() => window.__closed.join(','));
    if (granted) {
        check(answer === 'authorization AUTHORIZED', `${label}: ${answer}`);
        check(posted === 't1:Title:Body,t2:Two:', `${label}: posted ${posted}`);
        check(closed === 't2', `${label}: dismissed ${closed}`);
        // A click on the notification (no buttons on a plain page)
        await page.evaluate(() => window.__posted[0].notification.onclick({}));
        const response = await waitLine(/^response /);
        check(response === 'response t1 null', `${label}: ${response}`);
        check(await page.evaluate(() => window.__closed.join(',')) === 't2,t1', `${label}: a clicked notification closes`);
    }
    else {
        check(answer !== 'authorization AUTHORIZED', `${label}: ${answer}`);
        check(await page.evaluate(() => window.__requests) === 1, `${label}: the browser was asked during the click`);
        check(posted === '', `${label}: nothing posted (${posted})`);
    }
    await context.close();
}

(async () => {
    await new Promise(r => server.listen(0, '127.0.0.1', r));
    const url = `http://127.0.0.1:${server.address().port}/index.html`;
    const { chromium } = requirePlaywright();
    // The new headless mode of the full Chromium (still no window): the
    // headless shell denies every notification permission
    const browser = await chromium.launch({ headless: true, channel: 'chromium' });
    try {
        await run(browser, url, true);
        await run(browser, url, false);
    }
    catch (e) {
        check(false, String(e && e.message || e));
    }
    await browser.close();
    server.close();
    console.log(failures === 0 ? 'notifications web: OK' : `notifications web: ${failures} failed`);
    process.exit(failures === 0 ? 0 : 1);
})();
