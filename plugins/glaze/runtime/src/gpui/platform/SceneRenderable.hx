// Ported from gpui-pre-wgpu 0.3.10: src/wgpu_renderer.rs (draw loop, gamma parameters)
// and gpui-pre 0.3.10: src/platform.rs (get_gamma_correction_ratios)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
// Contrast and gamma correction adapted by GPUI from Windows Terminal,
// Copyright (c) Microsoft Corporation, licensed under MIT.
package gpui.platform;

import backend.BlendMode;
import ceramic.Renderable;
import ceramic.Shader;
import ceramic.Texture;
import gpui.scene.MonochromeSprite;
import gpui.scene.PolychromeSprite;
import gpui.scene.PrimitiveBatch;
import gpui.scene.Quad;
import gpui.scene.Scene;
import gpui.scene.Shadow;
import gpui.scene.Underline;

/**
 * Ceramic renderable that draws a GPUI `Scene`.
 *
 * Primitives are emitted batch by batch through Ceramic's `backend.Draw`,
 * with the `shaders.Gpui*` shaders. Each primitive is a quad of 4 vertices
 * carrying its data as custom float attributes (Ceramic has no instancing).
 *
 * The scene is in scaled pixels: positions are divided by `sceneScale` to get
 * this visual's local coordinates, then transformed by its world matrix,
 * so the renderable can be moved, scaled or rendered into a render texture
 * like any other visual.
 */
class SceneRenderable extends Renderable {

    /**
     * Scene to draw. Not owned: the window replaces it every frame.
     */
    public var scene:Scene = null;

    /**
     * Number of scene units (scaled pixels) per local unit.
     * Usually the screen density.
     */
    public var sceneScale:Float = 1;

    /**
     * Atlas textures, indexed by the `textureIndex` of sprite primitives.
     * Set `usedTexturesDirty = true` after changing this array.
     */
    public var atlasTextures:Array<Texture> = [];

    /**
     * Font gamma (see GPUI's `ZED_FONTS_GAMMA`), clamped to 1.0..2.2.
     *
     * Defaults to 1.0 (no correction), like GPUI's Metal renderer (macOS),
     * whose monochrome sprite shader multiplies the color alpha by the
     * coverage as is. GPUI's WGSL renderer (Linux, Windows, web) uses 1.8 and
     * a contrast of 1.0: set both to get its look.
     */
    public var fontsGamma(default, set):Float = 1.0;
    function set_fontsGamma(fontsGamma:Float):Float {
        this.fontsGamma = Math.max(1.0, Math.min(2.2, fontsGamma));
        gammaRatiosDirty = true;
        return this.fontsGamma;
    }

    /**
     * Contrast enhancement of grayscale text (see GPUI's `ZED_FONTS_GRAYSCALE_ENHANCED_CONTRAST`).
     * Defaults to 0.0 like GPUI's Metal renderer (see `fontsGamma`).
     */
    public var grayscaleEnhancedContrast:Float = 0.0;

    var gammaRatios:Array<Float> = [0, 0, 0, 0];

    var gammaRatiosDirty:Bool = true;

    var quadShader:Shader = null;
    var shadowShader:Shader = null;
    var underlineShader:Shader = null;
    var monoSpriteShader:Shader = null;
    var polySpriteShader:Shader = null;
    var pathSpriteShader:Shader = null;

    /** Local to world matrix, refreshed at the beginning of `render()` */
    var wa:Float = 1;
    var wb:Float = 0;
    var wc:Float = 0;
    var wd:Float = 1;
    var wtx:Float = 0;
    var wty:Float = 0;

    /** Last `hslaToRgba()` result */
    var r:Float = 0;
    var g:Float = 0;
    var b:Float = 0;
    var a:Float = 0;

    public function new() {

        super();

    }

    override function computeUsedTextures():Void {

        final arr = usedTextures.original;
        arr.resize(0);
        for (texture in atlasTextures) {
            if (texture != null) {
                arr.push(texture);
            }
        }

    }

