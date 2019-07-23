package ceramic;

/** An implementation-independant GPU 2D renderer.
    To be used in pair with a draw backend implementation. */
class Renderer extends Entity {

    public var maxVerts:Int = 16384;

    public var drawQuads(default,null):Int = 0;
    public var drawMeshes(default,null):Int = 0;

    var posFloats:Int = 0;
    var tcoordsFloats:Int = 0;
    var colorFloats:Int = 0;
    var normalFloats:Int = 0;

    var activeShader:backend.Shader = null;
    var customFloatAttributesSize:Int = 0;

    var stencilClip:Bool = false;

    var lastTexture:ceramic.Texture = null;
    var lastTextureId:backend.TextureId = backend.TextureId.DEFAULT;
    var lastTextureSlot:Int = 0;
    var lastShader:ceramic.Shader = null;
    var lastRenderTarget:ceramic.RenderTexture = null;
    var lastBlending:ceramic.Blending = ceramic.Blending.NORMAL;
    var lastComputedBlending:ceramic.Blending = ceramic.Blending.NORMAL;

    var draw:backend.Draw = null;

    var maxVertFloats:Int = 0;

    var visualNumVertices:Int = 0;
    var quad:ceramic.Quad = null;
    var mesh:ceramic.Mesh = null;

    var stateDirty:Bool = true;

#if ceramic_debug_draw
    var debugDraw:Int = false;
    var drawnQuad:Int = 0;
    var drawnMeshes:Int = 0;
#end

    public function new() {

        //

    } //new

    public function render(isMainRender:Bool):Void {

        draw = app.backend.draw;

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
        } else {
            debugDraw = false;
        }
#end

        posFloats = 0;
        tcoordFloats = 0;
        colorFloats = 0;
        normalFloats = 0;

        maxVertFloats = maxVerts * 4;

        visualNumVertices = 0;
        quad = null;
        mesh = null;

        lastTexture = null;
        lastTextureId = backend.TextureId.DEFAULT;
        lastTextureSlot: = 0;
        lastShader = null;
        lastRenderTarget = null;
        lastBlending = ceramic.Blending.NORMAL;
        lastComputedBlending = ceramic.Blending.NORMAL;

#if ceramic_debug_rendering_option
        var lastDebugRendering:ceramic.DebugRendering = ceramic.DebugRendering.DEFAULT;
#end
        
        var lastClip:ceramic.Visual = null;
        var clip:ceramic.Visual = null;
        stencilClip = false;

        var vertIndex:Int = 0;
        var i:Int = 0;
        var j:Int = 0;
        var k:Int = 0;
        var l:Int = 0;
        var n:Int = 0;
        var z:Float = 0;

        var r:Float = 1;
        var g:Float = 1;
        var b:Float = 1;
        var a:Float = 1;

        var x:Float;
        var y:Float;

        var matA:Float = 0;
        var matB:Float = 0;
        var matC:Float = 0;
        var matD:Float = 0;
        var matTX:Float = 0;
        var matTY:Float = 0;

        var uvX:Float = 0;
        var uvY:Float = 0;
        var uvW:Float = 0;
        var uvH:Float = 0;

        var w:Float;
        var h:Float;

        var meshAlphaColor:ceramic.AlphaColor = 0xFFFFFFFF;
        var meshIndicesColor = false;
        var meshSingleColor = false;
        var meshColors:Array<ceramic.AlphaColor> = null;
        var meshUvs:Array<Float> = null;
        var meshVertices:Array<Float> = null;
        var meshIndices:Array<Int> = null;
        var uvFactorX:Float = 1;
        var uvFactorY:Float = 1;

        var texWidth:Float = 0;
        var texHeight:Float = 0;
        var texWidthActual:Float = 0;
        var texHeightActual:Float = 0;

        stateDirty = true;

