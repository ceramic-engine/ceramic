package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/** An implementation-independant GPU 2D renderer.
    To be used in pair with a draw backend implementation. */
class Renderer extends Entity {

    public var maxVerts:Int = 16384;

    var posFloats:Int = 0;
    var uvFloats:Int = 0;
    var colorFloats:Int = 0;
    var normalFloats:Int = 0;

    var drawCalls:Int = 0;

    var activeShader:backend.Shader = null;
    var customFloatAttributesSize:Int = 0;

    var stencilClip:Bool = false;

    var lastTexture:ceramic.Texture = null;
    var lastTextureId:backend.TextureId = backend.TextureId.DEFAULT;
    var lastShader:ceramic.Shader = null;
    var lastRenderTarget:ceramic.RenderTexture = null;
    var lastComputedBlending:ceramic.Blending = ceramic.Blending.AUTO;
    var lastClip:ceramic.Visual = null;
    var activeTextureSlot:Int = 0;

    var texWidth:Int = 0;
    var texHeight:Int = 0;
    var texWidthActual:Int = 0;
    var texHeightActual:Int = 0;

    //var defaultPlainShader:backend.Shader = null;
    var defaultTexturedShader:backend.Shader = null;
    var defaultWhiteTexture:ceramic.Texture = null;

    var maxVertFloats:Int = 0;

    var quad:ceramic.Quad = null;
    var mesh:ceramic.Mesh = null;

    var stateDirty:Bool = true;

    var z:Float = 0;

    var usedTextureIndexes:Array<Int> = [];
    var usedTextures:Int = 0;
    var maxUsableTexturesInBatch:Int = -1;
    var activeShaderCanBatchMultipleTextures:Bool = false;

#if ceramic_debug_draw
    var lastDebugTime:Float = -1;
    var debugDraw:Bool = false;
    var drawnQuads:Int = 0;
    var drawnMeshes:Int = 0;
    var flushedQuads:Int = 0;
    var flushedMeshes:Int = 0;
#end

#if ceramic_debug_rendering_option
    var lastDebugRendering = ceramic.DebugRendering.DEFAULT;
#end

    public function new() {

        super();

    } //new

    public function render(isMainRender:Bool, ceramicVisuals:Array<Visual>):Void {

        var draw = app.backend.draw;

        //defaultPlainShader = ceramic.App.app.defaultColorShader.backendItem;
        defaultTexturedShader = ceramic.App.app.defaultTexturedShader.backendItem;
        defaultWhiteTexture = ceramic.App.app.defaultWhiteTexture;
        
        maxUsableTexturesInBatch = Std.int(Math.min(
            app.backend.textures.maxTexturesByBatch(),
            app.backend.shaders.maxIfStatementsByFragmentShader()
        ));

        #if ceramic_avoid_last_texture_slot
        if (maxUsableTexturesInBatch > 1) {
            // On some devices, we have problems if we use the last texture slot.
            // As a workaround, we avoid using it. I wish I could understand why.
            // That's sad. Very sad.
            maxUsableTexturesInBatch--;
        }
        #end

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

        posFloats = 0;
        uvFloats = 0;
        colorFloats = 0;
        normalFloats = 0;

        drawCalls = 0;

        maxVertFloats = maxVerts * 4;
        draw.initBuffers(maxVerts);

        quad = null;
        mesh = null;

        lastTexture = null;
        lastTextureId = backend.TextureId.DEFAULT;
        lastShader = null;
        lastRenderTarget = null;
        lastComputedBlending = ceramic.Blending.AUTO;
#if ceramic_debug_rendering_option
        lastDebugRendering = ceramic.DebugRendering.DEFAULT;
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
        var allRenderTextures = ceramic.App.app.renderTextures;
        for (ii in 0...allRenderTextures.length) {
            var renderTexture = allRenderTextures.unsafeGet(ii);
            if (renderTexture.autoRender) {
                renderTexture.renderDirty = true;
            }
        }

        draw.beginRender();

        // Initialize default state
        draw.setActiveTexture(0);
        activeTextureSlot = 0;
        draw.setRenderTarget(null, true);
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
                        if (visual.computedClip) {
                            // Get new clip and compare with last
                            var clippingVisual = visual;
                            while (clippingVisual != null && clippingVisual.clip == null) {
                                clippingVisual = clippingVisual.parent;
                            }
                            clip = clippingVisual != null ? clippingVisual.clip : null;

                        } else {
                            clip = null;
                        }

                        if (clip != lastClip) {

                            flush(draw);
                            unbindUsedTextures(draw);
                            stateDirty = true;

                            if (lastClip != null) {
                                lastRenderTarget = lastClip.computedRenderTarget;
                                useRenderTarget(draw, lastRenderTarget);

                                // Finish clipping
                                draw.drawWithoutStencilTest();
                            }

                            lastClip = clip;

                            if (lastClip != null) {
                                // Update stencil buffer
                                
                                lastRenderTarget = lastClip.computedRenderTarget;
                                useRenderTarget(draw, lastRenderTarget);

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
                                    drawMesh(draw, mesh);
                                    stencilClip = false;
                                    mesh = visual.asMesh;
                                }

                                // Next things to be drawn will be clipped
                                flush(draw);
                                unbindUsedTextures(draw);
                                stateDirty = true;

                                draw.endDrawingInStencilBuffer();
                                draw.drawWithStencilTest();
                            }
                        }

