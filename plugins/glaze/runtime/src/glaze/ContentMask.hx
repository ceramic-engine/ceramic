// Ported from gpui-pre 0.3.10: src/window.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Indicates which region of the window is visible. Content falling outside
 * of this mask will not be rendered. Currently, only rectangular content
 * masks are supported, but we give the struct a name to leave room for
 * more complex masks in the future.
 */
class ContentMask {

    /** The bounds */
    public final bounds:Bounds;

    public inline function new(bounds:Bounds) {
        this.bounds = bounds;
    }

    /**
     * Scale the content mask's pixel units by the given scaling factor.
     */
    public inline function scale(factor:Float):ContentMask {
        return new ContentMask(bounds.scale(factor));
    }

    /**
     * Intersect the content mask with the given content mask.
     */
    public inline function intersect(other:ContentMask):ContentMask {
        return new ContentMask(bounds.intersect(other.bounds));
    }

    public inline function equals(other:ContentMask):Bool {
        return other != null && bounds.equals(other.bounds);
    }

    public function toString():String {
        return 'ContentMask($bounds)';
    }

}
