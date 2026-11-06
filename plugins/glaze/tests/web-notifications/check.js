#!/usr/bin/env node
//
// Browser check of deliberate deviation DEV-021 in headless Chromium
// (Playwright, no window): the web build of this project (project/web) is
// served on 127.0.0.1 and driven by mouse clicks (trusted events, so the
// page gets user activation like with a real click).
//
// The page's Notification API is replaced by a recorder before the app
// starts: nothing reaches the system and nobody is asked. The recorder keeps
// its own permission ("default" at start), records each requestPermission
// call with navigator.userActivation.isActive at that moment, and answers
// what the check sets in window.__answer (the user's choice).
//
// - a post from a timer (no gesture) while the permission is not determined
//   asks nobody and shows nothing;
// - a click posts: the browser is asked during the gesture; the user closes
//   the prompt without a choice ("default"): nothing shows;
// - a second click asks again; the user allows: both posts of that click
//   show (title, body, tag);
// - the same tag replaces (a new notification with the tag, no action
//   buttons on a page), dismiss closes, a later post from a timer shows at
//   once without asking;
// - a click on a notification is the response with a null action id, the
//   page is focused and the notification closes.
//
// Usage: node check.js   (PLAYWRIGHT_DIR: a folder with node_modules/playwright)
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
const lines = [];
function check(ok, message) {
    console.log((ok ? 'ok   ' : 'FAIL ') + message);
    if (!ok) failures++;
}

// The page's Notification API, recorded (installed before the app starts)
const recorder = () => {
    let permission = 'default';
    window.__answer = 'default';
    window.__requests = [];
    window.__posted = [];
    window.__closed = [];
    window.__focus = 0;
    const realFocus = window.focus.bind(window);
    window.focus = () => { window.__focus++; realFocus(); };
    function Recorded(title, options) {
        if (permission !== 'granted') throw new TypeError('permission not granted');
        options = options || {};
        const notification = { title, body: options.body, tag: options.tag, actions: options.actions, onclick: null, onclose: null, onerror: null, onshow: null };
        notification.close = () => {
            window.__closed.push(options.tag);
            if (notification.onclose) notification.onclose({});
        };
        window.__posted.push(notification);
        return notification;
    }
    Object.defineProperty(Recorded, 'permission', { get: () => permission });
    Recorded.requestPermission = (callback) => {
        window.__requests.push({ active: !!(navigator.userActivation && navigator.userActivation.isActive) });
        return new Promise(resolve => setTimeout(() => {
            permission = window.__answer;
            if (typeof callback === 'function') callback(permission);
            resolve(permission);
        }, 200));
    };
    window.Notification = Recorded;
};

(async () => {
    await new Promise(r => server.listen(0, '127.0.0.1', r));
    const url = `http://127.0.0.1:${server.address().port}/index.html`;
    const { chromium } = requirePlaywright();
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({ viewport: { width: 640, height: 480 } });
    const page = await context.newPage();
    await page.addInitScript(recorder);
    const waiters = [];
    page.on('console', msg => {
        const text = msg.text();
        const at = text.indexOf('WEBNOTIF ');
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
    const state = () => page.evaluate(() => ({
        requests: window.__requests.slice(),
        posted: window.__posted.map(n => `${n.tag}:${n.title}:${n.body}`).join(','),
        closed: window.__closed.join(','),
        actions: window.__posted.map(n => n.actions === undefined ? '-' : JSON.stringify(n.actions)).join(','),
        focus: window.__focus,
    }));
    // A few frames, for anything the app would do later
    const frames = () => page.waitForTimeout(500);

    await page.goto(url);
    await waitLine(/^ready$/);

    // 1. Outside of a gesture, permission not determined: nobody asked, nothing shown
    await waitLine(/^posted timer$/);
    await frames();
    let s = await state();
    check(s.requests.length === 0, `post from a timer: the browser is not asked (${s.requests.length} request(s))`);
    check(s.posted === '', `post from a timer: nothing shown (${s.posted})`);

    // 2. A click asks during the gesture; the prompt is closed without a choice
    await page.mouse.click(160, 120);
    await waitLine(/^posted a2$/);
    await frames();
    s = await state();
    check(s.requests.length === 1 && s.requests[0].active, `a click asks, within the gesture (${JSON.stringify(s.requests)})`);
    check(s.posted === '', `prompt closed without a choice: nothing shown (${s.posted})`);

    // 3. The next click asks again; the user allows: both posts of the click show
    await page.evaluate(() => { window.__answer = 'granted'; });
    lines.length = 0;
    await page.mouse.click(160, 120);
    await waitLine(/^posted a2$/);
    await frames();
    s = await state();
    check(s.requests.length === 2 && s.requests[1].active, `the next click asks again, within the gesture (${JSON.stringify(s.requests)})`);
    check(s.posted === 'a1:Build finished:All tests passed,a2:Second:', `allowed: the posts made while the answer was pending show (${s.posted})`);

    // 4. Same tag: a new notification with the tag (the browser replaces it), no action buttons
    lines.length = 0;
    await page.mouse.click(480, 120);
    await waitLine(/^posted a1$/);
    await frames();
    s = await state();
    check(s.posted === 'a1:Build finished:All tests passed,a2:Second:,a1:Replaced:Same tag', `same tag posted again (${s.posted})`);
    check(s.actions === '-,-,-', `no action buttons on a page (${s.actions})`);
    check(s.requests.length === 2, `decided: no more questions (${s.requests.length} request(s))`);

    // 5. Dismiss closes
    lines.length = 0;
    await page.mouse.click(320, 360);
    await waitLine(/^dismissed a2$/);
    await frames();
    s = await state();
    check(s.closed === 'a2', `dismiss closes (${s.closed})`);

    // 6. A later post outside of a gesture shows at once
    lines.length = 0;
    await page.evaluate(() => window.__postLate());
    await waitLine(/^posted late$/);
    await frames();
    s = await state();
    check(/,late:Later:No gesture$/.test(s.posted) && s.requests.length === 2, `permission granted: a post from a timer shows without asking (${s.posted})`);

    // 7. A click on the notification: the response, null action id, focus, closed
    lines.length = 0;
    const focusBefore = s.focus;
    await page.evaluate(() => window.__posted[2].onclick({}));
    const response = await waitLine(/^response /);
    await frames();
    s = await state();
    check(response === 'response a1 null', `a click on the notification is the response with a null action id: "${response}"`);
    check(s.focus > focusBefore, `the page is focused (${s.focus - focusBefore})`);
    check(s.closed === 'a2,a1', `the clicked notification closes (${s.closed})`);
    // The replaced notification no longer answers
    const stale = await page.evaluate(() => window.__posted[0].onclick == null);
    check(stale, 'the replaced notification has no click handler left');

    await browser.close();
    server.close();
    console.log(failures === 0 ? 'All web notification checks passed.' : `${failures} web notification check(s) failed.`);
    process.exit(failures === 0 ? 0 : 1);
})().catch(error => {
    console.error(error);
    console.log('WEBNOTIF lines: ' + JSON.stringify(lines));
    process.exit(1);
});
