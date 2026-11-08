// Ported from gpui-kit 0.8.1: crates/base/src/root.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.Action;
import glaze.AnyElement;
import glaze.AnyView;
import glaze.App;
import glaze.AppContext;
import glaze.Component;
import glaze.ComponentBuilder.ComponentHost;
import glaze.Context;
import glaze.Div;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.Model;
import glaze.Render;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/** Move the focus to the next tab stop, inside the active focus trap if any. */
@:action(namespace = root) class Tab implements Action {}

/** Move the focus to the previous tab stop, inside the active focus trap if any. */
@:action(namespace = root) class TabPrev implements Action {}

/**
 * A presentation layer's retained, per-window facilities.
 *
 * Register during explicit application initialization, before creating
 * windows (`Root.registerPlugin(cx, MyPlugin, (window, cx) -> new MyPlugin())`).
 * The view renders above application content. On every root render, each
 * plugin participates in three stages:
 *
 * 1. `prepare` synchronizes window state before elements are built.
 * 2. `styleSurface` supplies defaults for the root surface.
 * 3. `decorate` wraps the completed surface in presentation owned by the plugin.
 *
 * The plugin's `render` output is mounted as an overlay above application
 * content. Plugins and their overlays are processed in registration order,
 * so later plugins appear above earlier ones. A plugin re-renders the root
 * when its observable state changes or when it is notified; `prepare` and
 * `styleSurface` must not write observable state, because they run during
 * that render.
 *
 * Rust's `RootPlugin` is a trait with default methods: here it is a base
 * class (Rust `style` is `styleSurface`, which would clash with `Styled`).
 */
abstract class RootPlugin extends Model implements Render {

    /**
     * Synchronize settings derived from this plugin with the window.
     */
    public function prepare(window:Window, cx:App):Void {}

    /**
     * Apply this plugin's default styles directly to the root surface.
     * Styles set on the `Root` instance take precedence over plugin defaults.
     */
    public function styleSurface(surface:Div, window:Window, cx:App):Void {}

    /**
     * Add presentation around the completed root surface. Return `surface`
     * unchanged when no outer presentation is needed.
     */
    public function decorate(surface:AnyElement, root:Root, window:Window, cx:App):IntoElement {
        return surface;
    }

    public abstract function render(window:Window, cx:Context<Dynamic>):IntoElement;

}

private typedef PluginFactory = (Window, App) -> RootPlugin;

/**
 * The registered plugin factories (a global), in registration order.
 */
class RootPluginRegistry {

    public final entries:Array<{type:Class<Dynamic>, build:PluginFactory}> = [];

    public function new() {}

}

/**
 * The window's content and overlay host, independent of any styled
 * component library: the kit's window root. It applies the theme to the
 * window body and mounts the dialogs, sheets, notifications, tooltips and
 * the text selection layer through its plugins (`WindowState`).
 *
 * A `Component`, placed with `Root.component().child(view)` where `view` is
 * a component, a `Render` entity or any `AnyView` (Rust `Root::new(view,
 * window, cx)`), usually as the root of a window:
 *
 * ```haxe
 * ui = new Glaze(Kit.window(AppView.component()));
 * // the explicit equivalent
 * ui = new Glaze(Root.component().child(AppView.component()));
 * ```
 *
 * The kit initializes itself when the root is created (`Kit.ensureInit`),
 * so its plugins are built with the window.
 */
class Root extends Component implements Styled {

    static inline final CONTEXT = 'Root';

    /**
     * The hosted views and components, in order (Rust's `view`), given with
     * `.child(...)` / `.children(...)`.
     */
    @prop(unobserved) var content:Null<Array<RootContent>> = null;

    /**
     * The style of the root surface (`Styled`), over the plugins' defaults.
     */
    @prop(unobserved) var surfaceStyle:Null<StyleRefinement> = null;

    @:allow(tests)
    final plugins:Array<RootPlugin> = [];

