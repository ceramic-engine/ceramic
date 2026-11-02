# Deliberate deviations

The port matches the original GPUI (`gpui-pre` 0.3.10) and gpui-kit (0.8.1) exactly. This file lists the only allowed differences: fixes of defects proven to exist in the original's own output. Any other difference between the port and the original is a bug of the port.

## Rules

A deviation is accepted only with all of the following:

1. **Proof in the original.** A render (or behaviour log) of the unmodified original that shows the defect, with a measurement. The unpatched renders of the affected scenarios are kept in `test/golden/gpui-original/` as that proof.
2. **The fix.** The smallest change that removes the defect without changing the intended look or behaviour. It is applied to the port (GPUI core and gpui-kit alike) and kept equivalent on both sides.
3. **A reference patch.** `reference/deviations/DEV-nnn.patch`, a unified diff against the pinned pristine sources (`gpui-kit/...` or `gpui-pre-<crate>-0.3.10/...`), applied by the reference harness so the port is still compared with the original, patched the same way.
4. **A declaration.** `reference/deviations/DEV-nnn.json`, machine readable: patched files and functions, port files, the scenarios the patch may affect with the allowed pixel regions and scene primitives, the original tests it intentionally changes (with the reason), and the defect metric checks.
5. **Validation.** `reference/verify-deviations.sh` passes (see "Safeguards"), the port matches the patched truth (`compare.js`, `compare-scene.js`) and the port side checks pass (`node reference/verify-deviations.js port`).
6. **Upstream status.** Whether the defect was reported or fixed upstream. When upstream fixes it in a version the port moves to, the deviation is removed.

The patches modify Apache-2.0 code (GPUI: Copyright Zed Industries, Inc.; gpui-kit: Copyright Longbridge). Patched files keep their license headers, every changed place carries a "Modified for ceramic-gpui (DEV-nnn)" comment, and the port files changed by a deviation say so in their header. See [NOTICE.md](NOTICE.md).

## How it works

- `test/golden/gpui/` is the **patched truth**: what the port must match.
- `test/golden/gpui-original/` keeps the unpatched renders and dumps of the scenarios affected by at least one deviation (proof of each defect), and `MANIFEST.json`, the hashes of the verified truth of those scenarios.
- Every scenario that no deviation declares is byte identical (PNG and JSON) between the pristine and the patched builds; the safeguards check it on every run.
- `reference/apply-deviations.sh <mode>` copies the pristine sources (gpui-kit from `../gpui-kit`, the touched gpui-pre crates from the cargo registry) into `reference/vendor/<mode>/`, applies the patches of the mode (`pristine`, `only-DEV-nnn`, `patched`) and writes a harness manifest that uses them (`[patch.crates-io]` for gpui-pre crates, path dependencies for gpui-kit). The plain `reference/Cargo.toml` build stays the pristine original.

To add a deviation: see "Adding a deviation" in [reference/README.md](reference/README.md).

## Safeguards

A patch of the original must never bring another change that would then be taken as truth. `reference/verify-deviations.sh` enforces it and is mandatory before changing a patch or regenerating truths (it is the only supported way to regenerate the truth of a declared scenario: `--update-truths`). It fails on any of:

1. **Declared scope.** Each `DEV-nnn.json` lists the patched files and functions, and for each scenario it may affect: the pixel rectangles allowed to change (`pixels`, device pixels) and the scene primitives allowed to change (`scene`: a region and the primitive kinds; a primitive is declared when its bounds lie inside the region). Behaviour logs it may change are listed in `behaviours`, with the patterns of the log lines the patch may remove (`log_removed`): the patched log must be the pristine log minus such lines. A patch that changes what a step reports declares `log_changed` (from a given log line on, the lines matching its patterns may differ; every other line, the steps included, must stay identical). Between two GPUI dumps, a sprite's atlas tile (`tile`) is not compared: rasterizing other glyphs moves the tiles of the later ones without changing what is drawn (the pixels are compared on their own).
2. **Original against patched.** All scenarios and behaviour logs are rendered with the pristine and the patched builds. A scenario no deviation declares must be byte identical (PNG and JSON). In a declared scenario, every pixel outside the declared rectangles must be identical, and the scene dump must be identical once the declared primitives are removed from both. Any other difference fails, naming the deviation, the differing pixels (count, bounding box, samples) and primitives.
3. **Deviations alone and together.** Each patch is also built alone (`only-DEV-nnn`, pristine plus that patch) and checked against its own declaration, so two patches cannot hide each other's side effects. With several deviations, the full patched build must differ from the pristine one only inside the union of the declarations, and inside the regions declared by a single deviation it must equal that deviation's own build.
4. **Original test suites.** The original projects' own tests that cover the patched files (`reference/deviations/tests.json`: `cargo test -p gpui-component --lib`, gpui-kit's `ui` and `integration` tests; when a gpui-pre crate is patched, all the gpui-kit suites built against each mode's copy of the gpui-pre crates, since gpui-pre's own lib tests cannot be built from the published crate) run on the pristine and on the patched copies and must pass the same set of tests, except tests listed in a declaration's `tests_changed` with the reason.
5. **Patch hygiene.** Patches must apply to the pinned pristine sources without offset or fuzz; the patched copy must differ from the sources in exactly the files the patches name (a copy that differs otherwise, a stale or edited file, fails); every patch needs a declaration and an entry here naming both files, and every entry needs a patch; the size of each patch is reported. `node reference/verify-deviations.js static` (also run by `test/golden/run-golden.sh`) checks the bookkeeping and that the truth of every declared scenario is still the verified patched render (it fails if someone regenerated it with the pristine harness).
6. **Port side.** `node reference/verify-deviations.js port` runs each declared defect metric on the port capture and on the patched truth (must pass, so the fix cannot silently revert) and on the original render (must still show the defect), and checks that the port scene equals the original scene outside the declared primitives, with the same outer bounds of the changed element.

## Entries

### DEV-001: icon Badge ring lets the badge color leak around it