    /**
     * Loads the GPUI shaders. They must have been added to the assets first,
     * which `GpuiPlugin` does with the default assets.
     */
    function ensureShaders():Bool {

        if (quadShader == null) {
            final assets = ceramic.App.app.assets;
            quadShader = assets.shader(shaders.GpuiQuad);
            shadowShader = assets.shader(shaders.GpuiShadow);
            underlineShader = assets.shader(shaders.GpuiUnderline);
            monoSpriteShader = assets.shader(shaders.GpuiMonoSprite);
            polySpriteShader = assets.shader(shaders.GpuiPolySprite);
            pathSpriteShader = assets.shader(shaders.GpuiPathSprite);
        }

        return quadShader != null
            && shadowShader != null
            && underlineShader != null
            && monoSpriteShader != null
            && polySpriteShader != null
            && pathSpriteShader != null;

    }

    override function render(draw:backend.Draw):Void {

        if (scene == null || scene.len() == 0) return;
        if (!ensureShaders()) return;

        if (gammaRatiosDirty) {
            gammaRatiosDirty = false;
            computeGammaCorrectionRatios(fontsGamma, gammaRatios);
        }

        // Local (scaled pixels) to world transform
        final invScale = 1.0 / sceneScale;
        wa = matA * invScale;
        wb = matB * invScale;
        wc = matC * invScale;
        wd = matD * invScale;
        wtx = matTX;
        wty = matTY;

        draw.setBlendFuncSeparate(
            BlendMode.ONE, BlendMode.ONE_MINUS_SRC_ALPHA,
            BlendMode.ONE, BlendMode.ONE_MINUS_SRC_ALPHA
        );

        scene.resetBatches();
        var batch = scene.nextBatch();
        while (batch != null) {
            switch batch.kind {
                case Shadow:
                    drawShadows(draw, batch);
                case Quad:
                    drawQuads(draw, batch);
                case Path:
                    drawPaths(draw, batch);
                case Underline:
                    drawUnderlines(draw, batch);
                case MonochromeSprite:
                    drawMonochromeSprites(draw, batch);
                case PolychromeSprite:
                    drawPolychromeSprites(draw, batch);
                case _:
            }
            batch = scene.nextBatch();
        }

        draw.flush();

    }

/// Helpers

    /**
     * Same conversion as `hsla_to_rgba()` in GPUI's shaders (result in `r`, `g`, `b`, `a`).
     */
    function hslaToRgba(h:Float, s:Float, l:Float, alpha:Float):Void {

        h = h * 6.0;
        final c = (1.0 - Math.abs(2.0 * l - 1.0)) * s;
        final x = c * (1.0 - Math.abs((h % 2.0) - 1.0));
        final m = l - c / 2.0;
        r = m;
        g = m;
        b = m;

        if (h >= 0.0 && h < 1.0) {
            r += c;
            g += x;
        }
        else if (h >= 1.0 && h < 2.0) {
            r += x;
            g += c;
        }
        else if (h >= 2.0 && h < 3.0) {
            g += c;
            b += x;
        }
        else if (h >= 3.0 && h < 4.0) {
            g += x;
            b += c;
        }
        else if (h >= 4.0 && h < 5.0) {
            r += x;
            b += c;
        }
        else {
            r += c;
            b += x;
        }

        a = alpha;

    }

    function useShader(draw:backend.Draw, shader:Shader):Void {

        draw.flush();
        draw.useShader(shader.backendItem);

    }

    inline function putPos(draw:backend.Draw, x:Float, y:Float):Void {

        draw.putPos(wtx + wa * x + wc * y, wty + wb * x + wd * y, 0);

    }

    inline function putQuadIndices(draw:backend.Draw, base:Int):Void {

        draw.putIndice(base);
        draw.putIndice(base + 1);
        draw.putIndice(base + 2);
        draw.putIndice(base);
        draw.putIndice(base + 2);
        draw.putIndice(base + 3);

    }

    inline function ensureCapacity(draw:backend.Draw, shader:Shader):Void {

        if (draw.shouldFlush(4, 6, shader.customFloatAttributesSize)) {
            draw.flush();
        }

    }

    static inline function unitX(i:Int):Float {
        return (i == 1 || i == 2) ? 1.0 : 0.0;
    }