        var defaultPlainShader:backend.Shader = ceramic.App.app.defaultColorShader.backendItem;
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
        draw.setActiveTexture(lastTextureSlot);
        draw.setRenderTarget(null);
        draw.enableBlending();
        useShader(draw, defaultPlainShader);

        // Default blending
        draw.setBlendFuncSeparate(
            backend.BlendMode.ONE,
            backend.BlendMode.ONE_MINUS_SRC_ALPHA,
            backend.BlendMode.ONE,
            backend.BlendMode.ONE_MINUS_SRC_ALPHA
        );

        // Default stencil test
        draw.disableStencilTest();

    } //render

    inline function useShader(shader:backend.Shader):Void {

        activeShader = shader;
        draw.useShader(shader);
        if (shader != null) {
            customFloatAttributesSize = draw.shaderCustomFloatAttributesSize(shader);
        }
        else {
            customFloatAttributesSize = 0;
        }

    } //useShader

    inline function applyBlending(blending:ceramic.Blending) {

        if (blending == ceramic.Blending.ADD) {
            draw.setBlendFuncSeparate(
                backend.BlendMode.ONE,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA,
                backend.BlendMode.ONE,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA
            );
        } else if (blending == ceramic.Blending.SET) {
            draw.setBlendFuncSeparate(
                backend.BlendMode.ONE,
                backend.BlendMode.SRC_ALPHA,
                backend.BlendMode.ONE,
                backend.BlendMode.SRC_ALPHA
            );
        } else if (blending == ceramic.Blending.NORMAL) {
            draw.setBlendFuncSeparate(
                backend.BlendMode.ONE,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA,
                backend.BlendMode.ONE,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA
            );
        } else /*if (lastBlending == ceramic.Blending.ALPHA)*/ {
            draw.setBlendFuncSeparate(
                backend.BlendMode.SRC_ALPHA,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA,
                backend.BlendMode.ONE,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA
            );
        }

    } //applyBlending

    inline function drawQuad(draw:backend.Draw, quad:ceramic.Quad):Void {

#if ceramic_debug_draw
        drawnQuads++;
#end

        if (stencilClip) {
            // Special case of drawing into stencil buffer

            // No texture
            if (lastShader == null && quad.shader == null) {
                // Default plain shader fallback
                useShader(defaultPlainShader);
            }
            lastTexture = null;
            lastTextureId = backend.TextureId.DEFAULT;
            draw.setActiveTexture(lastTextureSlot);

            // Default blending
            draw.setBlendFuncSeparate(
                backend.BlendMode.ONE,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA,
                backend.BlendMode.ONE,
                backend.BlendMode.ONE_MINUS_SRC_ALPHA
            );
            lastBlending = ceramic.Blending.NORMAL;

            stateDirty = false;

            // No render target when writing to stencil buffer
            draw.setRenderTarget(lastRenderTarget);
        }
        else {
            // Check if state is dirty
            if (!stateDirty) {
                if (quad.texture != lastTexture) {
                    if (quad.texture != null && lastTexture != null) {
                        // Different ceramic textures could use the same GL texture
                        if (!draw.textureBackendItemMatchesId(quad.texture.backendItem, lastTextureId)) {
                            stateDirty = true;
                        }
                    } else {
                        stateDirty = true;
                    }
                }
                if (!stateDirty) {
                    stateDirty =
                        quad.shader != lastShader ||
                        (quad.blending != lastBlending &&
                        (
                            (quad.blending != ceramic.Blending.NORMAL || lastBlending != ceramic.Blending.ADD) &&
                            (quad.blending != ceramic.Blending.ADD || lastBlending != ceramic.Blending.NORMAL)
                        )) ||
#if ceramic_debug_rendering_option
                        quad.debugRendering != lastDebugRendering ||
#end
                        quad.computedRenderTarget != lastRenderTarget;
                }
            }

            if (stateDirty) {
#if ceramic_debug_draw
                if (debugDraw) trace('-- flush --');
#end
                flush();

                // Update texture
                if (quad.texture != lastTexture) {
                    if (quad.texture != null && lastTexture != null) {
                        if (!draw.textureBackendItemMatchesId(quad.texture.backendItem, lastTextureId)) {
#if ceramic_debug_draw
                            if (debugDraw) trace('- texture ' + lastTexture + ' -> ' + quad.texture);
#end
                            lastTexture = quad.texture;
                            lastTextureId = draw.getTextureId(lastTexture.backendItem);
                            lastTextureSlot = draw.getTextureSlot(lastTexture.backendItem);
                            texWidthActual = draw.getTextureWidthActual(lastTexture.backendItem);
                            texHeightActual = draw.getTextureHeightActual(lastTexture.backendItem);
                            draw.bindTexture(lastTexture.backendItem);
                        }
                    } else {
                        if (quad.texture != null) {
#if ceramic_debug_draw
                            if (debugDraw) trace('- texture ' + lastTexture + ' -> ' + quad.texture);
#end
                            if (lastShader == null && quad.shader == null) {
                                // Default textured shader fallback
                                useShader(defaultTexturedShader);
                            }
                            lastTexture = quad.texture;
                            lastTextureId = draw.getTextureId(lastTexture.backendItem);
                            lastTextureSlot = draw.getTextureSlot(lastTexture.backendItem);
                            texWidthActual = draw.getTextureWidthActual(lastTexture.backendItem);
                            texHeightActual = draw.getTextureHeightActual(lastTexture.backendItem);
                            draw.bindTexture(lastTexture.backendItem);
                        } else {
#if ceramic_debug_draw
                            if (debugDraw) trace('- texture ' + lastTexture + ' -> ' + quad.texture);
#end
                            if (lastShader == null && quad.shader == null) {
                                // Default plain shader fallback
                                useShader(defaultPlainShader);
                            }
                            lastTexture = null;
                            lastTextureId = backend.TextureId.DEFAULT;
                            draw.setActiveTexture(lastTextureSlot);
                            draw.bindNoTexture();
                        }
                    }
                }

                // Update shader
                if (quad.shader != lastShader) {
#if ceramic_debug_draw
                    if (debugDraw) trace('- shader ' + lastShader + ' -> ' + quad.shader);
#end
                    lastShader = quad.shader;

                    if (lastShader != null) {
                        // Custom shader
                        useShader(lastShader.backendItem);
                    }
                    else if (lastTexture != null) {
                        // Default textured shader fallback
                        useShader(defaultTexturedShader);
                    }
                    else {
                        // Default plain shader fallback
                        useShader(defaultPlainShader);
                    }
                }

                // Update blending
                var newComputedBlending = quad.blending;
                if (newComputedBlending == ceramic.Blending.NORMAL && quad.texture != null && quad.texture.isRenderTexture) {
                    newComputedBlending = ceramic.Blending.ALPHA;
                }
                else if (newComputedBlending == ceramic.Blending.ADD) {
                    newComputedBlending = ceramic.Blending.NORMAL;
                }
                if (newComputedBlending != lastComputedBlending) {
#if ceramic_debug_draw
                    if (debugDraw) trace('- blending ' + lastComputedBlending + ' -> ' + newComputedBlending);
#end
                    lastComputedBlending = newComputedBlending;
                    applyBlending(lastComputedBlending);
                }

#if ceramic_debug_rendering_option
                lastDebugRendering = quad.debugRendering;
                draw.setRenderWireframe(lastDebugRendering == ceramic.DebugRendering.WIREFRAME);
#end

                // Update render target
                if (quad.computedRenderTarget != lastRenderTarget) {
#if ceramic_debug_draw
                    if (debugDraw) trace('- render target ' + lastRenderTarget + ' -> ' + quad.computedRenderTarget);
#end
                    lastRenderTarget = quad.computedRenderTarget;
                    computeRenderTarget(lastRenderTarget);
                }

                stateDirty = false;
            }
        }

    } //drawQuad

} //Renderer
