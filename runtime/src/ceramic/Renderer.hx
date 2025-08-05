package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/**
 * The core 2D rendering engine for Ceramic, responsible for efficiently drawing all visuals to the screen.
 * 
 * This implementation-independent renderer works with backend draw implementations to:
 * - Batch draw calls for optimal GPU performance
 * - Manage render state (textures, shaders, blend modes)
 * - Handle render-to-texture operations
 * - Implement stencil-based clipping
 * - Support multi-texture batching when available
 * 
 * The renderer uses several optimization strategies:
 * - **State batching**: Groups visuals with the same rendering state
 * - **Texture atlasing**: Batches multiple textures in a single draw call
 * - **Vertex buffering**: Minimizes GPU state changes
 * - **Z-ordering**: Maintains proper visual layering
 * 
 * Rendering pipeline:
 * 1. Sort visuals by depth and rendering state
 * 2. Group visuals into batches with matching states
 * 3. Submit batches to GPU with minimal state changes
 * 4. Handle special cases (stencil clipping, render targets)
 * 
 * ```haxe
 * // The renderer is typically managed by the App
 * var renderer = app.renderer;
 * renderer.render(true, app.visuals);
 * ```
 * 
 * @see Visual The base class for all renderable objects
 * @see backend.Draw The backend interface for GPU operations
 * @see Shader For custom GPU shader programs
 * @see RenderTexture For off-screen rendering
 */
class Renderer extends Entity {

    /**
     * Number of draw calls made in the current frame.
     * Lower values indicate better batching performance.
     */
    var drawCalls:Int = 0;

    /**
     * Currently active GPU shader program.
     */
    var activeShader:backend.Shader = null;
    
    /**
     * Number of custom float attributes per vertex for the active shader.
     */
    var customFloatAttributesSize:Int = 0;

    /**
     * Whether we're currently rendering to the stencil buffer for clipping.
     */
    var stencilClip:Bool = false;

    /**
     * Last used texture to detect state changes.
     */
    var lastTexture:ceramic.Texture = null;
    
    /**
     * Backend ID of the last used texture.
     */
    var lastTextureId:backend.TextureId = backend.TextureId.DEFAULT;
    
    /**
     * Last used shader to detect state changes.
     */
    var lastShader:ceramic.Shader = null;
    
    /**
     * Last used render target to detect state changes.
     */
    var lastRenderTarget:ceramic.RenderTexture = null;
    
    /**
     * Last computed blending mode to detect state changes.
     */
    var lastComputedBlending:ceramic.Blending = ceramic.Blending.PREMULTIPLIED_ALPHA;
    
    /**
     * Last clipping visual to detect state changes.
     */
    var lastClip:ceramic.Visual = null;
    
    /**
     * Whether the last clip was a regular quad (can use scissor test).
     */
    var lastClipIsRegular:Bool = false;
    
    /**
     * Currently active texture slot for multi-texturing.
     */
    var activeTextureSlot:Int = 0;

    /**
     * Backend texture management interface.
     */
    var backendTextures:backend.Textures;
    
    /**
     * Backend shader management interface.
     */
    var backendShaders:backend.Shaders;

    /**
     * Logical width of the current texture.
     */
    var texWidth:Int = 0;
    
    /**
     * Logical height of the current texture.
     */
    var texHeight:Int = 0;
    
    /**
     * Actual GPU width of the current texture (may be power of 2).
     */
    var texWidthActual:Int = 0;
    
    /**
     * Actual GPU height of the current texture (may be power of 2).
     */
    var texHeightActual:Int = 0;

    /**
     * Default shader for textured rendering.
     */
    var defaultTexturedShader:backend.Shader = null;
    
    /**
     * Default white texture used when no texture is specified.
     */
    var defaultWhiteTexture:ceramic.Texture = null;

    /**
     * Current quad being processed (for type casting optimization).
     */
    var quad:ceramic.Quad = null;
    
    /**
     * Current mesh being processed (for type casting optimization).
     */
    var mesh:ceramic.Mesh = null;

    /**
     * Whether the rendering state needs to be updated.
     */
    var stateDirty:Bool = true;

    /**
     * Current Z depth value for layering visuals.
     * Incremented slightly for each visual to maintain order.
     */
    var z:Float = 0;

    /**
     * Indexes of textures used in the current batch.
     */
    var usedTextureIndexes:Array<Int> = [];
    
    /**
     * Number of textures currently bound for multi-texturing.
     */
    var usedTextures:Int = 0;
    
    /**
     * Maximum number of textures that can be used in a single batch.
     * Determined by GPU capabilities and shader limitations.
     */
    var maxUsableTexturesInBatch:Int = -1;
    
    /**
     * Whether the active shader supports multi-texture batching.
     */
    var activeShaderCanBatchMultipleTextures:Bool = false;

    /**
     * Currently active render target.
     */
    var usedRenderTarget:ceramic.RenderTexture = null;

    #if ceramic_debug_draw
    var lastDebugTime:Float = -1;
    public static var debugDraw:Bool = false;
    var drawnQuads:Int = 0;
    var drawnMeshes:Int = 0;
    var flushedQuads:Int = 0;
    var flushedMeshes:Int = 0;
    #end

    #if ceramic_wireframe
    var lastWireframe = false;
    #end

    public function new() {

        super();

    }

