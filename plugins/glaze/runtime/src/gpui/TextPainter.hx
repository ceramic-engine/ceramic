// Ported from gpui-pre 0.3.10: src/window.rs (paint_glyph, paint_emoji, paint_underline,
// paint_strikethrough, paint_layer, underline_bounds, snapping helpers), src/util.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.AtlasTile;
import gpui.scene.Scene;

/**
 * Emits text primitives (glyph sprites, underlines, strikethroughs, run
 * backgrounds) into a `Scene`, like GPUI's `Window::paint_glyph`,
 * `paint_emoji`, `paint_underline`, `paint_strikethrough` and
 * `paint_layer`.
 *
 * It holds the window state these functions read: the scene being
 * painted, the sprite atlas, the text system, the scale factor, the
 * element opacity and the content mask (in logical pixels). A `Window`
 * keeps one painter, refreshes these fields before painting text (or
 * calls the static `emitGlyph()` from its own `paintGlyph()`), and gives
 * the painter to `ShapedLine.paint()` / `WrappedLine.paint()`.
 *
 * Glyph origins are quantized like GPUI: the x coordinate (in scaled
 * pixels) is rounded to a quarter pixel (`SUBPIXEL_VARIANTS_X` = 4), the
 * fraction selects one of 4 pre-rendered subpixel variants and the
 * integer part positions the sprite.
 *
 * Painting a glyph whose atlas tile already exists does not allocate.
 */
class TextPainter {

    /** Scene receiving the primitives */
    public var scene:Scene;

    /** Atlas holding glyph tiles (`SceneRenderable.atlasTextures` maps their texture indices) */
    public var atlas:PlatformAtlas;

    public var textSystem:TextSystem;

    /** Scale factor (device pixels per logical pixel) */
    public var scaleFactor:Float;

    /** Opacity applied to colors (`Window::element_opacity`) */
    public var elementOpacity:Float = 1.0;

    /** Current content mask, in logical pixels (`Window::content_mask`) */
    public var contentMaskBounds:Bounds;

    /**
     * When set, run backgrounds are painted with this function (usually
     * `Window.paintQuad`), otherwise a solid quad is emitted directly.
     */
    public var quadPainter:Null<PaintQuad->Void> = null;

    /** Text rendering mode (`Window::text_rendering_mode`); subpixel sprites are not supported yet */
    public var textRenderingMode:TextRenderingMode = PlatformDefault;

    final params:RenderGlyphParams = new RenderGlyphParams();

    var layerDepth:Int = 0;

    public function new(scene:Scene, atlas:PlatformAtlas, textSystem:TextSystem, scaleFactor:Float = 1.0, ?contentMaskBounds:Bounds) {
        this.scene = scene;
        this.atlas = atlas;
        this.textSystem = textSystem;
        this.scaleFactor = scaleFactor;
        this.contentMaskBounds = contentMaskBounds != null ? contentMaskBounds : new Bounds(new Point(0, 0), new Size(1e9, 1e9));
    }

    /** The current content mask */
    public inline function contentMask():ContentMask {
        return new ContentMask(contentMaskBounds);
    }

/// Rounding helpers (src/util.rs)

    /** Rounds to the nearest integer with 0.5 ties toward zero. */
    public static inline function roundHalfTowardZero(value:Float):Float {
        // Rust: `(value.abs() - 0.5).ceil().copysign(value)`; the ceil of
        // a small magnitude is -0.0, so the sign must come from `value`
        return gpui.util.MathUtil.copysign(Math.fceil(Math.abs(value) - 0.5), value);
    }

    public static inline function roundToDevicePixel(logical:Float, scaleFactor:Float):Float {
        return roundHalfTowardZero(logical * scaleFactor);
    }

    public static inline function roundStrokeToDevicePixel(logical:Float, scaleFactor:Float):Float {
        return logical == 0.0 ? 0.0 : Math.max(roundToDevicePixel(Math.max(logical, 0.0), scaleFactor), 1.0);
    }

    static inline function trunc(value:Float):Float {
        return value < 0 ? Math.fceil(value) : Math.ffloor(value);
    }

/// Layers

    /**
     * Starts a layer covering `bounds` (clipped by the content mask), like
     * `Window::paint_layer`. Returns false (and pushes nothing) when the
     * clipped bounds are empty; call `popLayer()` only when it returned true.
     */
    public function pushLayer(bounds:Bounds):Bool {
        final mask = contentMaskBounds;
        if (!pushCoverLayer(scene, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height, mask.origin.x, mask.origin.y, mask.size.width, mask.size.height, scaleFactor))
            return false;
        layerDepth++;
        return true;
    }

