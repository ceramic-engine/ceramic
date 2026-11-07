// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import haxe.io.Bytes;

/**
 * A text system without fonts, used by GPUI's test platform: every
 * character is a glyph whose id is its UTF-16 length, advancing by
 * `0.6 em` (twice that for emoji-like glyphs).
 */
class NoopTextSystem implements PlatformTextSystem {

    public function new() {}

    public function addFonts(fonts:Array<Bytes>):Void {}

    public function allFontNames():Array<String> {
        return [];
    }

    public function fontId(descriptor:Font):FontId {
        return 1;
    }

    public function fontMetrics(fontId:FontId):FontMetrics {
        return new FontMetrics(1000, 1025.0, -275.0, 0.0, -95.0, 60.0, 698.0, 516.0, new Bounds(new Point(-260.0, -245.0), new Size(1501.0, 1364.0)));
    }

    public function typographicBounds(fontId:FontId, glyphId:GlyphId):Bounds {
        return new Bounds(new Point(54.0, 0.0), new Size(392.0, 528.0));
    }

    public function advance(fontId:FontId, glyphId:GlyphId):Size {
        return new Size(600.0 * (glyphId:Int), 0.0);
    }

    public function glyphForChar(fontId:FontId, ch:Int):Null<GlyphId> {
        return glaze.util.Utf8.utf16Length(ch);
    }

    public function glyphRasterBounds(params:RenderGlyphParams):Bounds {
        return new Bounds();
    }

    public function rasterizeGlyph(params:RenderGlyphParams, rasterBounds:Bounds):Bytes {
        return Bytes.alloc(0);
    }

    public function layoutLine(text:String, fontSize:Pixels, runs:Array<FontRun>):LineLayout {
        var position:Float = 0.0;
        final metrics = fontMetrics(0);
        final emWidth = fontSize * advance(0, glyphForChar(0, 'm'.code)).width / metrics.unitsPerEm;
        final glyphs:Array<ShapedGlyph> = [];
        final decoded = new glaze.util.Utf8.Utf8Text(text);
        for (k in 0...decoded.count) {
            final ix = decoded.byteOffsets[k];
            final glyph:Int = glyphForChar(0, decoded.codePoints[k]);
            glyphs.push(new ShapedGlyph(glyph, new Point(position, 0.0), ix, glyph == 2));
            if (glyph == 2) {
                position += emWidth * 2.0;
            }
            else {
                position += emWidth;
            }
        }
        final runs:Array<ShapedRun> = [];
        if (glyphs.length > 0) {
            runs.push(new ShapedRun(0, glyphs));
        }
        else {
            position = 0.0;
        }

        return new LineLayout(fontSize, position, fontSize * (metrics.ascent / metrics.unitsPerEm), fontSize * (metrics.descent / metrics.unitsPerEm), runs, decoded.byteLength);
    }

    public function recommendedRenderingMode(fontId:FontId, fontSize:Pixels):TextRenderingMode {
        return Grayscale;
    }

    public function glyphDilationForColor(color:Hsla):Int {
        return 0;
    }

}
