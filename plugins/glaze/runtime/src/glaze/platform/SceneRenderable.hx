// Ported from gpui-pre-wgpu 0.3.10: src/wgpu_renderer.rs (draw loop, gamma parameters)
// and gpui-pre 0.3.10: src/platform.rs (get_gamma_correction_ratios)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
// Contrast and gamma correction adapted by GPUI from Windows Terminal,
// Copyright (c) Microsoft Corporation, licensed under MIT.
package glaze.platform;

import backend.BlendMode;
import ceramic.Renderable;
import ceramic.Shader;
import ceramic.Texture;
import glaze.scene.MonochromeSprite;
import glaze.scene.PolychromeSprite;
import glaze.scene.PrimitiveBatch;
import glaze.scene.Quad;
import glaze.scene.Scene;
import glaze.scene.Shadow;
import glaze.scene.Underline;

/**
 * Ceramic renderable that draws a GPUI `Scene`.
 *
 * Primitives are emitted batch by batch through Ceramic's `backend.Draw`,
 * with the `shaders.Glaze*` shaders. Each primitive is a quad of 4 vertices
 * carrying its data as custom float attributes (Ceramic has no instancing).
 *
 * The scene is in scaled pixels: positions are divided by `sceneScale` to get
 * this visual's local coordinates, then transformed by its world matrix,
 * so the renderable can be moved, scaled or rendered into a render texture
 * like any other visual.
 *
 * With `renderToTexture`, the scene is drawn into a `RenderTexture` of the
 * renderable's size at `sceneScale` density, only when it changed (a new
 * scene, a new scale, size or gamma), and a child `Quad` shows that texture
 * without filtering. Ceramic then draws a single quad per frame while the
 * window is idle.
 *
 * The render textures the scene shows (`img()` of a `RenderTexture`,
 * `visual()` elements) can change without a new scene: the window checks
 * them once per frame (`checkExternalTextures()`) and the texture is drawn
 * again when one of them is drawn by Ceramic.
 *
 * With `partialRendering` too, only the region that changed since the
 * scene the texture holds is cleared and drawn again (see `SceneDamage`),
 * one pass with a scissor per damage rectangle, which gives the same bytes
 * as a full redraw.
 */
@:allow(glaze.platform.SceneTargetDrawer)
class SceneRenderable extends Renderable {

    /**
     * Whether new renderables draw into a render texture (see
     * `renderToTexture`). On by default: the 425 golden scenes give the same
     * bytes in both modes. The `glaze_no_render_to_texture` define turns it off.
     */
    public static var defaultRenderToTexture:Bool = #if glaze_no_render_to_texture false #else true #end;

    /**
     * Whether new renderables draw only the changed region of their render
     * texture (see `partialRendering`). On by default: every frame of the
     * golden scenes (scripts replayed frame by frame) gives the same bytes
     * as a full redraw. The `glaze_no_partial_rendering` define turns it off.
     */
    public static var defaultPartialRendering:Bool = #if glaze_no_partial_rendering false #else true #end;

    /**
     * Test aid: with `partialRendering`, also draw every frame entirely into
     * a second render texture and compare both textures byte for byte after
     * Ceramic's draw (see `partialVerifiedFrames` and the counters next to
     * it). Must be set before the renderables create their texture.
     */
    public static var verifyPartialRendering:Bool = false;

    /**
     * Test aid: when not null, a copy of each new scene given to a renderable
     * is appended to it, so that a sequence of scenes drawn without Ceramic
     * frames in between (scripted golden scenes) can be played back frame by
     * frame with `verifyPartialRendering`.
     */
    public static var recordedScenes:Null<Array<Scene>> = null;

    /**
     * Statistics of the texture draws in `partialRendering` mode, for
     * benchmarks: draws, of which partial and full ones, and the sum of the
     * redrawn areas over the sum of the texture areas (reset them freely).
     */
    public static var partialStatsDraws:Int = 0;
    public static var partialStatsPartialDraws:Int = 0;
    public static var partialStatsFullDraws:Int = 0;
    public static var partialStatsArea:Float = 0;
    public static var partialStatsTotalArea:Float = 0;

    /** Damage rectangles (one pass each) of the partial draws */
    public static var partialStatsRects:Int = 0;

    /** Frames compared by `verifyPartialRendering` */
    public static var partialVerifiedFrames:Int = 0;

    /** Of these, frames drawn partially (the others were full redraws or had no change) */
    public static var partialDrawnFrames:Int = 0;

    /** Of these, frames drawn entirely (no previous scene, atlas changes, everything changed) */
    public static var partialFullFrames:Int = 0;

    /** Of these, frames whose textures differed */
    public static var partialMismatchedFrames:Int = 0;

    /** Description of the first mismatch, if any */
    public static var partialFirstMismatch:Null<String> = null;

    /** Sum of the redrawn areas of the compared frames, over the sum of the texture areas */
    public static var partialRedrawnArea:Float = 0;
    public static var partialTotalArea:Float = 0;

    /**
     * Scene to draw. Not owned: the window replaces it every frame.
     */
    public var scene(default, set):Scene = null;
    function set_scene(scene:Scene):Scene {
        if (recordedScenes != null && scene != null && scene != this.scene) {
            // Copy: the window reuses its two scenes
            final copy = new Scene();
            copy.replay(0, scene.paintIndex(), scene);
            copy.finish();
            recordedScenes.push(copy);
        }
        this.scene = scene;
        if (atlas != null && scene != null) {
            atlas.markSceneUsed(scene);
        }
        // Assigned once per drawn frame: the atlas may have new pages too
        if (targetDrawer != null) {
            targetDrawer.usedTexturesDirty = true;
        }
        externalTargetsDirty = true;
        markRenderDirty();
        return scene;
    }

