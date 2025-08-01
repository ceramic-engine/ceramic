package spec;

import backend.VisualItem;

/**
 * Backend interface for all graphics rendering operations.
 * 
 * This is the core rendering interface that backends must implement to draw Ceramic visuals.
 * It provides low-level GPU operations including vertex/index buffer management, texture binding,
 * shader usage, blending modes, and render state management.
 * 
 * The interface follows a stateful design where rendering state (textures, shaders, blend modes)
 * is set before drawing operations. Vertex data is accumulated in buffers and flushed to the GPU
 * when necessary.
 * 
 * Drawing flow:
 * 1. beginRender() - Start a frame
 * 2. Set states (shader, texture, blend mode)
 * 3. Add vertices/indices for visuals
 * 4. flush() when buffers are full or state changes
 * 5. swap() - Present the frame
 */
interface Draw {

    /**
     * Main drawing function that renders an array of visuals.
     * This is typically called once per frame with all visible visuals sorted by depth.
     * The implementation should iterate through visuals and generate appropriate draw calls.
     * @param visuals Array of Visual objects to render, pre-sorted by rendering order
     */
    function draw(visuals:Array<ceramic.Visual>):Void;

    /**
     * Swaps the back buffer to the front buffer, presenting the rendered frame.
     * This should be called after all drawing is complete for the frame.
     */
    function swap():Void;

    /**
     * Initializes or resets the vertex and index buffers.
     * Called during initialization and when buffers need to be recreated.
     */
    function initBuffers():Void;

    /**
     * Begins a new rendering frame.
     * Sets up initial render state and prepares for drawing operations.
     */
    function beginRender():Void;

    /**
     * Sets the current render target for subsequent draw operations.
     * Pass null to render to the main framebuffer.
     * @param renderTarget The RenderTexture to draw into, or null for the main framebuffer
     * @param force If true, forces the render target change even if it appears to be the same
     */
    function setRenderTarget(renderTarget:ceramic.RenderTexture, force:Bool = false):Void;

    /**
     * Activates a shader program for subsequent draw operations.
     * All following geometry will be rendered with this shader until changed.
     * @param shader The shader program to use
     */
    function useShader(shader:backend.Shader):Void;

    /**
     * Clears the current render target (color and depth buffers).
     * The clear color is determined by the current background color.
     */
    function clear():Void;

    /**
     * Enables alpha blending for subsequent draw operations.
     * The blend function should be set with setBlendFuncSeparate().
     */
    function enableBlending():Void;

    /**
     * Disables alpha blending for subsequent draw operations.
     * Pixels will be written directly without blending.
     */
    function disableBlending():Void;

    /**
     * Sets the blending function for both RGB and alpha channels separately.
     * This controls how source pixels are combined with destination pixels.
     * @param srcRgb Source blend factor for RGB channels
     * @param dstRgb Destination blend factor for RGB channels
     * @param srcAlpha Source blend factor for alpha channel
     * @param dstAlpha Destination blend factor for alpha channel
     */
    function setBlendFuncSeparate(srcRgb:backend.BlendMode, dstRgb:backend.BlendMode, srcAlpha:backend.BlendMode, dstAlpha:backend.BlendMode):Void;

    /**
     * Gets the currently active texture slot (0-based index).
     * @return The active texture slot number
     */
    function getActiveTexture():Int;

    /**
     * Sets the active texture slot for multi-texturing.
     * Subsequent texture binds will affect this slot.
     * @param slot The texture slot to activate (0-based)
     */
    function setActiveTexture(slot:Int):Void;

    /**
     * Checks if a backend texture matches a given texture ID.
     * Used for texture state tracking and validation.
     * @param backendItem The backend texture to check
     * @param textureId The texture ID to compare against
     * @return True if the texture matches the ID
     */
    function textureBackendItemMatchesId(backendItem:backend.Texture, textureId:backend.TextureId):Bool;

    /**
     * Gets the unique identifier for a backend texture.
     * @param backendItem The backend texture
     * @return The texture's unique ID
     */
    function getTextureId(backendItem:backend.Texture):backend.TextureId;

    /**
     * Binds a texture to the current texture slot for rendering.
     * Subsequent draw calls will use this texture.
     * @param backendItem The texture to bind
     */
    function bindTexture(backendItem:backend.Texture):Void;

    /**
     * Unbinds any texture from the current texture slot.
     * Used when rendering untextured geometry.
     */
    function bindNoTexture():Void;

    /**
     * Sets the primitive type for subsequent geometry.
     * @param primitiveType The primitive type (TRIANGLE or LINE)
     */
    function setPrimitiveType(primitiveType:ceramic.RenderPrimitiveType):Void;

    /**
     * Begins drawing a Quad visual.
     * Called before adding the quad's vertices to the buffer.
     * @param quad The Quad being drawn
     */
    function beginDrawQuad(quad:ceramic.Quad):Void;

    /**
     * Ends drawing a Quad visual.
     * Called after the quad's vertices have been added.
     */
    function endDrawQuad():Void;

    /**
     * Begins drawing a Mesh visual.
     * Called before adding the mesh's vertices to the buffer.
     * @param mesh The Mesh being drawn
     */
    function beginDrawMesh(mesh:ceramic.Mesh):Void;

    /**
     * Ends drawing a Mesh visual.
     * Called after the mesh's vertices have been added.
     */
    function endDrawMesh():Void;

    /**
     * Begins drawing into the stencil buffer.
     * Subsequent draw calls will write to the stencil buffer instead of color buffer.
     * Used for masking operations.
     */
    function beginDrawingInStencilBuffer():Void;

