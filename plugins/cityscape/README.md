# Cityscape

Cityscape is a code editor for Ceramic and Glaze: a Haxe port of [Monaco](https://github.com/microsoft/monaco-editor), the editor of Visual Studio Code (vscode `src/vs/editor`, at the commit of monaco-editor 0.52.2). It keeps Monaco's behaviour and API names (options, theme color keys, `deltaDecorations`, `pushEditOperations`...), renders with Glaze, and uses the Glaze kit for its chrome (scrollbars, popovers, menus, inputs). The editor is a Glaze component that sits anywhere in a Glaze UI, several at once, sharing models or not.

Package `cityscape`. Monaco is by Microsoft, MIT licensed; see [NOTICE.md](NOTICE.md).

**Status: in progress.** The text model, tokenization (TextMate grammars, themes) and the view are in place: `CityscapeEditor` shows a model with wrapping, decorations (Monaco's and typed styles), hidden ranges, selections and cursors, with minimal typing, mouse selection, clipboard and IME. The cursor controller, commands and the contributions come next.

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

## The editor

`CityscapeEditor` is a Glaze component, sized by the flex layout of its parent. Several editors can show the same model, each with its own selections, scroll and wrapping:

```haxe
final model = new TextModel(text, 'haxe', TextModel.DEFAULT_CREATION_OPTIONS, null, cityscape);

div().flex().sizeFull().child(
    CityscapeEditor.component().model(model).context(cityscape).options({wordWrap: 'on', lineNumbers: 'on'}).flex1()
);

// Monaco's decorations, plus typed styles and hidden ranges
model.deltaDecorations([], [
    {range: new Range(3, 5, 3, 12), options: {description: 'pill', inlineStyle: {background: '#2c313c', borderRadius: 4}}},
    {range: new Range(5, 10, 5, 20), options: {description: 'tag', hidden: true, revealOnCursorLine: true}},
]);
cityscape.registerDecorationStyle('my-class', {color: '#e06c75', fontWeight: 'bold'});
```

The `onCreate` callback gives the `CityscapeEditor`, with Monaco's editor methods and events (`getValue`, `setValue`, `getSelection`, `setSelections`, `revealLineInCenter`, `executeEdits`, `deltaDecorations`, `createDecorationsCollection`, `saveViewState`, `onDidChangeModelContent`, `onDidChangeCursorPosition`...). Commands, actions and keybindings use Monaco's API:

```haxe
CityscapeEditor.component().model(model).onCreate(editor -> {
    editor.addCommand(KeyMod.CtrlCmd | KeyCode.KeyS, (_, _) -> save());
    editor.addAction({
        id: 'my.uppercase',
        label: 'Uppercase',
        keybindings: [KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyU],
        run: (ed, _) -> uppercase(ed)
    });
})

// Remove a default keybinding, bind a command to another key
Cityscape.addKeybindingRule({keybinding: KeyCode.End, command: '-cursorEnd'});
Cityscape.addKeybindingRule({keybinding: KeyMod.CtrlCmd | KeyCode.KeyE, command: 'cursorEnd', when: 'editorTextFocus'});

// Markers (diagnostics), drawn as squiggles and overview ruler marks
Cityscape.setModelMarkers(model, 'my-linter', [{severity: MarkerSeverity.Error, message: 'Unknown name', startLineNumber: 3, startColumn: 5, endLineNumber: 3, endColumn: 9}]);

// Translations of the editor's texts, keyed by English text or message key
cityscape.nls.loadJson(Assets.text('editor-fr.json'));
```

Keys the focused editor does not handle go on to the key bindings of its ancestors, so app shortcuts keep working around an editor.

Models are tokenized in the background with one time budget per frame for all the models of the context (`cityscape.backgroundScheduler.budgetMs`), the visible lines first.

## The diff editor

`CityscapeDiffEditor` is Monaco's diff editor (`monaco.editor.createDiffEditor`) as a Glaze component: the original and the modified texts side by side, or inline (`renderSideBySide: false`, also used when it is narrower than `renderSideBySideInlineBreakpoint`), with the changed lines and characters, the aligned lines, the overview ruler of the changes and Monaco's diff options:

```haxe
CityscapeDiffEditor.component()
    .model({original: originalModel, modified: modifiedModel})
    .options({ignoreTrimWhitespace: false, hideUnchangedRegions: {enabled: true}})
    .onCreate(diffEditor -> {
        diffEditor.onDidUpdateDiff(() -> trace(diffEditor.getLineChanges()));
    })
    .flex1()
```

The diff is computed off the frame (a background thread on the native targets, the next frame on the web) and again 200 ms after an edit. `getOriginalEditor()` and `getModifiedEditor()` give the two `CityscapeEditor`s; `goToDiff('next')`, `revealFirstDiff()`, `updateOptions`, `saveViewState`... are Monaco's. The diff algorithms alone are `cityscape.common.diff.LinesDiffComputers.getDefault()` (and `getLegacy()`).

## Layout

- `runtime/src/cityscape`: the port, organized like `src/vs/editor` (`common/core`, `common/config`, `common/...`; `browser` becomes `view`), with the parts of `src/vs/base` and `src/vs/platform` it needs under `base/` and `platform/`.
- `tests/unit`: unit tests (vscode's own tests, ported, and comparisons with recordings of the real Monaco in `tests/unit/data/monaco`). Node: `ceramic headless run node --setup --assets --allow-multiple`; macOS: `ceramic clay build mac --setup --assets --allow-multiple`, then `project/mac/unit.app/Contents/MacOS/unit`.
- `tests/bench`: benchmarks (see its README).
- `tests/visual`: a visual check of the view (a Haxe sample in two editors), captured to PNG on macOS and the web (see `tests/visual/src/Project.hx`).
- `docs/PORTING.md`: the porting rules. `docs/DEVIATIONS.md`: the intended differences with Monaco.
