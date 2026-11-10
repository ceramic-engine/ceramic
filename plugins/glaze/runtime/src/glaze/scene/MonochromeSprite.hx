// Ported from gpui-pre 0.3.10: src/scene.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package glaze.scene;

/**
 * A coverage mask from an atlas (glyph, tinted icon) filled with a color,
 * with an optional 2D transformation (row major 2x2 rotation/scale plus
 * translation, like GPUI's `TransformationMatrix`).
 */
class MonochromeSprite extends SpritePrimitive {

    public var colorH:Float = 0;
    public var colorS:Float = 0;
    public var colorL:Float = 0;
    public var colorA:Float = 0;

    public var transformM00:Float = 1;
    public var transformM01:Float = 0;
    public var transformM10:Float = 0;
    public var transformM11:Float = 1;
    public var transformTx:Float = 0;
    public var transformTy:Float = 0;

    override function kind():PrimitiveKind {
        return MonochromeSprite;
    }

    override function reset():Void {

        super.reset();
        setTile(0, 0, 0, 0, 0);
        setColor(0, 0, 0, 0);
        resetTransformation();

    }

    public inline function setColor(h:Float, s:Float, l:Float, a:Float):Void {
        colorH = h;
        colorS = s;
        colorL = l;
        colorA = a;
    }

    public inline function setTransformation(m00:Float, m01:Float, m10:Float, m11:Float, tx:Float, ty:Float):Void {
        transformM00 = m00;
        transformM01 = m01;
        transformM10 = m10;
        transformM11 = m11;
        transformTx = tx;
        transformTy = ty;
    }

    public inline function resetTransformation():Void {
        setTransformation(1, 0, 0, 1, 0, 0);
    }

    public inline function hasTransformation():Bool {
        return transformM00 != 1 || transformM01 != 0 || transformM10 != 0 || transformM11 != 1 || transformTx != 0 || transformTy != 0;
    }

    /**
     * Copies every field of `other` (used to replay paint operations).
     */
    public function copyMonochromeFrom(other:MonochromeSprite):Void {
        copySpriteFrom(other);
        colorH = other.colorH;
        colorS = other.colorS;
        colorL = other.colorL;
        colorA = other.colorA;
        transformM00 = other.transformM00;
        transformM01 = other.transformM01;
        transformM10 = other.transformM10;
        transformM11 = other.transformM11;
        transformTx = other.transformTx;
        transformTy = other.transformTy;
    }

    override function sameDrawing(other:Primitive):Bool {
        if (!super.sameDrawing(other)) return false;
        final o:MonochromeSprite = cast other;
        return colorH == o.colorH
            && colorS == o.colorS
            && colorL == o.colorL
            && colorA == o.colorA
            && transformM00 == o.transformM00
            && transformM01 == o.transformM01
            && transformM10 == o.transformM10
            && transformM11 == o.transformM11
            && transformTx == o.transformTx
            && transformTy == o.transformTy;
    }

}
