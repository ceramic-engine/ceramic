#!/usr/bin/env node
//
// Runs the web build of the bench (project/web, built with
// `ceramic clay build web --setup --assets --allow-multiple [--variant perf]`)
// under Ceramic's Electron runner with a hidden window, and adds what the page
// cannot measure itself:
//
// - V8 collections per measured block: the runner is started with
//   `--js-flags=--trace-gc`, BenchRunner marks each block on the renderer's
//   stdout (`GPUI_BENCH_MARK`), and the trace lines between the marks are
//   summed (count, pause, minor and major, allocation volume: the growth of
//   `performance.memory.usedJSHeapSize` over the block plus what the
//   collections freed);
// - with `--profile`: a CPU profile of each block (`console.profile` in
//   BenchRunner, recorded through the DevTools protocol), saved as
//   `<label>.cpuprofile` (Chrome DevTools, speedscope) with the top self
//   times printed;
// - with `--alloc`: V8's sampling heap profiler until the end of the first
//   measured block (run one scenario and mode), from the start of the page
//   (setup and warmup included) or, with GPUI_BENCH_SCREEN=1, from the start
//   of the block; saved as `alloc.heapprofile` with the functions that
//   allocate the most printed.
//
// Usage:
//   GPUI_BENCH_SCENARIOS=cards,scroll-table GPUI_BENCH_FRAMES=200 \
//   GPUI_BENCH_RESULTS=/some/dir node web-run.js [--profile] [--top 40]
//
// Soak runs (GPUI_BENCH_SOAK_SECONDS) write their series as `-soak.json`;
// V8 runs with --expose-gc for their live memory samples.
// Every GPUI_BENCH_* variable of BenchRunner applies (the page reads them from
// process.env). Results: one JSON per block like the other targets, with a
// `webGc` object, in GPUI_BENCH_RESULTS (printed only when it is not set).
// CERAMIC_PATH: the Ceramic checkout (default: ../../../ceramic).
// GPUI_BENCH_WEB_DIR: another copy of project/web (A/B runs on frozen builds).

const fs = require('fs');
const path = require('path');
const http = require('http');
const { spawn } = require('child_process');

const args = process.argv.slice(2);
const profile = args.includes('--profile');
const alloc = args.includes('--alloc');
const topIndex = args.indexOf('--top');
const top = topIndex >= 0 ? parseInt(args[topIndex + 1], 10) : 40;
const port = 9300 + Math.floor(Math.random() * 500);

const ceramicPath = process.env.CERAMIC_PATH || path.resolve(__dirname, '../../../ceramic');
const runnerPath = path.join(ceramicPath, 'runner');
const electron = process.platform === 'darwin'
    ? path.join(runnerPath, 'node_modules/electron/dist/Electron.app/Contents/MacOS/Electron')
    : path.join(runnerPath, 'node_modules/electron/dist/electron');
const appFiles = process.env.GPUI_BENCH_WEB_DIR || path.join(__dirname, 'project/web');
const resultsDir = process.env.GPUI_BENCH_RESULTS || null;

const env = Object.assign({}, process.env);
delete env.ELECTRON_RUN_AS_NODE;
if (profile || alloc) env.GPUI_BENCH_PROFILE = '1';

const electronArgs = ['.', '--scripts-prepend-node-path', '--app-files', appFiles, '--hidden',
    '--js-flags=--trace-gc --expose-gc', '--enable-precise-memory-info'];
if (profile || alloc) electronArgs.push('--remote-debugging-port=' + port);
if (process.platform === 'linux') electronArgs.push('--no-sandbox');

const child = spawn(electron, electronArgs, { cwd: runnerPath, env });

