#!/usr/bin/env node
// Static boxing report of the generated C++ (step 5 of docs/perf/PLAN.md).
//
// Scans the C++ that hxcpp generated for the GPUI port and its libraries (by
// default test/bench/out/clay/mac/cpp after a native bench build) and counts,
// per Haxe module and per function, the constructs that box values or
// allocate behind the code's back:
//
//   dynLocal   `::Dynamic` locals and parameters (Null<Float>, Null<Int>,
//              Null<Bool>, function values, anonymous structures)
//   dynCall    calls through a `::Dynamic` value (a function value): the
//              arguments are boxed to Dynamic (Floats always allocate)
//   field      dynamic field reads and writes (`__Field` / `__SetField`, on
//              anonymous structures and Dynamic)
//   anon       anonymous structures created (`Anon_obj::Create`)
//   closure    local functions (`HX_BEGIN_LOCAL_FUNC`), one allocation each
//              time the enclosing code runs
//   member     bound methods taken as values (`obj->method_dyn()`, hxcpp's
//              CreateMemberFunction): one allocation each
//   dynCtor    other explicit `::Dynamic(...)` constructions
//   iter       iterator objects created by `for` loops and calls: `iterator()`,
//              `keys()`, `keyValueIterator()` (on hxcpp a Map's `keys()` and
//              `iterator()` also copy the keys or values into a new array)
//   dynIter    `hasNext()` / `next()` called through `Dynamic` (a field lookup
//              by name per call, and `next()` boxes the value it returns):
//              loops over an `Iterator<T>` / `Iterable<T>`, a Map, an
//              anonymous structure or `Dynamic`
//   primPop    `pop()` / `shift()` on an `Array<Int>`, `Array<Float>` or
//              `Array<Bool>`: hxcpp returns `Null<T>` as `Dynamic`, so the
//              value is boxed (Floats and Ints outside -1...255 allocate)
//              even when it is not used
//
// and, per module, the `::Dynamic` fields of its classes (from the generated
// headers: Null<Float>, Null<Int>, Null<Bool>, function values, anonymous
// structures). Arrays are left out: hxcpp types every array of objects as
// `Array< ::Dynamic>`, which says nothing about boxing.
//
// Usage:
//   node boxing-report.js [cpp-dir] [--all] [--functions N] [--json out.json]
//                         [--compare base.json]
//
//   cpp-dir        hxcpp output folder holding src/ and include/
//                  (default: out/clay/mac/cpp next to this script)
//   --all          report every module of gpui, taffy and ttf, not only the
//                  hot ones
//   --functions N  functions listed per module (default 12, 0 for none)
//   --json F       also write the counts as JSON (for --compare later)
//   --compare F    print the per module difference with a previous JSON

'use strict';

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
let cppDir = path.join(__dirname, 'out/clay/mac/cpp');
let all = false;
let maxFunctions = 12;
let jsonOut = null;
let compareWith = null;
for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--all') all = true;
    else if (a === '--functions') maxFunctions = parseInt(args[++i], 10);
    else if (a === '--json') jsonOut = args[++i];
    else if (a === '--compare') compareWith = args[++i];
    else if (a === '-h' || a === '--help') {
        console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(1, 36).map(l => l.replace(/^\/\/ ?/, '')).join('\n'));
        process.exit(0);
    }
    else cppDir = a;
}

const srcRoot = path.join(cppDir, 'src');
const includeRoot = path.join(cppDir, 'include');
if (!fs.existsSync(srcRoot)) {
    console.error('No generated C++ in ' + srcRoot + ' (build the bench natively first: ceramic clay build mac --setup --assets --allow-multiple)');
    process.exit(1);
}

// Packages scanned, and the hot modules (Haxe source paths) reported by default
const PACKAGES = ['gpui', 'taffy', 'ttf', 'tracker', 'similar', 'plutovg', 'lunasvg', 'textmate',
    'oniguruma', 'ropey', 'markdown', 'html5ever', 'unicode_segmentation', 'unicode_linebreak', 'clay', 'ceramic'];
