// Ported from gpui-pre 0.3.10: src/scene.rs (Path primitive)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package gpui.scene;

/**
 * A path primitive (Rust `Path<ScaledPixels>` in the scene).
 *
 * Differences with GPUI: the path is drawn as a coverage mask rasterized
 * by plutovg into the atlas (the tile), filled with its color, instead of
 * triangles rendered into an intermediate MSAA texture. `bounds` are the
 * exact bounds of the path (used for ordering and dumps, like GPUI);
 * `sprite*` is the device pixel rectangle where the tile is drawn.
 * Gradient and pattern backgrounds are kept in `background` and shaded per
 * pixel by `shaders.GpuiPathSprite`.
 */
class PathSprite extends MonochromeSprite {

    /** The color of the path (`null`: the solid color fields) */
    public var background:Null<gpui.Background> = null;

    public var spriteX:Float = 0;
    public var spriteY:Float = 0;
    public var spriteWidth:Float = 0;
    public var spriteHeight:Float = 0;

    /** Number of vertices of the path (0 for outlines rasterized directly) */
    public var vertexCount:Int = 0;

    override function kind():PrimitiveKind {
        return Path;
    }

    override function reset():Void {
        super.reset();
        background = null;
        spriteX = spriteY = spriteWidth = spriteHeight = 0;
        vertexCount = 0;
    }

    public inline function setSpriteBounds(x:Float, y:Float, width:Float, height:Float):Void {
        spriteX = x;
        spriteY = y;
        spriteWidth = width;
        spriteHeight = height;
    }

    /**
     * Copies every field of `other` (used to replay paint operations).
     */
    public function copyFrom(other:PathSprite):Void {
        copyMonochromeFrom(other);
        background = other.background;
        spriteX = other.spriteX;
        spriteY = other.spriteY;
        spriteWidth = other.spriteWidth;
        spriteHeight = other.spriteHeight;
        vertexCount = other.vertexCount;
    }

}
