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
- Reference data: the files of `tests/unit/data/monaco` are outputs of the real Monaco (the monaco-editor 0.52.2 build vendored in loreline-monaco), written by the scripts of glaze-golden's `reference/cityscape/`.
