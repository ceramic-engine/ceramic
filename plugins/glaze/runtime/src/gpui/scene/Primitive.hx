// Ported from gpui-pre 0.3.10: src/scene.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package gpui.scene;

/**
 * Base class of scene primitives.
 *
 * Unlike GPUI where primitives are plain structs holding `Bounds`, `Corners`,
 * `Hsla` values, primitives store flat `Float` fields: they are pooled by the
 * `Scene` and reused from one frame to the next, so painting a frame doesn't
 * allocate once pools have grown. All geometry is in scaled pixels.
 */
class Primitive {

    /** Draw order computed by the scene (see `BoundsTree`) */
    public var order:Int = 0;

    /** Insertion index, used as a tie-break to keep sorting stable */
    public var seq:Int = 0;

    public var boundsX:Float = 0;
    public var boundsY:Float = 0;
    public var boundsWidth:Float = 0;
    public var boundsHeight:Float = 0;

    public var contentMaskX:Float = 0;
    public var contentMaskY:Float = 0;
    public var contentMaskWidth:Float = 0;
    public var contentMaskHeight:Float = 0;

    public function new() {}

    public function kind():PrimitiveKind {
        return Quad;
    }

    /**
     * Resets every field to its default, so a pooled primitive can be refilled.
     */
    public function reset():Void {
        order = 0;
        seq = 0;
        boundsX = 0;
        boundsY = 0;
        boundsWidth = 0;
        boundsHeight = 0;
        contentMaskX = 0;
        contentMaskY = 0;
        contentMaskWidth = 0;
        contentMaskHeight = 0;
    }

    public inline function setBounds(x:Float, y:Float, width:Float, height:Float):Void {
        boundsX = x;
        boundsY = y;
        boundsWidth = width;
        boundsHeight = height;
    }

    public inline function setContentMask(x:Float, y:Float, width:Float, height:Float):Void {
        contentMaskX = x;
        contentMaskY = y;
        contentMaskWidth = width;
        contentMaskHeight = height;
    }

    /**
     * Copies every field of `other` (used to replay paint operations).
     */
    public function copyPrimitiveFrom(other:Primitive):Void {
        order = other.order;
        seq = other.seq;
        boundsX = other.boundsX;
        boundsY = other.boundsY;
        boundsWidth = other.boundsWidth;
        boundsHeight = other.boundsHeight;
        contentMaskX = other.contentMaskX;
        contentMaskY = other.contentMaskY;
        contentMaskWidth = other.contentMaskWidth;
        contentMaskHeight = other.contentMaskHeight;
    }

}
