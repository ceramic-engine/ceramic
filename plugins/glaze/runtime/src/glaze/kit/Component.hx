// Ported from gpui-kit 0.8.1: crates/component/src/lib.rs (init), crates/component/src/global_state.rs (init),
// crates/component/src/root.rs (init)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit;

import glaze.AppContext;
import glaze.kit.base.Base;
import glaze.kit.base.GlobalState;
import glaze.kit.base.Root;
import glaze.kit.theme.Theme;

/**
 * The styled component library of GPUI Kit (the `gpui-component` crate).
 */
class Component {

    /**
     * Initialize the components. You must call it at your application's
     * entry point, before opening windows.
     *
     * Ported so far: the theme, the global state, the root plugin
     * (`WindowState`) and the Base layer. The other modules register their
     * globals and key bindings here as they are ported.
     */
    public static function init(cx:AppContext):Void {
        Theme.init(cx);
        // Rust `global_state::init`: the legacy initialization point of the Base global
        GlobalState.init(cx);
        #if glaze_inspector
        // Rust `inspector::init` (feature `inspector`)
        glaze.kit.inspector.Inspector.init(cx);
        #end
        Root.registerPlugin(cx, WindowState, (window, cx) -> new WindowState(window, cx));
        Base.init(cx);
        // Rust order: gpui_base, input, diff, date_picker, dock, sheet...
        glaze.kit.input.ComponentLanguages.init(cx);
        glaze.kit.diff.DiffActions.init(cx);
        glaze.kit.time.DatePicker.DatePickerState.init(cx);
        glaze.kit.dock.DockSkin.init(cx);
        glaze.kit.sheet.Sheet.init(cx);
        glaze.kit.list.ListState.init(cx);
        glaze.kit.command.CommandState.init(cx);
        glaze.kit.carousel.Carousel.init(cx);
        glaze.kit.notification.Notification.NotificationList.init(cx);
        // Rust order: ... popover, questionnaire, menu, table, tooltip
        glaze.kit.menu.Menus.init(cx);
        glaze.kit.table.DataTable.init(cx);
    }

    /**
     * The current locale (Rust `locale()`).
     */
    public static inline function locale():String {
        return I18n.locale();
    }

    /**
     * Sets the locale (Rust `set_locale`).
     */
    public static inline function setLocale(locale:String):Void {
        I18n.setLocale(locale);
    }

}
