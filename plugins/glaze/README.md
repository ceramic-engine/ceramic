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

Open a window with a view:

```haxe
import glaze.*;
import glaze.Prelude.*;

class MainScene extends ceramic.Scene {

    override function create() {
        final cx = App.current;
        final window = Window.open(cx, {width: width, height: height}, (window, cx) -> {
            return cx.newEntity((cx:Context<Counter>) -> new Counter());
        });
        add(window.renderable);
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

For the components, initialize the kit once and wrap your view in a `Root`, which applies the theme:

```haxe
cx.update(cx -> glaze.kit.Component.init(cx));

Window.open(cx, {width: width, height: height}, (window, cx) -> {
    final view = cx.newEntity((cx:Context<MyView>) -> new MyView());
    return cx.newEntity((cx:Context<Root>) -> new Root(view, window, cx));
});
```

Then use them like in Rust, with camelCase names: `new Button('save').primary().label('Save').onClick(...)`. gpui-kit's documentation applies; [PORTING.md](PORTING.md) lists the differences.

## Samples

In `samples/`: `basic` (a small interactive view), `kit` (a tour of the components), `story` (gpui-kit's full gallery), `textfield` (text input with IME and clipboard) and `gpui-examples` (GPUI's own examples). Run one with `cd samples/basic && ceramic clay run web`.

## Tests

```sh
cd tests/unit && ceramic headless run node --setup --assets
```

## License

Apache License 2.0, see [LICENSE](LICENSE). Ported projects, fonts and icons keep their own licenses, listed in [NOTICE.md](NOTICE.md). The deliberate differences with the original GPUI are documented in [DEVIATIONS.md](DEVIATIONS.md).
