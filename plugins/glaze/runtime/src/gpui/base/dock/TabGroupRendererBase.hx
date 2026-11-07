// Ported from gpui-kit 0.8.1: crates/base/src/dock/tab_group.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.AnyElement;
import gpui.AnyView;
import gpui.App;
import gpui.Div;
import gpui.Window;

import gpui.Prelude.*;

/**
 * The default methods of the Rust `TabGroupRenderer` trait.
 */
abstract class TabGroupRendererBase implements TabGroupRenderer {

    public function new() {}

    public function frame(group:TabGroupContext, window:Window, cx:App):Div {
        return div().id('tab-group');
    }

    public function contentFrame(group:TabGroupContext, window:Window, cx:App):Div {
        return div().id('tab-group-content');
    }

    public abstract function renderTabBar(group:TabGroupContext, window:Window, cx:App):AnyElement;

    public function renderActivePanel(panel:AnyView, group:TabGroupContext, window:Window, cx:App):AnyElement {
        return panel.intoAnyElement();
    }

    public function renderDropIndicator(indicator:DropIndicator, window:Window, cx:App):Null<AnyElement> {
        return null;
    }

    public function renderEmpty(group:TabGroupContext, window:Window, cx:App):Null<AnyElement> {
        return null;
    }

}