    /**
     * Renders a list of visuals to the screen or render target.
     * 
     * This is the main entry point for the rendering pipeline. It:
     * 1. Initializes rendering state
     * 2. Processes each visual in order
     * 3. Batches visuals with matching states
     * 4. Handles special rendering modes (clipping, render targets)
     * 5. Submits draw calls to the GPU
     * 
     * @param isMainRender Whether this is the main render pass (vs render-to-texture)
     * @param ceramicVisuals Array of visuals to render, pre-sorted by depth
     */
    public function render(isMainRender:Bool, ceramicVisuals:Array<Visual>):Void {

        var draw = app.backend.draw;
        backendTextures = app.backend.textures;
        backendShaders = app.backend.shaders;

        //defaultPlainShader = ceramic.App.app.defaultColorShader.backendItem;
        defaultTexturedShader = ceramic.App.app.defaultTexturedShader.backendItem;
        defaultWhiteTexture = ceramic.App.app.defaultWhiteTexture;

        maxUsableTexturesInBatch = Std.int(Math.min(
            backendTextures.maxTexturesByBatch(),
            backendShaders.maxIfStatementsByFragmentShader()
        ));

        while (usedTextureIndexes.length < maxUsableTexturesInBatch) {
            usedTextureIndexes.push(0);
        }

        #if ceramic_avoid_last_texture_slot
        if (maxUsableTexturesInBatch > 1) {
            // On some devices, we have problems if we use the last texture slot.
            // As a workaround, we avoid using it. I wish I could understand why.
            // That's sad. Very sad.
            maxUsableTexturesInBatch--;
        }
        #end

        usedRenderTarget = null;

    #if ceramic_debug_draw
        if (isMainRender) {
            if (ceramic.Timer.now - lastDebugTime > 10) {
                debugDraw = true;
                lastDebugTime = ceramic.Timer.now;
            } else {
                debugDraw = false;
            }
            drawnQuads = 0;
            drawnMeshes = 0;
            flushedQuads = 0;
            flushedMeshes = 0;
        } else {
            debugDraw = false;
        }
    #end

        drawCalls = 0;

        draw.initBuffers();

        quad = null;
        mesh = null;

        lastTexture = null;
        lastTextureId = backend.TextureId.DEFAULT;
        lastShader = null;
        lastRenderTarget = null;
        lastComputedBlending = ceramic.Blending.PREMULTIPLIED_ALPHA;
    #if ceramic_wireframe
        lastWireframe = false;
    #end
        lastClip = null;
        usedTextures = 0;

        texWidth = 0;
        texHeight = 0;
        texWidthActual = 0;
        texHeightActual = 0;

        stencilClip = false;
        z = 0;
        stateDirty = true;

        //var defaultPlainShader:backend.Shader = ceramic.App.app.defaultColorShader.backendItem;
        var defaultTexturedShader:backend.Shader = ceramic.App.app.defaultTexturedShader.backendItem;

        // Mark auto-rendering render textures as dirty
        // and mark render textures as 'not used yet'
        var allRenderTextures = ceramic.App.app.renderTextures;
        for (ii in 0...allRenderTextures.length) {
            var renderTexture = allRenderTextures.unsafeGet(ii);
            renderTexture._usedInRendering = false;
            if (renderTexture.autoRender) {
                renderTexture.renderDirty = true;
            }
        }

        draw.beginRender();

        // Ensure no texture at all are bound before starting rendering
        usedTextures = maxUsableTexturesInBatch;
        unbindUsedTextures(draw);

        // Initialize default state
        draw.setActiveTexture(0);
        activeTextureSlot = 0;
        draw.setRenderTarget(null, true);
        draw.clearAndApplyBackground();
        draw.enableBlending();
        activeShader = null;
        lastShader = null;
        useShader(draw, null);

        // Default blending
        draw.setBlendFuncSeparate(
            backend.BlendMode.ONE,
            backend.BlendMode.ONE_MINUS_SRC_ALPHA,
            backend.BlendMode.ONE,
            backend.BlendMode.ONE_MINUS_SRC_ALPHA
        );
        lastComputedBlending = ceramic.Blending.PREMULTIPLIED_ALPHA;

        // Default stencil test
        draw.drawWithoutStencilTest();

        // For each ceramic visual in the list
        //
        if (ceramicVisuals != null) {

            for (ii in 0...ceramicVisuals.length) {
                var visual = ceramicVisuals.unsafeGet(ii);
                var quad = visual.asQuad;
                var mesh = visual.asMesh;

                // If it's valid to be drawn
                if (visual.computedVisible) {

                    // If it should be redrawn anyway
                    if (visual.computedRenderTarget == null || visual.computedRenderTarget.renderDirty) {

                        var clip:ceramic.Visual;
                        #if !ceramic_no_clip
                        clip = visual.computedClip;
                        #else
                        clip = null;
                        #end

                        if (clip != lastClip) {

                            flush(draw);
                            unbindUsedTextures(draw);
                            stateDirty = true;

                            if (lastClip != null) {
                                if (lastClipIsRegular) {
                                    draw.disableScissor();
                                }
                                else {
                                    lastRenderTarget = lastClip.computedRenderTarget;
                                    useRenderTarget(draw, lastRenderTarget);

                                    // Finish clipping
                                    draw.drawWithoutStencilTest();
                                }
                            }

                            lastClip = clip;

                            if (lastClip != null) {

                                // Update render target
                                lastRenderTarget = lastClip.computedRenderTarget;
                                useRenderTarget(draw, lastRenderTarget);

                                #if !ceramic_no_scissor
                                // If we clip with a regular rectangle quad, we can use scissor(),
                                // but in every other cases we need to use stencil buffer
                                if (lastClip.asQuad != null && lastClip.asQuad.isRegular()) {
                                    // Use scissor
                                    lastClipIsRegular = true;
                                    scissorWithQuad(draw, lastClip.asQuad);
                                }
                                else {
                                #end
                                    // Update stencil buffer
                                    lastClipIsRegular = false;

                                    draw.beginDrawingInStencilBuffer();

                                    if (lastClip.asQuad != null) {
                                        quad = lastClip.asQuad;
                                        stencilClip = true;
                                        drawQuad(draw, quad);
                                        stencilClip = false;
                                        quad = visual.asQuad;
                                    }
                                    else if (lastClip.asMesh != null) {
                                        mesh = lastClip.asMesh;
                                        stencilClip = true;
                                        #if !ceramic_no_mesh
                                        drawMesh(draw, mesh);
                                        #end
                                        stencilClip = false;
                                        mesh = visual.asMesh;
                                    }

                                    // Next things to be drawn will be clipped
                                    flush(draw);
                                    unbindUsedTextures(draw);
                                    stateDirty = true;

                                    draw.endDrawingInStencilBuffer();
                                    draw.drawWithStencilTest();
                                #if !ceramic_no_scissor
                                }
                                #end
                            }
                        }

                        if (quad != null && !quad.transparent) {

                            drawQuad(draw, quad);

                        }

                        else if (mesh != null) {

                            #if !ceramic_no_mesh
                            drawMesh(draw, mesh);
                            #end

                        }
                    }
                }
            }

            flush(draw);
            unbindUsedTextures(draw);
            stateDirty = true;
        }

    #if ceramic_debug_draw
        if (debugDraw) {
            log.success(' -- $drawCalls draw call' + (drawCalls > 1 ? 's' : '') + ' / $drawnQuads quad' + (drawnQuads > 1 ? 's' : '') + ' / $drawnMeshes mesh' + (drawnMeshes > 1 ? 'es' : '') + '');
        }
    #end

        // Mark all textures as rendered (renderDirty = false)
        var allRenderTextures = ceramic.App.app.renderTextures;
        for (ii in 0...allRenderTextures.length) {
            var renderTexture = allRenderTextures.unsafeGet(ii);
            renderTexture.renderDirty = false;
        }

        // Restore state
        draw.setActiveTexture(0);
        activeTextureSlot = 0;
        draw.setRenderTarget(null, true);
        draw.enableBlending();
        activeShader = null;
        lastShader = null;
        useShader(draw, null);

        #if !ceramic_no_scissor
        if (lastClipIsRegular) {
            draw.disableScissor();
        }
        #end

        // Default blending
        draw.setBlendFuncSeparate(
            backend.BlendMode.ONE,
            backend.BlendMode.ONE_MINUS_SRC_ALPHA,
            backend.BlendMode.ONE,
            backend.BlendMode.ONE_MINUS_SRC_ALPHA
        );

    }

