// Ported from gpui-kit 0.8.1: crates/base/src/dock/drag.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.Context;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.Window;

/**
 * Rust `impl Render for DragPanel`: base draws nothing, the styled drag
 * preview is appearance and belongs to the component layer.
 */
class DragPanelView extends Model implements Render {

    public final drag:DragPanel;

    public function new(drag:DragPanel) {
        super();
        this.drag = drag;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new gpui.Empty();
    }

}
