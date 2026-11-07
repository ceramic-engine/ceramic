#!/usr/bin/env node
// Compares two sets of benchmark results written by test/bench (BenchRunner).
//
// Usage:
//   node compare.js <baseline-glob-or-dir> <candidate-glob-or-dir> [--median-threshold 3] [--p99-threshold 5]
//
// Each argument is a directory (every *.json inside it) or a glob with `*`
// and `?` (expanded here, so quote it in the shell). Files are grouped by
// (target, scenario, mode); the median over the files of a group is taken
// for every metric. The script prints one table per group and exits with 1
// when, in any group present on both sides, the median frame time regresses
// by more than the median threshold (percent), the p99 by more than the p99
// threshold, or the bytes per frame or the total minor GC pause time by more
// than the median threshold.

'use strict';

const fs = require('fs');
const path = require('path');

function usage(message) {
    if (message) console.error(message);
    console.error('usage: node compare.js <baseline-glob-or-dir> <candidate-glob-or-dir> [--median-threshold 3] [--p99-threshold 5]');
    process.exit(2);
}

function parseArgs(argv) {
    const positional = [];
    const options = { medianThreshold: 3, p99Threshold: 5 };
    for (let i = 0; i < argv.length; i++) {
        const arg = argv[i];
        if (arg === '--median-threshold') {
            options.medianThreshold = parseFloat(argv[++i]);
        } else if (arg === '--p99-threshold') {
            options.p99Threshold = parseFloat(argv[++i]);
        } else if (arg.startsWith('--median-threshold=')) {
            options.medianThreshold = parseFloat(arg.split('=')[1]);
        } else if (arg.startsWith('--p99-threshold=')) {
            options.p99Threshold = parseFloat(arg.split('=')[1]);
        } else if (arg === '-h' || arg === '--help') {
            usage();
        } else {
            positional.push(arg);
        }
    }
    if (positional.length !== 2) usage('expected a baseline and a candidate');
    if (!(options.medianThreshold >= 0) || !(options.p99Threshold >= 0)) usage('thresholds must be numbers');
    return { baseline: positional[0], candidate: positional[1], options };
}

function globToRegExp(pattern) {
    let source = '^';
    for (const ch of pattern) {
        if (ch === '*') source += '[^/]*';
        else if (ch === '?') source += '[^/]';
        else source += ch.replace(/[.+^${}()|[\]\\]/g, '\\$&');
    }
    return new RegExp(source + '$');
}

// Expands a directory or a glob (wildcards in the last path component, or a
// `**` component matching any depth) into a sorted list of JSON files.
function expand(spec) {
    if (fs.existsSync(spec) && fs.statSync(spec).isDirectory()) {
        return fs.readdirSync(spec).filter(f => f.endsWith('.json')).sort().map(f => path.join(spec, f));
    }
    if (!/[*?]/.test(spec)) {
        return fs.existsSync(spec) ? [spec] : [];
    }
    const parts = spec.split(path.sep === '\\' ? /[\\/]/ : '/');
    let roots = [parts[0] === '' ? '/' : (/[*?]/.test(parts[0]) ? '.' : null)];
    let start = 0;
    if (roots[0] === '/') start = 1;
    else if (roots[0] === null) { roots = [parts[0]]; start = 1; }
    for (let i = start; i < parts.length; i++) {
        const part = parts[i];
        const next = [];
        for (const root of roots) {
            if (part === '**') {
                const walk = dir => {
                    next.push(dir);
                    for (const entry of safeReaddir(dir)) {
                        const full = path.join(dir, entry);
                        if (safeStat(full)?.isDirectory()) walk(full);
                    }
                };
                walk(root);
            } else if (/[*?]/.test(part)) {
                const re = globToRegExp(part);
                for (const entry of safeReaddir(root)) {
                    if (re.test(entry)) next.push(path.join(root, entry));
                }
            } else {
                const full = path.join(root, part);
                if (fs.existsSync(full)) next.push(full);
            }
        }
        roots = next;
    }
    return roots.filter(f => safeStat(f)?.isFile()).sort();
}

function safeReaddir(dir) {
    try { return fs.readdirSync(dir); } catch (e) { return []; }
}

function safeStat(file) {
    try { return fs.statSync(file); } catch (e) { return null; }
}

function flatten(value, prefix, out) {
    for (const key of Object.keys(value)) {
        const name = prefix ? prefix + '.' + key : key;
        const v = value[key];
        if (v !== null && typeof v === 'object' && !Array.isArray(v)) flatten(v, name, out);
        else if (typeof v === 'number') out[name] = v;
        else if (typeof v === 'boolean') out[name] = v ? 1 : 0;
    }
    return out;
}

function load(files) {
    const groups = new Map();
    for (const file of files) {
        let data;
        try {
            data = JSON.parse(fs.readFileSync(file, 'utf8'));
        } catch (e) {
            console.error(`skipping ${file}: ${e.message}`);
            continue;
        }
        if (!data || !data.metrics || !data.scenario) {
            console.error(`skipping ${file}: not a bench result`);
            continue;
        }
        const key = `${data.target}/${data.scenario}/${data.mode}`;
        if (!groups.has(key)) groups.set(key, { key, files: [], metrics: [] });
        const group = groups.get(key);
        group.files.push(file);
        group.metrics.push(flatten(data.metrics, '', {}));
    }
    return groups;
}

function median(values) {
    const sorted = values.slice().sort((a, b) => a - b);
    const n = sorted.length;
    if (n === 0) return NaN;
    return n % 2 === 1 ? sorted[(n - 1) / 2] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2;
}

