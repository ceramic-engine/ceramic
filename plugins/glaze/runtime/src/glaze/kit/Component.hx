// Ported from gpui-kit 0.8.1: crates/component/src/lib.rs (init), crates/component/src/global_state.rs (init),
// crates/component/src/root.rs (init)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component;

import gpui.AppContext;
import gpui.base.Base;
import gpui.base.GlobalState;
import gpui.base.Root;
import gpui.component.theme.Theme;

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
        #if gpui_inspector
        // Rust `inspector::init` (feature `inspector`)
        gpui.component.inspector.Inspector.init(cx);
        #end
        Root.registerPlugin(cx, WindowState, (window, cx) -> new WindowState(window, cx));
        Base.init(cx);
        // Rust order: gpui_base, input, diff, date_picker, dock, sheet...
        gpui.component.input.ComponentLanguages.init(cx);
        gpui.component.diff.DiffActions.init(cx);
        gpui.component.time.DatePicker.DatePickerState.init(cx);
        gpui.component.dock.DockSkin.init(cx);
        gpui.component.sheet.Sheet.init(cx);
        gpui.component.list.ListState.init(cx);
        gpui.component.command.CommandState.init(cx);
        gpui.component.carousel.Carousel.init(cx);
        gpui.component.notification.Notification.NotificationList.init(cx);
        // Rust order: ... popover, questionnaire, menu, table, tooltip
        gpui.component.menu.Menus.init(cx);
        gpui.component.table.DataTable.init(cx);
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
