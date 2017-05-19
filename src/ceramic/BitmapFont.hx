package ceramic;

// Substantial portion taken from luxe (https://github.com/underscorediscovery/luxe/blob/4c891772f54b4769c72515146bedde9206a7b986/phoenix/BitmapFont.hx)

import ceramic.internal.BitmapFontParser;

using unifill.Unifill;

class BitmapFont {

    /** The map of font texture pages to their id. */
    public var pages:Map<Int,Texture> = new Map();

    /** The bitmap font data. */
    public var data(default, set):BitmapFontData;
    function set_data(data:BitmapFontData) {

        this.data = data;

        if (data != null) {
            spaceChar = data.chars.get(32);
        }

        return data;

    } //data

    /** Cached reference of the ' '(32) character, for sizing on tabs/spaces */
    public var spaceChar:BitmapFontCharacter;

    public function new(data:BitmapFontData, pages:Map<String,Texture>) {

        this.data = data;

        if (data == null) {
            throw 'BitmapFont: data is null';
        }
        if (pages == null) {
            throw 'BitmapFont: pages is null';
        }

        for (pageInfo in data.pages) {
            var texture = pages.get(pageInfo.file);
            if (texture == null) {
                throw 'BitmapFont: missing texture for file ' + pageInfo.file;
            }
            this.pages.set(pageInfo.id, texture);
        }

    } //new

/// Public API

    /** Returns the kerning between two glyphs, or 0 if none.
        A glyph int id is the value from 'c'.charCodeAt(0) */
    public inline function kerning(first:Int, second:Int) {

        var map = data.kernings.get(first);

        if (map != null && map.exists(second)) {
            return map.get(second);
        }

        return 0;

    } //kerning

} //BitmapFont

@:structInit
class BitmapFontCharacter {
    public var id: Int;
    public var x: Float;
    public var y: Float;
    public var width: Float;
    public var height: Float;
    public var xOffset: Float;
    public var yOffset: Float;
    public var xAdvance: Float;
    public var page: Int;
}

@:structInit
class BitmapFontData {
    public var face: String;
    public var pointSize: Float;
    public var baseSize: Float;
    public var chars: Map<Int, BitmapFontCharacter>;
    public var charCount: Int;
    public var pages: Array<{ id : Int, file : String }>;
    public var lineHeight: Float;
    public var kernings: Map< Int, Map<Int, Float> >;
}
