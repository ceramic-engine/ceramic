package backend.impl;

import phoenix.Texture;

import snow.modules.opengl.GL;
import snow.api.buffers.Float32Array;

using ceramic.Extensions;

/** A custom luxe/phoenix batcher for ceramic. */
class CeramicBatcher extends phoenix.Batcher {

    public static inline var vert_attribute   : Int = 0;
    public static inline var tcoord_attribute : Int = 1;
    public static inline var color_attribute  : Int = 2;

    public var ceramicVisuals:Array<ceramic.Visual> = null;

    var primitiveType = phoenix.Batcher.PrimitiveType.triangles;

    override function batch(persist_immediate:Bool = false) {

        //trace('CeramicBatcher.batch() ' + ceramic.Timer.now + ' visuals=' + (ceramicVisuals != null ? ceramicVisuals.length : 0));

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
        var mesh:ceramic.Mesh = null;

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
        var j:Int = 0;
        var k:Int = 0;
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
        var luxeShader:phoenix.Shader = null;
        var defaultPlainShader:phoenix.Shader = renderer.shaders.plain.shader;
        var defaultTexturedShader:phoenix.Shader = renderer.shaders.textured.shader;
        
        // Initialize default state
        Luxe.renderer.state.bindTexture2D(null);
        renderer.state.enable(GL.BLEND);
        apply_default_uniforms(defaultPlainShader);
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

                quad = visual.quad;
                mesh = visual.mesh;

                // If it's valid to be drawn
                if (visual.computedVisible) {
                    if (quad != null && !quad.transparent) {

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
                                        if (lastShader == null && quad.shader == null) {
                                            // Default textured shader fallback
                                            apply_default_uniforms(defaultTexturedShader);
                                            defaultTexturedShader.activate();
                                        }
                                        lastTexture = quad.texture;
                                        lastTextureId = (quad.texture.backendItem : phoenix.Texture).texture;
                                        texWidthActual = (quad.texture.backendItem : phoenix.Texture).width_actual;
                                        texHeightActual = (quad.texture.backendItem : phoenix.Texture).height_actual;
                                        (lastTexture.backendItem : phoenix.Texture).bind();
                                    } else {
                                        if (lastShader == null && quad.shader == null) {
                                            // Default plain shader fallback
                                            apply_default_uniforms(defaultPlainShader);
                                            defaultPlainShader.activate();
                                        }
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
                                    // Custom shader
                                    apply_default_uniforms((lastShader.backendItem : phoenix.Shader));
                                    (lastShader.backendItem : phoenix.Shader).activate();
                                }
                                else if (lastTexture != null) {
                                    // Default textured shader fallback
                                    apply_default_uniforms(defaultTexturedShader);
                                    defaultTexturedShader.activate();
                                }
                                else {
                                    // Default plain shader fallback
                                    apply_default_uniforms(defaultPlainShader);
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

                            stateDirty = false;
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
                        //tl
                        pos_list[pos_floats] = matTX;
                        pos_list[pos_floats+1] = matTY;
                        pos_list[pos_floats+2] = z;
                        pos_list[pos_floats+3] = 0;
                        //tr
                        pos_list[pos_floats+4] = matTX + matA * w;
                        pos_list[pos_floats+5] = matTY + matB * w;
                        pos_list[pos_floats+6] = z;
                        pos_list[pos_floats+7] = 0;
                        //br
                        pos_list[pos_floats+8] = matTX + matA * w + matC * h;
                        pos_list[pos_floats+9] = matTY + matB * w + matD * h;
                        pos_list[pos_floats+10] = z;
                        pos_list[pos_floats+11] = 0;
                        //bl
                        pos_list[pos_floats+12] = matTX + matC * h;
                        pos_list[pos_floats+13] = matTY + matD * h;
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
                        z += 0.001;
                        dynamic_batched_count++;
                        vert_count += visualNumVertices;

                    } //quad

                    else if (mesh != null) {

                        // The following code is doing pretty much the same thing as quads, but for meshes.
                        // We could try to refactor to prevent redundancy but this is not required as our
                        // main concern here is raw performance and anyway this code won't be updated often.

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
                                    mesh.blending != lastBlend;
                                    // TODO clip
                            }
                        }

                        if (stateDirty) {
                            flush();

                            // Update texture
                            if (mesh.texture != lastTexture) {
                                if (mesh.texture != null && lastTexture != null) {
                                    if ((mesh.texture.backendItem : phoenix.Texture).texture != lastTextureId) {
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
                                        if (lastShader == null && mesh.shader == null) {
                                            // Default textured shader fallback
                                            apply_default_uniforms(defaultTexturedShader);
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
                                        if (lastShader == null && mesh.shader == null) {
                                            // Default plain shader fallback
                                            apply_default_uniforms(defaultPlainShader);
                                            defaultPlainShader.activate();
                                        }
                                        lastTexture = null;
                                        lastTextureId = null;
                                        Luxe.renderer.state.bindTexture2D(null);
                                    }
                                }
                            }

                            // Update shader
                            if (mesh.shader != lastShader) {
                                lastShader = mesh.shader;

                                if (lastShader != null) {
                                    // Custom shader
                                    apply_default_uniforms((lastShader.backendItem : phoenix.Shader));
                                    (lastShader.backendItem : phoenix.Shader).activate();
                                }
                                else if (lastTexture != null) {
                                    // Default textured shader fallback
                                    apply_default_uniforms(defaultTexturedShader);
                                    defaultTexturedShader.activate();
                                }
                                else {
                                    // Default plain shader fallback
                                    apply_default_uniforms(defaultPlainShader);
                                    defaultPlainShader.activate();
                                }
                            }

                            // Update blending
                            if (mesh.blending != lastBlend) {
                                lastBlend = mesh.blending;
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

                            stateDirty = false;
                        }

                        visible_count++;

                        // Update num vertices
                        visualNumVertices = mesh.indices.length;
                        countAfter = pos_floats + visualNumVertices * 4;

                        // Submit the current batch if we exceed the max buffer size
                        if (countAfter > maxVertFloats) {
                            flush();
                        }

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
                        meshSingleColor = mesh.colorMapping == MESH;
                        meshIndicesColor = mesh.colorMapping == INDICES;
                        if (meshSingleColor) {
                            meshAlphaColor = meshColors.unsafeGet(0);
                            a = mesh.computedAlpha * meshAlphaColor.alphaFloat;
                            r = meshAlphaColor.redFloat * a;
                            g = meshAlphaColor.greenFloat * a;
                            b = meshAlphaColor.blueFloat * a;
                        }

                        // Data
                        meshUvs = mesh.uvs;
                        meshVertices = mesh.vertices;
                        meshIndices = mesh.indices;

                        // UV factor
                        if (lastTexture != null) {
                            uvFactorX = texWidth / texWidthActual;
                            uvFactorY = texHeight / texHeightActual;
                        }

                        i = 0;
                        while (i < visualNumVertices) {

                            j = meshIndices.unsafeGet(i);
                            k = j * 2;

                            // Position
                            //
                            x = meshVertices.unsafeGet(k);
                            y = meshVertices.unsafeGet(k + 1);

                            pos_list[pos_floats++] = matTX + matA * x + matC * y;
                            pos_list[pos_floats++] = matTY + matB * x + matD * y;
                            pos_list[pos_floats++] = z;
                            pos_list[pos_floats++] = 0;

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
                                meshAlphaColor = meshIndicesColor ? meshColors.unsafeGet(j) : meshColors.unsafeGet(i);

                                a = mesh.computedAlpha * meshAlphaColor.alphaFloat;
                                r = meshAlphaColor.redFloat * a;
                                g = meshAlphaColor.greenFloat * a;
                                b = meshAlphaColor.blueFloat * a;

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

                    } //mesh
                }
            }
        } //visual list

