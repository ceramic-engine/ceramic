// Original code (not a port), written for ceramic-gpui: gives lunasvg the
// fonts of the GPUI text system, so that SVG <text> renders.
// MIT License, see Ceramic's LICENSE file.
package gpui.platform;

/**
 * A `lunasvg.FontProvider` over the faces of a `CeramicTextSystem` (the
 * fonts added to the GPUI text system). Installed by `SvgRenderer` the
 * first time an SVG is rendered (unless another provider is set with
 * `lunasvg.Lunasvg.setFontProvider()`).
 */
class SvgFontProvider implements lunasvg.FontProvider {

    final textSystem:CeramicTextSystem;

    final faces:Map<String, SvgFontFace> = new Map();

    public function new(textSystem:CeramicTextSystem) {
        this.textSystem = textSystem;
    }

    public function getFontFace(family:String, bold:Bool, italic:Bool):Null<lunasvg.FontProvider.FontFace> {
        final face = textSystem.faceForFamily(family, bold, italic);
        if (face == null)
            return null;
        final key = face.familyName + ':' + face.weight + ':' + face.italic + ':' + face.faceIndex;
        var result = faces.get(key);
        if (result == null) {
            result = new SvgFontFace(face);
            faces.set(key, result);
        }
        return result;
    }

}

/**
 * A `lunasvg.FontFace` over a `ttf.Font`.
 */
class SvgFontFace implements lunasvg.FontProvider.FontFace {

    final font:ttf.Font;

    final sink:ttf.PathOutlineSink = new ttf.PathOutlineSink();

    final box:ttf.GlyphBox = new ttf.GlyphBox();

    public function new(font:ttf.Font) {
        this.font = font;
    }

    inline function scale(size:Float):Float {
        return size / font.unitsPerEm;
    }

    public function getMetrics(size:Float, metrics:lunasvg.FontProvider.FontMetrics):Void {
        final s = scale(size);
        metrics.ascent = font.metrics.ascent * s;
        metrics.descent = font.metrics.descent * s;
        metrics.lineGap = font.metrics.lineGap * s;
    }

    public function getGlyphAdvance(codepoint:Int, size:Float):Float {
        return font.advance(font.glyphForChar(codepoint)) * scale(size);
    }

    public function getGlyphExtents(codepoint:Int, size:Float, extents:plutovg.Rect):Void {
        final s = scale(size);
        font.glyphBox(font.glyphForChar(codepoint), box);
        extents.x = box.xMin * s;
        extents.y = -box.yMax * s;
        extents.w = (box.xMax - box.xMin) * s;
        extents.h = (box.yMax - box.yMin) * s;
    }

    public function addGlyphPath(codepoint:Int, size:Float, x:Float, y:Float, path:plutovg.Path):Float {
        final gid = font.glyphForChar(codepoint);
        final s = scale(size);
        sink.path = path;
        sink.setTransform(s, x, y);
        font.outline(gid, sink);
        return font.advance(gid) * s;
    }

}
