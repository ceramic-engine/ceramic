// Ported from gpui-pre 0.3.10: src/platform.rs (Decorations, Tiling)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The kinds of decorations a window can have. The port's windows are always
 * server decorated (no client side decorations).
 */
enum Decorations {

    /** The window is configured to use server side decorations. */
    Server;

    /** The window is configured to use client side decorations. */
    Client(tiling:Tiling);

}

/**
 * A type to describe which sides of the window are currently tiled in some way.
 */
@:structInit
class Tiling {

    /** Whether the top edge is tiled. */
    public var top:Bool = false;

    /** Whether the left edge is tiled. */
    public var left:Bool = false;

    /** Whether the right edge is tiled. */
    public var right:Bool = false;

    /** Whether the bottom edge is tiled. */
    public var bottom:Bool = false;

    public function new(top:Bool = false, left:Bool = false, right:Bool = false, bottom:Bool = false) {
        this.top = top;
        this.left = left;
        this.right = right;
        this.bottom = bottom;
    }

    /** Initializes a `Tiling` with all sides tiled. */
    public static function tiled():Tiling {
        return new Tiling(true, true, true, true);
    }

    /** Whether any edge is tiled. */
    public function isTiled():Bool {
        return top || left || right || bottom;
    }

}