const HOT = [
    /^gpui\/Window\.hx$/,
    /^gpui\/Div\.hx$/,
    /^gpui\/Interactivity\.hx$/,
    /^gpui\/Style\.hx$/,
    /^gpui\/TaffyLayoutEngine\.hx$/,
    /^gpui\/TextLayout\.hx$/,
    /^gpui\/LineLayoutCache\.hx$/,
    /^gpui\/scene\/Scene\.hx$/,
    /^gpui\/scene\/BoundsTree\.hx$/,
    /^gpui\/platform\/SceneRenderable\.hx$/,
    /^gpui\/ViewElement\.hx$/,
    /^gpui\/SpringMath\.hx$/,
    /^taffy\/compute\//,
    /^taffy\/util\//,
    /^taffy\/tree\//,
];
const isHot = (mod) => HOT.some(r => r.test(mod));

const CATEGORIES = ['dynLocal', 'dynCall', 'field', 'anon', 'closure', 'member', 'dynCtor', 'iter', 'dynIter', 'primPop'];

function walk(dir, out) {
    if (!fs.existsSync(dir)) return out;
    for (const name of fs.readdirSync(dir)) {
        const p = path.join(dir, name);
        const st = fs.statSync(p);
        if (st.isDirectory()) walk(p, out);
        else if (/\.(cpp|h)$/.test(name)) out.push(p);
    }
    return out;
}

// Generated boilerplate (reflection, GC marking, boot): not code of the port
function isBoilerplate(fn) {
    if (fn === '__construct') return false;
    return fn.startsWith('__') || fn.startsWith('_hx_set_') || fn.startsWith('_hx_get') ||
        fn.endsWith('_dyn') || fn === '_hx_getInterfaceIndex' || fn === '_hx_isInstanceOf' ||
        fn === '_hx_getIndex' || fn === '_hx_getTag' || fn === '_hx_getParameters' ||
        fn === '_hx_storageInfo' || fn === '_hx_staticInfo';
}

