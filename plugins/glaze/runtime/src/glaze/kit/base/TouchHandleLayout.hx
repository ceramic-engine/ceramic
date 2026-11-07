// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.Hitbox;
import glaze.kit.base.input.SelectionEdge;

/**
 * The touch handles a participant laid out for a frame, with their hitboxes.
 */
class TouchHandleLayout {

    @:allow(glaze.kit.base)
    final hitboxes:Array<TouchHandleHitbox>;

    public function new(?hitboxes:Array<TouchHandleHitbox>) {
        this.hitboxes = hitboxes != null ? hitboxes : [];
    }

}

/** Rust `(SelectionEdge, Hitbox)`. */
class TouchHandleHitbox {
    public final edge:SelectionEdge;
    public final hitbox:Hitbox;

    public inline function new(edge:SelectionEdge, hitbox:Hitbox) {
        this.edge = edge;
        this.hitbox = hitbox;
    }
}
