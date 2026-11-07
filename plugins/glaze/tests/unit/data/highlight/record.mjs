#!/usr/bin/env node

// Records the expected colors of the TextMate highlighter tests
// (tests.kit.HighlighterTest) with the real vscode-textmate 9.2.0 and
// vscode-oniguruma 2.0.1, in truth.json next to this script.
//
// The tokens (and their scopes) come from vscode-textmate running the
// grammars bundled in assets/gpui/grammars. Each token gets the highlight
// name of gpui-kit's syntect backend rules (`semantic_name` of
// crates/component/src/highlighter/syntect_backend.rs, transliterated below
// from the Rust, independently of the Haxe port), and that name is resolved
// with the default light and dark highlight themes of gpui-kit
// (crates/component/src/theme/default-theme.json, read with the serde names
// of the build without tree-sitter: `comment_doc`, not `comment.doc`).
//
// Usage:
//   VTM_NODE_MODULES=/path/to/node_modules node test/unit/data/highlight/record.mjs
//
// The node_modules folder must hold vscode-textmate@9.2.0 and
// vscode-oniguruma@2.0.1 (npm install them in a scratch folder, never in this
// repository).

import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../../../..');
const grammarsDir = path.join(root, 'assets/gpui/grammars');
const samplesDir = path.join(here, 'samples');

const nodeModules = process.env.VTM_NODE_MODULES;
if (!nodeModules) {
    console.error('Set VTM_NODE_MODULES to a node_modules folder with vscode-textmate and vscode-oniguruma');
    process.exit(1);
}
const require = createRequire(path.join(nodeModules, 'noop.js'));
const vsctm = require('vscode-textmate');
const oniguruma = require('vscode-oniguruma');
const vtmVersion = JSON.parse(fs.readFileSync(path.join(nodeModules, 'vscode-textmate/package.json'), 'utf8')).version;
const onigVersion = JSON.parse(fs.readFileSync(path.join(nodeModules, 'vscode-oniguruma/package.json'), 'utf8')).version;
await oniguruma.loadWASM(fs.readFileSync(path.join(nodeModules, 'vscode-oniguruma/release/onig.wasm')).buffer);

// The cases: a sample, the language token the Haxe test gives the
// highlighter, and the bundled grammar it must resolve to.
const cases = [
    ['demo.toml', 'toml', 'toml'],
    ['demo.py', 'py', 'python'],
    ['demo.json', 'json', 'json'],
    ['demo.css', 'css', 'css'],
    ['demo.c', 'c', 'c'],
    ['demo.cpp', 'c++', 'cpp'],
    ['demo.go', 'go', 'go'],
    ['Demo.java', 'java', 'java'],
    ['demo.rb', 'rb', 'ruby'],
    ['demo.php', 'php', 'php'],
    ['demo.sql', 'sql', 'sql'],
    ['demo.lua', 'lua', 'lua'],
    ['demo.diff', 'diff', 'diff'],
    ['Makefile', 'makefile', 'make'],
    ['Dockerfile', 'dockerfile', 'docker'],
    ['demo.swift', 'swift', 'swift'],
    ['demo.kt', 'kt', 'kotlin'],
    ['Demo.cs', 'cs', 'csharp'],
    ['demo.zig', 'zig', 'zig'],
    ['demo.yaml', 'yml', 'yaml'],
    ['demo.sh', 'sh', 'shellscript'],
    ['demo.tsx', 'tsx', 'tsx'],
    ['demo.js', 'js', 'javascript'],
    ['demo.scss', 'scss', 'scss'],
    ['demo.ex', 'ex', 'elixir'],
    ['demo.scala', 'scala', 'scala'],
    ['demo.svelte', 'svelte', 'svelte'],
    ['demo.graphql', 'graphql', 'graphql'],
    ['demo.proto', 'protobuf', 'proto'],
    ['demo.astro', 'astro', 'astro'],
    ['CMakeLists.txt', 'cmake', 'cmake'],
    ['demo.erb', 'ejs', 'erb'],
    ['Demo.hx', 'haxe', 'haxe'],
    ['rope.rs', 'rust', 'rust'],
    ['grammar.ts', 'ts', 'typescript'],
    ['markdown-README.md', 'md', 'markdown'],
    ['embedded.html', 'html', 'html'],
    ['perltest.sh', 'bash', 'shellscript'],
    ['Rule.hx', 'hx', 'haxe'],
    ['pnpm-lock.yaml', 'yaml', 'yaml'],
];

// Grammars by scope.
const byScope = new Map();
const byName = new Map();
for (const file of fs.readdirSync(grammarsDir)) {
    if (!file.endsWith('.json')) continue;
    const content = fs.readFileSync(path.join(grammarsDir, file), 'utf8');
    const raw = vsctm.parseRawGrammar(content, file);
    byScope.set(raw.scopeName, raw);
    byName.set(file.replace(/\.json$/, ''), raw.scopeName);
}
const registry = new vsctm.Registry({
    onigLib: Promise.resolve({
        createOnigScanner: (patterns) => new oniguruma.OnigScanner(patterns),
        createOnigString: (s) => new oniguruma.OnigString(s)
    }),
    loadGrammar: async (scopeName) => byScope.get(scopeName) || null
});

