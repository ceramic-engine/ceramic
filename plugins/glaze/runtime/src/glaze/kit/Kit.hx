// Ported from gpui-kit 0.8.1: crates/component/src/lib.rs (init), crates/component/src/global_state.rs (init),
// crates/component/src/root.rs (init)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit;

import glaze.App;
import glaze.Glaze;
import glaze.AppContext;
import glaze.CeramicAssetSource;
import glaze.kit.base.Base;
import glaze.kit.base.GlobalState;
import glaze.kit.base.Root;
import glaze.kit.base.RootContent;
import glaze.kit.theme.Theme;
// Not used here: the dock's actions are modules of their own that only the
// dock refers to. Importing them keeps them registered (`ActionRegistry`, built
// by name from a keymap) in an app that does not use the dock, as when the
// kit's initialization loaded the dock.
import glaze.kit.dock.ClosePanel;
import glaze.kit.dock.ToggleZoom;

/**
 * The styled component library of GPUI Kit (the `gpui-component` crate).
 *
 * Rust's `gpui_component::init(cx)` is implicit in Glaze: the kit
 * initializes itself for an app the first time it is needed (a `Root` is
 * created, a component reads the theme, a setting is changed: `setLocale`,
 * `Theme.setMode`, a theme is loaded, `Theme.setScrollbarMode`,
 * `Theme.syncScrollbarAppearance`, `GlobalState.setAppMenus`...). A setting
 * changed before the first render initializes the kit and then applies, so
 * the first render already has the right locale and theme.
 */
class Kit {

    /**
     * The app initialized last: the fast path of `ensureInit`, which runs
     * on every theme read.
     */
    static var initializedApp:Null<App> = null;

    /**
     * Initializes the components for the app of `cx`, once per app.
     *
     * There is no need to call it: see `ensureInit`. It is kept for the code
     * that initializes at its entry point like the Rust applications do.
     */
    public static inline function init(cx:AppContext):Void {
        ensureInit(cx);
    }

    /**
     * Initializes the components for the app of `cx` if that was not done
     * yet. Idempotent and cheap once done: the kit calls it from its entry
     * points (`Root`, `Theme.global`, the settings).
     */
    public static function ensureInit(cx:AppContext):Void {
        final app:App = cx;
        if (app == initializedApp) return;
        tracker.Autorun.unobserve();
        final done = app.hasGlobal(KitInitialized);
        if (!done) {
            // Marked before the initialization runs: the kit's own init
            // path reads the theme and the globals, which come back here.
            app.setGlobal(KitInitialized.instance, KitInitialized);
        }
        tracker.Autorun.reobserve();
        initializedApp = app;
        if (done) return;
        tracker.Autorun.unobserve();
        try {
            initApp(app);
        }
        catch (e:Dynamic) {
            tracker.Autorun.reobserve();
            throw e;
        }
        tracker.Autorun.reobserve();
    }

    /**
     * Rust `gpui_component::init`.
     *
     * Ported so far: the theme, the global state, the root plugin
     * (`WindowState`) and the Base layer. The other modules register their
     * globals and key bindings here as they are ported.
     *
     * Every key binding is registered here, in the Rust order, whether the
     * app uses the component or not (the order decides which binding wins).
     * The bindings live in small classes of their own (`DataTableKeys`,
     * `CommandKeys`...) that do not refer to their component, so that a
     * component the app never uses is removed by `-dce full`. Keep it that
     * way: calling a component class from here keeps it in every app.
     */
    static function initApp(cx:AppContext):Void {
        // The icons are embedded in the code (`IconName`): no file to load
        final app:App = cx;
        final source = app.assetSource();
        if (source is CeramicAssetSource) {
            IconName.addTo(cast source);
        }
        Theme.initTheme(cx);
        // Rust `global_state::init`: the legacy initialization point of the Base global
        GlobalState.init(cx);
        #if glaze_inspector
        // Rust `inspector::init` (feature `inspector`)
        glaze.kit.inspector.Inspector.init(cx);
        #end
        Root.registerPlugin(cx, WindowState, (window, cx) -> new WindowState(window, cx));
        Base.init(cx);
        // Rust order: gpui_base, input, diff, date_picker, dock, sheet... (the
        // language service of gpui-kit's code editor, `input::init`, is not
        // part of Glaze: its code editor is Cityscape)
        glaze.kit.diff.DiffActions.init(cx);
        // `DatePickerState.init`
        glaze.kit.time.DatePickerKeys.init(cx);
        // `DockSkin.init` (Rust `dock::init`): the panel registry global
        @:privateAccess glaze.kit.base.dock.PanelRegistry.init(cx);
        glaze.kit.sheet.Sheet.bindKeys(cx);
        // `ListState.init`
        glaze.kit.list.ListKeys.init(cx);
        // `CommandState.init`
        glaze.kit.command.CommandKeys.init(cx);
        // `Carousel.bindKeys`
        glaze.kit.carousel.CarouselKeys.bindKeys(cx);
        // Kept as is: `WindowState`, registered above, uses the notification list
        glaze.kit.notification.Notification.NotificationList.init(cx);
        // Rust order: ... popover, questionnaire, menu, table, tooltip
        // `Menus.init`: `AppMenuBar.init`, then `PopupMenu.init`
        glaze.kit.menu.AppMenuBarKeys.init(cx);
        glaze.kit.menu.PopupMenuKeys.init(cx);
        // `DataTable.bindKeys`
        glaze.kit.table.DataTableKeys.bindKeys(cx);
    }

    /**
     * `Kit.window(view)` wraps the view in the kit's window root (`Root`):
     * theme on the window body, dialogs, sheets, notifications, tooltips,
     * text selection. It creates no window itself; `new Glaze(...)` carries
     * the GPUI window.
     *
     * ```haxe
     * ui = new Glaze(Kit.window(AppView.component()));
     * ```
     *
     * `view` is a component placed with `X.component()...`, a `Render`
     * entity or any `AnyView`. `Root.component().child(view)` is the
     * explicit equivalent.
     */
    public static function window(view:RootContent):Root {
        return Root.component().child(view);
    }

    /**
     * The current locale (Rust `locale()`).
     */
    public static inline function locale():String {
        return I18n.locale();
    }

    /**
     * Sets the locale (Rust `set_locale`). Initializes the kit of `cx`'s
     * app (the current app when `cx` is not given) first, so a locale set
     * before the first render applies to it.
     */
    public static function setLocale(locale:String, ?cx:AppContext):Void {
        ensureInit(cx != null ? cx : Glaze.app);
        I18n.setLocale(locale);
    }

}

/**
 * The global marking an app whose kit is initialized.
 */
private class KitInitialized {

    public static final instance:KitInitialized = new KitInitialized();

    function new() {}

}
