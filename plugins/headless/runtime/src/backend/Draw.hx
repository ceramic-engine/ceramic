package backend;

import ceramic.Float32;

using ceramic.Extensions;

#if !no_backend_docs
/**
 * Drawing and rendering implementation for the headless backend.
 *
 * This class implements the Ceramic drawing specification but performs
 * no actual rendering operations since headless mode doesn't require
 * visual output. All drawing methods are implemented as no-ops while
 * maintaining the same interface and state tracking as other backends.
 *
 * The class maintains vertex buffers, shader state, and rendering
 * statistics for API compatibility, but doesn't perform any GPU
 * operations or produce visual output.
 *
 * This is suitable for:
 * - Automated testing of rendering logic
 * - Server-side applications that process scenes without display
 * - Performance testing of non-rendering code paths
 * - Debugging rendering logic without visual dependencies
 */
#end
@:allow(backend.Backend)
class Draw #if !completion implements spec.Draw #end {

    #if !no_backend_docs
    /** Maximum number of vertices that can be buffered before flushing */
    #end
    #if !ceramic_debug_draw_backend inline #end static var MAX_VERTS_SIZE:Int = 65536;
    #if !no_backend_docs
    /** Maximum number of indices that can be buffered before flushing */
    #end
    #if !ceramic_debug_draw_backend inline #end static var MAX_INDICES:Int = 16384;

    #if !no_backend_docs
    /** Size of each vertex in the buffer (in floats) */
    #end
    static var _vertexSize:Int = 0;
    #if !no_backend_docs
    /** Current number of indices in the buffer */
    #end
    static var _numIndices:Int = 0;

    #if !no_backend_docs
    /** Current number of positions in the buffer */
    #end
    static var _numPos:Int = 0;
    #if !no_backend_docs
    /** Current index in the position buffer */
    #end
    static var _posIndex:Int = 0;

    #if !no_backend_docs
    /** Current number of UV coordinates in the buffer */
    #end
    static var _numUVs:Int = 0;
    #if !no_backend_docs
    /** Current index in the UV buffer */
    #end
    static var _uvIndex:Int = 0;

    #if !no_backend_docs
    /** Current number of colors in the buffer */
    #end
    static var _numColors:Int = 0;
    #if !no_backend_docs
    /** Current index in the color buffer */
    #end
    static var _colorIndex:Int = 0;

    #if !no_backend_docs
    /** Current index for custom float attributes */
    #end
    static var _floatAttributesIndex:Int = 0;

    #if !no_backend_docs
    /** Currently active shader */
    #end
    static var _currentShader:ShaderImpl;

    #if !no_backend_docs
    /** Maximum number of vertices that can fit in the current configuration */
    #end
    static var _maxVerts:Int = 0;

    #if !no_backend_docs
    /** Currently active texture slot */
    #end
    static var _activeTextureSlot:Int = 0;

/// Public API

    #if !no_backend_docs
    /**
     * Creates a new headless draw implementation.
     */
    #end
    public function new() {}

    #if !no_backend_docs
    /**
     * Gets the visual item type for a given visual object.
     *
     * The backend determines how each visual should be drawn by
     * categorizing it into a VisualItem type. This allows the
     * backend to optimize drawing by avoiding type checks during
     * each draw iteration.
     *
     * @param visual The visual object to categorize
     * @return The visual item type (QUAD, MESH, or NONE)
     */
    #end
    inline public function getItem(visual:ceramic.Visual):VisualItem {

        // The backend decides how each visual should be drawn.
        // Instead of checking instance type at each draw iteration,
        // The backend provides/computes a VisualItem object when
        // a visual is instanciated that it can later re-use
        // at each draw iteration to read/store per visual data.

        if (Std.isOfType(visual, ceramic.Quad)) {
            return QUAD;
        }
        else if (Std.isOfType(visual, ceramic.Mesh)) {
            return MESH;
        }
        else {
            return NONE;
        }

    }

    #if !no_backend_docs
    /**
     * Draws an array of visual objects.
     *
     * In headless mode, this is a no-op since no visual output is required.
     *
     * @param visuals Array of visual objects to draw
     */
    #end
    public function draw(visuals:Array<ceramic.Visual>):Void {

        // Unused in headless

    }

    #if !no_backend_docs
    /**
     * Swaps the front and back buffers to display rendered content.
     *
     * In headless mode, this is a no-op since there are no buffers to swap.
     */
    #end
    public function swap():Void {

        // Unused in headless

    }

