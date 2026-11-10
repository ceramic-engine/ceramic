// Ported from gpui-pre 0.3.10: src/scene.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package glaze.scene;

/**
 * A straight or wavy line under (or through) text.
 */
class Underline extends Primitive {

    public var colorH:Float = 0;
    public var colorS:Float = 0;
    public var colorL:Float = 0;
    public var colorA:Float = 0;

    public var thickness:Float = 0;

    public var wavy:Bool = false;

    override function kind():PrimitiveKind {
        return Underline;
    }

    override function reset():Void {

        super.reset();
        setColor(0, 0, 0, 0);
        thickness = 0;
        wavy = false;

    }

    public inline function setColor(h:Float, s:Float, l:Float, a:Float):Void {
        colorH = h;
        colorS = s;
        colorL = l;
        colorA = a;
    }

    /**
     * Copies every field of `other` (used to replay paint operations).
     */
    public function copyFrom(other:Underline):Void {
        copyPrimitiveFrom(other);
        colorH = other.colorH;
        colorS = other.colorS;
        colorL = other.colorL;
        colorA = other.colorA;
        thickness = other.thickness;
        wavy = other.wavy;
    }

    override function sameDrawing(other:Primitive):Bool {
        if (!super.sameDrawing(other)) return false;
        final o:Underline = cast other;
        return colorH == o.colorH
            && colorS == o.colorS
            && colorL == o.colorL
            && colorA == o.colorA
            && thickness == o.thickness
            && wavy == o.wavy;
    }

}
