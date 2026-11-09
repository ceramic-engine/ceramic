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

### Code editor

The code editor of Glaze is [Cityscape](../cityscape/README.md) (plugin `cityscape`), a port of Monaco, the editor of Visual Studio Code. It replaces gpui-kit's code editor (`Editor`, `EditorState`), which Glaze does not include: list both plugins in `ceramic.yml` and place a `CityscapeEditor` in your interface like any kit component. The kit's text inputs (`Input`, `Textarea`, `InputGroup`, `NumberInput`, `OtpInput`), rich text and `TextView` stay in Glaze.

The kit's element inspector (define `glaze_inspector`, toggled with cmd-alt-i on macOS and ctrl-shift-i elsewhere) edits styles in Cityscape editors: a project built with `glaze_inspector` lists the `cityscape` plugin too, the build stops with an error saying so otherwise. Without `glaze_inspector`, Glaze does not depend on Cityscape.

## Text and fonts

Glaze draws text with its own text system: fonts are TTF, OTF or TTC files added to the text system (Inter and JetBrains Mono are bundled). Two choices of Glaze go beyond the real GPUI and are deliberate:

- **Font smoothing.** `TextSystem.fontSmoothing` is `Dense` by default, on every platform: stems are made a little thicker, close to the text of macOS (Safari, Chrome and native apps), by an amount that depends on the size and on the luminance of the text color, measured on Chromium on macOS. `Thin` is the raw coverage of the outlines, what GPUI renders with its font file text system (Glaze's golden scenes use it, with the define `glaze_font_smoothing: thin`), and `Auto` follows the platform (`Dense` on macOS, `Thin` on Windows and Linux). Set it once at startup: `app.textSystem().fontSmoothing = Thin`, or with the define.
- **Fonts of the system by name.** On macOS, a family that no added font provides (`Menlo`, a font the user installed) is read from the system font folders, all its faces, and drawn like an added font (`glaze.platform.SystemFontFamilies`, not on the web, TODO on Windows and Linux; define `glaze_no_system_fonts` to keep the added fonts only). `TextSystem.isFamilyAvailable(name)` tells whether a family is there, to pick the first of a CSS like list. Well known names that are not found keep their bundled substitutes. The generic family `monospace` is the default fixed font of browsers on the platform (Menlo on macOS) when the system fonts are on. Characters that no added font has come from the fonts of the system (`SystemFontFallback`), Han, kana and hangul from the font of their script in the system's list (kana in Hiragino Sans on macOS, even after Han text loaded Hiragino Sans GB).

`Font.synthesizeStyle` (off by default, like GPUI) draws the italic of a family without an italic face as a slanted upright face, like a browser. `Font.wholeRunShaping` (off by default, like GPUI) shapes a line whose runs all use such fonts in one piece, like a browser, instead of word by word like GPUI's cosmic-text: kerning and contextual features then apply across the line break opportunities (between CJK characters, after a hyphen), in the fallback fonts too.

## Samples

The `glaze-settings` sample of [ceramic-samples](https://github.com/ceramic-engine/ceramic-samples) is the reference for the component pattern: a settings window with tabs, labeled rows, switches, selects, a stepper and a confirmation dialog, over a small tracker model.

In this plugin's `samples/`: `basic` (a small interactive view), `kit` (a tour of the components), `story` (gpui-kit's full gallery), `textfield` (text input with IME and clipboard) and `gpui-examples` (GPUI's own examples). Run one with `cd samples/basic && ceramic clay run web`.

## Tests

```sh
cd tests/unit && ceramic headless run node --setup --assets
```

## License

Apache License 2.0, see [LICENSE](LICENSE). Ported projects, fonts and icons keep their own licenses, listed in [NOTICE.md](NOTICE.md). The few differences with the original GPUI and gpui-kit introduced during the initial port are listed in [docs/DEVIATIONS.md](docs/DEVIATIONS.md); Glaze now evolves on its own.
