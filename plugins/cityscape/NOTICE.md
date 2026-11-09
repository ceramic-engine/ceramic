# Notices and credits

Cityscape is Copyright (c) 2026 Jeremy Faivre and licensed under the MIT License (see [LICENSE](LICENSE)).

This project contains Haxe translations ("ports") of third party code. The original authors keep their copyright, and the ported files remain under their original license. Each ported file starts with a header naming the original file, its copyright holder and license, and stating that it was modified (translated to Haxe):

```haxe
// Ported from vscode src/vs/editor/common/core/range.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
```

## Visual Studio Code (Monaco editor)

- Project: Visual Studio Code, <https://github.com/microsoft/vscode>, whose `src/vs/editor` is the Monaco editor (<https://github.com/microsoft/monaco-editor>)
- Version ported: vscode commit a7d9e2c32d573e29e68975838196722ae9bb0f15, the `vscodeRef` of monaco-editor 0.52.2
- Copyright (c) Microsoft Corporation
- License: MIT, see [LICENSES/MIT-vscode.txt](LICENSES/MIT-vscode.txt)
- Ported into: `runtime/src/cityscape/**` (from `src/vs/editor/**`, and the parts of `src/vs/base/**` and `src/vs/platform/**` it uses), and the tests of `tests/unit` ported from vscode's tests (`src/vs/editor/test/**`). Files that are new code (not ports) say so in their header.
- Reference data: the files of `tests/unit/data/monaco` are outputs of the real Monaco (the monaco-editor 0.52.2 build vendored in loreline-monaco), written by the scripts of glaze-golden's `reference/cityscape/`. `textmate-tokens.json` also holds VS Code's Dark+ and Light+ themes (Copyright (c) Microsoft Corporation, MIT, as vscode-textmate's tests ship them) and the texts of Glaze's highlighter samples (`plugins/glaze/tests/unit/data/highlight/samples`, see their NOTICE.md); the grammars it was made with are Glaze's (`plugins/glaze/assets/glaze/grammars`, see their NOTICE.md).

## Codicons (vscode-codicons)

- Project: vscode-codicons, <https://github.com/microsoft/vscode-codicons>, the icon font Monaco ships (`codicon.ttf` of monaco-editor 0.52.2)
- Copyright (c) Microsoft Corporation
- License: Creative Commons Attribution 4.0 International (CC BY 4.0), <https://creativecommons.org/licenses/by/4.0/>
- Used in: `runtime/src/cityscape/view/Codicons.hx`, the outlines of the `chevron-down` (U+EAB4) and `chevron-right` (U+EAB6) glyphs, written as SVG paths (the glyph points of the font, flipped to SVG's y axis). Modified: converted from the font's glyph outlines to SVG paths; the shapes are unchanged.

## Lucide

- Project: Lucide, <https://lucide.dev>, version lucide-static 1.60.0
- Copyright (c) 2026 Lucide Icons and Contributors (some icons derived from Feather, Copyright (c) 2013-present Cole Bemis, MIT, listed in the license file)
- License: ISC, see [LICENSES/ISC-lucide.txt](LICENSES/ISC-lucide.txt)
- Used in: `runtime/src/cityscape/view/SymbolIcons.hx`, the SVG icons standing for Monaco's codicons in the suggest widget, the hover, the quick fix menu and the lightbulb (completion and symbol kinds, marker severities, lightbulb). Unmodified, embedded as SVG text.