// Collections per renderer process, in stdout order
const gcLine = /^\[(\d+):0x[0-9a-f]+\]\s+([\d.]+) ms: (.+?) ([\d.]+) \(([\d.]+)\) -> ([\d.]+) \(([\d.]+)\) MB, (?:pooled: [\d.]+ MB, )?([\d.]+) \/ ([\d.]+) ms/;
const blocks = {}; // label -> { pid, heapBegin, heapEnd, events: [] }
const open = {}; // pid -> label
const lastAfter = {}; // pid -> heap after the last collection (MB)
const jsons = [];

function onLine(line) {
    const gc = gcLine.exec(line);
    if (gc) {
        const pid = gc[1];
        const event = { kind: gc[3], before: parseFloat(gc[4]), after: parseFloat(gc[6]), pause: parseFloat(gc[8]) };
        const label = open[pid];
        if (label != null) {
            event.prevAfter = lastAfter[pid];
            blocks[label].events.push(event);
        }
        lastAfter[pid] = event.after;
        return;
    }
    const mark = /GPUI_BENCH_MARK (begin|end) (\S+) (\d+) ([\d.]+)/.exec(line);
    if (mark) {
        const [, kind, label, pid, heap] = mark;
        if (kind === 'begin') {
            blocks[label] = { pid, heapBegin: parseFloat(heap), heapEnd: 0, events: [] };
            open[pid] = label;
            if (startAlloc != null) { startAlloc(); startAlloc = null; }
        }
        else {
            if (blocks[label]) blocks[label].heapEnd = parseFloat(heap);
            delete open[pid];
            if (stopAlloc != null) { stopAlloc(); stopAlloc = null; }
        }
        return;
    }
    const json = line.indexOf('BENCH_JSON ');
    if (json >= 0) {
        jsons.push(JSON.parse(line.substring(json + 'BENCH_JSON '.length)));
    }
    if (!/^\[\d+:0x/.test(line) && line.trim() !== '' && !/Security Warning|electronjs\.org|^\s{2}|unsafe-eval|packaged\.|^For more/.test(line)) {
        process.stdout.write(line + '\n');
    }
}

function splitter(stream) {
    let rest = '';
    stream.on('data', data => {
        rest += data.toString();
        let index;
        while ((index = rest.indexOf('\n')) >= 0) {
            onLine(rest.substring(0, index));
            rest = rest.substring(index + 1);
        }
    });
    stream.on('end', () => { if (rest !== '') onLine(rest); });
}
splitter(child.stdout);
splitter(child.stderr);

const MB = 1024 * 1024;

function gcSummary(block, frames) {
    // Allocated = heap growth over the block + what the collections freed
    // (performance.memory and the trace differ by a constant, their
    // differences agree)
    let minor = 0, major = 0, minorMs = 0, majorMs = 0, maxMs = 0, freedMb = 0;
    for (const e of block.events) {
        const isMinor = /Scavenge|Minor/.test(e.kind);
        if (isMinor) { minor++; minorMs += e.pause; } else { major++; majorMs += e.pause; }
        maxMs = Math.max(maxMs, e.pause);
        freedMb += e.before - e.after;
    }
    const volumeMb = Math.max(0, (block.heapEnd - block.heapBegin) / MB + freedMb);
    return {
        minorCount: minor, majorCount: major,
        minorPauseMs: minorMs, majorPauseMs: majorMs, maxPauseMs: maxMs,
        pauseMsPerFrame: (minorMs + majorMs) / frames,
        allocatedBytesPerFrame: volumeMb * MB / frames,
        heapBeginBytes: block.heapBegin, heapEndBytes: block.heapEnd
    };
}

// DevTools protocol: enable the profiler, then let the page start
const profiles = [];
let stopAlloc = null;
let startAlloc = null;
// On screen the page returns to its event loop between frames: the sampling
// can start with the measured block instead of with the page
const allocFromBlock = process.env.GPUI_BENCH_SCREEN === '1';
let heapProfile = null;
function getJson(url) {
    return new Promise((resolve, reject) => {
        http.get(url, res => {
            let body = '';
            res.on('data', d => body += d);
            res.on('end', () => { try { resolve(JSON.parse(body)); } catch (e) { reject(e); } });
        }).on('error', reject);
    });
}
async function attachProfiler() {
    let target = null;
    for (let i = 0; i < 200 && target == null; i++) {
        try {
            const list = await getJson(`http://127.0.0.1:${port}/json/list`);
            target = list.find(t => t.type === 'page' && t.webSocketDebuggerUrl);
        }
        catch (e) {}
        if (target == null) await new Promise(r => setTimeout(r, 100));
    }
    if (target == null) { console.error('web-run: no page to profile'); return; }
    const ws = new WebSocket(target.webSocketDebuggerUrl);
    let id = 0;
    let allocStopId = -1;
    const send = (method, params) => ws.send(JSON.stringify({ id: ++id, method, params: params || {} }));
    ws.onmessage = msg => {
        const data = JSON.parse(msg.data);
        if (data.id === allocStopId) {
            if (data.result) heapProfile = data.result.profile;
            else console.error('web-run: stopSampling: ' + JSON.stringify(data.error));
            send('Runtime.evaluate', { expression: 'window.gpuiBenchMayQuit = true' });
        }
        if (data.method === 'Profiler.consoleProfileFinished') {
            profiles.push({ title: data.params.title, profile: data.params.profile });
        }
    };
    ws.onopen = () => {
        if (profile) {
            send('Profiler.enable');
            send('Profiler.setSamplingInterval', { interval: 100 });
        }
        if (alloc) {
            send('HeapProfiler.enable');
            const start = () => {
                send('HeapProfiler.startSampling', { samplingInterval: 16384, includeObjectsCollectedByMajorGC: true, includeObjectsCollectedByMinorGC: true });
                stopAlloc = () => { send('HeapProfiler.stopSampling'); allocStopId = id; };
            };
            if (allocFromBlock) startAlloc = start;
            else start();
        }
        // Without allocation sampling the profiles come with the page's
        // console.profileEnd: the page may quit right after the last one
        if (!alloc) send('Runtime.evaluate', { expression: 'window.gpuiBenchMayQuit = true' });
        // The page may still be loading: set the flags until they stick
        const ready = setInterval(() => send('Runtime.evaluate', { expression: 'window.gpuiBenchProfilerReady = true' + (alloc ? '' : '; window.gpuiBenchMayQuit = true') }), 200);
        child.on('exit', () => clearInterval(ready));
    };
}
if (profile || alloc) attachProfiler();

function selfTimes(profile) {
    const byId = new Map();
    for (const node of profile.nodes) byId.set(node.id, node);
    const counts = new Map();
    const dt = new Map();
    for (let i = 0; i < profile.samples.length; i++) {
        const id = profile.samples[i];
        dt.set(id, (dt.get(id) || 0) + (profile.timeDeltas[i + 1] || 0));
    }
    let total = 0;
    for (const [id, us] of dt) {
        const node = byId.get(id);
        const cf = node.callFrame;
        const key = `${cf.functionName || '(anonymous)'} ${path.basename(cf.url || '')}:${cf.lineNumber + 1}`;
        counts.set(key, (counts.get(key) || 0) + us);
        total += us;
    }
    return { total, list: [...counts.entries()].sort((a, b) => b[1] - a[1]) };
}

child.on('exit', code => {
    const byLabel = {};
    for (const json of jsons) {
        if (json.soak != null) {
            // Endurance run (GPUI_BENCH_SOAK_SECONDS): written as is
            const s = json.soak.summary;
            console.log(`${json.scenario}-${json.mode} soak: live ${s.live.mbPerMinute.toFixed(3)} MB/min (mean ${s.live.meanMb.toFixed(1)} MB), V8 used ${s.jsUsed.mbPerMinute.toFixed(3)} MB/min, leak suspected: ${s.leakSuspected}`);
            if (resultsDir) {
                fs.mkdirSync(resultsDir, { recursive: true });
                fs.writeFileSync(path.join(resultsDir, `${json.timestamp}-web-${json.scenario}-${json.mode}-soak.json`), JSON.stringify(json, null, 2) + '\n');
            }
            continue;
        }
        if (json.metrics == null) continue;
        const label = `${json.scenario}-${json.mode}-r${json.run + 1}`;
        byLabel[label] = json;
        const block = blocks[label];
        if (block) json.webGc = gcSummary(block, json.frames);
    }
    for (const label of Object.keys(byLabel)) {
        const json = byLabel[label];
        const gc = json.webGc;
        if (gc) {
            const m = json.metrics;
            const timing = m.medianMs != null
                ? `mean ${m.meanMs.toFixed(2)} ms, median ${m.medianMs.toFixed(2)} ms, p99 ${m.p99Ms.toFixed(2)} ms`
                : `idle: wall ${m.wallMsPerFrame.toFixed(2)} ms per frame, ceramic draw ${m.drawMedianMs.toFixed(2)} ms median`;
            console.log(`${label}: ${timing}; V8 GC: ${gc.minorCount} minor (${gc.minorPauseMs.toFixed(1)} ms), ${gc.majorCount} major (${gc.majorPauseMs.toFixed(1)} ms), max ${gc.maxPauseMs.toFixed(1)} ms, ${gc.pauseMsPerFrame.toFixed(3)} ms and ${(gc.allocatedBytesPerFrame / 1024).toFixed(0)} KiB allocated per frame`);
        }
        if (resultsDir) {
            fs.mkdirSync(resultsDir, { recursive: true });
            const suffix = json.runs > 1 ? `-r${json.run + 1}` : '';
            fs.writeFileSync(path.join(resultsDir, `${json.timestamp}-web-${json.scenario}-${json.mode}${suffix}.json`), JSON.stringify(json, null, 2) + '\n');
        }
    }
    for (const p of profiles) {
        if (resultsDir) {
            fs.mkdirSync(resultsDir, { recursive: true });
            fs.writeFileSync(path.join(resultsDir, `${p.title}.cpuprofile`), JSON.stringify(p.profile));
        }
        const { total, list } = selfTimes(p.profile);
        const idle = list.filter(([key]) => key.startsWith('(idle)')).reduce((sum, [, us]) => sum + us, 0);
        console.log(`\nprofile ${p.title}: ${(total / 1000).toFixed(0)} ms sampled, ${((total - idle) / 1000).toFixed(0)} ms busy, top self times:`);
        for (const [key, us] of list.slice(0, top)) {
            console.log(`  ${(100 * us / total).toFixed(1).padStart(5)} %  ${(us / 1000).toFixed(1).padStart(8)} ms  ${key}`);
        }
    }
    if (heapProfile != null) {
        if (resultsDir) {
            fs.mkdirSync(resultsDir, { recursive: true });
            fs.writeFileSync(path.join(resultsDir, 'alloc.heapprofile'), JSON.stringify(heapProfile));
        }
        const bySelf = new Map();
        let total = 0;
        const walk = node => {
            const cf = node.callFrame;
            const key = `${cf.functionName || '(anonymous)'} ${path.basename(cf.url || '')}:${cf.lineNumber + 1}`;
            bySelf.set(key, (bySelf.get(key) || 0) + node.selfSize);
            total += node.selfSize;
            for (const c of node.children) walk(c);
        };
        walk(heapProfile.head);
        console.log(`\nallocation sampling: ${(total / 1048576).toFixed(0)} MB sampled, top allocating functions:`);
        for (const [key, bytes] of [...bySelf.entries()].sort((a, b) => b[1] - a[1]).slice(0, top)) {
            console.log(`  ${(100 * bytes / total).toFixed(1).padStart(5)} %  ${(bytes / 1048576).toFixed(1).padStart(8)} MB  ${key}`);
        }
    }
    process.exit(code || 0);
});