                        if (quad != null && !quad.transparent) {

                            drawQuad(draw, quad);

                        } //quad

                        else if (mesh != null) {

                            drawMesh(draw, mesh);

                        } //mesh
                    }
                }
            }

            flush(draw);
            unbindUsedTextures(draw);
            stateDirty = true;
        }

#if ceramic_debug_draw
        if (debugDraw) {
            log.success(' -- $drawCalls draw calls / $drawnQuads quads / $drawnMeshes meshes');
        }
#end

    } //render

    #if !ceramic_debug_draw inline #end function useShader(draw:backend.Draw, shader:backend.Shader):Void {

        if (shader == null) {
            shader = defaultTexturedShader;
        }

        //if (activeShader != shader) {
            activeShader = shader;
            draw.useShader(shader);
            activeShaderCanBatchMultipleTextures = app.backend.shaders.canBatchWithMultipleTextures(activeShader);
            customFloatAttributesSize = draw.shaderCustomFloatAttributesSize(shader);
        //}

    } //useShader

    #if !ceramic_debug_draw inline #end function useBlending(draw:backend.Draw, blending:ceramic.Blending):Void {

        #if ceramic_debug_draw
        if (debugDraw) {
            log.debug('(use blending $blending)');
        }
        #end

        switch blending {
            case AUTO | PREMULTIPLIED_ALPHA:
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
            case ALPHA:
                draw.setBlendFuncSeparate(
                    backend.BlendMode.SRC_ALPHA,
                    backend.BlendMode.ONE_MINUS_SRC_ALPHA,
                    backend.BlendMode.ONE,
                    backend.BlendMode.ONE_MINUS_SRC_ALPHA
                );
        }

        /*
        if (blending == ceramic.Blending.ADD) {
            draw.setBlendFuncSeparate(
                backend.BlendMode.ONE,
                backend.BlendMode.ONE,
                backend.BlendMode.ONE,
                backend.BlendMode.ONE
            );
        } else if (blending == ceramic.Blending.SET) {
            draw.setBlendFuncSeparate(
                backend.BlendMode.ONE,
                backend.BlendMode.SRC_ALPHA,
                backend.BlendMode.ONE,
                backend.BlendMode.SRC_ALPHA
            );
        } else if (blending == ceramic.Blending.AUTO) {
            draw.setBlendFuncSeparate(
                backend.BlendMode.ONE,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA,
                backend.BlendMode.ONE,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA
            );
        } else {
            draw.setBlendFuncSeparate(
                backend.BlendMode.SRC_ALPHA,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA,
                backend.BlendMode.ONE,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA
            );
        }
        */

    } //useBlending

    #if !ceramic_debug_draw inline #end function useRenderTarget(draw:backend.Draw, renderTarget:ceramic.RenderTexture):Void {

        if (renderTarget != null) {
            draw.setRenderTarget(renderTarget);
        }
        else {
            draw.setRenderTarget(null);
        }

    } //useRenderTarget

    #if !ceramic_debug_draw inline #end function useFirstTextureInBatch(draw:backend.Draw, texture:ceramic.Texture):Void {

        //if (texture != null) {
            if (texture == null) {
                texture = defaultWhiteTexture;
            }
            usedTextures = 1;
            var textureIndex = app.backend.textures.getTextureIndex(texture.backendItem);
            usedTextureIndexes[0] = textureIndex;
            draw.setActiveTexture(0);
            activeTextureSlot = 0;
            useTexture(draw, texture);
        /*}
        else {
            usedTextures = 0;
            draw.setActiveTexture(0);
            activeTextureSlot = 0;
            useTexture(draw, null);
        }*/

    } //useFirstTextureInBatch

    #if !ceramic_debug_draw inline #end function useTexture(draw:backend.Draw, texture:ceramic.Texture, reusing:Bool = false):Void {

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

    } //useTexture

    #if !ceramic_debug_draw inline #end function canUseTextureInSameBatch(draw:backend.Draw, texture:ceramic.Texture):Bool {

        var canKeepSameState = false;

        if (texture == null) {
            texture = defaultWhiteTexture;
        }

        if (usedTextures > 0) {
            if (activeShaderCanBatchMultipleTextures) {

                var textureIndex = app.backend.textures.getTextureIndex(texture.backendItem);

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
        }

        return canKeepSameState;

    } //canUseTextureInSameBatch

    #if !ceramic_debug_draw inline #end function useTextureInSameBatch(draw:backend.Draw, texture:ceramic.Texture):Void {

        var alreadyUsed = false;

        if (texture == null) {
            texture = defaultWhiteTexture;
        }

        if (activeShaderCanBatchMultipleTextures) {

            var textureIndex = app.backend.textures.getTextureIndex(texture.backendItem);

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
                usedTextureIndexes[slot] = textureIndex;
                draw.setActiveTexture(slot);
                activeTextureSlot = slot;
                useTexture(draw, texture);
            }
        }

    } //useTextureInSameBatch

    #if !ceramic_debug_draw inline #end function unbindUsedTextures(draw:backend.Draw):Void {

        while (usedTextures > 0) {
            usedTextures--;
            draw.setActiveTexture(usedTextures);
            draw.bindNoTexture();
        }
        draw.setActiveTexture(0);
        activeTextureSlot = 0;
        useTexture(draw, null);

    } //unbindUsedTextures

    #if !ceramic_debug_draw inline #end function drawQuad(draw:backend.Draw, quad:ceramic.Quad):Void {

