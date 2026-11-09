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