// Pass 1: the Dynamic fields and the method names of every class (headers)
const dynFieldNames = new Set();
const primArrayFieldNames = new Set();
const methodNames = new Set();
const headerFields = new Map(); // header rel path (no extension) -> {dyn: [...]}
for (const pkg of PACKAGES) {
    for (const file of walk(path.join(includeRoot, pkg), [])) {
        if (!file.endsWith('.h')) continue;
        const rel = path.relative(includeRoot, file).replace(/\.h$/, '');
        const text = fs.readFileSync(file, 'utf8');
        const info = { dyn: [] };
        for (const line of text.split('\n')) {
            let m;
            if ((m = /^\t\t(?:static )? *::Array< (?:int|Float|bool) > ([A-Za-z_][A-Za-z0-9_]*);$/.exec(line))) {
                primArrayFieldNames.add(m[1]);
            }
            if ((m = /^\t\t(?:static )? *::Dynamic ([A-Za-z_][A-Za-z0-9_]*);$/.exec(line))) {
                info.dyn.push(m[1]);
                dynFieldNames.add(m[1]);
            }
            else if ((m = /^\t\t(?:static |virtual )?[^;(]*?[ *&]([A-Za-z_][A-Za-z0-9_]*)\([^;]*\)[^;]*[;{]/.exec(line))) {
                if (!m[1].endsWith('_dyn') && !m[1].startsWith('_hx_set_')) methodNames.add(m[1]);
            }
        }
        headerFields.set(rel, info);
    }
}
for (const name of methodNames) dynFieldNames.delete(name);

function escapeRe(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// Pass 2: function bodies of the sources
const modules = new Map(); // haxe module -> {files, fields, functions: Map(name -> counts)}

function emptyCounts() {
    const c = {};
    for (const k of CATEGORIES) c[k] = 0;
    return c;
}

function moduleFor(text, rel) {
    const m = /HX_(?:DEFINE|LOCAL)_STACK_FRAME\([^,]+,"[^"]*","[^"]*",[^,]+,"[^"]*","([^"]+)"/.exec(text);
    if (m) return m[1];
    return rel.replace(/\.cpp$/, '.hx') + ' (no frames)';
}

// Top level definitions start at column 0, or with one space before a `::` type
const DEF_RE = /^(?!HX|#|static |\t| [^:]|  )([^;=]*?)\b([A-Za-z_][A-Za-z0-9_]*)_obj::([A-Za-z_~][A-Za-z0-9_]*)\(([^;]*)\)\s*\{?\s*$/;

for (const pkg of PACKAGES) {
    for (const file of walk(path.join(srcRoot, pkg), [])) {
        if (!file.endsWith('.cpp')) continue;
        const rel = path.relative(srcRoot, file);
        const text = fs.readFileSync(file, 'utf8');
        const mod = moduleFor(text, rel);
        let entry = modules.get(mod);
        if (entry == null) {
            entry = { module: mod, files: [], dynFields: [], functions: new Map() };
            modules.set(mod, entry);
        }
        entry.files.push(rel);
        const header = headerFields.get(rel.replace(/\.cpp$/, ''));
        const className = path.basename(rel, '.cpp');
        if (header) {
            for (const f of header.dyn) entry.dynFields.push(className + '.' + f);
        }

        // Split into top level definitions
        const lines = text.split('\n');
        let current = null;
        const flush = () => {
            if (current == null) return;
            if (!isBoilerplate(current.fn)) analyse(entry, className, current);
            current = null;
        };
        for (const line of lines) {
            const m = DEF_RE.exec(line);
            if (m) {
                flush();
                current = { fn: m[3], params: m[4], body: [] };
                continue;
            }
            if (current != null) {
                if (/^HX_DEFINE_DYNAMIC_FUNC|^STATIC_HX_DEFINE_DYNAMIC_FUNC/.test(line)) { flush(); continue; }
                current.body.push(line);
            }
        }
        flush();
    }
}

function analyse(entry, className, def) {
    const name = className + '.' + (def.fn === '__construct' ? 'new' : def.fn);
    const counts = emptyCounts();
    const body = def.body.join('\n');

    // Dynamic locals and parameters (closure arguments and captures included)
    const dynNames = new Set();
    const paramRe = /(?:^|[(,])\s*::Dynamic ([A-Za-z_][A-Za-z0-9_]*)/g;
    let m;
    while ((m = paramRe.exec(def.params))) { dynNames.add(m[1]); counts.dynLocal++; }
    const localRe = /(?:^|[\s;{)])\s*::Dynamic ([A-Za-z_][A-Za-z0-9_]*)\s*(?:=|;)/g;
    while ((m = localRe.exec(body))) { dynNames.add(m[1]); counts.dynLocal++; }
    const closureParamRe = /_hx_run\(([^)]*)\)/g;
    while ((m = closureParamRe.exec(body))) {
        const inner = /(?:^|,)\s*::Dynamic ([A-Za-z_][A-Za-z0-9_]*)/g;
        let p;
        while ((p = inner.exec(m[1]))) { dynNames.add(p[1]); counts.dynLocal++; }
    }
    const captureRe = /HX_BEGIN_LOCAL_FUNC_S\d+\(::hx::LocalFunc,_hx_Closure_\d+(,[^)]*)\)/g;
    while ((m = captureRe.exec(body))) {
        const parts = m[1].split(',').map(s => s.trim()).filter(s => s.length > 0);
        for (let i = 0; i + 1 < parts.length; i += 2) {
            if (parts[i] === '::Dynamic') dynNames.add(parts[i + 1]);
        }
    }

    // Calls through Dynamic values: locals and parameters, and Dynamic fields
    for (const n of dynNames) {
        const re = new RegExp('(?<![A-Za-z0-9_>.:])' + escapeRe(n) + '\\(', 'g');
        const found = body.match(re);
        if (found) counts.dynCall += found.length;
    }
    const fieldCallRe = /->([A-Za-z_][A-Za-z0-9_]*)\(/g;
    while ((m = fieldCallRe.exec(body))) {
        if (dynFieldNames.has(m[1])) counts.dynCall++;
    }

    counts.iter = (body.match(/(?:->|IMap_obj::|::)(?:iterator|keys|keyValueIterator)\(/g) || []).length +
        (body.match(/->__Field\(HX_\("(?:iterator|keys|keyValueIterator)",/g) || []).length;
    const primArrays = new Set();
    const primRe = /::Array< (?:int|Float|bool) > ([A-Za-z_][A-Za-z0-9_]*)/g;
    while ((m = primRe.exec(def.params + '\n' + body))) primArrays.add(m[1]);
    const popRe = /(this->|[ (!=\t])([A-Za-z_][A-Za-z0-9_]*)->(?:pop|shift)\(\)/g;
    counts.primPop = 0;
    while ((m = popRe.exec(body))) {
        if (m[1] === 'this->' ? primArrayFieldNames.has(m[2]) : (primArrays.has(m[2]) || primArrayFieldNames.has(m[2]))) counts.primPop++;
    }
    counts.dynIter = (body.match(/->__Field\(HX_\("(?:hasNext|next)",/g) || []).length;
    counts.field = (body.match(/->__(?:Field|SetField)\(HX_/g) || []).length -
        (body.match(/->__Field\(HX_\("(?:iterator|keys|keyValueIterator|hasNext|next)",/g) || []).length +
        (body.match(/::hx::FieldRef\(/g) || []).length;
    counts.anon = (body.match(/Anon_obj::Create\(/g) || []).length;
    counts.closure = (body.match(/HX_BEGIN_LOCAL_FUNC/g) || []).length;
    counts.member = (body.match(/->[A-Za-z_][A-Za-z0-9_]*_dyn\(\)/g) || []).length +
        (body.match(/CreateMemberFunction/g) || []).length;
    const ctors = body.match(/::Dynamic\(\s*[^)]/g) || [];
    const nonCtor = (body.match(/::Dynamic\(\s*(?:new _hx_Closure|::hx::Anon_obj::Create)/g) || []).length;
    counts.dynCtor = ctors.length - nonCtor;

    let fn = entry.functions.get(name);
    if (fn == null) entry.functions.set(name, counts);
    else for (const k of CATEGORIES) fn[k] += counts[k];
}

function total(counts) {
    let t = 0;
    for (const k of CATEGORIES) t += counts[k];
    return t;
}

// Summaries
const summary = [];
for (const entry of modules.values()) {
    const sum = emptyCounts();
    for (const c of entry.functions.values()) for (const k of CATEGORIES) sum[k] += c[k];
    summary.push({
        module: entry.module,
        hot: isHot(entry.module),
        counts: sum,
        dynFields: entry.dynFields,
        functions: [...entry.functions.entries()]
            .map(([name, counts]) => ({ name, counts, total: total(counts) }))
            .filter(f => f.total > 0)
            .sort((a, b) => b.total - a.total || a.name.localeCompare(b.name)),
    });
}
summary.sort((a, b) => a.module.localeCompare(b.module));

function pad(s, n) {
    s = String(s);
    return s.length >= n ? s : s + ' '.repeat(n - s.length);
}
function lpad(s, n) {
    s = String(s);
    return s.length >= n ? s : ' '.repeat(n - s.length) + s;
}

const shown = summary.filter(s => (all || s.hot) && (total(s.counts) > 0 || s.dynFields.length > 0));
const header = pad('module', 44) + CATEGORIES.map(k => lpad(k, 9)).join('') + lpad('fields', 8) + lpad('total', 8);
console.log('Boxing report of ' + path.resolve(cppDir) + (all ? ' (all modules)' : ' (hot modules)'));
console.log('');
console.log(header);
const grand = emptyCounts();
let grandFields = 0;
for (const s of shown) {
    const fields = s.dynFields.length;
    for (const k of CATEGORIES) grand[k] += s.counts[k];
    grandFields += fields;
    console.log(pad(s.module, 44) + CATEGORIES.map(k => lpad(s.counts[k], 9)).join('') + lpad(fields, 8) + lpad(total(s.counts) + fields, 8));
}
console.log(pad('TOTAL', 44) + CATEGORIES.map(k => lpad(grand[k], 9)).join('') + lpad(grandFields, 8) + lpad(total(grand) + grandFields, 8));

if (maxFunctions > 0) {
    for (const s of shown) {
        if (s.functions.length === 0 && s.dynFields.length === 0) continue;
        console.log('');
        console.log('## ' + s.module);
        if (s.dynFields.length > 0) console.log('  Dynamic fields: ' + s.dynFields.join(', '));
        for (const f of s.functions.slice(0, maxFunctions)) {
            const parts = CATEGORIES.filter(k => f.counts[k] > 0).map(k => k + ' ' + f.counts[k]);
            console.log('  ' + pad(f.name, 56) + parts.join(', '));
        }
        if (s.functions.length > maxFunctions) console.log('  ... ' + (s.functions.length - maxFunctions) + ' more functions');
    }
}

const jsonData = {
    cppDir: path.resolve(cppDir),
    date: new Date().toISOString(),
    modules: Object.fromEntries(summary.map(s => [s.module, {
        hot: s.hot,
        counts: s.counts,
        fields: s.dynFields.length,
        functions: Object.fromEntries(s.functions.map(f => [f.name, f.counts])),
    }])),
};

if (jsonOut != null) {
    fs.writeFileSync(jsonOut, JSON.stringify(jsonData, null, 1));
    console.log('');
    console.log('Counts written to ' + jsonOut);
}

if (compareWith != null) {
    const base = JSON.parse(fs.readFileSync(compareWith, 'utf8'));
    console.log('');
    console.log('Difference with ' + compareWith + ' (' + base.date + ')');
    console.log(pad('module', 44) + CATEGORIES.map(k => lpad(k, 9)).join('') + lpad('fields', 8) + lpad('total', 8));
    const names = new Set([...Object.keys(base.modules), ...Object.keys(jsonData.modules)]);
    const sumDelta = emptyCounts();
    let sumFields = 0;
    for (const name of [...names].sort()) {
        const a = base.modules[name];
        const b = jsonData.modules[name];
        const hot = (b || a).hot;
        if (!all && !hot) continue;
        const ca = a ? a.counts : emptyCounts();
        const cb = b ? b.counts : emptyCounts();
        const fa = a ? a.fields : 0;
        const fb = b ? b.fields : 0;
        const d = CATEGORIES.map(k => cb[k] - ca[k]);
        const df = fb - fa;
        if (d.every(x => x === 0) && df === 0) continue;
        CATEGORIES.forEach((k, i) => sumDelta[k] += d[i]);
        sumFields += df;
        const fmt = x => x === 0 ? '.' : (x > 0 ? '+' + x : String(x));
        console.log(pad(name, 44) + d.map(x => lpad(fmt(x), 9)).join('') + lpad(fmt(df), 8) + lpad(fmt(d.reduce((p, q) => p + q, 0) + df), 8));
    }
    const fmt = x => x === 0 ? '.' : (x > 0 ? '+' + x : String(x));
    console.log(pad('TOTAL', 44) + CATEGORIES.map(k => lpad(fmt(sumDelta[k]), 9)).join('') + lpad(fmt(sumFields), 8) + lpad(fmt(total(sumDelta) + sumFields), 8));
}