    /**
     * The atlas owned by the window of this renderable, if any: told which
     * path pages each new scene uses (see `CeramicAtlas.markSceneUsed()`).
     * Leave null for an atlas shared by several windows.
     */
    public var atlas:Null<CeramicAtlas> = null;

    /**
     * Number of scene units (scaled pixels) per local unit.
     * Usually the screen density.
     */
    public var sceneScale(default, set):Float = 1;
    function set_sceneScale(sceneScale:Float):Float {
        if (this.sceneScale != sceneScale) {
            this.sceneScale = sceneScale;
            targetLayoutDirty();
        }
        return sceneScale;
    }

    /**
     * Atlas textures, indexed by the `textureIndex` of sprite primitives.
     * Set `usedTexturesDirty = true` after changing this array.
     */
    public var atlasTextures(default, set):Array<Texture> = [];
    function set_atlasTextures(atlasTextures:Array<Texture>):Array<Texture> {
        this.atlasTextures = atlasTextures;
        if (targetDrawer != null) {
            targetDrawer.usedTexturesDirty = true;
        }
        externalTargetsDirty = true;
        markRenderDirty();
        return atlasTextures;
    }

    /**
     * Draw the scene into a render texture shown by a child quad, and only
     * when it changed, instead of drawing it again at every Ceramic frame.
     * Defaults to `defaultRenderToTexture`.
     */
    public var renderToTexture(default, set):Bool = false;
    function set_renderToTexture(renderToTexture:Bool):Bool {
        if (this.renderToTexture != renderToTexture) {
            this.renderToTexture = renderToTexture;
            if (renderToTexture) {
                targetLayoutDirty();
            }
            else {
                destroyTarget();
            }
        }
        return renderToTexture;
    }

    /**
     * In `renderToTexture` mode, clear and draw again only the region of the
     * texture that changed since its last draw, instead of all of it.
     * Defaults to `defaultPartialRendering`. Needs the clay backend (other
     * backends always draw the whole texture).
     */
    public var partialRendering(default, set):Bool = false;
    function set_partialRendering(partialRendering:Bool):Bool {
        if (this.partialRendering != partialRendering) {
            this.partialRendering = partialRendering;
            damage.invalidate();
            targetLayoutDirty();
            markRenderDirty();
        }
        return partialRendering;
    }

    /** Changed region between two scenes (`partialRendering`) */
    final damage:SceneDamage = new SceneDamage();

    /**
     * The render textures (not owned) the scene's polychrome sprites show
     * (`img()` of a `RenderTexture`, `visual()` elements), whose pixels can
     * change without a new scene (see `checkExternalTextures()`).
     */
    var externalTargets:Array<ceramic.RenderTexture> = [];

    /** `renderVersion` of each of `externalTargets` when the texture was last drawn */
    var externalVersions:Array<Int> = [];

    /** The arrays `updateExternalTargets()` fills next (swapped with the above) */
    var scratchTargets:Array<ceramic.RenderTexture> = [];
    var scratchVersions:Array<Int> = [];

    /** Whether `externalTargets` must be listed again (new scene or atlas textures) */
    var externalTargetsDirty:Bool = true;

    /**
     * Draws done because an external render texture changed (see
     * `checkExternalTextures()`), for tests and benchmarks (reset freely).
     */
    public static var externalTextureRedraws:Int = 0;

    /**
     * Partial rendering of the frame being drawn: only the primitives whose
     * rectangle (see `SceneDamage`) intersects `regionX0, regionY0` to
     * `regionX1, regionY1` are drawn.
     */
    var regionClip:Bool = false;
    var regionX0:Int = 0;
    var regionY0:Int = 0;
    var regionX1:Int = 0;
    var regionY1:Int = 0;

    /** Index (in draw order) of the first primitive of the batch being drawn */
    var batchBase:Int = 0;

    /** Full redraws of `verifyPartialRendering` */
    var verifyTexture:Null<ceramic.RenderTexture> = null;
    var verifyDrawer:Null<SceneTargetDrawer> = null;

    /** Set by the partial drawer when it draws (`verifyPartialRendering`) */
    var verifyPending:Bool = false;
    var verifyPendingArea:Float = 0;
    var verifyPendingPartial:Bool = false;
    var verifyPendingFull:Bool = false;
    var verifyPixels:Null<ceramic.UInt8Array> = null;
    var verifyReferencePixels:Null<ceramic.UInt8Array> = null;

    /** Render texture of `renderToTexture` (null until the first update) */
    public var targetTexture(default, null):Null<ceramic.RenderTexture> = null;

    /** Draws the scene into `targetTexture` */
    var targetDrawer:Null<SceneTargetDrawer> = null;

    /** Shows `targetTexture` */
    var targetQuad:Null<ceramic.Quad> = null;

