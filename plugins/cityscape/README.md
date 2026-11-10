# Cityscape

Cityscape is a code editor for Ceramic and Glaze: a Haxe port of [Monaco](https://github.com/microsoft/monaco-editor), the editor of Visual Studio Code (vscode `src/vs/editor`, at the commit of monaco-editor 0.52.2). It keeps Monaco's behaviour and API names (options, theme color keys, `deltaDecorations`, `pushEditOperations`...), renders with Glaze, and uses the Glaze kit for its chrome (scrollbars, popovers, menus, inputs). The editor is a Glaze component that sits anywhere in a Glaze UI, several at once, sharing models or not.

Package `cityscape`. Monaco is by Microsoft, MIT licensed; see [NOTICE.md](NOTICE.md).

Cityscape is Glaze's code editor: it replaces gpui-kit's code editor, which Glaze does not include (the kit keeps its text inputs, `Input`, `Textarea` and the others).

**Status: in progress.** In place: the text model, tokenization (TextMate grammars, themes), the view (wrapping, decorations of Monaco and typed styles, hidden ranges, selections, cursors, mouse, clipboard, IME, sticky scroll), Monaco's commands and keybindings, the editing contributions (find and replace, folding, bracket matching, multicursor, comments, line operations, indentation), the language features (suggest, hover, markers, code actions, definitions, symbols) with an LSP client, and the diff editor. Not yet: inlay hints, code lens, rename, semantic tokens, inline completions, parameter hints, color decorators, and Unity.

## Setup

Cityscape needs Glaze. List both plugins in your project's `ceramic.yml`:

```yaml
app:
    plugins:
        - glaze
        - cityscape
```

Ceramic has no way for a plugin to enable another one, hence both entries. Until the Ceramic tools are rebuilt with this plugin, add its sources too (`paths: [<ceramic>/plugins/cityscape/runtime/src]`), like the test projects do.

## In a Glaze UI

A `CityscapeEditor` is placed like any kit component, inside the kit's window root, and sized by the flex layout of its parent:

```haxe
// A view of the app: a toolbar of the kit above an editor that takes the rest
vFlex().sizeFull()
    .child(hFlex().gap2().p2().child(Button.component('run').label('Run').onClick(() -> run())))
    .child(CityscapeEditor.component().model(model).context(cityscape).flex1())
```

To make an editor look like the kit around it, `cityscape.kit.KitTheme.apply(context, Theme.global(cx))` defines and sets a theme made of the kit theme's colors (call it from a render: it changes the theme only when the kit's colors changed), and `cityscape.kit.KitGrammars.register(context, 'rust')` registers a TextMate grammar bundled with Glaze (on the web, load its file first with `glaze.kit.highlighter.Highlighter.preload(['rust'], done)`). For VS Code's colors, `cityscape.standalone.common.VSCodeDefaultThemes.apply(context, dark)` sets Dark+ or Light+ (the story gallery of Glaze follows the kit's theme mode with them).

### The kit inspector

Glaze's element inspector (define `glaze_inspector`, see Glaze's README) edits the style of the inspected element as Rust builder calls and as JSON in two `CityscapeEditor`s, configured to look like gpui-kit's code editor (the kit's mono font and size, rows of 1.5 times the size, the kit theme's colors with `KitTheme`, indent guides, no line numbers, the kit frame and scrollbar, and gpui-kit's scrolling past the last line with the Cityscape options `scrollBeyondLastLineGap` and `scrollbarThumbExcludesPadding`), with a completion provider for the style methods and the parse errors as markers. A project built with `glaze_inspector` lists this plugin too:

```yaml
app:
    plugins:
        - glaze
        - cityscape
    defines:
        - glaze_inspector
```

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

