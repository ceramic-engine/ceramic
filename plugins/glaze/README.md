# Glaze

Glaze is the UI framework of Ceramic. You describe an interface as a tree of elements and components, written in Haxe with chained calls; Glaze lays it out with flexbox, draws it with Ceramic, and redraws the parts that read a value when that value changes. It runs wherever Ceramic runs: desktop, web, mobile, Unity.

It is a Haxe port of [GPUI](https://github.com/zed-industries/zed/tree/main/crates/gpui), the framework behind the Zed editor (package `glaze`), and of [gpui-kit](https://github.com/longbridge/gpui-kit), its component library (package `glaze.kit`). GPUI is by Zed Industries and gpui-kit by Longbridge, both Apache-2.0; see [NOTICE.md](NOTICE.md).

## Setup

Enable the plugin in your project's `ceramic.yml`:

```yaml
app:
    plugins:
        - glaze
```

## A first interface

A `Glaze` is a Ceramic visual. Give it a component, size it, add it to your scene:

```haxe
import glaze.*;
import glaze.Prelude.*;

class MainScene extends ceramic.Scene {

    var ui:Glaze;

    override function create() {
        ui = new Glaze(Counter.component());
        ui.size(width, height);
        add(ui);
    }

    override function resize(width:Float, height:Float) {
        ui.size(width, height);
    }

}

class Counter extends Component {

    @observe var count:Int = 0;

    function render(window:Window, cx:App):IntoElement {
        return div().p4().textColor(hsla(0, 0, 0.9, 1)).fontFamily('Inter')
            .child(
                div().id('button').px3().py1().roundedMd().bg(hsla(0.6, 0.6, 0.5, 1))
                    .onClick(() -> count++)
                    .child('Clicked $count times')
            );
    }

}
```

`import glaze.Prelude.*;` brings in GPUI's free functions: the element constructors (`div()`, `svg()`, `img()`, `uniformList()`...), the units (`px()`, `rems()`, `relative()`) and the colors (`hsla()`, `rgb()`, `white()`...).

Three things happen here:

- **Elements** are built with chained calls: `div().p4().bg(...).child(...)`. The style methods follow Tailwind's names (`p4`, `px3`, `roundedMd`, `textSm`, `flex`, `gap2`...).
- **A component** is a class with a `render` method. `Counter.component()` places it in the tree.
- **Reactivity** comes from tracker: `count` is an `@observe` field, so the click changes it and the component is drawn again. The same goes for any `@observe` field of your own models read during `render`: no `notify`, no manual refresh.

`ui.window` is the GPUI window behind the visual. `Glaze.app` is the GPUI app context (the `cx` of the signatures), for calls made outside a render such as `Glaze.app.bindKeys([...])`.

## Components

A component reads your data and describes a piece of interface. Its `@prop` fields become chained setters, and `children` receives what the parent passes with `.child(...)`:

```haxe
class LabeledRow extends Component {

    @prop var label:String = '';

    function render(window:Window, cx:App):IntoElement {
        return div().flex().itemsCenter().gap4()
            .child(div().w(px(140)).textSm().child(label))
            .child(div().flex().itemsCenter().children(children));
    }

}

// In a parent's render
LabeledRow.component().label('Word wrap')
    .child(Switch.component('wrap').checked(prefs.wordWrap).onChange(on -> prefs.wordWrap = on))
```

Inside the class, a prop is read by its name (`label`). From outside, the field is `labelProp`; you rarely need it.

**Two kinds of components.** The class decides which one it is:

- **Props only:** the component is rebuilt on every render of its parent, like an element. Cheap, no state.
- **With state** (an `@observe`, `@compute` or `@autorun` field, an `init()` or `destroy()` method, or the `@persist` meta): the component is **persistent**. It is created on its first render, found again on the next ones, drawn again only when one of its props or an observable it reads changes, and destroyed when it leaves the tree.

A persistent component is found again by the position of its `component()` call in the code. In a loop, or when the same class is placed twice on one line, give each one a key:

```haxe
.children([for (file in files) FileRow.component().at(file.path).file(file)])
```

Lifecycle of a persistent component: its constructor runs once; `init(window, cx)` runs before the first render, for what needs the window; `destroy()` runs when it leaves the tree. It is also a `tracker.Owner`, so `this` is a valid owner for model events, `Timer.interval(this, ...)`, tweens and immediates, and those subscriptions end with it. (A props only component owns nothing: passing `this` as an owner there does not compile.)

Element listeners take short callbacks: `.onClick(() -> ...)` or `.onClick(event -> ...)`.

**Data that tracker does not see.** Glaze keeps the rendering of a component and draws it again only when a prop or an observable it read changes. When a rendering also depends on something else (a plain field, a buffer filled by other code, a native resource), call `notify()` once that data changed:

```haxe
class LogPanel extends Component {

    // Filled outside of tracker: a plain array, not observable
    final lines:Array<String> = [];

    override function init(window:Window, cx:App) {
        Timer.interval(this, 0.5, () -> {
            lines.push(Log.readPending());
            notify();
        });
    }

    function render(window:Window, cx:App):IntoElement {
        return div().flex().flexCol().children([for (line in lines) div().child(line)]);
    }

}
```

It is the same idea as `cx.notify()` on an entity: the rendering is stale (a component has no observers today, so nothing else listens to it). A persistent component renders again like after a change of an observable (alone, see below); its siblings and the persistent components inside it stay cached. A props only component has no cache of its own: `notify()` renders the view or persistent component it is drawn in. Several calls before the next frame give one render; a call after the component left the tree, or from its own `render`, does nothing. Prefer observable data (`@observe` fields, models) when you can: `notify()` is for what cannot be observed.

**A change renders only what changed.** When a view or persistent component renders again because of its own data (an observable it read, `cx.notify()`, `notify()` on a component) and its size and place do not change, Glaze renders it alone: its ancestors do not render again (GPUI renders them), and what it draws replaces what it drew last time, at the same place in drawing and hit testing order. One changed row of a list of thousands costs about the same as in a list of ten. The frame is the one a full redraw would give; when the view's size changes, or anything else would make it differ (popovers or a tooltip shown, an animation frame, a view drawn twice, `window.refresh()`...), the whole frame is drawn, like in GPUI. A view renders again when its own data changes and when an entity it read with `read(cx)` during its last render is notified, model or view: an ancestor that draws something from a child's state (a toast stack placing its toasts, an editor listing its widgets) follows the child's `cx.notify()` when it read the child that way, and must not count on rendering whenever the child does. Elements that hand their descendants a context outside of the window's stacks (an app global they read while drawing) call `Window.enterSharedContext()` and `exitSharedContext()` around them: views inside are then drawn with their ancestors. `window.inPlaceRendering = false` (or `Window.defaultInPlaceRendering`) turns it off.

**State read across views.** The same goes between views. A view that reads another view's state with `read(cx)` renders again when that view is notified (`cx.notify()`), like it does for a model: a plain field plus `cx.notify()` works across views. `@observe` fields are still the clearest choice: the reader renders when the field changes, with or without a notify, and only then. What is not followed: a plain field reached through a reference kept outside the entity (no `read(cx)`, so no entity access is recorded), and a change without `cx.notify()`; `glaze_verify_cache` reports both as stale renderings. For example, a list view whose selection a sidebar view shows:

```haxe
class FileList extends Model implements Render {
    @observe public var selected:Null<String> = null;   // read by the sidebar: observable
    ...
}

class Sidebar extends Model implements Render {
    final list:Entity<FileList>;
    function render(window:Window, cx:Context<Sidebar>):IntoElement {
        // Reading `selected` makes the sidebar render again when it changes;
        // with a plain `var selected`, the list must `cx.notify()` after
        // changing it, or the sidebar keeps showing the old value
        return div().child(list.read(cx).selected ?? 'Nothing selected');
    }
}
```

**Checking the cache in development.** A missing `notify()` shows as a part of the interface that does not update. Build your app with the define `glaze_verify_cache` to find them:

```yaml
app:
    defines:
        - glaze_verify_cache
```

Every view or persistent component that Glaze would take from its cache then renders for real, and what it draws (shapes, text, hitboxes, cursors, the number of listeners and dispatch nodes) is compared with what the cache holds, apart from the views drawn for real inside it: a view notified inside it changes legitimately, a stale view inside it is reported on its own, and a view drawn inside it that the last frame did not draw is a change of its own render. A difference logs a warning naming the class and its element id path, for example `LogPanel (element view-1.view-3) rendered differently from its cached rendering without being notified: notify() probably missing, or a read the tracker does not see`. The fresh rendering is the one displayed. Hover changes are not reported: like GPUI, a cached view keeps its hover until the mouse moves over it. Each frame where views rendered alone is also compared with a full frame drawn right after it (scene, hitboxes, dispatch tree, listeners, element states), and a difference is reported the same way. The check renders every cached view on every frame, so keep it for development and tests (`Window.verifyCache = false` turns it off at runtime, `Window.onCacheVerificationFailure` receives the messages); without the define it costs nothing. Glaze's own test suites run with it.

## Using the kit

`glaze.kit` is gpui-kit's component library: buttons, inputs, selects, menus, dialogs, tabs, tables, trees, charts, markdown views, a dock system, and more. Wrap your interface in the kit's window root, which carries the theme, dialogs, sheets, notifications, tooltips and text selection:

```haxe
ui = new Glaze(Kit.window(AppView.component()));
```

Then place the kit components like your own:

```haxe
Button.component('save').primary().label('Save').onClick(() -> save())
Input.component().at('name').placeholder('Your name').value(model.name).onChange(v -> model.name = v)
Select.component().at('theme').options(themes).value(prefs.theme).onChange(id -> prefs.theme = id)
```

The kit initializes itself the first time it is needed. A setting made before the first render initializes it too, then applies: `Theme.setMode(ThemeMode.Dark)`, `Kit.setLocale('fr')`. Stateful controls (`Input`, `Select`, `Slider`) keep their own state under the identity of their call, like persistent components; `.value(v)` makes them controlled.

Icons are `IconName` values: `Button.component('add').icon(IconName.Plus)`. The SVG files of your project's `resources/glaze/icons` become icons too (`resources/glaze/icons/alarm-clock.svg` is `IconName.AlarmClock`), and more directories can be listed in `ceramic.yml` (`glaze:` then `icons:` with a list of paths). Every icon is embedded in the code at compile time, so nothing has to be preloaded, on the web included.

The names are gpui-kit's in camelCase, so its documentation applies; [docs/PORTING.md](docs/PORTING.md) lists the differences. `Kit.window(view)` is `Root.component().child(view)`: `Root` is itself a component.

### Scrollbars

The kit's scrollbars (`Scrollable`, `overflowYScrollbar()`, lists, tables, trees, Cityscape's editors) fade in and out quickly in place, over 0.12 seconds each way, and keep the same width when the pointer is over them or drags them (only the color of the thumb changes). gpui-kit's own behaviour, where a hiding scrollbar slides toward the edge while it fades and the thumb grows from 6 to 8 pixels on hover, is an option. The setting (`ScrollbarAppearance`, in `glaze.kit.scroll`) is global and can change at runtime:

