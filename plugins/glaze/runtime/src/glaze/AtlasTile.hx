// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A rectangle of an atlas texture holding one entry.
 */
class AtlasTile {

    /** The texture this tile belongs to. */
    public final textureId:AtlasTextureId;

    /** The unique ID of this tile within its texture. */
    public final tileId:Int;

    /** Padding around the tile content in pixels. */
    public final padding:Int;

    /** The bounds of this tile within the texture (device pixels, whole values). */
    public final bounds:Bounds;

    public function new(textureId:AtlasTextureId, tileId:Int, padding:Int, bounds:Bounds) {
        this.textureId = textureId;
        this.tileId = tileId;
        this.padding = padding;
        this.bounds = bounds;
    }

    public function equals(other:AtlasTile):Bool {
        return other != null && textureId.equals(other.textureId) && tileId == other.tileId && padding == other.padding && bounds.equals(other.bounds);
    }

    public function toString():String {
        return 'AtlasTile(${textureId.index}, ${textureId.kind}, $tileId, $bounds)';
    }

}

/**
 * Identifies an atlas texture. `index` is also the index of the texture
 * in `SceneRenderable.atlasTextures` (and the `textureIndex` of sprites).
 */
class AtlasTextureId {

    /** The index of this texture in the atlas. */
    public final index:Int;

    /** The kind of content stored in this texture. */
    public final kind:AtlasTextureKind;

    public function new(index:Int, kind:AtlasTextureKind) {
        this.index = index;
        this.kind = kind;
    }

    public inline function equals(other:AtlasTextureId):Bool {
        return other != null && index == other.index && kind == other.kind;
    }

}

/**
 * The kind of content of an atlas texture.
 */
enum abstract AtlasTextureKind(Int) {
    var Monochrome = 0;
    var Polychrome = 1;
    var Subpixel = 2;
}

/**
 * Content to insert into an atlas (Rust `(Size<DevicePixels>, Cow<[u8]>)`):
 * 1 byte per pixel for monochrome tiles, 4 (BGRA) for polychrome and
 * subpixel ones. Polychrome pages hold straight alpha BGRA like GPUI's
 * (images and SVG images are straight, `straightAlpha`); premultiplied
 * polychrome sources (`straightAlpha` false) are converted when inserted.
 *
 * Ceramic addition: `texture` makes the tile cover a whole Ceramic texture
 * (images backed by a texture) instead of copying pixels.
 */
class AtlasTileSource {

    public final width:Int;

    public final height:Int;

    public final bytes:haxe.io.Bytes;

    /** The pixels have straight (not premultiplied) alpha */
    public var straightAlpha:Bool = false;

    /** A texture the tile covers (no pixels are copied) */
    public var texture:Null<ceramic.Texture> = null;

    public function new(width:Int, height:Int, bytes:haxe.io.Bytes) {
        this.width = width;
        this.height = height;
        this.bytes = bytes;
    }

}
