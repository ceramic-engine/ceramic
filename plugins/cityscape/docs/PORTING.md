# Porting conventions (TypeScript to Haxe)

Cityscape is a port of Monaco (vscode `src/vs/editor`, commit a7d9e2c32d573e29e68975838196722ae9bb0f15, the `vscodeRef` of monaco-editor 0.52.2), not a rewrite. The goal is code that can be compared line by line with the TypeScript, behaving the same, while staying idiomatic Haxe and fast on hxcpp. Expected values in tests come from vscode (its tests, ported) or from recordings of the real Monaco, never from Cityscape.

## Public surface and the end of the port

- What a Cityscape user writes against sits at the package root: `cityscape.CityscapeEditor` (the Glaze component), `cityscape.Cityscape` (the context). Code that is Cityscape's own (the component, the context, the typed decoration API) goes to the root or to a package with a meaningful name, never to a vscode folder name such as `standalone`.
- Ported files keep vscode's paths during the port only, so that each one can be compared with its original. This mapping is a tool for the port, not a lasting constraint: once Monaco is ported, Cityscape is its own code base. From then on files are moved, merged, renamed and changed freely like any other code, without keeping a correspondence with Monaco's files (owner decision, 2026-11-09). The `Ported from` headers stay as the record of origin and license.

## Sources

- vscode sources: glaze-golden `reference/vscode` (shallow, sparse, read only clone of `src/vs/editor`, `src/vs/base` and a few `src/vs/platform` folders).
- The monaco-editor 0.52.2 build vendored in loreline-monaco (`monaco-editor/esm`), with loreline's patches (marked `[loreline]`): the second reference, and the one the truth scripts of glaze-golden `reference/cityscape/` run.

## Files and headers

- One Haxe module per TypeScript file, named after the file in PascalCase, in the package that mirrors its folder: `src/vs/editor/common/core/range.ts` becomes `cityscape/common/core/Range.hx` (package `cityscape.common.core`). `src/vs/editor` is the root (`cityscape`); `src/vs/base/...` goes to `cityscape/base/...`, `src/vs/platform/...` to `cityscape/platform/...`. `browser` becomes `view` (Glaze rendering).
- A module holds all the types of its TypeScript file (`Model.hx` holds `ITextModel`, `EndOfLinePreference`, `FindMatch`...): `import cityscape.common.Model;` brings them all. The module functions of a file go into a class named after the file (`strings.ts` functions are `Strings.isBasicASCII`...), or after its main concept when the file name is already a type (`ModelUtils.shouldSynchronizeModel`).
- Every ported file starts with:

  ```haxe
  // Ported from vscode src/vs/editor/common/core/range.ts
  // Original code Copyright (c) Microsoft Corporation, licensed under MIT.
  // Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
  ```

  (`src/vs/base/...` or `src/vs/platform/...` for those files). Ported tests use the same header with the test file. New code says `// New code for Cityscape (not a port): ...`.
- Keep Monaco's doc comments (shortened when they only repeat the code). Keep `@internal` marks.
- Parts not ported yet are marked `TODO(step N)` with what is missing; placeholders sit in the module where the real type will go, so that later work fills them in place.

## Names

- Monaco's names are kept everywhere: types, methods, fields, option names, theme color keys, command ids. Monaco code and Monaco options (loreline-monaco's, Writer's) must map one to one.
- Haxe forbids a static and an instance field with the same name: the static one takes the suffix `Static` (`Range.isEmpty(r)` is `Range.isEmptyStatic(r)`, `Position.equals(a, b)` is `Position.equalsStatic(a, b)`; the instance methods keep their names).
- Haxe keywords used as names are quoted in object literals (`"class"`, `"function"`); a field or method named like a keyword gets a suffix and a comment.
- `const enum` and number enums become `enum abstract X(Int) from Int to Int` with the same values; string literal unions become `String` (or `enum abstract X(String)`, like `Handler`), with the allowed values in the doc comment. Named string unions keep their name as a typedef (`typedef EditorAutoClosingStrategy = String`).
- `EditorOption` is a typed id: `EditorOption.fontSize` is an `EditorOption<Float>`, and `options.get(EditorOption.fontSize)` is a `Float`, like Monaco's `FindComputedEditorOptionValueById`.

## Types

