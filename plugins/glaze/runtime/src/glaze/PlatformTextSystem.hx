// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import haxe.io.Bytes;

/**
 * The platform side of the text system: font loading, metrics, shaping and
 * glyph rasterization. Implemented by `glaze.platform.CeramicTextSystem`
 * (pure Haxe, over the `ttf` library) and by `NoopTextSystem` for tests.
 *
 * Errors (Rust `Result::Err`) are thrown. Device pixel bounds are `Bounds`
 * holding whole values.
 */
interface PlatformTextSystem {

    /** Adds font files (TTF, OTF, TTC) to the system. */
    function addFonts(fonts:Array<Bytes>):Void;

    /** Get all available font names. */
    function allFontNames():Array<String>;

    /** Get the font ID for a font descriptor. Throws if no face matches. */
    function fontId(descriptor:Font):FontId;

    /** Get metrics for a font. */
    function fontMetrics(fontId:FontId):FontMetrics;

    /** Get typographic bounds for a glyph, in font units. */
    function typographicBounds(fontId:FontId, glyphId:GlyphId):Bounds;

    /** Get the advance width for a glyph, in font units. */
    function advance(fontId:FontId, glyphId:GlyphId):Size;

    /** Get the glyph ID for a character, or null. */
    function glyphForChar(fontId:FontId, ch:Int):Null<GlyphId>;

    /** Get raster bounds for a glyph (device pixels, y down from the baseline). */
    function glyphRasterBounds(params:RenderGlyphParams):Bounds;

    /**
     * Rasterize a glyph into an 8-bit coverage bitmap of the size of
     * `rasterBounds` (rows of `rasterBounds.size.width` bytes).
     */
    function rasterizeGlyph(params:RenderGlyphParams, rasterBounds:Bounds):Bytes;

    /** Layout a line of text with the given font runs. */
    function layoutLine(text:String, fontSize:Pixels, runs:Array<FontRun>):LineLayout;

    /** Returns the recommended text rendering mode for the given font and size. */
    function recommendedRenderingMode(fontId:FontId, fontSize:Pixels):TextRenderingMode;

    /** Returns the dilation level to use for a glyph painted in the given color. */
    function glyphDilationForColor(color:Hsla):Int;

}
