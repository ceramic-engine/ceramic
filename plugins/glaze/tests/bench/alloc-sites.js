#!/usr/bin/env node
// Static allocation sites of one generated function (hxcpp): every object
// still allocated after Haxe's inline constructor elimination, with the Haxe
// line it comes from (`X_obj::__alloc`, array literals, closures, Dynamic
// boxes). Pairs with the allocprof profile, which names functions only.
//
// usage: node alloc-sites.js <cpp-dir> <Class.method> [more...]
//   e.g. node alloc-sites.js out/clay/mac/cpp taffy.compute.BlockLayout.computeInnerWith
'use strict';
const fs = require('fs');
const path = require('path');
const [cppDir, ...names] = process.argv.slice(2);
if (!cppDir || names.length === 0) {
    console.error('usage: node alloc-sites.js <cpp-dir> <pkg.Class.method>...');
    process.exit(1);
}
for (const full of names) {
    const parts = full.split('.');
    const method = parts.pop();
    const cls = parts.pop();
    const file = path.join(cppDir, 'src', ...parts, cls + '.cpp');
    if (!fs.existsSync(file)) { console.log(full + ': no ' + file); continue; }
    const lines = fs.readFileSync(file, 'utf8').split('\n');
    // The definition: at column 0 (or one space before a `::` type), not a call
    const def = new RegExp('^(?:\\S| ::).*\\b' + cls + '_obj::' + method + '\\(');
    const start = lines.findIndex(l => def.test(l) && !l.startsWith('HX'));
    if (start < 0) { console.log(full + ': function not found'); continue; }
    console.log('## ' + full);
    let hxline = '?';
    for (let i = start + 1; i < lines.length; i++) {
        const l = lines[i];
        if (/^(?:\S| ::).*_obj::\w+\(/.test(l) && !l.startsWith('HX') && !l.startsWith('}')) break;
        const m = /^HX(?:LINE|DLIN)\(\s*(\d+)\)/.exec(l);
        if (m) hxline = m[1];
        const allocs = [];
        let a;
        const re = /::([\w:]+)_obj::__alloc\(|::Array_obj< [^>]+ >::(?:__new|fromData)\(|new _hx_Closure_\d+|::Dynamic\(\s*\(Float\)|::hx::Anon_obj::Create/g;
        while ((a = re.exec(l))) allocs.push(a[1] ? a[1].split('::').pop() : a[0].replace(/\($/, ''));
        if (allocs.length) console.log('  line ' + hxline + ': ' + allocs.join(', '));
    }
}