- **Component.** gpui-kit `Badge` with `.icon(...)` (`crates/component/src/badge.rs`, `impl RenderOnce for Badge`, `BadgeVariant::Icon` branch). Port: `runtime/src/gpui/component/badge/Badge.hx` (`Badge.render`, `Icon` branch).
- **Defect.** The icon badge is a colored disc with `.border_1().border_color(theme.background)`: a ring in the page color that cuts the disc out of what lies below (the bell icon in the scenario). GPUI's `Style::paint` paints the background as one quad before the children and the border as another quad after them, both on the same outer edge, each antialiased on its own. An edge pixel with coverage `c` gets `ring * c + disc * c(1 - c) + below * (1 - c)^2` instead of `ring * c + below * (1 - c)`: a fringe of the disc color outside the ring.
- **Proof.** `test/golden/gpui-original/kit-badges-dark.png`, pixel (527, 42) is (26, 63, 39), green tinted, outside the ring that should only mix the page (10, 10, 10) and the white bell. Largest chroma (max minus min channel) of the pixels at 14.75 to 17 device pixels from the disc center (the ring and its outer edge, which should be achromatic): 37 in dark, 35 in light (`kit-badges-light.png`, (197, 232, 210) at the same pixel). The port had the same fringe.
- **Fix.** The ring is the padding of a disc in the page color, around an inner disc in the badge color: `.bg(theme.background).p(px(1.))` with a child `h_flex().size_full().justify_center().items_center().rounded_full_style(cx).bg(color).child(icon)`. Same layout (a 1px border and a 1px padding take the same room), same look (the inner disc edge sits where the inner border edge was), and no two shapes share an edge. A single quad with background and border is not possible from a gpui-kit element, since GPUI's `Div` always paints the border as a separate quad.
- **Reference patch.** `reference/deviations/DEV-001.patch` (gpui-kit, 1 file, +17 -3 lines), declaration `reference/deviations/DEV-001.json`.
- **Scope.** `kit-badges-dark`, `kit-badges-light`: pixels and primitives inside the badge bounds (520, 40, 32, 32). `story-badge` (the gallery page, added later): its two icon badges, (464, 802, 32, 32) and (592, 802, 32, 32), with the same change. The badge disc quad keeps its bounds; the border quad (order 5) is replaced by the inner disc quad (28 x 28 at 522, 42, order 4) and the icon sprite moves from order 4 to 5. 124 pixels change in each scenario. Every other scenario and behaviour log is byte identical.
- **Result.** Largest chroma around the ring: 0 on the patched truth and on the port (check threshold 4, original at least 20). The port matches the patched truth: `compare-scene.js` exact (272 primitives), `compare.js` within the documented SVG icon tolerance (the only differing pixels are the bell and check icons, lunasvg versus resvg).
- **Same pattern elsewhere.** gpui-kit `BubbleReactions` (`crates/component/src/bubble.rs`) draws its reaction pill with `.border_3().border_color(background).bg(muted)`, the same cutout. Not patched yet: bubble is not ported and no scenario renders it, so the defect is not proven there. To do when bubble is ported, with a scenario and a measurement.
- **Upstream.** Not reported yet.
- **Captures** (`node reference/deviation-captures.js DEV-001`; columns: original, patched original, port; x8):

  ![DEV-001 light](docs/deviations/DEV-001/icon-badge-light.png)
  ![DEV-001 dark](docs/deviations/DEV-001/icon-badge-dark.png)

### DEV-002: a rounded background no longer leaks through the edge of its opaque border

- **Component.** GPUI core: `Style::paint` (`gpui-pre` `src/style.rs`), used by every `Div` and `Canvas`. Port: `runtime/src/gpui/Style.hx` (`Style.paintBackground`, new `Style.backgroundUnderBorder`).
- **Defect.** `Style::paint` paints the background as one quad before the children and the border as another quad after them, both on the same outer edge and each antialiased on its own. On a rounded edge, a pixel with coverage `c` gets `border * c + background * c(1 - c) + below * (1 - c)^2` instead of `border * c + below * (1 - c)`: a fringe of the background color outside the border (the DEV-001 defect, in GPUI itself).
- **Proof.** Metric `edge-fringe` (largest distance, max channel, of an outer edge pixel of the corner arcs to the mix of the border color and the color 2.5 px further out): `kit-tooltips-light` Tooltip view (near black surface, light gray border, white page) 50 levels, pixel (267, 804) is (179, 179, 179) where the border/page mix allows (229..238); `kit-tooltips-dark` 45; `div-decorations` green card on the gradient 28 (top left and bottom right corners); `overflow-clip` card 9. Renders: `test/golden/gpui-original/<scenario>.png`.
- **Fix.** When the background is a solid color and the border is solid, opaque (color and element opacity), of one width on every side and the element is rounded, the background quad is inset by half the border width, rounded down to whole device pixels, and its corner radii are reduced by the same amount. Its antialiased edge then lies where the border is fully opaque, so the outer edge only mixes the border and what lies below. Everything else keeps the original bounds: translucent, dashed or uneven borders, gradients and patterns, square elements (their edges are on whole device pixels, no conflation), borders thinner than 2 device pixels (no room under them). Paint order, layout, children, shadows and hit testing do not change.
- **Reference patch.** `reference/deviations/DEV-002.patch` (gpui-pre, 1 file, +71 -2 lines), declaration `reference/deviations/DEV-002.json`.
- **Scope.** Generated from the pristine dumps by `reference/deviations/DEV-002-scope.js` (the rule of the patch applied to the pristine scene, never derived from the patched output; with `--with-others`, also to the renders of each other deviation alone, since DEV-002 applies to the elements they move or resize, such as the DEV-010 menus): 241 scenarios since the story gallery pages, the DEV-010 to DEV-015 scenes and DEV-016's `kit-input-scroll-follow` (was 158) (the 42 of the wave 1 to 5 components listed below, plus the wave 6 to 10 scenes with rounded bordered fields: inputs, textareas, number and OTP inputs, input groups, select, combobox, command palette, date and time pickers, color picker, form and settings, pagination, data table, light and dark, and their behaviour scripts), with `div-decorations`, `overflow-clip`, `kit-buttons`, `kit-button-states`, `kit-badges`, `kit-avatars`, `kit-checks`, `kit-toggles`, `kit-controls-script`, `kit-alerts`, `kit-text`, `kit-popovers`, `kit-tooltips`, `kit-overlays-script`, `kit-dialogs`, `kit-dialog-stack`, `kit-alert-dialogs`, `kit-modals-script`, `kit-notifications`, `kit-notifications-expanded`, `kit-dropdowns`, `kit-menus-script`, light and dark. Per element, the allowed primitive is its background quad only (rule on the element bounds with `edge_tolerance` the inset and `borderless`), and the allowed pixels are its four corner squares. GPUI's bounds tree gives a primitive the order 1 + the highest order of the earlier primitives it overlaps: a primitive whose clipped bounds touch only the outer band of such a background can get a lower order, and so can a primitive whose highest overlapped order came only from such a primitive (the focus ring strips of an OTP box, then the border strips of the box drawn over them). Those 173 primitives are declared `order_only` (every other field must stay equal). Every other scenario is byte identical.
- **Tests changed.** gpui-kit's `dialog::dialog::tests::closing_fades_the_dialog_surface` fails on the patched copy: its probe reads the quads whose bounds equal the dialog bounds within 1 device pixel, and under the 1px border at scale 2 the background is inset by exactly 1 device pixel, so it only finds the transparent border quad (alpha 0). The dialog still fades. The port's copy of the test accepts the inset background and passes. Declared in `tests_changed`.
- **Result.** `edge-fringe` on the patched truth and on the port: `kit-tooltips-light` 0, `kit-tooltips-dark` 0 (were 50 and 45), `div-decorations` 7 (was 28; the rest is the gradient below varying across 2.5 px), `overflow-clip` 1 (was 9).
- **Same pattern elsewhere, not fixed.** Elements outside the rule keep the fringe: the red card of `div-decorations` (border widths 2, 8, 16, 4, uneven radii), dashed borders (`example-hello-world`, `borders`; the dash gaps show the background on purpose, so an inset background would change the look), gradient backgrounds. Avatars in an `AvatarGroup` overlap their neighbours, so their edge metric is not meaningful; their pixels changed only in the corner squares.
- **Upstream.** Not reported yet.
- **Captures** (columns: original, patched original, port):

  ![DEV-002 tooltip light](docs/deviations/DEV-002/tooltip-light.png)
  ![DEV-002 tooltip dark](docs/deviations/DEV-002/tooltip-dark.png)
  ![DEV-002 div-decorations](docs/deviations/DEV-002/div-decorations-card.png)
  ![DEV-002 overflow-clip](docs/deviations/DEV-002/overflow-clip-corner.png)