#if ceramic_debug_draw
        drawnQuads++;
#end

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
            if (!stateDirty) {
                var newComputedBlending = computeQuadBlending(quad);
                stateDirty =
                    !isSameShader(quad.shader, lastShader) ||
                    newComputedBlending != lastComputedBlending ||
#if ceramic_debug_rendering_option
                    quad.debugRendering != lastDebugRendering ||
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
                                    stateDirty = true;
                                }
                                else {
                                    textureToUseInSameBatch = quad.texture;
                                }
                            }
                        } else {
                            // We could use multiple texture in same batch
                            if (!canUseTextureInSameBatch(draw, quad.texture)) {
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
                flush(draw);
                unbindUsedTextures(draw);

                // Update texture
                lastTexture = quad.texture;
                useFirstTextureInBatch(draw, lastTexture);

#if ceramic_debug_rendering_option
                lastDebugRendering = quad.debugRendering;
                draw.setRenderWireframe(lastDebugRendering == ceramic.DebugRendering.WIREFRAME);
#end

                // Update render target
                if (quad.computedRenderTarget != lastRenderTarget) {
                    lastRenderTarget = quad.computedRenderTarget;
                    useRenderTarget(draw, lastRenderTarget);
                }

                // Update shader
                lastShader = quad.shader;
                useShader(draw, lastShader != null ? lastShader.backendItem : null);

                // Update blending
                lastComputedBlending = computeQuadBlending(quad);
                useBlending(draw, lastComputedBlending);

                stateDirty = false;
            }
            else {
                if (textureToUseInSameBatch != null) {
                    useTextureInSameBatch(draw, textureToUseInSameBatch);
                }
            }
        }

        // Update num vertices
        var posFloats = this.posFloats;
        var customFloatAttributesSize = this.customFloatAttributesSize;
        var visualNumVertices = 6;
        var countAfter = posFloats + visualNumVertices * (4 + customFloatAttributesSize);

        // Submit the current batch if we exceed the max buffer size
        if (countAfter > maxVertFloats) {
            var textureBeforeFlush = lastTexture;
            flush(draw);
            unbindUsedTextures(draw);
            useFirstTextureInBatch(draw, textureBeforeFlush);
            posFloats = this.posFloats;
        }

        var w:Float;
        var h:Float;

        // Update size
        if (quad.rotateFrame == ceramic.RotateFrame.ROTATE_90) {
            w = quad.height;
            h = quad.width;
        } else {
            w = quad.width;
            h = quad.height;
        }

        // Fetch matrix
        //
        var matA:Float = quad.matA;
        var matB:Float = quad.matB;
        var matC:Float = quad.matC;
        var matD:Float = quad.matD;
        var matTX:Float = quad.matTX;
        var matTY:Float = quad.matTY;
        var z:Float = this.z;
        var posList = draw.getPosList();
        var textureSlot:Float = activeShaderCanBatchMultipleTextures ? activeTextureSlot : -1;
        var quadDrawsRenderTexture:Bool = quad.texture != null && quad.texture.isRenderTexture;

