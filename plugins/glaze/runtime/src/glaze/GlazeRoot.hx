// New code for the Haxe port of GPUI (no GPUI origin): what a window takes as
// its root. See NOTICE.md.
package glaze;

/**
 * The root of a window, as `new Glaze(...)` and `Window.open` take it: the
 * builder of GPUI's `open_window`, `(window, cx) -> AnyView`, or directly a
 * view, built when the window is:
 *
 * - a `Component` placed with `X.component()...` (the component lives as
 *   long as the window);
 * - a `Render` entity, or an `Entity<T>` of one;
 * - any `AnyView`.
 *
 * ```haxe
 * new Glaze(SettingsWindow.component().settings(settings));
 * new Glaze(Kit.window(SettingsWindow.component().settings(settings)));
 * new Glaze((window, cx) -> cx.newEntity(cx -> new MyView()));
 * ```
 */
abstract GlazeRoot((Window, App) -> AnyView) from (Window, App) -> AnyView to (Window, App) -> AnyView {

    inline function new(build:(Window, App) -> AnyView) {
        this = build;
    }

    /**
     * A `Component` as the root view: its root view entity is created when
     * the window is built, like the view of a builder.
     */
    @:from static function fromComponent(component:Component):GlazeRoot {
        return new GlazeRoot((window, cx) -> ComponentBuilder.rootView(component, cx));
    }

    @:from static function fromAnyView(view:AnyView):GlazeRoot {
        return new GlazeRoot((window, cx) -> view);
    }

    @:from static function fromRender(view:Render):GlazeRoot {
        final anyView:AnyView = view;
        return new GlazeRoot((window, cx) -> anyView);
    }

    @:from static function fromEntity<T:Model & Render>(entity:Entity<T>):GlazeRoot {
        final anyView:AnyView = entity;
        return new GlazeRoot((window, cx) -> anyView);
    }

    /**
     * Builds the root view of `window`.
     */
    public inline function build(window:Window, cx:App):AnyView {
        return this(window, cx);
    }

}