```haxe
Theme.setScrollbarAppearance(ScrollbarAppearance.instant(), cx);     // shown and hidden at once
Theme.setScrollbarAppearance(ScrollbarAppearance.fade(0.2), cx);     // a slower fade, 0.2 s each way
Theme.setScrollbarAppearance(ScrollbarAppearance.fade()
    .withShowDuration(0.08).withHideDuration(0.3), cx);              // separate show and hide durations
Theme.setScrollbarAppearance(ScrollbarAppearance.gpuiKit(), cx);     // gpui-kit: slide out, thumb growth
Theme.setScrollbarAppearance(ScrollbarAppearance.fade().withThumbGrowth(true), cx);
```

The define `glaze_scrollbar_appearance` (`fade`, `instant` or `gpuikit`) changes the default at compile time (Glaze's golden scenes use `gpuikit`, to compare with the real gpui-kit). One scrollbar can differ from the global setting: `Scrollbar.vertical(handle).appearance(ScrollbarAppearance.instant())`, or `div().overflowYScrollbar().scrollbarAppearance(ScrollbarAppearance.gpuiKit())`. When the bars are shown (on hover, while scrolling, always) is a separate setting, `Theme.setScrollbarMode`. With reduced motion (`cx.setReduceMotion(true)`), scrollbars show and hide at once. See DEV-023 in [docs/DEVIATIONS.md](docs/DEVIATIONS.md).

### Code editor

The code editor of Glaze is [Cityscape](../cityscape/README.md) (plugin `cityscape`), a port of Monaco, the editor of Visual Studio Code. It replaces gpui-kit's code editor (`Editor`, `EditorState`), which Glaze does not include: list both plugins in `ceramic.yml` and place a `CityscapeEditor` in your interface like any kit component. The kit's text inputs (`Input`, `Textarea`, `InputGroup`, `NumberInput`, `OtpInput`), rich text and `TextView` stay in Glaze.

The kit's element inspector (define `glaze_inspector`, toggled with cmd-alt-i on macOS and ctrl-shift-i elsewhere) edits styles in Cityscape editors: a project built with `glaze_inspector` lists the `cityscape` plugin too, the build stops with an error saying so otherwise. Without `glaze_inspector`, Glaze does not depend on Cityscape.

## Ceramic visuals in Glaze

`visual(v)` shows a Ceramic `Visual` (a quad, a mesh, text, Spine, particles, a whole sub scene, a game) as an element of the interface. It is sized by the flex layout like any styled element (the visual's own size when none is given), drawn in order with the other elements (a popover, a menu or a dialog goes over it), clipped by scrolling containers, with the element's corner radii and opacity, and Ceramic pointer events reach it. This is an addition of Glaze: GPUI has no equivalent.

```haxe
final game = new GameScene();          // any ceramic.Visual
final focus = cx.focusHandle();

div().flex().gap4()
    .child(visual(game)
        .flex1().h(px(300.))
        .rounded(px(8.))
        .onResize((width, height) -> game.size(width, height))   // lay out the visual
        .trackFocus(focus))                                      // a click in it focuses it
    .child(Button.component('pause').label('Pause').onClick(() -> game.paused = true));

// In the game: react to Ceramic keys only when its element has the focus
if (VisualElement.isFocused(game) && input.keyJustPressed(KeyCode.SPACE)) jump();
```

The visual is reparented into the content of a Ceramic `Filter` that renders it into a texture at the window's scale factor, and the window shows that texture in place of the element. Small visuals share an atlas of render textures, large ones get their own. While the element is not drawn, the visual is deactivated and detached, never destroyed; its filter is kept `VisualElement.gracePeriodFrames` frames (120), then destroyed. A visual is shown by one element at a time.

- **Size.** The content area is the element's size, rounded to device pixels: `onResize(width, height)` is called when it changes. With `fit(ObjectFit.Contain)` (or `Cover`, `Fill`, `ScaleDown`, `None`), the visual is scaled and placed in the area from its own `width` and `height`, like an image. With `nativeResolution()`, the visual is rendered at its own size and the texture is scaled into the element (with `textureFilter(NEAREST)` for pixel art).
- **Rendering.** `renderMode(Always)` (the default) renders the visual at every frame, for animations; `renderMode(Explicit)` renders it when it is shown or resized, and on `VisualElement.renderNow(v)`, for static content that costs nothing at rest. Either way, the window draws only the element's rectangle of its texture again: no view renders, nothing is laid out again, and cached views stay cached. `antialiasing(samples)` sets the multisampling of the texture.
- **Pointer.** With `interactive(true)` (the default), `onPointerDown`, `onPointerOver` and the other pointer events of the visual and its children work as usual, with their local coordinates, only where no Glaze element drawn over it blocks the mouse (like GPUI's hover test) and inside its clipping: a Glaze popover or dialog over it, or a part scrolled out of view, receives nothing. The element blocks the mouse for the Glaze elements behind it, the scroll wheel excepted, so scrolling containers still scroll. `interactive(false)` makes it an image.
- **Keyboard.** Ceramic keys are global: `trackFocus(handle)` gives the element a focus handle, focused by a click in the content, and `VisualElement.isFocused(v)` (or `handle.isFocused(window)`) tells the visual when to react. `VisualElement.isHovered(v)` tells whether the pointer is over it.
- **Interactivity.** Like `img()`, the element takes `id`, `hover`, `onClick`, `onMouseDown`, `tooltip` and the other interactive methods.

Any `RenderTexture` shown with `img(texture)` follows its content the same way: the window checks once per frame the render textures its scene shows (`RenderTexture.renderVersion` changes each time Ceramic draws into one) and draws their rectangles again.

The story gallery (`samples/story`) has a page with these cases: an animated visual in a panel, inside a scroll area, under a popover, and a Ceramic quad receiving clicks.

## Text and fonts

Glaze draws text with its own text system: fonts are TTF, OTF or TTC files added to the text system (Inter and JetBrains Mono are bundled). Two choices of Glaze go beyond the real GPUI and are deliberate:

- **Font smoothing.** `TextSystem.fontSmoothing` is `Dense` by default, on every platform: stems are made a little thicker, close to the text of macOS (Safari, Chrome and native apps), by an amount that depends on the size and on the luminance of the text color, measured on Chromium on macOS. `Thin` is the raw coverage of the outlines, what GPUI renders with its font file text system (Glaze's golden scenes use it, with the define `glaze_font_smoothing: thin`), and `Auto` follows the platform (`Dense` on macOS, `Thin` on Windows and Linux). Set it once at startup: `app.textSystem().fontSmoothing = Thin`, or with the define.
- **Fonts of the system by name.** On macOS, a family that no added font provides (`Menlo`, a font the user installed) is read from the system font folders, all its faces, and drawn like an added font (`glaze.platform.SystemFontFamilies`, not on the web, TODO on Windows and Linux; define `glaze_no_system_fonts` to keep the added fonts only). `TextSystem.isFamilyAvailable(name)` tells whether a family is there, to pick the first of a CSS like list. Well known names that are not found keep their bundled substitutes. The generic family `monospace` is the default fixed font of browsers on the platform (Menlo on macOS) when the system fonts are on. Characters that no added font has come from the fonts of the system (`SystemFontFallback`), Han, kana and hangul from the font of their script in the system's list (kana in Hiragino Sans on macOS, even after Han text loaded Hiragino Sans GB).

`Font.synthesizeStyle` (off by default, like GPUI) draws the italic of a family without an italic face as a slanted upright face, like a browser. `Font.wholeRunShaping` (off by default, like GPUI) shapes a line whose runs all use such fonts in one piece, like a browser, instead of word by word like GPUI's cosmic-text: kerning and contextual features then apply across the line break opportunities (between CJK characters, after a hyphen), in the fallback fonts too. On the web, the graphemes the browser draws for such a font (the Canvas2D fallback: CJK, emoji) are measured as whole runs, so the kerning between them applies too, and a grapheme that the font or one of its fallbacks maps as text keeps that glyph (emoji presentation does not force the emoji font, like the native text system). `Font.preferColorEmoji` (off by default, like GPUI) draws every emoji (Unicode's `Extended_Pictographic`, unless followed by U+FE0E) with a color emoji font, even where a font of the list has a text glyph for it: the bundled or system emoji font natively, the browser's emoji font on the web.

## Samples

The `glaze-settings` sample of [ceramic-samples](https://github.com/ceramic-engine/ceramic-samples) is the reference for the component pattern: a settings window with tabs, labeled rows, switches, selects, a stepper and a confirmation dialog, over a small tracker model.

In this plugin's `samples/`: `basic` (a small interactive view), `kit` (a tour of the components), `story` (gpui-kit's full gallery), `textfield` (text input with IME and clipboard) and `gpui-examples` (GPUI's own examples). Run one with `cd samples/basic && ceramic clay run web`.

## Tests

```sh
cd tests/unit && ceramic headless run node --setup --assets
```

The layout is incremental: a view that renders again keeps the layout of the nodes that did not change, and a changed node whose size and position do not change leaves the rest of the tree as it is. Define `glaze_verify_layout` to check it while developing: after each layout, the tree is laid out again from scratch and any difference is logged as an error (slow, for tests only).

## License

Apache License 2.0, see [LICENSE](LICENSE). Ported projects, fonts and icons keep their own licenses, listed in [NOTICE.md](NOTICE.md). The few differences with the original GPUI and gpui-kit introduced during the initial port are listed in [docs/DEVIATIONS.md](docs/DEVIATIONS.md); Glaze now evolves on its own.
