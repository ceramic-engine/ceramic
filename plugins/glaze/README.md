# ceramic-gpui

Haxe port of [GPUI](https://github.com/zed-industries/zed/tree/main/crates/gpui) (Zed's UI framework) as a Ceramic plugin, as a foundation to port [gpui-kit](https://github.com/longbridge/gpui-kit) on top of it.

## Layout

| Path | Content |
|---|---|
| `ceramic.yml` | Plugin declaration (`gpui`) |
| `runtime/src/gpui/` | The GPUI port |
| `runtime/src/ceramic/GpuiPlugin.hx` | Runtime entry point (`pluginInit()`) |
| `tools/src/tools/GpuiPlugin.hx` | Tools entry point (required for Ceramic to register an external plugin) |
| `samples/basic/` | Minimal Ceramic app using the plugin |
| `samples/kit/` | Gallery of the gpui-kit components ported so far (`t` toggles the dark theme) |
| `samples/textfield/` | GPUI's `examples/input.rs`: a text field with IME, selection and clipboard (`shared/textfield/TextInput.hx`) |
| `samples/gpui-examples/` | GPUI's own examples ported line by line (`hello_world`, `uniform_list`, `text_wrapper`, `tab_stop`, `drag_drop`, `shadow`, `animation`) and pages of gpui-kit's base showcase (`shared/examples`), switched with the left / right arrows |
| `test/unit/` | Unit tests, run headless with Node |
| `test/golden/` | Golden-image tests, run with clay web under the Electron runner |
| `test/bench/` | View caching benchmark (Node and native) |
| `reference/` | Rust harness rendering the same scenarios with the original GPUI |
| `gpui-kit/`, `gpui-src/` | Reference sources (ignored by git) |

Projects in this repository use the plugin through a `plugins/gpui.plugin` file containing a path relative to the project root. To use it from another project, add a `plugins/gpui.plugin` file pointing to this directory, then add `gpui` to `app.plugins` in its `ceramic.yml`.

## UI API

The API follows GPUI and gpui-kit with camelCase names (`div().flex().gap2().child(...)`, see `PORTING.md`). One convenience goes beyond Rust: `child(null)` is accepted and does nothing, exactly as if `child()` had not been called, and `children([...])` skips its null entries. This works for a literal `null` and for a null element, string, view, entity or component, on every element and gpui-kit component with `child` / `children` (and the appenders like `StatusBar.left` / `right` or `Toolbar.content`), so `div().child(cond ? a : null)` builds a conditional child. Order, layout and element ids are the same as in the tree built without the nulls. Rust passes an `Option` through `children` or `when_some` instead (`whenSome` in the port).

## Input, interactivity and focus

Windows receive Ceramic input through `gpui.GpuiInput` (created on demand,
`bindInput: false` in `WindowOptions` opts out): mouse, wheel and keyboard
events become GPUI `PlatformInput` (`MouseDownEvent`, `ScrollEvent`,
`KeyDownEvent`...), in window coordinates (`renderable.screenToVisual`),
routed to the window under the pointer (or the window the button was pressed
on) and, for keys, to the active window (the last one clicked). Cursor styles
are applied to `screen.cursor`. Tests and tools can also inject events with
`window.dispatchEvent(event)` and `window.dispatchKeystroke(Keystroke.parse("ctrl-k"))`.

`Div` has GPUI's `InteractiveElement` / `StatefulInteractiveElement` methods:
`onClick`, `onMouseDown`, `hover(s -> s.bg(...))`, `active`, `groupHover`,
`overflowYScroll` + `trackScroll(ScrollHandle)`, `onDrag` / `dragOver` /
`onDrop`, `tooltip`, `trackFocus(FocusHandle)`, `tabIndex`, `tabGroup`,
`keyContext("Editor")`, `onAction(MyAction, ...)`, `onKeyDown`... Key
bindings go through `app.bindKeys([new KeyBinding("ctrl-k ctrl-c", new MyAction(), "Editor")])`,
actions are classes declared with `@:action(namespace = editor) class MyAction implements Action {}`.
Animations: `div().withAnimation(id, new Animation(0.3), (div, t) -> ...)` and `withSpring`.

## Unit tests

```sh
cd test/unit
ceramic headless run node --setup --assets
```

The process exits with a non-zero code if any test fails. Run a subset with `GPUI_TEST_FILTER=SomeTest ceramic headless run node`. Test classes are registered in `test/unit/src/Tests.hx`.

## Golden-image tests

```sh
cd test/golden
./run-golden.sh                 # capture every scenario listed in scenarios.txt
./run-golden.sh smoke           # or only some of them
CERAMIC_PATH=../../../ceramic node compare.js            # compare captures with their expected images
node compare-scene.js                                    # compare the scene primitives with GPUI's dumps
node compare-cache.js                                    # view cache equivalence of every scenario
CERAMIC_PATH=../../../ceramic node compare.js --update   # bless baselines of non GPUI scenarios only
```

Expected images:

- `test/golden/gpui/<id>.png` (and `<id>.json`, the dump of the scene primitives) are rendered by the **original GPUI** through `reference/`. For every scenario that has one, it is the only truth: the port must match it, and `--update` refuses to replace it with a capture of the port. The only allowed differences with the original are the fixes listed in [DEVIATIONS.md](DEVIATIONS.md), so the truths are rendered by the original **with those fixes applied as patches**: regenerate them with `reference/verify-deviations.sh --update-truths` (which also keeps the unpatched renders of the affected scenarios in `test/golden/gpui-original/` as proof of each defect), or render one new scenario with `cd reference && ./apply-deviations.sh patched --build`, then `vendor/patched/bin/gpui-reference --scenario <id> --out ../test/golden/gpui/<id>.png --json ../test/golden/gpui/<id>.json` (run from `vendor/patched/harness`, or with absolute paths). A plain `cargo run` in `reference/` builds against the unmodified gpui-kit: it renders anywhere else, but refuses to write into `test/golden/gpui/` (only the patched build may) or `test/golden/gpui-original/` (only the pristine build may). `node reference/verify-deviations.js port` checks the fixes on the port captures.

To see the original, the patched original and the port side by side for every scenario, run `node reference/triptychs.js` (or give it scenario ids): it writes `test/golden/triptychs/<id>.png` (columns ORIGINAL, PATCHED, PORT, each labelled with how it compares with the column on its left) and an `index.html`. The ORIGINAL column comes from the pristine build of the latest complete safeguard run (`reference/vendor/runs/<date>`), and the script checks that each truth is that run's patched render, so the three columns always come from the builds they claim.
- `test/golden/golden/<id>.png` are only for scenarios that don't involve GPUI rendering (harness checks: `smoke`, `color-check`).

Captures are written by the app itself with `screen.toPng()` (exact pixels); the Electron window capture is color managed and must not be used for comparisons.

`compare.js` tolerates 12 levels per channel on 0.2% of the pixels by default, and applies stricter or documented per scenario rules (`RULES`): text and paths must be identical, images exact (one .5 tie of a grayscale conversion excepted), SVG icons and SVG images keep a documented tolerance (lunasvg versus resvg antialiasing). `compare-scene.js` compares every primitive with an epsilon of 1e-3 and no other tolerance. The reasons and measurements are in `reference/SCENARIOS.md`. Text is compared with GPUI rasterizing glyphs unhinted, like on macOS (see `reference/README.md`), and the port's monochrome sprites follow GPUI's Metal shader by default (no text gamma or contrast correction).

## Comparison with the original GPUI

`reference/` renders the same scenarios with the original GPUI (gpui-pre 0.3.10, Metal offscreen on macOS) and compares them with the Ceramic captures:

```sh
cd reference
cargo run --release -- --all --out-dir ../test/golden/gpui                          # versioned GPUI truth
CERAMIC_PATH=../../ceramic node compare.js --ceramic-dir ../test/golden/captured   # per region report
```

GPUI's own examples are validated the same way: `reference/src/examples` holds verbatim copies of the Rust examples (only their entry point replaced), rendered by the original GPUI at their own window size with scripted inputs, and `test/golden` renders the Haxe ports (`samples/gpui-examples/shared/examples`) with the same scripts. Their scene dumps carry the behaviour log (steps, state, what the example prints), compared line by line by `compare-scene.js`. They match GPUI exactly (pixels, primitives and logs), see "GPUI examples" in `reference/SCENARIOS.md`. To try the examples:

```sh
cd samples/gpui-examples
ceramic clay run web           # or: ceramic clay build mac
GPUI_EXAMPLE=tab_stop project/mac/gpuiexamples.app/Contents/MacOS/gpuiexamples   # native: start with another example
```

Behaviour scenarios (`mouse-dispatch`, `drag-drop`, `scroll-wheel`, `focus-tab`, `key-actions`, `tooltip`, `text-input`, `view-cache`, `effects-order`) log the handlers GPUI runs for a scripted input sequence (`test/golden/gpui/<id>.json`); unit tests replay the same scripts on the port and require identical logs. See `reference/SCENARIOS.md`.

Scenarios are listed in `test/golden/scenarios.txt` and built in `test/golden/src/Scenarios.hx`. Running `ceramic clay run web --debug` in `test/golden` opens a live window where scenarios can be switched with the left / right arrow keys.

## View caching and performance

Like GPUI, `entity.cached(style)` (or `anyView.cached(style)`) embeds a view
whose prepaint and paint are reused from the previous frame while it is not
dirty and its bounds, content mask and text style are unchanged: hitboxes,
dispatch nodes, listeners, tooltips, deferred draws, tab stops, input
handlers, element states, line layouts and the scene paint operations are
replayed (`Window.reusePrepaint` / `reusePaint`, `Scene.replay`).

On top of that, every view is cached by default (`WindowOptions.viewCaching`,
`Window.defaultViewCaching`), without a style: thanks to tracker, a view is
dirty only when an observable field it read changed, when it was notified, or
when one of its descendant views is dirty. A clean view retains its taffy
layout subtree (laid out again from taffy's cache, so it gets exactly the
layout it would get by rendering), then reuses its prepaint and paint if its
context (bounds, content mask, text styles, rem size, opacity, group
hitboxes, image cache) did not change, or renders again in prepaint
otherwise. Clean descendants of a dirty view are reused too, and keep their
tracker bindings and element states. `view.uncached()` opts out,
`window.refresh()` renders everything, and an explicit `window.draw()` of a
window that is not dirty renders every view cached by default (like GPUI's
uncached views). `window.renderedViewCount` / `reusedViewCount` count them.

Caching never changes what is drawn: `test/unit/src/tests/ViewCacheTest.hx`
draws the same views in a window with view caching and in a window without
any view cache, through scripted and random sequences of changes (text,
layout shifts, hover, clicks, scrolling, lists, popovers, focus, opacity...),
and requires identical scene dumps and frame state; `test/golden` does the
same for every golden scenario (`node compare-cache.js`).

Benchmark (`test/bench`, 70 cards with text, icons, borders and shadows,
about 2000 elements, one observable field changed per frame):

```sh
cd test/bench
ceramic headless run node --setup --assets            # Node
ceramic clay build mac --setup --assets && project/mac/bench.app/Contents/MacOS/bench   # native
```

It prints the draw time, the views rendered and reused, and the objects
created per frame (`gpui.util.AllocationCounters`, enabled by the
`gpui_count_allocations` define) without and with view caching, then checks
that idle frames draw and allocate nothing.

## Text input, IME and clipboard

A view becomes editable by implementing `EntityInputHandler` (GPUI's text
input protocol, ranges in UTF-16 code units: `selectedTextRange`,
`markedTextRange`, `textForRange`, `replaceTextInRange`,
`replaceAndMarkTextInRange`, `unmarkText`, `boundsForRange`,
`characterIndexForPoint`; `paste`, `selectionBoundsForRange`,
`setSelectedTextRange`, `textLengthUtf16`, `acceptsTextInput`,
`textInputConfiguration` and `textInputEditableRange` have defaults added by a
macro) and registering it in paint, while focused:
`window.handleInput(focusHandle, new ElementInputHandler(bounds, view), cx)`.
Lower level handlers extend `InputHandler`. After app driven edits, call
`window.notifyTextInputChanged(focusHandle)` / `notifyTextSelectionChanged`.

Key dispatch follows GPUI: a key down that no binding or listener consumes
types its character (`window.dispatchKeystroke` inserts it like GPUI's test
platform), a printable key starting a multi-stroke binding waits for its
timeout and is then typed, and `KeyDownEvent.preferCharacterInput` (AltGr)
skips bindings when the focused input accepts text (`KeystrokeEvent.inputPreference`).

On Ceramic, `GpuiInput` gives each window a `TextInputBridge` (its
`window.textInputPlatform`), modeled on GPUI's web platform: when a focused
element registers an input handler accepting text, it starts Ceramic text
editing (`input.startTextEditing`) and stops it when that focus is lost;
`input.onTextCommit` becomes `replaceTextInRange(null, text)`,
`input.onTextComposition` becomes `replaceAndMarkTextInRange(null, text,
selection)` (an empty composition followed by a commit commits the marked
text, without a commit it is cancelled), the character of a key down that a
binding consumed is not typed, keys are left to the IME while composing, and
the IME candidate area follows `boundsForRange` (start of the marked text, or
the selection head).

Clipboard: `cx.writeToClipboard(ClipboardItem.newString(text))`,
`cx.readFromClipboard()` (`ClipboardItem`, string entries with optional
metadata, `text()`, `metadata()`), over Ceramic's clipboard by default
(`App.platformClipboard`, `CeramicClipboard`: text only, the metadata of the
last written item is kept while the clipboard holds its text), or an in memory
`TestClipboard`.

`samples/textfield` is GPUI's input example (typing, IME, mouse and keyboard
selection, copy / cut / paste), built only on these APIs.

