// Ported from gpui-kit 0.8.1: crates/base/src/text/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

/**
 * One text element's laid-out vertical extent, reported by `Inline` during
 * prepaint so `TextView` can snap its `maxLines` clip to a whole-line
 * boundary.
 */
class LineSpan {

    public final top:Float;

    public final bottom:Float;

    public final lineHeight:Float;

    public inline function new(top:Float, bottom:Float, lineHeight:Float) {
        this.top = top;
        this.bottom = bottom;
        this.lineHeight = lineHeight;
    }

}
