package backend.impl;

/** A custom luxe/phoenix batcher for ceramic. */
class CeramicBatcher extends Batcher {

    public var ceramicVisuals:Array<ceramic.Visual> = null;

    public function batch( persist_immediate : Bool = false ) {

        // Reset render stats before we start
        dynamic_batched_count = 0;
        static_batched_count = 0;
        visible_count = 0;

        pos_floats = 0;
        tcoord_floats = 0;
        color_floats = 0;
        normal_floats = 0;

        var visualNumVertices = 0;
        var quad:ceramic.Quad = null;

        var lastTexture:ceramic.Texture = null;
        var lastTextureId:phoenix.TextureID = null;
        var lastShader:ceramic.Shader = null;
        var lastBlend:ceramic.Blending = Blending.NORMAL;
        var lastClip = false;
        var lastClipX = 0.0;
        var lastClipY = 0.0;
        var lastClipW = 0.0;
        var lastClipH = 0.0;

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
                                    (lastTexture.backendItem : phoenix.Texture).bind();
                                }
                            } else {
                                if (quad.texture != null) {
                                    lastTexture = quad.texture;
                                    lastTextureId = (quad.texture.backendItem : phoenix.Texture).texture;
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
                    visual_num_vertices = 6; // TODO check this is correct

                    // Batch geometry
                    // TODO batch

                    // Increase counts
                    dynamic_batched_count++;
                    vert_count += visual_num_vertices;

                } //quad
            }
        } //visual list

        // If there is anything left in the vertex buffer, submit it.
        // TODO

        // Disable any states set by the batches
        //state.deactivate(this);
        // Cleanup
        //state = null;

        prune();

    } //batch

    inline function flush():Void {

        // TODO

    } //flush

} //CeramicBatcher