#if ceramic_debug_draw
        if (debugDraw && #if ceramic_debug_multitexture activeShaderCanBatchMultipleTextures #else quad.id != null #end) {
            log.warning('* drawQuad(${quad.id != null ? quad.id : ''}) slot=$textureSlot texture=${lastTexture} stencil=$stencilClip clip=$lastClip');
        }
#end

        // Let backend know we will start sending quad data
        draw.beginDrawQuad(quad);

        /** Using an inline internal function because we want to use similar code multiple times,
            and let haxe compiler evaluate `hasCustomAttributes` and `hasTextureSlot`
            at compile time. */
        inline function batchQuadVertices(hasCustomAttributes:Bool, hasTextureSlot:Bool) {

            //tl
            draw.putInPosList(posList, posFloats, matTX);
            posFloats++;
            draw.putInPosList(posList, posFloats, matTY);
            posFloats++;
            draw.putInPosList(posList, posFloats, z);
            posFloats++;
            if (hasTextureSlot) {
                draw.putInPosList(posList, posFloats, textureSlot);
                posFloats++;
            }
            if (hasCustomAttributes) {
                for (l in 0...customFloatAttributesSize) {
                    draw.putInPosList(posList, posFloats, 0.0);
                    posFloats++;
                }
            }

            //tr
            draw.putInPosList(posList, posFloats, matTX + matA * w);
            posFloats++;
            draw.putInPosList(posList, posFloats, matTY + matB * w);
            posFloats++;
            draw.putInPosList(posList, posFloats, z);
            posFloats++;
            if (hasTextureSlot) {
                draw.putInPosList(posList, posFloats, textureSlot);
                posFloats++;
            }
            if (hasCustomAttributes) {
                for (l in 0...customFloatAttributesSize) {
                    draw.putInPosList(posList, posFloats, 0.0);
                    posFloats++;
                }
            }

            //br
            var n8 = matTX + matA * w + matC * h;
            var n9 = matTY + matB * w + matD * h;

            draw.putInPosList(posList, posFloats, n8);
            posFloats++;
            draw.putInPosList(posList, posFloats, n9);
            posFloats++;
            draw.putInPosList(posList, posFloats, z);
            posFloats++;
            if (hasTextureSlot) {
                draw.putInPosList(posList, posFloats, textureSlot);
                posFloats++;
            }
            if (hasCustomAttributes) {
                for (l in 0...customFloatAttributesSize) {
                    draw.putInPosList(posList, posFloats, 0.0);
                    posFloats++;
                }
            }

            //bl
            draw.putInPosList(posList, posFloats, matTX + matC * h);
            posFloats++;
            draw.putInPosList(posList, posFloats, matTY + matD * h);
            posFloats++;
            draw.putInPosList(posList, posFloats, z);
            posFloats++;
            if (hasTextureSlot) {
                draw.putInPosList(posList, posFloats, textureSlot);
                posFloats++;
            }
            if (hasCustomAttributes) {
                for (l in 0...customFloatAttributesSize) {
                    draw.putInPosList(posList, posFloats, 0.0);
                    posFloats++;
                }
            }

            //tl2
            draw.putInPosList(posList, posFloats, matTX);
            posFloats++;
            draw.putInPosList(posList, posFloats, matTY);
            posFloats++;
            draw.putInPosList(posList, posFloats, z);
            posFloats++;
            if (hasTextureSlot) {
                draw.putInPosList(posList, posFloats, textureSlot);
                posFloats++;
            }
            if (hasCustomAttributes) {
                for (l in 0...customFloatAttributesSize) {
                    draw.putInPosList(posList, posFloats, 0.0);
                    posFloats++;
                }
            }

            //br2
            draw.putInPosList(posList, posFloats, n8);
            posFloats++;
            draw.putInPosList(posList, posFloats, n9);
            posFloats++;
            draw.putInPosList(posList, posFloats, z);
            posFloats++;
            if (hasTextureSlot) {
                draw.putInPosList(posList, posFloats, textureSlot);
                posFloats++;
            }
            if (hasCustomAttributes) {
                for (l in 0...customFloatAttributesSize) {
                    draw.putInPosList(posList, posFloats, 0.0);
                    posFloats++;
                }
            }

        } //batchQuadVertices

        // Position
        var n = posFloats;
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

        this.posFloats = posFloats;

        var uvX:Float = 0;
        var uvY:Float = 0;
        var uvW:Float = 0;
        var uvH:Float = 0;
        var uvFloats = this.uvFloats;

        if (quad.texture != null) {

            var texWidthActual = this.texWidthActual;
            var texHeightActual = this.texHeightActual;
            var texDensity = quad.texture.density;

            // UV
            //
            if (quad.rotateFrame == ceramic.RotateFrame.ROTATE_90) {
                uvX = (quad.frameX * texDensity) / texWidthActual;
                uvY = (quad.frameY * texDensity) / texHeightActual;
                uvW = (quad.frameHeight * texDensity) / texWidthActual;
                uvH = (quad.frameWidth * texDensity) / texHeightActual;
            }
            else {
                uvX = (quad.frameX * texDensity) / texWidthActual;
                uvY = (quad.frameY * texDensity) / texHeightActual;
                uvW = (quad.frameWidth * texDensity) / texWidthActual;
                uvH = (quad.frameHeight * texDensity) / texHeightActual;
            }

            var uvList = draw.getUvList();

            //tl
            draw.putInUvList(uvList, uvFloats, uvX);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, uvY);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, 0);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, 0);
            uvFloats++;
            //tr
            draw.putInUvList(uvList, uvFloats, uvX + uvW);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, uvY);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, 0);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, 0);
            uvFloats++;
            //br
            draw.putInUvList(uvList, uvFloats, uvX + uvW);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, uvY + uvH);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, 0);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, 0);
            uvFloats++;
            //bl
            draw.putInUvList(uvList, uvFloats, uvX);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, uvY + uvH);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, 0);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, 0);
            uvFloats++;
            //tl2
            draw.putInUvList(uvList, uvFloats, uvX);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, uvY);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, 0);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, 0);
            uvFloats++;
            //br2
            draw.putInUvList(uvList, uvFloats, uvX + uvW);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, uvY + uvH);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, 0);
            uvFloats++;
            draw.putInUvList(uvList, uvFloats, 0);
            uvFloats++;

        } else {
            var uvList = draw.getUvList();
            var i = 0;
            while (i++ < 24) {
                draw.putInUvList(uvList, uvFloats, 0);
                uvFloats++;
            }
        }

        this.uvFloats = uvFloats;

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
        else if (quadDrawsRenderTexture || lastComputedBlending == ceramic.Blending.ALPHA) {
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

        var colorFloats = this.colorFloats; 
        var colorList = draw.getColorList();

        var i = 0;
        while (i < 24) {
            draw.putInColorList(colorList, colorFloats, r);
            colorFloats++;
            draw.putInColorList(colorList, colorFloats, g);
            colorFloats++;
            draw.putInColorList(colorList, colorFloats, b);
            colorFloats++;
            draw.putInColorList(colorList, colorFloats, a);
            colorFloats++;
            i += 4;
        }

        this.colorFloats = colorFloats;

        // Let backend know we did finish sending quad data
        draw.endDrawQuad();

        // Increase counts
        this.z = z + 0.001;

    } //drawQuad

    #if !ceramic_debug_draw inline #end function drawMesh(draw:backend.Draw, mesh:ceramic.Mesh):Void {

