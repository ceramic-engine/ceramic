package ceramic;

// Substantial portion taken from luxe (https://github.com/underscorediscovery/luxe/blob/4c891772f54b4769c72515146bedde9206a7b986/phoenix/BitmapFont.hx)

using unifill.Unifill;
using ceramic.Extensions;

class BitmapFont extends Entity {

    /** The map of font texture pages to their id. */
    public var pages:Map<Int,Texture> = new Map();

    /** The bitmap font fontData. */
    private var fontData(default, set):BitmapFontData;
    function set_fontData(fontData:BitmapFontData) {

        this.fontData = fontData;

        if (fontData != null) {
            spaceChar = fontData.chars.get(32);

            // Use regular space glyph data as no-break space
            // if there is no explicit no-break space glyph in data.
            if (fontData.chars.get(160) == null) {
                fontData.chars.set(160, spaceChar);
            }
        }

        return fontData;

    } //fontData

    public var face(get,set):String;
    inline function get_face():String { return fontData.face; }
    inline function set_face(face:String):String { return fontData.face = face; }

    public var pointSize(get,set):Float;
    inline function get_pointSize():Float { return fontData.pointSize; }
    inline function set_pointSize(pointSize:Float):Float { return fontData.pointSize = pointSize; }

    public var baseSize(get,set):Float;
    inline function get_baseSize():Float { return fontData.baseSize; }
    inline function set_baseSize(baseSize:Float):Float { return fontData.baseSize = baseSize; }

    public var chars(get,set):Map<Int,BitmapFontCharacter>;
    inline function get_chars():Map<Int,BitmapFontCharacter> { return fontData.chars; }
    inline function set_chars(chars:Map<Int,BitmapFontCharacter>):Map<Int,BitmapFontCharacter> { return fontData.chars = chars; }

    public var charCount(get,set):Int;
    inline function get_charCount():Int { return fontData.charCount; }
    inline function set_charCount(charCount:Int):Int { return fontData.charCount = charCount; }

    public var lineHeight(get,set):Float;
    inline function get_lineHeight():Float { return fontData.lineHeight; }
    inline function set_lineHeight(lineHeight:Float):Float { return fontData.lineHeight = lineHeight; }

    public var kernings(get,set):Map<Int,Map<Int,Float>>;
    inline function get_kernings():Map<Int,Map<Int,Float>> { return fontData.kernings; }
    inline function set_kernings(kernings:Map<Int,Map<Int,Float>>):Map<Int,Map<Int,Float>> { return fontData.kernings = kernings; }

    /** Cached reference of the ' '(32) character, for sizing on tabs/spaces */
    public var spaceChar:BitmapFontCharacter;
    
    public var asset:Asset;

/// Lifecycle

    public function new(fontData:BitmapFontData, pages:Map<String,Texture>) {

        super();

        this.fontData = fontData;

        if (fontData == null) {
            throw 'BitmapFont: fontData is null';
        }
        if (pages == null) {
            throw 'BitmapFont: pages is null';
        }

        for (pageInfo in fontData.pages) {
            var texture = pages.get(pageInfo.file);
            if (texture == null) {
                throw 'BitmapFont: missing texture for file ' + pageInfo.file;
            }
            this.pages.set(pageInfo.id, texture);
        }

    } //new

    override function destroy() {

        super.destroy();

        if (asset != null) asset.destroy();
        
        for (texture in pages) {
            texture.destroy();
        }
        pages = null;

    } //destroy

/// Public API

    /** Returns the kerning between two glyphs, or 0 if none.
        A glyph int id is the value from 'c'.charCodeAt(0) */
    public inline function kerning(first:Int, second:Int) {

        var map = fontData.kernings.get(first);

        if (map != null && map.exists(second)) {
            return map.get(second);
        }

        return 0;

    } //kerning

} //BitmapFont