## Text, SVG icons and paths

Strings are elements: `div().textColor(...).fontFamily("Inter").textSize(px(16)).lineHeight(px(24)).child("Hello")`. Text inherits the text style of its ancestors (`textColor`, `textSize`, `textXs`...`text3xl`, `fontFamily`, `fontWeight`, `italic`, `lineHeight`, `textLeft` / `textCenter` / `textRight`, `whitespaceNowrap`, `truncate`, `textEllipsis`, `lineClamp(n)`, `underline`, `lineThrough`, `textBg`, `textDecorationWavy`...), wraps at the width it gets from the layout and is laid out like GPUI's text element. `new StyledText(text).withHighlights([new TextHighlight(start, end, {color: red(), fontWeight: FontWeight.BOLD})])` styles UTF-8 byte ranges on top of the inherited style (`withDefaultHighlights`, `withRuns`, `withFontFamilyOverrides` too); its `layout()` (`TextLayout`) maps positions and indices (`indexForPosition`, `positionForIndex`, `lineLayoutForIndex`, `wrappedText`). `new InteractiveText(id, styledText).onClick(ranges, (rangeIx, window, cx) -> ...)` adds clicks, hover and tooltips on ranges. `text("...")` gives a `Text` an id derived from its call site.

Fonts: the plugin bundles Inter and JetBrains Mono (SIL Open Font License 1.1, `assets/gpui/fonts`) and adds them to `App.defaultTextSystem()` with the default assets (define `gpui_no_default_fonts` to skip). `.SystemUIFont`, the default family, is Inter. Add other fonts with `cx.textSystem().addFonts([bytes])` (TTF, OTF or collections); only the faces you add can be requested by family, and the face closest to the requested weight and style is used (no synthetic bold or italic). On native desktop targets (mac, Windows, Linux), characters that no added face covers (CJK ideographs, kana, hangul, symbols) fall back on the fonts of the operating system, read on first use through `ceramic.Files` (`gpui.platform.SystemFontFallback`: Hiragino Sans GB, Heiti, Hiragino Sans, Apple SD Gothic Neo, SF, Menlo, Apple Symbols on macOS; Microsoft YaHei, JhengHei, Yu Gothic, Malgun Gothic, Segoe UI Symbol on Windows; Noto Sans CJK, WenQuanYi, DejaVu, Noto Sans Symbols on Linux; `cjkLocale` picks the Han font); define `gpui_no_system_fonts` to keep the added fonts only. On native desktop targets, color emoji come from the emoji font of the system (Apple Color Emoji, Segoe UI Emoji, Noto Color Emoji), read piece by piece on first use. Bundled emoji font (opt-in): with the define `gpui_bundled_emoji`, the plugin ships Noto Color Emoji (10.7 MB, `CBDT` bitmap build; SIL Open Font License 1.1 for the font, Apache License 2.0 for the images, see `emoji-font/README.md`) and adds it to `App.defaultTextSystem()` once the default assets are loaded (`gpui.platform.BundledEmojiFont`), so emoji look the same on every target: it comes first for emoji, and the system emoji font (native) or the browser canvas (web) only supply the graphemes it lacks (CJK keeps its own policy). Native targets read only its tables at startup (about 95 KB) and the images of the emoji drawn; browsers download the whole file with the default assets. Without the define, nothing of it is compiled or shipped. In browsers (clay web, Electron), the port follows gpui-pre-web: no fonts of the system are read, and graphemes that no added face covers (or emoji without a color glyph) are measured and drawn by the browser with its own fonts on a Canvas2D (`OffscreenCanvas`), as alpha masks or, for emoji, color sprites (`gpui.platform.CanvasFallbackText`). The policy is GPUI's `CanvasFontFallback`: `Emoji` (the default, emoji only), `EmojiAndCjk` (also CJK ideographs, kana, hangul and CJK punctuation, drawn one grapheme at a time) or `Disabled`; set it with `(cast cx.textSystem().platformTextSystem : gpui.platform.CeramicTextSystem).canvasFontFallback = EmojiAndCjk` before laying out text (the story sample does). Define `gpui_no_canvas_fallback` to keep the added fonts only (the golden project does: its truths use Inter and JetBrains Mono only, with notdef boxes for CJK and emoji; the test projects also define `gpui_no_system_fonts`). Windows draw glyphs from their own sprite atlas (`window.spriteAtlas`, a `CeramicAtlas`); `window.textSystem()` is the per window `WindowTextSystem`, and `window.textPainter()` gives a `TextPainter` to paint `ShapedLine` / `WrappedLine` from a canvas.