    static inline function unitY(i:Int):Float {
        return (i >= 2) ? 1.0 : 0.0;
    }

/// Quads

    function drawQuads(draw:backend.Draw, batch:PrimitiveBatch):Void {

        // Order barrier of the dash code (see `GpuiQuad_Frag.dashOne`)
        quadShader.setFloat('dashOne', 1);
        useShader(draw, quadShader);
        final quads = scene.quads;

        for (q in batch.start...batch.end) {
            final quad = quads[q];
            ensureCapacity(draw, quadShader);
            final base = draw.getNumPos();

            hslaToRgba(quad.backgroundSolidH, quad.backgroundSolidS, quad.backgroundSolidL, quad.backgroundSolidA);
            final solidR = r;
            final solidG = g;
            final solidB = b;
            final solidA = a;
            hslaToRgba(quad.borderColorH, quad.borderColorS, quad.borderColorL, quad.borderColorA);
            final borderR = r;
            final borderG = g;
            final borderB = b;
            final borderA = a;
            hslaToRgba(quad.backgroundColor0H, quad.backgroundColor0S, quad.backgroundColor0L, quad.backgroundColor0A);
            final c0R = r;
            final c0G = g;
            final c0B = b;
            final c0A = a;
            hslaToRgba(quad.backgroundColor1H, quad.backgroundColor1S, quad.backgroundColor1L, quad.backgroundColor1A);
            final c1R = r;
            final c1G = g;
            final c1B = b;
            final c1A = a;

            for (i in 0...4) {
                final ux = unitX(i);
                final uy = unitY(i);
                putPos(draw, quad.boundsX + ux * quad.boundsWidth, quad.boundsY + uy * quad.boundsHeight);

                draw.beginFloatAttributes();
                // vertexBounds
                draw.putFloatAttribute(0, quad.boundsX);
                draw.putFloatAttribute(1, quad.boundsY);
                draw.putFloatAttribute(2, quad.boundsWidth);
                draw.putFloatAttribute(3, quad.boundsHeight);
                // vertexContentMask
                draw.putFloatAttribute(4, quad.contentMaskX);
                draw.putFloatAttribute(5, quad.contentMaskY);
                draw.putFloatAttribute(6, quad.contentMaskWidth);
                draw.putFloatAttribute(7, quad.contentMaskHeight);
                // vertexCornerRadii
                draw.putFloatAttribute(8, quad.cornerRadiusTopLeft);
                draw.putFloatAttribute(9, quad.cornerRadiusTopRight);
                draw.putFloatAttribute(10, quad.cornerRadiusBottomRight);
                draw.putFloatAttribute(11, quad.cornerRadiusBottomLeft);
                // vertexBorderWidths
                draw.putFloatAttribute(12, quad.borderWidthTop);
                draw.putFloatAttribute(13, quad.borderWidthRight);
                draw.putFloatAttribute(14, quad.borderWidthBottom);
                draw.putFloatAttribute(15, quad.borderWidthLeft);
                // vertexBorderColor
                draw.putFloatAttribute(16, borderR);
                draw.putFloatAttribute(17, borderG);
                draw.putFloatAttribute(18, borderB);
                draw.putFloatAttribute(19, borderA);
                // vertexParams
                draw.putFloatAttribute(20, quad.backgroundTag);
                draw.putFloatAttribute(21, quad.backgroundColorSpace);
                draw.putFloatAttribute(22, quad.backgroundGradientAngleOrPatternHeight);
                draw.putFloatAttribute(23, quad.borderStyle);
                // vertexColor0
                draw.putFloatAttribute(24, c0R);
                draw.putFloatAttribute(25, c0G);
                draw.putFloatAttribute(26, c0B);
                draw.putFloatAttribute(27, c0A);
                // vertexColor1
                draw.putFloatAttribute(28, c1R);
                draw.putFloatAttribute(29, c1G);
                draw.putFloatAttribute(30, c1B);
                draw.putFloatAttribute(31, c1A);
                // vertexStops
                draw.putFloatAttribute(32, quad.backgroundColor0Percentage);
                draw.putFloatAttribute(33, quad.backgroundColor1Percentage);
                draw.endFloatAttributes();

                draw.putUVs(ux, uy);
                draw.putColor(solidR, solidG, solidB, solidA);
            }

            putQuadIndices(draw, base);
        }

    }

/// Shadows

