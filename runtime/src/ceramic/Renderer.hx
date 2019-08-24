package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

/** An implementation-independant GPU 2D renderer.
    To be used in pair with a draw backend implementation. */
class Renderer extends Entity {

    public var maxVerts:Int = 16384;

    public var drawnQuads(default,null):Int = 0;
    public var drawnMeshes(default,null):Int = 0;

    var posFloats:Int = 0;
    var uvFloats:Int = 0;
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

    var texWidth:Int = 0;
    var texHeight:Int = 0;
    var texWidthActual:Int = 0;
    var texHeightActual:Int = 0;

    var defaultPlainShader:backend.Shader = null;
    var defaultTexturedShader:backend.Shader = null;

    var maxVertFloats:Int = 0;

    var quad:ceramic.Quad = null;
    var mesh:ceramic.Mesh = null;

    var stateDirty:Bool = true;

    var z:Float = 0;

#if ceramic_debug_draw
    var debugDraw:Int = false;
    var drawnQuad:Int = 0;
    var drawnMeshes:Int = 0;
#end

    public function new() {

        //

    } //new

    public function render(isMainRender:Bool):Void {

        var draw = app.backend.draw;

        defaultPlainShader = ceramic.App.app.defaultColorShader.backendItem;
        defaultTexturedShader = ceramic.App.app.defaultTexturedShader.backendItem;

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
        uvFloats = 0;
        colorFloats = 0;
        normalFloats = 0;

        maxVertFloats = maxVerts * 4;
        draw.initBuffers(maxVerts);

        quad = null;
        mesh = null;

        lastTexture = null;
        lastTextureId = backend.TextureId.DEFAULT;
        lastTextureSlot = 0;
        lastShader = null;
        lastRenderTarget = null;
        lastBlending = ceramic.Blending.NORMAL;
        lastComputedBlending = ceramic.Blending.NORMAL;

        texWidth = 0;
        texHeight = 0;
        texWidthActual = 0;
        texHeightActual = 0;

#if ceramic_debug_rendering_option
        var lastDebugRendering:ceramic.DebugRendering = ceramic.DebugRendering.DEFAULT;
#end

        stencilClip = false;
        z = 0;
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

    inline function useShader(draw:backend.Draw, shader:backend.Shader):Void {

        activeShader = shader;
        draw.useShader(shader);
        if (shader != null) {
            customFloatAttributesSize = draw.shaderCustomFloatAttributesSize(shader);
        }
        else {
            customFloatAttributesSize = 0;
        }

    } //useShader

    inline function useBlending(draw:backend.Draw, blending:ceramic.Blending):Void {

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

    } //useBlending

    inline function useRenderTarget(draw:backend.Draw, renderTarget:ceramic.RenderTexture):Void {

        if (renderTarget != null) {
            draw.useRenderTarget(renderTarget.backendItem);
            if (renderTarget.clearOnRender) draw.clear();
        }
        else {
            draw.useRenderTarget(null);
        }

    } //useRenderTarget

    inline function drawQuad(draw:backend.Draw, quad:ceramic.Quad):Void {

#if ceramic_debug_draw
        drawnQuads++;
#end

        if (stencilClip) {
            // Special case of drawing into stencil buffer

            // No texture
            if (lastShader == null && quad.shader == null) {
                // Default plain shader fallback
                useShader(draw, defaultPlainShader);
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
                        // Different ceramic textures could use the same backend texture
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
                flush(draw);

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
                            texWidth = draw.getTextureWidth(lastTexture.backendItem);
                            texHeight = draw.getTextureHeight(lastTexture.backendItem);
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
                                useShader(draw, defaultTexturedShader);
                            }
                            lastTexture = quad.texture;
                            lastTextureId = draw.getTextureId(lastTexture.backendItem);
                            lastTextureSlot = draw.getTextureSlot(lastTexture.backendItem);
                            texWidth = draw.getTextureWidth(lastTexture.backendItem);
                            texHeight = draw.getTextureHeight(lastTexture.backendItem);
                            texWidthActual = draw.getTextureWidthActual(lastTexture.backendItem);
                            texHeightActual = draw.getTextureHeightActual(lastTexture.backendItem);
                            draw.bindTexture(lastTexture.backendItem);
                        } else {
#if ceramic_debug_draw
                            if (debugDraw) trace('- texture ' + lastTexture + ' -> ' + quad.texture);
#end
                            if (lastShader == null && quad.shader == null) {
                                // Default plain shader fallback
                                useShader(draw, defaultPlainShader);
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
                        useShader(draw, lastShader.backendItem);
                    }
                    else if (lastTexture != null) {
                        // Default textured shader fallback
                        useShader(draw, defaultTexturedShader);
                    }
                    else {
                        // Default plain shader fallback
                        useShader(draw, defaultPlainShader);
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
                    useBlending(draw, lastComputedBlending);
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
                    useRenderTarget(draw, lastRenderTarget);
                }

                stateDirty = false;
            }
        }

        // Update num vertices
        var visualNumVertices = 6;
        var countAfter = posFloats + visualNumVertices * 4;

        // Submit the current batch if we exceed the max buffer size
        if (countAfter > maxVertFloats) {
            flush(draw);
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
        var matA:Float = quad.a;
        var matB:Float = quad.b;
        var matC:Float = quad.c;
        var matD:Float = quad.d;
        var matTX:Float = quad.tx;
        var matTY:Float = quad.ty;
        var z:Float = this.z;
        var posFloats:Int = this.posFloats;

        // Let backend know we will start sending quad data
        draw.beginDrawQuad(quad);

        // Position
        var n = posFloats;
        if (customFloatAttributesSize == 0) {

            //tl
            draw.putInPosList(posFloats++, matTX);
            draw.putInPosList(posFloats++, matTY);
            draw.putInPosList(posFloats++, z);
            draw.putInPosList(posFloats++, 0);
            //tr
            draw.putInPosList(posFloats++, matTX + matA * w);
            draw.putInPosList(posFloats++, matTY + matB * w);
            draw.putInPosList(posFloats++, z);
            draw.putInPosList(posFloats++, 0);

            var n8 = matTX + matA * w + matC * h;
            var n9 = matTY + matB * w + matD * h;

            //br
            draw.putInPosList(posFloats++, n8);
            draw.putInPosList(posFloats++, n9);
            draw.putInPosList(posFloats++, z);
            draw.putInPosList(posFloats++, 0);
            //bl
            draw.putInPosList(posFloats++, matTX + matC * h);
            draw.putInPosList(posFloats++, matTY + matD * h);
            draw.putInPosList(posFloats++, z);
            draw.putInPosList(posFloats++, 0);
            //tl2
            draw.putInPosList(posFloats++, matTX);
            draw.putInPosList(posFloats++, matTY);
            draw.putInPosList(posFloats++, z);
            draw.putInPosList(posFloats++, 0);
            //br2
            draw.putInPosList(posFloats++, n8);
            draw.putInPosList(posFloats++, n9);
            draw.putInPosList(posFloats++, z);
            draw.putInPosList(posFloats++, 0);
        }
        else {

            //tl
            draw.putInPosList(posFloats++, matTX);
            draw.putInPosList(posFloats++, matTY);
            draw.putInPosList(posFloats++, z);
            draw.putInPosList(posFloats++, 0);
            for (l in 0...customFloatAttributesSize) {
                draw.putInPosList(posFloats++, 0.0);
            }
            //tr
            draw.putInPosList(posFloats++, matTX + matA * w);
            draw.putInPosList(posFloats++, matTY + matB * w);
            draw.putInPosList(posFloats++, z);
            draw.putInPosList(posFloats++, 0);
            for (l in 0...customFloatAttributesSize) {
                draw.putInPosList(posFloats++, 0.0);
            }

            var n8 = matTX + matA * w + matC * h;
            var n9 = matTY + matB * w + matD * h;

            //br
            draw.putInPosList(posFloats++, n8);
            draw.putInPosList(posFloats++, n9);
            draw.putInPosList(posFloats++, z);
            draw.putInPosList(posFloats++, 0);
            for (l in 0...customFloatAttributesSize) {
                draw.putInPosList(posFloats++, 0.0);
            }
            //bl
            draw.putInPosList(posFloats++, matTX + matC * h);
            draw.putInPosList(posFloats++, matTY + matD * h);
            draw.putInPosList(posFloats++, z);
            draw.putInPosList(posFloats++, 0);
            for (l in 0...customFloatAttributesSize) {
                draw.putInPosList(posFloats++, 0.0);
            }
            //tl2
            draw.putInPosList(posFloats++, matTX);
            draw.putInPosList(posFloats++, matTY);
            draw.putInPosList(posFloats++, z);
            draw.putInPosList(posFloats++, 0);
            for (l in 0...customFloatAttributesSize) {
                draw.putInPosList(posFloats++, 0.0);
            }
            //br2
            draw.putInPosList(posFloats++, n8);
            draw.putInPosList(posFloats++, n9);
            draw.putInPosList(posFloats++, z);
            draw.putInPosList(posFloats++, 0);
            for (l in 0...customFloatAttributesSize) {
                draw.putInPosList(posFloats++, 0.0);
            }
        }

        this.posFloats = posFloats;

        var uvX:Float = 0;
        var uvY:Float = 0;
        var uvW:Float = 0;
        var uvH:Float = 0;
        var uvFloats = this.uvFloats;

        if (lastTexture != null) {

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

            //tl
            draw.putInUvList(uvFloats++, uvX);
            draw.putInUvList(uvFloats++, uvY);
            draw.putInUvList(uvFloats++, 0);
            draw.putInUvList(uvFloats++, 0);
            //tr
            draw.putInUvList(uvFloats++, uvX + uvW);
            draw.putInUvList(uvFloats++, uvY);
            draw.putInUvList(uvFloats++, 0);
            draw.putInUvList(uvFloats++, 0);
            //br
            draw.putInUvList(uvFloats++, uvX + uvW);
            draw.putInUvList(uvFloats++, uvY + uvH);
            draw.putInUvList(uvFloats++, 0);
            draw.putInUvList(uvFloats++, 0);
            //bl
            draw.putInUvList(uvFloats++, uvX);
            draw.putInUvList(uvFloats++, uvY + uvH);
            draw.putInUvList(uvFloats++, 0);
            draw.putInUvList(uvFloats++, 0);
            //tl2
            draw.putInUvList(uvFloats++, uvX);
            draw.putInUvList(uvFloats++, uvY);
            draw.putInUvList(uvFloats++, 0);
            draw.putInUvList(uvFloats++, 0);
            //br2
            draw.putInUvList(uvFloats++, uvX + uvW);
            draw.putInUvList(uvFloats++, uvY + uvH);
            draw.putInUvList(uvFloats++, 0);
            draw.putInUvList(uvFloats++, 0);

        } else {
            var i = 0;
            while (i++ < 24) {
                draw.putInUvList(uvFloats++, 0);
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
        } else {
            a = quad.computedAlpha;
            r = quad.color.redFloat * a;
            g = quad.color.greenFloat * a;
            b = quad.color.blueFloat * a;
            if (quad.blending == ceramic.Blending.ADD) a = 0;
        }

        var colorFloats = this.colorFloats; 

        var i = 0;
        while (i < 24) {
            draw.putInColorList(colorFloats++, r);
            draw.putInColorList(colorFloats++, g);
            draw.putInColorList(colorFloats++, b);
            draw.putInColorList(colorFloats++, a);
            i += 4;
        }

        this.colorFloats = colorFloats;

        // Let backend know we did finish sending quad data
        draw.endDrawQuad();

        // Increase counts
        this.z = z + 0.001;

    } //drawQuad

    inline function drawMesh(draw:backend.Draw, mesh:ceramic.Mesh):Void {

#if ceramic_debug_draw
        drawnMeshes++;
#end
        // The following code is doing pretty much the same thing as quads, but for meshes.
        // We could try to refactor to prevent redundancy but this is not required as our
        // main concern here is raw performance and anyway this code won't be updated often.

        if (stencilClip) {
            // Special case of drawing into stencil buffer

            // No texture
            if (lastShader == null && mesh.shader == null) {
                // Default plain shader fallback
                useShader(draw, defaultPlainShader);
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
                if (mesh.texture != lastTexture) {
                    if (mesh.texture != null && lastTexture != null) {
                        // Different ceramic textures could use the same backend texture
                        if (!draw.textureBackendItemMatchesId(mesh.texture.backendItem, lastTextureId)) {
                            stateDirty = true;
                        }
                    } else {
                        stateDirty = true;
                    }
                }
                if (!stateDirty) {
                    stateDirty =
                        mesh.shader != lastShader ||
                        (mesh.blending != lastBlending &&
                        (
                            (mesh.blending != ceramic.Blending.NORMAL || lastBlending != ceramic.Blending.ADD) &&
                            (mesh.blending != ceramic.Blending.ADD || lastBlending != ceramic.Blending.NORMAL)
                        )) ||
#if ceramic_debug_rendering_option
                        mesh.debugRendering != lastDebugRendering ||
#end
                        mesh.computedRenderTarget != lastRenderTarget;
                }
            }

            if (stateDirty) {
#if ceramic_debug_draw
                if (debugDraw) trace('-- flush --');
#end
                flush(draw);

                // Update texture
                if (mesh.texture != lastTexture) {
                    if (mesh.texture != null && lastTexture != null) {
                        if (!draw.textureBackendItemMatchesId(mesh.texture.backendItem, lastTextureId)) {
#if ceramic_debug_draw
                            if (debugDraw) trace('- texture ' + lastTexture + ' -> ' + mesh.texture);
#end
                            lastTexture = mesh.texture;
                            lastTextureId = draw.getTextureId(lastTexture.backendItem);
                            lastTextureSlot = draw.getTextureSlot(lastTexture.backendItem);
                            texWidthActual = draw.getTextureWidthActual(lastTexture.backendItem);
                            texHeightActual = draw.getTextureHeightActual(lastTexture.backendItem);
                            draw.bindTexture(lastTexture.backendItem);
                        }
                    } else {
                        if (mesh.texture != null) {
#if ceramic_debug_draw
                            if (debugDraw) trace('- texture ' + lastTexture + ' -> ' + mesh.texture);
#end
                            if (lastShader == null && mesh.shader == null) {
                                // Default textured shader fallback
                                useShader(draw, defaultTexturedShader);
                            }
                            lastTexture = mesh.texture;
                            lastTextureId = draw.getTextureId(lastTexture.backendItem);
                            lastTextureSlot = draw.getTextureSlot(lastTexture.backendItem);
                            texWidthActual = draw.getTextureWidthActual(lastTexture.backendItem);
                            texHeightActual = draw.getTextureHeightActual(lastTexture.backendItem);
                            draw.bindTexture(lastTexture.backendItem);
                        } else {
#if ceramic_debug_draw
                            if (debugDraw) trace('- texture ' + lastTexture + ' -> ' + mesh.texture);
#end
                            if (lastShader == null && mesh.shader == null) {
                                // Default plain shader fallback
                                useShader(draw, defaultPlainShader);
                            }
                            lastTexture = null;
                            lastTextureId = backend.TextureId.DEFAULT;
                            draw.setActiveTexture(lastTextureSlot);
                            draw.bindNoTexture(); // This was commented out. Why? Try to run uncommented
                        }
                    }
                }

                // Update shader
                if (mesh.shader != lastShader) {
#if ceramic_debug_draw
                    if (debugDraw) trace('- shader ' + lastShader + ' -> ' + mesh.shader);
#end
                    lastShader = mesh.shader;

                    if (lastShader != null) {
                        // Custom shader
                        useShader(draw, lastShader.backendItem);
                    }
                    else if (lastTexture != null) {
                        // Default textured shader fallback
                        useShader(draw, defaultTexturedShader);
                    }
                    else {
                        // Default plain shader fallback
                        useShader(draw, defaultPlainShader);
                    }
                }

                // Update blending
                var newComputedBlending = mesh.blending;
                if (newComputedBlending == ceramic.Blending.NORMAL && mesh.texture != null && mesh.texture.isRenderTexture) {
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
                    useBlending(draw, lastComputedBlending);
                }

#if ceramic_debug_rendering_option
                lastDebugRendering = mesh.debugRendering;
                draw.setRenderWireframe(lastDebugRendering == ceramic.DebugRendering.WIREFRAME);
#end

                // Update render target
                if (mesh.computedRenderTarget != lastRenderTarget) {
#if ceramic_debug_draw
                    if (debugDraw) trace('- render target ' + lastRenderTarget + ' -> ' + mesh.computedRenderTarget);
#end
                    lastRenderTarget = mesh.computedRenderTarget;
                    useRenderTarget(draw, lastRenderTarget);
                }

                stateDirty = false;
            }
        }

        // Fetch matrix
        //
        var matA:Float = quad.a;
        var matB:Float = quad.b;
        var matC:Float = quad.c;
        var matD:Float = quad.d;
        var matTX:Float = quad.tx;
        var matTY:Float = quad.ty;
        var z:Float = this.z;

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
            i = 0;
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
        var customFloatAttributesSize = this.customFloatAttributesSize;
        var countAfter = posFloats + visualNumVertices * (4 + customFloatAttributesSize);

        // Submit the current batch if we exceed the max buffer size
        if (countAfter > maxVertFloats) {
            flush(draw);
        }

        // Actual texture size may differ from its logical one.
        // Keep factor values to generate UV mapping that matches the real texture.
        var uvFactorX:Float = 0;
        var uvFactorY:Float = 0;
        if (lastTexture != null) {
            uvFactorX = texWidth / texWidthActual;
            uvFactorY = texHeight / texHeightActual;
        }
        
        var uvFloats = this.uvFloats;
        var colorFloats = this.colorFloats; 

        var i = 0;
        while (i < visualNumVertices) {

            var j = meshIndices.unsafeGet(i);
            var k = j * 2;
            var l = j * (2 + customFloatAttributesSize);

            // Position
            //
            var x = meshVertices.unsafeGet(l++);
            var y = meshVertices.unsafeGet(l++);

            draw.putInPosList(posFloats++, matTX + matA * x + matC * y);
            draw.putInPosList(posFloats++, matTY + matB * x + matD * y);
            draw.putInPosList(posFloats++, z);
            draw.putInPosList(posFloats++, 0);

            // Custom (float) attributes
            //
            if (customFloatAttributesSize != 0) {
                for (n in 0...customFloatAttributesSize) {
                    draw.putInPosList(posFloats++, meshVertices.unsafeGet(l++));
                }
            }

            // UV
            //
            if (lastTexture != null) {
                var uvX:Float = meshUvs.unsafeGet(k) * uvFactorX;
                var uvY:Float = meshUvs.unsafeGet(k + 1) * uvFactorY;
                draw.putInUvList(uvFloats++, uvX);
                draw.putInUvList(uvFloats++, uvY);
                draw.putInUvList(uvFloats++, 0);
                draw.putInUvList(uvFloats++, 0);
            }

            // Color
            //
            if (!meshSingleColor) {
                var meshAlphaColor:AlphaColor = meshIndicesColor ? meshColors.unsafeGet(i) : meshColors.unsafeGet(j);

                var a = mesh.computedAlpha * meshAlphaColor.alphaFloat;
                var r = meshAlphaColor.redFloat * a;
                var g = meshAlphaColor.greenFloat * a;
                var b = meshAlphaColor.blueFloat * a;
                if (mesh.blending == ceramic.Blending.ADD) a = 0;

                draw.putInColorList(colorFloats++, r);
                draw.putInColorList(colorFloats++, g);
                draw.putInColorList(colorFloats++, b);
                draw.putInColorList(colorFloats++, a);
            }

            i++;
        }

        this.posFloats = posFloats;

        // No texture, all uvs to zero
        //
        if (lastTexture == null) {
            i = 0;
            while (i < visualNumVertices) {
                draw.putInUvList(uvFloats++, 0);
                draw.putInUvList(uvFloats++, 0);
                draw.putInUvList(uvFloats++, 0);
                draw.putInUvList(uvFloats++, 0);
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
            } else {
                var meshAlphaColor = meshColors.unsafeGet(0);
                a = mesh.computedAlpha * meshAlphaColor.alphaFloat;
                r = meshAlphaColor.redFloat * a;
                g = meshAlphaColor.greenFloat * a;
                b = meshAlphaColor.blueFloat * a;
                if (mesh.blending == ceramic.Blending.ADD) a = 0;
            }

            i = 0;
            while (i < visualNumVertices) {
                draw.putInColorList(colorFloats++, r);
                draw.putInColorList(colorFloats++, g);
                draw.putInColorList(colorFloats++, b);
                draw.putInColorList(colorFloats++, a);
                i++;
            }
        }

        this.colorFloats = colorFloats;

        // Let backend know we did finish sending quad data
        draw.endDrawMesh();

        // Increase counts
        this.z = z + 0.001;

    } //drawMesh

    inline function flush(draw:backend.Draw) {

        // TODO

    } //flush

} //Renderer