#if ceramic_debug_draw
        drawnMeshes++;
#end
        // The following code is doing pretty much the same thing as quads, but for meshes.
        // We could try to refactor to prevent redundancy but this is not required as our
        // main concern here is raw performance and anyway this code won't be updated often.

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
            if (!stateDirty) {
                var newComputedBlending = computeMeshBlending(mesh);
                stateDirty =
                    !isSameShader(mesh.shader, lastShader) ||
                    newComputedBlending != lastComputedBlending ||
#if ceramic_debug_rendering_option
                    mesh.debugRendering != lastDebugRendering ||
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
                                    stateDirty = true;
                                }
                                else {
                                    textureToUseInSameBatch = mesh.texture;
                                }
                            }
                        } else {
                            // We could use multiple texture in same batch
                            if (!canUseTextureInSameBatch(draw, mesh.texture)) {
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
                flush(draw);
                unbindUsedTextures(draw);

                // Update texture
                lastTexture = mesh.texture;
                useFirstTextureInBatch(draw, lastTexture);

#if ceramic_debug_rendering_option
                lastDebugRendering = mesh.debugRendering;
                draw.setRenderWireframe(lastDebugRendering == ceramic.DebugRendering.WIREFRAME);
#end

                // Update render target
                if (mesh.computedRenderTarget != lastRenderTarget) {
                    lastRenderTarget = mesh.computedRenderTarget;
                    useRenderTarget(draw, lastRenderTarget);
                }

                // Update shader
                lastShader = mesh.shader;
                useShader(draw, lastShader != null ? lastShader.backendItem : null);

                // Update blending
                lastComputedBlending = computeMeshBlending(mesh);
                useBlending(draw, lastComputedBlending);

                stateDirty = false;
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
        if (debugDraw && #if ceramic_debug_multitexture activeShaderCanBatchMultipleTextures #else mesh.id != null #end) {
            log.warning('* drawMesh(${mesh.id != null ? mesh.id : ''}) slot=$textureSlot texture=${lastTexture} stencil=$stencilClip clip=$lastClip');
        }
#end

        // Color
        var meshColors = mesh.colors;
        var meshSingleColor = stencilClip || mesh.colorMapping == MESH;
        var meshIndicesColor = !stencilClip && mesh.colorMapping == INDICES;

        // Data
        var meshUvs = mesh.uvs;
        var meshVertices = mesh.vertices;
        var meshIndices = mesh.indices;

        // Let backend know we will start sending mesh data
        draw.beginDrawMesh(mesh); // TODO pass mesh info

#if ceramic_debug_rendering_option
        // TODO avoid allocating an array
        if (lastDebugRendering == ceramic.DebugRendering.WIREFRAME) {
            meshIndices = [];
            var i = 0;
            while (i < mesh.indices.length) {
                meshIndices.push(mesh.indices[i]);
                meshIndices.push(mesh.indices[i+1]);
                meshIndices.push(mesh.indices[i+1]);
                meshIndices.push(mesh.indices[i+2]);
                meshIndices.push(mesh.indices[i+2]);
                meshIndices.push(mesh.indices[i]);
                i += 3;
            }
            meshSingleColor = true;
        }
#end

        // Update num vertices
        var visualNumVertices = meshIndices.length;
        var posFloats = this.posFloats;
        var posList = draw.getPosList();
        var customFloatAttributesSize = this.customFloatAttributesSize;
        var meshCustomFloatAttributesSize = mesh.customFloatAttributesSize;
        var floatsPerVertex = (4 + customFloatAttributesSize);
        var countAdd = visualNumVertices * floatsPerVertex;
        var countAfter = posFloats + countAdd;
        var startVertices = 0;
        var meshDrawsRenderTexture:Bool = false;//mesh.texture != null && mesh.texture.isRenderTexture;
        var endVertices = visualNumVertices;
        var maxVertices = Std.int((maxVertFloats / floatsPerVertex) / 3) * 3;

        // Submit the current batch if we exceed the max buffer size
        if (countAfter > maxVertFloats) {
            var textureBeforeFlush = lastTexture;
            flush(draw);
            unbindUsedTextures(draw);
            useFirstTextureInBatch(draw, textureBeforeFlush);
            posFloats = this.posFloats;
            countAfter = posFloats + countAdd;

            // Check that our mesh is still not too large
            if (countAfter > maxVertFloats) {
                endVertices = maxVertices;
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

        var uvList = draw.getUvList();
        var colorList = draw.getColorList();

        inline function batchMeshVertices() {

            // We may run this code multiple times if the mesh
            // needs to be splitted into multiple draw calls.
            // That is why it is inside a `while` block
            // Exit condition is at the end.
            while (true) {
            
                var uvFloats = this.uvFloats;
                var colorFloats = this.colorFloats; 

                var i = startVertices;
                while (i < endVertices) {

                    var j = meshIndices.unsafeGet(i);
                    var k = j * 2;
                    var l = j * (2 + meshCustomFloatAttributesSize);

                    // Position
                    //
                    var x = meshVertices.unsafeGet(l++);
                    var y = meshVertices.unsafeGet(l++);

                    draw.putInPosList(posList, posFloats, matTX + matA * x + matC * y);
                    posFloats++;
                    draw.putInPosList(posList, posFloats, matTY + matB * x + matD * y);
                    posFloats++;
                    draw.putInPosList(posList, posFloats, z);
                    posFloats++;
                    if (textureSlot != -1) {
                        draw.putInPosList(posList, posFloats, textureSlot);
                        posFloats++;
                    }
                    //draw.putInPosList(posList, posFloats, 0);

                    // Custom (float) attributes
                    //
                    if (customFloatAttributesSize != 0) {
                        for (n in 0...customFloatAttributesSize) {
                            if (n < meshCustomFloatAttributesSize) {
                                draw.putInPosList(posList, posFloats, meshVertices.unsafeGet(l++));
                            }
                            else {
                                draw.putInPosList(posList, posFloats, 0.0);
                            }
                            posFloats++;
                        }
                    }

                    // UV
                    //
                    if (texture != null) {
                        var uvX:Float = meshUvs.unsafeGet(k) * uvFactorX;
                        var uvY:Float = meshUvs.unsafeGet(k + 1) * uvFactorY;
                        draw.putInUvList(uvList, uvFloats, uvX);
                        uvFloats++;
                        draw.putInUvList(uvList, uvFloats, uvY);
                        uvFloats++;
                        draw.putInUvList(uvList, uvFloats, 0);
                        uvFloats++;
                        draw.putInUvList(uvList, uvFloats, 0);
                        uvFloats++;
                    }

                    // Color
                    //
                    if (!meshSingleColor) {
                        var meshAlphaColor:AlphaColor = meshIndicesColor ? meshColors.unsafeGet(i) : meshColors.unsafeGet(j);

                        var a:Float;
                        var r:Float;
                        var g:Float;
                        var b:Float;
                        if (meshDrawsRenderTexture || lastComputedBlending == ceramic.Blending.ALPHA) {
                            a = mesh.computedAlpha;
                            r = mesh.color.redFloat;
                            g = mesh.color.greenFloat;
                            b = mesh.color.blueFloat;
                            if (mesh.blending == ceramic.Blending.ADD && lastComputedBlending != ceramic.Blending.ADD) a = 0;
                        }
                        else {
                            a = mesh.computedAlpha * meshAlphaColor.alphaFloat;
                            r = meshAlphaColor.redFloat * a;
                            g = meshAlphaColor.greenFloat * a;
                            b = meshAlphaColor.blueFloat * a;
                            if (mesh.blending == ceramic.Blending.ADD && lastComputedBlending != ceramic.Blending.ADD) a = 0;
                        }

                        draw.putInColorList(colorList, colorFloats, r);
                        colorFloats++;
                        draw.putInColorList(colorList, colorFloats, g);
                        colorFloats++;
                        draw.putInColorList(colorList, colorFloats, b);
                        colorFloats++;
                        draw.putInColorList(colorList, colorFloats, a);
                        colorFloats++;
                    }

                    i++;
                }

                this.posFloats = posFloats;
                var uvList = draw.getUvList();

                // No texture, all uvs to zero
                //
                if (texture == null) {
                    i = startVertices;
                    while (i < endVertices) {
                        draw.putInUvList(uvList, uvFloats, 0);
                        uvFloats++;
                        draw.putInUvList(uvList, uvFloats, 0);
                        uvFloats++;
                        draw.putInUvList(uvList, uvFloats, 0);
                        uvFloats++;
                        draw.putInUvList(uvList, uvFloats, 0);
                        uvFloats++;
                        i++;
                    }
                }

                this.uvFloats = uvFloats;

                // Single color
                //
                if (meshSingleColor) {

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
                    else if (meshDrawsRenderTexture || lastComputedBlending == ceramic.Blending.ALPHA) {
                        a = mesh.computedAlpha;
                        r = mesh.color.redFloat;
                        g = mesh.color.greenFloat;
                        b = mesh.color.blueFloat;
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

                    var colorList = draw.getColorList();
                    i = startVertices;
                    while (i < endVertices) {
                        draw.putInColorList(colorList, colorFloats, r);
                        colorFloats++;
                        draw.putInColorList(colorList, colorFloats, g);
                        colorFloats++;
                        draw.putInColorList(colorList, colorFloats, b);
                        colorFloats++;
                        draw.putInColorList(colorList, colorFloats, a);
                        colorFloats++;
                        i++;
                    }
                }

                this.colorFloats = colorFloats;

                if (endVertices == visualNumVertices) {
                    // No need to submit more data, exit loop
                    break;
                }
                else {
                    
                    // There is still data left that needs to be submitted.
                    // Flush pending buffers and iterate once more.

                    var textureBeforeFlush = lastTexture;
                    flush(draw);
                    unbindUsedTextures(draw);
                    useFirstTextureInBatch(draw, textureBeforeFlush);
                    posFloats = this.posFloats;

                    startVertices = endVertices;
                    endVertices = startVertices + maxVertices;
                    if (endVertices > visualNumVertices) {
                        endVertices = visualNumVertices;
                    }
                }

            } //while

        } //batchMeshVertices

        batchMeshVertices();

        // Let backend know we did finish sending quad data
        draw.endDrawMesh();

        // Increase counts
        this.z = z + 0.001;

    } //drawMesh

    #if !ceramic_debug_draw inline #end function computeQuadBlending(quad:ceramic.Quad):ceramic.Blending {

        var blending = quad.blending;

        /*if (blending == ceramic.Blending.PREMULTIPLIED_ALPHA) {
            // Keep explicit blending
        }*/
        /*else if (blending == ceramic.Blending.AUTO && quad.texture != null && quad.texture.isRenderTexture) {
            blending = ceramic.Blending.ALPHA;
        }
        else */
        if (blending == ceramic.Blending.AUTO || blending == ceramic.Blending.ADD) {
            if (quad.computedRenderTarget != null) {
                blending = ceramic.Blending.RENDER_TO_TEXTURE;
            }
            else {
                blending = ceramic.Blending.PREMULTIPLIED_ALPHA;
            }
        }

        return blending;

    } //computeQuadBlending

    #if !ceramic_debug_draw inline #end function computeMeshBlending(mesh:ceramic.Mesh):ceramic.Blending {

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
        if (blending == ceramic.Blending.AUTO || blending == ceramic.Blending.ADD) {
            if (mesh.computedRenderTarget != null) {
                blending = ceramic.Blending.RENDER_TO_TEXTURE;
            }
            else {
                blending = ceramic.Blending.PREMULTIPLIED_ALPHA;
            }
        }

        return blending;

    } //computeMeshBlending

    inline function isSameShader(shaderA:ceramic.Shader, shaderB:ceramic.Shader):Bool {

        var backendItemA = shaderA != null ? shaderA.backendItem : defaultTexturedShader;
        var backendItemB = shaderB != null ? shaderB.backendItem : defaultTexturedShader;

        return backendItemA == backendItemB;

    } //isSameShader

    #if !ceramic_debug_draw inline #end function flush(draw:backend.Draw):Bool {

        var posFloats = this.posFloats;

        if (posFloats == 0) {
            return false;
        }

        if (posFloats > draw.maxPosFloats()) {
            throw 'Too many floats are being submitted: max=${draw.maxPosFloats()} attempt=${this.posFloats}).';
        }

        draw.flush(posFloats, uvFloats, colorFloats);

        drawCalls++;

        this.posFloats = 0;
        this.uvFloats = 0;
        this.colorFloats = 0;

#if ceramic_debug_draw
        var flushingQuadsNow = drawnQuads - flushedQuads;
        var flushingMeshesNow = drawnMeshes - flushedMeshes;
        if (debugDraw) {
            log.info('#$drawCalls(${flushingQuadsNow + flushingMeshesNow}/$posFloats) / $lastTexture / $lastShader / $lastRenderTarget / $lastComputedBlending / $lastClip');
        }
        flushedQuads = drawnQuads;
        flushedMeshes = drawnMeshes;
#end

        return true;

    } //flush

} //Renderer