    function drawShadows(draw:backend.Draw, batch:PrimitiveBatch):Void {

        useShader(draw, shadowShader);
        final shadows = scene.shadows;

        for (s in batch.start...batch.end) {
            final shadow = shadows[s];
            ensureCapacity(draw, shadowShader);
            final base = draw.getNumPos();

            hslaToRgba(shadow.colorH, shadow.colorS, shadow.colorL, shadow.colorA);

            // Geometry covered by the shadow
            var gx:Float;
            var gy:Float;
            var gw:Float;
            var gh:Float;
            if (shadow.inset) {
                gx = shadow.elementBoundsX;
                gy = shadow.elementBoundsY;
                gw = shadow.elementBoundsWidth;
                gh = shadow.elementBoundsHeight;
            }
            else {
                final margin = 3.0 * shadow.blurRadius;
                gx = shadow.boundsX - margin;
                gy = shadow.boundsY - margin;
                gw = shadow.boundsWidth + 2.0 * margin;
                gh = shadow.boundsHeight + 2.0 * margin;
            }

            for (i in 0...4) {
                final ux = unitX(i);
                final uy = unitY(i);
                putPos(draw, gx + ux * gw, gy + uy * gh);

                draw.beginFloatAttributes();
                // vertexGeometry
                draw.putFloatAttribute(0, gx);
                draw.putFloatAttribute(1, gy);
                draw.putFloatAttribute(2, gw);
                draw.putFloatAttribute(3, gh);
                // vertexContentMask
                draw.putFloatAttribute(4, shadow.contentMaskX);
                draw.putFloatAttribute(5, shadow.contentMaskY);
                draw.putFloatAttribute(6, shadow.contentMaskWidth);
                draw.putFloatAttribute(7, shadow.contentMaskHeight);
                // vertexBounds
                draw.putFloatAttribute(8, shadow.boundsX);
                draw.putFloatAttribute(9, shadow.boundsY);
                draw.putFloatAttribute(10, shadow.boundsWidth);
                draw.putFloatAttribute(11, shadow.boundsHeight);
                // vertexCornerRadii
                draw.putFloatAttribute(12, shadow.cornerRadiusTopLeft);
                draw.putFloatAttribute(13, shadow.cornerRadiusTopRight);
                draw.putFloatAttribute(14, shadow.cornerRadiusBottomRight);
                draw.putFloatAttribute(15, shadow.cornerRadiusBottomLeft);
                // vertexElementBounds
                draw.putFloatAttribute(16, shadow.elementBoundsX);
                draw.putFloatAttribute(17, shadow.elementBoundsY);
                draw.putFloatAttribute(18, shadow.elementBoundsWidth);
                draw.putFloatAttribute(19, shadow.elementBoundsHeight);
                // vertexElementCornerRadii
                draw.putFloatAttribute(20, shadow.elementCornerRadiusTopLeft);
                draw.putFloatAttribute(21, shadow.elementCornerRadiusTopRight);
                draw.putFloatAttribute(22, shadow.elementCornerRadiusBottomRight);
                draw.putFloatAttribute(23, shadow.elementCornerRadiusBottomLeft);
                // vertexParams
                draw.putFloatAttribute(24, shadow.blurRadius);
                draw.putFloatAttribute(25, shadow.inset ? 1.0 : 0.0);
                draw.endFloatAttributes();

                draw.putUVs(ux, uy);
                draw.putColor(r, g, b, a);
            }

            putQuadIndices(draw, base);
        }

    }

/// Underlines

