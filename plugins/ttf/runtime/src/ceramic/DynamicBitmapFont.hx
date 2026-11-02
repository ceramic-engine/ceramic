package ceramic;

import ceramic.BitmapFontData;
import ceramic.Shortcuts.*;
import ceramic.TtfGlyphAtlas.TtfAtlasGlyph;
import ttf.shape.Script;
import ttf.shape.Shaper;

/**
 * A `BitmapFont` created from a TrueType / OpenType font, whose glyphs are
 * rasterized on demand (the first time `ceramic.Text` needs them) into a
 * dynamic glyph atlas, so that `ceramic.Text` can use a `.ttf` / `.otf`
 * font directly, without any precomputed bitmap font.
 *
 * The font is rendered at `pixelSize * density` device pixels per em, without
 * hinting. Glyph metrics follow the `BitmapFont` conventions: they are
 * expressed in device pixels, `pointSize` being `pixelSize * density`, and the
 * page textures have the same `density`, so a `Text` with
 * `pointSize = pixelSize` is displayed at the rasterized size. Use one font
 * per size for the sharpest result (see `TtfFontAsset.bitmapFont()`).
 *
 * Kerning pairs between loaded characters are computed when characters are
 * added (`GPOS` kerning or legacy `kern` table). Ligatures and other
 * contextual substitutions are not applied (`ceramic.Text` lays out
 * characters one by one): use `TtfText` for shaped text.
 *
 * Characters missing from the font are taken from `fallbacks` (in order),
 * otherwise the `.notdef` glyph of the font is used. Control characters get
 * an empty glyph.
 *
 * Glyphs are never evicted: the atlas grows by pages of `pageSize` pixels.
 */
class DynamicBitmapFont extends BitmapFont {

    /**
     * The font to rasterize.
     */
    public var ttfFont(default, null):ttf.Font;

    /**
     * Fonts used for characters missing from `ttfFont`.
     */
    public var fallbacks(default, null):Array<ttf.Font>;

    /**
     * Size in logical pixels per em.
     */
    public var pixelSize(default, null):Float;

    /**
     * Rendering density (`screen.texturesDensity` by default).
     */
    public var density(default, null):Float;

    /**
     * The glyph atlas holding the rasterized characters.
     */
    public var glyphAtlas(default, null):TtfGlyphAtlas;

    /**
     * Baseline position from the top of a line, in device pixels.
     */
    public var baseline(default, null):Float;

    var atlasGlyph:TtfAtlasGlyph = new TtfAtlasGlyph();

    var shaper:Shaper = new Shaper();

    // Characters loaded so far, with their font and glyph (for kerning pairs)
    var loadedCodes:Array<Int> = [];
    var loadedGlyphs:Array<Int> = [];
    var loadedFonts:Array<ttf.Font> = [];

    /**
     * @param font The font to rasterize
     * @param pixelSize Size in logical pixels per em
     * @param density Rendering density (-1 to use `screen.texturesDensity`)
     * @param fallbacks Fonts used for characters missing from `font`
     * @param pageSize Size of the atlas pages, in device pixels
     * @param preload Characters to rasterize right away
     */
    public function new(font:ttf.Font, pixelSize:Float, density:Float = -1, ?fallbacks:Array<ttf.Font>, pageSize:Int = 512, ?preload:String) {

        if (density <= 0)
            density = screen.texturesDensity;

        var deviceSize = pixelSize * density;
        var scale = deviceSize / font.unitsPerEm;
        var m = font.metrics;

        var data:BitmapFontData = {
            face: font.familyName,
            path: '.',
            pointSize: deviceSize,
            baseSize: deviceSize,
            chars: new IntMap(),
            charCount: 0,
            distanceField: null,
            pages: [],
            lineHeight: (m.ascent - m.descent + m.lineGap) * scale,
            kernings: new IntMap()
        };

        super(data, new Map());

        this.ttfFont = font;
        this.fallbacks = fallbacks != null ? fallbacks : [];
        this.pixelSize = pixelSize;
        this.density = density;
        this.baseline = Math.round(m.ascent * scale);
        this.providesMissingChars = true;

        glyphAtlas = new TtfGlyphAtlas(pageSize, 0, density);
        glyphAtlas.filter = NEAREST;
        // The first page always exists, so that empty glyphs have a valid page texture
        glyphAtlas.atlas.addPage();
        bindPage(0);

        spaceChar = getChar(32);
        if (chars.get(160) == null)
            chars.set(160, spaceChar);

        if (preload != null)
            this.preload(preload);

    }

