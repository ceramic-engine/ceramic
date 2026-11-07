// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * Methods that Rust defines on `Edges<DefiniteLength>`.
 * `toPixels` is attached to `EdgesOf` with `@:using`.
 */
class EdgesOfDefiniteLength {

    /**
     * Edges set to zero pixels on every side.
     */
    public static inline function zero():EdgesOf<DefiniteLength> {

        return EdgesOf.all(DefiniteLength.Absolute(AbsoluteLength.Pixels(0.0)));

    }

    /**
     * Converts each side to `Pixels`. Fractions of top and bottom are relative
     * to the parent height, fractions of left and right to the parent width.
     */
    public static function toPixels(self:EdgesOf<DefiniteLength>, parentSize:SizeOf<AbsoluteLength>, remSize:Pixels):Edges {

        return new Edges(
            self.top.toPixels(parentSize.height, remSize),
            self.right.toPixels(parentSize.width, remSize),
            self.bottom.toPixels(parentSize.height, remSize),
            self.left.toPixels(parentSize.width, remSize)
        );

    }

}