    function drawUnderlines(draw:backend.Draw, batch:PrimitiveBatch):Void {

        useShader(draw, underlineShader);
        final underlines = scene.underlines;

        for (u in batch.start...batch.end) {
            final underline = underlines[u];
            ensureCapacity(draw, underlineShader);
            final base = draw.getNumPos();

            hslaToRgba(underline.colorH, underline.colorS, underline.colorL, underline.colorA);

            for (i in 0...4) {
                final ux = unitX(i);
                final uy = unitY(i);
                putPos(draw, underline.boundsX + ux * underline.boundsWidth, underline.boundsY + uy * underline.boundsHeight);

                draw.beginFloatAttributes();
                // vertexBounds
                draw.putFloatAttribute(0, underline.boundsX);
                draw.putFloatAttribute(1, underline.boundsY);
                draw.putFloatAttribute(2, underline.boundsWidth);
                draw.putFloatAttribute(3, underline.boundsHeight);
                // vertexContentMask
                draw.putFloatAttribute(4, underline.contentMaskX);
                draw.putFloatAttribute(5, underline.contentMaskY);
                draw.putFloatAttribute(6, underline.contentMaskWidth);
                draw.putFloatAttribute(7, underline.contentMaskHeight);
                // vertexParams
                draw.putFloatAttribute(8, underline.thickness);
                draw.putFloatAttribute(9, underline.wavy ? 1.0 : 0.0);
                draw.endFloatAttributes();

                draw.putUVs(ux, uy);
                draw.putColor(r, g, b, a);
            }

            putQuadIndices(draw, base);
        }

    }

/// Sprites

    function bindAtlasTexture(draw:backend.Draw, textureIndex:Int):Null<Texture> {

        final texture = textureIndex >= 0 && textureIndex < atlasTextures.length ? atlasTextures[textureIndex] : null;
        if (texture == null) return null;

        draw.flush();
        draw.setActiveTexture(0);
        draw.bindTexture(texture.backendItem);

        return texture;

    }

    function drawMonochromeSprites(draw:backend.Draw, batch:PrimitiveBatch):Void {

        monoSpriteShader.setVec4('gammaRatios', gammaRatios[0], gammaRatios[1], gammaRatios[2], gammaRatios[3]);
        monoSpriteShader.setFloat('grayscaleEnhancedContrast', grayscaleEnhancedContrast);
        useShader(draw, monoSpriteShader);

        final texture = bindAtlasTexture(draw, batch.textureIndex);
        if (texture == null) return;

        final texWidth:Float = texture.nativeWidthActual;
        final texHeight:Float = texture.nativeHeightActual;
        final sprites = scene.monochromeSprites;

        for (si in batch.start...batch.end) {
            final sprite:MonochromeSprite = sprites[si];
            ensureCapacity(draw, monoSpriteShader);
            final base = draw.getNumPos();

            hslaToRgba(sprite.colorH, sprite.colorS, sprite.colorL, sprite.colorA);

            for (i in 0...4) {
                final ux = unitX(i);
                final uy = unitY(i);

                // Scene position, after the sprite transformation (row major, like GPUI's `apply()`)
                final px = sprite.boundsX + ux * sprite.boundsWidth;
                final py = sprite.boundsY + uy * sprite.boundsHeight;
                final sx = sprite.transformM00 * px + sprite.transformM01 * py + sprite.transformTx;
                final sy = sprite.transformM10 * px + sprite.transformM11 * py + sprite.transformTy;

                putPos(draw, sx, sy);

                draw.beginFloatAttributes();
                // vertexScenePosition
                draw.putFloatAttribute(0, sx);
                draw.putFloatAttribute(1, sy);
                // vertexContentMask
                draw.putFloatAttribute(2, sprite.contentMaskX);
                draw.putFloatAttribute(3, sprite.contentMaskY);
                draw.putFloatAttribute(4, sprite.contentMaskWidth);
                draw.putFloatAttribute(5, sprite.contentMaskHeight);
                draw.endFloatAttributes();

                draw.putUVs(
                    (sprite.tileX + ux * sprite.tileWidth) / texWidth,
                    (sprite.tileY + uy * sprite.tileHeight) / texHeight
                );
                draw.putColor(r, g, b, a);
            }

            putQuadIndices(draw, base);
        }

    }