    /**
     * Ends drawing into the stencil buffer.
     * Returns to normal color buffer rendering.
     */
    function endDrawingInStencilBuffer():Void;

    /**
     * Enables stencil testing for subsequent draw operations.
     * Only pixels passing the stencil test will be rendered.
     */
    function drawWithStencilTest():Void;

    /**
     * Disables stencil testing for subsequent draw operations.
     * All pixels will be rendered regardless of stencil buffer contents.
     */
    function drawWithoutStencilTest():Void;

    /**
     * Enables scissor testing with the specified rectangle.
     * Only pixels within this rectangle will be rendered.
     * @param x The left edge of the scissor rectangle
     * @param y The top edge of the scissor rectangle
     * @param width The width of the scissor rectangle
     * @param height The height of the scissor rectangle
     */
    function enableScissor(x:Float, y:Float, width:Float, height:Float):Void;

    /**
     * Disables scissor testing.
     * Rendering will no longer be clipped to a rectangle.
     */
    function disableScissor():Void;

    /**
     * Gets the number of vertices currently in the vertex buffer.
     * @return The current vertex count
     */
    function getNumPos():Int;

    /**
     * Adds a vertex position to the vertex buffer.
     * @param x The X coordinate
     * @param y The Y coordinate
     * @param z The Z coordinate (depth)
     */
    function putPos(x:Float, y:Float, z:Float):Void;

    /**
     * Adds a vertex position with texture slot to the vertex buffer.
     * Used for multi-textured rendering.
     * @param x The X coordinate
     * @param y The Y coordinate
     * @param z The Z coordinate (depth)
     * @param textureSlot The texture slot index for this vertex
     */
    function putPosAndTextureSlot(x:Float, y:Float, z:Float, textureSlot:Float):Void;

    /**
     * Adds an index to the index buffer.
     * Indices reference vertices in the vertex buffer.
     * @param i The vertex index
     */
    function putIndice(i:Int):Void;

    /**
     * Adds texture coordinates to the vertex buffer.
     * Must be called after putPos() for each vertex.
     * @param uvX The U (horizontal) texture coordinate (0.0 to 1.0)
     * @param uvY The V (vertical) texture coordinate (0.0 to 1.0)
     */
    function putUVs(uvX:Float, uvY:Float):Void;

    /**
     * Adds vertex color to the vertex buffer.
     * Must be called after putUVs() for each vertex.
     * @param r Red component (0.0 to 1.0)
     * @param g Green component (0.0 to 1.0)
     * @param b Blue component (0.0 to 1.0)
     * @param a Alpha component (0.0 to 1.0)
     */
    function putColor(r:Float, g:Float, b:Float, a:Float):Void;

    /**
     * Begins adding custom float attributes to vertices.
     * Called before putFloatAttribute() for custom shader attributes.
     */
    function beginFloatAttributes():Void;

    /**
     * Adds a custom float attribute value for the current vertex.
     * Used with custom shaders that require additional per-vertex data.
     * @param index The attribute index (defined by the shader)
     * @param value The attribute value
     */
    function putFloatAttribute(index:Int, value:Float):Void;

    /**
     * Ends adding custom float attributes to vertices.
     * Called after all putFloatAttribute() calls for a vertex.
     */
    function endFloatAttributes():Void;

    /**
     * Clears the screen and applies the current background color/image.
     * Typically called at the start of each frame.
     */
    function clearAndApplyBackground():Void;

    /**
     * Gets the logical width of a texture (may be smaller than actual GPU texture).
     * @param texture The texture to query
     * @return The logical width in pixels
     */
    function getTextureWidth(texture:backend.Texture):Int;

    /**
     * Gets the logical height of a texture (may be smaller than actual GPU texture).
     * @param texture The texture to query
     * @return The logical height in pixels
     */
    function getTextureHeight(texture:backend.Texture):Int;

    /**
     * Gets the actual GPU texture width (may be power-of-two padded).
     * @param texture The texture to query
     * @return The actual GPU texture width in pixels
     */
    function getTextureWidthActual(texture:backend.Texture):Int;

    /**
     * Gets the actual GPU texture height (may be power-of-two padded).
     * @param texture The texture to query
     * @return The actual GPU texture height in pixels
     */
    function getTextureHeightActual(texture:backend.Texture):Int;

    /**
     * Checks if the buffers should be flushed before adding more geometry.
     * @param numVerticesAfter Number of vertices that would be in buffer after adding
     * @param numIndicesAfter Number of indices that would be in buffer after adding
     * @param customFloatAttributesSize Size of custom float attributes per vertex
     * @return True if buffers should be flushed first
     */
    function shouldFlush(numVerticesAfter:Int, numIndicesAfter:Int, customFloatAttributesSize:Int):Bool;

    /**
     * Gets the number of vertices that can still be added before flushing.
     * @return The remaining vertex capacity
     */
    function remainingVertices():Int;

    /**
     * Gets the number of indices that can still be added before flushing.
     * @return The remaining index capacity
     */
    function remainingIndices():Int;

    /**
     * Checks if there is any geometry in the buffers to flush.
     * @return True if there are vertices/indices to flush
     */
    function hasAnythingToFlush():Bool;

    /**
     * Flushes all buffered geometry to the GPU.
     * Sends the accumulated vertices and indices as a draw call.
     * This must be called when:
     * - Buffers are full
     * - Render state changes (texture, shader, etc.)
     * - Frame is complete
     */
    function flush():Void;

}