Without a `fontFamily`, the editor uses JetBrains Mono, the monospace font bundled with Glaze, on every target; give `fontFamily` (`'Menlo, monospace'`) to use system fonts. Emoji are drawn with the color emoji font on every target, even when a font of the list has a text glyph for them (the Cityscape option `preferColorEmoji`, true by default; `false` follows the font list like Chromium, where Menlo's `☕` is a text glyph).

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

Semantic tokens (`context.registerDocumentSemanticTokensProvider`, `registerDocumentRangeSemanticTokensProvider`) color the identifiers over the TextMate tokens when `editor.semanticHighlighting.enabled` is on (`semanticHighlighting: {enabled: true}` in the options, or a VS Code theme with `"semanticHighlighting": true`); a VS Code theme styles them with its `semanticTokenColors`, else through its TextMate rules like VS Code. Rename (F2) asks the rename providers (`context.registerRenameProvider`) and shows Monaco's rename input at the symbol.

Models are tokenized in the background with one time budget per frame for all the models of the context (`cityscape.backgroundScheduler.budgetMs`), the visible lines first.

## Symbol navigation

Go to definition (F12), declaration, type definition, implementation (Cmd+F12) and references (Shift+F12) use the providers of the context, with Monaco's `gotoLocation` option: several results open the references peek view (Alt+F12, Shift+F12 to peek), a popup under the line with a preview editor and the list of the locations. Locations in other models open through the handlers a host registers:

```haxe
cityscape.codeEditorService.registerCodeEditorOpenHandler((input, source, sideBySide, resolve) -> {
    final editor = openTabFor(input.resource); // the host shows the file
    editor.setSelection(input.options.selection);
    resolve(editor);
});
// "Symbol 1 of 3, F12 for next", shown until disposed
cityscape.onStatusMessage = message -> {
    statusBar.show(message);
    return Lifecycle.toDisposable(() -> statusBar.clear());
};
## Links and colors

Links in the text (http, https and file links, and those of `registerLinkProvider`) are underlined and open on Cmd+click (Ctrl+click elsewhere), through `cityscape.openLink` when the host sets it, else with the platform (`http`, `https`, `mailto`) or as commands (`command:`). Colors (`registerColorProvider`, or the CSS like colors of the text with `defaultColorDecorators: true`) get a swatch that opens a color picker:

```haxe
cityscape.openLink = (uri, fromUserGesture) -> {
    openInMyBrowserTab(uri.toString());
    return true; // handled
};
CityscapeEditor.component().model(model).options({defaultColorDecorators: true, colorDecoratorsActivatedOn: 'click'})
```
Inlay hints and code lenses come from providers, like Monaco's: `context.registerInlayHintsProvider('mylang', provider)` shows the hints (type and parameter hints, with tooltips, a location to go to on Cmd+click, a command or text edits) as injected text (`inlayHints` option: `enabled`, `padding`), and `context.registerCodeLensProvider('mylang', provider)` shows the lenses above their lines, a click running their command (`codeLens`, `codeLensFontSize`, `codeLensFontFamily` options). `context.codeLensCache.saveState()` keeps the lines of the lenses in the context's `storageService` for the next session.
## Snippets and parameter hints

Snippets use Monaco's syntax (tab stops, placeholders, choices, variables, transforms) and its controller; Tab and Shift+Tab move between the tab stops, Escape leaves the snippet:

```haxe
SnippetController2.get(editor.getEditor()).insert("for (i in ${1:0}...${2:count}) {\n\t$0\n}");
```

The file and workspace variables (`TM_FILEPATH`, `WORKSPACE_NAME`...) read `cityscape.labelService` and `cityscape.workspaceContextService` (Monaco's standalone services by default; a host can set its own); `CLIPBOARD` reads `cityscape.readClipboardText`. The parameter hints show the answer of the signature help providers (`cityscape.registerSignatureHelpProvider`) when a trigger character is typed or with Cmd+Shift+Space (`parameterHints: {enabled, cycle}` options, Up and Down for the overloads).

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

## Inline completions

Inline completions (ghost text) follow `monaco.languages.registerInlineCompletionsProvider`: the suggestion shows after the cursor, its next lines below the line, Tab accepts it, Escape hides it, Alt+] and Alt+[ cycle through the suggestions, Cmd+Right (Ctrl+Right) accepts the next word. The `inlineSuggest` option (`enabled`, `mode`, `suppressSuggestions`, `keepOnBlur`) is Monaco's.

```haxe
cityscape.registerInlineCompletionsProvider('haxe', myProvider); // provideInlineCompletions(model, position, context, token, resolve)
```

## Layout

- `runtime/src/cityscape`: the port, organized like `src/vs/editor` (`common/core`, `common/config`, `common/...`; `browser` becomes `view`), with the parts of `src/vs/base` and `src/vs/platform` it needs under `base/` and `platform/`. `kit/` is new code tying the editor to the Glaze kit (`KitTheme`, `KitGrammars`).
- `tests/unit`: unit tests (vscode's own tests, ported, and comparisons with recordings of the real Monaco in `tests/unit/data/monaco`). The project defines `cityscape_debug_counters`: `cityscape.base.common.DebugCounters` then counts the live emitter listeners, disposables, timers, editor views and Glaze entities, which the leak test (`EditorLeakTest`, 100 editors and 20 diff editors created and destroyed) compares with their first values. Node: `ceramic headless run node --setup --assets --allow-multiple`; macOS: `ceramic clay build mac --setup --assets --allow-multiple`, then `project/mac/unit.app/Contents/MacOS/unit`.
- `tests/bench`: benchmarks (see its README).
- `tests/visual`: a visual check of the view (a Haxe sample in two editors), captured to PNG on macOS and the web (see `tests/visual/src/Project.hx`).
- `docs/PORTING.md`: the porting rules. `docs/DEVIATIONS.md`: the intended differences with Monaco.
