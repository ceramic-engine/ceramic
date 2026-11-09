# Porting conventions (TypeScript to Haxe)

Cityscape is a port of Monaco (vscode `src/vs/editor`, commit a7d9e2c32d573e29e68975838196722ae9bb0f15, the `vscodeRef` of monaco-editor 0.52.2), not a rewrite. The goal is code that can be compared line by line with the TypeScript, behaving the same, while staying idiomatic Haxe and fast on hxcpp. Expected values in tests come from vscode (its tests, ported) or from recordings of the real Monaco, never from Cityscape.

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

## Tests

- Port vscode's tests of every ported module into `tests/unit/src/tests/<path>`, same names (`test('empty range')` becomes `testEmptyRange`), same expected values. A test that cannot be ported yet is listed in the class comment with the reason.
- Data from the real Monaco lives in `tests/unit/data/monaco`, written by glaze-golden's `reference/cityscape/` scripts, and is embedded at compile time (`testing.MonacoTruth`). Never edit those files by hand.
- Every suite passes on Node and native macOS before a change is handed over (Unity at the end).
