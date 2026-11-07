// Ported from gpui-pre-web 0.3.10: src/glyph_cache.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.platform;

/**
 * A grapheme drawn by the browser (Rust `CanvasGlyph`): its glyph id is its
 * index in the `CanvasGlyphCache`.
 */
class CanvasGlyph {

    public final fontId:FontId;

    public final text:String;

    public final color:Bool;

    public function new(fontId:FontId, text:String, color:Bool) {
        this.fontId = fontId;
        this.text = text;
        this.color = color;
    }

}

/**
 * Glyph ids of the graphemes drawn by the browser (Rust `GlyphCache`): one
 * id per canvas font, grapheme and presentation, numbered in insertion order
 * across all fonts.
 */
class CanvasGlyphCache {

    final glyphs:Array<CanvasGlyph> = [];

    /** Ids by `fontId:color` then by text */
    final idsByFont:Map<String, Map<String, Int>> = new Map();

    public function new() {}

    /** Number of glyphs registered */
    public var length(get, never):Int;

    inline function get_length():Int {
        return glyphs.length;
    }

    static inline function fontKey(fontId:FontId, color:Bool):String {
        return (fontId:Int) + (color ? ':1' : ':0');
    }

    public function idFor(fontId:FontId, text:String, color:Bool):Null<GlyphId> {
        final ids = idsByFont.get(fontKey(fontId, color));
        if (ids == null)
            return null;
        final id = ids.get(text);
        return id != null ? (id:GlyphId) : null;
    }

    public function getOrInsert(fontId:FontId, text:String, color:Bool):GlyphId {
        final existing = idFor(fontId, text, color);
        if (existing != null)
            return existing;
        // `u32::try_from(len)`
        if (glyphs.length >= 0x7FFFFFFF)
            throw 'Canvas glyph ID space exhausted';
        final glyphId = glyphs.length;
        glyphs.push(new CanvasGlyph(fontId, text, color));
        final key = fontKey(fontId, color);
        var ids = idsByFont.get(key);
        if (ids == null) {
            ids = new Map();
            idsByFont.set(key, ids);
        }
        ids.set(text, glyphId);
        return glyphId;
    }

    /** The glyph of an id, or null when the id is unknown or belongs to another font */
    public function glyph(fontId:FontId, glyphId:GlyphId):Null<CanvasGlyph> {
        final index:Int = glyphId;
        if (index < 0 || index >= glyphs.length)
            return null;
        final glyph = glyphs[index];
        return (glyph.fontId:Int) == (fontId:Int) ? glyph : null;
    }

}
