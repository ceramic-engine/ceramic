# onig-wasm

Files of vscode-oniguruma 2.0.1 (https://github.com/microsoft/vscode-oniguruma), unchanged:

- `onig.wasm`: file `release/onig.wasm` of the npm package, the WebAssembly build of Oniguruma;
- `vscode-oniguruma.js`: file `release/main.js` of the npm package (its UMD browser build), renamed.

vscode-oniguruma is MIT licensed (LICENSE.txt, Copyright (c) Microsoft Corporation); the
Oniguruma code compiled into `onig.wasm` is BSD-2-Clause (NOTICES.txt, Copyright (c) K.Kosako).

These files are not Ceramic assets. They are only used by web builds of projects that set
the `gpui_onig_wasm` define: the `ceramic gpui setup onig-wasm` task (a `begin build` hook of
the plugin's ceramic.yml) copies `onig.wasm` and `vscode-oniguruma.js` into `project/web`, and
the code highlighter loads them at startup instead of using the pure Haxe Oniguruma engine.
Without the define, the task removes them from `project/web` and nothing of them is compiled
or shipped.
