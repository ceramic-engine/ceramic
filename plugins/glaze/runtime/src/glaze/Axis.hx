// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * Axis in a 2D cartesian space.
 */
enum abstract Axis(Int) {

    /**
     * The y axis, or up and down.
     */
    var Vertical = 0;

    /**
     * The x axis, or left and right.
     */
    var Horizontal = 1;

    /**
     * Swaps this axis to the opposite axis.
     */
    public inline function invert():Axis {

        return (cast this:Axis) == Vertical ? Horizontal : Vertical;

    }

    public function toString():String {

        return (cast this:Axis) == Vertical ? 'Vertical' : 'Horizontal';

    }

}
