// Ported from gpui-pre 0.3.10: src/scene.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package gpui.scene;

/**
 * A rounded rectangle with borders and a background.
 *
 * Colors are HSLA (hue in 0..1) like in GPUI. The background is stored
 * flat: `backgroundTag` 0 = solid, 1 = linear gradient, 2 = pattern slash,
 * 3 = checkerboard; `backgroundColorSpace` 0 = sRGB, 1 = Oklab.
 */
class Quad extends Primitive {

    public var borderStyle:BorderStyle = Solid;

    public var backgroundTag:Int = 0;
    public var backgroundColorSpace:Int = 0;
    public var backgroundSolidH:Float = 0;
    public var backgroundSolidS:Float = 0;
    public var backgroundSolidL:Float = 0;
    public var backgroundSolidA:Float = 0;
    public var backgroundGradientAngleOrPatternHeight:Float = 0;
    public var backgroundColor0H:Float = 0;
    public var backgroundColor0S:Float = 0;
    public var backgroundColor0L:Float = 0;
    public var backgroundColor0A:Float = 0;
    public var backgroundColor0Percentage:Float = 0;
    public var backgroundColor1H:Float = 0;
    public var backgroundColor1S:Float = 0;
    public var backgroundColor1L:Float = 0;
    public var backgroundColor1A:Float = 0;
    public var backgroundColor1Percentage:Float = 0;

    public var borderColorH:Float = 0;
    public var borderColorS:Float = 0;
    public var borderColorL:Float = 0;
    public var borderColorA:Float = 0;

    public var cornerRadiusTopLeft:Float = 0;
    public var cornerRadiusTopRight:Float = 0;
    public var cornerRadiusBottomRight:Float = 0;
    public var cornerRadiusBottomLeft:Float = 0;

    public var borderWidthTop:Float = 0;
    public var borderWidthRight:Float = 0;
    public var borderWidthBottom:Float = 0;
    public var borderWidthLeft:Float = 0;

    override function kind():PrimitiveKind {
        return Quad;
    }

    override function reset():Void {

        super.reset();
        borderStyle = Solid;
        backgroundTag = 0;
        backgroundColorSpace = 0;
        backgroundSolidH = 0;
        backgroundSolidS = 0;
        backgroundSolidL = 0;
        backgroundSolidA = 0;
        backgroundGradientAngleOrPatternHeight = 0;
        backgroundColor0H = 0;
        backgroundColor0S = 0;
        backgroundColor0L = 0;
        backgroundColor0A = 0;
        backgroundColor0Percentage = 0;
        backgroundColor1H = 0;
        backgroundColor1S = 0;
        backgroundColor1L = 0;
        backgroundColor1A = 0;
        backgroundColor1Percentage = 0;
        borderColorH = 0;
        borderColorS = 0;
        borderColorL = 0;
        borderColorA = 0;
        cornerRadiusTopLeft = 0;
        cornerRadiusTopRight = 0;
        cornerRadiusBottomRight = 0;
        cornerRadiusBottomLeft = 0;
        borderWidthTop = 0;
        borderWidthRight = 0;
        borderWidthBottom = 0;
        borderWidthLeft = 0;

    }

    public inline function setSolidBackground(h:Float, s:Float, l:Float, a:Float):Void {
        backgroundTag = 0;
        backgroundSolidH = h;
        backgroundSolidS = s;
        backgroundSolidL = l;
        backgroundSolidA = a;
    }

    public inline function setBorderColor(h:Float, s:Float, l:Float, a:Float):Void {
        borderColorH = h;
        borderColorS = s;
        borderColorL = l;
        borderColorA = a;
    }

    public inline function setCornerRadii(topLeft:Float, topRight:Float, bottomRight:Float, bottomLeft:Float):Void {
        cornerRadiusTopLeft = topLeft;
        cornerRadiusTopRight = topRight;
        cornerRadiusBottomRight = bottomRight;
        cornerRadiusBottomLeft = bottomLeft;
    }

    public inline function setBorderWidths(top:Float, right:Float, bottom:Float, left:Float):Void {
        borderWidthTop = top;
        borderWidthRight = right;
        borderWidthBottom = bottom;
        borderWidthLeft = left;
    }

    /**
     * Copies every field of `other` (used to replay paint operations).
     */
    public function copyFrom(other:Quad):Void {
        copyPrimitiveFrom(other);
        borderStyle = other.borderStyle;
        backgroundTag = other.backgroundTag;
        backgroundColorSpace = other.backgroundColorSpace;
        backgroundSolidH = other.backgroundSolidH;
        backgroundSolidS = other.backgroundSolidS;
        backgroundSolidL = other.backgroundSolidL;
        backgroundSolidA = other.backgroundSolidA;
        backgroundGradientAngleOrPatternHeight = other.backgroundGradientAngleOrPatternHeight;
        backgroundColor0H = other.backgroundColor0H;
        backgroundColor0S = other.backgroundColor0S;
        backgroundColor0L = other.backgroundColor0L;
        backgroundColor0A = other.backgroundColor0A;
        backgroundColor0Percentage = other.backgroundColor0Percentage;
        backgroundColor1H = other.backgroundColor1H;
        backgroundColor1S = other.backgroundColor1S;
        backgroundColor1L = other.backgroundColor1L;
        backgroundColor1A = other.backgroundColor1A;
        backgroundColor1Percentage = other.backgroundColor1Percentage;
        borderColorH = other.borderColorH;
        borderColorS = other.borderColorS;
        borderColorL = other.borderColorL;
        borderColorA = other.borderColorA;
        cornerRadiusTopLeft = other.cornerRadiusTopLeft;
        cornerRadiusTopRight = other.cornerRadiusTopRight;
        cornerRadiusBottomRight = other.cornerRadiusBottomRight;
        cornerRadiusBottomLeft = other.cornerRadiusBottomLeft;
        borderWidthTop = other.borderWidthTop;
        borderWidthRight = other.borderWidthRight;
        borderWidthBottom = other.borderWidthBottom;
        borderWidthLeft = other.borderWidthLeft;
    }

}
