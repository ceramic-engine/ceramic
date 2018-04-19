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
    var activeShader:backend.impl.CeramicShader = null;
    var customFloatAttributesSize:Int = 0;

    override function batch(persist_immediate:Bool = false) {

        if (ceramic.App.app.defaultColorShader == null) return;

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
        var lastTextureSlot:Int = 0;
        var lastShader:ceramic.Shader = null;
        var lastBlend:ceramic.Blending = ceramic.Blending.NORMAL;
        
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
        
        // Initialize default state
        renderer.state.activeTexture(GL.TEXTURE0 + lastTextureSlot);
        //renderer.state.bindTexture2D(null);
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

        #if !debug inline #end function drawQuad() {

            if (stencilClip) {
                // Special case of drawing into stencil buffer

                // No texture
                if (lastShader == null && quad.shader == null) {
                    // Default plain shader fallback
                    useShader(defaultPlainShader);
                    defaultPlainShader.activate();
                }
                lastTexture = null;
                lastTextureId = null;
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
                lastBlend = ceramic.Blending.NORMAL;

                stateDirty = false;
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
                            quad.blending != lastBlend;
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
                                lastTextureSlot = (quad.texture.backendItem : phoenix.Texture).slot;
                                texWidthActual = (quad.texture.backendItem : phoenix.Texture).width_actual;
                                texHeightActual = (quad.texture.backendItem : phoenix.Texture).height_actual;
                                (lastTexture.backendItem : phoenix.Texture).bind();
                            }
                        } else {
                            if (quad.texture != null) {
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
                                if (lastShader == null && quad.shader == null) {
                                    // Default plain shader fallback
                                    useShader(defaultPlainShader);
                                    defaultPlainShader.activate();
                                }
                                lastTexture = null;
                                lastTextureId = null;
                                renderer.state.activeTexture(GL.TEXTURE0 + lastTextureSlot);
                                renderer.state.bindTexture2D(null);
                            }
                        }
                    }

                    // Update shader
                    if (quad.shader != lastShader) {
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

        #if !debug inline #end function drawMesh() {

            // The following code is doing pretty much the same thing as quads, but for meshes.
            // We could try to refactor to prevent redundancy but this is not required as our
            // main concern here is raw performance and anyway this code won't be updated often.

            if (stencilClip) {
                // Special case of drawing into stencil buffer

                // No texture
                if (lastShader == null && quad.shader == null) {
                    // Default plain shader fallback
                    useShader(defaultPlainShader);
                    defaultPlainShader.activate();
                }
                lastTexture = null;
                lastTextureId = null;
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
                lastBlend = ceramic.Blending.NORMAL;

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
                                if (lastShader == null && mesh.shader == null) {
                                    // Default plain shader fallback
                                    useShader(defaultPlainShader);
                                    defaultPlainShader.activate();
                                }
                                lastTexture = null;
                                lastTextureId = null;
                                renderer.state.activeTexture(GL.TEXTURE0 + lastTextureSlot);
                                //renderer.state.bindTexture2D(null);
                            }
                        }
                    }

                    // Update shader
                    if (mesh.shader != lastShader) {
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
                }
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
            for (visual in ceramicVisuals) {

                quad = visual.quad;
                mesh = visual.mesh;

                // If it's valid to be drawn
                if (visual.computedVisible) {

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
                            GL.depthMask(false);
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
                            GL.depthMask(true);
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
        } //visual list

        // If there is anything left in the vertex buffer, submit it.
        if (pos_floats != 0) {
            flush();
        }

        // Disable any states set by the batches
        //
        if (lastTextureId != null) {
            // Remove bound texture
            renderer.state.activeTexture(GL.TEXTURE0 + lastTextureSlot);
            //renderer.state.bindTexture2D(null);
        }
        // Remove shader program
        renderer.state.useProgram(null);
    
        // Restore default blend mode
        renderer.state.enable(GL.BLEND);
        GL.blendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
        GL.blendEquation(GL.FUNC_ADD);

        // Restore default stencil test
        GL.disable(GL.STENCIL_TEST);
        GL.stencilFunc(GL.ALWAYS, 1, 0xFF);
        GL.stencilMask(0x00);
        GL.depthMask(true);
        GL.colorMask(true, true, true, true);

        prune();

    } //batch

    inline function flush():Bool {

        if (pos_floats == 0) {
            return false;
        }

        if (pos_floats > max_floats) {
            throw "Too many floats are being submitted (max:$max_floats, attempt:$pos_floats).";
        }

        var vertexSize = 4;
        if (activeShader != null && activeShader.customAttributes != null) {
            for (attr in activeShader.customAttributes) {
                vertexSize += attr.size;
            }
        }

        // fromBuffer takes byte length, so floats * 4
        var _pos = Float32Array.fromBuffer(pos_list.buffer, 0, pos_floats * 4);
        var _tcoords = Float32Array.fromBuffer(tcoord_list.buffer, 0, tcoord_floats * 4);
        var _colors = Float32Array.fromBuffer(color_list.buffer, 0, color_floats * 4);

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

        var customGLBuffers = null;
        if (activeShader != null && activeShader.customAttributes != null) {

            var n = color_attribute + 1;
            var offset = 4;
            for (attr in activeShader.customAttributes) {

                var b = GL.createBuffer();
                if (customGLBuffers == null) customGLBuffers = [];
                customGLBuffers.push(b);

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

        if (customGLBuffers != null) {
            var n = color_attribute + 1;
            for (b in customGLBuffers) {
                GL.deleteBuffer(b);
                GL.disableVertexAttribArray(n);
                n++;
            }
        }
        customGLBuffers = null;

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

    inline public function useShader(_shader:backend.impl.CeramicShader) {

        activeShader = _shader;

        if (!_shader.no_default_uniforms) {
            _shader.set_matrix4_arr('projectionMatrix', view.proj_arr);
            _shader.set_matrix4_arr('modelViewMatrix', view.view_inverse_arr);
        }

        // Custom attributes?
        customFloatAttributesSize = 0;
        if (activeShader != null && activeShader.customAttributes != null) {
            for (attr in activeShader.customAttributes) {
                customFloatAttributesSize += attr.size;
            }
        }

    } //applyDefaultUniforms

} //CeramicBatcher