    /**
     * Paths are 4x MSAA coverage tiles in the atlas (see `PathRasterizer`),
     * drawn with `shaders.GpuiPathSprite`, which fills them with their
     * background (solid, linear gradient or pattern) evaluated at each pixel
     * center like GPUI's `path_rasterization_fragment`, and quantizes the
     * color like GPUI's Metal path pipeline (8-bit samples, resolved).
     */
    function drawPaths(draw:backend.Draw, batch:PrimitiveBatch):Void {

        // RGBA (polychrome) pages hold the tiles of paths with Loop-Blinn
        // curves, monochrome pages coverage masks (see `PathRasterizer`)
        final batchTexture = batch.textureIndex >= 0 && batch.textureIndex < atlasTextures.length ? atlasTextures[batch.textureIndex] : null;
        final curves = batchTexture != null && CeramicAtlas.isStraightAlpha(batchTexture);
        pathSpriteShader.setFloat('pathCoverage', curves ? 2 : 1);
        useShader(draw, pathSpriteShader);

        final texture = bindAtlasTexture(draw, batch.textureIndex);
        if (texture == null) return;

        final texWidth:Float = texture.nativeWidthActual;
        final texHeight:Float = texture.nativeHeightActual;
        final paths = scene.paths;

        for (si in batch.start...batch.end) {
            final path = paths[si];
            ensureCapacity(draw, pathSpriteShader);
            final base = draw.getNumPos();

            // Background, prepared like `Window.paintQuad()` prepares quads
            final background = path.background;
            var tag:Float = 0;
            var colorSpace:Float = 0;
            var angleOrHeight:Float = 0;
            var c0R:Float = 0;
            var c0G:Float = 0;
            var c0B:Float = 0;
            var c0A:Float = 0;
            var c1R:Float = 0;
            var c1G:Float = 0;
            var c1B:Float = 0;
            var c1A:Float = 0;
            var stop0:Float = 0;
            var stop1:Float = 0;
            if (background != null) {
                tag = cast(background.tag, Int);
                colorSpace = cast(background.colorSpace, Int);
                angleOrHeight = background.gradientAngleOrPatternHeight;
                final c0 = background.colors0;
                hslaToRgba(c0.color.h, c0.color.s, c0.color.l, c0.color.a);
                c0R = r;
                c0G = g;
                c0B = b;
                c0A = a;
                stop0 = c0.percentage;
                final c1 = background.colors1;
                hslaToRgba(c1.color.h, c1.color.s, c1.color.l, c1.color.a);
                c1R = r;
                c1G = g;
                c1B = b;
                c1A = a;
                stop1 = c1.percentage;
            }
            hslaToRgba(path.colorH, path.colorS, path.colorL, path.colorA);

            // Gradient and pattern bounds: GPUI's Metal renderer gives the
            // path rasterization vertices `path.bounds.intersect(&path.content_mask.bounds)`
            // (scaled pixels, f32)
            final boundsLeft = f32(path.boundsX);
            final boundsTop = f32(path.boundsY);
            final boundsRight = f32(boundsLeft + f32(path.boundsWidth));
            final boundsBottom = f32(boundsTop + f32(path.boundsHeight));
            final maskLeft = f32(path.contentMaskX);
            final maskTop = f32(path.contentMaskY);
            final maskRight = f32(maskLeft + f32(path.contentMaskWidth));
            final maskBottom = f32(maskTop + f32(path.contentMaskHeight));
            final clipLeft = Math.max(boundsLeft, maskLeft);
            final clipTop = Math.max(boundsTop, maskTop);
            final clipWidth = f32(Math.max(Math.min(boundsRight, maskRight), clipLeft) - clipLeft);
            final clipHeight = f32(Math.max(Math.min(boundsBottom, maskBottom), clipTop) - clipTop);

            for (i in 0...4) {
                final ux = unitX(i);
                final uy = unitY(i);
                final sx = path.spriteX + ux * path.spriteWidth;
                final sy = path.spriteY + uy * path.spriteHeight;

                putPos(draw, sx, sy);

                draw.beginFloatAttributes();
                // vertexScenePosition
                draw.putFloatAttribute(0, sx);
                draw.putFloatAttribute(1, sy);
                // vertexContentMask
                draw.putFloatAttribute(2, path.contentMaskX);
                draw.putFloatAttribute(3, path.contentMaskY);
                draw.putFloatAttribute(4, path.contentMaskWidth);
                draw.putFloatAttribute(5, path.contentMaskHeight);
                // vertexBounds
                draw.putFloatAttribute(6, clipLeft);
                draw.putFloatAttribute(7, clipTop);
                draw.putFloatAttribute(8, clipWidth);
                draw.putFloatAttribute(9, clipHeight);
                // vertexParams
                draw.putFloatAttribute(10, tag);
                draw.putFloatAttribute(11, colorSpace);
                draw.putFloatAttribute(12, angleOrHeight);
                // vertexColor0
                draw.putFloatAttribute(13, c0R);
                draw.putFloatAttribute(14, c0G);
                draw.putFloatAttribute(15, c0B);
                draw.putFloatAttribute(16, c0A);
                // vertexColor1
                draw.putFloatAttribute(17, c1R);
                draw.putFloatAttribute(18, c1G);
                draw.putFloatAttribute(19, c1B);
                draw.putFloatAttribute(20, c1A);
                // vertexStops
                draw.putFloatAttribute(21, stop0);
                draw.putFloatAttribute(22, stop1);
                draw.endFloatAttributes();

                draw.putUVs(
                    (path.tileX + ux * path.tileWidth) / texWidth,
                    (path.tileY + uy * path.tileHeight) / texHeight
                );
                draw.putColor(r, g, b, a);
            }

            putQuadIndices(draw, base);
        }

    }

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

