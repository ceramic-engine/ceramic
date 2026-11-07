// Ported from gpui-pre 0.3.10: src/scene.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package glaze.scene;

/**
 * An RGBA image or emoji from an atlas, with rounded corners, opacity and
 * an optional grayscale filter.
 */
class PolychromeSprite extends SpritePrimitive {

    public var grayscale:Bool = false;

    public var opacity:Float = 1;

    public var cornerRadiusTopLeft:Float = 0;
    public var cornerRadiusTopRight:Float = 0;
    public var cornerRadiusBottomRight:Float = 0;
    public var cornerRadiusBottomLeft:Float = 0;

    override function kind():PrimitiveKind {
        return PolychromeSprite;
    }

    override function reset():Void {

        super.reset();
        setTile(0, 0, 0, 0, 0);
        grayscale = false;
        opacity = 1;
        setCornerRadii(0, 0, 0, 0);

    }

    public inline function setCornerRadii(topLeft:Float, topRight:Float, bottomRight:Float, bottomLeft:Float):Void {
        cornerRadiusTopLeft = topLeft;
        cornerRadiusTopRight = topRight;
        cornerRadiusBottomRight = bottomRight;
        cornerRadiusBottomLeft = bottomLeft;
    }

    /**
     * Copies every field of `other` (used to replay paint operations).
     */
    public function copyFrom(other:PolychromeSprite):Void {
        copySpriteFrom(other);
        grayscale = other.grayscale;
        opacity = other.opacity;
        cornerRadiusTopLeft = other.cornerRadiusTopLeft;
        cornerRadiusTopRight = other.cornerRadiusTopRight;
        cornerRadiusBottomRight = other.cornerRadiusBottomRight;
        cornerRadiusBottomLeft = other.cornerRadiusBottomLeft;
    }

}