// gpui-kit's `semantic_name` (syntect_backend.rs).
function semanticName(scope) {
    const is = (prefix) => scope === prefix || (scope.startsWith(prefix) && scope[prefix.length] === '.');
    if (is('punctuation.definition.string') || is('punctuation.definition.comment') || is('invalid') || is('meta') || is('source') || is('text')) return null;
    if (is('comment.block.documentation') || is('comment.line.documentation')) return 'comment.doc';
    if (is('comment')) return 'comment';
    if (is('constant.character.escape')) return 'string.escape';
    if (is('string.regexp')) return 'string.regex';
    if (is('string')) return 'string';
    if (is('constant.numeric')) return 'number';
    if (is('constant.language.boolean')) return 'boolean';
    if (is('constant') || is('support.constant') || is('entity.name.constant')) return 'constant';
    if (is('keyword.operator')) return 'operator';
    if (is('keyword.control.import') || is('meta.preprocessor')) return 'preproc';
    if (is('keyword') || is('storage.modifier')) return 'keyword';
    if (is('storage.type')) {
        const words = ['class', 'enum', 'function', 'impl', 'interface', 'module', 'namespace', 'struct', 'trait', 'type', 'let', 'var', 'const'];
        return words.some((w) => scope.includes(w)) ? 'keyword' : 'type';
    }
    if (is('entity.name.function') || is('support.function') || is('variable.function') || is('meta.function-call')) return 'function';
    if (is('entity.name.type') || is('entity.name.class') || is('entity.name.struct') || is('entity.name.enum') || is('entity.name.trait')
        || is('entity.name.interface') || is('entity.other.inherited-class') || is('support.type') || is('support.class')) return 'type';
    if (is('entity.name.tag')) return 'tag';
    if (is('entity.other.attribute-name')) return 'attribute';
    if (is('entity.name.label')) return 'label';
    if (is('entity.name.section') || is('markup.heading')) return 'title';
    if (is('variable.language')) return 'variable.special';
    if (is('variable.other.member') || is('variable.other.property') || is('support.variable.property') || is('meta.mapping.key')) return 'property';
    if (is('variable')) return 'variable';
    if (is('markup.bold')) return 'emphasis.strong';
    if (is('markup.italic')) return 'emphasis';
    if (is('markup.underline.link')) return 'link_uri';
    if (is('markup.raw')) return 'text.literal';
    if (is('markup.list')) return 'punctuation.list_marker';
    if (is('punctuation.section') || is('punctuation.definition.block')) return 'punctuation.bracket';
    if (is('punctuation.separator') || is('punctuation.terminator')) return 'punctuation.delimiter';
    if (is('punctuation')) return 'punctuation';
    return null;
}

// The default highlight themes, with the serde names of `SyntaxColors`.
const themeSet = JSON.parse(fs.readFileSync(path.join(root, 'gpui-kit/crates/component/src/theme/default-theme.json'), 'utf8'));
const KEYS = {
    'comment.doc': 'comment_doc'
};
function hex(color) {
    // `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa` as lowercase `#rrggbbaa`.
    let h = color.trim().slice(1).toLowerCase();
    if (h.length === 3 || h.length === 4) h = h.split('').map((c) => c + c).join('');
    if (h.length === 6) h += 'ff';
    return '#' + h;
}
function resolver(highlight) {
    const syntax = (highlight && highlight.syntax) || {};
    const own = (name) => {
        const entry = syntax[KEYS[name] || name];
        if (!entry || typeof entry !== 'object') return null;
        const color = typeof entry.color === 'string' ? hex(entry.color) : null;
        const italic = entry.font_style === 'italic' ? 1 : 0;
        const weight = [100, 200, 300, 400, 500, 600, 700, 800, 900].includes(entry.font_weight) ? entry.font_weight : null;
        return { color, italic, weight };
    };
    const style = (name) => {
        if (name.length === 0) return null;
        const s = own(name);
        if (s) return s;
        if (name.includes('.')) return style(name.split('.')[0]);
        return null;
    };
    return style;
}
const themes = {};
for (const theme of themeSet.themes) themes[theme.mode] = resolver(theme.highlight);

function lineRuns(tokens, length, style) {
    // One entry per UTF-16 unit: the style of the innermost named scope.
    const runs = [];
    for (const token of tokens) {
        const start = Math.min(token.startIndex, length);
        const end = Math.min(token.endIndex, length);
        if (end <= start) continue;
        let name = null;
        for (let i = token.scopes.length - 1; i >= 0; i--) {
            name = semanticName(token.scopes[i]);
            if (name) break;
        }
        const s = name ? style(name) : null;
        const key = s ? [s.color, s.italic, s.weight] : [null, 0, null];
        const last = runs[runs.length - 1];
        if (last && last[1] === start && last[2] === key[0] && last[3] === key[1] && last[4] === key[2]) {
            last[1] = end;
        } else {
            runs.push([start, end, ...key]);
        }
    }
    return runs;
}

const out = { vscodeTextmate: vtmVersion, vscodeOniguruma: onigVersion, cases: [] };
for (const [sample, token, grammarName] of cases) {
    const text = fs.readFileSync(path.join(samplesDir, sample), 'utf8');
    const grammar = await registry.loadGrammar(byName.get(grammarName));
    if (!grammar) throw new Error('No grammar ' + grammarName);
    const lines = text.split('\n');
    if (lines[lines.length - 1] === '') lines.pop();
    const record = { sample, token, grammar: grammarName, light: [], dark: [] };
    let state = vsctm.INITIAL;
    for (const line of lines) {
        const r = grammar.tokenizeLine(line, state);
        record.light.push(lineRuns(r.tokens, line.length, themes.light));
        record.dark.push(lineRuns(r.tokens, line.length, themes.dark));
        state = r.ruleStack;
    }
    out.cases.push(record);
}
fs.writeFileSync(path.join(here, 'truth.json'), JSON.stringify(out));
console.log('Recorded ' + out.cases.length + ' cases');