### DEV-003: an icon Button with a dropdown caret no longer clips its caret

- **Component.** gpui-kit `Button` (`crates/component/src/button/button.rs`, `impl RenderOnce for Button`, icon button sizing). Port: `runtime/src/gpui/component/button/Button.hx` (`Button.render`).
- **Defect.** A button without label nor children is sized as a square of its icon size (`size_6` for `small()`), even when `dropdown_caret(true)` adds a caret after the icon: the caret is laid out outside the square and clipped by the content's `overflow_hidden`.
- **Proof.** `kit-buttons-light` and `-dark`, row 6, last button (`i-caret-only`, ghost, small, Ellipsis icon): the button is 48 x 48 device pixels (710..758), the caret sprite is at 746..774, so only a sliver of it shows. Metric `ink-deficit` on the place of the caret in the fixed layout (762, 432, 28, 48): 0 ink pixels of the 40 required (deficit 40).
- **Fix.** An icon with a dropdown caret is sized like a normal button (the `else` branch: `h_6().px_2()` for small), the way gpui-kit already sizes a label with a caret. A caret alone (the DropdownButton's caret half) keeps the square.
- **Reference patch.** `reference/deviations/DEV-003.patch` (gpui-kit, 1 file, +6 -1 lines), declaration `reference/deviations/DEV-003.json`.
- **Scope.** `kit-buttons-light`, `kit-buttons-dark`: pixels and quads and sprites inside (690, 420, 130, 72); 248 pixels change in each. Every other scenario is byte identical (no other scenario renders an icon button with a caret).
- **Result.** `ink-deficit` 0 on the patched truth and on the port (62 ink pixels in light), 40 on the original. The button is 96 device pixels wide (710..806) and shows the whole caret.
- **Upstream.** Not reported yet.
- **Captures** (columns: original, patched original, port; x6):

  ![DEV-003 light](docs/deviations/DEV-003/caret-only-light.png)
  ![DEV-003 dark](docs/deviations/DEV-003/caret-only-dark.png)

### DEV-004: Infer sizing of a horizontal VirtualList takes the known height

- **Component.** gpui-base `VirtualList` (`crates/base/src/virtual_list.rs`, `request_layout`, `ListSizingBehavior::Infer` measure, horizontal axis), re-exported by gpui-component. Port: `runtime/src/gpui/base/VirtualList.hx` (`VirtualList.requestLayout`).
- **Defect.** On the horizontal axis the measure sets `size.height = known_dimensions.width.unwrap_or(...)`: a list with a known width and no known height becomes as high as it is wide, whatever the available height.
- **Proof.** New scenario `kit-virtual-list-infer-light` / `-dark` (`reference/src/kit_scenes4.rs`, `test/golden/src/KitScenarios4.hx`): two `h_virtual_list(...).with_sizing_behavior(Infer).w(...).h_auto()` (the list is `size_full` by default) of widths 120 and 300 in a row 100 px high with `items_start`. The original makes them 120 and 300 px high, overflowing the row. Metric `ink-count` (pixels of the list background below the row, region (26, 230, 864, 400)): 246240.
- **Fix.** Read `known_dimensions.height` (as the vertical axis does for its height): the lists take the definite available height of the row, 98 px.
- **Reference patch.** `reference/deviations/DEV-004.patch` (gpui-kit, 1 file, +3 -1 lines), declaration `reference/deviations/DEV-004.json`.
- **Scope.** `kit-virtual-list-infer-light`, `-dark` only: the two list quads and their items (whose content mask is the list bounds), and the pixels below the row. Every other scenario is byte identical (no other scenario uses `Infer` on a horizontal list).
- **Result.** `ink-count` 0 on the patched truth and on the port.
- **Upstream.** Not reported yet.
- **Captures** (columns: original, patched original, port; x0.5, nearest):

  ![DEV-004 light](docs/deviations/DEV-004/infer-light.png)
  ![DEV-004 dark](docs/deviations/DEV-004/infer-dark.png)

### DEV-005: a disabled solid Secondary Button fades like the other neutral variants

- **Component.** gpui-kit `ButtonVariant::disabled` (`crates/component/src/button/button.rs`). Port: `runtime/src/gpui/component/button/Button.hx` (`ButtonVariantTools.disabled`).
- **Defect.** The disabled style of a solid Secondary button uses `button_secondary.background.opacity(1.5)` for its background and `button_secondary.opacity(1.5)` for its border. `opacity` clamps its factor to 1, so the call has no effect: the disabled button keeps the enabled background, and only its label fades.
- **Proof.** Scenario `kit-button-states-light` / `-dark` (`reference/src/kit_scenes3.rs`: each solid variant enabled, then disabled). The disabled Secondary background is (229, 229, 229) in light and (38, 38, 38) in dark, exactly the enabled one, while every other variant fades. Metric `page-contrast` (largest channel distance between the fill at (196, 56) and the page at (180, 56)): 26 in light, 28 in dark, the same as the enabled button.
- **Decision.** The intended value is not known (1.5 is not a valid factor). The owner chose 0.5 on 2026-10-29: gpui-kit fades the colored variants to 0.15 and the neutral ones (Default, every outline button) to 0.5, and Secondary is a neutral gray. 0.15 makes the light gray almost vanish on the page ((251, 251, 251) in light).
- **Fix.** `opacity(0.5)` for the background and the border of a disabled solid Secondary button: (242, 242, 242) in light, (24, 24, 24) in dark.
- **Reference patch.** `reference/deviations/DEV-005.patch` (gpui-kit, 1 file, +4 -2 lines), declaration `reference/deviations/DEV-005.json`.
- **Scope.** `kit-button-states-light`, `-dark`: the background quad of the disabled Secondary button and its pixels, (186, 22, 160, 68). No other scenario renders a disabled solid Secondary button.
- **Result.** `page-contrast` on the patched truth and on the port: 13 in light, 14 in dark (were 26 and 28).
- **Upstream.** Not reported yet.
- **Captures** (columns: original, patched original, port; x2):

  ![DEV-005 light](docs/deviations/DEV-005/disabled-secondary-light.png)
  ![DEV-005 dark](docs/deviations/DEV-005/disabled-secondary-dark.png)

### DEV-006: Combobox shows its localized default placeholder, not the raw key

- **Component.** gpui-kit `ComboboxState::default_trigger_body` (`crates/component/src/combobox.rs`). Port: `runtime/src/gpui/component/combobox/ComboboxState.hx` (`ComboboxState.defaultTriggerBody`).
- **Defect.** An unset placeholder falls back to `t!("Combobox.placeholder")`, but `locales/ui.yml` names the key `ComboBox.placeholder` (as `ComboBox.search_placeholder` and `ComboBox.empty`, which the same file reads correctly). `rust_i18n` returns a missing key as is, so the trigger shows "Combobox.placeholder".
- **Proof.** `test/golden/gpui-original/kit-combobox-light.png`, slot L0: the trigger reads "Combobox.placeholder" (glyphs from x 47 to 354). Metric `ink-count` (placeholder ink past the end of "Please select", region (232, 40, 130, 36)): 960 in `kit-combobox-light`, `-dark`, `kit-combobox-mouse` and `kit-combobox-search-typing`.
- **Fix.** Read `ComboBox.placeholder`: "Please select" (and its translations), like Select.
- **Reference patch.** `reference/deviations/DEV-006.patch` (gpui-kit, 1 file, +3 -1 lines), declaration `reference/deviations/DEV-006.json`.
- **Scope.** The placeholder glyphs of the first combobox in `kit-combobox-light`, `-dark`, `kit-combobox-search-typing` (40, 36, 330, 40) and `kit-combobox-mouse` (540, 36, 330, 40): about 3440 pixels each. Every other scenario is byte identical. The other glyphs of these dumps keep their bounds and content but take other atlas tiles (`tile` is not compared between two GPUI dumps, see "Safeguards").
- **Result.** `ink-count` 0 on the patched truth and on the port (960 on the original).
- **Upstream.** Not reported yet.
- **Captures** (columns: original, patched original, port; x2):

  ![DEV-006 light](docs/deviations/DEV-006/placeholder-light.png)
  ![DEV-006 dark](docs/deviations/DEV-006/placeholder-dark.png)

### DEV-007: the NumberInput placeholder is used

- **Component.** gpui-kit `NumberInput` (`crates/component/src/input/number_input.rs`, `impl RenderOnce for NumberInput`). Port: `runtime/src/gpui/component/input/NumberInput.hx` (`NumberInput.render`).
- **Defect.** `NumberInput::placeholder` stores its text in a field that `render` never reads, so the placeholder never shows.
- **Proof.** `test/golden/gpui-original/kit-number-otp-light.png`: the empty NumberInput at (12, 12) 238 x 32 built with `.placeholder("Quantity")` shows no text. Metric `ink-deficit` (ink in the middle of the field (200, 36, 124, 44), 100 pixels required): 100 (no ink) in light and dark.
- **Fix.** `render` passes a non-empty placeholder to the input state (`set_placeholder`, only when it differs, since it notifies), as Command and List do for their query inputs. Without a placeholder on the element, the state keeps its own.
- **Reference patch.** `reference/deviations/DEV-007.patch` (gpui-kit, 1 file, +10 lines), declaration `reference/deviations/DEV-007.json`.
- **Scope.** `kit-number-otp-light`, `-dark`: the placeholder glyphs (200, 36, 124, 44), 1032 pixels. Every other scenario is byte identical.
- **Result.** `ink-deficit` 0 on the patched truth and on the port (876 ink pixels: the muted, centered "Quantity").
- **Upstream.** Not reported yet.
- **Captures** (columns: original, patched original, port; x2):

  ![DEV-007 light](docs/deviations/DEV-007/placeholder-light.png)
  ![DEV-007 dark](docs/deviations/DEV-007/placeholder-dark.png)

### DEV-008: Accordion on_toggle_click is reported by the item that toggled

- **Component.** gpui-kit `Accordion` (`crates/component/src/accordion.rs`, `impl RenderOnce for Accordion`). Port: `runtime/src/gpui/component/accordion/Accordion.hx` (`Accordion.render`).
- **Defect.** The group callback is an `on_click` on the accordion root: it fires for any click inside it (the content of an open item, a disabled item) and reports the open list unchanged.
- **Proof.** `test/golden/gpui-original/kit-accordion-script.json`: the click on the disabled "Locked" item logs `toggle []` while the open list stays `[]`. Metric `unchanged-events` (toggle reports in a step that leaves the open list as it was): 1.
- **Fix.** Each item's own toggle callback (only set on enabled items) updates the open list, then calls the group callback with it. The root `on_click` is gone. The list still comes from a `HashSet` (its order is not specified; the scene sorts it).
- **Reference patch.** `reference/deviations/DEV-008.patch` (gpui-kit, 1 file, +11 -11 lines), declaration `reference/deviations/DEV-008.json`.
- **Scope.** Behaviour log of `kit-accordion-script` only (declared in `behaviours`: the patched log is the original minus the `toggle [...]` line of that click). Its render, its dump and every other scenario are byte identical.
- **Result.** `unchanged-events` 0 on the patched truth and on the port.
- **Upstream.** Not reported yet.
- **Captures** (log excerpts, columns: original, patched original, port):

  ![DEV-008 log](docs/deviations/DEV-008/toggle-log.png)

### DEV-009: InputEvent::Change only when the value changed

- **Component.** gpui-base `InputBaseState::replace_text_in_range` (`crates/base/src/input/base/state.rs`, single-line path). Port: `runtime/src/gpui/base/input/InputBaseState.hx` (`InputBaseState.replaceTextInRange`).
- **Defect.** The single-line path emits `InputEvent::Change` at its end whatever happened to the text: a newline typed in a single-line input (dropped by the normalization), a character rejected by the mask, or an IME commit of the text already marked all report a change of a value that did not change.
- **Proof.** Behaviour logs of the original (`test/golden/gpui-original/`): `kit-input-typing`, `event A Change` after `enter` and `shift-enter` with the value unchanged; `kit-input-ime`, 2 such events; `kit-input-mask`, field B logs 10 Change events for the 10 typed characters of which the mask keeps 7, field C 15 for 14 changes. Metrics: `unchanged-events` 2 (typing) and 2 (IME); `log-count` 10 (B) and 15 (C).
- **Fix.** Emit `Change` only when the text differs from the text before the edit (`self.text != old_text`). Everything else (history, cursor, highlighter, `on_text_typed`) is unchanged.
- **Reference patch.** `reference/deviations/DEV-009.patch` (gpui-kit, 1 file, +4 -1 lines), declaration `reference/deviations/DEV-009.json`.
- **Scope.** Behaviour logs of `kit-input-typing`, `kit-input-ime` and `kit-input-mask` (declared in `behaviours`: only `event X Change` lines are removed). Their renders and every other scenario are byte identical. gpui-kit's own test suites pass the same tests on the pristine and patched copies.
- **Result.** On the patched truth and on the port: `unchanged-events` 0 and 0, `log-count` 7 (B) and 14 (C).
- **Upstream.** Not reported yet.
- **Captures** (log excerpts, columns: original, patched original, port):

  ![DEV-009 typing](docs/deviations/DEV-009/typing-enter-log.png)
  ![DEV-009 mask](docs/deviations/DEV-009/mask-log.png)

### DEV-010: Select and Combobox with a width size and place their menu from the trigger

- **Component.** gpui-kit `SelectState` and `ComboboxState` (`crates/component/src/select.rs`, `crates/component/src/combobox.rs`, `impl Render`). Port: `runtime/src/gpui/component/select/SelectState.hx`, `runtime/src/gpui/component/combobox/ComboboxState.hx` (`render`).
- **Defect.** The style given to the element (`.w(px(160.))`) goes to the trigger, but the menu (`menu_width` Auto) is sized and placed from the bounds of the `relative()` wrapper around the trigger, measured with `on_prepaint`. The wrapper is a block child of a `size_full()` div, so it spans the parent. Combobox also tests a press against those bounds in `dismiss`, so a press right of the trigger counted as a press on it.
- **Proof.** `kit-select-width-light` / `-dark` and the new scene `kit-combobox-width-light` / `-dark` (`reference/src/kit_scenes6_combobox.rs`, `test/golden/src/KitScenarios6Combobox.hx`: the same layout with a Combobox): a 976 device pixels wide menu under a 320 device pixels wide trigger. Metric `ink-count` (menu pixels right of the trigger, region (400, 104, 600, 310), delta 8): 36052 and 36068 (Select), 36052 and 36068 (Combobox).
- **Fix.** The wrapper measures its first child, the trigger, with GPUI's `Div::on_children_prepainted` (the child's layout bounds: its border box) instead of itself with `on_prepaint`. Moving the `on_prepaint` canvas into the trigger would measure its padding box (an absolute child is laid out inside the 1 px border): 1 px off in place and 2 px narrower. With the fix the menu is exactly as wide as the trigger and starts at its left edge (both 320 device pixels at x 24). The `ElementExt` import, no longer used, is dropped.
- **Reference patch.** `reference/deviations/DEV-010.patch` (gpui-kit, 2 files, +24 -6 lines), declaration `reference/deviations/DEV-010.json`.
- **Scope.** `kit-select-width` and `kit-combobox-width`, light and dark: the menu primitives (shadows, quads, sprites) and pixels in (0, 94, 1024, 360). Every other scenario is byte identical. The menu has a rounded opaque border, so DEV-002 insets its background: DEV-002's scope generator now also applies its rule to the renders of the other deviations alone (`--with-others`), so the corners of the menu at its new size are declared too.
- **Result.** `ink-count` 0 on the patched truth and on the port.
- **Upstream.** Not reported yet.
- **Captures** (columns: original, patched original, port; x0.5):

  ![DEV-010 select light](docs/deviations/DEV-010/select-width-light.png)
  ![DEV-010 select dark](docs/deviations/DEV-010/select-width-dark.png)
  ![DEV-010 combobox light](docs/deviations/DEV-010/combobox-width-light.png)

