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

Add a `Glaze` visual to a scene, with the view it shows:

```haxe
import glaze.*;
import glaze.Prelude.*;

class MainScene extends ceramic.Scene {

    var ui:Glaze;

    override function create() {
        ui = new Glaze((window, cx) -> cx.newEntity((cx:Context<Counter>) -> new Counter()));
        ui.size(width, height);
        add(ui);
    }

    override function resize(width:Float, height:Float) {
        ui.size(width, height);
    }

}

class Counter extends Model implements Render {

    @observe var count:Int = 0;

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().p4().textColor(hsla(0, 0, 0.9, 1)).fontFamily('Inter')
            .child(
                div().id('button').px3().py1().roundedMd().bg(hsla(0.6, 0.6, 0.5, 1))
                    .onClick((_, _, _) -> count++)
                    .child('Clicked ' + count + ' times')
            );
    }

}
```

`Glaze` is a regular Ceramic visual: it resizes its window with it and closes it when destroyed. `ui.window` gives the GPUI window behind it.

For the components, wrap your view in a `Root`, which applies the theme. The kit initializes itself the first time it is needed; a setting made before the first render (`Theme.change`, `Kit.setLocale`...) initializes it too, then applies:

```haxe
ui = new Glaze(Root.builder(AppView.component()));
```

`Root.builder(view)` is the root view builder `new Glaze(...)` takes: it creates the `Root` of the window around `view`, a `Component`, an entity view or any `AnyView`. The explicit form is `(window, cx) -> cx.newEntity((cx:Context<Root>) -> new Root(view, window, cx))`.

Then use them like in Rust, with camelCase names: `new Button('save').primary().label('Save').onClick(...)`. gpui-kit's documentation applies; [docs/PORTING.md](docs/PORTING.md) lists the differences.

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

Inside the class a prop is read by its name (`label`); outside, the field is `labelProp`. A component with props only is rebuilt on every render of its parent, like an element. A component with an `@observe`, `@compute` or `@autorun` field (or `init()`, `destroy()`, or the `@persist` meta) is persistent: created on the first render, found again on the next ones by the position of the call in the code (or by `.at(key)` in a loop, or when the same class is placed twice on one line), rendered again only when a prop or an observable it reads changes, destroyed when it leaves the tree. Its constructor runs once (window dependent setup goes in `init(window, cx)`), `destroy()` runs when it leaves the tree. The observables are tracker's: `@observe` fields of your models read during `render` redraw the components that read them. Element listeners take short callbacks: `.onClick(() -> ...)` or `.onClick(event -> ...)`.

## Samples

In `samples/`: `basic` (a small interactive view), `kit` (a tour of the components), `story` (gpui-kit's full gallery), `textfield` (text input with IME and clipboard) and `gpui-examples` (GPUI's own examples). Run one with `cd samples/basic && ceramic clay run web`.

## Tests

```sh
cd tests/unit && ceramic headless run node --setup --assets
```

## License

Apache License 2.0, see [LICENSE](LICENSE). Ported projects, fonts and icons keep their own licenses, listed in [NOTICE.md](NOTICE.md).

The few differences with the original GPUI and gpui-kit introduced during the initial port are listed in [docs/DEVIATIONS.md](docs/DEVIATIONS.md). Glaze now evolves on its own.
