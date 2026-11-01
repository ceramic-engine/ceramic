package gpui;

import haxe.ds.IntMap;
import haxe.io.FPHelper;

/**
 * A map keyed by `RenderGlyphParams`, with lookups that don't allocate.
 *
 * Rust hashes `RenderGlyphParams` in `FxHashMap`s (raster bounds of the
 * `TextSystem`, atlas tiles). Building a string key for every glyph painted
 * every frame would allocate, so this map nests `IntMap`s: font id, then the
 * exact `f32` bits of the font size and of the scale factor, then the glyph
 * id combined with the subpixel variant, emoji, subpixel rendering and
 * dilation fields.
 */
class GlyphCache<T> {

    final fonts:IntMap<IntMap<IntMap<IntMap<T>>>> = new IntMap();

    /** Number of entries */
    public var size(default, null):Int = 0;

    public function new() {}

    static inline function innerKey(params:RenderGlyphParams):Int {
        return ((((((params.glyphId:Int) * 4 + params.subpixelVariantX) * 2 + params.subpixelVariantY) * 2 + (params.isEmoji ? 1 : 0)) * 2 + (params.subpixelRendering ? 1 : 0)) * 16) + params.dilation;
    }

    public function get(params:RenderGlyphParams):Null<T> {
        final sizes = fonts.get(params.fontId);
        if (sizes == null) return null;
        final scales = sizes.get(FPHelper.floatToI32(params.fontSize));
        if (scales == null) return null;
        final glyphs = scales.get(FPHelper.floatToI32(params.scaleFactor));
        if (glyphs == null) return null;
        return glyphs.get(innerKey(params));
    }

    public function set(params:RenderGlyphParams, value:T):Void {
        var sizes = fonts.get(params.fontId);
        if (sizes == null) {
            sizes = new IntMap();
            fonts.set(params.fontId, sizes);
        }
        final sizeKey = FPHelper.floatToI32(params.fontSize);
        var scales = sizes.get(sizeKey);
        if (scales == null) {
            scales = new IntMap();
            sizes.set(sizeKey, scales);
        }
        final scaleKey = FPHelper.floatToI32(params.scaleFactor);
        var glyphs = scales.get(scaleKey);
        if (glyphs == null) {
            glyphs = new IntMap();
            scales.set(scaleKey, glyphs);
        }
        final key = innerKey(params);
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
        if (glyphs.remove(innerKey(params))) {
            size--;
            return true;
        }
        return false;
    }

    public function clear():Void {
        fonts.clear();
        size = 0;
    }

}
