package ceramic;

import ceramic.Shortcuts.*;
import ttf.GlyphRasterizer;
import ttf.shape.Features;
import ttf.shape.FontRun;
import ttf.shape.LineLayout;
import ttf.shape.Shaper;

using ceramic.Extensions;

/**
 * A visual displaying shaped text from TrueType / OpenType fonts.
 *
 * Unlike `ceramic.Text` with a `DynamicBitmapFont`, the text goes through
 * the `ttf` shaper: ligatures and contextual alternates (`GSUB`), kerning and
 * mark positioning (`GPOS`), and per character font fallback. Glyphs are
 * rasterized at the exact device size with 4 horizontal subpixel variants
 * (like GPUI) into a shared `TtfGlyphAtlas`, and drawn on whole device pixels.
 *
 * Lines are separated with `\n`. There is no automatic wrapping.
 *
 * ```haxe
 * var text = new TtfText();
 * text.font = assets.ttfFont('fonts/JetBrainsMono');
 * text.fontSize = 18;
 * text.content = 'a -> b != c';
 * add(text);
 * ```
 */
class TtfText extends Visual {

    static var shaper:Shaper = null;

    static var layout:LineLayout = new LineLayout();

    /**
     * The text to display.
     */
    public var content(default, set):String = '';
    function set_content(content:String):String {
        if (this.content == content) return content;
        this.content = content;
        contentDirty = true;
        return content;
    }

    /**
     * Primary font.
     */
    public var font(default, set):ttf.Font = null;
    function set_font(font:ttf.Font):ttf.Font {
        if (this.font == font) return font;
        this.font = font;
        contentDirty = true;
        return font;
    }

    /**
     * Fonts used for characters missing from `font`, in order.
     */
    public var fallbacks(default, set):Array<ttf.Font> = null;
    function set_fallbacks(fallbacks:Array<ttf.Font>):Array<ttf.Font> {
        this.fallbacks = fallbacks;
        contentDirty = true;
        return fallbacks;
    }

    /**
     * OpenType features (null for the defaults: kerning, ligatures, contextual alternates...).
     */
    public var features(default, set):Features = null;
    function set_features(features:Features):Features {
        if (this.features == features) return features;
        this.features = features;
        contentDirty = true;
        return features;
    }

    /**
     * Font size, in logical pixels per em.
     */
    public var fontSize(default, set):Float = 16;
    function set_fontSize(fontSize:Float):Float {
        if (this.fontSize == fontSize) return fontSize;
        this.fontSize = fontSize;
        contentDirty = true;
        return fontSize;
    }

    /**
     * Line height multiplier (1 uses the font ascent, descent and line gap).
     */
    public var lineHeight(default, set):Float = 1;
    function set_lineHeight(lineHeight:Float):Float {
        if (this.lineHeight == lineHeight) return lineHeight;
        this.lineHeight = lineHeight;
        contentDirty = true;
        return lineHeight;
    }

    /**
     * Text color.
     */
    public var color(default, set):Color = Color.WHITE;
    function set_color(color:Color):Color {
        if (this.color == color) return color;
        this.color = color;
        for (i in 0...quads.length)
            quads.unsafeGet(i).color = color;
        return color;
    }

    /**
     * Glyph atlas used to render the glyphs (`TtfGlyphAtlas.shared` by default).
     */
    public var glyphAtlas(default, set):TtfGlyphAtlas = null;
    function set_glyphAtlas(glyphAtlas:TtfGlyphAtlas):TtfGlyphAtlas {
        if (this.glyphAtlas == glyphAtlas) return glyphAtlas;
        if (this.glyphAtlas != null)
            this.glyphAtlas.offPageEvicted(handlePageEvicted);
        this.glyphAtlas = glyphAtlas;
        if (glyphAtlas != null)
            glyphAtlas.onPageEvicted(this, handlePageEvicted);
        contentDirty = true;
        return glyphAtlas;
    }

    /**
     * Number of lines of the last layout.
     */
    public var numLines(default, null):Int = 0;

    var quads:Array<Quad> = [];

    var evictedDuringLayout:Bool = false;

    var computingContent:Bool = false;

    public function new() {

        super();

        if (shaper == null)
            shaper = new Shaper();

        glyphAtlas = TtfGlyphAtlas.shared;

    }

    override function destroy():Void {

        glyphAtlas = null;
        super.destroy();

    }

    override function get_width():Float {
        if (contentDirty) computeContent();
        return super.get_width();
    }

    override function get_height():Float {
        if (contentDirty) computeContent();
        return super.get_height();
    }

    function handlePageEvicted(page:Int):Void {

        if (computingContent)
            evictedDuringLayout = true;
        contentDirty = true;

    }

    override function computeContent():Void {

        computingContent = true;
        evictedDuringLayout = false;

        var usedQuads = 0;
        var maxWidth = 0.0;
        var y = 0.0;
        numLines = 0;

        if (font != null && glyphAtlas != null) {

            var atlas = glyphAtlas;
            var density = atlas.density;
            var deviceSize = fontSize * density;
            var variants = GlyphRasterizer.SUBPIXEL_VARIANTS_X;
            var runFeatures = features;

            var lines = content.split('\n');
            for (l in 0...lines.length) {
                var line = lines[l];
                var runs = [new FontRun(ttf.Utf8.byteLength(line), font, fallbacks, runFeatures)];
                shaper.layoutLine(line, deviceSize, runs, layout);

                // Baseline on a whole device pixel
                var m = font.metrics;
                var scale = deviceSize / font.unitsPerEm;
                var ascent = Math.max(layout.ascent, m.ascent * scale);
                var descent = Math.max(layout.descent, -m.descent * scale);
                var lineGap = m.lineGap * scale;
                var baseline = Math.round(y * density + ascent);

                for (r in 0...layout.runs.length) {
                    var run = layout.runs[r];
                    var glyphs = run.glyphs;
                    for (g in 0...glyphs.length) {
                        var glyph = glyphs[g];
                        // Quantize the pen position into subpixel variants, like GPUI
                        var quantized = Math.round(glyph.x * variants) / variants;
                        var whole = Math.floor(quantized);
                        var variant = Std.int((quantized - whole) * variants);
                        var entry = atlas.glyph(run.font, glyph.id, deviceSize, variant);
                        if (entry.width == 0)
                            continue;

                        var quad:Quad = usedQuads < quads.length ? quads[usedQuads] : null;
                        if (quad == null) {
                            quad = new Quad();
                            quad.inheritAlpha = true;
                            quads.push(quad);
                            add(quad);
                        }
                        usedQuads++;

                        quad.texture = atlas.textures[entry.page];
                        quad.color = color;
                        quad.depth = 0;
                        quad.frame(
                            entry.x / density,
                            entry.y / density,
                            entry.width / density,
                            entry.height / density
                        );
                        quad.pos(
                            (whole + entry.left) / density,
                            (baseline + Math.round(glyph.y) - entry.top) / density
                        );
                        quad.size(entry.width / density, entry.height / density);
                    }
                }

                if (layout.width / density > maxWidth)
                    maxWidth = layout.width / density;
                y += (ascent + descent + lineGap) * lineHeight / density;
                numLines++;
            }
        }

        // Remove unused quads
        while (usedQuads < quads.length) {
            var quad = quads.pop();
            quad.destroy();
        }

        width = Math.round(maxWidth * 1000) / 1000;
        height = Math.round(y * 1000) / 1000;

        computingContent = false;
        contentDirty = evictedDuringLayout;

    }

}