    /**
     * The body of `Window::paint_layer`: clips the bounds by the mask
     * (`Bounds::intersect`), then pushes a layer covering them
     * (`Window::cover_bounds`). Returns false (and pushes nothing) when the
     * clipped bounds are empty.
     *
     * Every step is rounded to `f32` like GPUI's `Bounds<Pixels>` math:
     * a far edge computed in f64 can land just above an integer that the
     * f32 sum rounds to exactly (66.4000015 + 54.6000023 is 121.0000038
     * in f64 and 121.0 in f32), and the ceiled layer then overlaps the next pixel
     * column, which raises the draw order of what is painted there.
     */
    public static function pushCoverLayer(scene:Scene, x:Float, y:Float, width:Float, height:Float, maskX:Float, maskY:Float, maskWidth:Float, maskHeight:Float, scaleFactor:Float):Bool {
        // Bounds::intersect: upper_left = max of the origins, bottom_right =
        // min of the bottom right corners (then at least upper_left)
        x = SpringMath.f32(x);
        y = SpringMath.f32(y);
        maskX = SpringMath.f32(maskX);
        maskY = SpringMath.f32(maskY);
        final left = Math.max(x, maskX);
        final top = Math.max(y, maskY);
        final right = Math.max(Math.min(SpringMath.f32(x + SpringMath.f32(width)), SpringMath.f32(maskX + SpringMath.f32(maskWidth))), left);
        final bottom = Math.max(Math.min(SpringMath.f32(y + SpringMath.f32(height)), SpringMath.f32(maskY + SpringMath.f32(maskHeight))), top);
        // Bounds::from_corners, then is_empty
        final clippedWidth = SpringMath.f32(right - left);
        final clippedHeight = SpringMath.f32(bottom - top);
        if (clippedWidth <= 0 || clippedHeight <= 0)
            return false;
        // cover_bounds: floor near edges, ceil far edges (right() and
        // bottom() add the size back in f32)
        final scale = SpringMath.f32(scaleFactor);
        final l = Math.ffloor(SpringMath.f32(left * scale));
        final t = Math.ffloor(SpringMath.f32(top * scale));
        final r = Math.max(Math.fceil(SpringMath.f32(SpringMath.f32(left + clippedWidth) * scale)), l);
        final b = Math.max(Math.fceil(SpringMath.f32(SpringMath.f32(top + clippedHeight) * scale)), t);
        scene.pushLayer(l, t, r - l, b - t);
        return true;
    }

    public function popLayer():Void {
        if (layerDepth > 0) {
            layerDepth--;
            scene.popLayer();
        }
    }

/// Content mask

    var maskX:Float = 0;
    var maskY:Float = 0;
    var maskW:Float = 0;
    var maskH:Float = 0;

    /** Covers the content mask with device pixels (floor near edges, ceil far edges) */
    inline function snapContentMask():Void {
        final bounds = contentMaskBounds;
        final left = Math.ffloor(bounds.origin.x * scaleFactor);
        final top = Math.ffloor(bounds.origin.y * scaleFactor);
        final right = Math.max(Math.fceil((bounds.origin.x + bounds.size.width) * scaleFactor), left);
        final bottom = Math.max(Math.fceil((bounds.origin.y + bounds.size.height) * scaleFactor), top);
        maskX = left;
        maskY = top;
        maskW = right - left;
        maskH = bottom - top;
    }

/// Glyphs

    /**
     * Paints a monochrome (non-emoji) glyph. The y component of the origin
     * is the baseline of the glyph.
     */
    public inline function paintGlyph(origin:Point, fontId:FontId, glyphId:GlyphId, fontSize:Pixels, color:Hsla):Void {
        paintGlyphAt(origin.x, origin.y, fontId, glyphId, fontSize, color);
    }

    /** `paintGlyph()` with the origin given as two floats */
    public function paintGlyphAt(x:Float, y:Float, fontId:FontId, glyphId:GlyphId, fontSize:Pixels, color:Hsla):Void {
        snapContentMask();
        emitGlyph(scene, atlas, textSystem, params, scaleFactor, elementOpacity, maskX, maskY, maskW, maskH, x, y, fontId, glyphId, fontSize, color);
    }

