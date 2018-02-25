package backend.impl;

import phoenix.Texture;

import snow.modules.opengl.GL;
import snow.api.buffers.Float32Array;

/** A custom luxe/phoenix batcher for ceramic. */
class CeramicBatcher extends phoenix.Batcher {

    public var ceramicVisuals:Array<ceramic.Visual> = null;

    override function batch(persist_immediate:Bool = false) {

        // Reset render stats before we start
        dynamic_batched_count = 0;
        static_batched_count = 0;
        visible_count = 0;

        var len = 0;
        var countAfter = 0;
        var bufferVertices = 0;
        var maxVertFloats = max_verts * 4;

        pos_floats = 0;
        tcoord_floats = 0;
        color_floats = 0;
        normal_floats = 0;

        var visualNumVertices = 0;
        var quad:ceramic.Quad = null;

        var lastTexture:ceramic.Texture = null;
        var lastTextureId:phoenix.TextureID = null;
        var lastShader:ceramic.Shader = null;
        var lastBlend:ceramic.Blending = ceramic.Blending.NORMAL;
        var lastClip = false;
        var lastClipX = 0.0;
        var lastClipY = 0.0;
        var lastClipW = 0.0;
        var lastClipH = 0.0;

        var vertIndex = 0;
        var i:Int = 0;
        var z:Float = 0;

        var r:Float;
        var g:Float;
        var b:Float;
        var a:Float;

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

        var texWidthActual:Float = 0;
        var texHeightActual:Float = 0;

        var stateDirty = true;
        var luxeShader:phoenix.Shader = null;
        var defaultPlainShader:phoenix.Shader = renderer.shaders.plain.shader;
        var defaultTexturedShader:phoenix.Shader = renderer.shaders.textured.shader;
        
        // Initialize default state
        Luxe.renderer.state.bindTexture2D(null);
        renderer.state.enable(GL.BLEND);
        defaultPlainShader.activate();
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

        // For each ceramic visual in the list
        if (ceramicVisuals != null) {
            for (visual in ceramicVisuals) {

                quad = (visual.backendItem == QUAD) ? cast(visual, ceramic.Quad) : null;

                // If it's valid to be drawn
                if (visual.visible && quad != null) {

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
                                quad.blending != lastBlend;
                                // TODO clip
                        }
                    }

                    if (stateDirty) {
                        flush();

                        // Update texture
                        if (quad.texture != lastTexture) {
                            if (quad.texture != null && lastTexture != null) {
                                if ((quad.texture.backendItem : phoenix.Texture).texture != lastTextureId) {
                                    lastTexture = quad.texture;
                                    lastTextureId = (quad.texture.backendItem : phoenix.Texture).texture;
                                    texWidthActual = (quad.texture.backendItem : phoenix.Texture).width_actual;
                                    texHeightActual = (quad.texture.backendItem : phoenix.Texture).height_actual;
                                    (lastTexture.backendItem : phoenix.Texture).bind();
                                }
                            } else {
                                if (quad.texture != null) {
                                    lastTexture = quad.texture;
                                    lastTextureId = (quad.texture.backendItem : phoenix.Texture).texture;
                                    texWidthActual = (quad.texture.backendItem : phoenix.Texture).width_actual;
                                    texHeightActual = (quad.texture.backendItem : phoenix.Texture).height_actual;
                                    (lastTexture.backendItem : phoenix.Texture).bind();
                                } else {
                                    lastTexture = null;
                                    lastTextureId = null;
                                    Luxe.renderer.state.bindTexture2D(null);
                                }
                            }
                        }

                        // Update shader
                        if (quad.shader != lastShader) {
                            lastShader = quad.shader;

                            if (lastShader != null) {
                                // Default
                                (lastShader.backendItem : phoenix.Shader).activate();
                            }
                            else if (lastTexture != null) {
                                // Default textured shader fallback
                                defaultTexturedShader.activate();
                            }
                            else {
                                // Default plain shader fallback
                                defaultPlainShader.activate();
                            }
                        }

                        // Update blending
                        if (quad.blending != lastBlend) {
                            lastBlend = quad.blending;
                            if (lastBlend == ceramic.Blending.ADD) {
                                GL.blendFuncSeparate(
                                    //src_rgb
                                    phoenix.Batcher.BlendMode.one,
                                    //dest_rgb
                                    phoenix.Batcher.BlendMode.one,
                                    //src_alpha
                                    phoenix.Batcher.BlendMode.one,
                                    //dest_alpha
                                    phoenix.Batcher.BlendMode.one
                                );
                            } else {
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
                            }
                        }
                    }

                    visible_count++;

                    // Update num vertices
                    visualNumVertices = 6;

                    // Batch visual
                    //
                    countAfter = pos_floats + visualNumVertices * 4;

                    // Submit the current batch if we exceed the max buffer size
                    if (countAfter > maxVertFloats) {
                        flush();
                    }

                    // Batch visual
                    //
                    // Update size
                    if (quad.rotateFrame == ceramic.RotateFrame.ROTATE_90) {
                        w = quad.height;
                        h = quad.width;
                    } else {
                        w = quad.width;
                        h = quad.height;
                    }

                    matA = quad.a;
                    matB = quad.b;
                    matC = quad.c;
                    matD = quad.d;
                    matTX = quad.tx;
                    matTY = quad.ty;

                    //tl
                    pos_list[pos_floats] = matTX;
                    pos_list[pos_floats+1] = matTY;
                    pos_list[pos_floats+2] = z;
                    pos_list[pos_floats+3] = 0;
                    //tr
                    pos_list[pos_floats+4] = matA * w;
                    pos_list[pos_floats+5] = matB * w;
                    pos_list[pos_floats+6] = z;
                    pos_list[pos_floats+7] = 0;
                    //br
                    pos_list[pos_floats+8] = matA * w + matC * h;
                    pos_list[pos_floats+9] = matB * w + matD * h;
                    pos_list[pos_floats+10] = z;
                    pos_list[pos_floats+11] = 0;
                    //bl
                    pos_list[pos_floats+12] = matC * h;
                    pos_list[pos_floats+13] = matD * h;
                    pos_list[pos_floats+14] = z;
                    pos_list[pos_floats+15] = 0;
                    //tl2
                    pos_list[pos_floats+16] = pos_list[pos_floats];
                    pos_list[pos_floats+17] = pos_list[pos_floats+1];
                    pos_list[pos_floats+18] = pos_list[pos_floats+2];
                    pos_list[pos_floats+19] = 0;
                    //br2
                    pos_list[pos_floats+20] = pos_list[pos_floats+8];
                    pos_list[pos_floats+21] = pos_list[pos_floats+9];
                    pos_list[pos_floats+22] = pos_list[pos_floats+10];
                    pos_list[pos_floats+23] = 0;

                    pos_floats += 24;

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
                    a = quad.computedAlpha;
                    r = quad.color.redFloat * a;
                    g = quad.color.greenFloat * a;
                    b = quad.color.blueFloat * a;

                    i = 0;
                    while (i < 24) {
                        color_list[color_floats++] = r;
                        color_list[color_floats++] = g;
                        color_list[color_floats++] = b;
                        color_list[color_floats++] = a;
                        i += 4;
                    }

                    // Increase counts
                    z++;
                    dynamic_batched_count++;
                    vert_count += visualNumVertices;

                } //quad
            }
        } //visual list

        // If there is anything left in the vertex buffer, submit it.
        if (pos_floats > 0) {
            flush();
        }

        // Disable any states set by the batches
        //
        if (lastTextureId != null) {
            // Remove bound texture
            renderer.state.bindTexture2D(null);
        }
        // Remove shader program
        renderer.state.useProgram(null);
        if (lastClip) {
            // Remove clipping
            GL.disable(GL.SCISSOR_TEST);
        }
        // Restore default blend mode
        renderer.state.enable(GL.BLEND);
        GL.blendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
        GL.blendEquation(GL.FUNC_ADD);

        prune();

    } //batch

    inline function flush():Void {

        // TODO

    } //flush

} //CeramicBatcher