### DEV-011: the ColorPicker trigger and tooltip show the rounded hex

- **Component.** gpui-kit `ColorPicker` (`crates/component/src/color_picker.rs`: `impl RenderOnce for ColorPicker`, tooltip title; `ColorPickerButton::render_field`, hex text). Port: `runtime/src/gpui/component/colorpicker/ColorPicker.hx` (`ColorPicker.render`, `ColorPickerButton.renderField`, new `ColorPicker.displayHex`).
- **Defect.** The trigger and its tooltip format the color with `Colorize::to_hex`, which truncates the channels, while the hex field of the popup uses gpui-base's `hex_string`, which rounds them: the same teal reads `#28A3A3` on the trigger and `#29A3A3` in the field.
- **Proof.** `test/golden/gpui-original/kit-color-picker-light.png` (ColorSelect triggers of the right column) and `kit-color-picker-select-light.png`: `#28A3A3`; the field of `kit-color-picker-script` reads `#29A3A3` for the same value. Metric `ink-count` (the lower left bowl of the third character, an 8 where the rounded hex has a 9, region (630, 58, 3, 2), or (130, 58, 3, 2) in the select scene, delta 64): 6 in each of the four renders.
- **Fix.** A private `display_hex` with the rounding of `hex_string` (duplicated: gpui-base keeps it private) formats the trigger text and the tooltip title. `Colorize::to_hex` is unchanged: it is a theme API whose own tests assert truncated values, and it also builds element ids.
- **Reference patch.** `reference/deviations/DEV-011.patch` (gpui-kit, 1 file, +26 -2 lines), declaration `reference/deviations/DEV-011.json`.
- **Scope.** `kit-color-picker-light`, `-dark` (the hex glyphs of the right column, (580, 40, 180, 545)) and `kit-color-picker-select-light`, `-dark` ((110, 40, 120, 30)): pixels and glyph sprites. The glyphs keep their bounds (an 8 and a 9 are as wide), only their atlas tiles change; the translucent value reads `#E052A780` instead of `#E051A77F`. Every other scenario is byte identical (the script's log formats the value with `to_hex` itself).
- **Result.** `ink-count` 0 on the patched truth and on the port.
- **Upstream.** Not reported yet.
- **Captures** (columns: original, patched original, port; x3):

  ![DEV-011 light](docs/deviations/DEV-011/hex-light.png)
  ![DEV-011 dark](docs/deviations/DEV-011/hex-dark.png)

### DEV-012: the Calendar year page follows the current year

- **Component.** gpui-base `CalendarState` (`crates/base/src/calendar.rs`). Port: `runtime/src/gpui/base/Calendar.hx` (`CalendarState`).
- **Defect.** The year view shows the page of `year_page`, which is computed only when the year range is set (`apply_year_range`), from the current year at that time. `set_date` / `apply_date`, `prev_month` / `next_month` across a year and `select_year` change the current year but never the page: with `year_range(2000, 2026)` set while the current year is still the wall clock's (outside the range, so page 0), a date in 2025 opens the year view on 2000 to 2019, without the selected year.
- **Proof.** New scene `kit-calendar-year-page-light` / `-dark` (`reference/src/kit_scenes6_time.rs`, `test/golden/src/KitScenarios6Time.hx`): two year views with `year_range(2000, 2026)`, one with the date 2025-03-14, one with 2019-12-10 moved to January 2020 by `next_month`. The original shows 2000 to 2019 in both. Metric `ink-count` (years of a third and fourth row, regions (40, 310, 440, 110) and (544, 310, 440, 110), delta 32): 4886 and 4886 in light, 4884 and 4884 in dark.
- **Fix.** One private `sync_year_page` (the page lookup of `apply_year_range`, which now calls it) called wherever `current_year` changes: `apply_date`, `prev_month` and `next_month` when they cross a year, `select_year`. Paging by the user (`prev_year_page`, `next_year_page`) is kept until the current year changes.
- **Reference patch.** `reference/deviations/DEV-012.patch` (gpui-kit, 1 file, +10 lines), declaration `reference/deviations/DEV-012.json`.
- **Scope.** `kit-calendar-year-page-light`, `-dark`: the two calendars (0, 0, 1024, 560). `kit-calendar-script`: its render, log and primitives are unchanged (its year view already pages to 2020 to 2025 before picking 2021), only the atlas tiles of the glyphs move (the first year view rasterizes other years); declared with no region. Every other scenario is byte identical.
- **Result.** `ink-count` 0 on the patched truth and on the port: both calendars show 2020 to 2025.
- **Upstream.** Not reported yet.
- **Captures** (columns: original, patched original, port; x0.5):

  ![DEV-012 light](docs/deviations/DEV-012/year-page-light.png)
  ![DEV-012 dark](docs/deviations/DEV-012/year-page-dark.png)

### DEV-013: an icon-only Tab keeps its intended width

- **Component.** gpui-kit `Tab` (`crates/component/src/tab/tab.rs`, `impl RenderOnce for Tab`, inner box of an icon-only tab). Port: `runtime/src/gpui/component/tab/Tab.hx` (`Tab.render`).
- **Defect.** The inner box of every tab gets `flex_1()` (grow 1, basis 0), and an icon-only one also `w(inner_height * 1.25)`. In the tab, which sizes to its content, the zero basis wins: the box shrinks to the icon and the width is ignored.
- **Proof.** `test/golden/gpui-original/kit-tabs-content-light.png`: the selected Segmented icon tab's indicator is 16 px wide instead of 30, and the icon tabs of the bar and of the small Outline row are crowded. Metric `ink-deficit` (the fourth icon of the Segmented icon bar where 30 px tabs put it, region (236, 136, 34, 34), 100 ink pixels required): 100 in light and dark.
- **Fix.** `flex_none()` on the inner box of an icon-only tab, so the 1.25 ratio applies (30 px for a Segmented tab of the default size). Labelled tabs are unchanged.
- **Reference patch.** `reference/deviations/DEV-013.patch` (gpui-kit, 1 file, +4 lines), declaration `reference/deviations/DEV-013.json`.
- **Scope.** `kit-tabs-content-light`, `-dark`: the tab bars of the left column (16, 116, 270, 550). Every other scenario is byte identical.
- **Result.** `ink-deficit` 0 on the patched truth and on the port.
- **Upstream.** Not reported yet.
- **Captures** (columns: original, patched original, port):

  ![DEV-013 light](docs/deviations/DEV-013/icon-tabs-light.png)
  ![DEV-013 dark](docs/deviations/DEV-013/icon-tabs-dark.png)

### DEV-014: no sliding indicator under a disabled selected Tab

- **Component.** gpui-kit `TabBar` and `Tab` (`crates/component/src/tab/tab_bar.rs`, `impl RenderOnce for TabBar`; `crates/component/src/tab/tab.rs`, `impl RenderOnce for Tab`). Port: `runtime/src/gpui/component/tab/TabBar.hx`, `runtime/src/gpui/component/tab/Tab.hx` (`render`).
- **Defect.** The TabBar draws its sliding indicator under the selected tab even when that tab is disabled. A disabled selected Pill tab then shows the full strength indicator under its own 0.5 primary background, against the comment in `Tab::render` ("a disabled-selected tab keeps its dimmed styling instead of the full-strength indicator color"); a disabled selected Segmented tab shows the raised indicator and loses its own inner background (made transparent for every tab while the indicator is active); a disabled selected Underline tab hides the indicator under its own gray bottom border.
- **Proof.** `test/golden/gpui-original/kit-tabs-light.png`, right column (disabled selected tabs). Metric `page-contrast` (the Pill fill at (890, 247) against the page at (860, 247)): 232 in light, 240 in dark (the black or white indicator).
- **Fix.** The TabBar does not draw its indicator when the selected tab is disabled, and such a tab keeps its own inner background, so it paints its own selected style from `TabVariant::disabled(selected = true)` in every variant: Pill a 0.5 primary fill, Segmented a plain background box without shadow, Underline its gray bottom border. Enabled tabs are unchanged.
- **Reference patch.** `reference/deviations/DEV-014.patch` (gpui-kit, 2 files, +15 -1 lines), declaration `reference/deviations/DEV-014.json`.
- **Scope.** `kit-tabs-light`, `-dark`: the right column (800, 200, 190, 300). Every other scenario is byte identical.
- **Result.** `page-contrast` on the patched truth and on the port: 116 in light, 120 in dark.
- **Upstream.** Not reported yet.
- **Captures** (columns: original, patched original, port; x2):

  ![DEV-014 light](docs/deviations/DEV-014/disabled-selected-light.png)
  ![DEV-014 dark](docs/deviations/DEV-014/disabled-selected-dark.png)

### DEV-015: typing over a selection undoes in one step

- **Component.** gpui-base input (`crates/base/src/input/base/state.rs`, `InputBaseState::push_history`; `crates/base/src/input/base/undo_manager.rs`, `is_adjacent`). Port: `runtime/src/gpui/base/input/InputBaseState.hx` (`pushHistory`), `runtime/src/gpui/base/input/UndoManager.hx` (`isAdjacent`).
- **Defect.** A character typed over the selection is recorded as an `Atomic` edit, and an atomic transaction ends coalescing, so the typing that follows is a separate undo step: "new" typed over "one to" undoes to "n", then to "one to". macOS text fields (and TextEdit, VS Code) undo the replacement and the typing that follows at once. The owner chose the single undo on 2026-10-31.
- **Proof.** Behaviour log `test/golden/gpui-original/kit-input-undo.json`: after `> type "new"` over the selected "one to", the first `> key cmd-z` leaves `A value="n"`. Metric `log-count` (state lines `A value="n"`): 1.
- **Fix.** In `push_history`, an unlabelled edit that replaces exactly the selection with one character (no line break) is a `Typing` edit, recorded after a coalescing boundary (`break_transaction_coalescing`): it starts a new typing run, and nothing ends it. In `is_adjacent`, a `Typing` change may follow a change that replaced text (the merge of a run already keeps the replaced text and its range, so undo restores it). Pastes, cuts, multi-character IME commits and multi-cursor edits keep their intent.
- **Reference patch.** `reference/deviations/DEV-015.patch` (gpui-kit, 2 files, +18 -2 lines), declaration `reference/deviations/DEV-015.json`.
- **Scope.** Behaviour log of `kit-input-undo` (declared with `log_changed`: from `> type "new"` on, the `A value=` and `event A Change` lines may differ; the steps and everything before stay identical), and its final render (one undo less: the field text and caret, (40, 30, 770, 50)). Every other scenario is byte identical. `verify-deviations.js` gained the `log_changed` rule for this.
- **Tests changed.** gpui-kit's `input::state::tests::test_undo_manager_selected_replacement_is_atomic` asserts the two-step undo (X typed over a selected b, then z: undo to "aXc", then "abc"); on the patched copy the first undo gives "abc". Declared in `tests_changed`. Every other test of the gpui-kit suites passes the same on both copies (@TESTS@). The port's copy of that test asserts the one-step undo.
- **Result.** `log-count` 0 on the patched truth and on the port: the first undo restores "one to" with its selection.
- **Upstream.** Not reported yet.
- **Captures** (log excerpts, columns: original, patched original, port):

  ![DEV-015 log](docs/deviations/DEV-015/undo-log.png)

### DEV-016: an input that only moved does not notify its view

- **Component.** gpui-base input (`crates/base/src/input/base/element.rs`, `impl Element for TextElement`, `paint`, and a new `only_moved`). Port: `runtime/src/gpui/base/input/TextElement.hx` (`TextElement.paint`, new `TextElement.onlyMoved`).
- **Defect.** At the end of `paint`, the input stores its geometry in its state (`last_bounds`, `input_bounds`, `last_layout` with the caret bounds, `scroll_size`) and calls `cx.notify()` when any of it changed (`element.rs:3519-3539`). These are window positions, so a scrolled page changes them on every frame for every input it shows. A notify sent during a draw requests no frame (`WindowInvalidator::invalidate_view`, `window.rs:178`): it marks the input view and all its ancestors dirty, and the next frame, whatever causes it, renders them again instead of reusing them from the view cache. The owner chose on 2026-11-01 to drop that notify when only the position changed, as long as rendering, caret, selection, completion popup and IME stay as expected.
- **What the notify serves.** Each consumer of that geometry, read from the code:
  - The input's own render and layout read only sizes: the scrollbar (`scroll_size`, the input size), auto grow (`last_layout`), the wrap width (`set_input_bounds` notifies on its own when the width changes), the resize reveal of the caret (`layout_cursors`, size and line height). A move changes none of them.
  - The caret, the selection and the search matches are laid out in `prepaint` from the current bounds and painted in the same frame.
  - The completion and code action menus are placed in their deferred prepaint from `prepaint_caret_geometry`, stashed by the input's prepaint of the same frame (`caret_anchored.rs`): current position without a re-render.
  - The IME: the window registers `ElementInputHandler::new(bounds, state)` in every `paint`, and `bounds_for_range` reads `last_bounds` when the platform asks (gpui-kit never calls `invalidate_character_coordinates`). Mouse selection, touch handles, auto scroll and the context menu read `last_bounds` and `input_bounds` when the event comes.
  - The hover and diagnostic popovers (`hover_popover.rs`, `Popover::request_layout`) read `range_to_bounds`, which adds `last_bounds.origin`, while they lay out: in a frame where the input moved, they use the position of the previous paint, and only the next frame (the one the notify dirties the views for) places them at the input. These keep gpui-kit's behaviour: the input still notifies when it moved while a hover or diagnostic popover is shown.
  - Code outside gpui-kit that reads `cursor_layout()`, `text_bounds()`, `input_bounds()` or `range_to_bounds()` while it renders gets the moved position on its next render instead of a forced one. gpui-kit itself has no such reader besides the two popovers (its tests do it after a draw).
- **Proof.** New scenario `kit-input-scroll-follow` (`reference/src/kit_scenes13_input_scroll.rs`, `test/golden/src/KitScenarios13InputScroll.hx`): a page with a cached sidebar view S and a scrolled column of cached field views (F1: Input A, F2: Input B, F3: Editor C with a completion provider), their renders logged during the scroll phases, driven without refresh like `view-cache`. Three phases scroll the page by wheel steps while A shows IME marked text, B a selection and C its open completion menu. After each scroll a frame caused by S alone (`> notify S`) renders F1, F2 and F3 again in the original. Metric `log-count-in-steps` (lines `F1 render` to `F3 render` inside the `> notify S` steps): 18 on the original. Bench `gallery-input-scroll` (the gallery's Input page, 40 inputs, a 30 px wheel step per frame), cached mode: the input views are dirty on every frame.
- **Fix.** `paint` still stores the whole geometry; it skips the notify when the geometry only moved: same size of the text bounds and of the input bounds, same scroll size and line height, the text bounds and the caret at the same offset from the input bounds (within 0.01 px, the float rounding of a translation), and no hover or diagnostic popover shown. Any other change notifies as before (resize, caret or text moved inside the input, inner scroll, first paint).
- **Reference patch.** `reference/deviations/DEV-016.patch` (gpui-kit, 1 file, +48 -1 lines), declaration `reference/deviations/DEV-016.json`.
- **Scope.** Behaviour log of `kit-input-scroll-follow` only (declared in `behaviours`: the patched log is the original minus 18 `F1 render` to `F3 render` lines). Every state line is identical: page scroll, input bounds, caret, IME bounds (`bounds_for_range` of the marked range), selection bounds, completion popup origin, after every step. Its render and scene dump and every other scenario and behaviour log are byte identical in the original and the patched builds (the deviation shows only in the number of renders). The scenario joins DEV-002's generated scope (the input backgrounds under their 1 px borders). gpui-kit's own test suites pass the same tests on both copies (no test asserts the notify of a moved input).
- **Result.** `log-count-in-steps` 0 on the patched truth and on the port. Bench `gallery-input-scroll`, cached mode (the app's mode), 200 frames, median of 3 runs, median / p99 frame time in ms: node 5.85 / 10.65 before, 3.04 / 5.92 after; native default build 4.62 / 7.22 before, 2.94 / 4.40 after (9.6 to 6.2 MB allocated per frame, 5200 to 4742 counted objects). Views rendered per frame stay 40: the port's default view caching still renders a view that moved, but in prepaint over its retained layout nodes, where a dirty view rendered and was laid out again. Full render mode unchanged (node 5.7 / 10.3, native 4.5 / 6.6).
- **Tests.** Port: `InputMoveNotifyTest` (`test/unit/src/tests/kit/`): the input views are not rendered again after a scroll (fails without the fix), they are after a resize, and while a hover popover is shown; caret, IME bounds, selection bounds and the completion popup move with the field over scroll steps, and every frame equals the frame of a window rendering every view.
- **Upstream.** Not reported yet.
- **Captures** (log excerpts and the final frame, columns: original, patched original, port):

  ![DEV-016 log](docs/deviations/DEV-016/render-log.png)
  ![DEV-016 frame](docs/deviations/DEV-016/scrolled-fields.png)

## Decision policy

Decided by the owner on 2026-10-29:
- A defect of the original that is **proven by a render of the original** and has an **obvious fix** is fixed directly, as a new entry, without asking first.
- When the intent of the original is ambiguous (for example a value that has no effect and whose intended value is unknown), the owner decides before the fix.
- Every entry must be documented with **comparative captures**: crops of the affected region rendered by the original (pristine), by the patched original and by the port, side by side and zoomed, stored in `docs/deviations/DEV-nnn/` and shown in the entry, plus the numbers of the defect metric before and after.

The captures are built by `node reference/deviation-captures.js [DEV-nnn...]` from the `captures` of each declaration (scenario, device pixel region, zoom), nearest neighbour, with the columns always in this order and labelled: `ORIGINAL` (`test/golden/gpui-original/`), `PATCHED` (`test/golden/gpui/`), `PORT` (`test/golden/captured/`). A candidate uses `--spec reference/deviations/candidates/<name>.json`, whose captures name their own columns.

## Candidates awaiting a decision

Defects found in the original but not fixed yet. Each needs the owner's decision before becoming an entry (with proof, patch, declaration and port change).

- **GPUI `on_hover` keeps a single listener** (only a `debug_assert` guards it): a gpui-kit component Button with both `on_hover` and a tooltip silently loses its own `on_hover` in release builds (found by reading the code, reproduced by the port, no render proof yet).

- **gpui-kit editor with tab size 0 panics** (code reading only, no render proof yet): `crates/base/src/input/editor/indent.rs:138` iterates `(0..indent_count).step_by(tab_size.tab_size)`, and `step_by(0)` panics; `set_tab_size` accepts 0 (`indent.rs:510`) and indent guides are on by default for the code editor (`mode.rs:84`). The port throws at the same place. To prove with a scene when the code editor is ported (wave 11).
- **similar 2.7.0: diffs of two empty sequences panic in the utils** (proven by a reference run of the original crate, 16 recorded cases): the LCS diff of two empty sequences yields an empty `Delete` op, and `utils::diff_words`, `diff_chars` and the other helpers then panic with "slice out of bounds". The port throws the same error; gpui-kit is not affected (it uses Myers and `TextDiff` directly).
- **gpui-kit syntect backend scope rules** (code reading, proven by `HighlighterTest.testScopesMapByTheSyntectBackendRules`): in `semantic_name`, every `storage.type...` scope contains "type", so the `"type"` branch never runs (`int`, `bool` come out as keywords, against the code's own comment), and `is("meta")` is checked first, so the `meta.preprocessor`, `meta.function-call` and `meta.mapping.key` branches never run. Only visible with highlighting, which the reference has no truth for (the port's highlighter is an addition).
- **gpui-kit without tree-sitter: transparent diagnostic colors and ignored theme keys** (`wasm_stub.rs`): `StatusColors` returns transparent black, so diagnostics are invisible in syntect and wasm builds; the stub `HighlightThemeStyle` has no serde renames, so the dotted `editor.*` theme keys and `comment.doc` are ignored; the stub `SyntaxHighlighter::language()` returns an empty string. The port reproduces the reference build.
- **gpui-kit Accordion open indices come from a `HashSet`**: the list passed to `on_toggle_click` has a random order per process (the port keeps the opening order; the scenes sort it). Not a visible defect; the toggle reports themselves are fixed by DEV-008.
- **gpui-kit Stepper separator, vertical with `text_center`, uses `mx` instead of `my`** (`stepper/item.rs`), which also overrides its `ml` (code reading only).
- **gpui-kit ColorPicker::anchor() is never used** (code reading only).
- **gpui-kit Settings: no active item in the sidebar when the default selection is a group of a closed page** (minor UX): `default_selected_index` on such a group leaves the page item inactive and the group items hidden. Proof: `test/golden/gpui/kit-settings-small-light.png`.

## Checked, not deviations

The audit of the same defect class (two separately antialiased shapes sharing an edge) over every current scenario and the ported components (`runtime/src/gpui/component`, `runtime/src/gpui/base`):

- **GPUI core, `Div` with a background and a border of another color**: fixed by DEV-002 for rounded elements with a solid background and a solid, opaque border of one width. Left as in the original: dashed borders (`example-hello-world`, `borders`: the dash gaps show the background on purpose), borders of different widths per side (the red card of `div-decorations`), gradient backgrounds and translucent borders (see DEV-002).
- **Tags, outline badges, avatars without a status ring** (`Tag`, `Avatar`, `AvatarGroup`): background and border of the same or a close color, so the conflation only makes the edge a little more opaque (no foreign color). Not a defect.
- **Overlays of fills sharing a rounded corner** (progress fill over its track, nested rounded fills): no pair of quads with different bounds shares a rounded corner in the current scenarios.
- **Images with rounded corners** (`images`, `kit-avatars`): no image shares its edge with a quad below it (avatar images are inset by the border).
- **Focus rings** (`focus-ring`): drawn around the element with an offset, no shared edge.
