// Ported from gpui-kit 0.8.1: crates/base/src/resizable/mod.rs (free functions)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.resizable;

import gpui.ElementIdArg;
import gpui.Pixels;

/**
 * The free functions of gpui-base's `resizable` module.
 */
class Resizable {

    public static inline final PANEL_MIN_SIZE:Pixels = 100.;

    /**
     * Create a `ResizablePanelGroup` with horizontal resizing.
     */
    public static function hResizable(id:ElementIdArg):ResizablePanelGroup {
        return new ResizablePanelGroup(id).axis(Horizontal);
    }

    /**
     * Create a `ResizablePanelGroup` with vertical resizing.
     */
    public static function vResizable(id:ElementIdArg):ResizablePanelGroup {
        return new ResizablePanelGroup(id).axis(Vertical);
    }

    /**
     * Create a `ResizablePanel`.
     */
    public static function resizablePanel():ResizablePanel {
        return new ResizablePanel();
    }

}
