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

**Entities made while a view is drawn.** An entity made or read while a view is drawn counts as accessed by that view, as in GPUI (`cx.new` marks the new entity accessed, like a read). A component is made, and runs its `init`, while the view that holds it is drawn, and so does the closure of `window.useKeyedState`: what they make or read is counted for the holder until the holder renders again. Nothing visible follows from it (the window only keeps following these entities a little longer), and the check above does not report it. Make state once, in `init` or with `window.useState` / `window.useKeyedState`, never on each `render`: an entity made on each render is a new one every time, and whatever it held is lost.

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

The kit's scrollbars (`Scrollable`, `overflowYScrollbar()`, lists, tables, trees, Cityscape's editors) fade in and out quickly in place, over 0.12 seconds each way, and keep the same width when the pointer is over them or drags them (only the color of the thumb changes). Their thumb is 8 pixels wide and fully rounded, like Loreline Writer's scrollbars, 4 pixels from the edge of the 16 pixel scrollbar band. gpui-kit's own behaviour, where a hiding scrollbar slides toward the edge while it fades and a 6 pixel thumb in the theme's radius grows to 8 pixels on hover, is an option. The setting (`ScrollbarAppearance`, in `glaze.kit.scroll`) is global and can change at runtime:

```haxe
Theme.setScrollbarAppearance(ScrollbarAppearance.instant(), cx);     // shown and hidden at once
Theme.setScrollbarAppearance(ScrollbarAppearance.fade(0.2), cx);     // a slower fade, 0.2 s each way
Theme.setScrollbarAppearance(ScrollbarAppearance.fade()
    .withShowDuration(0.08).withHideDuration(0.3), cx);              // separate show and hide durations
Theme.setScrollbarAppearance(ScrollbarAppearance.gpuiKit(), cx);     // gpui-kit: slide out, thumb growth
Theme.setScrollbarAppearance(ScrollbarAppearance.fade().withThumbGrowth(true), cx); // 8 px, 10 px on hover
Theme.setScrollbarAppearance(ScrollbarAppearance.fade().withThumbWidth(6), cx);      // a thinner thumb
Theme.setScrollbarAppearance(ScrollbarAppearance.fade().withThumbRadius(null), cx);  // the theme's radius
```

`withThumbWidth(null)` gives gpui-kit's 6 pixels (8 when grown). Explicit `ScrollbarStyles` widths and radii (a scrollbar's own `styles(...)`, the kit theme's mobile thumb) still win over the appearance, and a theme whose radius is zero still squares the thumb. Cityscape's editor scrollbars take the same width in a band of their own (`scrollbar.verticalScrollbarSize` and `horizontalScrollbarSize`), no wider than `verticalSliderSize` and `horizontalSliderSize`.