    /**
     * Rust `root::init`: the key bindings of the root (called by `Base.init`).
     */
    public static function bindKeys(cx:AppContext):Void {
        (cx:App).bindKeys([
            new KeyBinding('tab', new Tab(), CONTEXT),
            new KeyBinding('shift-tab', new TabPrev(), CONTEXT),
            new KeyBinding(glaze.OperatingSystem.current == Mac ? 'cmd-c' : 'ctrl-c', new glaze.kit.base.input.InputActions.Copy(), CONTEXT)
        ]);
    }

    /**
     * Register a presentation plugin once per application. Re-registering its
     * type replaces the factory for future windows rather than mounting it twice.
     */
    public static function registerPlugin<V:RootPlugin>(cx:AppContext, type:Class<V>, build:(Window, Context<V>) -> V):Void {
        final app:App = cx;
        if (!app.hasGlobal(RootPluginRegistry)) {
            app.setGlobal(new RootPluginRegistry(), RootPluginRegistry);
        }
        final factory:PluginFactory = (window, cx) -> {
            final entity:Entity<V> = cx.newEntity((pluginCx:Context<V>) -> build(window, pluginCx));
            return (entity : V);
        };
        tracker.Autorun.unobserve();
        final registry = app.global(RootPluginRegistry);
        tracker.Autorun.reobserve();
        for (entry in registry.entries) {
            if (entry.type == cast type) {
                entry.build = factory;
                return;
            }
        }
        registry.entries.push({type: cast type, build: factory});
    }

    public function new() {
        super();
    }

    /**
     * Hosts `view` (a component, a `Render` entity or any `AnyView`) in this
     * root, after the content given before.
     */
    public function child(view:RootContent):Root {
        if (view != null) {
            var list = content;
            if (list == null) {
                list = [];
            }
            list.push(view);
            (this : Root).content(list);
        }
        return this;
    }

    /**
     * Hosts `views` in this root, after the content given before (null
     * entries are skipped).
     */
    public function children(views:Array<RootContent>):Root {
        for (view in views) {
            child(view);
        }
        return this;
    }

    /**
     * Builds the plugins of the window. The kit initializes itself here when
     * the app did not: its root plugin (`WindowState`) must be registered
     * before the plugins are built.
     *
     * A plugin's rendering is attributed to the plugin's own view, a child of
     * the root, so its observable state re-renders that view (Rust observes
     * every plugin entity to notify the root).
     */
    override function init(window:Window, cx:App):Void {
        glaze.kit.Kit.ensureInit(cx);
        tracker.Autorun.unobserve();
        final registry = cx.tryGlobal(RootPluginRegistry);
        tracker.Autorun.reobserve();
        if (registry != null) {
            for (entry in registry.entries.copy()) {
                plugins.push(entry.build(window, cx));
            }
        }
    }

    /**
     * The original application content entity (Rust `view()`): the first
     * hosted view, or `null` when the root hosts a component.
     */
    public function contentView():Null<AnyView> {
        final list = content;
        if (list == null)
            return null;
        for (item in list) {
            final view = item.view();
            if (view != null)
                return view;
        }
        return null;
    }

    /**
     * Find a presentation plugin owned by this window.
     */
    public function plugin<V:RootPlugin>(type:Class<V>):Null<V> {
        for (plugin in plugins) {
            if (Std.isOfType(plugin, type))
                return cast plugin;
        }
        return null;
    }

    public function style():StyleRefinement {
        var style = surfaceStyle;
        if (style == null) {
            style = new StyleRefinement();
            (this : Root).surfaceStyle(style);
        }
        return style;
    }

    /**
     * The `Root` of `window`. Throws when the window's root view is not a `Root`.
     */
    public static function read(window:Window, cx:AppContext):Root {
        final root = tryRead(window);
        if (root == null)
            throw 'window must have a Base Root';
        return root;
    }

    /**
     * The `Root` of `window`, or null.
     */
    public static function tryRead(window:Window):Null<Root> {
        final host = tryReadHost(window);
        if (host == null)
            return null;
        final instance = host.instance;
        return Std.isOfType(instance, Root) ? cast instance : null;
    }