    /**
     * Port of `Window::paint_glyph` that a `Window` can call directly:
     * quantizes the origin into a subpixel variant, gets (or rasterizes)
     * the atlas tile and commits a `MonochromeSprite`.
     *
     * `params` is a scratch object (overwritten), the mask is the snapped
     * content mask in scaled pixels, the origin is in logical pixels.
     * Returns false if nothing was painted (empty glyph).
     */
    public static function emitGlyph(scene:Scene, atlas:PlatformAtlas, textSystem:TextSystem, params:RenderGlyphParams, scaleFactor:Float, elementOpacity:Float, maskX:Float, maskY:Float, maskW:Float, maskH:Float, originX:Float, originY:Float, fontId:FontId, glyphId:GlyphId, fontSize:Pixels, color:Hsla):Bool {
        final glyphOriginX = originX * scaleFactor;
        final glyphOriginY = originY * scaleFactor;

        final quantizedX = roundHalfTowardZero(glyphOriginX * TextSystem.SUBPIXEL_VARIANTS_X) / TextSystem.SUBPIXEL_VARIANTS_X;
        final quantizedY = roundHalfTowardZero(glyphOriginY * TextSystem.SUBPIXEL_VARIANTS_Y) / TextSystem.SUBPIXEL_VARIANTS_Y;
        // `(fract * variants) as u8` saturates negative fractions to 0
        final variantX = gpui.util.MathUtil.toU8((quantizedX - trunc(quantizedX)) * TextSystem.SUBPIXEL_VARIANTS_X);
        final variantY = gpui.util.MathUtil.toU8((quantizedY - trunc(quantizedY)) * TextSystem.SUBPIXEL_VARIANTS_Y);
        final integerX = trunc(quantizedX);
        final integerY = trunc(quantizedY);

        // Subpixel (LCD) sprites are not supported by the Ceramic renderer
        final subpixelRendering = false;
        final dilation = textSystem.glyphDilationForColor(color);
        params.set(fontId, glyphId, fontSize, variantX, variantY, scaleFactor, false, subpixelRendering, dilation);

        final rasterBounds = textSystem.rasterBounds(params);
        if (rasterBounds.isZero())
            return false;

        var tile = atlas.getGlyph(params);
        if (tile == null) {
            final key = params.clone();
            tile = atlas.getOrInsertWith(AtlasKey.Glyph(key), () -> {
                final bytes = textSystem.rasterizeGlyph(key);
                final bounds = textSystem.rasterBounds(key);
                return new AtlasTileSource(Std.int(bounds.size.width), Std.int(bounds.size.height), bytes);
            });
            if (tile == null)
                throw 'Callback above only errors or returns Some';
        }

        final sprite = scene.nextMonochromeSprite();
        sprite.setBounds(integerX + rasterBounds.origin.x, integerY + rasterBounds.origin.y, tile.bounds.size.width, tile.bounds.size.height);
        sprite.setContentMask(maskX, maskY, maskW, maskH);
        sprite.setColor(color.h, color.s, color.l, color.a * gpui.util.MathUtil.clamp(elementOpacity, 0.0, 1.0));
        sprite.setTile(tile.textureId.index, tile.bounds.origin.x, tile.bounds.origin.y, tile.bounds.size.width, tile.bounds.size.height);
        scene.commitMonochromeSprite(sprite);
        return true;
    }

    /**
     * Paints an emoji glyph. The y component of the origin is the baseline of the glyph.
     */
    public inline function paintEmoji(origin:Point, fontId:FontId, glyphId:GlyphId, fontSize:Pixels):Void {
        paintEmojiAt(origin.x, origin.y, fontId, glyphId, fontSize);
    }

    /** `paintEmoji()` with the origin given as two floats */
    public function paintEmojiAt(x:Float, y:Float, fontId:FontId, glyphId:GlyphId, fontSize:Pixels):Void {
        snapContentMask();
        emitEmoji(scene, atlas, textSystem, params, scaleFactor, elementOpacity, maskX, maskY, maskW, maskH, x, y, fontId, glyphId, fontSize);
    }

    /**
     * Port of `Window::paint_emoji`: commits a `PolychromeSprite` (RGBA tile).
     */
    public static function emitEmoji(scene:Scene, atlas:PlatformAtlas, textSystem:TextSystem, params:RenderGlyphParams, scaleFactor:Float, elementOpacity:Float, maskX:Float, maskY:Float, maskW:Float, maskH:Float, originX:Float, originY:Float, fontId:FontId, glyphId:GlyphId, fontSize:Pixels):Bool {
        final integerX = roundHalfTowardZero(originX * scaleFactor);
        final integerY = roundHalfTowardZero(originY * scaleFactor);
        params.set(fontId, glyphId, fontSize, 0, 0, scaleFactor, true, false, 0);

        final rasterBounds = textSystem.rasterBounds(params);
        if (rasterBounds.isZero())
            return false;

        var tile = atlas.getGlyph(params);
        if (tile == null) {
            final key = params.clone();
            tile = atlas.getOrInsertWith(AtlasKey.Glyph(key), () -> {
                final bytes = textSystem.rasterizeGlyph(key);
                final bounds = textSystem.rasterBounds(key);
                final source = new AtlasTileSource(Std.int(bounds.size.width), Std.int(bounds.size.height), bytes);
                // Color glyphs are straight alpha BGRA, like GPUI's
                source.straightAlpha = true;
                return source;
            });
            if (tile == null)
                throw 'Callback above only errors or returns Some';
        }

        final sprite = scene.nextPolychromeSprite();
        sprite.setBounds(integerX + rasterBounds.origin.x, integerY + rasterBounds.origin.y, tile.bounds.size.width, tile.bounds.size.height);
        sprite.setContentMask(maskX, maskY, maskW, maskH);
        sprite.setTile(tile.textureId.index, tile.bounds.origin.x, tile.bounds.origin.y, tile.bounds.size.width, tile.bounds.size.height);
        sprite.grayscale = false;
        sprite.opacity = elementOpacity;
        scene.commitPolychromeSprite(sprite);
        return true;
    }

/// Decorations