The define `glaze_scrollbar_appearance` (`fade`, `instant` or `gpuikit`) changes the default at compile time (Glaze's golden scenes use `gpuikit`, to compare with the real gpui-kit). One scrollbar can differ from the global setting: `Scrollbar.vertical(handle).appearance(ScrollbarAppearance.instant())`, or `div().overflowYScrollbar().scrollbarAppearance(ScrollbarAppearance.gpuiKit())`. When the bars are shown (on hover, while scrolling, always) is a separate setting, `Theme.setScrollbarMode`. With reduced motion (`cx.setReduceMotion(true)`), scrollbars show and hide at once. See DEV-023 in [docs/DEVIATIONS.md](docs/DEVIATIONS.md).

### Additions to gpui-kit

A few options of the kit have no equivalent in gpui-kit. Each one is off by default, so a component left alone looks and behaves like gpui-kit's. They are listed as KIT-nnn in [docs/DEVIATIONS.md](docs/DEVIATIONS.md).

**Tabs.** A style set on a `Tab` wins over its variant, like on a `Button`: `Tab.component().h(px(34)).textSize(px(13)).bg(color)`, and `.hover(s -> s.bg(color))` for the pointer. `TabVariant.Custom` is a rectangular tab filled from the theme tokens `tab.background`, `tab.hover.background`, `tab.hover.foreground` and `tab.active.background`, with a geometry of your own: `Tab.labelStyle(s -> s.textColor(red).lineThrough())` styles the label alone, not the prefix, the suffix or the children. A `TabBar.lastEmptySpace(element)` set by the caller is always drawn after the last tab (the default one only next to a suffix or the menu), so it can hold a button.

```haxe
TabBar.component('documents')
    .custom(new TabAppearance().topRadius(6).height(34).paddingX(12).textSize(13).sideBorders(false).bottomBorder(false))
    .labelMaxWidth(px(120))      // the label alone is truncated, the close button keeps its place
    .revealSelected(true)        // a tab selected by code is scrolled into view, not only a clicked one
    .selectedIndex(current)
    .children([for (doc in documents) Tab.component()
        .label(doc.name)
        .group('tab')            // the suffix can use groupHover('tab', ...)
        .suffix(closeButton(doc))
        .onHover((hovered, _, _) -> {})
        .onDragMove(DraggedTab, (event, _, _) -> placeInsertionLine(event.bounds, event.event.position))
        .contextMenu((menu, _, _) -> menu.item(PopupMenuItem.create('Close')))])
```

**Resizable panels.** `resizablePanel().shrinkPriority(n)` orders the panels that give up space when the window shrinks (highest first, each down to the start of its `sizeRange`; a `fixed()` panel with a priority gets its size back when the window grows again). `hResizable(id).onResizing((state, window, cx) -> ...)` follows a drag move by move, `onResize` still reports its end. A handle appearance can tell the dividers of a group apart with `handle.index()`. A group whose first panel is hidden no longer keeps a handle on its leading edge. `.handleSize(px(0))` on a group sets the thickness of the divider line (1 px by default; with zero nothing is drawn over the panels and the 4 px on each side of the boundary still resize), and `.onLayoutSizes((state, window, cx) -> ...)` reports the sizes after the container changed size (`onResize` reports the drags).

```haxe
hResizable('workspace')
    .withHandleAppearance((handle, window, cx) -> handle.index() == 0 ? treeDivider(handle) : null)
    .onResizing((state, _, cx) -> model.previewWidth = state.read(cx).sizes()[2])
    .children([
        resizablePanel().visible(model.treeVisible).size(px(220)).fixed().shrinkPriority(0).child(tree),
        resizablePanel().sizeRange(new PixelsRange(px(200), Pixels.MAX)).shrinkPriority(2).child(editor),
        resizablePanel().size(px(360)).fixed().shrinkPriority(1).sizeRange(new PixelsRange(px(150), Pixels.MAX)).child(player),
    ])
```

**Tree.** `new TreeItem(id, label).folder(true)` is a folder even when it is empty. `state.setItems(items, cx, true)` keeps the selection by item id when the list is rebuilt. On a `Tree`, `.toggleOnClick(false)` makes a click select only (a double click, Enter and the arrows toggle), and `.navigationKeys(true)` adds Home, End, PageUp, PageDown and the left arrow going to the parent. Rows drag and drop with Glaze's own drags:

```haxe
Tree.component(state, renderRow)
    .dragEntries((ix, entry) -> new DraggedFile(entry.item().id), (file, _, _, cx) -> preview(file, cx))
    .dropOnEntries(DraggedFile, (file, ix, entry, _, _) -> move(file.id, entry.item().id),
        (file, ix, entry, _, _) -> entry.isFolder() && entry.item().id != file.id)
    .dropTargetStyle(s -> s.bg(theme.dropTarget))
    .dropOnRoot(DraggedFile, (file, _, _) -> move(file.id, null))
```

A drag over a file can highlight its folder instead of the file: `.dropTargetFor((ix, entry) -> entry.isFolder() ? ix : state.read(cx).parentIndex(ix))` names the row that takes the `dropTargetStyle` (`null`: the tree itself, with its `rootDropTargetStyle`); the drop still goes to the row under the pointer. `.rootContextMenu((menu, window, cx) -> menu.item(...))` is the menu of the empty area under the rows; a right click on a row opens the row's menu only. `.rowHover(s -> s.bg(color))` and `.rowSelected(s -> s.bg(color))` replace the theme's `list.hover` and `list.active` for the rows of one tree (`ListItem.hover(style)` and `ListItem.selectedStyle(style)` do it for one item of any list).

**Title bar.** `TitleBar.component().platform(TitleBarPlatform.Windows)` gives one title bar the look and behaviour of another system (`Mac`, `Windows`, `Linux`, `Web`) without touching `OperatingSystem.current`, which also decides the key bindings: the Windows or Linux bar can be shown and tested on a Mac. On the Windows look, the minimize, maximize or restore, and close buttons act on the window themselves (`onCloseWindow` replaces the default close); `.controlClicks(false)` leaves them to a platform that handles the window control areas. `.windowControls(false)` draws no window button (for a window that keeps the system's decorations), `.controlWidth(px(46))` sets their width, and a left padding set on the bar is the whole left padding, in fullscreen too (the 12 px a fullscreen window adds are for the default padding).

**Dialog.** `dialog.maxH(px(480))` and `dialog.maxHRatio(0.85)` limit the height of a dialog (it scrolls its children beyond). `dialog.overlayCloseOnClick(true)` closes on a whole click of the overlay, press and release, so a text selection that ends outside the dialog does not close it. `dialog.header(element)` places a row above the title, for a back button. A `shadow` set on the dialog replaces the default one (`dialog.shadow([])` for none).

**Custom button colors.** `new ButtonCustomVariant(cx).color(bg).foreground(fg).hover(hoverBg).hoverForeground(hoverFg)` changes the label and icon color under the pointer (and while pressed, unless `activeForeground` is set). Like gpui-kit, the resting background of a custom variant is `color` mixed with 20 % of transparent; `.exact()` uses the colors as given.

**App menu behind a button.** The menus declared once with `cx.setMenus(...)` feed the native menu bar on macOS and, where no menu bar shows, a drawn menu: `Button.component('menu').icon(IconName.Menu).appMenu()` (with `using glaze.kit.menu.DropdownMenu;`) opens every app menu as a submenu under the button. `menu.withAppMenus(window, cx)` and `menu.withMenuItems(items, window, cx)` do the same inside any `PopupMenu` builder (a context menu, a dropdown of your own).

**Field with suggestions.** `SuggestInput` is a text field with a list of suggestions filtered by what is typed, where any text stays allowed, like an HTML `<input list>`: arrows move in the list, Enter picks the highlighted suggestion (or keeps the text as typed when none is), Escape closes the list.

```haxe
// once, where the view is created
codes = cx.newEntity((c:Context<SuggestInputState>) -> new SuggestInputState(window, c)
    .withPlaceholder('Language code', c)
    .withSuggestions(['en', 'en-GB', 'fr', 'fr-CA']));
cx.subscribe(codes, SuggestInputEvent, (view, _, event, cx) -> switch event {
    case Change(value): view.code = value;
    case Accept(value) | Submit(value): view.confirm(value);
});

// in render
SuggestInput.component(codes).input(input -> input.small())
```

**Alert content, separator label.** `Alert.info('note', '').content(element)` shows any element in place of the message, a `RichText` for example. `Separator.horizontal().label('Section').labelStyle(s -> s.bg(surface).px3().textSize(px(11)))` styles the label, to match a surface that is not the theme's background.

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

The story gallery (`samples/story`) has a page with these cases: an animated visual in a panel, inside a scroll area, under a popover, and a Ceramic quad receiving clicks, then measured Ceramic views (an `ImageView`, a column of Ceramic buttons next to Glaze text, a `TextView` wrapping in a column, and a button that lengthens its text). See "Computed sizes" below for the size of a Ceramic `View`.

## Computed sizes

The layout computes the size of an element from its style (`w`, `h`, `flex`, `aspectRatio`...) and, when it has children, from them. A leaf whose size depends on its content has a measure function: the layout tells it what it already knows and it answers with a size. That is how text is sized ("at most 300 pixels wide", "then 3 lines, 300 by 54"). A measure function receives `known` (for each axis, the size given by the style or the parent, or `null`) and `available` (for each axis, `Definite(n)`: at most n pixels, `MinContent`: the smallest size, `MaxContent`: the ideal size without constraint). It can be called several times per layout with different constraints: it must give the same answer to the same question and change nothing visible.

For a `Component`, three cases, from the most common to the rarest:

```haxe
// 1. The size comes from the content: nothing to do.
// The card is as wide as its title and as high as its lines.
function render(window:Window, cx:App) {
    return vFlex().p(px(12.)).gap(px(4.))
        .child(label(title).textLg())
        .child(label(subtitle));
}

// 2. Keeping a ratio: the `aspectRatio` style. One dimension comes from the
// layout, the other follows. A 16/9 thumbnail as wide as its column:
div().wFull().aspectRatio(16. / 9.).child(img(thumbnail).sizeFull())

// 3. A size computed by code: `measure(fn)` on `canvas()`.
// A chart 24 pixels high per series, as wide as it is given (400 by default):
canvas(prepaintChart, paintChart)
    .measure((known, available, window, cx) -> {
        final width = known.width ?? switch available.width {
            case Definite(n): n;
            case _: 400.;
        };
        return size(px(width), px(series.length * 24.));
    })
```

When the data changes, the component renders again (tracker or `notify()`) and the layout measures again: nothing else to do. `canvas().measure(fn)` is an addition of Glaze: with GPUI it takes a custom element.

### Ceramic views

A Ceramic `View` (plugin `ui`: `TextView`, `LinearLayout`, `ImageView`, your own) shown with `visual(view)` measures itself: the element asks the view its size with `computeSize`, gives it the size the layout decides (`view.size(...)`) and Ceramic lays out its content in the same frame.

```haxe
// A column of Ceramic buttons (vertical LinearLayout, auto size): as wide as
// its widest button, as high as their sum
hFlex().gap(px(8.))
    .child(visual(ceramicButtons))
    .child(label('next to it, in Glaze'))

// A Ceramic TextView in a Glaze column of 300 pixels: on one line it keeps
// its natural width, otherwise it wraps in 300
vFlex().itemsStart().w(px(300.)).child(visual(ceramicText))

// An ImageView with no size: the size of its texture (in points, density
// respected), reduced to the available width if it is wider
div().flex().itemsStart().child(visual(imageView))

// An ImageView: the width from Glaze, the height from the ratio of its texture
div().child(visual(imageView).w(px(200.)))
```

How a question of the layout becomes a `computeSize` call:

| The layout says | The view is asked |
|---|---|
| an axis is known (`known.width = 300`) | that parent size, with no freedom on the axis: the view is 300 wide (a `TextView` wraps in 300, an `ImageView` gets its height from the ratio) |
| a free axis, `MinContent` or `MaxContent` | its natural size (parent size 0, flexible on the axis, like `autoComputeSize()`). Ceramic has no separate minimal size: both get the natural size |
| a free width, `Definite(n)` | like CSS fit-content: the natural width if it fits in n, otherwise n imposed. The height is never limited by the available height (the content overflows or scrolls, like text) |

When the content of the view changes size (a longer text, a button added), Ceramic lays the view out again and the element asks its last questions again: if an answer changed, the Glaze view showing it is notified and its branch is laid out again, in the same frame. Nothing is polled: a view that does not change costs nothing.

Who decides what, and the limits:

- **Sizes that depend on the parent belong to the Glaze style.** Write `flex1()`, `wFull()` or `w(relative(0.5))` on the element, not `ViewSize.fill()` or `ViewSize.percent()` on the view: the view gives its natural (`auto`) or fixed size only. A view in `fill` or `percent` on a free axis takes the available space when the layout gives a definite one, and 0 otherwise.
- **A hosted view does not shrink under a min content constraint.** In a row that shrinks its children (`hFlex()` narrower than them), the view keeps its natural width and overflows, where a Glaze text would wrap. Give it a width in the Glaze style: `visual(view).flex1().minW0()` or `w(...)`.
- **A block container imposes its width.** In a plain `div().w(px(300.))`, a child is as wide as the div (300, even for a short text). Use a flex container with `itemsStart()` to keep the natural width.
- **`ImageView` sizes.** With no size anywhere, an `ImageView` takes the size of its texture (`texture.width` and `texture.height`, in points), whatever its `scaling`. A width or a height in the Glaze style, an axis imposed by the layout, or a `viewSize()` axis gives the other axis from the ratio of the texture; a fixed `viewSize()` on both axes is kept. Without a texture (image still loading) it is 0 by 0.
- **A view measured at 0 by 0 is not shown**, and not laid out by Ceramic until its Glaze view renders again.
- The padding of the element's style is not given to the view (the view fills the element): use the view's own padding.
- `fit()` does not apply to a measured view (it is resized to the element). With `nativeResolution()`, the view keeps its own fixed size, like any visual.

Any other visual keeps its own size (`width`, `height`) when the style gives none, or computes it with the same `measure(fn)` as `canvas()`:

```haxe
visual(particles).measure((known, available, window, cx) -> size(px(known.width ?? 120.), px(80.)))
```

## Render on demand

By default Ceramic draws every frame. With `settings.renderOnDemand = true` (in
`Project.hx`, off by default, see `ceramic.Settings.renderOnDemand`), a frame is drawn
only when something changed. An interface at rest then costs almost nothing, and the
frame that answers a keystroke reaches the screen sooner.

Glaze needs nothing more: every change of a window requests a render (a view notified
or refreshed, input, `window.requestAnimationFrame()`, timers such as the caret blink,
images that finish loading, textures shown by `img()` that are drawn again). A
`visual(v)` element in `Always` mode (the default) renders its visual at every frame,
so every frame is drawn while it is shown: use `renderMode(Explicit)` and
`VisualElement.renderNow(v)` for a visual that changes rarely.

Ceramic code of the app that changes a plain field at every frame (`quad.color`, the
arrays of a `Mesh`, shader uniforms) calls `app.requestRender()`, or holds
`app.requestContinuousRender(owner)` while it animates. In debug, the define
`ceramic_verify_render_on_demand` reports such a change made without a request.

## Text and fonts

Glaze draws text with its own text system: fonts are TTF, OTF or TTC files added to the text system (Inter and JetBrains Mono are bundled). Two choices of Glaze go beyond the real GPUI and are deliberate:

- **Font smoothing.** `TextSystem.fontSmoothing` is `Dense` by default, on every platform: stems are made a little thicker, close to the text of macOS (Safari, Chrome and native apps), by an amount that depends on the size and on the luminance of the text color, measured on Chromium on macOS. `Thin` is the raw coverage of the outlines, what GPUI renders with its font file text system (Glaze's golden scenes use it, with the define `glaze_font_smoothing: thin`), and `Auto` follows the platform (`Dense` on macOS, `Thin` on Windows and Linux). Set it once at startup: `app.textSystem().fontSmoothing = Thin`, or with the define.
- **Fonts of the system by name.** On macOS, a family that no added font provides (`Menlo`, a font the user installed) is read from the system font folders, all its faces, and drawn like an added font (`glaze.platform.SystemFontFamilies`, not on the web, TODO on Windows and Linux; define `glaze_no_system_fonts` to keep the added fonts only). `TextSystem.isFamilyAvailable(name)` tells whether a family is there, to pick the first of a CSS like list. Well known names that are not found keep their bundled substitutes. The generic family `monospace` is the default fixed font of browsers on the platform (Menlo on macOS) when the system fonts are on. Characters that no added font has come from the fonts of the system (`SystemFontFallback`), Han, kana and hangul from the font of their script in the system's list (kana in Hiragino Sans on macOS, even after Han text loaded Hiragino Sans GB).
- **Variable fonts and the system font of macOS.** A variable font (a `wght` axis) gives every font weight, each one an instance of the font (`ttf.Font.instance`), italic through the italic file of the family or its `ital` / `slnt` axis, and a font with an optical size axis (`opsz`) is drawn with the instance of the font size, like CoreText does. The system font of macOS is such a font, reached by the names a browser gives it: `system-ui`, `-apple-system`, `BlinkMacSystemFont` (and `.AppleSystemUIFont`) for SF, `ui-monospace` for SF Mono, at every weight (the named instances of the font: 500 is its Medium) with its tracking by size. `.fontFamily('system-ui').fontWeight(FontWeight.SEMIBOLD)` is the semibold of the interface font of macOS. `.SystemUIFont` stays the bundled font (`systemFontFallback`), and `SF Pro`, `SF Pro Text` and `SF Mono`, fonts that are not installed by default, keep their substitutes unless `SystemFontFamilies.appleFamilyAliases` is set. `CeramicTextSystem.variableFonts = false` gives a variable font its default instance only, `variableFontTracking = false` leaves its tracking out. Static fonts are not concerned, and a variable font that only the system fallback uses (a symbol taken from the system font) keeps its default instance.

`Font.synthesizeStyle` (off by default, like GPUI) draws the italic of a family without an italic face as a slanted upright face, like a browser. `Font.wholeRunShaping` (off by default, like GPUI) shapes a line whose runs all use such fonts in one piece, like a browser, instead of word by word like GPUI's cosmic-text: kerning and contextual features then apply across the line break opportunities (between CJK characters, after a hyphen), in the fallback fonts too. On the web, the graphemes the browser draws for such a font (the Canvas2D fallback: CJK, emoji) are measured as whole runs, so the kerning between them applies too, and a grapheme that the font or one of its fallbacks maps as text keeps that glyph (emoji presentation does not force the emoji font, like the native text system). `Font.preferColorEmoji` (off by default, like GPUI) draws every emoji (Unicode's `Extended_Pictographic`, unless followed by U+FE0E) with a color emoji font, even where a font of the list has a text glyph for it: the bundled or system emoji font natively, the browser's emoji font on the web.

### Rich text

`RichText` (in `glaze.kit.text`) is a paragraph of typed spans: families, weights and sizes on one baseline, colors, decorations, letter spacing, upper or lower case, boxes (pills), inline elements, links, and spans animated as a whole or character by character. It is the paragraph engine of the markdown view (`TextView`), without any markup: you give spans and styles.

```haxe
final shout = new RichTextStyle().textTransform(Uppercase).letterSpacing(Em(0.03)).fontWeight(FontWeight.BOLD);
final tag = new RichTextStyle().fontSize(Relative(0.85))
    .box(StyleBuilder.build(s -> s.px(px(6)).border1().borderColor(theme.border).rounded(px(9))));
final wave = new RichTextStyle().animation(RichTextAnimation.of([
        new Keyframe(0.0, MotionTransform.identity()),
        new Keyframe(0.5, new MotionTransform(new Point(0, -0.12), new Point(1, 1), 0, 1)),
        new Keyframe(1.0, MotionTransform.identity()),
    ], new Timing(1.2).ease(Easing.EaseInOut).iterations(Infinite))
    .translationInEm()                              // the keyframes move by parts of an em
    .perCharacter(new Stagger(0.09, First), true)); // each character 90 ms ahead of the next

RichText.component('line')
    .textSize(px(16))
    .textAlign(TextAlign.Left)
    .whiteSpace(PreWrap)
    .spans([
        RichSpan.text('Hello '),
        RichSpan.text('everyone', wave),
        RichSpan.text(', listen ', shout),
        RichSpan.box('happy', tag),
        RichSpan.lineBreak(),
        RichSpan.element(Icon.component(IconName.Heart).size4()),
    ])
```

`RichTextStyle.baselineShift(Em(0.4))` raises a span from the baseline (a superscript with a smaller `fontSize`, `Em(-0.2)` for a subscript, a few hundredths of an em to center a pill), `lineHeight(Relative(1.6))` gives a span its own line height (it takes part in the height of its line with it, and a box is as tall as it), and the vertical margins of a box make its line taller. A span without a line height of its own counts for its glyphs only, so a shifted span grows the line just by what leaves it.

A style left unset is inherited from the text style around the component. `RichTextStyle.merge(other)` layers two styles. An animation is keyframes of `MotionTransform` (translation, scale, rotation, opacity) with a `Timing` from `glaze.kit.base.motion`: `perRun()` (the default) moves the span in one piece with its box, `perCharacter(stagger)` animates each character, whose words are then never cut by a line end. An animated span never lays the paragraph out again, asks for frames only while it is visible, and stands still under reduced motion (`cx.setReduceMotion(true)`). See ADD-008 in [docs/DEVIATIONS.md](docs/DEVIATIONS.md).

`.selectable(true)` makes the text of a `RichText` selectable like the text of a markdown view: drag, double click (word), triple click (line), shift click, and, once a selection started in it gave it the focus, select all and copy (`cmd-a`, `cmd-c`; `ctrl` elsewhere). What is copied is the plain text as shown (white space rule and case applied), with the line breaks of `RichSpan.lineBreak()` and of `PreWrap`; elements are left out. It uses the selection of `TextView`, so the window needs the kit's `Root`, and one selection can run across selectable `RichText` and `TextView` paragraphs. A span with a `transformation` or an `animation` is not selectable: nothing shows selected in it, no selection starts in it, and its text is copied only when the selection covers text before and after it in the same paragraph. When the spans of a selectable `RichText` change its text, what was selected is dropped.

## Additions to GPUI

These features have no equivalent in GPUI. They change nothing unless used. [docs/DEVIATIONS.md](docs/DEVIATIONS.md) has the details (entries `ADD-nnn`).

**Window drag areas with clickable content.** An element marked `windowControlArea(Drag)` (the kit's `TitleBar` does it) moves the native window when dragged. Elements drawn above it that answer the left button (`onClick`, `onMouseDown(Left, ...)`, `onDrag`...), that block the mouse (`occlude()`) or that are another window control area keep their presses: a button, a tab bar or a text field in a title bar works without anything to declare. `div().noWindowDrag()` does the same for an element without a listener, and `window.excludeFromWindowDrag(hitbox)` for a hitbox inserted by hand.

**Letter spacing.** `div().trackingWider()` and its siblings (`trackingTighter`, `trackingTight`, `trackingNormal`, `trackingWide`, `trackingWidest`: Tailwind's values, in em) or `div().letterSpacing(px(1))` (pixels, rems, or `relative(0.05)` for 0.05 em) add space after each character of the text inside, like CSS `letter-spacing`. The space counts in the width of the text, in wrapping, in truncation and in the position of the caret. A text run can carry its own (`TextRun.letterSpacing`, in pixels), and `textSystem.lineWrapper(font, fontSize, letterSpacing)` measures with it.

**Grid tracks.** `div().grid().gridTemplateCols([px(140), fr(1)])` and `gridTemplateRows([...])` take a list of tracks like CSS `grid-template-columns`: lengths in pixels or rems, `relative(0.25)` for a percentage, `fr(1)`, `auto()`, `minContent()`, `maxContent()` and `minmax(px(0), fr(1))`. `gridCols(n)` stays GPUI's `repeat(n, minmax(0, 1fr))`, and `colSpanFull()` makes an item span every column.

```haxe
div().grid().gapX2().gridTemplateCols([rems(6), minmax(px(0), fr(1)), maxContent(), auto()])
```

**Transformations.** `div().transformation(Transformation.scaled(size(1.03, 1.03)))` draws an element and its children scaled or moved without changing the layout, like CSS `transform`: the neighbours do not move, hover and clicks follow what is drawn, and the mouse positions given to the listeners inside are in the coordinates of their element. The pivot is the center of the element, `withOrigin(0, 0)` makes it the top left corner. Combine and animate it like any style:

```haxe
div().withAnimation('appear', new Animation(0.45).withEasing(Easing.ease),
    (el, t) -> el.opacity(t).transformation(Transformation.translated(point(px(0.), px(4. * (1. - t))))))
```

Only translation and scale apply to an element (a rotation is ignored, with an error in debug builds); rotate icons with `svg().withTransformation(...)` and glyphs with `paintGlyph`. Popovers, menus and tooltips opened from a transformed element are not transformed. `Transformation.fromMotion(motionTransform)` converts the kit's `MotionTransform`, and an element written by hand uses `window.withElementTransform(matrix, w -> ...)`, with `window.currentElementTransform()` to read the current one. `TransformationMatrix` has `inverse()`, `isAxisAligned()` and `mapBounds(bounds)`.

**Glyph transformations.** `window.paintGlyph(origin, fontId, glyphId, fontSize, color, matrix)` and `window.paintEmoji(origin, fontId, glyphId, fontSize, matrix)` draw one glyph moved, scaled or rotated around its origin on the baseline (`TransformationMatrix.unit().rotate(radians(0.02))`), for animated text. An emoji is moved and scaled, not rotated.

**Key sequence delay.** `cx.setPendingInputTimeout(1.5)` sets how long the first keys of a sequence (`cmd-k cmd-s`) wait for the next one before they are replayed. 1 second by default, like GPUI.

**Key sequences that never complete.** The first keys of a sequence wait for the next one during that delay only when they could also be something by themselves: when they have a binding of their own (`cmd-k` bound next to `cmd-k cmd-s`), or when a focused text input would take the key as text. A prefix that only starts longer sequences (`cmd-k` with nothing bound to `cmd-k` alone) waits with no limit, until another key or a focus change: this is GPUI's rule. `cx.setPendingInputAlwaysTimesOut(true)` makes every unfinished sequence time out after the delay (the keys typed so far are replayed, then forgotten), which is what most editors do.

**Hide, Hide Others, Show All.** `MenuItemTools.osAction('Hide My App', new NoAction(), Hide)`, `HideOthers` and `ShowAll` are the three items of a macOS application menu that the system handles itself: no handler to write, and `cmd-h` and `alt-cmd-h` are shown unless the action has its own binding. On other platforms they are regular items.

**Dependencies of a cached view.** A view that draws from something no entity notifies (the focus of a handle, a setting behind a plain reference) calls `window.recordViewDependency(state, () -> changed)` while it renders or paints: when the next frame starts and the check answers true, the view renders instead of being taken from the cache. A persistent component with a `@prop(unobserved)` compared by content overrides `propsApplied():Bool` to render when its parent gave a value whose content really changed.

**Window zoom.** `window.setZoom(1.5)` (or `zoom: 1.5` in the window options) zooms the whole interface like a web page: the window keeps its size on the screen, its viewport becomes 1.5 times smaller in logical pixels, the interface is laid out again and everything is drawn 1.5 times larger, text rasterized at the new size. With a `Glaze` visual, the window is `ui.window`. `window.zoom()` reads it, `window.scaleFactor()` and `window.viewportSize()` answer with the zoom applied.

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
