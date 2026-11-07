// Ported from gpui-pre 0.3.10: src/text_system.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Parameters for rendering a glyph, used as cache keys for raster bounds.
 *
 * This struct identifies a specific glyph rendering configuration including
 * font, size, subpixel positioning, and scale factor. It's used to look up
 * cached raster bounds and sprite atlas entries (see `GlyphCache`).
 *
 * `subpixel_variant` (a `Point<u8>`) is stored as two Int fields.
 */
class RenderGlyphParams {

    public var fontId:FontId;
    public var glyphId:GlyphId;
    public var fontSize:Pixels;
    public var subpixelVariantX:Int;
    public var subpixelVariantY:Int;
    public var scaleFactor:Float;
    public var isEmoji:Bool;
    public var subpixelRendering:Bool;
    public var dilation:Int;

    public function new(fontId:FontId = 0, glyphId:GlyphId = 0, fontSize:Pixels = 0, subpixelVariantX:Int = 0, subpixelVariantY:Int = 0, scaleFactor:Float = 1, isEmoji:Bool = false, subpixelRendering:Bool = false, dilation:Int = 0) {
        this.fontId = fontId;
        this.glyphId = glyphId;
        this.fontSize = fontSize;
        this.subpixelVariantX = subpixelVariantX;
        this.subpixelVariantY = subpixelVariantY;
        this.scaleFactor = scaleFactor;
        this.isEmoji = isEmoji;
        this.subpixelRendering = subpixelRendering;
        this.dilation = dilation;
    }

    public function set(fontId:FontId, glyphId:GlyphId, fontSize:Pixels, subpixelVariantX:Int, subpixelVariantY:Int, scaleFactor:Float, isEmoji:Bool, subpixelRendering:Bool, dilation:Int):RenderGlyphParams {
        this.fontId = fontId;
        this.glyphId = glyphId;
        this.fontSize = fontSize;
        this.subpixelVariantX = subpixelVariantX;
        this.subpixelVariantY = subpixelVariantY;
        this.scaleFactor = scaleFactor;
        this.isEmoji = isEmoji;
        this.subpixelRendering = subpixelRendering;
        this.dilation = dilation;
        return this;
    }

    public function clone():RenderGlyphParams {
        return new RenderGlyphParams(fontId, glyphId, fontSize, subpixelVariantX, subpixelVariantY, scaleFactor, isEmoji, subpixelRendering, dilation);
    }

    public function equals(other:RenderGlyphParams):Bool {
        return other != null && (fontId:Int) == (other.fontId:Int) && (glyphId:Int) == (other.glyphId:Int)
            && (fontSize:Float) == (other.fontSize:Float) && subpixelVariantX == other.subpixelVariantX
            && subpixelVariantY == other.subpixelVariantY && scaleFactor == other.scaleFactor
            && isEmoji == other.isEmoji && subpixelRendering == other.subpixelRendering && dilation == other.dilation;
    }

    /** A string identifying these parameters (used by generic atlas keys). */
    public function key():String {
        return '$fontId:$glyphId:${(fontSize:Float)}:$subpixelVariantX:$subpixelVariantY:$scaleFactor:${isEmoji ? 1 : 0}:${subpixelRendering ? 1 : 0}:$dilation';
    }

    public function toString():String {
        return 'RenderGlyphParams(${key()})';
    }

}
