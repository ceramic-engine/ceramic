package backend.impl;

#if !ceramic_legacy_renderer

using ceramic.Extensions;

/** A custom luxe/phoenix batcher for ceramic. */
class CeramicBatcher extends phoenix.Batcher {

    public var ceramicRenderer:ceramic.Renderer = new ceramic.Renderer();
    public var isMainRender:Bool = false;
    public var ceramicVisuals:Array<ceramic.Visual> = null;

    override function batch(persist_immediate:Bool = false) {

        if (ceramic.App.app.defaultTexturedShader == null) return;

        ceramicRenderer.render(isMainRender, ceramicVisuals);

    } //batch

} //CeramicBatcher

#else

import phoenix.Texture;
import phoenix.Renderer;

import snow.modules.opengl.GL;
import snow.api.buffers.Float32Array;

using ceramic.Extensions;

/** A custom luxe/phoenix batcher for ceramic. */
class CeramicBatcher extends phoenix.Batcher {

    public static inline var vert_attribute   : Int = 0;
    public static inline var tcoord_attribute : Int = 1;
    public static inline var color_attribute  : Int = 2;

    public var isMainRender:Bool = false;
    public var ceramicVisuals:Array<ceramic.Visual> = null;

    var primitiveType = phoenix.Batcher.PrimitiveType.triangles;
    var activeShader:backend.impl.CeramicShader = null;
    var customFloatAttributesSize:Int = 0;
    var transparentColor = new phoenix.Color(1.0, 1.0, 1.0, 0.0);

#if cpp
    var view_pos = @:privateAccess new snow.api.buffers.ArrayBufferView(Float32);
    var view_tcoords = @:privateAccess new snow.api.buffers.ArrayBufferView(Float32);
    var view_colors = @:privateAccess new snow.api.buffers.ArrayBufferView(Float32);
#end

#if ceramic_debug_draw
    var lastDebugTime:Float = 0;
    var debugDraw:Bool = false;
    var drawnQuads:Int = 0;
    var drawnMeshes:Int = 0;
#end

#if ceramic_batch_multiple_buffers
    public static var NUM_BUFFERS = 32;

    public var pos_list_array    : Array<Float32Array>;
    public var tcoord_list_array : Array<Float32Array>;
    public var color_list_array  : Array<Float32Array>;

    public var buffers_index = 0;
#end

    var customGLBuffers:Array<GLBuffer> = [];

    public function new( _r : Renderer, ?_name:String = '', ?_max_verts:Int=16384 ) {

        super(_r, _name, _max_verts);

#if ceramic_batch_multiple_buffers
        pos_list_array = [pos_list];
        tcoord_list_array = [tcoord_list];
        color_list_array = [color_list];

        for (i in 1...NUM_BUFFERS) {
            pos_list_array.push(new Float32Array( max_floats ));
            tcoord_list_array.push(new Float32Array( max_floats ));
            color_list_array.push(new Float32Array( max_floats ));
        }
#end

    } //new