    /**
     * Draws a single quad to the current render target.
     * 
     * Optimized for the most common rendering case. Handles:
     * - Texture binding and UV mapping
     * - Color and alpha blending
     * - Matrix transformations
     * - Custom shader attributes
     * - Batching with previous quads when possible
     * 
     * @param draw Backend draw interface
     * @param quad The quad visual to render
     */
    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function drawQuad(draw:backend.Draw, quad:ceramic.Quad):Void {

    #if ceramic_debug_draw
        drawnQuads++;
    #end

        inline function flushAndCleanState() {

            flush(draw);
            unbindUsedTextures(draw);

            // Update texture
            lastTexture = quad.texture;

    #if ceramic_wireframe
            lastWireframe = quad.wireframe;
            if (lastWireframe) {
                lastTexture = null;
                draw.setPrimitiveType(LINE);
            }
            else {
                draw.setPrimitiveType(TRIANGLE);
            }
    #end

            useFirstTextureInBatch(draw, lastTexture);

            // Update render target
            if (quad.computedRenderTarget != lastRenderTarget) {
                lastRenderTarget = quad.computedRenderTarget;
                useRenderTarget(draw, lastRenderTarget);
                if (lastClip != null && lastClipIsRegular) {
                    scissorWithQuad(draw, lastClip.asQuad);
                }
            }

            // Update shader
            lastShader = quad.shader;
            useShader(draw, lastShader != null ? lastShader.backendItem : null);

            // Update blending
            lastComputedBlending = computeQuadBlending(quad);
            useBlending(draw, lastComputedBlending);

            stateDirty = false;

        }

        if (stencilClip) {
            // Special case of drawing into stencil buffer

            // No texture
            unbindUsedTextures(draw);
            useFirstTextureInBatch(draw, null);

            // Default blending
            draw.setBlendFuncSeparate(
                backend.BlendMode.ONE,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA,
                backend.BlendMode.ONE,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA
            );
            lastComputedBlending = ceramic.Blending.PREMULTIPLIED_ALPHA;

            // No render target when writing to stencil buffer
            lastRenderTarget = quad.computedRenderTarget;
            useRenderTarget(draw, lastRenderTarget);

            // Use default shader
            lastShader = null;
            useShader(draw, null);

            stateDirty = false;
        }
        else {
            // Check if state is dirty
            var textureToUseInSameBatch = null;
            var needsCheckRenderTextureClear = true;
            if (!stateDirty) {
                var newComputedBlending = computeQuadBlending(quad);
                stateDirty =
                    !isSameShader(quad.shader, lastShader) ||
                    newComputedBlending != lastComputedBlending ||
    #if ceramic_wireframe
                    quad.wireframe != lastWireframe ||
    #end
                    quad.computedRenderTarget != lastRenderTarget;
    #if ceramic_debug_draw_flush_reason
                if (debugDraw && stateDirty) {
                    if (!isSameShader(quad.shader, lastShader))
                        log.debug('- dirty: shader');
                    if (newComputedBlending != lastComputedBlending)
                        log.debug('- dirty: blending $lastComputedBlending -> $newComputedBlending');
                    if (quad.computedRenderTarget != lastRenderTarget)
                        log.debug('- dirty: render target');
                }
    #end
                if (!stateDirty) {
                    if (quad.texture != lastTexture) {
                        if (quad.texture != null && lastTexture != null) {
                            // Different ceramic textures could use the same backend texture
                            if (!draw.textureBackendItemMatchesId(quad.texture.backendItem, lastTextureId)) {
                                // We could use multiple texture in same batch
                                if (!canUseTextureInSameBatch(draw, quad.texture)) {
    #if ceramic_debug_draw_flush_reason
                                    if (debugDraw) {
                                        log.debug('- dirty: texture not matching');
                                    }
    #end
                                    stateDirty = true;
                                }
                                else {
                                    textureToUseInSameBatch = quad.texture;
                                }
                            }
                        } else {
                            // We could use multiple texture in same batch
                            if (!canUseTextureInSameBatch(draw, quad.texture)) {
    #if ceramic_debug_draw_flush_reason
                                if (debugDraw) {
                                    log.debug('- dirty: texture not matching');
                                }
    #end
                                stateDirty = true;
                            }
                            else {
                                textureToUseInSameBatch = quad.texture != null ? quad.texture : defaultWhiteTexture;
                            }
                        }
                    }
                }
            }

            if (stateDirty) {
                flushAndCleanState();
            }
            else {
                if (textureToUseInSameBatch != null) {
                    useTextureInSameBatch(draw, textureToUseInSameBatch);
                }
            }
        }

        // Submit the current batch if we exceed the max buffer size
        if (draw.shouldFlush(4, 6, customFloatAttributesSize)) {
            flushAndCleanState();
        }

        // Update size
        var w:Float = quad.width;
        var h:Float = quad.height;

        // Fetch matrix
        //
        var matA:Float = quad.matA;
        var matB:Float = quad.matB;
        var matC:Float = quad.matC;
        var matD:Float = quad.matD;
        var matTX:Float = quad.matTX;
        var matTY:Float = quad.matTY;
        var z:Float = this.z;
        var textureSlot:Float = activeShaderCanBatchMultipleTextures ? activeTextureSlot : -1;

        #if ceramic_quad_float_attributes
        var floatAttributes = quad.floatAttributes;
        #end

    #if ceramic_debug_draw
        if (debugDraw && #if ceramic_debug_draw_all true #elseif ceramic_debug_multitexture activeShaderCanBatchMultipleTextures #else quad.id != null #end) {
            log.warning('* drawQuad(${quad.id != null ? quad.id : ''}) slot=$textureSlot texture=${lastTexture} stencil=$stencilClip clip=$lastClip');
        }
    #end

        // Let backend know we will start sending quad data
        draw.beginDrawQuad(quad);

        /** Using an inline internal function because we want to use similar code multiple times,
            and let haxe compiler evaluate `hasCustomAttributes` and `hasTextureSlot`
            at compile time. */
        inline function batchQuadVertices(hasCustomAttributes:Bool, hasTextureSlot:Bool) {

            var numPos = draw.getNumPos();

            #if !ceramic_render_no_flip_quad_vertices

            // We send bottom-right and bottom-left vertices first,
            // then top-left and top-right vertices, because before we did this,
            // we had a bug in web target (windows only) where in some rare situations
            // a gap would be visible between the two triangles.

            //br
            var n8 = matTX + matA * w + matC * h;
            var n9 = matTY + matB * w + matD * h;

            if (hasTextureSlot) {
                draw.putPosAndTextureSlot(
                    n8,
                    n9,
                    z,
                    textureSlot
                );
            }
            else {
                draw.putPos(
                    n8,
                    n9,
                    z
                );
            }
            if (hasCustomAttributes) {
                draw.beginFloatAttributes();
                #if ceramic_quad_float_attributes
                if (floatAttributes != null) {
                    var floatAttributesLen = floatAttributes.length;
                    for (l in 0...customFloatAttributesSize) {
                        var attr = l < floatAttributesLen ? floatAttributes.unsafeGet(l) : 0.0;
                        draw.putFloatAttribute(l, attr);
                    }
                }
                else {
                    for (l in 0...customFloatAttributesSize) {
                        draw.putFloatAttribute(l, 0.0);
                    }
                }
                #else
                for (l in 0...customFloatAttributesSize) {
                    draw.putFloatAttribute(l, 0.0);
                }
                #end
                draw.endFloatAttributes();
            }

            //bl
            if (hasTextureSlot) {
                draw.putPosAndTextureSlot(
                    matTX + matC * h,
                    matTY + matD * h,
                    z,
                    textureSlot
                );
            }
            else {
                draw.putPos(
                    matTX + matC * h,
                    matTY + matD * h,
                    z
                );
            }
            if (hasCustomAttributes) {
                draw.beginFloatAttributes();
                #if ceramic_quad_float_attributes
                if (floatAttributes != null) {
                    var floatAttributesLen = floatAttributes.length;
                    for (l in 0...customFloatAttributesSize) {
                        var attr = l < floatAttributesLen ? floatAttributes.unsafeGet(l) : 0.0;
                        draw.putFloatAttribute(l, attr);
                    }
                }
                else {
                    for (l in 0...customFloatAttributesSize) {
                        draw.putFloatAttribute(l, 0.0);
                    }
                }
                #else
                for (l in 0...customFloatAttributesSize) {
                    draw.putFloatAttribute(l, 0.0);
                }
                #end
                draw.endFloatAttributes();
            }

            //tl
            if (hasTextureSlot) {
                draw.putPosAndTextureSlot(
                    matTX,
                    matTY,
                    z,
                    textureSlot
                );
            }
            else {
                draw.putPos(
                    matTX,
                    matTY,
                    z
                );
            }
            if (hasCustomAttributes) {
                draw.beginFloatAttributes();
                #if ceramic_quad_float_attributes
                if (floatAttributes != null) {
                    var floatAttributesLen = floatAttributes.length;
                    for (l in 0...customFloatAttributesSize) {
                        var attr = l < floatAttributesLen ? floatAttributes.unsafeGet(l) : 0.0;
                        draw.putFloatAttribute(l, attr);
                    }
                }
                else {
                    for (l in 0...customFloatAttributesSize) {
                        draw.putFloatAttribute(l, 0.0);
                    }
                }
                #else
                for (l in 0...customFloatAttributesSize) {
                    draw.putFloatAttribute(l, 0.0);
                }
                #end
                draw.endFloatAttributes();
            }

            //tr
            if (hasTextureSlot) {
                draw.putPosAndTextureSlot(
                    matTX + matA * w,
                    matTY + matB * w,
                    z,
                    textureSlot
                );
            }
            else {
                draw.putPos(
                    matTX + matA * w,
                    matTY + matB * w,
                    z
                );
            }
            if (hasCustomAttributes) {
                draw.beginFloatAttributes();
                #if ceramic_quad_float_attributes
                if (floatAttributes != null) {
                    var floatAttributesLen = floatAttributes.length;
                    for (l in 0...customFloatAttributesSize) {
                        var attr = l < floatAttributesLen ? floatAttributes.unsafeGet(l) : 0.0;
                        draw.putFloatAttribute(l, attr);
                    }
                }
                else {
                    for (l in 0...customFloatAttributesSize) {
                        draw.putFloatAttribute(l, 0.0);
                    }
                }
                #else
                for (l in 0...customFloatAttributesSize) {
                    draw.putFloatAttribute(l, 0.0);
                }
                #end
                draw.endFloatAttributes();
            }

            #else

            //tl
            if (hasTextureSlot) {
                draw.putPosAndTextureSlot(
                    matTX,
                    matTY,
                    z,
                    textureSlot
                );
            }
            else {
                draw.putPos(
                    matTX,
                    matTY,
                    z
                );
            }
            if (hasCustomAttributes) {
                draw.beginFloatAttributes();
                #if ceramic_quad_float_attributes
                if (floatAttributes != null) {
                    var floatAttributesLen = floatAttributes.length;
                    for (l in 0...customFloatAttributesSize) {
                        var attr = l < floatAttributesLen ? floatAttributes.unsafeGet(l) : 0.0;
                        draw.putFloatAttribute(l, attr);
                    }
                }
                else {
                    for (l in 0...customFloatAttributesSize) {
                        draw.putFloatAttribute(l, 0.0);
                    }
                }
                #else
                for (l in 0...customFloatAttributesSize) {
                    draw.putFloatAttribute(l, 0.0);
                }
                #end
                draw.endFloatAttributes();
            }

            //tr
            if (hasTextureSlot) {
                draw.putPosAndTextureSlot(
                    matTX + matA * w,
                    matTY + matB * w,
                    z,
                    textureSlot
                );
            }
            else {
                draw.putPos(
                    matTX + matA * w,
                    matTY + matB * w,
                    z
                );
            }
            if (hasCustomAttributes) {
                draw.beginFloatAttributes();
                #if ceramic_quad_float_attributes
                if (floatAttributes != null) {
                    var floatAttributesLen = floatAttributes.length;
                    for (l in 0...customFloatAttributesSize) {
                        var attr = l < floatAttributesLen ? floatAttributes.unsafeGet(l) : 0.0;
                        draw.putFloatAttribute(l, attr);
                    }
                }
                else {
                    for (l in 0...customFloatAttributesSize) {
                        draw.putFloatAttribute(l, 0.0);
                    }
                }
                #else
                for (l in 0...customFloatAttributesSize) {
                    draw.putFloatAttribute(l, 0.0);
                }
                #end
                draw.endFloatAttributes();
            }

            //br
            var n8 = matTX + matA * w + matC * h;
            var n9 = matTY + matB * w + matD * h;

            if (hasTextureSlot) {
                draw.putPosAndTextureSlot(
                    n8,
                    n9,
                    z,
                    textureSlot
                );
            }
            else {
                draw.putPos(
                    n8,
                    n9,
                    z
                );
            }
            if (hasCustomAttributes) {
                draw.beginFloatAttributes();
                #if ceramic_quad_float_attributes
                if (floatAttributes != null) {
                    var floatAttributesLen = floatAttributes.length;
                    for (l in 0...customFloatAttributesSize) {
                        var attr = l < floatAttributesLen ? floatAttributes.unsafeGet(l) : 0.0;
                        draw.putFloatAttribute(l, attr);
                    }
                }
                else {
                    for (l in 0...customFloatAttributesSize) {
                        draw.putFloatAttribute(l, 0.0);
                    }
                }
                #else
                for (l in 0...customFloatAttributesSize) {
                    draw.putFloatAttribute(l, 0.0);
                }
                #end
                draw.endFloatAttributes();
            }

            //bl
            if (hasTextureSlot) {
                draw.putPosAndTextureSlot(
                    matTX + matC * h,
                    matTY + matD * h,
                    z,
                    textureSlot
                );
            }
            else {
                draw.putPos(
                    matTX + matC * h,
                    matTY + matD * h,
                    z
                );
            }
            if (hasCustomAttributes) {
                draw.beginFloatAttributes();
                #if ceramic_quad_float_attributes
                if (floatAttributes != null) {
                    var floatAttributesLen = floatAttributes.length;
                    for (l in 0...customFloatAttributesSize) {
                        var attr = l < floatAttributesLen ? floatAttributes.unsafeGet(l) : 0.0;
                        draw.putFloatAttribute(l, attr);
                    }
                }
                else {
                    for (l in 0...customFloatAttributesSize) {
                        draw.putFloatAttribute(l, 0.0);
                    }
                }
                #else
                for (l in 0...customFloatAttributesSize) {
                    draw.putFloatAttribute(l, 0.0);
                }
                #end
                draw.endFloatAttributes();
            }

            #end


            #if ceramic_wireframe
            if (lastWireframe) {
                draw.putIndice(numPos);
                draw.putIndice(numPos + 1);
                draw.putIndice(numPos + 1);
                draw.putIndice(numPos + 2);
                draw.putIndice(numPos + 2);
                draw.putIndice(numPos);
                draw.putIndice(numPos);
                draw.putIndice(numPos + 2);
                draw.putIndice(numPos + 2);
                draw.putIndice(numPos + 3);
                draw.putIndice(numPos + 3);
                draw.putIndice(numPos);
            }
            else {
                draw.putIndice(numPos);
                draw.putIndice(numPos + 1);
                draw.putIndice(numPos + 2);
                draw.putIndice(numPos);
                draw.putIndice(numPos + 2);
                draw.putIndice(numPos + 3);
            }
            #else
            draw.putIndice(numPos);
            draw.putIndice(numPos + 1);
            draw.putIndice(numPos + 2);
            draw.putIndice(numPos);
            draw.putIndice(numPos + 2);
            draw.putIndice(numPos + 3);
            #end

        }

        // Position
        if (customFloatAttributesSize == 0) {
            if (textureSlot != -1) {
                batchQuadVertices(false, true);
            }
            else {
                batchQuadVertices(false, false);
            }
        }
        else {
            if (textureSlot != -1) {
                batchQuadVertices(true, true);
            }
            else {
                batchQuadVertices(true, false);
            }
        }

        // Colors
        //
        var r:Float;
        var g:Float;
        var b:Float;
        var a:Float;

        if (stencilClip) {
            a = 1;
            r = 1;
            g = 0;
            b = 0;
        }
        else if (lastComputedBlending == ceramic.Blending.ALPHA) {
            a = quad.computedAlpha;
            r = quad.color.redFloat;
            g = quad.color.greenFloat;
            b = quad.color.blueFloat;
            if (quad.blending == ceramic.Blending.ADD && lastComputedBlending != ceramic.Blending.ADD) a = 0;
        }
        else {
            a = quad.computedAlpha;
            r = quad.color.redFloat * a;
            g = quad.color.greenFloat * a;
            b = quad.color.blueFloat * a;
            if (quad.blending == ceramic.Blending.ADD && lastComputedBlending != ceramic.Blending.ADD) a = 0;
        }

        var i = 0;
        while (i < 4) {
            draw.putColor(r, g, b, a);
            i++;
        }

        var uvX:Float = 0;
        var uvY:Float = 0;
        var uvW:Float = 0;
        var uvH:Float = 0;

        if (quad.texture != null) {

            var texWidthActual = this.texWidthActual;
            var texHeightActual = this.texHeightActual;
            var texDensity = quad.texture.density;

            // UV
            //
            uvX = (quad.frameX * texDensity) / texWidthActual;
            uvY = (quad.frameY * texDensity) / texHeightActual;

            if (quad.rotateFrame) {

                uvW = (quad.frameHeight * texDensity) / texWidthActual;
                uvH = (quad.frameWidth * texDensity) / texHeightActual;

                #if !ceramic_render_no_flip_quad_vertices
                //br
                draw.putUVs(uvX + uvW, uvY);
                //bl
                draw.putUVs(uvX + uvW, uvY + uvH);
                //tl
                draw.putUVs(uvX, uvY + uvH);
                //tr
                draw.putUVs(uvX, uvY);
                #else
                //tl
                draw.putUVs(uvX, uvY + uvH);
                //tr
                draw.putUVs(uvX, uvY);
                //br
                draw.putUVs(uvX + uvW, uvY);
                //bl
                draw.putUVs(uvX + uvW, uvY + uvH);
                #end
            }
            else {

                uvW = (quad.frameWidth * texDensity) / texWidthActual;
                uvH = (quad.frameHeight * texDensity) / texHeightActual;

                #if !ceramic_render_no_flip_quad_vertices
                //br
                draw.putUVs(uvX + uvW, uvY + uvH);
                //bl
                draw.putUVs(uvX, uvY + uvH);
                //tl
                draw.putUVs(uvX, uvY);
                //tr
                draw.putUVs(uvX + uvW, uvY);
                #else
                //tl
                draw.putUVs(uvX, uvY);
                //tr
                draw.putUVs(uvX + uvW, uvY);
                //br
                draw.putUVs(uvX + uvW, uvY + uvH);
                //bl
                draw.putUVs(uvX, uvY + uvH);
                #end
            }

        } else {
            draw.putUVs(0, 0);
            draw.putUVs(0, 0);
            draw.putUVs(0, 0);
            draw.putUVs(0, 0);
        }

        // Let backend know we did finish sending quad data
        draw.endDrawQuad();

        // Increase counts
        this.z = z + 0.001;

    }

#if !ceramic_no_mesh
    /**
     * Draws a mesh with arbitrary vertices and triangles.
     * 
     * More flexible than drawQuad but with similar optimizations:
     * - Vertex buffer management
     * - Color mapping (per-mesh, per-triangle, or per-vertex)
     * - Custom vertex attributes
     * - Large mesh splitting across multiple draw calls
     * 
     * @param draw Backend draw interface
     * @param mesh The mesh visual to render
     */
    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function drawMesh(draw:backend.Draw, mesh:ceramic.Mesh):Void {

    #if ceramic_debug_draw
        drawnMeshes++;
    #end
        // The following code is doing pretty much the same thing as quads, but for meshes.
        // We could try to refactor to prevent redundancy but this is not required as our
        // main concern here is raw performance and anyway this code won't be updated often.

        inline function flushAndCleanState() {

            flush(draw);
            unbindUsedTextures(draw);

            // Update texture
            lastTexture = mesh.texture;

    #if ceramic_wireframe
            lastWireframe = mesh.wireframe;
            if (lastWireframe) {
                lastTexture = null;
                draw.setPrimitiveType(LINE);
            }
            else {
                draw.setPrimitiveType(TRIANGLE);
            }
    #end

            useFirstTextureInBatch(draw, lastTexture);

            // Update render target
            if (mesh.computedRenderTarget != lastRenderTarget) {
                lastRenderTarget = mesh.computedRenderTarget;
                useRenderTarget(draw, lastRenderTarget);
                if (lastClip != null && lastClipIsRegular) {
                    scissorWithQuad(draw, lastClip.asQuad);
                }
            }

            // Update shader
            lastShader = mesh.shader;
            useShader(draw, lastShader != null ? lastShader.backendItem : null);

            // Update blending
            lastComputedBlending = computeMeshBlending(mesh);
            useBlending(draw, lastComputedBlending);

            stateDirty = false;

        }

        if (stencilClip) {
            // Special case of drawing into stencil buffer

            // No texture
            unbindUsedTextures(draw);
            useFirstTextureInBatch(draw, null);

            // Default blending
            draw.setBlendFuncSeparate(
                backend.BlendMode.ONE,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA,
                backend.BlendMode.ONE,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA
            );
            lastComputedBlending = ceramic.Blending.PREMULTIPLIED_ALPHA;

            // No render target when writing to stencil buffer
            lastRenderTarget = mesh.computedRenderTarget;
            useRenderTarget(draw, lastRenderTarget);

            // Use default shader
            lastShader = null;
            useShader(draw, null);

            stateDirty = false;
        }
        else {
            // Check if state is dirty
            var textureToUseInSameBatch = null;
            var needsCheckRenderTextureClear = true;
            if (!stateDirty) {
                var newComputedBlending = computeMeshBlending(mesh);
                stateDirty =
                    !isSameShader(mesh.shader, lastShader) ||
                    newComputedBlending != lastComputedBlending ||
    #if ceramic_wireframe
                    mesh.wireframe != lastWireframe ||
    #end
                    mesh.computedRenderTarget != lastRenderTarget;
    #if ceramic_debug_draw_flush_reason
                if (debugDraw && stateDirty) {
                    if (!isSameShader(mesh.shader, lastShader))
                        log.debug('- dirty: shader');
                    if (newComputedBlending != lastComputedBlending)
                        log.debug('- dirty: blending $lastComputedBlending -> $newComputedBlending');
                    if (mesh.computedRenderTarget != lastRenderTarget)
                        log.debug('- dirty: render target');
                }
    #end
                if (!stateDirty) {
                    if (mesh.texture != lastTexture) {
                        if (mesh.texture != null && lastTexture != null) {
                            // Different ceramic textures could use the same backend texture
                            if (!draw.textureBackendItemMatchesId(mesh.texture.backendItem, lastTextureId)) {
                                // We could use multiple texture in same batch
                                if (!canUseTextureInSameBatch(draw, mesh.texture)) {
    #if ceramic_debug_draw_flush_reason
                                    if (debugDraw) {
                                        log.debug('- dirty: texture not matching');
                                    }
    #end
                                    stateDirty = true;
                                }
                                else {
                                    textureToUseInSameBatch = mesh.texture;
                                }
                            }
                        } else {
                            // We could use multiple texture in same batch
                            if (!canUseTextureInSameBatch(draw, mesh.texture)) {
    #if ceramic_debug_draw_flush_reason
                                if (debugDraw) {
                                    log.debug('- dirty: texture not matching');
                                }
    #end
                                stateDirty = true;
                            }
                            else {
                                textureToUseInSameBatch = mesh.texture != null ? mesh.texture : defaultWhiteTexture;
                            }
                        }
                    }
                }
            }

            if (stateDirty) {
                flushAndCleanState();
            }
            else {
                if (textureToUseInSameBatch != null) {
                    useTextureInSameBatch(draw, textureToUseInSameBatch);
                }
            }
        }

        // Fetch matrix
        //
        var matA:Float = mesh.matA;
        var matB:Float = mesh.matB;
        var matC:Float = mesh.matC;
        var matD:Float = mesh.matD;
        var matTX:Float = mesh.matTX;
        var matTY:Float = mesh.matTY;
        var z:Float = this.z;
        var textureSlot:Float = activeShaderCanBatchMultipleTextures ? activeTextureSlot : -1;

    #if ceramic_debug_draw
        if (debugDraw && #if ceramic_debug_draw_all true #elseif ceramic_debug_multitexture activeShaderCanBatchMultipleTextures #else mesh.id != null #end) {
            log.warning('* drawMesh(${mesh.id != null ? mesh.id : ''}) slot=$textureSlot texture=${lastTexture} stencil=$stencilClip clip=$lastClip');
        }
    #end

        // Color
        var meshColors = mesh.colors;
        var meshFloatColors = mesh.floatColors;
        var meshSingleColor = stencilClip || mesh.colorMapping == MESH;
        var meshIndicesColor = !stencilClip && mesh.colorMapping == INDICES;

        // Data
        var meshUvs = mesh.uvs;
        var meshVertices = mesh.vertices;
        var meshIndices = mesh.indices;

        // Let backend know we will start sending mesh data
        draw.beginDrawMesh(mesh); // TODO pass mesh info

    #if (debug || ceramic_debug_mesh_colors)
        if (meshFloatColors != null) {
            if (meshSingleColor && meshFloatColors.length < 4) {
                log.error('Trying to draw mesh $mesh with a single color but floatColors array is too short. It must have at least 4 elements, current is ${meshFloatColors.length} (RGBA)' #if ceramic_debug_entity_allocs , @:privateAccess mesh.posInfos #end);
            }
            else if (meshIndicesColor && meshFloatColors.length < meshIndices.length * 4) {
                log.error('Trying to draw mesh $mesh with indices colors but floatColors array is too short. It must have at least ${meshIndices.length * 4} elements, current is ${meshFloatColors.length} (RGBA)' #if ceramic_debug_entity_allocs , @:privateAccess mesh.posInfos #end);
            }
            else if (!meshSingleColor && !meshIndicesColor && meshFloatColors.length < Math.round(meshVertices.length / (2 + customFloatAttributesSize))) {
                log.error('Trying to draw mesh $mesh with vertices colors but floatColors array is too short. It must have at least ${Math.round(meshVertices.length / (2 + customFloatAttributesSize))} elements, current is ${meshFloatColors.length} (RGBA)' #if ceramic_debug_entity_allocs , @:privateAccess mesh.posInfos #end);
            }
        }
        else if (meshColors != null) {
            if (meshSingleColor && meshColors.length < 1) {
                log.error('Trying to draw mesh $mesh with a single color but colors array is too short. Add at least 1 element or assign a valid color' #if ceramic_debug_entity_allocs , @:privateAccess mesh.posInfos #end);
            }
            else if (meshIndicesColor && meshColors.length < meshIndices.length) {
                log.error('Trying to draw mesh $mesh with indices colors but colors array is too short. It must have at least ${meshIndices.length} elements' #if ceramic_debug_entity_allocs , @:privateAccess mesh.posInfos #end);
            }
            else if (!meshSingleColor && !meshIndicesColor && meshColors.length < Math.round(meshVertices.length / (2 + customFloatAttributesSize))) {
                log.error('Trying to draw mesh $mesh with vertices colors but colors array is too short. It must have at least ${Math.round(meshVertices.length / (2 + customFloatAttributesSize))} elements' #if ceramic_debug_entity_allocs , @:privateAccess mesh.posInfos #end);
            }
        }
        else {
            log.error('Trying to draw mesh $mesh with no colors. Either set mesh.color, mesh.colors or mesh.floatColors' #if ceramic_debug_entity_allocs , @:privateAccess mesh.posInfos #end);
        }
    #end

    #if ceramic_wireframe
        if (lastWireframe) {
            meshIndices = mesh.wireframeIndices;
            if (meshIndices == null) {
                meshIndices = [];
                mesh.wireframeIndices = meshIndices;
            }
            if (meshIndicesColor) {
                meshColors = mesh.wireframeColors;
                if (meshColors == null) {
                    meshColors = [];
                    mesh.wireframeColors = meshColors;
                }
            }
            var i = 0;
            var n = 0;
            while (i < mesh.indices.length) {
                meshIndices[n] = mesh.indices[i];
                n++;
                meshIndices[n] = mesh.indices[i+1];
                n++;
                meshIndices[n] = mesh.indices[i+1];
                n++;
                meshIndices[n] = mesh.indices[i+2];
                n++;
                meshIndices[n] = mesh.indices[i+2];
                n++;
                meshIndices[n] = mesh.indices[i];
                n++;
                if (meshIndicesColor) {
                    n -= 6;
                    meshColors[n] = mesh.colors[i];
                    n++;
                    meshColors[n] = mesh.colors[i+1];
                    n++;
                    meshColors[n] = mesh.colors[i+1];
                    n++;
                    meshColors[n] = mesh.colors[i+2];
                    n++;
                    meshColors[n] = mesh.colors[i+2];
                    n++;
                    meshColors[n] = mesh.colors[i];
                    n++;
                }
                i += 3;
            }
            if (meshIndices.length > n)
                meshIndices.setArrayLength(n);
        }
    #end

        // Update num vertices
        var visualNumVertices = meshIndices.length;
        //var posFloats = this.posFloats;
        //var uvFloats = this.uvFloats;
        //var posList = draw.getPosList();
        var customFloatAttributesSize = this.customFloatAttributesSize;
        var meshCustomFloatAttributesSize = mesh.customFloatAttributesSize;
        //var floatsPerVertex = (4 + customFloatAttributesSize);
        //var posFloatsAdd = visualNumVertices * floatsPerVertex;
        //var posFloatsAfter = posFloats + posFloatsAdd;
        //var uvFloatsAfter = uvFloats + visualNumVertices * 4;
        var startVertices = 0;
        var meshDrawsRenderTexture:Bool = mesh.texture != null && mesh.texture.isRenderTexture;
        var endVertices = visualNumVertices;
        // Divide and multiply by 3 (a triangle has 3 vertices, we want to split between 2 triangles)
        //var maxVertices = Std.int((maxVertFloats / floatsPerVertex) / 3) * 3;

        // Submit the current batch if we exceed the max buffer size
        if (draw.shouldFlush(visualNumVertices, visualNumVertices, customFloatAttributesSize)) {//posFloatsAfter > maxVertFloats || uvFloatsAfter > maxVertFloats) {
            flushAndCleanState();
            textureSlot = activeShaderCanBatchMultipleTextures ? activeTextureSlot : -1;

            // Check that our mesh is still not too large
            if (visualNumVertices > draw.remainingVertices() || visualNumVertices > draw.remainingIndices()) {
                endVertices = Std.int(Math.min(draw.remainingVertices(), draw.remainingIndices()));
                #if ceramic_wireframe
                endVertices = lastWireframe ? Std.int(endVertices / 6) * 6 : Std.int(endVertices / 3) * 3;
                #else
                endVertices = Std.int(endVertices / 3) * 3;
                #end
            }
        }

        // Actual texture size may differ from its logical one.
        // Keep factor values to generate UV mapping that matches the real texture.
        var texture = mesh.texture;
        var uvFactorX:Float = 0;
        var uvFactorY:Float = 0;
        if (texture != null) {
            uvFactorX = texWidth / texWidthActual;
            uvFactorY = texHeight / texHeightActual;
        }

        //var uvList = draw.getUvList();
        //var colorList = draw.getColorList();

        inline function batchMeshVertices() {

            // We may run this code multiple times if the mesh
            // needs to be splitted into multiple draw calls.
            // That is why it is inside a `while` block
            // Exit condition is at the end.
            while (true) {

                //var colorFloats = this.colorFloats;

                var a:Float = 0;
                var r:Float = 0;
                var g:Float = 0;
                var b:Float = 0;

                // Single color
                //
                if (meshSingleColor) {

                    if (stencilClip) {
                        a = 1;
                        r = 1;
                        g = 0;
                        b = 0;
                    }
                    else {
                        if (meshFloatColors != null) {
                            a = mesh.computedAlpha * meshFloatColors[3];
                            r = meshFloatColors[0];
                            g = meshFloatColors[1];
                            b = meshFloatColors[2];
                            if (mesh.blending == ceramic.Blending.ADD && lastComputedBlending != ceramic.Blending.ADD) a = 0;
                        }
                        else if (lastComputedBlending == ceramic.Blending.ALPHA) {
                            var meshAlphaColor = meshColors.unsafeGet(0);
                            a = mesh.computedAlpha * meshAlphaColor.alphaFloat;
                            r = meshAlphaColor.redFloat;
                            g = meshAlphaColor.greenFloat;
                            b = meshAlphaColor.blueFloat;
                            if (mesh.blending == ceramic.Blending.ADD && lastComputedBlending != ceramic.Blending.ADD) a = 0;
                        }
                        else {
                            var meshAlphaColor = meshColors.unsafeGet(0);
                            a = mesh.computedAlpha * meshAlphaColor.alphaFloat;
                            r = meshAlphaColor.redFloat * a;
                            g = meshAlphaColor.greenFloat * a;
                            b = meshAlphaColor.blueFloat * a;
                            if (mesh.blending == ceramic.Blending.ADD && lastComputedBlending != ceramic.Blending.ADD) a = 0;
                        }
                    }
                }

                var i = startVertices;
                var numPos = draw.getNumPos();
                while (i < endVertices) {

                    var j = meshIndices.unsafeGet(i);
                    var k = j * 2;
                    var l = j * (2 + meshCustomFloatAttributesSize);

                    // Position
                    //
                    var x = meshVertices.unsafeGet(l++);
                    var y = meshVertices.unsafeGet(l++);

                    draw.putIndice(numPos);
                    numPos++;

                    if (textureSlot != -1) {
                        draw.putPosAndTextureSlot(
                            matTX + matA * x + matC * y,
                            matTY + matB * x + matD * y,
                            z,
                            textureSlot
                        );
                    }
                    else {
                        draw.putPos(
                            matTX + matA * x + matC * y,
                            matTY + matB * x + matD * y,
                            z
                        );
                    }

                    //draw.putInPosList(posList, posFloats, 0);

                    // Color
                    //
                    if (!meshSingleColor) {
                        if (meshFloatColors != null) {
                            var floatColorIndex = (meshIndicesColor ? i : j) * 4;

                            if (meshDrawsRenderTexture || lastComputedBlending == ceramic.Blending.ALPHA) {
                                a = mesh.computedAlpha * meshFloatColors[floatColorIndex+3];
                                r = meshFloatColors[floatColorIndex];
                                g = meshFloatColors[floatColorIndex+1];
                                b = meshFloatColors[floatColorIndex+2];
                                if (mesh.blending == ceramic.Blending.ADD && lastComputedBlending != ceramic.Blending.ADD) a = 0;
                            }
                            else {
                                a = mesh.computedAlpha * meshFloatColors[floatColorIndex+3];
                                r = meshFloatColors[floatColorIndex] * a;
                                g = meshFloatColors[floatColorIndex+1] * a;
                                b = meshFloatColors[floatColorIndex+2] * a;
                                if (mesh.blending == ceramic.Blending.ADD && lastComputedBlending != ceramic.Blending.ADD) a = 0;
                            }
                        }
                        else {
                            var meshAlphaColor:AlphaColor = meshIndicesColor ? meshColors.unsafeGet(i) : meshColors.unsafeGet(j);

                            if (meshDrawsRenderTexture || lastComputedBlending == ceramic.Blending.ALPHA) {
                                a = mesh.computedAlpha * meshAlphaColor.alphaFloat;
                                r = meshAlphaColor.redFloat;
                                g = meshAlphaColor.greenFloat;
                                b = meshAlphaColor.blueFloat;
                                if (mesh.blending == ceramic.Blending.ADD && lastComputedBlending != ceramic.Blending.ADD) a = 0;
                            }
                            else {
                                a = mesh.computedAlpha * meshAlphaColor.alphaFloat;
                                r = meshAlphaColor.redFloat * a;
                                g = meshAlphaColor.greenFloat * a;
                                b = meshAlphaColor.blueFloat * a;
                                if (mesh.blending == ceramic.Blending.ADD && lastComputedBlending != ceramic.Blending.ADD) a = 0;
                            }
                        }
                    }
                    draw.putColor(r, g, b, a);

                    // UV
                    //
                    if (texture != null) {
                        var uvX:Float = meshUvs.unsafeGet(k) * uvFactorX;
                        var uvY:Float = meshUvs.unsafeGet(k + 1) * uvFactorY;
                        draw.putUVs(uvX, uvY);
                    }
                    else {
                        draw.putUVs(0, 0);
                    }

                    // Custom (float) attributes
                    //
                    if (customFloatAttributesSize != 0) {
                        draw.beginFloatAttributes();
                        for (n in 0...customFloatAttributesSize) {
                            if (n < meshCustomFloatAttributesSize) {
                                draw.putFloatAttribute(n, meshVertices.unsafeGet(l++));
                            }
                            else {
                                draw.putFloatAttribute(n, 0.0);
                            }
                        }
                        draw.endFloatAttributes();
                    }

                    i++;
                }

                if (endVertices == visualNumVertices) {
                    // No need to submit more data, exit loop
                    break;
                }
                else {

                    // There is still data left that needs to be submitted.
                    // Flush pending buffers and iterate once more.

                    flushAndCleanState();
                    textureSlot = activeShaderCanBatchMultipleTextures ? activeTextureSlot : -1;

                    startVertices = endVertices;
                    endVertices = startVertices + Std.int(Math.min(draw.remainingVertices(), draw.remainingIndices()));
                    #if ceramic_wireframe
                    endVertices = lastWireframe ? Std.int(endVertices / 6) * 6 : Std.int(endVertices / 3) * 3;
                    #else
                    endVertices = Std.int(endVertices / 3) * 3;
                    #end
                    if (endVertices > visualNumVertices) {
                        endVertices = visualNumVertices;
                    }
                }

            }

        }

        batchMeshVertices();

        // Let backend know we did finish sending mesh data
        draw.endDrawMesh();

        // Increase counts
        this.z = z + 0.001;

    }
#end

    /**
     * Flushes pending draw commands to the GPU.
     * 
     * Called when:
     * - Render state changes (texture, shader, blend mode)
     * - Buffer capacity is reached
     * - Rendering is complete
     * 
     * @param draw Backend draw interface
     * @return True if anything was flushed
     */
    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function flush(draw:backend.Draw):Bool {

        if (!draw.hasAnythingToFlush()) {
            return false;
        }

        draw.flush();
        drawCalls++;

    #if ceramic_debug_draw
        var flushingQuadsNow = drawnQuads - flushedQuads;
        var flushingMeshesNow = drawnMeshes - flushedMeshes;
        if (debugDraw) {
            log.info('flush - #$drawCalls(${flushingQuadsNow + flushingMeshesNow}) / $lastTexture / $lastShader / $lastRenderTarget / $lastComputedBlending / $lastClip');
        }
        flushedQuads = drawnQuads;
        flushedMeshes = drawnMeshes;
    #end

        return true;

    }

    /**
     * Computes the actual blending mode for a quad.
     * 
     * Resolves AUTO blending based on render target:
     * - Regular rendering: PREMULTIPLIED_ALPHA
     * - Render-to-texture: RENDER_TO_TEXTURE
     * 
     * @param quad The quad to compute blending for
     * @return The resolved blending mode
     */
    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function computeQuadBlending(quad:ceramic.Quad):ceramic.Blending {

        var blending = quad.blending;

        /*if (blending == ceramic.Blending.PREMULTIPLIED_ALPHA) {
            // Keep explicit blending
        }*/
        /*if (blending == ceramic.Blending.AUTO && quad.texture != null && quad.texture.isRenderTexture) {
            if (quad.computedRenderTarget != null) {
                blending = ceramic.Blending.RENDER_TO_TEXTURE_ALPHA;
            }
            else {
                blending = ceramic.Blending.ALPHA;
            }
        }
        else*/ if (blending == ceramic.Blending.AUTO || blending == ceramic.Blending.ADD) {
            if (quad.computedRenderTarget != null) {
                blending = ceramic.Blending.RENDER_TO_TEXTURE;
            }
            else {
                blending = ceramic.Blending.PREMULTIPLIED_ALPHA;
            }
        }

        return blending;

    }

    /**
     * Computes the actual blending mode for a mesh.
     * 
     * Similar to computeQuadBlending but for mesh visuals.
     * 
     * @param mesh The mesh to compute blending for
     * @return The resolved blending mode
     */
    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function computeMeshBlending(mesh:ceramic.Mesh):ceramic.Blending {

        var blending = mesh.blending;

        /*
        if (blending == ceramic.Blending.PREMULTIPLIED_ALPHA) {
            // Keep explicit blending
        }
        else if (blending == ceramic.Blending.AUTO && mesh.texture != null && mesh.texture.isRenderTexture) {
            blending = ceramic.Blending.ALPHA;
        }
        else if (blending == ceramic.Blending.ADD && (mesh.texture == null || !mesh.texture.isRenderTexture)) {
            blending = ceramic.Blending.PREMULTIPLIED_ALPHA;
        }
        */
        /*if (blending == ceramic.Blending.AUTO && mesh.texture != null && mesh.texture.isRenderTexture) {
            if (mesh.computedRenderTarget != null) {
                blending = ceramic.Blending.RENDER_TO_TEXTURE_ALPHA;
            }
            else {
                blending = ceramic.Blending.ALPHA;
            }
        }
        else*/ if (blending == ceramic.Blending.AUTO || blending == ceramic.Blending.ADD) {
            if (mesh.computedRenderTarget != null) {
                blending = ceramic.Blending.RENDER_TO_TEXTURE;
            }
            else {
                blending = ceramic.Blending.PREMULTIPLIED_ALPHA;
            }
        }

        return blending;

    }

    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function isSameShader(shaderA:ceramic.Shader, shaderB:ceramic.Shader):Bool {

        var backendItemA = shaderA != null ? shaderA.backendItem : defaultTexturedShader;
        var backendItemB = shaderB != null ? shaderB.backendItem : defaultTexturedShader;

        return backendItemA == backendItemB;

    }

    /**
     * Activates a shader program for subsequent draw calls.
     * 
     * Updates:
     * - Active shader state
     * - Multi-texture capability flags
     * - Custom attribute configuration
     * 
     * @param draw Backend draw interface
     * @param shader Backend shader to activate (null for default)
     */
    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function useShader(draw:backend.Draw, shader:backend.Shader):Void {

        #if ceramic_debug_draw_shader_use
        if (debugDraw) {
            log.debug('(use shader $shader)');
        }
        #end

        if (shader == null) {
            shader = defaultTexturedShader;
        }

        //if (activeShader != shader) {
            activeShader = shader;
            draw.useShader(shader);
            activeShaderCanBatchMultipleTextures = backendShaders.canBatchWithMultipleTextures(shader);
            customFloatAttributesSize = backendShaders.customFloatAttributesSize(shader);
        //}

    }

    /**
     * Configures GPU blending mode for transparency and compositing.
     * 
     * Supports various blend modes:
     * - PREMULTIPLIED_ALPHA: Standard alpha blending
     * - ADD: Additive blending for light effects
     * - ALPHA: Non-premultiplied alpha
     * - RENDER_TO_TEXTURE: Special mode for render targets
     * 
     * @param draw Backend draw interface
     * @param blending The blending mode to apply
     */
    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function useBlending(draw:backend.Draw, blending:ceramic.Blending):Void {

        #if ceramic_debug_draw_blending_use
        if (debugDraw) {
            log.debug('(use blending $blending)');
        }
        #end

        switch blending {
            case PREMULTIPLIED_ALPHA:
                draw.setBlendFuncSeparate(
                    backend.BlendMode.ONE,
                    backend.BlendMode.ONE_MINUS_SRC_ALPHA,
                    backend.BlendMode.ONE,
                    backend.BlendMode.ONE_MINUS_SRC_ALPHA
                );
            case ADD:
                draw.setBlendFuncSeparate(
                    backend.BlendMode.ONE,
                    backend.BlendMode.ONE,
                    backend.BlendMode.ONE,
                    backend.BlendMode.ONE
                );
            case SET:
                draw.setBlendFuncSeparate(
                    backend.BlendMode.ONE,
                    backend.BlendMode.SRC_ALPHA,
                    backend.BlendMode.ONE,
                    backend.BlendMode.SRC_ALPHA
                );
            case RENDER_TO_TEXTURE:
                draw.setBlendFuncSeparate(
                    backend.BlendMode.ONE,
                    backend.BlendMode.ONE_MINUS_SRC_ALPHA,
                    backend.BlendMode.ONE_MINUS_DST_ALPHA,
                    backend.BlendMode.ONE
                );
            case RENDER_TO_TEXTURE_ALPHA:
                draw.setBlendFuncSeparate(
                    backend.BlendMode.SRC_ALPHA,
                    backend.BlendMode.ONE_MINUS_SRC_ALPHA,
                    backend.BlendMode.ONE_MINUS_DST_ALPHA,
                    backend.BlendMode.ONE
                );
            case ALPHA:
                draw.setBlendFuncSeparate(
                    backend.BlendMode.SRC_ALPHA,
                    backend.BlendMode.ONE_MINUS_SRC_ALPHA,
                    backend.BlendMode.ONE,
                    backend.BlendMode.ONE_MINUS_SRC_ALPHA
                );
            case AUTO:
                throw 'Cannot apply AUTO blending. Needs to be computed to an actual blending function.';
        }

    }

    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function scissorWithQuad(draw:backend.Draw, quad:ceramic.Quad):Void {

        draw.enableScissor(
            quad.matTX,
            quad.matTY,
            quad.matA * quad.width,
            quad.matD * quad.height
        );

    }

    inline function isNotRenderedRenderTexture(texture:ceramic.Texture):Bool {

        var renderTexture = texture.asRenderTexture;
        return (renderTexture != null && !renderTexture._renderedOnce && renderTexture.renderDirty && !renderTexture._usedInRendering);

    }

    /**
     * Sets the render target for subsequent draw calls.
     * 
     * @param draw Backend draw interface
     * @param renderTarget Texture to render to (null for screen)
     */
    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function useRenderTarget(draw:backend.Draw, renderTarget:ceramic.RenderTexture):Void {

        usedRenderTarget = renderTarget;
        if (renderTarget != null) {
            renderTarget._usedInRendering = true;
            renderTarget._renderedOnce = true;
            draw.setRenderTarget(renderTarget);
        }
        else {
            draw.setRenderTarget(null);
        }

    }

    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function useFirstTextureInBatch(draw:backend.Draw, texture:ceramic.Texture):Void {

        //if (texture != null) {
            if (texture == null) {
                texture = defaultWhiteTexture;
            }
            usedTextures = 1;
            var textureIndex = backendTextures.getTextureIndex(texture.backendItem);
            usedTextureIndexes.unsafeSet(0, textureIndex);
            draw.setActiveTexture(0);
            activeTextureSlot = 0;
            useTexture(draw, texture, false);
        /*}
        else {
            usedTextures = 0;
            draw.setActiveTexture(0);
            activeTextureSlot = 0;
            useTexture(draw, null);
        }*/

    }

    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function useTexture(draw:backend.Draw, texture:ceramic.Texture, reusing:Bool):Void {

        if (texture != null) {
    #if (ceramic_debug_draw && ceramic_debug_multitexture)
            if (debugDraw && activeShaderCanBatchMultipleTextures) {
                if (reusing) {
                    log.success('REUSE Texture(${draw.getActiveTexture()}) -> ${texture}');
                }
                else {
                    log.success('BIND Texture(${draw.getActiveTexture()}) -> ${texture}');
                }
            }
    #end
            lastTexture = texture;
            lastTextureId = draw.getTextureId(texture.backendItem);
            texWidth = draw.getTextureWidth(texture.backendItem);
            texHeight = draw.getTextureHeight(texture.backendItem);
            texWidthActual = draw.getTextureWidthActual(texture.backendItem);
            texHeightActual = draw.getTextureHeightActual(texture.backendItem);
            if (!reusing) {
                draw.bindTexture(texture.backendItem);
            }
        }
        else {
            lastTexture = null;
            lastTextureId = backend.TextureId.DEFAULT;
            draw.bindNoTexture();
        }

    }

    /**
     * Checks if a texture can be added to the current batch.
     * 
     * For multi-texture batching, checks if:
     * - Texture is already bound in a slot
     * - Free texture slots are available
     * 
     * @param draw Backend draw interface
     * @param texture Texture to check
     * @return True if batching can continue
     */
    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function canUseTextureInSameBatch(draw:backend.Draw, texture:ceramic.Texture):Bool {

        var canKeepSameState = false;

        if (texture == null) {
            texture = defaultWhiteTexture;
        }

        if (usedTextures > 0) {

            if (activeShaderCanBatchMultipleTextures) {

                var textureIndex = backendTextures.getTextureIndex(texture.backendItem);

                for (slot in 0...usedTextures) {
                    if (textureIndex == usedTextureIndexes.unsafeGet(slot)) {
                        // Texture already used in batch, all good
                        canKeepSameState = true;
                        break;
                    }
                }

                if (!canKeepSameState && usedTextures < maxUsableTexturesInBatch) {

                    canKeepSameState = true;
                }
            }
            else if (lastTexture == texture) {

                canKeepSameState = true;
            }
        }

        return canKeepSameState;

    }

    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function useTextureInSameBatch(draw:backend.Draw, texture:ceramic.Texture):Void {

        var alreadyUsed = false;

        if (texture == null) {
            texture = defaultWhiteTexture;
        }

        if (activeShaderCanBatchMultipleTextures) {

            var textureIndex = backendTextures.getTextureIndex(texture.backendItem);

            for (slot in 0...usedTextures) {
                if (textureIndex == usedTextureIndexes.unsafeGet(slot)) {
                    // Texture already used in batch, all good
                    draw.setActiveTexture(slot);
                    activeTextureSlot = slot;
                    useTexture(draw, texture, true);
                    alreadyUsed = true;
                    break;
                }
            }

            if (!alreadyUsed && usedTextures < maxUsableTexturesInBatch) {
                var slot = usedTextures++;
                usedTextureIndexes.unsafeSet(slot, textureIndex);
                draw.setActiveTexture(slot);
                activeTextureSlot = slot;
                useTexture(draw, texture, false);
            }
        }

    }

    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end function unbindUsedTextures(draw:backend.Draw):Void {

        while (usedTextures > 0) {
            usedTextures--;
            draw.setActiveTexture(usedTextures);
            draw.bindNoTexture();
        }
        draw.setActiveTexture(0);
        activeTextureSlot = 0;
        useTexture(draw, null, false);

    }

}
