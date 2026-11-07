// Ported from gpui-kit 0.8.1: crates/base/src/dock/drag.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

/**
 * A host-owned value being dragged over the dock, opaque to the dock itself.
 *
 * Not to be confused with GPUI's `glaze.AnyDrag` (the active drag of the app).
 */
class AnyDrag {

    final valueHolder:Dynamic;

    public function new(value:Dynamic) {
        this.valueHolder = value;
    }

    public inline function value():Dynamic {
        return valueHolder;
    }

    public inline function clone():AnyDrag {
        return this;
    }

}
