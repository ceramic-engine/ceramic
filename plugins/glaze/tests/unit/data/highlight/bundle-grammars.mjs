#!/usr/bin/env node

// Copies the grammars bundled with the gpui plugin from the tm-grammars
// package (the grammar collection of shiki 3.23) into assets/gpui/grammars,
// with their licenses, and writes the catalog the highlighter reads
// (runtime/src/gpui/component/highlighter/GrammarCatalog.hx).
//
// Usage:
//   node test/unit/data/highlight/bundle-grammars.mjs <tm-grammars package folder>
//
// The package folder is the content of the npm tarball of tm-grammars 1.31.15
// (npm pack tm-grammars@1.31.15, then extract it outside the repository).

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../../../..');
const pkg = process.argv[2];
if (!pkg) {
    console.error('Usage: node bundle-grammars.mjs <tm-grammars package folder>');
    process.exit(1);
}
const { grammars, injections } = await import(pathToFileURL(path.join(pkg, 'index.js')).href);
const version = JSON.parse(fs.readFileSync(path.join(pkg, 'package.json'), 'utf8')).version;

// The languages of gpui-kit's highlighters (tree-sitter languages and the
// fence names its syntect backend tests), the grammars they embed that are
// worth their size, and Haxe. GLSL (embedded by C++) is left out: its
// origin, polym0rph/GLSL.tmbundle, states no license.
const bundled = [
    'astro', 'c', 'cmake', 'coffee', 'cpp', 'cpp-macro', 'csharp', 'css', 'diff', 'docker', 'elixir', 'erb',
    'go', 'graphql', 'haml', 'haxe', 'html', 'html-derivative', 'hxml', 'ini', 'java', 'javascript',
    'json', 'jsonc', 'jsx', 'kotlin', 'less', 'lua', 'make', 'markdown', 'php', 'postcss', 'proto', 'pug',
    'python', 'regexp', 'ruby', 'rust', 'sass', 'scala', 'scss', 'shellscript', 'sql', 'stylus', 'svelte',
    'swift', 'toml', 'tsx', 'typescript', 'xml', 'yaml', 'zig'
];

// File extensions and other names a code fence or an editor may use, matched
// case insensitively like syntect's `find_syntax_by_token` matches extensions.
const extraTokens = {
    'c': ['h'],
    'cpp': ['cc', 'cxx', 'hpp', 'hh', 'hxx', 'h++'],
    'csharp': ['csx'],
    'css': [],
    'diff': ['patch'],
    'docker': ['containerfile'],
    'elixir': ['ex', 'exs'],
    'erb': ['rhtml'],
    'go': ['golang'],
    'haxe': ['hx'],
    'html': ['htm', 'xhtml'],
    'javascript': ['es6'],
    'jsonc': ['json5'],
    'kotlin': ['ktm'],
    'make': ['mk', 'mak', 'gnumakefile'],
    'markdown': ['markdown', 'mdown', 'mkd', 'mdx'],
    'python': ['pyi', 'pyw', 'python3', 'py3'],
    'ruby': ['rake', 'gemspec'],
    'shellscript': ['bash', 'sh', 'zsh', 'ksh', 'shell'],
    'xml': ['xsd', 'svg', 'plist'],
    'yaml': ['yml']
};

const all = [...grammars, ...injections];
const byName = new Map(all.map(g => [g.name, g]));
const outDir = path.join(root, 'assets/gpui/grammars');
fs.mkdirSync(outDir, { recursive: true });

const entries = [];
for (const name of bundled) {
    const info = byName.get(name);
    if (!info) throw new Error('Unknown grammar ' + name);
    const file = name + '.json';
    fs.copyFileSync(path.join(pkg, 'grammars', file), path.join(outDir, file));
    const tokens = [name, ...(info.aliases || []), ...(extraTokens[name] || [])];
    entries.push({
        name,
        displayName: info.displayName || name,
        scopeName: info.scopeName,
        file,
        tokens: [...new Set(tokens.map(t => t.toLowerCase()))],
        embedded: (info.embedded || []).filter(e => bundled.includes(e)),
        injectTo: info.injectTo || [],
        source: info.source,
        license: info.license || ''
    });
}