    function drawPolychromeSprites(draw:backend.Draw, batch:PrimitiveBatch):Void {

        final textureIndex = batch.textureIndex;
        final atlasTexture = textureIndex >= 0 && textureIndex < atlasTextures.length ? atlasTextures[textureIndex] : null;
        if (atlasTexture == null) return;

        // Polychrome atlas pages hold straight alpha texels, sampled and
        // blended like GPUI's Metal pipeline (SourceAlpha, OneMinusSourceAlpha
        // for color; One, OneMinusSourceAlpha for alpha). Other textures
        // (texture backed images) are premultiplied.
        final straightAlpha = CeramicAtlas.isStraightAlpha(atlasTexture);
        polySpriteShader.setFloat('straightAlpha', straightAlpha ? 1.0 : 0.0);
        useShader(draw, polySpriteShader);
        if (straightAlpha) {
            draw.setBlendFuncSeparate(
                BlendMode.SRC_ALPHA, BlendMode.ONE_MINUS_SRC_ALPHA,
                BlendMode.ONE, BlendMode.ONE_MINUS_SRC_ALPHA
            );
        }

        final texture = bindAtlasTexture(draw, textureIndex);

        final texWidth:Float = texture.nativeWidthActual;
        final texHeight:Float = texture.nativeHeightActual;
        final sprites = scene.polychromeSprites;

        for (si in batch.start...batch.end) {
            final sprite:PolychromeSprite = sprites[si];
            ensureCapacity(draw, polySpriteShader);
            final base = draw.getNumPos();

            for (i in 0...4) {
                final ux = unitX(i);
                final uy = unitY(i);
                putPos(draw, sprite.boundsX + ux * sprite.boundsWidth, sprite.boundsY + uy * sprite.boundsHeight);

                draw.beginFloatAttributes();
                // vertexUnit
                draw.putFloatAttribute(0, ux);
                draw.putFloatAttribute(1, uy);
                // vertexBounds
                draw.putFloatAttribute(2, sprite.boundsX);
                draw.putFloatAttribute(3, sprite.boundsY);
                draw.putFloatAttribute(4, sprite.boundsWidth);
                draw.putFloatAttribute(5, sprite.boundsHeight);
                // vertexContentMask
                draw.putFloatAttribute(6, sprite.contentMaskX);
                draw.putFloatAttribute(7, sprite.contentMaskY);
                draw.putFloatAttribute(8, sprite.contentMaskWidth);
                draw.putFloatAttribute(9, sprite.contentMaskHeight);
                // vertexCornerRadii
                draw.putFloatAttribute(10, sprite.cornerRadiusTopLeft);
                draw.putFloatAttribute(11, sprite.cornerRadiusTopRight);
                draw.putFloatAttribute(12, sprite.cornerRadiusBottomRight);
                draw.putFloatAttribute(13, sprite.cornerRadiusBottomLeft);
                // vertexParams
                draw.putFloatAttribute(14, sprite.grayscale ? 1.0 : 0.0);
                draw.putFloatAttribute(15, sprite.opacity);
                draw.endFloatAttributes();

                draw.putUVs(
                    (sprite.tileX + ux * sprite.tileWidth) / texWidth,
                    (sprite.tileY + uy * sprite.tileHeight) / texHeight
                );
                draw.putColor(1, 1, 1, 1);
            }

            putQuadIndices(draw, base);
        }

        if (straightAlpha) {
            // Back to the premultiplied blending of every other primitive
            draw.flush();
            draw.setBlendFuncSeparate(
                BlendMode.ONE, BlendMode.ONE_MINUS_SRC_ALPHA,
                BlendMode.ONE, BlendMode.ONE_MINUS_SRC_ALPHA
            );
        }

    }

/// Gamma

