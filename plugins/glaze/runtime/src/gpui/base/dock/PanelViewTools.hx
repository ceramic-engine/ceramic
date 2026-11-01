// Ported from gpui-kit 0.8.1: crates/base/src/dock/panel.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.dock;

import gpui.Entity;
import gpui.Model;

/**
 * Helpers of `PanelView` (Rust trait impls on `dyn PanelView`).
 */
class PanelViewTools {

    /**
     * Rust `impl PartialEq for dyn PanelView`: the same view.
     */
    public static function same(a:PanelView, b:PanelView):Bool {
        return a.view().entityId() == b.view().entityId();
    }

    /**
     * Rust `impl From<&dyn PanelView> for Entity<T>`: the entity behind a
     * handle built from one (throws for another handle).
     */
    public static function entity<T:Model>(panel:PanelView):Entity<T> {
        return cast panel.view();
    }

}