        // If there is anything left in the vertex buffer, submit it.
        if (pos_floats != 0) {
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

    inline function flush():Bool {

        if (pos_floats == 0) {
            return false;
        }

        if (pos_floats > max_floats) {
            throw "Too many floats are being submitted (max:$max_floats, attempt:$pos_floats).";
        }

        // fromBuffer takes byte length, so floats * 4
        var _pos = Float32Array.fromBuffer(pos_list.buffer, 0, pos_floats*4);
        var _tcoords = Float32Array.fromBuffer(tcoord_list.buffer, 0, tcoord_floats*4);
        var _colors = Float32Array.fromBuffer(color_list.buffer, 0, color_floats*4);

        // -- Begin submit

        var pb = GL.createBuffer();
        var cb = GL.createBuffer();
        var tb = GL.createBuffer();

        GL.bindBuffer(GL.ARRAY_BUFFER, pb);
        GL.vertexAttribPointer(vert_attribute, 4, GL.FLOAT, false, 0, 0);
        GL.bufferData(GL.ARRAY_BUFFER, _pos, GL.STREAM_DRAW);

        GL.bindBuffer(GL.ARRAY_BUFFER, tb);
        GL.vertexAttribPointer( tcoord_attribute, 4, GL.FLOAT, false, 0, 0);
        GL.bufferData(GL.ARRAY_BUFFER, _tcoords, GL.STREAM_DRAW);

        GL.bindBuffer(GL.ARRAY_BUFFER, cb);
        GL.vertexAttribPointer( color_attribute, 4, GL.FLOAT, false, 0, 0);
        GL.bufferData(GL.ARRAY_BUFFER, _colors, GL.STREAM_DRAW);

        // Draw
        GL.drawArrays(primitiveType, 0, Std.int(_pos.length/4));

        GL.deleteBuffer(pb);
        GL.deleteBuffer(cb);
        GL.deleteBuffer(tb);

        draw_calls++;

        // -- End submit

        _pos = null;
        _tcoords = null;
        _colors = null;

        pos_floats = 0;
        tcoord_floats = 0;
        color_floats = 0;

        return true;

    } //flush

} //CeramicBatcher