    static final GAMMA_INCORRECT_TARGET_RATIOS:Array<Array<Float>> = [
        [0.0000 / 4.0, 0.0000 / 4.0, 0.0000 / 4.0, 0.0000 / 4.0], // gamma = 1.0
        [0.0166 / 4.0, -0.0807 / 4.0, 0.2227 / 4.0, -0.0751 / 4.0], // gamma = 1.1
        [0.0350 / 4.0, -0.1760 / 4.0, 0.4325 / 4.0, -0.1370 / 4.0], // gamma = 1.2
        [0.0543 / 4.0, -0.2821 / 4.0, 0.6302 / 4.0, -0.1876 / 4.0], // gamma = 1.3
        [0.0739 / 4.0, -0.3963 / 4.0, 0.8167 / 4.0, -0.2287 / 4.0], // gamma = 1.4
        [0.0933 / 4.0, -0.5161 / 4.0, 0.9926 / 4.0, -0.2616 / 4.0], // gamma = 1.5
        [0.1121 / 4.0, -0.6395 / 4.0, 1.1588 / 4.0, -0.2877 / 4.0], // gamma = 1.6
        [0.1300 / 4.0, -0.7649 / 4.0, 1.3159 / 4.0, -0.3080 / 4.0], // gamma = 1.7
        [0.1469 / 4.0, -0.8911 / 4.0, 1.4644 / 4.0, -0.3234 / 4.0], // gamma = 1.8
        [0.1627 / 4.0, -1.0170 / 4.0, 1.6051 / 4.0, -0.3347 / 4.0], // gamma = 1.9
        [0.1773 / 4.0, -1.1420 / 4.0, 1.7385 / 4.0, -0.3426 / 4.0], // gamma = 2.0
        [0.1908 / 4.0, -1.2652 / 4.0, 1.8650 / 4.0, -0.3476 / 4.0], // gamma = 2.1
        [0.2031 / 4.0, -1.3864 / 4.0, 1.9851 / 4.0, -0.3501 / 4.0] // gamma = 2.2
    ];

    /**
     * Gamma correction ratios for text rendering, adapted by GPUI from
     * Windows Terminal (Copyright (c) Microsoft Corporation, MIT license).
     */
    public static function computeGammaCorrectionRatios(gamma:Float, result:Array<Float>):Void {

        final norm13 = (0x10000 / (255.0 * 255.0)) * 4.0;
        final norm24 = (0x100 / 255.0) * 4.0;

        var index = Math.round(gamma * 10.0);
        if (index < 10) index = 10;
        if (index > 22) index = 22;
        final ratios = GAMMA_INCORRECT_TARGET_RATIOS[index - 10];

        result[0] = ratios[0] * norm13;
        result[1] = ratios[1] * norm24;
        result[2] = ratios[2] * norm13;
        result[3] = ratios[3] * norm24;

    }

}