/// Rendering

    #if !no_backend_docs
    /**
     * Initializes vertex and index buffers for rendering.
     *
     * In headless mode, this is a no-op since no GPU buffers are allocated.
     */
    #end
    inline public function initBuffers():Void {

        // Unused in headless

    }

    #if !no_backend_docs
    /**
     * Begins a new rendering pass.
     *
     * In headless mode, this is a no-op since no rendering occurs.
     */
    #end
    inline public function beginRender():Void {

        // Unused in headless

    }

    #if !no_backend_docs
    /**
     * Sets the current render target.
     *
     * @param renderTarget The texture to render to (null for screen)
     * @param force Whether to force the render target change
     */
    #end
    inline public function setRenderTarget(renderTarget:ceramic.RenderTexture, force:Bool = false):Void {

        // Unused in headless

    }

    #if !no_backend_docs
    /**
     * Sets the current shader for rendering.
     *
     * This updates vertex buffer calculations and resets buffer indices
     * to accommodate the shader's attribute requirements.
     *
     * @param shader The shader implementation to use
     */
    #end
    inline public function useShader(shader:backend.ShaderImpl):Void {

        _currentShader = shader;

        var attributesSize = ceramic.App.app.backend.shaders.customFloatAttributesSize(_currentShader);
        if (attributesSize % 2 == 1) attributesSize++;

        _vertexSize = 9 + attributesSize + (ceramic.App.app.backend.shaders.canBatchWithMultipleTextures(_currentShader) ? 1 : 0);

        _maxVerts = Std.int(Math.floor(MAX_VERTS_SIZE / _vertexSize));

        if (_posIndex == 0) {
            resetIndexes();
        }

    }

    #if !no_backend_docs
    /**
     * Clears the current render target.
     *
     * In headless mode, this is a no-op since no rendering surface exists.
     */
    #end
    inline public function clear():Void {

        // Unused in headless

    }

    #if !no_backend_docs
    /**
     * Enables alpha blending for subsequent draw calls.
     *
     * In headless mode, this is a no-op since no rendering occurs.
     */
    #end
    inline public function enableBlending():Void {

        // Unused in headless

    }

    #if !no_backend_docs
    /**
     * Disables alpha blending for subsequent draw calls.
     *
     * In headless mode, this is a no-op since no rendering occurs.
     */
    #end
    inline public function disableBlending():Void {

        // Unused in headless

    }

    #if !no_backend_docs
    /**
     * Sets the blend function for RGB and alpha channels separately.
     *
     * @param srcRgb Source blend mode for RGB channels
     * @param dstRgb Destination blend mode for RGB channels
     * @param srcAlpha Source blend mode for alpha channel
     * @param dstAlpha Destination blend mode for alpha channel
     */
    #end
    inline public function setBlendFuncSeparate(srcRgb:backend.BlendMode, dstRgb:backend.BlendMode, srcAlpha:backend.BlendMode, dstAlpha:backend.BlendMode):Void {

        // Unused in headless

    }

    #if !no_backend_docs
    /**
     * Gets the currently active texture slot.
     *
     * @return The active texture slot index
     */
    #end
    inline public function getActiveTexture():Int {

        return _activeTextureSlot;

    }

    #if !no_backend_docs
    /**
     * Sets the active texture slot for subsequent operations.
     *
     * @param slot The texture slot index to activate
     */
    #end
    inline public function setActiveTexture(slot:Int):Void {

        _activeTextureSlot = slot;

    }

    inline public function textureBackendItemMatchesId(backendItem:backend.Texture, textureId:backend.TextureId):Bool {

        return (backendItem:TextureImpl).textureId == textureId;

    }

    inline public function getTextureId(backendItem:backend.Texture):backend.TextureId {

        return (backendItem:TextureImpl).textureId;

    }

    inline public function getTextureWidth(texture:backend.Texture):Int {

        return (texture:TextureImpl).width;

    }

    inline public function getTextureHeight(texture:backend.Texture):Int {

        return (texture:TextureImpl).height;

    }

    inline public function getTextureWidthActual(texture:backend.Texture):Int {

        return (texture:TextureImpl).width;

    }

    inline public function getTextureHeightActual(texture:backend.Texture):Int {

        return (texture:TextureImpl).height;

    }

    inline public function bindTexture(backendItem:backend.Texture):Void {

        // Unused in headless

    }

    inline public function bindNoTexture():Void {

        // Unused in headless

    }

    inline public function setPrimitiveType(primitiveType:ceramic.RenderPrimitiveType):Void {

        // Unused in headless

    }

    inline public function beginDrawQuad(quad:ceramic.Quad):Void {

        // Unused in headless

    }

    inline public function endDrawQuad():Void {

        // Unused in headless

    }

    inline public function beginDrawMesh(mesh:ceramic.Mesh):Void {

        // Unused in headless

    }

    inline public function endDrawMesh():Void {

        // Unused in headless

    }

    inline public function enableScissor(x:Float, y:Float, width:Float, height:Float):Void {

        // Unused in headless

    }

    inline public function disableScissor():Void {

        // Unused in headless

    }

    inline public function beginDrawingInStencilBuffer():Void {

        // Unused in headless

    }

    inline public function endDrawingInStencilBuffer():Void {

        // Unused in headless

    }

    inline public function drawWithStencilTest():Void {

        // Unused in headless

    }

    inline public function drawWithoutStencilTest():Void {

        // Unused in headless

    }

    inline public function getNumPos():Int {

        return _numPos;

    }

    inline public function putPos(x:Float32, y:Float32, z:Float32):Void {

        _posIndex += _vertexSize;
        _numPos++;

    }

    inline public function putPosAndTextureSlot(x:Float32, y:Float32, z:Float32, textureSlot:Float32):Void {

        _posIndex += _vertexSize;
        _numPos++;

    }

    inline public function putIndice(i:Int):Void {

        _numIndices++;

    }

    inline public function putUVs(uvX:Float, uvY:Float):Void {

        _numUVs++;
        _uvIndex += _vertexSize;

    }

    inline public function putColor(r:Float, g:Float, b:Float, a:Float):Void {

        _numColors++;
        _colorIndex += _vertexSize;

    }

    inline public function beginFloatAttributes():Void {

        // Nothing to do here

    }

    inline public function putFloatAttribute(index:Int, value:Float):Void {

        // Unused in headless

    }

    inline public function endFloatAttributes():Void {

        _floatAttributesIndex += _vertexSize;

    }

    inline public function clearAndApplyBackground():Void {

        // Unused in headless

    }

    #if !no_backend_docs
    /**
     * Determines if the vertex buffer should be flushed before adding more data.
     *
     * @param numVerticesAfter Number of vertices that will be added
     * @param numIndicesAfter Number of indices that will be added
     * @param customFloatAttributesSize Size of custom attributes
     * @return True if the buffer should be flushed
     */
    #end
    inline public function shouldFlush(numVerticesAfter:Int, numIndicesAfter:Int, customFloatAttributesSize:Int):Bool {

        return (_numPos + numVerticesAfter > _maxVerts || _numIndices + numIndicesAfter > MAX_INDICES);

    }

    #if !no_backend_docs
    /**
     * Gets the number of vertices that can still fit in the buffer.
     *
     * @return Number of remaining vertex slots
     */
    #end
    inline public function remainingVertices():Int {

        return _maxVerts - _numPos;

    }

    #if !no_backend_docs
    /**
     * Gets the number of indices that can still fit in the buffer.
     *
     * @return Number of remaining index slots
     */
    #end
    inline public function remainingIndices():Int {

        return MAX_INDICES - _numIndices;

    }

    #if !no_backend_docs
    /**
     * Checks if there is any buffered geometry to flush.
     *
     * @return True if there are vertices to render
     */
    #end
    inline public function hasAnythingToFlush():Bool {

        return _numPos > 0;

    }

    #if !no_backend_docs
    /**
     * Flushes all buffered geometry and resets buffer indices.
     *
     * In headless mode, this just resets the buffer state.
     */
    #end
    inline public function flush():Void {

        resetIndexes();

    }

    #if !no_backend_docs
    /**
     * Resets all buffer indices to their initial state.
     *
     * This configures the buffer layout based on whether the current
     * shader supports multiple textures per batch.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end function resetIndexes():Void {

        _numIndices = 0;

        _numPos = 0;
        _posIndex = 0;

        if (ceramic.App.app.backend.shaders.canBatchWithMultipleTextures(_currentShader)) {
            _numColors = 0;
            _colorIndex = 4;

            _numUVs = 0;
            _uvIndex = 8;

            _floatAttributesIndex = 10;
        }
        else {
            _numColors = 0;
            _colorIndex = 3;

            _numUVs = 0;
            _uvIndex = 7;

            _floatAttributesIndex = 9;
        }

    }

}
