// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * Methods that Rust defines on `Edges<AbsoluteLength>`.
 * `toPixels` is attached to `EdgesOf` with `@:using`.
 */
class EdgesOfAbsoluteLength {

    /**
     * Edges set to zero pixels on every side.
     */
    public static inline function zero():EdgesOf<AbsoluteLength> {

        return EdgesOf.all(AbsoluteLength.Pixels(0.0));

    }

    /**
     * Converts each side to `Pixels` based on the rem size.
     */
    public static function toPixels(self:EdgesOf<AbsoluteLength>, remSize:Pixels):Edges {

        return new Edges(
            self.top.toPixels(remSize),
            self.right.toPixels(remSize),
            self.bottom.toPixels(remSize),
            self.left.toPixels(remSize)
        );

    }

}