function medians(group) {
    const names = new Set();
    for (const m of group.metrics) for (const k of Object.keys(m)) names.add(k);
    const out = {};
    for (const name of names) {
        out[name] = median(group.metrics.filter(m => name in m).map(m => m[name]));
    }
    return out;
}

function fmt(value) {
    if (value === undefined || Number.isNaN(value)) return '';
    if (Math.abs(value) >= 1000) return value.toFixed(0);
    if (Math.abs(value) >= 10) return value.toFixed(2);
    return value.toFixed(3);
}

function fmtDelta(base, cand) {
    if (base === undefined || cand === undefined || Number.isNaN(base) || Number.isNaN(cand)) return '';
    if (base === 0) return cand === 0 ? '0.0%' : 'n/a';
    const pct = (cand - base) / Math.abs(base) * 100;
    return (pct > 0 ? '+' : '') + pct.toFixed(1) + '%';
}

function pad(text, width, right) {
    text = String(text);
    if (text.length >= width) return text;
    return right ? ' '.repeat(width - text.length) + text : text + ' '.repeat(width - text.length);
}

// Metrics checked against the thresholds: name, threshold option, label.
const CHECKS = [
    { metric: 'medianMs', threshold: 'medianThreshold', label: 'median frame time' },
    { metric: 'p99Ms', threshold: 'p99Threshold', label: 'p99 frame time' },
    { metric: 'bytesPerFrame', threshold: 'medianThreshold', label: 'bytes per frame' },
    { metric: 'gc.totalMinorPauseMs', threshold: 'medianThreshold', label: 'total minor GC pause' },
];

// Preferred order of the rows; the remaining metrics follow alphabetically.
const ORDER = ['meanMs', 'medianMs', 'p50Ms', 'p95Ms', 'p99Ms', 'maxMs',
    'renderedViewsPerFrame', 'reusedViewsPerFrame', 'objectsPerFrame', 'anyElementsPerFrame', 'bytesPerFrame',
    'phasesMsPerFrame.update', 'phasesMsPerFrame.layout', 'phasesMsPerFrame.prepaint', 'phasesMsPerFrame.paint',
    'phasesMsPerFrame.finish', 'phasesMsPerFrame.render',
    'gc.minorPauses', 'gc.totalMinorPauseMs', 'gc.maxMinorPauseMs', 'gc.lastMinorPauseMs',
    'draws', 'objectsCreated', 'bytesTotal', 'ok'];

function main() {
    const { baseline, candidate, options } = parseArgs(process.argv.slice(2));
    const baseFiles = expand(baseline);
    const candFiles = expand(candidate);
    if (baseFiles.length === 0) usage(`no baseline files match ${baseline}`);
    if (candFiles.length === 0) usage(`no candidate files match ${candidate}`);
    const baseGroups = load(baseFiles);
    const candGroups = load(candFiles);
    const keys = Array.from(new Set([...baseGroups.keys(), ...candGroups.keys()])).sort();
    const failures = [];
    let compared = 0;

    for (const key of keys) {
        const base = baseGroups.get(key);
        const cand = candGroups.get(key);
        console.log('');
        console.log(`== ${key}  (baseline: ${base ? base.files.length : 0} run(s), candidate: ${cand ? cand.files.length : 0} run(s))`);
        if (!base || !cand) {
            console.log('   only on one side, skipped');
            continue;
        }
        compared++;
        const b = medians(base);
        const c = medians(cand);
        const names = Array.from(new Set([...Object.keys(b), ...Object.keys(c)]));
        names.sort((x, y) => {
            const ix = ORDER.indexOf(x), iy = ORDER.indexOf(y);
            if (ix !== -1 && iy !== -1) return ix - iy;
            if (ix !== -1) return -1;
            if (iy !== -1) return 1;
            return x < y ? -1 : x > y ? 1 : 0;
        });
        const rows = names.map(name => [name, fmt(b[name]), fmt(c[name]), fmtDelta(b[name], c[name])]);
        const widths = [0, 0, 0, 0];
        const header = ['metric', 'baseline', 'candidate', 'delta'];
        for (const row of [header, ...rows]) row.forEach((cell, i) => widths[i] = Math.max(widths[i], String(cell).length));
        const line = row => '   ' + pad(row[0], widths[0]) + '  ' + pad(row[1], widths[1], true) + '  ' + pad(row[2], widths[2], true) + '  ' + pad(row[3], widths[3], true);
        console.log(line(header));
        console.log('   ' + widths.map(w => '-'.repeat(w)).join('  '));
        for (const row of rows) {
            let flag = '';
            const check = CHECKS.find(ch => ch.metric === row[0]);
            if (check && b[row[0]] > 0 && c[row[0]] !== undefined) {
                const pct = (c[row[0]] - b[row[0]]) / b[row[0]] * 100;
                if (pct > options[check.threshold]) {
                    flag = `  REGRESSION (> ${options[check.threshold]}%)`;
                    failures.push(`${key}: ${check.label} ${fmt(b[row[0]])} -> ${fmt(c[row[0]])} (${fmtDelta(b[row[0]], c[row[0]])})`);
                }
            }
            console.log(line(row) + flag);
        }
    }

    console.log('');
    if (compared === 0) {
        console.log('no group present on both sides');
        process.exit(2);
    }
    if (failures.length > 0) {
        console.log(`${failures.length} regression(s):`);
        for (const f of failures) console.log('  ' + f);
        process.exit(1);
    }
    console.log(`no regression (median threshold ${options.medianThreshold}%, p99 threshold ${options.p99Threshold}%)`);
}

main();
