// Ported from gpui-pre 0.3.10: src/scene.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package glaze.scene;

/**
 * Common fields of sprite primitives: an atlas tile, identified by the
 * index of its atlas texture and its bounds in that texture, in texels.
 */
class SpritePrimitive extends Primitive {

    /** Index of the atlas texture holding the tile (batches are split per texture) */
    public var textureIndex:Int = 0;

    public var tileX:Float = 0;
    public var tileY:Float = 0;
    public var tileWidth:Float = 0;
    public var tileHeight:Float = 0;

    public inline function setTile(textureIndex:Int, x:Float, y:Float, width:Float, height:Float):Void {
        this.textureIndex = textureIndex;
        tileX = x;
        tileY = y;
        tileWidth = width;
        tileHeight = height;
    }

    /**
     * Copies every field of `other` (used to replay paint operations).
     */
    public function copySpriteFrom(other:SpritePrimitive):Void {
        copyPrimitiveFrom(other);
        textureIndex = other.textureIndex;
        tileX = other.tileX;
        tileY = other.tileY;
        tileWidth = other.tileWidth;
        tileHeight = other.tileHeight;
    }

}
