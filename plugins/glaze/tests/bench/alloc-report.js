#!/usr/bin/env node
// Summary of the allocation profiles written by the `allocprof` variant of
// the bench (`<scenario>-<mode>-rN-allocs.txt`, see src/AllocProfile.hx).
//
// Usage:
//   node alloc-report.js <dir> [--top N] [--sites] [--type T] [--match RE]
//   node alloc-report.js <before-dir> <after-dir>        per scenario delta
//
//   <dir>        folder holding the -allocs.txt files of one run
//   --top N      lines of the cross scenario rankings (default 40)
//   --sites      rank the sites (type @ function < caller < caller) instead
//                of the allocating functions
//   --type T     only the sites of this allocated type (with --sites)
//   --match RE   only the functions or sites matching this regular expression
//
// The ranking sums the objects (and bytes) per frame of every scenario and
// mode, and shows the scenarios where the line weighs the most.

'use strict';

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const dirs = [];
let top = 40;
let sites = false;
let onlyType = null;
let match = null;
for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--top') top = parseInt(args[++i], 10);
    else if (a === '--sites') sites = true;
    else if (a === '--type') onlyType = args[++i];
    else if (a === '--match') match = new RegExp(args[++i]);
    else dirs.push(a);
}
if (dirs.length === 0) {
    console.error('usage: node alloc-report.js <dir> [<after-dir>] [--top N] [--sites] [--type T] [--match RE]');
    process.exit(1);
}

function parse(file) {
    const text = fs.readFileSync(file, 'utf8');
    const out = { objects: 0, bytes: 0, byType: new Map(), byFunction: new Map(), bySite: new Map() };
    const head = /allocations per frame: ([\d.]+) objects, ([\d.]+) bytes/.exec(text);
    if (head) {
        out.objects = parseFloat(head[1]);
        out.bytes = parseFloat(head[2]);
    }
    let table = null;
    for (const line of text.split('\n')) {
        if (line.startsWith('## by type')) table = out.byType;
        else if (line.startsWith('## by allocating function')) table = out.byFunction;
        else if (line.startsWith('## by site')) table = out.bySite;
        else if (table != null) {
            const m = /^\s*([\d.]+)\s+([\d.]+)\s+(.*)$/.exec(line);
            if (m) table.set(m[3], { count: parseFloat(m[1]), bytes: parseFloat(m[2]) });
        }
    }
    return out;
}

function load(dir) {
    const result = new Map();
    for (const name of fs.readdirSync(dir).sort()) {
        const m = /^(.*)-r\d+-allocs\.txt$/.exec(name);
        if (!m) continue;
        result.set(m[1], parse(path.join(dir, name)));
    }
    return result;
}

const pad = (s, n) => { s = String(s); return s.length >= n ? s : s + ' '.repeat(n - s.length); };
const lpad = (s, n) => { s = String(s); return s.length >= n ? s : ' '.repeat(n - s.length) + s; };
const num = x => x >= 100 ? x.toFixed(0) : x.toFixed(1);
const kb = x => (x / 1024).toFixed(1);

if (dirs.length >= 2) {
    const a = load(dirs[0]);
    const b = load(dirs[1]);
    console.log(pad('scenario', 32) + lpad('objects before', 16) + lpad('after', 12) + lpad('delta', 9) + lpad('KiB before', 13) + lpad('after', 11) + lpad('delta', 9));
    for (const name of [...new Set([...a.keys(), ...b.keys()])].sort()) {
        const x = a.get(name), y = b.get(name);
        if (!x || !y) continue;
        const pct = (p, q) => p > 0 ? ((q - p) / p * 100).toFixed(1) + ' %' : '';
        console.log(pad(name, 32) + lpad(num(x.objects), 16) + lpad(num(y.objects), 12) + lpad(pct(x.objects, y.objects), 9)
            + lpad(kb(x.bytes), 13) + lpad(kb(y.bytes), 11) + lpad(pct(x.bytes, y.bytes), 9));
    }
    process.exit(0);
}

const profiles = load(dirs[0]);
console.log(pad('scenario', 32) + lpad('objects/frame', 15) + lpad('KiB/frame', 12));
for (const [name, p] of profiles) {
    console.log(pad(name, 32) + lpad(num(p.objects), 15) + lpad(kb(p.bytes), 12));
}
console.log('');

const ranking = new Map();
for (const [scenario, p] of profiles) {
    const table = sites ? p.bySite : p.byFunction;
    for (const [key, v] of table) {
        if (onlyType != null && !key.startsWith(onlyType + ' @ ')) continue;
        if (match != null && !match.test(key)) continue;
        let r = ranking.get(key);
        if (r == null) ranking.set(key, r = { count: 0, bytes: 0, scenarios: [] });
        r.count += v.count;
        r.bytes += v.bytes;
        r.scenarios.push([scenario, v.count]);
    }
}
const list = [...ranking.entries()].sort((x, y) => y[1].count - x[1].count);
console.log('Ranking of the ' + (sites ? 'sites' : 'allocating functions') + ' (objects per frame summed over the scenarios, KiB per frame summed; heaviest scenarios)');
for (const [key, r] of list.slice(0, top)) {
    const worst = r.scenarios.sort((x, y) => y[1] - x[1]).slice(0, 3).map(([s, c]) => s + ' ' + num(c)).join(', ');
    console.log(lpad(num(r.count), 10) + lpad(kb(r.bytes), 10) + '  ' + key + '  [' + worst + ']');
}