    override function destroy():Void {

        super.destroy();

        if (glyphAtlas != null) {
            glyphAtlas.destroy();
            glyphAtlas = null;
        }

    }

    /**
     * Rasterizes the characters of `text` now (instead of on first use).
     */
    public function preload(text:String):Void {

        var i = 0;
        while (i < text.length) {
            var code = ttf.Utf8.codePointAt(text, i);
            getChar(code);
            i += ttf.Utf8.utf16Length(code);
        }

    }

    function bindPage(index:Int):Void {

        if (pages.exists(index))
            return;
        var texture = glyphAtlas.textures[index];
        pages.set(index, texture);
        @:privateAccess fontData.pages.push({ id: index, file: '' });

    }

    override function requestChar(code:Int):BitmapFontCharacter {

        if (glyphAtlas == null)
            return null;

        // Control characters: empty glyph without advance
        if (code < 32 || (code >= 0x7F && code < 0xA0)) {
            var empty:BitmapFontCharacter = {
                id: code, x: 0, y: 0, width: 0, height: 0,
                xOffset: 0, yOffset: 0, xAdvance: 0, page: 0
            };
            chars.set(code, empty);
            return empty;
        }

        // Pick the font (primary first, then fallbacks)
        var font = ttfFont;
        var gid = font.glyphForChar(code);
        if (gid == 0) {
            for (fallback in fallbacks) {
                var g = fallback.glyphForChar(code);
                if (g != 0) {
                    font = fallback;
                    gid = g;
                    break;
                }
            }
        }

        var fontScale = pointSize / font.unitsPerEm;
        var glyph = glyphAtlas.render(font, gid, pointSize, 0, atlasGlyph);
        if (glyph.width > 0)
            bindPage(glyph.page);

        var char:BitmapFontCharacter = {
            id: code,
            x: glyph.x,
            y: glyph.y,
            width: glyph.width,
            height: glyph.height,
            xOffset: glyph.left,
            yOffset: baseline - glyph.top,
            xAdvance: font.advance(gid) * fontScale,
            page: glyph.page
        };

        chars.set(code, char);
        charCount++;

        addKernings(code, gid, font, fontScale);

        loadedCodes.push(code);
        loadedGlyphs.push(gid);
        loadedFonts.push(font);

        return char;

    }

    /**
     * Computes kerning pairs between a new character and the loaded ones
     * (both orders), with the same font only.
     */
    function addKernings(code:Int, gid:Int, font:ttf.Font, fontScale:Float):Void {

        if (font.gpos == null && font.kern == null)
            return;

        var script = Script.of(code);
        if (script == Script.COMMON || script == Script.OTHER)
            script = Script.LATIN;

        var kernings = this.kernings;
        for (i in 0...loadedCodes.length) {
            if (loadedFonts[i] != font)
                continue;
            var other = loadedCodes[i];
            var otherGid = loadedGlyphs[i];
            var before = shaper.pairKerning(font, otherGid, gid, script);
            if (before != 0)
                setKerning(kernings, other, code, before * fontScale);
            var after = shaper.pairKerning(font, gid, otherGid, script);
            if (after != 0)
                setKerning(kernings, code, other, after * fontScale);
        }
        var self = shaper.pairKerning(font, gid, gid, script);
        if (self != 0)
            setKerning(kernings, code, code, self * fontScale);

    }

    static function setKerning(kernings:IntMap<IntFloatMap>, first:Int, second:Int, amount:Float):Void {

        var map = kernings.get(first);
        if (map == null) {
            map = new IntFloatMap();
            kernings.set(first, map);
        }
        map.set(second, amount);

    }

}
