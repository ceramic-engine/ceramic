# Cityscape

Cityscape is a code editor for Ceramic and Glaze: a Haxe port of [Monaco](https://github.com/microsoft/monaco-editor), the editor of Visual Studio Code (vscode `src/vs/editor`, at the commit of monaco-editor 0.52.2). It keeps Monaco's behaviour and API names (options, theme color keys, `deltaDecorations`, `pushEditOperations`...), renders with Glaze, and uses the Glaze kit for its chrome (scrollbars, popovers, menus, inputs). The editor is a Glaze component that sits anywhere in a Glaze UI, several at once, sharing models or not.

Package `cityscape`. Monaco is by Microsoft, MIT licensed; see [NOTICE.md](NOTICE.md).

**Status: in progress.** The foundations are in place (core types, frozen interfaces of the model, view model and editor, editor option validation); the model, the view, the cursor controller and the contributions come next. There is no usable editor yet.

## Setup

Cityscape needs Glaze. List both plugins in your project's `ceramic.yml`:

```yaml
app:
    plugins:
        - glaze
        - cityscape
```

Ceramic has no way for a plugin to enable another one, hence both entries. Until the Ceramic tools are rebuilt with this plugin, add its sources too (`paths: [<ceramic>/plugins/cityscape/runtime/src]`), like the test projects do.

## Languages, grammars and themes

Languages, tokenizers and themes belong to a `Cityscape` context (`Cityscape.defaultContext`, or `new Cityscape()` to keep two uses apart), like Monaco's `monaco.languages` and `monaco.editor.defineTheme`:

```haxe
final cityscape = Cityscape.defaultContext;

// monaco.languages.register
cityscape.languageService.registerLanguage({id: 'javascript', extensions: ['.js', '.mjs'], aliases: ['JavaScript', 'js']});

// A TextMate grammar (text of a .tmLanguage.json file, here one of the
// grammars bundled with Glaze), tokenized with vscode-textmate's port and
// Oniguruma (onig.wasm on the web when Glaze loads it)
cityscape.textMate.registerGrammar({languageId: 'javascript', grammar: grammarJson, path: 'javascript.json'});

// monaco.editor.defineTheme / setTheme, from a VS Code theme ({colors, tokenColors})
// or a tmTheme style one ({colors, settings}): token colors follow, live
cityscape.themeService.defineTheme('my-theme', VSCodeTheme.toStandaloneThemeData(themeObject));
cityscape.themeService.setTheme('my-theme');
```

Models are tokenized in the background with one time budget per frame for all the models of the context (`cityscape.backgroundScheduler.budgetMs`), the visible lines first.

## Layout

- `runtime/src/cityscape`: the port, organized like `src/vs/editor` (`common/core`, `common/config`, `common/...`; `browser` becomes `view`), with the parts of `src/vs/base` and `src/vs/platform` it needs under `base/` and `platform/`.
- `tests/unit`: unit tests (vscode's own tests, ported, and comparisons with recordings of the real Monaco in `tests/unit/data/monaco`). Node: `ceramic headless run node --setup --assets --allow-multiple`; macOS: `ceramic clay build mac --setup --assets --allow-multiple`, then `project/mac/unit.app/Contents/MacOS/unit`.
- `tests/bench`: benchmarks (see its README).
- `docs/PORTING.md`: the porting rules. `docs/DEVIATIONS.md`: the intended differences with Monaco.
