// Ported from gpui-pre 0.3.10: src/scene.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package glaze.scene;

/**
 * A blurred rounded rectangle, drawn as a drop shadow (outside the element)
 * or an inset shadow (inside the element bounds).
 */
class Shadow extends Primitive {

    public var blurRadius:Float = 0;

    public var cornerRadiusTopLeft:Float = 0;
    public var cornerRadiusTopRight:Float = 0;
    public var cornerRadiusBottomRight:Float = 0;
    public var cornerRadiusBottomLeft:Float = 0;

    public var colorH:Float = 0;
    public var colorS:Float = 0;
    public var colorL:Float = 0;
    public var colorA:Float = 0;

    public var elementBoundsX:Float = 0;
    public var elementBoundsY:Float = 0;
    public var elementBoundsWidth:Float = 0;
    public var elementBoundsHeight:Float = 0;

    public var elementCornerRadiusTopLeft:Float = 0;
    public var elementCornerRadiusTopRight:Float = 0;
    public var elementCornerRadiusBottomRight:Float = 0;
    public var elementCornerRadiusBottomLeft:Float = 0;

    public var inset:Bool = false;

    override function kind():PrimitiveKind {
        return Shadow;
    }

    override function reset():Void {

        super.reset();
        blurRadius = 0;
        setCornerRadii(0, 0, 0, 0);
        setColor(0, 0, 0, 0);
        setElementBounds(0, 0, 0, 0);
        setElementCornerRadii(0, 0, 0, 0);
        inset = false;

    }

    public inline function setColor(h:Float, s:Float, l:Float, a:Float):Void {
        colorH = h;
        colorS = s;
        colorL = l;
        colorA = a;
    }

    public inline function setCornerRadii(topLeft:Float, topRight:Float, bottomRight:Float, bottomLeft:Float):Void {
        cornerRadiusTopLeft = topLeft;
        cornerRadiusTopRight = topRight;
        cornerRadiusBottomRight = bottomRight;
        cornerRadiusBottomLeft = bottomLeft;
    }

    public inline function setElementBounds(x:Float, y:Float, width:Float, height:Float):Void {
        elementBoundsX = x;
        elementBoundsY = y;
        elementBoundsWidth = width;
        elementBoundsHeight = height;
    }

    public inline function setElementCornerRadii(topLeft:Float, topRight:Float, bottomRight:Float, bottomLeft:Float):Void {
        elementCornerRadiusTopLeft = topLeft;
        elementCornerRadiusTopRight = topRight;
        elementCornerRadiusBottomRight = bottomRight;
        elementCornerRadiusBottomLeft = bottomLeft;
    }

    /**
     * Copies every field of `other` (used to replay paint operations).
     */
    public function copyFrom(other:Shadow):Void {
        copyPrimitiveFrom(other);
        blurRadius = other.blurRadius;
        cornerRadiusTopLeft = other.cornerRadiusTopLeft;
        cornerRadiusTopRight = other.cornerRadiusTopRight;
        cornerRadiusBottomRight = other.cornerRadiusBottomRight;
        cornerRadiusBottomLeft = other.cornerRadiusBottomLeft;
        colorH = other.colorH;
        colorS = other.colorS;
        colorL = other.colorL;
        colorA = other.colorA;
        elementBoundsX = other.elementBoundsX;
        elementBoundsY = other.elementBoundsY;
        elementBoundsWidth = other.elementBoundsWidth;
        elementBoundsHeight = other.elementBoundsHeight;
        elementCornerRadiusTopLeft = other.elementCornerRadiusTopLeft;
        elementCornerRadiusTopRight = other.elementCornerRadiusTopRight;
        elementCornerRadiusBottomRight = other.elementCornerRadiusBottomRight;
        elementCornerRadiusBottomLeft = other.elementCornerRadiusBottomLeft;
        inset = other.inset;
    }

    override function sameDrawing(other:Primitive):Bool {
        if (!super.sameDrawing(other)) return false;
        final o:Shadow = cast other;
        return blurRadius == o.blurRadius
            && cornerRadiusTopLeft == o.cornerRadiusTopLeft
            && cornerRadiusTopRight == o.cornerRadiusTopRight
            && cornerRadiusBottomRight == o.cornerRadiusBottomRight
            && cornerRadiusBottomLeft == o.cornerRadiusBottomLeft
            && colorH == o.colorH
            && colorS == o.colorS
            && colorL == o.colorL
            && colorA == o.colorA
            && elementBoundsX == o.elementBoundsX
            && elementBoundsY == o.elementBoundsY
            && elementBoundsWidth == o.elementBoundsWidth
            && elementBoundsHeight == o.elementBoundsHeight
            && elementCornerRadiusTopLeft == o.elementCornerRadiusTopLeft
            && elementCornerRadiusTopRight == o.elementCornerRadiusTopRight
            && elementCornerRadiusBottomRight == o.elementCornerRadiusBottomRight
            && elementCornerRadiusBottomLeft == o.elementCornerRadiusBottomLeft
            && inset == o.inset;
    }

}