    /**
     * Whether `SceneTargetDrawer` draws the scene mirrored into the render
     * texture (and `targetQuad` mirrors it back), so that the GPU
     * rasterizes and interpolates the primitives exactly like on the screen.
     * On clay, Ceramic flips what it draws into a render texture: the mirror
     * cancels that flip. Ceramic's Unity backend draws render textures the
     * way it draws the screen (Unity orients render textures itself), so the
     * mirror would do the opposite there: the Unity captures in this mode
     * differed from the web on dithered gradients and antialiased edges
     * (interpolated positions a few ulps apart), and gave the same bytes as
     * the screen mode once the mirror was left out.
     */
    static final MIRROR_TARGET:Bool = #if unity false #else true #end;

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
        damage.invalidate();
        markRenderDirty();
        return this.fontsGamma;
    }

    /**
     * Contrast enhancement of grayscale text (see GPUI's `ZED_FONTS_GRAYSCALE_ENHANCED_CONTRAST`).
     * Defaults to 0.0 like GPUI's Metal renderer (see `fontsGamma`).
     */
    public var grayscaleEnhancedContrast(default, set):Float = 0.0;
    function set_grayscaleEnhancedContrast(grayscaleEnhancedContrast:Float):Float {
        this.grayscaleEnhancedContrast = grayscaleEnhancedContrast;
        damage.invalidate();
        markRenderDirty();
        return grayscaleEnhancedContrast;
    }

    var gammaRatios:Array<Float> = [0, 0, 0, 0];

    var gammaRatiosDirty:Bool = true;

    /**
     * The uniforms set by the renderer. A shader keeps the values of its
     * uniforms, and only this class sets these ones (the shaders are shared
     * by every renderable): a value equal to the last one given to the same
     * shader is not set again.
     */
    static final dashOneUniform = new UniformCache('dashOne');
    static final gammaRatiosUniform = new UniformCache('gammaRatios');
    static final contrastUniform = new UniformCache('grayscaleEnhancedContrast');
    static final pathCoverageUniform = new UniformCache('pathCoverage');
    static final straightAlphaUniform = new UniformCache('straightAlpha');
    static final gradientColor1Uniform = new UniformCache('gradientColor1');
    static final gradientStopsUniform = new UniformCache('gradientStops');

    /**
     * Vertex attributes and varying rows (GLSL ES 1.0 appendix A packing)
     * the default shaders need: `shaders.GlazeQuad` reads 12 attributes and
     * 10 varying rows.
     */
    public static inline final DEFAULT_SHADERS_VERTEX_ATTRIBUTES = 12;
    public static inline final DEFAULT_SHADERS_VARYING_VECTORS = 10;

    /**
     * Whether quads, shadows and paths are drawn with the compact shaders
     * (`shaders.GlazeQuadCompact`, `shaders.GlazeShadowCompact`,
     * `shaders.GlazePathSpriteCompact`), which fit in 8 vertex attributes
     * and 8 varying rows: only when the GPU gives less than the default
     * shaders need, like WebGL in Firefox with fingerprinting resistance
     * or `webgl.min_capability_mode`. Chosen once by `chooseShaders()`,
     * before the shaders are loaded (define `glaze_compact_shaders` to
     * force them, for tests).
     */
    public static var useCompactShaders(default, null):Bool = false;

    /**
     * Whether a GPU with these limits needs the compact shaders (the
     * default ones need `DEFAULT_SHADERS_VERTEX_ATTRIBUTES` attributes and
     * `DEFAULT_SHADERS_VARYING_VECTORS` varying vectors).
     */
    public static function needsCompactShaders(maxVertexAttributes:Int, maxVaryingVectors:Int):Bool {

        return maxVertexAttributes < DEFAULT_SHADERS_VERTEX_ATTRIBUTES
            || maxVaryingVectors < DEFAULT_SHADERS_VARYING_VECTORS;

    }

    /**
     * Sets `useCompactShaders` from the limits of the GPU and returns it.
     * Called by `ceramic.GlazePlugin` before it adds the shaders to the
     * default assets.
     */
    public static function chooseShaders():Bool {

        #if glaze_compact_shaders
        useCompactShaders = true;
        #else
        final backendShaders = ceramic.App.app.backend.shaders;
        useCompactShaders = needsCompactShaders(backendShaders.maxVertexAttributes(), backendShaders.maxVaryingVectors());
        #end
        return useCompactShaders;

    }

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

        if (defaultRenderToTexture) {
            renderToTexture = true;
        }
        if (defaultPartialRendering) {
            partialRendering = true;
        }

    }

    override function destroy():Void {

        destroyTarget();
        super.destroy();

    }

    override function set_width(width:Float):Float {

        if (this.width != width) {
            super.set_width(width);
            targetLayoutDirty();
        }
        return width;

    }

    override function set_height(height:Float):Float {

        if (this.height != height) {
            super.set_height(height);
            targetLayoutDirty();
        }
        return height;

    }

    /**
     * Draw the scene into the render texture again at the next Ceramic frame
     * (`renderToTexture` mode; nothing to do otherwise). Called when the
     * scene, the atlas textures, the scale, the size or the gamma change.
     */
    public function markRenderDirty():Void {

        if (targetTexture != null) {
            targetTexture.renderDirty = true;
        }
        if (verifyTexture != null) {
            verifyTexture.renderDirty = true;
        }

    }

    /**
     * Whether the texture is drawn partially (`partialRendering` on a
     * backend that supports it).
     */
    inline function partialActive():Bool {

        #if clay
        return partialRendering;
        #else
        return false;
        #end

    }

    /**
     * Lists the render textures shown by the scene's polychrome sprites
     * (`externalTargets`), keeping the versions of those already listed.
     */
    function updateExternalTargets():Void {

        if (!externalTargetsDirty) return;
        externalTargetsDirty = false;
        final listed = scratchTargets;
        final versions = scratchVersions;
        listed.resize(0);
        versions.resize(0);
        final scene = this.scene;
        if (scene != null) {
            final sprites = scene.polychromeSprites;
            final textures = atlasTextures;
            var lastIndex = -1;
            for (i in 0...sprites.length) {
                final index = sprites[i].textureIndex;
                // Consecutive sprites mostly share their texture
                if (index == lastIndex) continue;
                lastIndex = index;
                final texture = index >= 0 && index < textures.length ? textures[index] : null;
                if (texture == null) continue;
                final target = texture.asRenderTexture;
                if (target == null || target == targetTexture || listed.indexOf(target) != -1) continue;
                // A texture listed before keeps the version it was drawn with
                final previous = externalTargets.indexOf(target);
                listed.push(target);
                versions.push(previous != -1 ? externalVersions[previous] : target.renderVersion);
            }
        }
        scratchTargets = externalTargets;
        scratchVersions = externalVersions;
        externalTargets = listed;
        externalVersions = versions;
        if (listed.length > 0) {
            // The per frame check runs in the system, which windows drawn by
            // hand (`autoDraw: false`) do not create
            glaze.GlazeSystem.ensure();
        }

    }

    /**
     * Called once per frame by the window (`GlazeSystem`): when a render
     * texture shown by the scene is about to be drawn by Ceramic this frame
     * (`autoRender` or `renderDirty`) or was drawn since this renderable's
     * texture was (its `renderVersion` changed), draws the texture again
     * (`markRenderDirty()`). In `partialRendering` mode, only the rectangles
     * of the sprites showing it are drawn again (`SceneDamage` records the
     * versions). No view is rendered and the scene is unchanged: Ceramic
     * draws the external texture before this one (it is among the used
     * textures), so the sprites sample its new pixels. Returns whether the
     * texture was marked dirty. Nothing to do without `renderToTexture`: the
     * scene is then drawn at every Ceramic frame.
     */
    public function checkExternalTextures():Bool {

        if (!renderToTexture || targetTexture == null) return false;
        updateExternalTargets();
        for (i in 0...externalTargets.length) {
            final target = externalTargets[i];
            if (target.destroyed) continue;
            if (target.renderVersion != externalVersions[i] || target.renderDirty || target.autoRender) {
                if (!targetTexture.renderDirty) {
                    externalTextureRedraws++;
                    markRenderDirty();
                }
                return true;
            }
        }
        return false;

    }

    /** Remembers the versions of the external textures as drawn (the texture is being drawn). */
    function recordExternalVersions():Void {

        updateExternalTargets();
        for (i in 0...externalTargets.length) {
            externalVersions[i] = externalTargets[i].renderVersion;
        }

    }

    inline function targetLayoutDirty():Void {

        if (renderToTexture) {
            contentDirty = true;
        }

    }

    /**
     * Creates or resizes the render texture of `renderToTexture` mode, before
     * the visuals are rendered.
     */
    override function computeContent():Void {

        if (renderToTexture) {
            updateTarget();
        }
        contentDirty = false;

    }

    function updateTarget():Void {

        final density = sceneScale;
        final textureWidth = Math.round(width * density);
        final textureHeight = Math.round(height * density);

        if (textureWidth <= 0 || textureHeight <= 0) {
            destroyTarget();
            return;
        }

        #if clay
        // A texture larger than the GPU allows (2048 or 1024 pixels with
        // WebGL in Firefox with fingerprinting resistance or
        // `webgl.min_capability_mode`) cannot be created: draw the scene
        // directly instead (same bytes, see `defaultRenderToTexture`)
        final backendTextures = ceramic.App.app.backend.textures;
        if (textureWidth > backendTextures.maxTextureWidth() || textureHeight > backendTextures.maxTextureHeight()) {
            ceramic.Shortcuts.log.warning('Scene of ${textureWidth}x${textureHeight} pixels larger than the maximum texture size (${backendTextures.maxTextureWidth()}x${backendTextures.maxTextureHeight()}): drawn without render texture');
            renderToTexture = false;
            return;
        }
        #end

        if (targetTexture != null
            && targetTexture.density == density
            && Math.round(targetTexture.width * density) == textureWidth
            && Math.round(targetTexture.height * density) == textureHeight) {
            targetTexture.clearOnRender = !partialActive();
            updateVerifyTarget();
            layoutTargetQuad();
            return;
        }

        if (targetTexture != null) {
            targetQuad.texture = null;
            targetTexture.destroy();
            targetTexture = null;
        }

        // No depth, stencil or multisampling: GPUI's shaders antialias
        // their primitives themselves, nothing clips with the stencil
        final texture = new ceramic.RenderTexture(width, height, density, false, false, 0);
        texture.autoRender = false;
        // In partial mode, the drawer clears what it draws again
        texture.clearOnRender = !partialActive();
        texture.filter = NEAREST;
        texture.renderDirty = true;
        targetTexture = texture;
        damage.invalidate();

        if (targetDrawer == null) {
            targetDrawer = new SceneTargetDrawer(this);
        }
        targetDrawer.usedTexturesDirty = true;
        texture.add(targetDrawer);

        if (targetQuad == null) {
            targetQuad = new ceramic.Quad();
            // Rows bottom up (see `SceneTargetDrawer.render()`)
            if (MIRROR_TARGET) targetQuad.scaleY = -1;
            // Input goes to this renderable (see `GlazeInput`)
            targetQuad.touchable = false;
            add(targetQuad);
        }
        targetQuad.texture = texture;
        layoutTargetQuad();
        updateVerifyTarget();

    }

    /**
     * Creates, resizes or destroys the reference texture of
     * `verifyPartialRendering`.
     */
    function updateVerifyTarget():Void {

        if (!verifyPartialRendering || !partialActive() || targetTexture == null) {
            destroyVerifyTarget();
            return;
        }
        if (verifyTexture != null
            && verifyTexture.density == targetTexture.density
            && verifyTexture.width == targetTexture.width
            && verifyTexture.height == targetTexture.height) {
            return;
        }
        destroyVerifyTarget();
        final texture = new ceramic.RenderTexture(targetTexture.width, targetTexture.height, targetTexture.density, false, false, 0);
        texture.autoRender = false;
        texture.clearOnRender = true;
        texture.renderDirty = true;
        verifyTexture = texture;
        verifyDrawer = new SceneTargetDrawer(this, true);
        verifyDrawer.usedTexturesDirty = true;
        texture.add(verifyDrawer);
        ceramic.App.app.onFinishDraw(this, verifyAfterDraw);

    }

    function destroyVerifyTarget():Void {

        if (verifyDrawer != null) {
            verifyDrawer.destroy();
            verifyDrawer = null;
        }
        if (verifyTexture != null) {
            verifyTexture.destroy();
            verifyTexture = null;
            ceramic.App.app.offFinishDraw(verifyAfterDraw);
        }
        verifyPending = false;

    }

    /**
     * Compares the partially drawn texture with the full redraw of the same
     * scene (`verifyPartialRendering`), after Ceramic drew both.
     */
    function verifyAfterDraw():Void {

        if (!verifyPending || targetTexture == null || verifyTexture == null) return;
        verifyPending = false;

        final pixelCount = Std.int(targetTexture.nativeWidthActual * targetTexture.nativeHeightActual * 4);
        if (verifyPixels == null || verifyPixels.length != pixelCount) {
            verifyPixels = new ceramic.UInt8Array(pixelCount);
            verifyReferencePixels = new ceramic.UInt8Array(pixelCount);
        }
        targetTexture.fetchPixels(verifyPixels);
        verifyTexture.fetchPixels(verifyReferencePixels);

        partialVerifiedFrames++;
        if (verifyPendingPartial) partialDrawnFrames++;
        if (verifyPendingFull) partialFullFrames++;
        partialRedrawnArea += verifyPendingArea;
        partialTotalArea += targetTexture.nativeWidthActual * targetTexture.nativeHeightActual;

        var differing = 0;
        var first = -1;
        for (i in 0...pixelCount) {
            if (verifyPixels[i] != verifyReferencePixels[i]) {
                if (first < 0) first = i;
                differing++;
            }
        }
        if (differing > 0) {
            partialMismatchedFrames++;
            if (partialFirstMismatch == null) {
                final width = Std.int(targetTexture.nativeWidthActual);
                final pixel = Std.int(first / 4);
                partialFirstMismatch = 'frame ${partialVerifiedFrames}: $differing bytes differ, first at texel '
                    + '(${pixel % width}, ${Std.int(pixel / width)}) ${verifyPixels[first]} instead of ${verifyReferencePixels[first]}'
                    + ', region ${damage.x0},${damage.y0} to ${damage.x1},${damage.y1} in ${damage.rectCount} rectangle(s)'
                    + (verifyPendingPartial ? ' (partial)' : ' (full)');
            }
        }

    }

    inline function layoutTargetQuad():Void {

        targetQuad.size(width, height);
        targetQuad.pos(0, MIRROR_TARGET ? height : 0);

    }

    function destroyTarget():Void {

        destroyVerifyTarget();
        damage.invalidate();
        if (targetQuad != null) {
            targetQuad.destroy();
            targetQuad = null;
        }
        if (targetDrawer != null) {
            targetDrawer.destroy();
            targetDrawer = null;
        }
        if (targetTexture != null) {
            targetTexture.destroy();
            targetTexture = null;
        }

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
     * which `GlazePlugin` does with the default assets.
     */
    function ensureShaders():Bool {

        if (quadShader == null) {
            final assets = ceramic.App.app.assets;
            if (useCompactShaders) {
                quadShader = assets.shader(shaders.GlazeQuadCompact);
                shadowShader = assets.shader(shaders.GlazeShadowCompact);
                pathSpriteShader = assets.shader(shaders.GlazePathSpriteCompact);
            }
            else {
                quadShader = assets.shader(shaders.GlazeQuad);
                shadowShader = assets.shader(shaders.GlazeShadow);
                pathSpriteShader = assets.shader(shaders.GlazePathSprite);
            }
            underlineShader = assets.shader(shaders.GlazeUnderline);
            monoSpriteShader = assets.shader(shaders.GlazeMonoSprite);
            polySpriteShader = assets.shader(shaders.GlazePolySprite);
        }

        return quadShader != null
            && shadowShader != null
            && underlineShader != null
            && monoSpriteShader != null
            && polySpriteShader != null
            && pathSpriteShader != null;

    }

    override function render(draw:backend.Draw):Void {

        // In `renderToTexture` mode, `targetDrawer` draws the scene into the
        // texture shown by `targetQuad`
        if (renderToTexture) return;
        glaze.util.FrameProfiler.begin(glaze.util.FrameProfiler.RENDER);
        renderScene(draw, matA, matB, matC, matD, matTX, matTY);
        glaze.util.FrameProfiler.end(glaze.util.FrameProfiler.RENDER);

    }

    /**
     * Draws the scene with the given local (logical units) to world matrix.
     */
    function renderScene(draw:backend.Draw, a:Float, b:Float, c:Float, d:Float, tx:Float, ty:Float):Void {

        if (scene == null || scene.len() == 0) return;
        if (!ensureShaders()) {
            damage.invalidate();
            return;
        }

        if (gammaRatiosDirty) {
            gammaRatiosDirty = false;
            computeGammaCorrectionRatios(fontsGamma, gammaRatios);
        }

        // Local (scaled pixels) to world transform
        final invScale = 1.0 / sceneScale;
        wa = a * invScale;
        wb = b * invScale;
        wc = c * invScale;
        wd = d * invScale;
        wtx = tx;
        wty = ty;

        draw.setBlendFuncSeparate(
            BlendMode.ONE, BlendMode.ONE_MINUS_SRC_ALPHA,
            BlendMode.ONE, BlendMode.ONE_MINUS_SRC_ALPHA
        );

        scene.resetBatches();
        var batch = scene.nextBatch();
        var nextBase = 0;
        while (batch != null) {
            batchBase = nextBase;
            nextBase += batch.end - batch.start;
            // A partial pass skips the batches it draws nothing of (no
            // shader switch, no flush)
            if (regionClip && batchOutsideRegion(batchBase, nextBase)) {
                batch = scene.nextBatch();
                continue;
            }
            switch batch.kind {
                case Shadow:
                    if (useCompactShaders) drawShadowsCompact(draw, batch);
                    else drawShadows(draw, batch);
                case Quad:
                    if (useCompactShaders) drawQuadsCompact(draw, batch);
                    else drawQuads(draw, batch);
                case Path:
                    if (useCompactShaders) drawPathsCompact(draw, batch);
                    else drawPaths(draw, batch);
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

    /**
     * Whether the primitive at `index` (in draw order) of a batch is left
     * out of a partial redraw: its rectangle misses the redrawn region, so
     * it changes none of its pixels.
     */
    inline function outsideRegion(index:Int):Bool {

        return regionClip && (
            damage.drawnRectX0(index) >= regionX1
            || damage.drawnRectX1(index) <= regionX0
            || damage.drawnRectY0(index) >= regionY1
            || damage.drawnRectY1(index) <= regionY0
        );

    }

    /** Whether every primitive `start...end` (in draw order) is outside the redrawn region */
    @:noDebug
    function batchOutsideRegion(start:Int, end:Int):Bool {

        for (i in start...end) {
            if (!outsideRegion(i)) return false;
        }
        return true;

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

        // Order barrier of the dash code (see `GlazeQuad_Frag.dashOne`)
        dashOneUniform.setFloat(quadShader, 1);
        useShader(draw, quadShader);
        final quads = scene.quads;

        for (q in batch.start...batch.end) {
            if (outsideRegion(batchBase + q - batch.start)) continue;
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
            if (outsideRegion(batchBase + s - batch.start)) continue;
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
            if (outsideRegion(batchBase + u - batch.start)) continue;
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

        gammaRatiosUniform.setVec4(monoSpriteShader, gammaRatios[0], gammaRatios[1], gammaRatios[2], gammaRatios[3]);
        contrastUniform.setFloat(monoSpriteShader, grayscaleEnhancedContrast);
        useShader(draw, monoSpriteShader);

        final texture = bindAtlasTexture(draw, batch.textureIndex);
        if (texture == null) return;

        final texWidth:Float = texture.nativeWidthActual;
        final texHeight:Float = texture.nativeHeightActual;
        final sprites = scene.monochromeSprites;

        for (si in batch.start...batch.end) {
            if (outsideRegion(batchBase + si - batch.start)) continue;
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
     * drawn with `shaders.GlazePathSprite`, which fills them with their
     * background (solid, linear gradient or pattern) evaluated at each pixel
     * center like GPUI's `path_rasterization_fragment`, and quantizes the
     * color like GPUI's Metal path pipeline (8-bit samples, resolved).
     */
    function drawPaths(draw:backend.Draw, batch:PrimitiveBatch):Void {

        // RGBA (polychrome) pages hold the tiles of paths with Loop-Blinn
        // curves, monochrome pages coverage masks (see `PathRasterizer`)
        final batchTexture = batch.textureIndex >= 0 && batch.textureIndex < atlasTextures.length ? atlasTextures[batch.textureIndex] : null;
        final curves = batchTexture != null && CeramicAtlas.isStraightAlpha(batchTexture);
        pathCoverageUniform.setFloat(pathSpriteShader, curves ? 2 : 1);
        useShader(draw, pathSpriteShader);

        final texture = bindAtlasTexture(draw, batch.textureIndex);
        if (texture == null) return;

        final texWidth:Float = texture.nativeWidthActual;
        final texHeight:Float = texture.nativeHeightActual;
        final paths = scene.paths;

        for (si in batch.start...batch.end) {
            if (outsideRegion(batchBase + si - batch.start)) continue;
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

/// Compact shaders

    /**
     * `drawQuads()` with `shaders.GlazeQuadCompact` (see `useCompactShaders`).
     */
    function drawQuadsCompact(draw:backend.Draw, batch:PrimitiveBatch):Void {

        // Order barrier of the dash code (see `GlazeQuadCompact_Frag.dashOne`)
        dashOneUniform.setFloat(quadShader, 1);
        useShader(draw, quadShader);
        final quads = scene.quads;

        for (q in batch.start...batch.end) {
            if (outsideRegion(batchBase + q - batch.start)) continue;
            final quad = quads[q];
            // The second stop of a linear gradient and its stop percentages
            // are uniforms (the vertex attributes and varyings must fit in
            // WebGL's minimum limits): a draw call holds the gradient quads
            // of one value. Switched before taking the base vertex, as a
            // flush restarts the vertex buffers.
            final gradient = quad.backgroundTag == 1;
            if (gradient) {
                hslaToRgba(quad.backgroundColor1H, quad.backgroundColor1S, quad.backgroundColor1L, quad.backgroundColor1A);
                if (!gradientColor1Uniform.hasVec4(quadShader, r, g, b, a)
                    || !gradientStopsUniform.hasVec2(quadShader, quad.backgroundColor0Percentage, quad.backgroundColor1Percentage)) {
                    draw.flush();
                    gradientColor1Uniform.setVec4(quadShader, r, g, b, a);
                    gradientStopsUniform.setVec2(quadShader, quad.backgroundColor0Percentage, quad.backgroundColor1Percentage);
                    draw.useShader(quadShader.backendItem);
                }
            }
            ensureCapacity(draw, quadShader);
            final base = draw.getNumPos();

            // Background color: the solid color, or the first stop of a
            // linear gradient (the shader reads one or the other)
            if (gradient) {
                hslaToRgba(quad.backgroundColor0H, quad.backgroundColor0S, quad.backgroundColor0L, quad.backgroundColor0A);
            }
            else {
                hslaToRgba(quad.backgroundSolidH, quad.backgroundSolidS, quad.backgroundSolidL, quad.backgroundSolidA);
            }
            final solidR = r;
            final solidG = g;
            final solidB = b;
            final solidA = a;
            hslaToRgba(quad.borderColorH, quad.borderColorS, quad.borderColorL, quad.borderColorA);
            final borderR = r;
            final borderG = g;
            final borderB = b;
            final borderA = a;
            // Unit vertex and flags (see `GlazeQuadCompact_Vert.vertexTCoord`)
            final flags = (4.0 * (quad.backgroundTag + 4 * quad.backgroundColorSpace + 8 * quad.borderStyle));
            final value = quad.backgroundGradientAngleOrPatternHeight;

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
                draw.endFloatAttributes();

                draw.putUVs(ux + 2.0 * uy + flags, value);
                draw.putColor(solidR, solidG, solidB, solidA);
            }

            putQuadIndices(draw, base);
        }

    }

    /**
     * `drawShadows()` with `shaders.GlazeShadowCompact` (see `useCompactShaders`).
     */
    function drawShadowsCompact(draw:backend.Draw, batch:PrimitiveBatch):Void {

        useShader(draw, shadowShader);
        final shadows = scene.shadows;

        for (s in batch.start...batch.end) {
            if (outsideRegion(batchBase + s - batch.start)) continue;
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

            // Unit vertex and inset flag, blur radius (see `GlazeShadowCompact_Vert.vertexTCoord`)
            final insetFlag = shadow.inset ? 4.0 : 0.0;

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
                // vertexElementCornerRadii (the element bounds of an inset
                // shadow are its geometry)
                draw.putFloatAttribute(16, shadow.elementCornerRadiusTopLeft);
                draw.putFloatAttribute(17, shadow.elementCornerRadiusTopRight);
                draw.putFloatAttribute(18, shadow.elementCornerRadiusBottomRight);
                draw.putFloatAttribute(19, shadow.elementCornerRadiusBottomLeft);
                draw.endFloatAttributes();

                draw.putUVs(ux + 2.0 * uy + insetFlag, shadow.blurRadius);
                draw.putColor(r, g, b, a);
            }

            putQuadIndices(draw, base);
        }

    }

    /**
     * `drawPaths()` with `shaders.GlazePathSpriteCompact` (see `useCompactShaders`).
     */
    function drawPathsCompact(draw:backend.Draw, batch:PrimitiveBatch):Void {

        // RGBA (polychrome) pages hold the tiles of paths with Loop-Blinn
        // curves, monochrome pages coverage masks (see `PathRasterizer`)
        final batchTexture = batch.textureIndex >= 0 && batch.textureIndex < atlasTextures.length ? atlasTextures[batch.textureIndex] : null;
        final curves = batchTexture != null && CeramicAtlas.isStraightAlpha(batchTexture);
        pathCoverageUniform.setFloat(pathSpriteShader, curves ? 2 : 1);
        useShader(draw, pathSpriteShader);

        final texture = bindAtlasTexture(draw, batch.textureIndex);
        if (texture == null) return;

        final texWidth:Float = texture.nativeWidthActual;
        final texHeight:Float = texture.nativeHeightActual;
        final paths = scene.paths;

        for (si in batch.start...batch.end) {
            if (outsideRegion(batchBase + si - batch.start)) continue;
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
            // Solid color, or the first stop of a linear gradient (the
            // shader reads one or the other)
            if (tag != 1) {
                hslaToRgba(path.colorH, path.colorS, path.colorL, path.colorA);
            }
            else {
                r = c0R;
                g = c0G;
                b = c0B;
                a = c0A;
            }

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
                // vertexScenePosition (xy) and gradient stops (zw)
                draw.putFloatAttribute(0, sx);
                draw.putFloatAttribute(1, sy);
                draw.putFloatAttribute(2, stop0);
                draw.putFloatAttribute(3, stop1);
                // vertexContentMask
                draw.putFloatAttribute(4, path.contentMaskX);
                draw.putFloatAttribute(5, path.contentMaskY);
                draw.putFloatAttribute(6, path.contentMaskWidth);
                draw.putFloatAttribute(7, path.contentMaskHeight);
                // vertexBounds
                draw.putFloatAttribute(8, clipLeft);
                draw.putFloatAttribute(9, clipTop);
                draw.putFloatAttribute(10, clipWidth);
                draw.putFloatAttribute(11, clipHeight);
                // vertexParams
                draw.putFloatAttribute(12, tag);
                draw.putFloatAttribute(13, colorSpace);
                draw.putFloatAttribute(14, angleOrHeight);
                // vertexColor1
                draw.putFloatAttribute(15, c1R);
                draw.putFloatAttribute(16, c1G);
                draw.putFloatAttribute(17, c1B);
                draw.putFloatAttribute(18, c1A);
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
        return glaze.SpringMath.f32(value);
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
        straightAlphaUniform.setFloat(polySpriteShader, straightAlpha ? 1.0 : 0.0);
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
            if (outsideRegion(batchBase + si - batch.start)) continue;
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

/**
 * The renderable drawing the scene of a `SceneRenderable` into its render
 * texture (`renderToTexture` mode), at the origin of the texture.
 */
@:allow(glaze.platform.SceneRenderable)
class SceneTargetDrawer extends Renderable {

    final owner:SceneRenderable;

    /** Always draws the whole scene (reference of `verifyPartialRendering`) */
    final reference:Bool;

    function new(owner:SceneRenderable, reference:Bool = false) {

        super();
        this.owner = owner;
        this.reference = reference;
        pos(0, 0);

    }

    override function computeUsedTextures():Void {

        final arr = usedTextures.original;
        arr.resize(0);
        for (texture in owner.atlasTextures) {
            if (texture != null) {
                arr.push(texture);
            }
        }

    }

    override function render(draw:backend.Draw):Void {

        // Ceramic flips the content of render textures vertically (row 0 at
        // the top, like loaded textures). The scene is drawn mirrored so that
        // this flip gives back the vertex positions the screen would get: the
        // GPU rasterizes and interpolates exactly like on the screen, with
        // the texture rows bottom up (`targetQuad` shows them mirrored back).
        // Not on Unity, which does not flip (see `MIRROR_TARGET`)
        final height = owner.targetTexture != null ? owner.targetTexture.height : owner.height;

        // The reference drawer of `verifyPartialRendering` is left out
        if (!reference) {
            owner.recordExternalVersions();
            glaze.util.FrameProfiler.begin(glaze.util.FrameProfiler.RENDER);
        }
        #if clay
        if (!reference && owner.partialRendering && owner.targetTexture != null) {
            renderPartial(draw, height);
        }
        else
        #end
        if (SceneRenderable.MIRROR_TARGET) {
            owner.regionClip = false;
            owner.renderScene(draw, matA, -matB, matC, -matD, matTX, height - matTY);
        }
        else {
            owner.regionClip = false;
            owner.renderScene(draw, matA, matB, matC, matD, matTX, matTY);
        }
        if (!reference) glaze.util.FrameProfiler.end(glaze.util.FrameProfiler.RENDER);

    }

    #if clay
    /**
     * `partialRendering`: clears and draws again the region that changed
     * since the last draw (see `SceneDamage`), one damage rectangle at a
     * time with a scissor. The texture is not cleared by Ceramic in this
     * mode (`clearOnRender` is off).
     */
    function renderPartial(draw:backend.Draw, height:Float):Void {

        final texture = owner.targetTexture;
        final pixelWidth = Std.int(texture.nativeWidthActual);
        final pixelHeight = Std.int(texture.nativeHeightActual);
        final damage = owner.damage;

        if (!owner.ensureShaders()) {
            damage.invalidate();
            draw.batcher.clear(0, 0, 0, 0, false);
            return;
        }

        damage.record(owner.scene, owner.atlasTextures, owner.atlas != null ? owner.atlas.releaseCount : -1);
        damage.diff(pixelWidth, pixelHeight);

        var area = 0;
        for (r in 0...damage.rectCount) {
            area += (damage.rectX1(r) - damage.rectX0(r)) * (damage.rectY1(r) - damage.rectY0(r));
        }

        SceneRenderable.partialStatsDraws++;
        if (damage.full) SceneRenderable.partialStatsFullDraws++;
        else if (area > 0) SceneRenderable.partialStatsPartialDraws++;
        SceneRenderable.partialStatsArea += area;
        SceneRenderable.partialStatsTotalArea += pixelWidth * pixelHeight;
        if (!damage.full) SceneRenderable.partialStatsRects += damage.rectCount;

        if (SceneRenderable.verifyPartialRendering) {
            owner.verifyPending = true;
            owner.verifyPendingArea = area;
            owner.verifyPendingPartial = !damage.full && area > 0;
            owner.verifyPendingFull = damage.full;
        }

        if (area <= 0) return;

        if (damage.full) {
            owner.regionClip = false;
            draw.batcher.clear(0, 0, 0, 0, false);
            owner.renderScene(draw, matA, -matB, matC, -matD, matTX, height - matTY);
            return;
        }

        // One pass per damage rectangle, each with its own scissor (see
        // `SceneDamage` for why this gives the bytes of a full redraw).
        // Scene rows are drawn where the screen would have them (see
        // `render()`): scene row y is framebuffer row `pixelHeight - 1 - y`
        draw.flush();
        for (r in 0...damage.rectCount) {
            final x0 = damage.rectX0(r);
            final y0 = damage.rectY0(r);
            final x1 = damage.rectX1(r);
            final y1 = damage.rectY1(r);
            draw.batcher.enableScissor(x0, pixelHeight - y1, x1 - x0, y1 - y0);
            draw.batcher.clear(0, 0, 0, 0, false);
            owner.regionClip = true;
            owner.regionX0 = x0;
            owner.regionY0 = y0;
            owner.regionX1 = x1;
            owner.regionY1 = y1;
            owner.renderScene(draw, matA, -matB, matC, -matD, matTX, height - matTY);
            owner.regionClip = false;
            draw.flush();
        }
        draw.batcher.disableScissor();

    }
    #end

}

/**
 * The last value given to a uniform of a shader (see `SceneRenderable`).
 */
class UniformCache {

    final name:String;

    var shader:Null<Shader> = null;

    var x:Float = 0;
    var y:Float = 0;
    var z:Float = 0;
    var w:Float = 0;

    public function new(name:String) {
        this.name = name;
    }

    public inline function setFloat(target:Shader, value:Float):Void {
        if (shader != target || x != value) {
            shader = target;
            x = value;
            target.setFloat(name, value);
        }
    }

    public inline function setVec2(target:Shader, x:Float, y:Float):Void {
        if (shader != target || this.x != x || this.y != y) {
            shader = target;
            this.x = x;
            this.y = y;
            target.setVec2(name, x, y);
        }
    }

    /** Whether `target` already has this value */
    public inline function hasVec2(target:Shader, x:Float, y:Float):Bool {
        return shader == target && this.x == x && this.y == y;
    }

    /** Whether `target` already has this value */
    public inline function hasVec4(target:Shader, x:Float, y:Float, z:Float, w:Float):Bool {
        return shader == target && this.x == x && this.y == y && this.z == z && this.w == w;
    }

    public inline function setVec4(target:Shader, x:Float, y:Float, z:Float, w:Float):Void {
        if (shader != target || this.x != x || this.y != y || this.z != z || this.w != w) {
            shader = target;
            this.x = x;
            this.y = y;
            this.z = z;
            this.w = w;
            target.setVec4(name, x, y, z, w);
        }
    }

}