    /**
     * Paints an underline (`Window::paint_underline`).
     */
    public inline function paintUnderline(origin:Point, width:Pixels, style:UnderlineStyle):Void {
        paintUnderlineAt(origin.x, origin.y, width, style);
    }

    /** `paintUnderline()` with the origin given as two floats */
    public function paintUnderlineAt(x:Float, y:Float, width:Float, style:UnderlineStyle):Void {
        snapContentMask();
        final thickness = roundStrokeToDevicePixel(style.thickness, scaleFactor);
        final height = style.wavy ? thickness * 3.0 : thickness;
        final underline = scene.nextUnderline();
        underline.setBounds(roundToDevicePixel(x, scaleFactor), roundToDevicePixel(y, scaleFactor), roundStrokeToDevicePixel(width, scaleFactor), height);
        underline.setContentMask(maskX, maskY, maskW, maskH);
        final color = style.color;
        if (color != null) {
            underline.setColor(color.h, color.s, color.l, color.a * gpui.util.MathUtil.clamp(elementOpacity, 0.0, 1.0));
        }
        underline.thickness = thickness;
        underline.wavy = style.wavy;
        scene.commitUnderline(underline);
    }

    /**
     * Paints a strikethrough (`Window::paint_strikethrough`).
     */
    public inline function paintStrikethrough(origin:Point, width:Pixels, style:StrikethroughStyle):Void {
        paintStrikethroughAt(origin.x, origin.y, width, style);
    }

    /** `paintStrikethrough()` with the origin given as two floats */
    public function paintStrikethroughAt(x:Float, y:Float, width:Float, style:StrikethroughStyle):Void {
        snapContentMask();
        final thickness = roundStrokeToDevicePixel(style.thickness, scaleFactor);
        final underline = scene.nextUnderline();
        underline.setBounds(roundToDevicePixel(x, scaleFactor), roundToDevicePixel(y, scaleFactor), roundStrokeToDevicePixel(width, scaleFactor), thickness);
        underline.setContentMask(maskX, maskY, maskW, maskH);
        final color = style.color;
        if (color != null) {
            underline.setColor(color.h, color.s, color.l, color.a * gpui.util.MathUtil.clamp(elementOpacity, 0.0, 1.0));
        }
        underline.thickness = thickness;
        underline.wavy = false;
        scene.commitUnderline(underline);
    }

    /**
     * Fills a rectangle with a solid color (run backgrounds, Rust
     * `window.paint_quad(fill(bounds, color))`).
     */
    public function paintFill(x:Float, y:Float, width:Float, height:Float, color:Hsla):Void {
        if (quadPainter != null) {
            final quad = new PaintQuad(new Bounds(new Point(x, y), new Size(width, height)));
            quad.setSolidBackground(color.h, color.s, color.l, color.a);
            quadPainter(quad);
            return;
        }
        final alpha = color.a * gpui.util.MathUtil.clamp(elementOpacity, 0.0, 1.0);
        if (alpha == 0.0)
            return;
        snapContentMask();
        final left = roundToDevicePixel(x, scaleFactor);
        final top = roundToDevicePixel(y, scaleFactor);
        final right = Math.max(roundToDevicePixel(x + width, scaleFactor), left);
        final bottom = Math.max(roundToDevicePixel(y + height, scaleFactor), top);
        final quad = scene.nextQuad();
        quad.setBounds(left, top, right - left, bottom - top);
        quad.setContentMask(maskX, maskY, maskW, maskH);
        quad.backgroundTag = 0;
        quad.backgroundSolidH = color.h;
        quad.backgroundSolidS = color.s;
        quad.backgroundSolidL = color.l;
        quad.backgroundSolidA = alpha;
        scene.commitQuad(quad);
    }

}