- Object types with methods become Haxe `interface`s (`ITextModel`, `ICommand`, `IViewModel`). Data shapes become `typedef` structures (`IPosition`, `IRange`, `IModelDecorationOptions`, the option inputs), so that literals work like in TypeScript (`{lineNumber: 1, column: 1}`). Classes stay classes.
- `readonly` fields are `final`; optional fields are `@:optional` (or `?name` arguments). `T | null` is `Null<T>`.
- Unions of unrelated types are `haxe.extern.EitherType<A, B>` and are tested at run time like Monaco does (`JsValues.isString`, `Std.isOfType`). Avoid `Dynamic`; `Any` is used only for values that are untyped in Monaco (`any`, `unknown`: option input before validation, `attachedData`, command arguments).
- Function types use the modern notation: `(lineNumber:Int) -> String`, `() -> Void`, never the curried form.
- Monaco's `Event<T>` is `cityscape.base.common.Event<T>`, a function taking a listener and returning an `IDisposable`; `Event<void>` is `VoidEvent` (its listener takes no argument).
- Methods returning promises in Monaco return nothing (or take a callback) unless the asynchronous result is needed: say so in the doc comment.
- Overloads are merged into one method: optional arguments, or one `EitherType` parameter, documented.
- Structural typedefs (`IRange`, `IPosition`, `ISelection`) are read through dynamic field access on hxcpp and C#. Hot paths take the classes (`Range`, `Position`, `Selection`); the `I*` typedefs are for API entry points and literals. Instance methods read their own fields directly instead of calling the static version with `this`.
- JavaScript semantics on untyped values (`typeof`, `Boolean(x)`, `parseInt(x, 10)`, `parseFloat(x)`, `String(x)`) go through `cityscape.base.common.JsValues`, never Haxe's `Std.parseInt` (it accepts `0x` and differs between targets).
- Sorting: JavaScript's `Array.prototype.sort` is stable, Haxe's `Array.sort` is not guaranteed to be: use `haxe.ds.ArraySort.sort` where Monaco sorts with ties.

## Binary tokens

- `Uint32Array` is `haxe.io.UInt32Array` (a typed array on js, bytes on hxcpp). Read an element as `(tokens[i] : Int)` before comparing or computing; metadata with the highest background bit set is a negative `Int` (same bits). Monaco's `Uint32Array | ArrayBuffer` storage of line tokens is always the `UInt32Array` here.
- Tuples returned by TypeScript functions become small classes (`EolCount` for `countEOL`), or typedefs when they are built once.

## Pitfalls

