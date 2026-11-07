// Ported from gpui-kit 0.8.1: crates/base/src/root.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.Action;
import gpui.AnyElement;
import gpui.AnyView;
import gpui.App;
import gpui.AppContext;
import gpui.Context;
import gpui.Div;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.KeyBinding;
import gpui.Model;
import gpui.Render;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;

import gpui.Prelude.*;

using gpui.base.StyledExt;

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
    public function prepare(window:Window, cx:Context<Dynamic>):Void {}

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

private typedef PluginFactory = (Window, Context<Root>) -> RootPlugin;

/**
 * The registered plugin factories (a global), in registration order.
 */
class RootPluginRegistry {

    public final entries:Array<{type:Class<Dynamic>, build:PluginFactory}> = [];

    public function new() {}

}

/**
 * The window's content and overlay host, independent of any styled
 * component library.
 *
 */
class Root extends Model implements Render implements Styled {

    static inline final CONTEXT = 'Root';

    final view:AnyView;

    final rootStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final plugins:Array<RootPlugin> = [];

    public static function init(cx:AppContext):Void {
        (cx:App).bindKeys([
            new KeyBinding('tab', new Tab(), CONTEXT),
            new KeyBinding('shift-tab', new TabPrev(), CONTEXT),
            new KeyBinding(gpui.OperatingSystem.current == Mac ? 'cmd-c' : 'ctrl-c', new gpui.base.input.InputActions.Copy(), CONTEXT)
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

    /**
     * Creates a root for `view`. Build it in the window's root view builder:
     * `Window.open(app, options, (window, cx) -> cx.newEntity(rootCx -> new Root(view, window, rootCx)))`.
     *
     * A plugin's rendering is attributed to the plugin's own view, a child of
     * the root, so its observable state re-renders that view (Rust observes
     * every plugin entity to notify the root).
     */
    public function new(view:AnyView, window:Window, cx:Context<Root>) {
        super();
        this.view = view;
        tracker.Autorun.unobserve();
        final registry = cx.app.tryGlobal(RootPluginRegistry);
        tracker.Autorun.reobserve();
        if (registry != null) {
            for (entry in registry.entries.copy()) {
                plugins.push(entry.build(window, cx));
            }
        }
    }

    /**
     * The original application content entity.
     */
    public inline function contentView():AnyView {
        return view;
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

    public inline function style():StyleRefinement {
        return rootStyle;
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
        final view = window.rootView();
        if (view == null)
            return null;
        final model:Model = view;
        return Std.isOfType(model, Root) ? cast model : null;
    }

    public static function update<R>(window:Window, cx:AppContext, f:(Root, Window, Context<Root>) -> R):R {
        final root:Entity<Root> = read(window, cx);
        return root.update(cx, (root, cx) -> f(root, window, cx));
    }

    function onActionTab(_:Tab, window:Window, cx:App):Void {
        advanceFocus(window, cx, (window, cx) -> window.focusNext(cx));
    }

    function onActionTabPrev(_:TabPrev, window:Window, cx:App):Void {
        advanceFocus(window, cx, (window, cx) -> window.focusPrev(cx));
    }

    function onActionCopy(_:gpui.base.input.InputActions.Copy, window:Window, cx:App):Void {
        final text = StringTools.trim(TextSelection.selectedText(window, cx));
        if (text.length == 0) {
            cx.propagate();
            return;
        }
        cx.writeToClipboard(gpui.ClipboardItem.newString(text));
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

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        for (plugin in plugins) {
            plugin.prepare(window, cast cx);
        }
        final content = div()
            .id('root')
            .keyContext(CONTEXT)
            .onAction(Tab, (action, window, cx) -> onActionTab(action, window, cx))
            .onAction(TabPrev, (action, window, cx) -> onActionTabPrev(action, window, cx))
            .onAction(gpui.base.input.InputActions.Copy, (action, window, cx) -> onActionCopy(action, window, cx))
            .relative()
            .sizeFull()
            .child(new TextSelectionLayer())
            .child(view.intoAnyElement())
            .child(
                div()
                    .absolute()
                    .inset0()
                    .children([for (plugin in plugins) (plugin : IntoElement)])
            );
        for (plugin in plugins) {
            plugin.styleSurface(content, window, cx.app);
        }
        var surface:AnyElement = content.refineStyle(rootStyle).intoAnyElement();
        for (plugin in plugins) {
            surface = plugin.decorate(surface, this, window, cx.app);
        }
        return surface;
    }

}