`svg().path("icons/heart.svg").size(px(16)).textColor(color)` draws an SVG as a mask tinted by its own text color, rendered at twice its size by the Haxe port of lunasvg (`withTransformation(Transformation.rotated(...))`, `externalPath`, `data(bytes)`). Paths are loaded from the app's asset source (`cx.assetSource()`, by default `App.defaultAssetSource()`, relative to the project assets): call `App.defaultAssetSource().preload(paths, done)` before rendering on targets without synchronous file access (the web), or `add(path, bytes)`, or set your own `AssetSource` with `cx.setAssetSource(...)`. SVG `<text>` uses the fonts of the text system.

`window.paintPath(path, color)` paints a `Path` built with `PathBuilder.fill()` / `PathBuilder.stroke(width)` (`moveTo`, `lineTo`, `curveTo`, `cubicBezierTo`, `arcTo`, `addPolygon`, `close`, `dashArray`, `translate`, `scale`, `rotate`, then `build()`), or a raw `new Path(start)` with `lineTo` / `curveTo`. Paths are tessellated by a port of lyon (GPUI's tessellator) with its `f32` arithmetic, so their vertices are bit identical to GPUI's, and covered like GPUI's Metal renderer (4x MSAA sample positions, vertex snapping like the GPU, 8-bit samples resolved), into the sprite atlas. The second argument can be any `Background`: linear gradients (sRGB or Oklab) and the slash and checkerboard patterns are shaded per pixel like GPUI's Metal path shader, over the path bounds clipped by the content mask.

## Lists and anchored elements

`uniformList(id, itemCount, (start, end, window, cx) -> [...])` renders only the visible rows of a list whose rows all have the height of the first one (GPUI's `uniform_list`). Control it with a `UniformListScrollHandle` (`trackScroll(handle)`, `scrollToItem(ix, ScrollStrategy.Center)`, `scrollToItemStrict`, `scrollToItemWithOffset`, `scrollToBottom`), and tune it with `withSizingBehavior(Infer)`, `withHorizontalSizingBehavior(Unconstrained)`, `yFlipped(true)` and `withDecoration(...)`. `list(state, (ix, window, cx) -> ...)` (a `ListElement`) renders rows of variable height; its `ListState` (`new ListState(count, ListAlignment.Top, overdraw)`) lives on your view: `splice(start, end, count)`, `reset`, `remeasure`, `remeasureItems`, `scrollTo(new ListOffset(ix, offset))`, `scrollBy`, `scrollToRevealItem`, `scrollToEnd`, `setFollowMode(FollowMode.Tail)`, `logicalScrollTop()`, `boundsForItem(ix)`, `setScrollHandler` and the scrollbar helpers. Ranges are `start, end` arguments. `anchored()` positions popovers inside the window: `anchor(Anchor.TopRight)`, `position(point)`, `offset(point)`, `positionMode(AnchoredPositionMode.Local)`, `snapToWindow()`, `snapToWindowWithMargin(edges)` (the default switches the anchor corner on overflow); wrap it in `deferred(...)` to paint it on top.

## Images

`img(source)` (GPUI's `Img`) takes an `ImageSource`: a `String` (a path in the app's asset source, `App.assetSource()`, or a URI when it has a scheme), a `Resource` (`Embedded(path)`, `Path(file)`, `Uri(uri)`, see below), a `RenderImage`, an encoded `Image` (`Image.fromBytes(ImageFormat.Png, bytes)`), a `ceramic.Texture` (`ImageSource.Texture`, specific to the port) or a loading function. Resources and encoded images load asynchronously and redraw the view when ready: PNG, JPEG, GIF (first frame), BMP and WebP are decoded by the Ceramic backend into a texture backed image (`ImageAssetLoader.decodeToBytes = true` reads them back into BGRA bytes like GPUI), anything else is rendered as SVG. Style it with `objectFit(ObjectFit.Cover)` (`Fill`, `Contain`, the default, `Cover`, `ScaleDown`, `None`), `grayscale(true)`, `rounded(...)`, `withLoading(() -> element)` (shown after `Img.LOADING_DELAY`, 200ms) and `withFallback(() -> element)` (shown on error). Without a size it takes the size of the image and keeps its aspect ratio. Multi frame `RenderImage`s animate when the `img` has an `id`. Images are cached by the app (`ImageSource.removeAsset(cx)` drops one), or by an image cache: `imageCache(retainAll('id')).child(img(...))` or `imageCache(RetainAllImageCache.create(cx))`, or any `ImageCache` given to `img(...).imageCache(cache)`; `RetainAllImageCache.clear/remove` drop the images from the sprite atlas.

`Uri` images (`http://`, `https://`) are loaded like GPUI's `ImageAssetLoader`: a GET through the app's HTTP client (`cx.httpClient()`, `cx.setHttpClient(client)`, GPUI's `HttpClient`), following redirects; the format comes from the bytes (raster, otherwise SVG), whatever the URL or content type; a status outside 2xx fails with `ImageCacheError.BadStatus(uri, status, firstLineOfBody)`, a request that gets no response with `Other('loading image asset from "uri": cause')`, and `img()` shows its fallback. Loads are cached like other resources. The client comes from Ceramic's `http` plugin, which is optional: add `- http` to the app's plugins and an app of the Ceramic platform gets a `gpui.CeramicHttpClient` (requests through `ceramic.Http`: XMLHttpRequest on the web, Node's `http`/`https` on Node, `akifox-asynchttp` sockets with TLS on native), like a GPUI web app gets `FetchHttpClient`. Without the plugin (define `plugin_http` absent), the app keeps GPUI's `NullHttpClient` and `Uri` images fail with `No HttpClient available`. Apps on a test dispatcher keep `NullHttpClient` too; tests install `gpui.FakeHttpClient`. In browsers, the browser's rules apply as with gpui-pre-web's `fetch`: a cross-origin image is readable only when the server (and every redirect) sends CORS headers (`Access-Control-Allow-Origin`), otherwise the request fails and the fallback shows. `file://` URIs are read like paths.

## gpui-kit components

`gpui.base.*` (gpui-base) and `gpui.component.*` (gpui-component) port gpui-kit 0.8.1 on top of the GPUI port. Call `gpui.component.Component.init(cx)` at startup, then make a `gpui.base.Root` the root view of each window (`cx.newEntity(rootCx -> new Root(view, window, rootCx))`): its component plugin sets the rem size, font, background and text color from the theme. Components are builders like in Rust: `new Label('Name').secondary('(optional)')`, `Tag.primary().outline().child('New')`, `new Avatar().name('Jason Lee').large()`, `new Progress('upload').value(60.)`, `new Icon(IconName.Search).small()`; neutral helpers are static extensions (`using gpui.base.StyledExt;` for `hFlex()`, `fontMedium()`...). Controls (wave 3) are controlled: the application keeps the value and renders it back, e.g. `new Button('save').primary().icon(IconName.Plus).label('Save').onClick((_, _, _) -> save())`, `new Checkbox('remember').label('Remember me').checked(checked).onChange((next, _, _) -> checked = next)`, `new Switch('wifi').checked(on).onChange(...)`, `RadioGroup.horizontal('plan').selectedIndex(ix).child(Radio.labeled('Free'))...`, `new Toggle('bold').icon(IconName.Bell).checked(bold)`, `new ToggleGroup('align').segmented()`, `new ButtonGroup('size').child(...)`, `new Toolbar('tools').child(button).content(separator)`, and `new Slider(state)` over a `SliderState` entity (`cx.newEntity(_ -> new SliderState().step(10.).defaultValue(20.))`, emitting `SliderEvent.Change` / `Release`). The Switch lives in `gpui.component.switch_` (`switch` is a Haxe keyword). The unstyled behaviors are in `gpui.base` (`Button`, `Toggle`, `Checkbox`, `Radio`, `Switch`, `Slider`, `Toolbar`...), and expose what they would export to accessibility as an `a11y` record (no accesskit in the port). Their tooltips are managed tooltips (wave 5), and `DropdownButton` is in `gpui.component.button` (it needs the menus).

Scrolling (wave 4): `using gpui.component.scroll.Scrollable;` turns a `Div` into a scroll area with overlay scrollbars, `vFlex().h(px(300.)).overflowYScrollbar().children(rows)` (also `overflowXScrollbar`, `overflowScrollbar`, and `verticalScrollbar(handle)` / `scrollbar(handle, axis)` on an element you scroll yourself). The Base pieces are in `gpui.base`: `new Scrollbar(handle).axis(Vertical).mode(Always).styles(s -> s.thumb(t -> t.bg(color).width(6.)))` over any `ScrollbarHandle` (a `ScrollHandle`, `UniformListScrollHandle`, `ListState`, `VirtualListScrollHandle`, or your own `ScrollbarHandleImpl`), `ScrollBounce` (edge stretch and spring return), `ScrollableMask` (wheel routing between nested scrollers), `RoundedFrameCover`, `AutoScroll`, and `VirtualList.vVirtualList(entity, id, sizes, (view, start, end, window, cx) -> rows)` for rows (or columns) of different sizes. The scrollbar's mode, timing and colors come from the theme (`Theme.setScrollbarMode`). Times are read from `cx.backgroundExecutor().now()` (the original reads the wall clock for the scrollbar's idle hold), and touch drags of the thumb are not ported (no touch input).

Overlays (wave 5): `new Popover('id').trigger(new Button('open').label('Open')).anchor(Anchor.TopLeft).arrow(true).content((state, window, cx) -> ...)` (`gpui.component.popover`, also `defaultOpen`, `open` with `onOpenChange`, `overlayClosable`, `appearance`, `triggerStyle`, `trackFocus`; Escape and outside clicks dismiss it, the focus returns to the trigger), `new HoverCard('id').trigger(...).content(...)` (`gpui.component.hovercard`, open and close delays in seconds), and tooltips: `button.tooltip('Save')`, `tooltipWithAction`, `tooltipPlacement`, `tooltipShowDelay` (also on toggles, checkboxes, radios and switches), or `new Tooltip('text')` views (`gpui.component.tooltip`), shown by the window's tooltip overlay (`TooltipDefaults`: 500 ms show delay, 300 ms grace period). The unstyled pieces are in `gpui.base` (`Positioner`, `Popup`, `Popover`, `Tooltip`, `TooltipOverlay`, `HoverCard`).

Dialogs, sheets and notifications (wave 5): `using gpui.component.WindowExt;` adds the window helpers of the component root: `window.openDialog(cx, (dialog, window, cx) -> dialog.title('Edit').child(body).footer(new DialogFooter().child(new DialogClose().trigger(b -> b.label('Cancel'))).child(new DialogAction().child(new Button('ok').primary().label('OK')))))` (`gpui.component.dialog`: `DialogHeader`, `DialogTitle`, `DialogDescription`, `DialogContent`, stacked dialogs, overlay, escape and overlay clicks close, the focus stays inside and returns to its previous holder), `window.openAlertDialog(cx, (alert, _, _) -> alert.title('Delete?').description('...').confirm().okVariant(Danger))`, `window.openSheetAt(Placement.Right, cx, (sheet, _, _) -> sheet.title('Settings').size(px(240.)).child(body))` (or `openSheet`, on any side), `closeDialog`, `closeSheet`, and `window.pushNotification(new Notification().title('Saved').message('...').withType(Success), cx)` (`gpui.component.notification`: a stack per corner, autohide, hover expands it; `removeNotification`, `clearNotifications`). The unstyled pieces are in `gpui.base` (`Dialog`, `AlertDialog`, `Sheet`, `Toast`). Notifications are never posted to the operating system's notification center (the port has no API for it); their timing follows the executor clock, as in the original component (`background_executor().now()`).

Menus (wave 5, `gpui.component.menu`): `PopupMenu.build(window, cx, (menu, window, cx) -> menu.menu('Copy', new Copy()).separator().menuWithCheck('Wrap', true, new ToggleWrap()).submenu('Share', window, cx, (menu, _, _) -> ...))` (labels, icons, check items on either side, disabled items, links, custom element items, scrollable menus, shortcut hints from the keymap, keyboard navigation in the `PopupMenu` key context, actions dispatched through the trigger's ancestors), `using gpui.component.menu.ContextMenu.ContextMenuExt;` for `div().id('row').contextMenu((menu, window, cx) -> ...)` (right click), `using gpui.component.menu.DropdownMenu;` for `new Button('more').label('More').dropdownMenu(...)`, `new DropdownButton('save').button(new Button('save-action').label('Save')).dropdownMenu(...)` (split button), and `AppMenuBar.create(cx)`, which draws the menus set with `GlobalState.globalMut(cx).setAppMenus([new Menu('File').withItems([...]).owned()])` (GPUI's `Menu` / `MenuItem` / `OwnedMenu` data types, `gpui.Menu`). gpui-kit's `native_menu` (menus drawn by the operating system, with a drawn fallback on Linux) is not ported: the port has no platform menus, so applications use these drawn menus directly, and the app menu bar is always drawn in the window. Context menus do not open on a long press (no touch input).

Inputs (wave 6, `gpui.component.input`): keep the state on your view (`cx.newEntity(c -> new InputState(window, c).withPlaceholder('Search'))`) and render it with `new Input(state)`, with `.prefix(...)`, `.suffix(...)`, `.cleanable(true)`, `.maskToggle()`, `.disabled(true)`, `.readonly(true)` and the sizes. `withMaskPattern('(999)-999-9999')`, `withMasked(true)`, `withValidate`, `min` / `max` / `step` and `setValue` configure the state, which emits `InputEvent.Change`, `PressEnter`, `Focus` and `Blur`. `new Textarea(cx.newEntity(c -> new TextareaState(window, c).rows(4)))` (or `.autoGrow(1, 4)`) is the multi-line field, `new NumberInput(state)` adds step buttons and the up and down keys, `new OtpInput(cx.newEntity(c -> new OtpState(6, window, c))).groups(2)` takes a one-time code (`OtpEvent.Change` / `Complete`), and `new InputGroup('id').input(new Input(state)).addon(new InputGroupAddon('a').align(InlineEnd).child(new InputGroupButton('copy').icon(IconName.Copy)))` frames a control with addons. `window.focusedInput(cx)` (`using gpui.component.WindowExt;`) returns the input that holds the focus. Editing goes through the window's input handler, so IME composition, the clipboard and the macOS / Windows / Linux keymaps work as in gpui-kit. The code editor, its search panel and the native context menu come later.

Select (wave 6, `gpui.component.select`): keep `cx.newEntity(c -> new SelectState(new SearchableVec(['Rust', 'Go']), new IndexPath(0), window, c).searchable(true))` on your view and render `new Select(state)`, with `.placeholder(..)`, `.titlePrefix(..)`, `.cleanable(true)`, `.icon(..)`, `.menuWidth(..)`, `.menuMaxH(..)`, `.searchPlaceholder(..)`, `.appearance(false)`, `.disabled(true)` and the sizes. Grouped items use `SearchableVec.groups([new SelectGroup('Fruits').withItems([...])])`. The state emits `SelectEvent.Confirm(value)` and `DismissEvent`; `setSelectedValue`, `setSelectedIndex` and `setItems` drive it. The general `List` (`gpui.component.list`: `ListState` with a `ListDelegate`, `ListItem`) is available too.

Combobox and command palette (wave 6): `new Combobox(cx.newEntity(c -> new ComboboxState(new SearchableVec(['Rust', 'Go']), [], window, c).multiple(true).searchable(true))).placeholder('Pick').cleanable(true)` (`gpui.component.combobox`, emits `ComboboxEvent.Change` / `Confirm`; delegates in `gpui.component.searchablelist`: `SearchableVec`, `SearchableVec.groups([...])`, or your own `SearchableListDelegateBase`), and `new Command(cx.newEntity(c -> new CommandState(window, c))).group(new CommandGroup().label('Suggestions').item(new CommandItem().label('Calendar').icon(IconName.Calendar).action(new OpenCalendar())))` (`gpui.component.command`: filtering by label and keywords, keybinding hints, `onSelect` / `onConfirm` / `onQuery` / `onCancel`, header, footer, custom rows).

Time and color (wave 6): `new Calendar(cx.newEntity(c -> new CalendarState(window, c)))` (`.numberOfMonths(2)`, `.firstDayOfWeek(Mon)`, a `Matcher` for disabled dates), `new TimeField(state)` over a `TimeFieldState` (`.precision(Second)`, `.hourCycle(H12)`), `new DatePicker(state)` over a `DatePickerState` (or `DatePickerState.range`, with `.timePrecision`, `.presets([...])`, `.cleanable(true)`), and `new ColorPicker(state)` / `new ColorSelect(state)` over a `ColorPickerState` (palette and HSLA panels, hex field). Dates use `gpui.base.chrono` (`NaiveDate`, `NaiveTime`, `NaiveDateTime`); "today" comes from `Local`, which tests fix with `Local.fixAt`. The color picker's segmented tabs are `gpui.component.tab` (`TabBar`, `Tab`).

Forms and settings (wave 6): `Form.vForm()` / `Form.hForm()` with `Form.field().label(..).description(..).required(true).colSpan(2).child(control)`, `columns`, `labelWidth` and `footer`. `new Settings('id').pages([...])` builds a searchable settings window from `SettingPage` > `SettingGroup` > `SettingItem.create(title, SettingField.switch_ | checkbox | input | dropdown | numberInput | render(...))`, with `defaultValue` driving the page reset button. They are built on `gpui.component.sidebar.Sidebar`, `gpui.component.resizable.Resizable.hResizable` (base pieces in `gpui.base.resizable`) and GPUI's `containerQuery`.

Disclosure and navigation (wave 7): `new Accordion('faq').multiple(true).item(i -> i.title('General').open(open).child(body)).onToggleClick((open, _, _) -> ...)`, `new Collapsible().open(open).motionId('details').child(header).content(body)`, `new Pagination('pages').currentPage(p).totalPages(20).onClick((page, _, _) -> ...)` (`compact()`, `visiblePages(n)`, sizes), `new Stepper('wizard').selectedIndex(step).items([new StepperItem().child('Account')]).onClick(...)` (`vertical()`, `textCenter(true)`).

Tabs (wave 7, `gpui.component.tab`): `new TabBar('id').segmented()` (or `.pill()`, `.outline()`, `.underline()`, `.folder()`, `withVariant(..)`), `.selectedIndex(i)`, `.onClick((ix, window, cx) -> ...)`, `.children([new Tab().label('One'), Tab.fromIcon(new Icon(IconName.Inbox))])`, `.prefix`, `.suffix`, `.menu(true)` (overflow menu), `.maxWidth(px)`, `.trackScroll(handle)` and the sizes. Tabs take `.prefix`, `.suffix`, `.disabled`, `.ariaLabel` and the drag and drop listeners. The base pieces are `gpui.base.Tabs` and `BaseTab`.

Base dock (wave 7, `gpui.base.dock`): the layout tree (`PaneTree`), docks, tab groups, panels (`Panel` / `PanelBase`, registered with `PanelRegistry.registerPanel`), drag and drop of panels with split and merge, zoom, and persistence (`DockAreaState.toJson` / `fromJson`) that writes the same JSON as gpui-kit, so layouts saved by one load in the other. The styled dock is `gpui.component.dock` (`DockSkin`: tab groups with the component tab bar, panel title bars and toolbars, zoom and close buttons, dock collapse buttons, resize handles, drop placeholders; the panel presentation traits `Panel` / `PanelBase`, `PanelHandle`, `DockToggleEvent`, and the `ToggleZoom` / `ClosePanel` actions).

Tree and table (wave 8): `new Tree(cx.newEntity(c -> new TreeState(c).items([new TreeItem('src', 'src').expanded(true).child(...)])), (ix, entry, selected, window, cx) -> new ListItem(ix).child(entry.item().label))` (`gpui.component.tree`, with `.contextMenu(...)`; the state emits `TreeEvent.Expanded` / `Collapsed` and has `setSelectedItem`, `revealItem`, `scrollToItem`; the unstyled base is `gpui.base.Tree`). `new DataTable(cx.newEntity(c -> new TableState(delegate, window, c).cellSelectable(true)))` (`gpui.component.table`, with `.stripe`, `.bordered`, `.fixedColsBorder`, `.headerRowHeight`, `.scrollbarVisible` and the sizes): delegates extend `TableDelegateBase` (`columnsCount`, `rowsCount`, `column` with `new Column(key, name).withWidth(..).sortable().fixedLeft()`, `renderTd`, and optional sorting, column moves, groups, loading, load more, `fitColumn`); columns resize and reorder by drag, rows, columns and cells can be selected, and large tables are virtualized on both axes. The stateless `Table` / `TableHeader` / `TableBody` / `TableFooter` / `TableRow` / `TableHead` / `TableCell` / `TableCaption` lay out simple tables.

Charts (wave 9, `gpui.component.chart`): `new LineChart(data).x(d -> d.month).y(d -> d.value)` (`.linear()`, `.stepAfter()`, `.dot()`, `.yAxis(true)`, `.yDomain(min, max)`, `.referenceLine(v)`, `.pointCount(n)`); the same pattern builds `AreaChart`, `BarChart` (`.band`, `.value`, `.alignment(Left)`, `.label`, `.fill`, `.fillGradient`, `.valueAxis(true)`), `PieChart` (`.innerRadius`, `.padAngle`, `.label`), `RadarChart`, `CandlestickChart` and `SankeyChart`. Every chart has a hover tooltip and draws in on its first paint. The unstyled primitives are in `gpui.base.plot` (scales, shapes, `Grid`, `PlotAxis`, `PlotLabel`, `PathCaches`): extend `Plot` to write your own plot. Also `new ProgressCircle('id').value(60.)`.

Rich text (wave 10, `gpui.base.text`): `TextView.markdown('id', source)` / `TextView.html(...)`, or keep `cx.newEntity(c -> TextViewState.markdown(text, c))` on your view and render `TextView.create(state)` (`.selectable`, `.selectionFormat(Source)`, `.scrollable`, `.maxLines(n)`, `.onLinkClick`, `.codeBlockHighlighter`, `.withStyle(TextViewStyle...)`). Markdown (GFM, math, frontmatter, MDX constructs) is parsed with the `markdown` library (port of markdown-rs), HTML with `html5ever`. Stream with `state.pushStr` / `setText` (`new TextViewMotion().withStreamFade(0.3)` fades new text in), highlight ranges with `state.setRangeHighlights([...])` over `state.renderedText()`, scroll to them with `revealRange`. Text can be selected across views of a window (`TextSelection`: `selectedText`, `clear`; the base `Root` mounts the `TextSelectionLayer` and copies on cmd-c / ctrl-c); `SelectableText` is plain selectable text; external editors use `EditorHost.collectLeafGeometry`.

Component rich text and chat (wave 10): `gpui.component.text.TextView.markdown(id, source)` / `.html` / `.create(state)`, with `.withStyle(new TextViewStyle()...)`, `.streamFade(true)` and `.markdownPlugin(new FrontmatterPlugin())`; `Text` (a string or a text view) is accepted by Alert, Tooltip and DescriptionList. Chat: `new Message().avatar(..).header(new MessageHeader()..).content(new MessageContent().bubble(new Bubble().withVariant(Secondary).child(..))).footer(..)`, `BubbleReactions`, `new Attachment().id(..).status(Uploading).progress(40.).media(..).content(..)`, `AttachmentGroup`, and `new MessageScroller(id, cx.newEntity(c -> new MessageScrollerState(count, c)), (ix, window, cx) -> row)`. Dialogs and sheets confine text selection to their own scope and clear it when they open or close. Code blocks are not syntax highlighted yet (wave 11).

Code highlighting (wave 11, `gpui.component.highlighter`): complete TextMate grammars like VSCode, through the `textmate` (port of vscode-textmate) and `oniguruma` (port of Oniguruma) libraries, with 52 grammars of tm-grammars bundled in `assets/gpui/grammars`. It is off by default: call `Highlighter.enable(cx)` to turn it on (on the web, `Highlighter.preload(languages, done)` first). Editors re-highlight only the lines an edit changes, and text view code blocks are highlighted too. gpui-kit has no highlighting without its tree-sitter or syntect features, so this is an addition: every scene compared with gpui-kit renders without it, and its colors are validated token by token against vscode-textmate with gpui-kit's scope rules (`HighlighterTest`). On the web, the regex engine can be vscode-oniguruma's `onig.wasm` instead of the pure Haxe Oniguruma port (about twice as fast) with the `gpui_onig_wasm` define (opt-in). Web builds with the define get `onig.wasm` (462 KB) and its JavaScript binding `vscode-oniguruma.js` (20 KB) copied from `onig-wasm/` into `project/web` by a `begin build` hook (`ceramic gpui setup onig-wasm`), and load them with the default assets, so the engine is chosen before the app is ready. If loading fails, a warning is logged and the pure Haxe engine stays in use. Without the define, the hook removes the two files from `project/web` and none of this is compiled; native builds never ship them.

Code editor and diff (wave 11): `new Editor(cx.newEntity(c -> new EditorState(window, c).language('json')))` (`gpui.component.input`: line numbers, folding, indent guides, the search and replace panel, and `lsp()` providers for completion, inline completion, hover, definitions, code actions, document colors and semantic tokens, with their popovers). `gpui.component.diff.Diff` renders unified diffs, git conflicts and inline changes in unified or split views, with line and text selection, review annotations, decorations and gutter markers; it computes diffs with the `similar` library (port of the `similar` crate 2.7).

Questionnaire (wave 12): `gpui.base.questionnaire` (`QuestionnaireState` with its items, answers, validators, navigation and keyboard contract: letter shortcuts, arrows, Enter, cmd-Enter to submit, Backspace) and the styled `gpui.component.questionnaire.Questionnaire` (progress, item, title, description, choices, input, error, previous / skip / next / submit actions).

Carousel (wave 12, `gpui.component.carousel`): keep `cx.newEntity(_ -> new CarouselState(3).withAxis(Vertical).withLooping(true))` on your view and render `new Carousel('id', state).child(new CarouselContent(state).child(new CarouselItem('s0', 0, state).child(...))).child(new CarouselPrevious(state)).child(new CarouselNext(state)).child(new CarouselPagination().children([...]))`: arrow keys, Home and End, pointer drag with axis lock, wheel and trackpad snapping, looping; the state emits `CarouselEvent.Change(i)`. Element inspector (define `gpui_inspector`, GPUI's optional `inspector` feature): `window.toggleInspector(cx)` or cmd-alt-i after `Component.init`; pick with the mouse, change the depth with the wheel, and edit the picked element's style as Rust builder calls or JSON in gpui-kit's panel. Without the define the core compiles exactly as before. Golden: `GPUI_GOLDEN_VARIANT=gpui_inspector ./run-golden.sh`; reference: `GPUI_REFERENCE_FEATURES=inspector ./apply-deviations.sh patched --build`.

Story gallery (wave 13, `samples/story`): gpui-kit's story gallery ported to Haxe, runnable in clay web and native (`GPUI_STORY=<name>` opens one story). Every story page is a golden scenario `story-<name>`, rendered by the original story files compiled into the reference harness (`reference/src/story`, `reference/src/story_scenes_{a,b}.rs`; `test/golden/src/StoryScenarios{A,B}.hx`), and `story-gallery` is the whole gallery window. Not compared: `story-tree` (the original lists its working directory), `story-list` and `story-data-table` (random data), `story-date-picker` and `story-calendar` (they show the month of the wall clock "today", which gpui-kit reads with no way to inject it; `story-calendar` was removed on 2026-11-01 when the month changed) and `story-color-picker` (the original asks for the font family "monospace", which the harness cannot resolve); they are ported and listed in the gallery. `DropdownMenu` also works on `SidebarHeader` and `SidebarFooter` (`using gpui.component.sidebar.SidebarDropdownMenu;`).

Window chrome (wave 7): `new TitleBar().child(...)` and `WindowBorder.windowBorder().child(...)` follow `OperatingSystem.current` (macOS: traffic light padding; Windows and Linux: drawn controls; web: a plain bar). Native window operations (minimize, maximize, move, resize, window menu) go through `Window` and an optional `window.platformOperations`, since Ceramic does not expose them yet; fullscreen goes through Ceramic's `settings.fullscreen`.

Icons: the 106 default icons of gpui-kit (Lucide, ISC, some derived from Feather, MIT, plus a few gpui-kit icons) are bundled in `assets/icons` (license in `assets/icons/LICENSE-LUCIDE.txt`), and `IconName` is generated from that directory by a build macro (`IconName.ChevronDown` is `"icons/chevron-down.svg"`). On the web, call `IconName.preload(done)` before rendering icons. To embed more icons, copy SVG files from `gpui-kit/crates/assets/assets/icons` (the complete catalog of 1830 icons) into the plugin's `assets/icons` (they get an `IconName` variant) or into your project's assets and draw them with `Icon.empty().path("icons/name.svg")`.

## Running native apps without windows

Native test and sample runs must never put a window on screen. `test/unit` and `test/bench` define `clay_sdl_headless` (clay creates its SDL window hidden). To debug a native crash of any app without a visible window or a crash dialog: build it with `clay_sdl_headless` in its defines and `--debug`, then run it under lldb in batch mode, e.g. `lldb -b -o run -k "bt 30" -k quit -- <app>.app/Contents/MacOS/<app>`. Otherwise launch apps hidden with `open -g -j -W --stdout <log> --stderr <log> <app>.app`.