- An `enum abstract` imported into a module brings its values into scope: `StandardTokenType` has a value `String`, so `Std.isOfType(x, String)` in a module importing it tests against the number 2. Write `std.String` there.
- On hxcpp, call `StringTools.fastCodeAt` on a typed local, not directly on the field of a structure (`final text:String = change.text;` first): the dynamic field access breaks the inlined `cca` call ("Null Function Pointer").
- A `macro` function in a module that also holds runtime code makes the macro context type that module and everything it references: keep macros in macro-only modules (`testing.MonacoTruth`, the bench's `testing.BenchData`).

## Text and positions

- Text is stored as Haxe `String`. Line numbers and columns start at 1; columns, offsets and lengths are in UTF-16 code units, exactly like Monaco and LSP, on every target: `String.length` and `charCodeAt` count UTF-16 units on js, hxcpp (checked by `HaxeStringTest`, including astral characters as surrogate pairs) and C#.
- Use `StringTools.fastCodeAt` (or `unsafeCodeAt` in checked hot loops) for `charCodeAt`; the results compare with `CharCode` constants.
- The conversion to the UTF-8 bytes of Glaze's text system happens per visible line, at the rendering boundary, and nowhere else.

## No dependency injection, no editor state in statics

- vscode's services and `instantiationService` are not ported. Services become fields of a `Cityscape` context object (`cityscape.Cityscape`): a default one, and others can be created to keep two uses apart. A class that takes services in Monaco's constructor takes the context (or the specific service objects) instead.
- No editor state in statics: several editors run at once, in one window or several, sharing a model or not. Statics are only for immutable data (option definitions, character tables) and global id counters. Static data that depends on the platform is created on first use (the Ceramic app does not exist yet when statics initialize on the web).

## Chrome from the Glaze kit

- Monaco's DOM widgets are not ported. The logic of the contributions (find, suggest, hover, folding...) is ported; their UI uses the Glaze kit: scrollbars and scrolling, popovers (`HoverCard`, `Popover`), lists and menus (`ContextMenu`), `Input`, buttons, toggles, `ColorPicker`, `TextView` for markdown. Parts of the kit's previous code editor that fit (`CompletionMenu`, `CodeActionMenu`, `HoverPopover`, `SearchPanel`, `CaretAnchoredPopup`) are reused.
- When the kit and Monaco disagree on chrome behaviour (scrolling), the kit wins; the difference goes to [DEVIATIONS.md](DEVIATIONS.md).

## Model specifics (step 1)

- Regular expressions: ported code uses `cityscape.base.common.RegExp` (JavaScript's `RegExp`: `exec`, `lastIndex`, `global`/`ignoreCase`/`multiline`/`unicode`, match indices in UTF-16 units, null for groups that did not match) where Monaco uses a regex literal or `new RegExp`. It is the native `RegExp` on JavaScript and Haxe's `EReg` (PCRE2 on hxcpp) elsewhere, with the source translated to keep JavaScript's meaning (see the class comment and DEVIATIONS.md). Fixed patterns that only test characters (`/\r\n|\r|\n/g` replacements, `cleanClassName`, `escapeRegExpCharacters`...) are written as loops instead (`Strings.replaceLineBreaks`, `Strings.removeTrailingLineBreak`, `Strings.splitLines`).
- Red-black trees: Monaco shares one `SENTINEL` node per module and writes to it during operations; `PieceTreeBase` and `IntervalTree` have their own `SENTINEL` field instead (no state shared between models), and `TreeNode.next`/`prev` take the sentinel of their tree. The code otherwise reads like Monaco's (`final SENTINEL = T.SENTINEL;`).
- Tuples returned by Monaco's functions become small result objects or fields: `EolCounter.countEOL(text, ?result)` returns an `EolCount` (reusable, no allocation per call), `PieceTreeBase.getIndexOf` stores its result in fields.
- Scratch objects on the hot paths: `PieceTreeBase.getLineCharCode` and `getPositionAt` reuse a scratch node position and cursor; the search cache of the piece tree reuses its entry; the change buffer's line starts grow in place (Monaco concatenates arrays). These change no result.
- Change buffer of the piece tree: appending to a string copies it on hxcpp, so the piece tree starts a new change buffer every 16384 characters (`PieceTreeBase.ChangeBufferLimit`); the text, the line breaks and the line starts are the same as Monaco's (tested by `ChangeBufferTest` against a plain string).
- Events: `Emitter`/`VoidEmitter` (base/common/Event.hx) port the delivery queue of Monaco's emitter: an event fired from a listener is delivered after the current event reached all the listeners; an error in a listener goes to `Errors.onUnexpectedError` and the other listeners still get the event.
- `IntervalNode`s are returned as `IModelDecoration`s (they have the same fields), and their `options` are `ModelDecorationOptions` instances read through `IModelDecorationOptions`; `Std.downcast(decoration.options, ModelDecorationOptions)` gives typed access.
- Interface methods must match exactly in Haxe (no extra optional argument in the implementation): Monaco's extra arguments become separate methods (`PieceTreeTextBufferBuilder.finish(normalizeEOL)` is `finishWithNormalizeEOL(normalizeEOL)`, `TextModel.getLinesDecorations(..., onlyMarginDecorations)` is `_getLinesDecorations`), and the `eol` argument of `ITextBuffer.getValueInRange` stays required.
- `EditOperation.insert`/`delete`/`replace`/`replaceMove` return `IIdentifiedSingleEditOperation` (TypeScript accepts an `ISingleEditOperation` there, Haxe does not), which still passes as an `ISingleEditOperation`.
- Undo/redo: `UndoRedoService` is a field of the `Cityscape` context (`context.undoRedoService`); `TextModel` takes the context as its last constructor argument (`Cityscape.defaultContext` when null). The tests create a context per model (`tests.TestTextModel.createTextModel`), like vscode's test services.

## View specifics (step 2)

- Two classes of a module may not share a name in Haxe: the outgoing `ViewZonesChangedEvent` of viewModelEventDispatcher.ts is `ViewZonesChangedOutgoingEvent` (the view event keeps its name), and the outgoing events extend `OutgoingViewModelEvent` (Monaco's union type).
- `ViewLineRenderer` keeps Monaco's rendering to HTML (`renderViewLine`, used by vscode's tests) and renders through a sink (`IRenderLineSink`, `renderViewLineTo`): the Glaze view collects the text and the class names of each part (`ViewLineRuns`) instead of HTML. The character mapping is Monaco's.
- `ViewModel` takes the `Cityscape` context as its last argument (the model's when null) for the theme service and the tokenization registry Monaco injects; `CityscapeView` reads the theme colors and the token color map through `ViewTheme`.
- Monaco's view parts (DOM) are replaced by one Glaze element (`CityscapeViewElement`) that paints the same layers in Monaco's order: current line, decorations, selections, indent guides, rulers, text, cursors, then the margin and the overview ruler.

## Cursor specifics (step 3)

- The cursors of an editor are a `CursorsController` (common/cursor/Cursor.hx) owned by its `ViewModel`, which exposes Monaco's cursor operations (`type`, `paste`, `cut`, `compositionType`, `startComposition`, `endComposition`, `executeEdits`, `executeCommand`, `executeCommands`, `setCursorStates`, `saveCursorState`, `restoreCursorState`). `ViewModel.setSelections` takes `Selection` instances (Monaco takes `ISelection`s).
- `PartialCursorState` is the common base class of `CursorState`, `PartialModelCursorState` and `PartialViewCursorState` (Monaco's union type); `CursorState.fromSelections` lifts `Selection` instances without structural access.
- `CursorConfiguration` takes the `ILanguageConfigurationService` of the context (`Cityscape.languageConfigurationService`); Monaco's `CharacterMap` objects are `Map<String, String>`/`Map<String, Bool>`, and `shouldAutoCloseBefore` is a small class of three functions.
- Tuples become result classes or arrays (`DeleteOperations.deleteLeft` returns a `DeleteOperationsResult`, `AtomicTabMoveOperations.whitespaceVisibleColumn` an array of three numbers, `Strings.getCharContainingOffset` an array of two offsets). JavaScript truthiness is written out (`IndentAction.None` is 0 and falsy where Monaco tests `if (action)`; `normalizeOperationType`'s `'space'` is -1).
- Code points out of range are -1 (JavaScript's `NaN`) in `Strings.getNextCodePoint` and `getPrevCodePoint`; the grapheme break table is `GraphemeBreakData` (a module of its own because of its size).
- The editor commands of `browser/coreCommands.ts` and `contrib/wordOperations/browser/wordOperations.ts` are ported in `cityscape/view/CoreCommands.hx` and `cityscape/contrib/wordOperations/view/WordOperations.hx`, with their keybindings (see "Commands, keybindings and the editor"). They run on an `ICodeEditor` (`cityscape/view/EditorBrowser.hx`) and their `ServicesAccessor` is the `Cityscape` context. Their arguments are `Any` (Monaco's `Partial<...Options>`), read with `JsValues`.
- Test helpers: `testing.TestCodeEditor` (vscode's `TestCodeEditor` and `withTestCodeEditor`: a `CodeEditorWidget` on the real `ViewModel`, the test configuration of 100x100 pixels with the mock font) and `testing.TestCommand` (`testCommand`, `getEditOperation`). vscode tests that replace `viewModel.getCompletelyVisibleViewRange` set `ViewModel._getCompletelyVisibleViewRangeOverride` (an interface method cannot be replaced in Haxe). Test helpers whose name starts with `test` are renamed (`doTestCommand`...): the runner runs every method named `test*`.

## Folding specifics (step 4)

- contrib/folding/browser is `cityscape/contrib/folding/view`. The module functions of foldingModel.ts, indentRangeProvider.ts and foldingRanges.ts are in `FoldingModelUtils`, `IndentRangeProviderUtils` and `FoldingRangesConstants`. `FoldRange` is a class (the merge reads and writes it on every update). `getRegionsInside` takes a filter without level; the filter with a level (Monaco checks the arity of the function) is `getRegionsInsideWithLevel`. Monaco's `false` for a limit that was not reached (`FoldingLimitReporter.update`) is null.
- Promises: `RangeProvider.compute` and `FoldingRangeProvider.provideFoldingRanges` give their result to a `resolve` callback (at once or later); `FoldingController.getFoldingModel(callback)` calls back once the pending update ran. `CancellationToken` (base/common/Cancellation.hx) is Monaco's, its `onCancellationRequested` a method taking a listener.
- The folding range providers are registered in the context (`context.languageFeaturesService.foldingRangeProvider.register(selector, provider)`, Monaco's `languages.registerFoldingRangeProvider`); the provider selector of `FoldingController.setFoldingRangeProviderSelector` belongs to the context too. Glob patterns of language filters are not supported yet.
- The controller talks to its editor through `IFoldingEditor` (the part of `ICodeEditor` it uses: decorations owned by the editor, hidden areas, selections, reveal, scroll state, and the events `onDidChangeModel`, `onDidChangeModelContent`, `onDidChangeCursorPosition`, `onMouseDown`, `onMouseUp`...). The mouse events carry Monaco's mouse targets (`cityscape/view/EditorBrowser.hx`), computed by `CityscapeView.mouseTargetAt` like `MouseTargetFactory`. The view keeps the folding state of each model it showed, with its selections and scroll (`saveViewState`/`restoreViewState` of the contribution).
- Commands and keys: the folding actions are Monaco's `EditorAction`s (`FoldingEditorAction`, registered by `FoldingRegistration.register` from `EditorAll`), with Monaco's keybindings (chords included), the precondition `foldingEnabled` (the controller binds it to `isEnabled()` in the editor's context keys) and `editorTextFocus`. The controller works on an `IFoldingEditor`; `CodeEditorFoldingAdapter` gives one over an `ICodeEditor`.

## Commands, keybindings and the editor (step 3, API)

- Registries and services are fields of the `Cityscape` context: `commandsRegistry` (Monaco's `CommandsRegistry`), `keybindingsRegistry` (`KeybindingsRegistry`, with a `version` that changes on every registration), `contextKeyService` (the root `ContextKeyService`), `commandService`, `keybindingService` (`StandaloneKeybindingService`), `codeEditorService`, `modelService`, `markerService`, `markerDecorationsService`, `nls`. `context.editorExtensions` (`EditorExtensionsRegistry`, Monaco's `EditorExtensionsRegistry` and the module level registration code of editorExtensions.ts) is filled on first use by `EditorAll.registerAll` (editor.all.ts): one `XxxRegistration.register(r)` per ported contribution.
- A command or action class takes the registry in its constructor when it needs `localize` (`new StartFindAction(r)`), since NLS is per context. Monaco's `registerEditorCommand(new X())` at module level becomes a line of the contribution's `register(r)`.
- `EditorCommand.bindToContribution` is `ContributionCommand<T>` (a class with a getter and a handler), `MultiEditorAction` and `MultiCommand` keep Monaco's priorities. `Action2`/`EditorAction2` have no menu service: their `f1`, `menu` and `precondition` are kept for lookups only.
- `ICommandHandler` is `(accessor:Null<Cityscape>, args:Array<Any>) -> Void`: the accessor is the context, the arguments one array (Monaco's rest arguments).
- `ContextKeyExpr` and its expression classes, `Scanner` and `Parser` are contextkey.ts and scanner.ts; the `when` clauses are parsed by the same parser. `ContextKeyExpr.false()`/`true()` are `falseExpr()`/`trueExpr()`, `in` is `inExpr`, the rest arguments of `and`/`or` are kept (Haxe `...rest`), `andArray`/`orArray` take an array. JavaScript comparisons of context values (`==`, `<` on strings and numbers) are `JsCompare`.
- `KeyCode`, `ScanCode` and `KeyMod` are keyCodes.ts (`KeyChord(a, b)` is `KeyCodes.KeyChord`). `Keybindings.decodeKeybinding` takes a number; Monaco's `number[]` form is `decodeKeybindingChords`. `Platform.OS` is the `OperatingSystem` of Glaze.
- `CodeEditorWidget` (`cityscape/view/widget/codeEditor`) is Monaco's code editor widget without the DOM: model, view model, options, context keys, contributions, actions, events, decorations, per model view state. `CityscapeView` (Glaze entity) renders it (`ICodeEditorView`), and `CityscapeEditor` (Glaze component) owns both and forwards Monaco's `IStandaloneCodeEditor` methods.
- Keys: each distinct chord of the context's keybindings gets one Glaze `KeyBinding` in the key context `CityscapeEditor` with the data action `cityscape::RunKeybinding` (its Monaco dispatch string). The editor's root element handles it: `keybindingService.dispatchKeypress` resolves it against the editor's scoped context keys, runs the command with the editor as the invoking editor, or calls `cx.propagate()` so that a binding of an ancestor key context (an app shortcut) runs. New chords are bound when the keybindings change. Keys without a binding reach the view's key listener (Enter typed, `onKeyDown` listeners); typed characters come from the text input handler.

## Find specifics (step 4)

- contrib/find/browser is `cityscape/contrib/find/view`. The contribution, its actions and its commands are registered by `FindRegistration.register(r)` (findController.ts module level code); `StartFindAction` and `StartFindReplaceAction` are plain `EditorAction`s (Monaco's `MultiEditorAction` with its single editor implementation). The context keys are `RawContextKey`s of `FindModel` (`findWidgetVisible`, `findInputFocussed`, `replaceInputFocussed`), bound to the editor's context key service.
- The find widget is the overlay widget `FindWidgetOverlay` (top right corner), whose Glaze view `FindWidget` (kit inputs and buttons) is created at the first render of the editor and shows or hides itself, so that a change of the find state renders the widget only.
- `FindReplaceState.change` takes Monaco's `INewFindReplaceState` with optional fields; `searchScope: null` (clear the scope) is told apart from a missing `searchScope` with `Reflect.hasField`. `changeMatchInfo`'s optional `currentMatch` is an extra `hasCurrentMatch` argument, `research`'s optional new scope a `hasNewFindScope` argument.
- `ReplacePiece`'s static constructors take the `Static` suffix (`ReplacePiece.staticValueStatic`). The module functions of replacePattern.ts are in `ReplacePatternParser`, of search.ts in `Search`.
- The query options (case, whole word, regex, preserve case) are stored in `Cityscape.storageService` (vscode's `IStorageService`, `platform/storage/common/Storage.hx`); the tests give their controller a storage of their own.

## Editing contributions specifics (step 4)

- bracketMatching, wordHighlighter, multicursor, comment, linesOperations, indentation, smartSelect, caretOperations, cursorUndo, inPlaceReplace and stickyScroll are under `cityscape/contrib/<name>/view` (indentation also has `common`), each registered by its `XxxRegistration.register(r)` line in `EditorAll`. The look of their class names (`bracket-match`, `wordHighlight*`, `selectionHighlight`, `valueSetReplacement`) is registered as decoration styles of the context unless the host registered its own, like the find decorations.
- Promises are callbacks: document highlight, document symbol and selection range providers give their result to a `resolve` callback; `OutlineModel.create`, the sticky model providers and `StickyLineCandidateProvider.update` call back when done. Their timers (`RunOnceScheduler`, `Delayer`) are Monaco's; tests call `_flushPendingUpdate` instead of waiting.
- Monaco's module statics that hold state (the query of the word highlighter) belong to the context: the registration creates them and gives them to the contributions.
- `SymbolKind` is a module of its own (`cityscape.common.SymbolKind`): its values (`String`, `Array`, `Boolean`...) would shadow the standard types of every module importing `Languages`.
- The view parts these contributions need: `view/viewParts/indentGuides/IndentGuides.hx` (Monaco's `IndentGuidesOverlay`, painted by `CityscapeViewElement`), `view/Codicons.hx` (the codicon outlines of the folding controls), the sticky scroll widget (an overlay widget whose Glaze view is an entity of its own, rendered again when the widget changes).

## Tests

- Port vscode's tests of every ported module into `tests/unit/src/tests/<path>`, same names (`test('empty range')` becomes `testEmptyRange`), same expected values. A test that cannot be ported yet is listed in the class comment with the reason.
- Data from the real Monaco lives in `tests/unit/data/monaco`, written by glaze-golden's `reference/cityscape/` scripts, and is embedded at compile time (`testing.MonacoTruth`). Never edit those files by hand.
- Every suite passes on Node and native macOS before a change is handed over (Unity at the end).
