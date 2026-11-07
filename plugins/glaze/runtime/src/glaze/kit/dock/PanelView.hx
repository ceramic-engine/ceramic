// Ported from gpui-kit 0.8.1: crates/component/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.dock;

import glaze.AnyElement;
import glaze.App;
import glaze.Window;
import glaze.kit.button.Button;
import glaze.kit.menu.PopupMenu;

/**
 * Object-safe counterpart of `Panel`, and the presentation half of the
 * handle a skin holds (Rust `dyn PanelView`). `EntityPanelView` is the one
 * of a panel entity.
 */
interface PanelView extends glaze.kit.base.dock.PanelView {

    function tabName(cx:App):Null<String>;

    function title(window:Window, cx:App):AnyElement;

    function titleStyle(cx:App):Null<TitleStyle>;

    function titleSuffix(window:Window, cx:App):Null<AnyElement>;

    function toolbarButtons(window:Window, cx:App):Null<Array<Button>>;

    function dropdownMenu(menu:PopupMenu, window:Window, cx:App):PopupMenu;

    function zoomControl(cx:App):Null<PanelControl>;

    function innerPadding(cx:App):Bool;

    function titleBar(cx:App):Bool;

}