    /**
     * The entity drawing the `Root` of `window` as its root view, or null.
     */
    static function tryReadHost(window:Window):Null<ComponentHost> {
        final view = window.rootView();
        if (view == null)
            return null;
        final model:Model = view;
        if (!Std.isOfType(model, ComponentHost))
            return null;
        final host:ComponentHost = cast model;
        return Std.isOfType(host.instance, Root) ? host : null;
    }

    /**
     * Updates the `Root` of `window` in the context of the entity drawing it.
     */
    public static function update<R>(window:Window, cx:AppContext, f:(Root, Window, Context<Dynamic>) -> R):R {
        final host = tryReadHost(window);
        if (host == null)
            throw 'window must have a Base Root';
        final entity:Entity<ComponentHost> = host;
        return entity.update(cx, (host, hostCx) -> f(cast host.instance, window, cast hostCx));
    }

    function onActionTab(_:Tab, window:Window, cx:App):Void {
        advanceFocus(window, cx, (window, cx) -> window.focusNext(cx));
    }

    function onActionTabPrev(_:TabPrev, window:Window, cx:App):Void {
        advanceFocus(window, cx, (window, cx) -> window.focusPrev(cx));
    }

    function onActionCopy(_:glaze.kit.base.input.InputActions.Copy, window:Window, cx:App):Void {
        final text = StringTools.trim(TextSelection.selectedText(window, cx));
        if (text.length == 0) {
            cx.propagate();
            return;
        }
        cx.writeToClipboard(glaze.ClipboardItem.newString(text));
    }

    /**
     * Scan at most one cycle of the rendered tab order, preserving
     * containment regardless of how many controls exist behind a modal.
     */
    @:allow(tests)
    static function advanceFocus(window:Window, cx:App, advance:(Window, App) -> Void):Void {
        final container = FocusTrap.activeFocusTrap(window, cx);
        if (container == null) {
            advance(window, cx);
            return;
        }

        advance(window, cx);
        // GPUI's tab order can cycle short of the whole window (a stop whose
        // previous stop is itself), so the walk ends at the first repeated stop,
        // not only on a return to the one it began with.
        final visited:Array<Null<FocusHandle>> = [];
        while (!container.containsFocused(window, cx)) {
            final focused = window.focused(cx);
            if (visited.indexOf(focused) != -1) {
                // No tab stop in the trap is reachable. Its own handle remains a
                // safe focus target even when excluded from ordinary tab order.
                container.focus(window, cx);
                break;
            }
            visited.push(focused);
            advance(window, cx);
        }
    }

    function render(window:Window, cx:App):IntoElement {
        for (plugin in plugins) {
            plugin.prepare(window, cx);
        }
        final surfaceDiv = div()
            .id('root')
            .keyContext(CONTEXT)
            .onAction(Tab, (action, window, cx) -> onActionTab(action, window, cx))
            .onAction(TabPrev, (action, window, cx) -> onActionTabPrev(action, window, cx))
            .onAction(glaze.kit.base.input.InputActions.Copy, (action, window, cx) -> onActionCopy(action, window, cx))
            .relative()
            .sizeFull()
            .child(new TextSelectionLayer());
        final list = content;
        if (list != null) {
            for (item in list) {
                surfaceDiv.child(item.intoElement());
            }
        }
        surfaceDiv.child(
            div()
                .absolute()
                .inset0()
                .children([for (plugin in plugins) (plugin : IntoElement)])
        );
        for (plugin in plugins) {
            plugin.styleSurface(surfaceDiv, window, cx);
        }
        final rootStyle = surfaceStyle;
        if (rootStyle != null) {
            surfaceDiv.refineStyle(rootStyle);
        }
        var surface:AnyElement = surfaceDiv.intoAnyElement();
        for (plugin in plugins) {
            surface = plugin.decorate(surface, this, window, cx);
        }
        return surface;
    }

}
