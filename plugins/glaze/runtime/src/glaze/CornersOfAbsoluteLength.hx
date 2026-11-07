// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * Methods that Rust defines on `Corners<AbsoluteLength>`.
 * `toPixels` is attached to `CornersOf` with `@:using`.
 */
class CornersOfAbsoluteLength {

    /**
     * Converts each value to `Pixels` based on the rem size.
     */
    public static function toPixels(self:CornersOf<AbsoluteLength>, remSize:Pixels):Corners {

        return new Corners(
            self.topLeft.toPixels(remSize),
            self.topRight.toPixels(remSize),
            self.bottomRight.toPixels(remSize),
            self.bottomLeft.toPixels(remSize)
        );

    }

}
