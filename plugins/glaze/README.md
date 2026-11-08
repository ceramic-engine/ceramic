# Glaze

Glaze is a UI framework for Ceramic. It is a Haxe port of [GPUI](https://github.com/zed-industries/zed/tree/main/crates/gpui), the framework behind the Zed editor, and of [gpui-kit](https://github.com/longbridge/gpui-kit), its component library: `glaze` for the core, `glaze.kit` for the components.

Interfaces are built with chained calls, laid out with flexbox, and redrawn automatically when the data they read changes. They run wherever Ceramic runs: desktop, web, mobile, Unity.

GPUI is by Zed Industries and gpui-kit by Longbridge, both Apache-2.0. See [NOTICE.md](NOTICE.md).

## Usage

Enable the plugin in `ceramic.yml`:

```yaml
app:
    plugins:
        - glaze
```

Add a `Glaze` visual to a scene, with the component it shows:

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

`Glaze` is a regular Ceramic visual: it resizes its window with it and closes it when destroyed. `ui.window` gives the GPUI window behind it. `Glaze.app` is the GPUI app context (the `cx` of the signatures) for the calls made outside a render, such as `Glaze.app.bindKeys([...])`.

`new Glaze(...)` takes the root view directly: a component placed with `X.component()...`, an entity view, any `AnyView`, or the `(window, cx) -> AnyView` builder of GPUI's `open_window`.

For the components (`glaze.kit`), put the view under the kit's window root. The kit initializes itself the first time it is needed; a setting made before the first render (`Theme.change(ThemeMode.Dark, null, Glaze.app)`, `Kit.setLocale`...) initializes it too, then applies:

```haxe
ui = new Glaze(Kit.window(AppView.component()));
```

`Kit.window(view)` wraps the view in the kit's window root (`Root`): theme on the window body, dialogs, sheets, notifications, tooltips, text selection. It creates no window itself; `new Glaze(...)` carries the GPUI window. `Root.component().child(view)` is the explicit equivalent (`Root` is itself a `Component`). Then place the components like your own, with camelCase names: `Button.component('save').primary().label('Save').onClick(() -> save())`. gpui-kit's documentation applies; [docs/PORTING.md](docs/PORTING.md) lists the differences.

## Components

A `glaze.Component` is a class that reads your data and describes a piece of interface. Its `@prop` fields become chained setters, `children` receives what the parent passes with `.child(...)`, and `X.component()` places it in the tree:

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

Inside the class a prop is read by its name (`label`); outside, the field is `labelProp`. A component with props only is rebuilt on every render of its parent, like an element. A component with an `@observe`, `@compute` or `@autorun` field (or `init()`, `destroy()`, or the `@persist` meta) is persistent: created on the first render, found again on the next ones by the position of the call in the code (or by `.at(key)` in a loop, or when the same class is placed twice on one line), rendered again only when a prop or an observable it reads changes, destroyed when it leaves the tree. Its constructor runs once (window dependent setup goes in `init(window, cx)`), `destroy()` runs when it leaves the tree. A persistent component is a `tracker.Owner`: `this` is a valid owner for model events, `Timer.interval(this, ...)`, tweens and immediates, and those subscriptions end when the component leaves the tree (a stateless component is rebuilt at every render and owns nothing: passing `this` as an owner there does not compile). The observables are tracker's: `@observe` fields of your models read during `render` redraw the components that read them. Element listeners take short callbacks: `.onClick(() -> ...)` or `.onClick(event -> ...)`.

## Samples

The `glaze-settings` sample of [ceramic-samples](https://github.com/ceramic-engine/ceramic-samples) is the reference for the component pattern. In `samples/`: `basic` (a small interactive view), `kit` (a tour of the components), `story` (gpui-kit's full gallery), `textfield` (text input with IME and clipboard) and `gpui-examples` (GPUI's own examples). Run one with `cd samples/basic && ceramic clay run web`.

## Tests

```sh
cd tests/unit && ceramic headless run node --setup --assets
```

## License

Apache License 2.0, see [LICENSE](LICENSE). Ported projects, fonts and icons keep their own licenses, listed in [NOTICE.md](NOTICE.md).

The few differences with the original GPUI and gpui-kit introduced during the initial port are listed in [docs/DEVIATIONS.md](docs/DEVIATIONS.md). Glaze now evolves on its own.