    override function batch(persist_immediate:Bool = false) {

        if (ceramic.App.app.defaultColorShader == null) return;

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

        // Reset render stats before we start
        dynamic_batched_count = 0;
        static_batched_count = 0;
        visible_count = 0;

        var len = 0;
        var countAfter = 0;
        var bufferVertices = 0;
        var maxVertFloats = max_verts * 4;

        var defaultTransformScaleX = view.transform.scale.x;
        var defaultTransformScaleY = view.transform.scale.y;

        var defaultViewport = view.viewport;

        pos_floats = 0;
        tcoord_floats = 0;
        color_floats = 0;
        normal_floats = 0;

#if ceramic_batch_multiple_buffers
        pos_list = pos_list_array[buffers_index];
        tcoord_list = tcoord_list_array[buffers_index];
        color_list = color_list_array[buffers_index];
#end

        var visualNumVertices = 0;
        var quad:ceramic.Quad = null;
        var mesh:ceramic.Mesh = null;

        var lastTexture:ceramic.Texture = null;
        var lastTextureId:phoenix.TextureID = #if snow_web null #else 0 #end;
        var lastTextureSlot:Int = 0;
        var lastShader:ceramic.Shader = null;
        var lastRenderTarget:ceramic.RenderTexture = null;
        var lastBlending:ceramic.Blending = ceramic.Blending.NORMAL;
        var lastComputedBlending:ceramic.Blending = ceramic.Blending.NORMAL;

#if ceramic_debug_rendering_option
        var lastDebugRendering:ceramic.DebugRendering = ceramic.DebugRendering.DEFAULT;
#end
        
        var lastClip:ceramic.Visual = null;
        var clip:ceramic.Visual = null;
        var stencilClip:Bool = false;

        var vertIndex = 0;
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

        var stateDirty = true;

        var defaultPlainShader:backend.impl.CeramicShader = ceramic.App.app.defaultColorShader.backendItem;
        var defaultTexturedShader:backend.impl.CeramicShader = ceramic.App.app.defaultTexturedShader.backendItem;

        // Mark auto-rendering render textures as dirty
        var allRenderTextures = ceramic.App.app.renderTextures;
        for (ii in 0...allRenderTextures.length) {
            var renderTexture = allRenderTextures.unsafeGet(ii);
            if (renderTexture.autoRender) {
                renderTexture.renderDirty = true;
            }
        }
        
        // Initialize default state
        renderer.state.activeTexture(GL.TEXTURE0 + lastTextureSlot);
        
        //renderer.state.bindTexture2D(null);
        renderer.target = null;
        renderer.state.enable(GL.BLEND);
        useShader(defaultPlainShader);
        defaultPlainShader.activate();

        // Default blending
        GL.blendFuncSeparate(
            //src_rgb
            phoenix.Batcher.BlendMode.one,
            //dest_rgb
            phoenix.Batcher.BlendMode.one_minus_src_alpha,
            //src_alpha
            phoenix.Batcher.BlendMode.one,
            //dest_alpha
            phoenix.Batcher.BlendMode.one_minus_src_alpha
        );

        // Default stencil test
        GL.disable(GL.STENCIL_TEST);

        inline function applyBlending(blending:ceramic.Blending) {

            if (blending == ceramic.Blending.ADD) {
                GL.blendFuncSeparate(
                    //src_rgb
                    phoenix.Batcher.BlendMode.one,
                    //dest_rgb
                    phoenix.Batcher.BlendMode.one_minus_src_alpha,
                    //src_alpha
                    phoenix.Batcher.BlendMode.one,
                    //dest_alpha
                    phoenix.Batcher.BlendMode.one_minus_src_alpha
                );
            } else if (blending == ceramic.Blending.SET) {
                GL.blendFuncSeparate(
                    //src_rgb
                    phoenix.Batcher.BlendMode.one,
                    //dest_rgb
                    phoenix.Batcher.BlendMode.src_alpha,
                    //src_alpha
                    phoenix.Batcher.BlendMode.one,
                    //dest_alpha
                    phoenix.Batcher.BlendMode.src_alpha
                );
            } else if (blending == ceramic.Blending.NORMAL) {
                GL.blendFuncSeparate(
                    //src_rgb
                    phoenix.Batcher.BlendMode.one,
                    //dest_rgb
                    phoenix.Batcher.BlendMode.one_minus_src_alpha,
                    //src_alpha
                    phoenix.Batcher.BlendMode.one,
                    //dest_alpha
                    phoenix.Batcher.BlendMode.one_minus_src_alpha
                );
            } else /*if (lastBlending == ceramic.Blending.ALPHA)*/ {
                GL.blendFuncSeparate(
                    //src_rgb
                    phoenix.Batcher.BlendMode.src_alpha,
                    //dest_rgb
                    phoenix.Batcher.BlendMode.one_minus_src_alpha,
                    //src_alpha
                    phoenix.Batcher.BlendMode.one,
                    //dest_alpha
                    phoenix.Batcher.BlendMode.one_minus_src_alpha
                );
            }

        } //applyBlending

        inline function computeRenderTarget(lastRenderTarget:ceramic.RenderTexture) {

            if (lastRenderTarget != null) {
                var renderTexture:backend.impl.CeramicRenderTexture = cast lastRenderTarget.backendItem;
                renderer.target = renderTexture;
                view.transform.scale.x = ceramic.App.app.screen.nativeDensity;
                view.transform.scale.y = ceramic.App.app.screen.nativeDensity;
                view.process();
                GL.viewport(0, 0, renderTexture.width, renderTexture.height);
                if (lastRenderTarget.clearOnRender) Luxe.renderer.clear(transparentColor);
            } else {
                renderer.target = null;
                view.transform.scale.x = defaultTransformScaleX;
                view.transform.scale.y = defaultTransformScaleY;
                view.viewport = defaultViewport;
                update_view();
            }

        } //computeRenderTarget

        #if (!ceramic_debug_draw) inline #end function drawQuad() {
#if ceramic_debug_draw
            drawnQuads++;
#end

            if (stencilClip) {
                // Special case of drawing into stencil buffer

                // No texture
                if (lastShader == null && quad.shader == null) {
                    // Default plain shader fallback
                    useShader(defaultPlainShader);
                    defaultPlainShader.activate();
                }
                lastTexture = null;
                lastTextureId = #if snow_web null #else 0 #end;
                renderer.state.activeTexture(GL.TEXTURE0 + lastTextureSlot);
                //renderer.state.bindTexture2D(null);

                // Default blending
                GL.blendFuncSeparate(
                    //src_rgb
                    phoenix.Batcher.BlendMode.one,
                    //dest_rgb
                    phoenix.Batcher.BlendMode.one_minus_src_alpha,
                    //src_alpha
                    phoenix.Batcher.BlendMode.one,
                    //dest_alpha
                    phoenix.Batcher.BlendMode.one_minus_src_alpha
                );
                lastBlending = ceramic.Blending.NORMAL;

                stateDirty = false;

                // No render target when writing to stencil buffer
                computeRenderTarget(lastRenderTarget);
            }
            else {
                // Check if state is dirty
                if (!stateDirty) {
                    if (quad.texture != lastTexture) {
                        if (quad.texture != null && lastTexture != null) {
                            // Different ceramic textures could use the same GL texture
                            if ((quad.texture.backendItem : phoenix.Texture).texture != lastTextureId) {
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
                            if ((quad.texture.backendItem : phoenix.Texture).texture != lastTextureId) {
#if ceramic_debug_draw
                                if (debugDraw) trace('- texture ' + lastTexture + ' -> ' + quad.texture);
#end
                                lastTexture = quad.texture;
                                lastTextureId = (quad.texture.backendItem : phoenix.Texture).texture;
                                lastTextureSlot = (quad.texture.backendItem : phoenix.Texture).slot;
                                texWidthActual = (quad.texture.backendItem : phoenix.Texture).width_actual;
                                texHeightActual = (quad.texture.backendItem : phoenix.Texture).height_actual;
                                (lastTexture.backendItem : phoenix.Texture).bind();
                            }
                        } else {
                            if (quad.texture != null) {
#if ceramic_debug_draw
                                if (debugDraw) trace('- texture ' + lastTexture + ' -> ' + quad.texture);
#end
                                if (lastShader == null && quad.shader == null) {
                                    // Default textured shader fallback
                                    useShader(defaultTexturedShader);
                                    defaultTexturedShader.activate();
                                }
                                lastTexture = quad.texture;
                                lastTextureId = (quad.texture.backendItem : phoenix.Texture).texture;
                                lastTextureSlot = (quad.texture.backendItem : phoenix.Texture).slot;
                                texWidthActual = (quad.texture.backendItem : phoenix.Texture).width_actual;
                                texHeightActual = (quad.texture.backendItem : phoenix.Texture).height_actual;
                                (lastTexture.backendItem : phoenix.Texture).bind();
                            } else {
#if ceramic_debug_draw
                                if (debugDraw) trace('- texture ' + lastTexture + ' -> ' + quad.texture);
#end
                                if (lastShader == null && quad.shader == null) {
                                    // Default plain shader fallback
                                    useShader(defaultPlainShader);
                                    defaultPlainShader.activate();
                                }
                                lastTexture = null;
                                lastTextureId = #if snow_web null #else 0 #end;
                                renderer.state.activeTexture(GL.TEXTURE0 + lastTextureSlot);
                                renderer.state.bindTexture2D(#if snow_web null #else 0 #end);
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
                            (lastShader.backendItem : phoenix.Shader).activate();
                        }
                        else if (lastTexture != null) {
                            // Default textured shader fallback
                            useShader(defaultTexturedShader);
                            defaultTexturedShader.activate();
                        }
                        else {
                            // Default plain shader fallback
                            useShader(defaultPlainShader);
                            defaultPlainShader.activate();
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
                    primitiveType = lastDebugRendering == ceramic.DebugRendering.WIREFRAME ? phoenix.Batcher.PrimitiveType.lines : phoenix.Batcher.PrimitiveType.triangles;
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

            visible_count++;

            // Update num vertices
            visualNumVertices = 6;
            countAfter = pos_floats + visualNumVertices * 4;

            // Submit the current batch if we exceed the max buffer size
            if (countAfter > maxVertFloats) {
                flush();
            }

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
            matA = quad.a;
            matB = quad.b;
            matC = quad.c;
            matD = quad.d;
            matTX = quad.tx;
            matTY = quad.ty;

            // Position
            n = pos_floats;
            if (customFloatAttributesSize == 0) {
                //tl
                pos_list[pos_floats++] = matTX;
                pos_list[pos_floats++] = matTY;
                pos_list[pos_floats++] = z;
                pos_list[pos_floats++] = 0;
                //tr
                pos_list[pos_floats++] = matTX + matA * w;
                pos_list[pos_floats++] = matTY + matB * w;
                pos_list[pos_floats++] = z;
                pos_list[pos_floats++] = 0;
                //br
                pos_list[pos_floats++] = matTX + matA * w + matC * h;
                pos_list[pos_floats++] = matTY + matB * w + matD * h;
                pos_list[pos_floats++] = z;
                pos_list[pos_floats++] = 0;
                //bl
                pos_list[pos_floats++] = matTX + matC * h;
                pos_list[pos_floats++] = matTY + matD * h;
                pos_list[pos_floats++] = z;
                pos_list[pos_floats++] = 0;
                //tl2
                pos_list[pos_floats++] = pos_list[n];
                pos_list[pos_floats++] = pos_list[n+1];
                pos_list[pos_floats++] = pos_list[n+2];
                pos_list[pos_floats++] = 0;
                //br2
                pos_list[pos_floats++] = pos_list[n+8];
                pos_list[pos_floats++] = pos_list[n+9];
                pos_list[pos_floats++] = pos_list[n+10];
                pos_list[pos_floats++] = 0;

            } else {
                //tl
                pos_list[pos_floats++] = matTX;
                pos_list[pos_floats++] = matTY;
                pos_list[pos_floats++] = z;
                pos_list[pos_floats++] = 0;
                for (l in 0...customFloatAttributesSize) {
                    pos_list[pos_floats++] = 0.0;
                }
                //tr
                pos_list[pos_floats++] = matTX + matA * w;
                pos_list[pos_floats++] = matTY + matB * w;
                pos_list[pos_floats++] = z;
                pos_list[pos_floats++] = 0;
                for (l in 0...customFloatAttributesSize) {
                    pos_list[pos_floats++] = 0.0;
                }
                //br
                pos_list[pos_floats++] = matTX + matA * w + matC * h;
                pos_list[pos_floats++] = matTY + matB * w + matD * h;
                pos_list[pos_floats++] = z;
                pos_list[pos_floats++] = 0;
                for (l in 0...customFloatAttributesSize) {
                    pos_list[pos_floats++] = 0.0;
                }
                //bl
                pos_list[pos_floats++] = matTX + matC * h;
                pos_list[pos_floats++] = matTY + matD * h;
                pos_list[pos_floats++] = z;
                pos_list[pos_floats++] = 0;
                for (l in 0...customFloatAttributesSize) {
                    pos_list[pos_floats++] = 0.0;
                }
                //tl2
                pos_list[pos_floats++] = pos_list[n];
                pos_list[pos_floats++] = pos_list[n+1];
                pos_list[pos_floats++] = pos_list[n+2];
                pos_list[pos_floats++] = 0;
                for (l in 0...customFloatAttributesSize) {
                    pos_list[pos_floats++] = 0.0;
                }
                //br2
                pos_list[pos_floats++] = pos_list[n+customFloatAttributesSize*2+8];
                pos_list[pos_floats++] = pos_list[n+customFloatAttributesSize*2+9];
                pos_list[pos_floats++] = pos_list[n+customFloatAttributesSize*2+10];
                pos_list[pos_floats++] = 0;
                for (l in 0...customFloatAttributesSize) {
                    pos_list[pos_floats++] = 0.0;
                }
            }

            if (lastTexture != null) {
                // UV
                //
                if (quad.rotateFrame == ceramic.RotateFrame.ROTATE_90) {
                    uvX = (quad.frameX * quad.texture.density) / texWidthActual;
                    uvY = (quad.frameY * quad.texture.density) / texHeightActual;
                    uvW = (quad.frameHeight * quad.texture.density) / texWidthActual;
                    uvH = (quad.frameWidth * quad.texture.density) / texHeightActual;
                }
                else {
                    uvX = (quad.frameX * quad.texture.density) / texWidthActual;
                    uvY = (quad.frameY * quad.texture.density) / texHeightActual;
                    uvW = (quad.frameWidth * quad.texture.density) / texWidthActual;
                    uvH = (quad.frameHeight * quad.texture.density) / texHeightActual;
                }

                //tl
                tcoord_list[tcoord_floats++] = uvX;
                tcoord_list[tcoord_floats++] = uvY;
                tcoord_list[tcoord_floats++] = 0;
                tcoord_list[tcoord_floats++] = 0;
                //tr
                tcoord_list[tcoord_floats++] = uvX + uvW;
                tcoord_list[tcoord_floats++] = uvY;
                tcoord_list[tcoord_floats++] = 0;
                tcoord_list[tcoord_floats++] = 0;
                //br
                tcoord_list[tcoord_floats++] = uvX + uvW;
                tcoord_list[tcoord_floats++] = uvY + uvH;
                tcoord_list[tcoord_floats++] = 0;
                tcoord_list[tcoord_floats++] = 0;
                //bl
                tcoord_list[tcoord_floats++] = uvX;
                tcoord_list[tcoord_floats++] = uvY + uvH;
                tcoord_list[tcoord_floats++] = 0;
                tcoord_list[tcoord_floats++] = 0;
                //tl2
                tcoord_list[tcoord_floats++] = uvX;
                tcoord_list[tcoord_floats++] = uvY;
                tcoord_list[tcoord_floats++] = 0;
                tcoord_list[tcoord_floats++] = 0;
                //br2
                tcoord_list[tcoord_floats++] = uvX + uvW;
                tcoord_list[tcoord_floats++] = uvY + uvH;
                tcoord_list[tcoord_floats++] = 0;
                tcoord_list[tcoord_floats++] = 0;

            } else {
                i = 0;
                while (i++ < 24)
                    tcoord_list[tcoord_floats++] = 0;
            }

            // Colors
            //
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

            i = 0;
            while (i < 24) {
                color_list[color_floats++] = r;
                color_list[color_floats++] = g;
                color_list[color_floats++] = b;
                color_list[color_floats++] = a;
                i += 4;
            }

            // Increase counts
            z += 0.001;
            dynamic_batched_count++;
            vert_count += visualNumVertices;

        } //drawQuad

        #if (!ceramic_debug_draw) inline #end function drawMesh() {

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
                    useShader(defaultPlainShader);
                    defaultPlainShader.activate();
                }
                lastTexture = null;
                lastTextureId = #if snow_web null #else 0 #end;
                renderer.state.activeTexture(GL.TEXTURE0 + lastTextureSlot);
                //renderer.state.bindTexture2D(null);

                // Default blending
                GL.blendFuncSeparate(
                    //src_rgb
                    phoenix.Batcher.BlendMode.one,
                    //dest_rgb
                    phoenix.Batcher.BlendMode.one_minus_src_alpha,
                    //src_alpha
                    phoenix.Batcher.BlendMode.one,
                    //dest_alpha
                    phoenix.Batcher.BlendMode.one_minus_src_alpha
                );
                lastBlending = ceramic.Blending.NORMAL;

                stateDirty = false;
            }
            else {
                // Check if state is dirty
                if (!stateDirty) {
                    if (mesh.texture != lastTexture) {
                        if (mesh.texture != null && lastTexture != null) {
                            // Different ceramic textures could use the same GL texture
                            if ((mesh.texture.backendItem : phoenix.Texture).texture != lastTextureId) {
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
                    flush();

                    // Update texture
                    if (mesh.texture != lastTexture) {
                        if (mesh.texture != null && lastTexture != null) {
                            if ((mesh.texture.backendItem : phoenix.Texture).texture != lastTextureId) {
#if ceramic_debug_draw
                                if (debugDraw) trace('- texture ' + lastTexture + ' -> ' + mesh.texture);
#end
                                lastTexture = mesh.texture;
                                lastTextureId = (mesh.texture.backendItem : phoenix.Texture).texture;
                                texWidth = (mesh.texture.backendItem : phoenix.Texture).width;
                                texHeight = (mesh.texture.backendItem : phoenix.Texture).height;
                                texWidthActual = (mesh.texture.backendItem : phoenix.Texture).width_actual;
                                texHeightActual = (mesh.texture.backendItem : phoenix.Texture).height_actual;
                                (lastTexture.backendItem : phoenix.Texture).bind();
                            }
                        } else {
                            if (mesh.texture != null) {
#if ceramic_debug_draw
                                if (debugDraw) trace('- texture ' + lastTexture + ' -> ' + mesh.texture);
#end
                                if (lastShader == null && mesh.shader == null) {
                                    // Default textured shader fallback
                                    useShader(defaultTexturedShader);
                                    defaultTexturedShader.activate();
                                }
                                lastTexture = mesh.texture;
                                lastTextureId = (mesh.texture.backendItem : phoenix.Texture).texture;
                                texWidth = (mesh.texture.backendItem : phoenix.Texture).width;
                                texHeight = (mesh.texture.backendItem : phoenix.Texture).height;
                                texWidthActual = (mesh.texture.backendItem : phoenix.Texture).width_actual;
                                texHeightActual = (mesh.texture.backendItem : phoenix.Texture).height_actual;
                                (lastTexture.backendItem : phoenix.Texture).bind();
                            } else {
#if ceramic_debug_draw
                                if (debugDraw) trace('- texture ' + lastTexture + ' -> ' + mesh.texture);
#end
                                if (lastShader == null && mesh.shader == null) {
                                    // Default plain shader fallback
                                    useShader(defaultPlainShader);
                                    defaultPlainShader.activate();
                                }
                                lastTexture = null;
                                lastTextureId = #if snow_web null #else 0 #end;
                                renderer.state.activeTexture(GL.TEXTURE0 + lastTextureSlot);
                                //renderer.state.bindTexture2D(null);
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
                            useShader(lastShader.backendItem);
                            (lastShader.backendItem : phoenix.Shader).activate();
                        }
                        else if (lastTexture != null) {
                            // Default textured shader fallback
                            useShader(defaultTexturedShader);
                            defaultTexturedShader.activate();
                        }
                        else {
                            // Default plain shader fallback
                            useShader(defaultPlainShader);
                            defaultPlainShader.activate();
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
                        applyBlending(lastComputedBlending);
                    }

#if ceramic_debug_rendering_option
                    lastDebugRendering = mesh.debugRendering;
                    primitiveType = lastDebugRendering == ceramic.DebugRendering.WIREFRAME ? phoenix.Batcher.PrimitiveType.lines : phoenix.Batcher.PrimitiveType.triangles;
#end

                    // Update render target
                    if (mesh.computedRenderTarget != lastRenderTarget) {
#if ceramic_debug_draw
                        if (debugDraw) trace('- render target ' + lastRenderTarget + ' -> ' + mesh.computedRenderTarget);
#end
                        lastRenderTarget = mesh.computedRenderTarget;
                        computeRenderTarget(lastRenderTarget);
                    }

                    stateDirty = false;
                }
            }

            visible_count++;

            // Fetch matrix
            //
            matA = mesh.a;
            matB = mesh.b;
            matC = mesh.c;
            matD = mesh.d;
            matTX = mesh.tx;
            matTY = mesh.ty;

            // Color
            meshColors = mesh.colors;
            meshSingleColor = stencilClip || mesh.colorMapping == MESH;
            meshIndicesColor = !stencilClip && mesh.colorMapping == INDICES;

            if (meshSingleColor) {
                if (stencilClip) {
                    a = 1;
                    r = 1;
                    g = 0;
                    b = 0;
                } else {
                    meshAlphaColor = meshColors.unsafeGet(0);
                    a = mesh.computedAlpha * meshAlphaColor.alphaFloat;
                    r = meshAlphaColor.redFloat * a;
                    g = meshAlphaColor.greenFloat * a;
                    b = meshAlphaColor.blueFloat * a;
                    if (mesh.blending == ceramic.Blending.ADD) a = 0;
                }
            }

            // Data
            meshUvs = mesh.uvs;
            meshVertices = mesh.vertices;
            meshIndices = mesh.indices;

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
            visualNumVertices = meshIndices.length;
            countAfter = pos_floats + visualNumVertices * 4;

            // Submit the current batch if we exceed the max buffer size
            if (countAfter > maxVertFloats) {
                flush();
            }

            // Actual texture size may differ from its logical one.
            // Keep factor values to generate UV mapping that matches the real texture.
            if (lastTexture != null) {
                uvFactorX = texWidth / texWidthActual;
                uvFactorY = texHeight / texHeightActual;
            }

            i = 0;
            while (i < visualNumVertices) {

                j = meshIndices.unsafeGet(i);
                k = j * 2;
                l = j * (2 + customFloatAttributesSize);

                // Position
                //
                x = meshVertices.unsafeGet(l++);
                y = meshVertices.unsafeGet(l++);

                pos_list[pos_floats++] = matTX + matA * x + matC * y;
                pos_list[pos_floats++] = matTY + matB * x + matD * y;
                pos_list[pos_floats++] = z;
                pos_list[pos_floats++] = 0;

                // Custom (float) attributes
                //
                if (customFloatAttributesSize != 0) {
                    for (n in 0...customFloatAttributesSize) {
                        pos_list[pos_floats++] = meshVertices.unsafeGet(l++);
                    }
                }

                // UV
                //
                if (lastTexture != null) {
                    uvX = meshUvs.unsafeGet(k) * uvFactorX;
                    uvY = meshUvs.unsafeGet(k + 1) * uvFactorY;
                    tcoord_list[tcoord_floats++] = uvX;
                    tcoord_list[tcoord_floats++] = uvY;
                    tcoord_list[tcoord_floats++] = 0;
                    tcoord_list[tcoord_floats++] = 0;
                }

                // Color
                //
                if (!meshSingleColor) {
                    meshAlphaColor = meshIndicesColor ? meshColors.unsafeGet(i) : meshColors.unsafeGet(j);

                    a = mesh.computedAlpha * meshAlphaColor.alphaFloat;
                    r = meshAlphaColor.redFloat * a;
                    g = meshAlphaColor.greenFloat * a;
                    b = meshAlphaColor.blueFloat * a;
                    if (mesh.blending == ceramic.Blending.ADD) a = 0;

                    color_list[color_floats++] = r;
                    color_list[color_floats++] = g;
                    color_list[color_floats++] = b;
                    color_list[color_floats++] = a;
                }

                i++;
            }

            // No texture, all uvs to zero
            //
            if (lastTexture == null) {
                i = 0;
                while (i < visualNumVertices) {
                    tcoord_list[tcoord_floats++] = 0;
                    tcoord_list[tcoord_floats++] = 0;
                    tcoord_list[tcoord_floats++] = 0;
                    tcoord_list[tcoord_floats++] = 0;
                    i++;
                }
            }

            // Single color
            //
            if (meshSingleColor) {
                i = 0;
                while (i < visualNumVertices) {
                    color_list[color_floats++] = r;
                    color_list[color_floats++] = g;
                    color_list[color_floats++] = b;
                    color_list[color_floats++] = a;
                    i++;
                }
            }

            // Increase counts
            z += 0.001;
            dynamic_batched_count++;
            vert_count += visualNumVertices;

        } //drawMesh

        // For each ceramic visual in the list
        //
        if (ceramicVisuals != null) {
            for (ii in 0...ceramicVisuals.length) {
                var visual = ceramicVisuals.unsafeGet(ii);

                quad = visual.quad;
                mesh = visual.mesh;

                // If it's valid to be drawn
                if (visual.computedVisible) {

                    // If it should be redrawn anyway
                    if (visual.computedRenderTarget == null || visual.computedRenderTarget.renderDirty) {

                        if (visual.computedClip && visual.computedRenderTarget == null) {
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
                            lastClip = clip;

                            if (lastClip != null) {
                                // Update stencil buffer
                                flush();
                                GL.stencilMask(0xFF);
                                GL.clearStencil(0xFF);
                                GL.clear(GL.STENCIL_BUFFER_BIT);
                                GL.enable(GL.STENCIL_TEST);

                                GL.stencilOp(GL.KEEP, GL.KEEP, GL.REPLACE);

                                GL.stencilFunc(GL.ALWAYS, 1, 0xFF);
                                GL.stencilMask(0xFF);
                                //GL.depthMask(false);
                                GL.colorMask(false, false, false, false);

                                if (lastClip.quad != null) {
                                    quad = lastClip.quad;
                                    stencilClip = true;
                                    drawQuad();
                                    stencilClip = false;
                                    quad = visual.quad;
                                }
                                else if (lastClip.mesh != null) {
                                    mesh = lastClip.mesh;
                                    stencilClip = true;
                                    drawMesh();
                                    stencilClip = false;
                                    mesh = visual.mesh;
                                }

                                // Next things to be drawn will be clipped
                                flush();
                                GL.stencilFunc(GL.EQUAL, 1, 0xFF);
                                GL.stencilMask(0x00);
                                //GL.depthMask(true);
                                GL.colorMask(true, true, true, true);
                            }
                            else {

                                // Clipping gets disabled
                                flush();
                                GL.disable(GL.STENCIL_TEST);
                            }
                        }

                        if (quad != null && !quad.transparent) {

                            drawQuad();

                        } //quad

                        else if (mesh != null) {

                            drawMesh();

                        } //mesh
                    }
                }
            }
        } //visual list

        // If there is anything left in the vertex buffer, submit it.
        if (pos_floats != 0) {
            flush();
        }

        // Disable any states set by the batches
        //
        if (lastTextureId != #if snow_web null #else 0 #end) {
            // Remove bound texture
            renderer.state.activeTexture(GL.TEXTURE0 + lastTextureSlot);
            //renderer.state.bindTexture2D(null);
        }

        // Remove any render target
        if (lastRenderTarget != null) {
            renderer.target = null;
            view.transform.scale.x = defaultTransformScaleX;
            view.transform.scale.y = defaultTransformScaleY;
            view.viewport = defaultViewport;
        }

        // Mark all render textures as non-dirty now that rendering has finished
        for (ii in 0...allRenderTextures.length) {
            var renderTexture = allRenderTextures.unsafeGet(ii);
            renderTexture.renderDirty = false;
        }

        // Remove shader program
        renderer.state.useProgram(#if snow_web null #else 0 #end);
    
        // Restore default blend mode
        renderer.state.enable(GL.BLEND);
        GL.blendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
        GL.blendEquation(GL.FUNC_ADD);

        // Restore default stencil test
        GL.disable(GL.STENCIL_TEST);
        GL.stencilFunc(GL.ALWAYS, 1, 0xFF);
        GL.stencilMask(0x00);
        //GL.depthMask(true);
        GL.colorMask(true, true, true, true);

        prune();

#if ceramic_debug_draw
        if (debugDraw) trace('CeramicBatched.batch() drawCalls=' + draw_calls + ' visuals=' + ceramicVisuals.length + ' drawnQuads=' + drawnQuads + ' drawnMeshes=' + drawnMeshes);
#end

    } //batch

    #if (!ceramic_debug_draw && !telemetry) inline #end function flush():Bool {

        if (pos_floats == 0) {
            return false;
        }

        if (pos_floats > max_floats) {
            throw 'Too many floats are being submitted (max:$max_floats, attempt:$pos_floats).';
        }

        var vertexSize = 4;
        if (activeShader != null) {
            var allAttrs = activeShader.customAttributes;
            if (allAttrs != null) {
                for (ii in 0...allAttrs.length) {
                    var attr = allAttrs.unsafeGet(ii);
                    vertexSize += attr.size;
                }
            }
        }

        // fromBuffer takes byte length, so floats * 4
        var _pos = Float32Array.fromBuffer(pos_list.buffer, 0, pos_floats * 4 #if cpp , view_pos #end);
        var _tcoords = Float32Array.fromBuffer(tcoord_list.buffer, 0, tcoord_floats * 4 #if cpp , view_tcoords #end);
        var _colors = Float32Array.fromBuffer(color_list.buffer, 0, color_floats * 4 #if cpp , view_colors #end);

        // -- Begin submit

        var pb = GL.createBuffer();
        var cb = GL.createBuffer();
        var tb = GL.createBuffer();

        GL.bindBuffer(GL.ARRAY_BUFFER, pb);
        GL.vertexAttribPointer(vert_attribute, 4, GL.FLOAT, false, vertexSize * 4, 0);
        GL.bufferData(GL.ARRAY_BUFFER, _pos, GL.STREAM_DRAW);

        GL.bindBuffer(GL.ARRAY_BUFFER, tb);
        GL.vertexAttribPointer(tcoord_attribute, 4, GL.FLOAT, false, 0, 0);
        GL.bufferData(GL.ARRAY_BUFFER, _tcoords, GL.STREAM_DRAW);

        GL.bindBuffer(GL.ARRAY_BUFFER, cb);
        GL.vertexAttribPointer(color_attribute, 4, GL.FLOAT, false, 0, 0);
        GL.bufferData(GL.ARRAY_BUFFER, _colors, GL.STREAM_DRAW);

        var customGLBuffersLen:Int = 0;
        if (activeShader != null && activeShader.customAttributes != null) {

            var n = color_attribute + 1;
            var offset = 4;
            var allAttrs = activeShader.customAttributes;
            customGLBuffersLen = allAttrs.length;
            for (ii in 0...customGLBuffersLen) {
                var attr = allAttrs.unsafeGet(ii);

                var b = GL.createBuffer();
                customGLBuffers[ii] = b;

                GL.enableVertexAttribArray(n);
                GL.bindBuffer(GL.ARRAY_BUFFER, b);
                GL.vertexAttribPointer(n, attr.size, GL.FLOAT, false, vertexSize * 4, offset * 4);
                GL.bufferData(GL.ARRAY_BUFFER, _pos, GL.STREAM_DRAW);

                n++;
                offset += attr.size;

            }
        }

        // Draw
        GL.drawArrays(primitiveType, 0, Std.int(_colors.length/4));

        GL.deleteBuffer(pb);
        GL.deleteBuffer(cb);
        GL.deleteBuffer(tb);

        if (customGLBuffersLen > 0) {
            var n = color_attribute + 1;
            for (ii in 0...customGLBuffersLen) {
                var b = customGLBuffers.unsafeGet(ii);
                GL.deleteBuffer(b);
                GL.disableVertexAttribArray(n);
                n++;
            }
        }

        draw_calls++;

        // -- End submit

        _pos = null;
        _tcoords = null;
        _colors = null;

        pos_floats = 0;
        tcoord_floats = 0;
        color_floats = 0;

#if ceramic_batch_multiple_buffers
        buffers_index = (buffers_index + 1) % NUM_BUFFERS;
        pos_list = pos_list_array[buffers_index];
        tcoord_list = tcoord_list_array[buffers_index];
        color_list = color_list_array[buffers_index];
#end

        return true;

    } //flush

    #if !telemetry inline #end public function useShader(_shader:backend.impl.CeramicShader) {

        activeShader = _shader;

        if (!_shader.no_default_uniforms) {
            _shader.set_matrix4_arr('projectionMatrix', view.proj_arr);
            _shader.set_matrix4_arr('modelViewMatrix', view.view_inverse_arr);
        }

        // Custom attributes?
        customFloatAttributesSize = 0;
        if (activeShader != null) {
            var allAttrs = activeShader.customAttributes;
            if (allAttrs != null) {
                for (ii in 0...allAttrs.length) {
                    var attr = allAttrs.unsafeGet(ii);
                    customFloatAttributesSize += attr.size;
                }
            }
        }

    } //applyDefaultUniforms

} //CeramicBatcher

#end