// Licenses: tm-grammars' own MIT license, and the sections of its NOTICE
// that cover the bundled files.
fs.copyFileSync(path.join(pkg, 'LICENSE'), path.join(outDir, 'LICENSE-tm-grammars'));
const notice = fs.readFileSync(path.join(pkg, 'NOTICE'), 'utf8');
const separator = '=========================================================================================================';
const parts = notice.split(separator);
const kept = [parts[0].trimEnd()];
const covered = new Set();
for (const part of parts.slice(1)) {
    const filesLine = part.split('\n').find(line => line.startsWith('Files:'));
    if (!filesLine) continue;
    const files = filesLine.slice('Files:'.length).split(',').map(f => f.trim());
    const mine = files.filter(f => bundled.includes(f.replace(/\.json$/, '')));
    if (mine.length === 0) continue;
    for (const f of mine) covered.add(f);
    kept.push(separator + part.trimEnd());
}
fs.writeFileSync(path.join(outDir, 'NOTICE-tm-grammars'), kept.join('\n\n') + '\n');
const uncovered = entries.filter(e => !covered.has(e.file)).map(e => e.file);
if (uncovered.length > 0) console.log('Files without a NOTICE section: ' + uncovered.join(', '));

const rows = entries.map(e => `| ${e.file} | ${e.scopeName} | ${e.source} | ${e.license || 'see NOTICE-tm-grammars'} |`);
fs.writeFileSync(path.join(outDir, 'NOTICE.md'), `# Grammars

TextMate grammars used by the code highlighter (\`gpui.component.highlighter\`).
They are the files of tm-grammars ${version} (https://github.com/shikijs/textmate-grammars-themes),
the grammar collection of shiki 3.23, unchanged. tm-grammars itself is MIT licensed
(LICENSE-tm-grammars). Each grammar keeps the license of its origin: the sections of the
NOTICE file of tm-grammars that cover these files are reproduced in NOTICE-tm-grammars.

erb.json, toml.json and yaml.json come from TextMate bundles (textmate/ruby.tmbundle,
textmate/toml.tmbundle, textmate/yaml.tmbundle), not covered by that NOTICE. The README of
each bundle states this license for its files:

\`\`\`
Permission to copy, use, modify, sell and distribute this
software is granted. This software is provided "as is" without
express or implied warranty, and with no claim as to its
suitability for any purpose.
\`\`\`

Regenerate with \`node test/unit/data/highlight/bundle-grammars.mjs <tm-grammars package folder>\`.

| File | Scope | Origin | License |
|------|-------|--------|---------|
${rows.join('\n')}
`);

// The catalog.
const hx = (s) => "'" + s.replace(/\\/g, '\\\\').replace(/'/g, "\\'") + "'";
const arr = (a) => '[' + a.map(hx).join(', ') + ']';
const lines = entries.map(e => `        new GrammarInfo(${hx(e.name)}, ${hx(e.displayName)}, ${hx(e.scopeName)}, ${hx(e.file)}, ${arr(e.tokens)}, ${arr(e.embedded)}, ${arr(e.injectTo)})`);
fs.writeFileSync(path.join(root, 'runtime/src/gpui/component/highlighter/GrammarCatalog.hx'), `// Original code (not a port), written for ceramic-gpui.
// Generated by test/unit/data/highlight/bundle-grammars.mjs from tm-grammars ${version}. Do not edit.
package gpui.component.highlighter;

/**
 * The TextMate grammars bundled in \`assets/gpui/grammars\` (see NOTICE.md there).
 */
class GrammarCatalog {

    /** The tm-grammars version the files come from. */
    public static final VERSION:String = ${hx(version)};

    /** The folder of the grammar files, in the assets. */
    public static final FOLDER:String = 'gpui/grammars';

    public static final ENTRIES:Array<GrammarInfo> = [
${lines.join(',\n')}
    ];

}
`);
console.log('Bundled ' + entries.length + ' grammars');
