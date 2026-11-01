// Ported from gpui-kit 0.8.1: crates/component/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.dock;

import gpui.App;
import gpui.Context;
import gpui.IntoElement;
import gpui.Window;
import gpui.component.button.Button;
import gpui.component.menu.PopupMenu;

/**
 * What a panel draws, on top of the behavior `gpui.base.dock.Panel`
 * defines.
 *
 * `gpui-base` owns panel behavior: the name, the id, closability, visibility
 * and the activation callbacks. Everything a tab bar actually draws (the
 * title, the tab name, the toolbar, the ellipsis menu) is presentation and
 * lives here.
 *
 * Every method has a default in `PanelBase`, so a panel that extends it gets
 * an unnamed title and no chrome.
 */
interface Panel extends gpui.base.dock.Panel {

    /**
     * The short name shown when a tab bar has no room for the full title.
     *
     * Used by an already-collapsed tab group, where only the strip of tabs is
     * on screen.
     */
    function tabName(cx:App):Null<String>;

    /**
     * The panel's title, as an element rather than a string so a panel can
     * draw an icon, a badge, or a styled fragment in the tab.
     */
    function title(window:Window, cx:Context<Dynamic>):IntoElement;

    /**
     * Colors for the title, for a panel that wants its tab to stand out.
     */
    function titleStyle(cx:App):Null<TitleStyle>;

    /**
     * An element pinned to the trailing end of the title bar.
     */
    function titleSuffix(window:Window, cx:Context<Dynamic>):Null<IntoElement>;

    /**
     * Buttons for the title bar's toolbar.
     */
    function toolbarButtons(window:Window, cx:Context<Dynamic>):Null<Array<Button>>;

    /**
     * Entries the panel adds to the title bar's ellipsis menu.
     */
    function dropdownMenu(menu:PopupMenu, window:Window, cx:Context<Dynamic>):PopupMenu;

    /**
     * Where the zoom affordance appears, or `null` for nowhere.
     *
     * `null` withholds the whole affordance, not just the button: the
     * `ToggleZoom` action refuses to zoom a panel that offers no control, so
     * either answer alone is enough to mean "never zoom". Zooming out is
     * never refused: a panel that stops offering the control while zoomed
     * would otherwise strand the user with no way back.
     *
     * `gpui.base.dock.Panel.zoomable` is the other half: it decides whether
     * zooming happens at all, and base refuses a zoom that fails it however
     * the zoom was asked for.
     */
    function zoomControl(cx:App):Null<PanelControl>;

    /**
     * Whether the tab group pads the panel's content when it draws it inside
     * a tab bar.
     */
    function innerPadding(cx:App):Bool;

    /**
     * Whether the tab group draws a title bar above this panel when it is
     * the only panel in its group.
     *
     * `false` for a panel that carries its own chrome. A group holding
     * several panels still draws its tabs, so every panel stays reachable.
     */
    function titleBar(cx:App):Bool;

}
