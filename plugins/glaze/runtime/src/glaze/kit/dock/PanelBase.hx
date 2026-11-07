// Ported from gpui-kit 0.8.1: crates/component/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.dock;

import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Window;
import glaze.kit.I18n;
import glaze.kit.button.Button;
import glaze.kit.menu.PopupMenu;

/**
 * The default methods of both panel traits: base's (behavior, from
 * `glaze.kit.base.dock.PanelBase`) and this crate's `Panel` (presentation). A
 * panel extends this and implements `panelName`, `render` and
 * `focusHandle`.
 */
abstract class PanelBase extends glaze.kit.base.dock.PanelBase implements Panel {

    public function new() {
        super();
    }

    public function tabName(cx:App):Null<String> {
        return null;
    }

    public function title(window:Window, cx:Context<Dynamic>):IntoElement {
        return I18n.t('Dock.Unnamed');
    }

    public function titleStyle(cx:App):Null<TitleStyle> {
        return null;
    }

    public function titleSuffix(window:Window, cx:Context<Dynamic>):Null<IntoElement> {
        return null;
    }

    public function toolbarButtons(window:Window, cx:Context<Dynamic>):Null<Array<Button>> {
        return null;
    }

    public function dropdownMenu(menu:PopupMenu, window:Window, cx:Context<Dynamic>):PopupMenu {
        return menu;
    }

    public function zoomControl(cx:App):Null<PanelControl> {
        return PanelControl.Menu;
    }

    public function innerPadding(cx:App):Bool {
        return true;
    }

    public function titleBar(cx:App):Bool {
        return true;
    }

}
