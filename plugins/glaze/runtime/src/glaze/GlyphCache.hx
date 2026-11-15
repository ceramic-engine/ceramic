package glaze;

import ceramic.GenericIntMap;
import haxe.io.FPHelper;

/**
 * A map keyed by `RenderGlyphParams`, with lookups that don't allocate.
 *
 * Rust hashes `RenderGlyphParams` in `FxHashMap`s (raster bounds of the
 * `TextSystem`, atlas tiles). Building a string key for every glyph painted
 * every frame would allocate, so this map nests `GenericIntMap`s: font id,
 * then the exact `f32` bits of the font size and of the scale factor, then
 * the glyph id combined with the subpixel variant, emoji, subpixel rendering
 * and dilation fields.
 *
 * `@:generic`, like `GenericIntMap`: each value type gets its own class, so
 * a lookup returns the value with its type (on hxcpp, no `Dynamic` return
 * and no call into the hxcpp library's `IntMap`; about 7 to 10 % of the
 * Cityscape text scenarios).
 */
@:generic
class GlyphCache<T> {

    final fonts:GenericIntMap<GenericIntMap<GenericIntMap<GenericIntMap<T>>>> = new GenericIntMap();

    /** Number of entries */
    public var size(default, null):Int = 0;

    public function new() {}

    /**
     * The innermost map found by the last `get`, with the font id, font size
     * and scale factor that led to it: the glyphs of a line share them, so
     * most lookups skip the three outer maps. Only an existing map is kept;
     * maps are never removed from `fonts` except by `clear`, which forgets
     * it. Sizes are compared as numbers and zero is never kept, so a hit
     * always has the same `f32` bits as the outer keys (`0.0` and `-0.0`
     * are equal numbers but different keys; NaN never compares equal).
     */
    var lastGlyphs:Null<GenericIntMap<T>> = null;
    var lastFontId:Int = 0;
    var lastFontSize:Float = 0;
    var lastScaleFactor:Float = 0;

    public function get(params:RenderGlyphParams):Null<T> {
        final fontSize:Float = params.fontSize;
        final scaleFactor:Float = params.scaleFactor;
        final lastGlyphs = this.lastGlyphs;
        if (lastGlyphs != null && (params.fontId:Int) == lastFontId && fontSize == lastFontSize && scaleFactor == lastScaleFactor) {
            return lastGlyphs.get(GlyphCacheKey.innerKey(params));
        }
        final sizes = fonts.get(params.fontId);
        if (sizes == null) return null;
        final scales = sizes.get(FPHelper.floatToI32(fontSize));
        if (scales == null) return null;
        final glyphs = scales.get(FPHelper.floatToI32(scaleFactor));
        if (glyphs == null) return null;
        if (fontSize != 0 && scaleFactor != 0) {
            this.lastGlyphs = glyphs;
            lastFontId = params.fontId;
            lastFontSize = fontSize;
            lastScaleFactor = scaleFactor;
        }
        return glyphs.get(GlyphCacheKey.innerKey(params));
    }

    public function set(params:RenderGlyphParams, value:T):Void {
        var sizes = fonts.get(params.fontId);
        if (sizes == null) {
            sizes = new GenericIntMap();
            fonts.set(params.fontId, sizes);
        }
        final sizeKey = FPHelper.floatToI32(params.fontSize);
        var scales = sizes.get(sizeKey);
        if (scales == null) {
            scales = new GenericIntMap();
            sizes.set(sizeKey, scales);
        }
        final scaleKey = FPHelper.floatToI32(params.scaleFactor);
        var glyphs = scales.get(scaleKey);
        if (glyphs == null) {
            glyphs = new GenericIntMap();
            scales.set(scaleKey, glyphs);
        }
        final key = GlyphCacheKey.innerKey(params);
        if (!glyphs.exists(key))
            size++;
        glyphs.set(key, value);
    }

    public function remove(params:RenderGlyphParams):Bool {
        final sizes = fonts.get(params.fontId);
        if (sizes == null) return false;
        final scales = sizes.get(FPHelper.floatToI32(params.fontSize));
        if (scales == null) return false;
        final glyphs = scales.get(FPHelper.floatToI32(params.scaleFactor));
        if (glyphs == null) return false;
        if (glyphs.remove(GlyphCacheKey.innerKey(params))) {
            size--;
            return true;
        }
        return false;
    }

    public function clear():Void {
        fonts.clear();
        lastGlyphs = null;
        size = 0;
    }

}

/**
 * Inner key of `GlyphCache` (a `@:generic` class can't have static fields).
 */
private class GlyphCacheKey {

    public static inline function innerKey(params:RenderGlyphParams):Int {
        final key = ((((((params.glyphId:Int) * 4 + params.subpixelVariantX) * 2 + params.subpixelVariantY) * 2 + (params.isEmoji ? 1 : 0)) * 2 + (params.subpixelRendering ? 1 : 0)) * 16) + params.dilation;
        // Rotated right by 8 bits (a bijection, so keys stay distinct): the
        // glyph id ends up in the low bits. hxcpp's IntMap, used before
        // GenericIntMap, took the key as its own hash and picked the bucket
        // from the low bits, where the variant fields are almost always the
        // same. GenericIntMap mixes its keys, the rotation stays harmless.
        return (key >>> 8) | (key << 24);
    }

}
