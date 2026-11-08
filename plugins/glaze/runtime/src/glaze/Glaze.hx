package glaze;

import glaze.Window.WindowOptions;

/**
 * A Ceramic visual showing a Glaze window: the simplest way to put a Glaze
 * interface in a Ceramic scene.
 *
 * ```haxe
 * final ui = new Glaze(AppView.component());
 * ui.size(width, height);
 * add(ui);
 * ```
 *
 * It opens a `Window` (GPUI's window, see `Window.open`) whose root view is
 * `root` (a `Component`, a `Render` entity, an `AnyView`, or the builder
 * `(window, cx) -> AnyView` of GPUI's `open_window`; see `GlazeRoot`), draws
 * it, resizes it with the visual and closes it when the visual is destroyed.
 * The window stays available as `window` for the rest of the GPUI API. With
 * the kit, `new Glaze(Kit.window(AppView.component()))` puts the view under
 * the kit's window root.
 *
 * Glaze is the Haxe port of GPUI (Zed's UI framework) and gpui-kit, built
 * into Ceramic as the `glaze` plugin. See NOTICE.md.
 */
class Glaze extends ceramic.Visual {

    public static inline final VERSION:String = '0.0.1';

    /**
     * The current GPUI app (the `cx` of the signatures): the last `App`
     * created, or a default one created on first access. `glaze.App` is
     * GPUI's app and Ceramic has its own `ceramic.App`, so the current GPUI
     * context is reached from here.
     *
     * ```haxe
     * Glaze.app.bindKeys([...]);
     * ```
     */
    public static var app(get, set):App;
    static var _app:Null<App> = null;
    static function get_app():App {
        if (_app == null) {
            // A default app, with a `CeramicDispatcher` (its constructor sets `app`)
            new App();
        }
        return _app;
    }
    static function set_app(app:App):App {
        return _app = app;
    }

    /**
     * The window shown by this visual. `null` once the visual is destroyed.
     */
    public var window(default, null):Window;

    /**
     * Opens a window whose root view is `root` and shows it in this visual.
     * @param root The root view of the window: a component placed with `X.component()...`, a `Render` entity, an `AnyView`, or the builder `(window, cx) -> AnyView` (Rust `open_window`'s builder)
     * @param options Window options; the size of the visual is taken from them (512 x 512 by default)
     * @param app The app owning the window, `Glaze.app` by default
     */
    public function new(root:GlazeRoot, ?options:WindowOptions, ?app:App) {

        super();

        if (options == null) options = {};
        if (app == null) app = Glaze.app;

        _width = options.width;
        _height = options.height;

        window = Window.open(app, options, root);
        add(window.renderable);

    }

    override function set_width(width:Float):Float {

        if (_width == width) return width;
        super.set_width(width);
        if (window != null) window.resize(width, _height);
        return width;

    }

    override function set_height(height:Float):Float {

        if (_height == height) return height;
        super.set_height(height);
        if (window != null) window.resize(_width, height);
        return height;

    }

    override function destroy() {

        if (window != null) {
            window.destroy();
            window = null;
        }

        super.destroy();

    }

}
