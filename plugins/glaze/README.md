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

`glaze.kit` is gpui-kit's component library: buttons, inputs, selects, menus, dialogs, tabs, tables, trees, charts, a code editor, markdown views, a dock system, and more. Wrap your interface in the kit's window root, which carries the theme, dialogs, sheets, notifications, tooltips and text selection:

```haxe
ui = new Glaze(Kit.window(AppView.component()));
```

Then place the kit components like your own:

```haxe
Button.component('save').primary().label('Save').onClick(() -> save())
Input.component().at('name').placeholder('Your name').value(model.name).onChange(v -> model.name = v)
Select.component().at('theme').options(themes).value(prefs.theme).onChange(id -> prefs.theme = id)
```

The kit initializes itself the first time it is needed. A setting made before the first render initializes it too, then applies: `Theme.change(ThemeMode.Dark, null, Glaze.app)`, `Kit.setLocale('fr')`. Stateful controls (`Input`, `Select`, `Slider`) keep their own state under the identity of their call, like persistent components; `.value(v)` makes them controlled.

The names are gpui-kit's in camelCase, so its documentation applies; [docs/PORTING.md](docs/PORTING.md) lists the differences. `Kit.window(view)` is `Root.component().child(view)`: `Root` is itself a component.

## Samples

The `glaze-settings` sample of [ceramic-samples](https://github.com/ceramic-engine/ceramic-samples) is the reference for the component pattern: a settings window with tabs, labeled rows, switches, selects, a stepper and a confirmation dialog, over a small tracker model.

In this plugin's `samples/`: `basic` (a small interactive view), `kit` (a tour of the components), `story` (gpui-kit's full gallery), `textfield` (text input with IME and clipboard) and `gpui-examples` (GPUI's own examples). Run one with `cd samples/basic && ceramic clay run web`.

## Tests

```sh
cd tests/unit && ceramic headless run node --setup --assets
```

## License

Apache License 2.0, see [LICENSE](LICENSE). Ported projects, fonts and icons keep their own licenses, listed in [NOTICE.md](NOTICE.md). The few differences with the original GPUI and gpui-kit introduced during the initial port are listed in [docs/DEVIATIONS.md](docs/DEVIATIONS.md); Glaze now evolves on its own.
