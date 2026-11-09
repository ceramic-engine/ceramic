# Deviations from Monaco

Cityscape behaves like Monaco (vscode `src/vs/editor` at the commit of monaco-editor 0.52.2): expected values come from vscode's own tests, ported, or from recordings of the real Monaco, never from Cityscape. This file lists the intended differences, and only those. Each entry says what differs, why, and how it is tested.

Differences that only follow from Haxe (overloads merged into one method, static methods renamed with a `Static` suffix, `Event<void>` as `VoidEvent`...) are API conventions, described in [PORTING.md](PORTING.md); they change no behaviour and are not listed here.

## Decided in the plan, to be detailed as they are implemented

- **Rendering by Glaze instead of the DOM.** The view (`cityscape/view`) draws with Glaze; Monaco's DOM view parts are not ported.
- **Chrome from the Glaze kit.** Scrolling and scrollbars, popovers (hover, diagnostics), the suggest list, menus, the find widget and the color picker are the kit's, not Monaco's DOM widgets. Scroll positions are therefore not compared with recordings.
- **No minimap.** The `minimap` option and the minimap decorations are accepted and ignored.
- **Typed decoration style.** Decorations take a typed style (colors, font style, background, borders, joined ranges, hidden ranges) in addition to Monaco's CSS class names, which remain accepted as keys of registered styles.
- **Hidden text inside a line.** Monaco only hides whole lines; Cityscape can hide a range inside a line (through the line projections of the view model).
- **Per editor theme override.** The theme is global to a `Cityscape` context like Monaco's; an editor can override it.

## Option values

- **Options set to null.** Haxe has a single `null` where JavaScript has `undefined` and `null`: an option set to null is read as unset, so it takes its default. In Monaco a `null` reaches the validator (`readOnly: null` gives `false` there, the default `false` here too; `lineNumbers: null` gives `'off'` in Monaco and the default `'on'` here). Tests: `EditorOptionsTruthTest` (the Monaco truths do not include null inputs), `EditorConfigurationTest` (issues 94931 and 102920, where both agree).
- **Values of the wrong type copied as they are.** A few Monaco validators copy a value without checking its type (`gotoLocation.multipleDefinitions` and the other `multiple*` fields, `rulers[].color`). Cityscape keeps such a value only when it has the declared type (a string), and otherwise uses what Monaco uses for a missing value (`'peek'`, `null`). Values of the right type behave the same. Tests: `EditorOptionsTruthTest` (`gotoLocation`, `rulers` cases).

## Model

- **Regular expressions on the native targets.** Find (`TextModel.findMatches`, `TextModelSearch`) and word definitions use JavaScript regular expressions. On JavaScript they are the native `RegExp`. On hxcpp they run on PCRE2 10.42 (Haxe's `EReg`), with the source translated so that the JavaScript meaning is kept: `\w`, `\d`, `\b` are ASCII only, `\s` is JavaScript's set, `.` stops at `\n`, `\r`, U+2028 and U+2029, `^` and `$` follow JavaScript (also around `\r` with `m`), `\uXXXX`, `\u{...}`, `\v`, `\0`, `[]`, `[^]` and `\p{Script=...}` are supported. Differences left: a lookbehind of variable length is rejected by PCRE2 (the search then finds nothing, like an invalid pattern), a backreference to a group that did not take part fails instead of matching the empty string, lone surrogates in a pattern are rejected (in the searched text the result is undefined), case insensitive matching uses PCRE2's Unicode case folding. Tests: `RegExpTest` (JavaScript results, checked against the native `RegExp` by the Node run), `TextModelSearchTest` (all of vscode's cases pass on both targets).
- **Integer positions.** Line numbers, columns and offsets are `Int`: the NaN, float and `undefined` coordinates that Monaco's validation accepts (and floors) cannot be represented. vscode's tests for them are not ported (`EditorModelTextModelTest`, `TextModelCreateSnapshotTest`). On hxcpp, decoration offsets are 32 bit (Monaco's are 53 bit numbers): vscode's 'force delta overflow' interval tree test is not ported.
- **Undo without confirmation.** Monaco asks for a confirmation before undoing an element of another undo source or flagged `confirmBeforeUndo`; there is no dialog service here, the undo proceeds. Errors while undoing or redoing drop the stacks of the resource like Monaco's and go to `Errors.onUnexpectedError` (Monaco also shows a notification). Elements spanning several models (`MultiModelEditStackElement`, workspace elements) are not supported yet.
