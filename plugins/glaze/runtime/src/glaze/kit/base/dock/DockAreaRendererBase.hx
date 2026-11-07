// Ported from gpui-kit 0.8.1: crates/base/src/dock/dock_area.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.AnyElement;
import glaze.App;
import glaze.Axis;
import glaze.Div;
import glaze.ElementId;
import glaze.Window;
import glaze.kit.base.resizable.ResizeHandle.ResizeHandleContext;

import glaze.Prelude.*;

/**
 * The default methods of the Rust `DockAreaRenderer` trait.
 */
abstract class DockAreaRendererBase implements DockAreaRenderer {

    public function new() {}

    public function frame(window:Window, cx:App):Div {
        return div().id('dock-area');
    }

    public function splitFrame(node:NodeId, axis:Axis, window:Window, cx:App):Div {
        return div().id(ElementId.NamedInteger('dock-split-frame', node.asU64()));
    }

    public function centerFrame(window:Window, cx:App):Div {
        return div().id('dock-area-center');
    }

    public function renderSplitHandle(handle:ResizeHandleContext, window:Window, cx:App):Null<AnyElement> {
        return null;
    }

    public function renderDock(dock:DockContext, content:AnyElement, window:Window, cx:App):AnyElement {
        return content;
    }

    public function buildPlaceholder(state:PanelState, window:Window, cx:App):Null<PanelView> {
        return null;
    }

    public abstract function tabGroupRenderer():TabGroupRenderer;

}
