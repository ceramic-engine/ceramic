package backend;

import ceramic.Float32;
import clay.Clay;
import clay.buffers.ArrayBufferView;
import clay.buffers.Float32Array;
import clay.buffers.Uint16Array;
import clay.graphics.Graphics;
import clay.opengl.GL;

using ceramic.Extensions;

@:allow(backend.Backend)
@:access(backend.Backend)
/**
 * Clay backend rendering and graphics operations implementation.
 *
 * This class handles all OpenGL/WebGL rendering operations for the Clay backend,
 * including vertex buffer management, texture binding, shader operations,
 * render targets, and batch rendering optimization.
 *
 * Key features:
 * - Efficient batch rendering with automatic buffer management
 * - Support for multi-texture batching
 * - Render-to-texture capabilities
 * - Stencil buffer operations for masking
 * - Custom shader attribute support
 * - Scissor testing for clipping
 * - Blend mode management
 * - Matrix transformations and projections
 *
 * The class uses a buffer cycling system to avoid GPU stalls and provides
 * platform-specific optimizations for different targets (web, desktop, mobile).
 */
class Draw #if !completion implements spec.Draw #end {

    /**
     * The Ceramic renderer instance used for high-level rendering operations.
     */
    var renderer:ceramic.Renderer = new ceramic.Renderer();

/// Public API

    /**
     * Creates a new Draw backend instance.
     * Initializes the Ceramic renderer for handling visual rendering.
     */
    public function new() {

        renderer = new ceramic.Renderer();

    }

    /**
     * Begins a rendering frame (currently unused).
     * Reserved for future use or platform-specific initialization.
     */
    #if !ceramic_debug_draw_backend inline #end function begin():Void {

        //

    }

    /**
     * Ends a rendering frame (currently unused).
     * Reserved for future use or platform-specific cleanup.
     */
    #if !ceramic_debug_draw_backend inline #end function end():Void {

        //

    }

    /**
     * Renders an array of visual objects.
     *
     * On iOS, this method checks if the app is in background to prevent
     * GPU operations that could cause crashes when the app is not active.
     *
     * @param visuals Array of Visual objects to render
     */
    public function draw(visuals:Array<ceramic.Visual>):Void {

        #if ios
        // iOS doesn't like it when we send GPU commands when app is in background
        if (!ceramic.App.app.backend.mobileInBackground.load()) {
        #end
            renderer.render(true, visuals);
        #if ios
        }
        #end

    }

    /**
     * Swaps the front and back buffers (unused in Clay backend).
     * Buffer swapping is handled automatically by Clay framework.
     */
    inline public function swap():Void {

        // Unused

    }

/// Rendering

    /**
     * Maximum number of vertices that can be stored in a single buffer.
     */
    #if !ceramic_debug_draw_backend inline #end static var MAX_VERTS_SIZE:Int = 65536;

    /**
     * Maximum number of indices that can be stored in a single buffer.
     */
    #if !ceramic_debug_draw_backend inline #end static var MAX_INDICES:Int = 16384;

    /**
     * Maximum number of buffer sets to cycle through.
     * Buffer cycling prevents GPU stalls by using multiple buffer sets.
     */
    #if !ceramic_debug_draw_backend inline #end static var MAX_BUFFERS:Int = 64;

    /**
     * Vertex attribute location for position data (x, y, z).
     */
    #if !ceramic_debug_draw_backend inline #end static var ATTRIBUTE_POS:Int = 0;

    /**
     * Vertex attribute location for texture coordinate data (u, v).
     */
    #if !ceramic_debug_draw_backend inline #end static var ATTRIBUTE_UV:Int = 1;

    /**
     * Vertex attribute location for color data (r, g, b, a).
     */
    #if !ceramic_debug_draw_backend inline #end static var ATTRIBUTE_COLOR:Int = 2;

    #if cpp
    static var _viewPosBufferViewArray:Array<ArrayBufferView> = [];
    static var _viewUvsBufferViewArray:Array<ArrayBufferView> = [];
    static var _viewColorsBufferViewArray:Array<ArrayBufferView> = [];
    static var _viewIndicesBufferViewArray:Array<ArrayBufferView> = [];

    static var _viewPosBufferView:ArrayBufferView;
    static var _viewUvsBufferView:ArrayBufferView;
    static var _viewColorsBufferView:ArrayBufferView;
    static var _viewIndicesBufferView:ArrayBufferView;
    #end

    static var _buffersIndex:Int;

    static var _posListArray:Array<Float32Array> = [];
    static var _indiceListArray:Array<Uint16Array> = [];
    static var _uvListArray:Array<Float32Array> = [];
    static var _colorListArray:Array<Float32Array> = [];

    static var _posList:Float32Array;
    static var _indiceList:Uint16Array;
    static var _uvList:Float32Array;
    static var _colorList:Float32Array;

    #if cpp
    static var _posBuffer:clay.buffers.ArrayBuffer;
    static var _indiceBuffer:clay.buffers.ArrayBuffer;
    static var _uvBuffer:clay.buffers.ArrayBuffer;
    static var _colorBuffer:clay.buffers.ArrayBuffer;
    #end

    static var _activeTextureSlot:Int = 0;

    static var _batchMultiTexture:Bool = false;
    static var _posSize:Int = 0;
    static var _customGLBuffers:Array<GLBuffer> = [];

    static var _activeShader:ShaderImpl;

    static var _currentRenderTarget:ceramic.RenderTexture = null;
    static var _didUpdateCurrentRenderTarget:Bool = false;

    static var _projectionMatrix = ceramic.Float32Array.fromArray([
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0
    ]);

    static var _modelViewMatrix = ceramic.Float32Array.fromArray([
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0
    ]);

    static var _modelViewTransform = new ceramic.Transform();

    static var _renderTargetTransform = new ceramic.Transform();

    static var _viewportDensity:Float = 1.0;

    static var _viewportWidth:Float = 0.0;

    static var _viewportHeight:Float = 0.0;

    static var _blackTransparentColor = new ceramic.AlphaColor(ceramic.Color.BLACK, 0);

    static var _whiteTransparentColor = new ceramic.AlphaColor(ceramic.Color.WHITE, 0);

    static var _maxVerts:Int = 0;

    static var _vertexSize:Int = 0;
    static var _numIndices:Int = 0;

    static var _numPos:Int = 0;
    static var _posIndex:Int = 0;
    static var _floatAttributesSize:Int = 0;

    static var _numUVs:Int = 0;
    static var _uvIndex:Int = 0;

    static var _numColors:Int = 0;
    static var _colorIndex:Int = 0;

    static var _drawingInStencilBuffer:Bool = false;

    static var _primitiveType:Int = GL.TRIANGLES;

    /**
     * Initializes the vertex and index buffers for rendering.
     *
     * This method sets up the buffer management system and prepares
     * the first set of buffers for use. Should be called before any
     * rendering operations begin.
     */
    #if !ceramic_debug_draw_backend inline #end public function initBuffers():Void {

        _activeTextureSlot = 0;
        _buffersIndex = -1;

        prepareNextBuffers();

    }

    /**
     * Prepares the next set of vertex buffers for use.
     *
     * This implements a buffer cycling system to avoid GPU stalls. Instead of
     * reusing the same buffer immediately (which could cause the GPU to wait),
     * it cycles through multiple buffer sets.
     *
     * Buffer allocation:
     * - Position buffer: Full vertex capacity (MAX_VERTS_SIZE)
     * - UV buffer: 2/3 of vertex capacity (optimized for quads)
     * - Color buffer: Full vertex capacity (4 floats per vertex)
     * - Index buffer: MAX_INDICES * 2 capacity
     *
     * On C++ targets, additional ArrayBufferView objects are created for
     * efficient memory access without copying.
     */
    function prepareNextBuffers():Void {

        _buffersIndex++;
        if (_buffersIndex > MAX_BUFFERS) {
            _buffersIndex = 0;
        }
        if (_posListArray.length <= _buffersIndex) {

            _posListArray[_buffersIndex] = new Float32Array(MAX_VERTS_SIZE);
             // For uvs, we'll never need more than two thirds of vertex buffer size
            _uvListArray[_buffersIndex] = new Float32Array(Std.int(Math.ceil(MAX_VERTS_SIZE * 2.0 / 3.0)));
            _colorListArray[_buffersIndex] = new Float32Array(MAX_VERTS_SIZE);
            _indiceListArray[_buffersIndex] = new Uint16Array(MAX_INDICES * 2);

            #if cpp
            _viewPosBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
            _viewUvsBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
            _viewColorsBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Float32);
            _viewIndicesBufferViewArray[_buffersIndex] = @:privateAccess new clay.buffers.ArrayBufferView(Uint8);
            #end
        }

        _posList = _posListArray.unsafeGet(_buffersIndex);
        _uvList = _uvListArray.unsafeGet(_buffersIndex);
        _colorList = _colorListArray.unsafeGet(_buffersIndex);
        _indiceList = _indiceListArray.unsafeGet(_buffersIndex);

        #if cpp
        _viewPosBufferView = _viewPosBufferViewArray.unsafeGet(_buffersIndex);
        _viewUvsBufferView = _viewUvsBufferViewArray.unsafeGet(_buffersIndex);
        _viewColorsBufferView = _viewColorsBufferViewArray.unsafeGet(_buffersIndex);
        _viewIndicesBufferView = _viewIndicesBufferViewArray.unsafeGet(_buffersIndex);

        _posBuffer = (_posList:clay.buffers.ArrayBufferView).buffer;
        _uvBuffer = (_uvList:clay.buffers.ArrayBufferView).buffer;
        _colorBuffer = (_colorList:clay.buffers.ArrayBufferView).buffer;
        _indiceBuffer = (_indiceList:clay.buffers.ArrayBufferView).buffer;
        #end

    }

    /**
     * Begins a rendering pass by enabling vertex attributes.
     *
     * Enables the core vertex attributes used by all shaders:
     * - Position (x, y, z)
     * - Texture coordinates (u, v)
     * - Color (r, g, b, a)
     *
     * Additional attributes are enabled dynamically based on the active shader.
     */
    #if !ceramic_debug_draw_backend inline #end public function beginRender():Void {

        GL.enableVertexAttribArray(ATTRIBUTE_POS);
        GL.enableVertexAttribArray(ATTRIBUTE_UV);
        GL.enableVertexAttribArray(ATTRIBUTE_COLOR);

    }

    /**
     * Clears the current render target to transparent white.
     *
     * This method clears the color buffer with a transparent white background.
     * When rendering to a texture, this marks the render target as updated.
     */
    #if !ceramic_debug_draw_backend inline #end public function clear():Void {

        #if !ceramic_debug_draw_backend inline #end Graphics.clear(
            _whiteTransparentColor.redFloat,
            _whiteTransparentColor.greenFloat,
            _whiteTransparentColor.blueFloat,
            _whiteTransparentColor.alpha
        );

        if (_currentRenderTarget != null) {
            _didUpdateCurrentRenderTarget = true;
        }

    }

    /**
     * Clears the current render target and applies the application background color.
     *
     * This method clears the color buffer with the application's configured
     * background color (fully opaque). Used for the main screen clearing.
     */
    #if !ceramic_debug_draw_backend inline #end public function clearAndApplyBackground():Void {

        var background = ceramic.App.app.settings.background;

        #if !ceramic_debug_draw_backend inline #end Graphics.clear(
            background.redFloat,
            background.greenFloat,
            background.blueFloat,
            1
        );

        if (_currentRenderTarget != null) {
            _didUpdateCurrentRenderTarget = true;
        }

    }

    /**
     * Enables alpha blending for transparent rendering.
     *
     * This activates the GPU's blending functionality, allowing pixels to be
     * combined based on their alpha values. Must be enabled for transparency
     * to work correctly.
     */
    #if !ceramic_debug_draw_backend inline #end public function enableBlending():Void {

        Graphics.enableBlending();

    }

    /**
     * Disables alpha blending.
     *
     * When disabled, pixels are rendered opaque regardless of alpha values.
     * This can improve performance when rendering fully opaque content.
     */
    #if !ceramic_debug_draw_backend inline #end public function disableBlending():Void {

        Graphics.disableBlending();

    }

    /**
     * Sets the active texture unit slot for multi-texturing.
     *
     * Modern GPUs support multiple texture units, allowing shaders to sample
     * from multiple textures simultaneously. This method selects which texture
     * unit subsequent texture operations will affect.
     *
     * @param slot The texture unit index (0-based)
     */
    #if !ceramic_debug_draw_backend inline #end public function setActiveTexture(slot:Int):Void {

        _activeTextureSlot = slot;
        Graphics.setActiveTexture(slot);

    }

    /**
     * Sets the primitive type for rendering.
     *
     * Determines how vertices are interpreted:
     * - TRIANGLE: Every 3 vertices form a triangle (default)
     * - LINE: Every 2 vertices form a line
     *
     * @param primitiveType The primitive type to use for subsequent draw calls
     */
    #if !ceramic_debug_draw_backend inline #end public function setPrimitiveType(primitiveType:ceramic.RenderPrimitiveType):Void {

        _primitiveType = switch primitiveType {
            case LINE: GL.LINES;
            case _: GL.TRIANGLES;
        }

    }

    /**
     * Gets the currently active texture unit slot.
     *
     * @return The index of the active texture unit
     */
    #if !ceramic_debug_draw_backend inline #end public function getActiveTexture():Int {

        return _activeTextureSlot;

    }

    /**
     * Sets the active render target for subsequent drawing operations.
     *
     * This method switches between rendering to a texture (off-screen) or to the
     * main screen buffer. When switching targets, it handles:
     * - MSAA buffer blitting for antialiased render targets
     * - Projection and view matrix updates
     * - Viewport configuration
     * - Optional automatic clearing
     *
     * When renderTarget is null, rendering switches back to the main screen.
     *
     * @param renderTarget The render texture to render to, or null for main screen
     * @param force Force the render target switch even if it's the same target
     */
    #if (!ceramic_debug_draw && !ceramic_soft_inline) inline #end public function setRenderTarget(renderTarget:ceramic.RenderTexture, force:Bool = false):Void {

        if (_currentRenderTarget != renderTarget || force) {

            if (_currentRenderTarget != null && _currentRenderTarget != renderTarget && _didUpdateCurrentRenderTarget) {
                var clayRenderTexture:clay.graphics.RenderTexture = cast _currentRenderTarget.backendItem;
                if (clayRenderTexture.antialiasing > 1) {
                    Graphics.blitRenderTargetBuffers(clayRenderTexture.renderTarget, clayRenderTexture.width, clayRenderTexture.height);
                }
            }

            _currentRenderTarget = renderTarget;
            _didUpdateCurrentRenderTarget = true;

            if (renderTarget != null) {
                var renderTexture:clay.graphics.RenderTexture = cast renderTarget.backendItem;

                Graphics.setRenderTarget(renderTexture.renderTarget);

                updateProjectionMatrix(
                    renderTarget.width,
                    renderTarget.height
                );

                _renderTargetTransform.identity();
                _renderTargetTransform.scale(renderTarget.density, renderTarget.density);

                updateViewMatrix(
                    renderTarget.density,
                    renderTarget.width,
                    renderTarget.height,
                    _renderTargetTransform,
                    -1
                );

                _viewportDensity = renderTarget.density;
                _viewportWidth = renderTarget.width * _viewportDensity;
                _viewportHeight = renderTarget.height * _viewportDensity;
                Graphics.setViewport(
                    0, 0,
                    Std.int(renderTarget.width * renderTarget.density),
                    Std.int(renderTarget.height * renderTarget.density)
                );

                if (renderTarget.clearOnRender) {
                    Graphics.clear(
                        _blackTransparentColor.redFloat,
                        _blackTransparentColor.greenFloat,
                        _blackTransparentColor.blueFloat,
                        _blackTransparentColor.alphaFloat
                    );

                    _didUpdateCurrentRenderTarget = true;
                }

            } else {

                Graphics.setRenderTarget(null);

                updateProjectionMatrix(
                    ceramic.App.app.backend.screen.getWidth(),
                    ceramic.App.app.backend.screen.getHeight()
                );
                updateViewMatrix(
                    ceramic.App.app.backend.screen.getDensity(),
                    ceramic.App.app.backend.screen.getWidth(),
                    ceramic.App.app.backend.screen.getHeight(),
                    @:privateAccess ceramic.App.app.screen.matrix
                );
                _viewportDensity = ceramic.App.app.backend.screen.getDensity();
                _viewportWidth = ceramic.App.app.backend.screen.getWidth() * _viewportDensity;
                _viewportHeight = ceramic.App.app.backend.screen.getHeight() * _viewportDensity;
                Graphics.setViewport(
                    0, 0,
                    Std.int(_viewportWidth),
                    Std.int(_viewportHeight)
                );
            }
        }

    }

    /**
     * Activates a shader program for rendering.
     *
     * This method:
     * - Sets the shader as the active GPU program
     * - Uploads projection and modelview matrices as uniforms
     * - Configures vertex layout based on shader attributes
     * - Determines if multi-texture batching is supported
     * - Calculates maximum vertices per batch based on attribute size
     *
     * The vertex size calculation includes:
     * - 3 floats for position (x, y, z)
     * - Custom float attributes defined by the shader
     * - 1 float for texture slot (if multi-texturing is enabled)
     *
     * @param shader The shader to activate
     */
    #if !ceramic_debug_draw_backend inline #end public function useShader(shader:backend.Shader):Void {

        _activeShader = shader;

        (shader:ShaderImpl).uniforms.setMatrix4('projectionMatrix', _projectionMatrix);
        (shader:ShaderImpl).uniforms.setMatrix4('modelViewMatrix', _modelViewMatrix);

        var shadersBackend = ceramic.App.app.backend.shaders;

        _floatAttributesSize = shadersBackend.customFloatAttributesSize(_activeShader);

        _batchMultiTexture = shadersBackend.canBatchWithMultipleTextures(_activeShader);
        _vertexSize = 3 + _floatAttributesSize + (_batchMultiTexture ? 1 : 0);
        _posSize = _vertexSize;
        if (_vertexSize < 4)
            _vertexSize = 4;

        _maxVerts = Std.int(Math.floor(MAX_VERTS_SIZE / _vertexSize));

        (shader:ShaderImpl).activate();

        if (_numPos == 0) {
            resetIndexes();
        }

    }

    /**
     * Resets all vertex buffer indexes to zero.
     *
     * This prepares the buffers for a new batch of vertices.
     * Called when starting a new draw batch or after flushing.
     */
    #if !ceramic_debug_draw_backend inline #end function resetIndexes():Void {

        _numIndices = 0;
        _numPos = 0;
        _numUVs = 0;
        _numColors = 0;

        _posIndex = 0;
        _uvIndex = 0;
        _colorIndex = 0;

    }

    /**
     * Sets separate blend functions for RGB and alpha channels.
     *
     * This allows fine control over how colors are blended, with different
     * blend modes for color (RGB) and transparency (alpha) channels.
     *
     * Common blend modes:
     * - ONE: Use source value as-is
     * - ZERO: Ignore value (multiply by 0)
     * - SRC_ALPHA: Multiply by source alpha
     * - ONE_MINUS_SRC_ALPHA: Multiply by (1 - source alpha)
     *
     * @param srcRgb Blend factor for source RGB
     * @param dstRgb Blend factor for destination RGB
     * @param srcAlpha Blend factor for source alpha
     * @param dstAlpha Blend factor for destination alpha
     */
    #if !ceramic_debug_draw_backend inline #end public function setBlendFuncSeparate(srcRgb:backend.BlendMode, dstRgb:backend.BlendMode, srcAlpha:backend.BlendMode, dstAlpha:backend.BlendMode):Void {

        Graphics.setBlendFuncSeparate(
            srcRgb,
            dstRgb,
            srcAlpha,
            dstAlpha
        );

    }

    /**
     * Called before drawing a quad (currently unused).
     *
     * Reserved for future optimizations or quad-specific setup.
     *
     * @param quad The quad about to be drawn
     */
    #if !ceramic_debug_draw_backend inline #end public function beginDrawQuad(quad:ceramic.Quad):Void {

    }

    /**
     * Called after drawing a quad (currently unused).
     *
     * Reserved for future optimizations or quad-specific cleanup.
     */
    #if !ceramic_debug_draw_backend inline #end public function endDrawQuad():Void {

    }

    #if !ceramic_debug_draw_backend inline #end public function beginDrawMesh(mesh:ceramic.Mesh):Void {

    }

    #if !ceramic_debug_draw_backend inline #end public function endDrawMesh():Void {

    }

    /**
     * Enables scissor testing to clip rendering to a rectangular area.
     *
     * Scissor testing restricts rendering to pixels within the specified
     * rectangle. Any pixels outside this area are discarded by the GPU.
     *
     * The coordinates are transformed by the current modelview matrix and
     * adjusted for screen density. When rendering to a texture, the Y
     * coordinate is flipped to account for texture coordinate differences.
     *
     * @param x Left edge of the scissor rectangle in logical coordinates
     * @param y Top edge of the scissor rectangle in logical coordinates
     * @param width Width of the scissor rectangle in logical pixels
     * @param height Height of the scissor rectangle in logical pixels
     */
    public function enableScissor(x:Float, y:Float, width:Float, height:Float):Void {

        GL.enable(GL.SCISSOR_TEST);

        var density = _viewportDensity;
        var left = _modelViewTransform.transformX(x, y) * density;
        var top = _modelViewTransform.transformY(x, y) * density;
        var right = _modelViewTransform.transformX(x + width, y + height) * density;
        var bottom = _modelViewTransform.transformY(x + width, y + height) * density;

        if (_currentRenderTarget != null) {
            GL.scissor(Math.round(left), Math.round(_viewportHeight - top), Math.round(right - left), Math.round(top - bottom));
        }
        else {
            GL.scissor(Math.round(left), Math.round(_viewportHeight - bottom), Math.round(right - left), Math.round(bottom - top));
        }

    }

    /**
     * Disables scissor testing.
     *
     * After calling this, rendering is no longer clipped to a rectangular area.
     */
    #if !ceramic_debug_draw_backend inline #end public function disableScissor():Void {

        GL.disable(GL.SCISSOR_TEST);

    }

    /**
     * Enables stencil testing for masked rendering.
     *
     * This configures the stencil test to only render pixels where the
     * stencil buffer equals 1. Used after drawing to the stencil buffer
     * to render content only within the stenciled area.
     *
     * Stencil configuration:
     * - Test: Passes when stencil buffer equals 1
     * - Mask: Stencil buffer is read-only (0x00)
     * - Color: All color channels are written
     */
    #if !ceramic_debug_draw_backend inline #end public function drawWithStencilTest():Void {

        // This part is not provided by clay because too specific for now
        // Might change later if clay handles it

        GL.stencilFunc(GL.EQUAL, 1, 0xFF);
        GL.stencilMask(0x00);
        GL.colorMask(true, true, true, true);

        GL.enable(GL.STENCIL_TEST);

    }

    /**
     * Disables stencil testing for normal rendering.
     *
     * Resets stencil configuration to default values where all pixels
     * pass the stencil test and the stencil buffer can be written to.
     *
     * Stencil configuration:
     * - Test: Always passes
     * - Mask: Stencil buffer is writable (0xFF)
     * - Color: All color channels are written
     */
    #if !ceramic_debug_draw_backend inline #end public function drawWithoutStencilTest():Void {

        // This part is not provided by clay because too specific for now
        // Might change later if clay handles it

        GL.stencilFunc(GL.ALWAYS, 1, 0xFF);
        GL.stencilMask(0xFF);
        GL.colorMask(true, true, true, true);

        GL.disable(GL.STENCIL_TEST);

    }

    /**
     * Begins drawing to the stencil buffer for masking operations.
     *
     * This sets up the GPU to write to the stencil buffer instead of
     * the color buffer. Pixels drawn will mark areas in the stencil
     * buffer with a value of 1, creating a mask for subsequent rendering.
     *
     * Stencil configuration:
     * - Clears stencil buffer to 0xFF
     * - Writes 1 to stencil buffer where pixels are drawn
     * - Disables color output (only stencil is affected)
     * - Always passes stencil test during mask creation
     */
    #if !ceramic_debug_draw_backend inline #end public function beginDrawingInStencilBuffer():Void {

        _drawingInStencilBuffer = true;

        // This part is not provided by clay because too specific for now
        // Might change later if clay handles it

        GL.stencilMask(0xFF);
        GL.clearStencil(0xFF);
        GL.clear(GL.STENCIL_BUFFER_BIT);
        GL.enable(GL.STENCIL_TEST);

        GL.stencilOp(GL.KEEP, GL.KEEP, GL.REPLACE);

        GL.stencilFunc(GL.ALWAYS, 1, 0xFF);
        GL.stencilMask(0xFF);
        GL.colorMask(false, false, false, false);

    }

    #if !ceramic_debug_draw_backend inline #end public function endDrawingInStencilBuffer():Void {

        _drawingInStencilBuffer = false;

    }

    /**
     * Binds a texture to the current texture unit.
     *
     * Makes the texture available for sampling in shaders. The texture
     * will be bound to the currently active texture unit.
     *
     * @param backendItem The texture to bind
     */
    #if !ceramic_debug_draw_backend inline #end public function bindTexture(backendItem:backend.Texture):Void {

        Graphics.bindTexture2d((backendItem:clay.graphics.Texture).textureId);

    }

    /**
     * Binds no texture or a default white texture.
     *
     * On web targets, binds a 1x1 white texture because WebGL requires
     * a texture to be bound. On native targets, unbinds any texture.
     *
     * Used when rendering untextured geometry or solid colors.
     */
    #if !ceramic_debug_draw_backend inline #end public function bindNoTexture():Void {

        #if web
        var backendItem = ceramic.App.app.defaultWhiteTexture.backendItem;
        Graphics.bindTexture2d((backendItem:clay.graphics.Texture).textureId);
        #else
        Graphics.bindTexture2d(Graphics.NO_TEXTURE);
        #end

    }

    #if !ceramic_debug_draw_backend inline #end public function textureBackendItemMatchesId(backendItem:backend.Texture, textureId:backend.TextureId):Bool {

        return (backendItem:clay.graphics.Texture).textureId == textureId;

    }

    #if !ceramic_debug_draw_backend inline #end public function getTextureId(backendItem:backend.Texture):backend.TextureId {

        return (backendItem:clay.graphics.Texture).textureId;

    }

    #if !ceramic_debug_draw_backend inline #end public function getTextureWidth(backendItem:backend.Texture):Int {

        return (backendItem:clay.graphics.Texture).width;

    }

    #if !ceramic_debug_draw_backend inline #end public function getTextureHeight(backendItem:backend.Texture):Int {

        return (backendItem:clay.graphics.Texture).height;

    }

    #if !ceramic_debug_draw_backend inline #end public function getTextureWidthActual(backendItem:backend.Texture):Int {

        return (backendItem:clay.graphics.Texture).widthActual;

    }

    #if !ceramic_debug_draw_backend inline #end public function getTextureHeightActual(backendItem:backend.Texture):Int {

        return (backendItem:clay.graphics.Texture).heightActual;

    }

    /**
     * Updates the projection matrix for orthographic rendering.
     *
     * Creates an orthographic projection matrix that maps logical
     * coordinates to normalized device coordinates (-1 to 1).
     *
     * The projection uses:
     * - Origin at top-left (0,0)
     * - X increases rightward
     * - Y increases downward
     * - Z range from -1000 to 1000 for layering
     *
     * @param width Viewport width in logical pixels
     * @param height Viewport height in logical pixels
     */
    #if !ceramic_debug_draw_backend inline #end function updateProjectionMatrix(width:Float, height:Float):Void {

        // Making orthographic projection
        //

        var left = 0.0;
        var top = 0.0;
        var right = width;
        var bottom = height;
        var near = 1000.0;
        var far = -1000.0;

        var w = right - left;
        var h = top - bottom;
        var p = far - near;

        var tx = (right + left)   / w;
        var ty = (top   + bottom) / h;
        var tz = (far   + near)   / p;

        var m = _projectionMatrix;

        m[0] = 2 / w;  m[4] = 0;      m[8] = 0;       m[12] = -tx;
        m[1] = 0;      m[5] = 2 / h;  m[9] = 0;       m[13] = -ty;
        m[2] = 0;      m[6] = 0;      m[10] = -2 / p; m[14] = -tz;
        m[3] = 0;      m[7] = 0;      m[11] = 0;      m[15] = 1;

    }

    /**
     * Updates the view matrix for camera transformations.
     *
     * The view matrix handles:
     * - Camera position and rotation (via transform parameter)
     * - Screen density scaling for high-DPI displays
     * - Y-axis flipping for render-to-texture (textures have inverted Y)
     *
     * The matrix is inverted at the end because the view matrix
     * represents the inverse of the camera transform.
     *
     * @param density Screen density multiplier (e.g., 2 for retina)
     * @param width Viewport width in logical pixels
     * @param height Viewport height in logical pixels
     * @param transform Optional camera transform
     * @param flipY -1 to flip Y axis (for render targets), 1 for normal
     */
    #if !ceramic_debug_draw_backend inline #end function updateViewMatrix(density:Float, width:Float, height:Float, ?transform:ceramic.Transform, flipY:Float = 1):Void {

        if (transform != null) {
            _modelViewTransform.setToTransform(transform);
            _modelViewTransform.invert();
        }
        else {
            _modelViewTransform.identity();
        }
        var tx = _modelViewTransform.tx;
        var ty = _modelViewTransform.ty;
        _modelViewTransform.translate(-tx, -ty);
        _modelViewTransform.scale(density, density);
        _modelViewTransform.translate(tx, ty);

        if (flipY == -1) {
            // Flip vertically (needed when we are rendering to texture)
            _modelViewTransform.translate(
                -width * 0.5,
                -height * 0.5
            );
            _modelViewTransform.scale(1, -1);
            _modelViewTransform.translate(
                width * 0.5,
                height * 0.5
            );
        }

        _modelViewTransform.invert();

        setMatrixToTransform(_modelViewMatrix, _modelViewTransform);

    }

    #if !ceramic_debug_draw_backend inline #end function matrixIdentity(m:ceramic.Float32Array):Void {

        m[0] = 1;        m[4] = 0;        m[8] = 0;       m[12] = 0;
        m[1] = 0;        m[5] = 1;        m[9] = 0;       m[13] = 0;
        m[2] = 0;        m[6] = 0;        m[10] = 1;      m[14] = 0;
        m[3] = 0;        m[7] = 0;        m[11] = 0;      m[15] = 1;

    }

    #if !ceramic_debug_draw_backend inline #end function setMatrixToTransform(m:ceramic.Float32Array, transform:ceramic.Transform):Void {

        m[0] = transform.a; m[4] = transform.c; m[8] = 0;   m[12] = transform.tx;
        m[1] = transform.b; m[5] = transform.d; m[9] = 0;   m[13] = transform.ty;
        m[2] = 0;           m[6] = 0;           m[10] = 1;  m[14] = 0;
        m[3] = 0;           m[7] = 0;           m[11] = 0;  m[15] = 1;

    }

    #if !ceramic_debug_draw_backend inline #end public function getNumPos():Int {

        return _numPos;

    }

    /**
     * Adds a vertex position to the current batch.
     *
     * On C++ targets, uses direct memory access for performance.
     * On other targets, uses array access.
     *
     * @param x X coordinate in screen space
     * @param y Y coordinate in screen space
     * @param z Z coordinate for depth ordering (0-1 range typically)
     */
    #if !ceramic_debug_draw_backend inline #end public function putPos(x:Float32, y:Float32, z:Float32):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, _posIndex * Float32Array.BYTES_PER_ELEMENT, x);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 1) * Float32Array.BYTES_PER_ELEMENT, y);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 2) * Float32Array.BYTES_PER_ELEMENT, z);
        #else
        _posList[_posIndex] = x;
        _posList[_posIndex + 1] = y;
        _posList[_posIndex + 2] = z;
        #end
        _posIndex += 3;
        _numPos++;

    }

    #if !ceramic_debug_draw_backend inline #end public function putPosAndTextureSlot(x:Float32, y:Float32, z:Float32, textureSlot:Float32):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, _posIndex * Float32Array.BYTES_PER_ELEMENT, x);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 1) * Float32Array.BYTES_PER_ELEMENT, y);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 2) * Float32Array.BYTES_PER_ELEMENT, z);
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + 3) * Float32Array.BYTES_PER_ELEMENT, textureSlot);
        #else
        _posList[_posIndex] = x;
        _posList[_posIndex + 1] = y;
        _posList[_posIndex + 2] = z;
        _posList[_posIndex + 3] = textureSlot;
        #end
        _posIndex += 4;
        _numPos++;

    }

    #if !ceramic_debug_draw_backend inline #end public function beginFloatAttributes():Void {

        // Nothing to do here

    }

    #if !ceramic_debug_draw_backend inline #end public function putFloatAttribute(index:Int, value:Float):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_posBuffer, (_posIndex + index) * Float32Array.BYTES_PER_ELEMENT, value);
        #else
        _posList[_posIndex + index] = value;
        #end

    }

    #if !ceramic_debug_draw_backend inline #end public function endFloatAttributes():Void {

        _posIndex += _floatAttributesSize;

    }

    #if !ceramic_debug_draw_backend inline #end public function putIndice(i:Int):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setUint16(_indiceBuffer, _numIndices * Uint16Array.BYTES_PER_ELEMENT, i);
        #else
        _indiceList[_numIndices] = i;
        #end
        _numIndices++;

    }

    #if !ceramic_debug_draw_backend inline #end public function putUVs(uvX:Float, uvY:Float):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_uvBuffer, _uvIndex * Float32Array.BYTES_PER_ELEMENT, uvX);
        clay.buffers.ArrayBufferIO.setFloat32(_uvBuffer, (_uvIndex + 1) * Float32Array.BYTES_PER_ELEMENT, uvY);
        #else
        _uvList[_uvIndex] = uvX;
        _uvList[_uvIndex + 1] = uvY;
        #end
        _uvIndex += 2;
        _numUVs++;

    }

    /**
     * Adds a vertex color to the current batch.
     *
     * Colors are stored as floating-point values from 0.0 to 1.0.
     * The color will be interpolated across the triangle/line.
     *
     * @param r Red component (0.0 to 1.0)
     * @param g Green component (0.0 to 1.0)
     * @param b Blue component (0.0 to 1.0)
     * @param a Alpha component (0.0 to 1.0)
     */
    #if !ceramic_debug_draw_backend inline #end public function putColor(r:Float, g:Float, b:Float, a:Float):Void {

        #if cpp
        clay.buffers.ArrayBufferIO.setFloat32(_colorBuffer, _colorIndex * Float32Array.BYTES_PER_ELEMENT, r);
        clay.buffers.ArrayBufferIO.setFloat32(_colorBuffer, (_colorIndex + 1) * Float32Array.BYTES_PER_ELEMENT, g);
        clay.buffers.ArrayBufferIO.setFloat32(_colorBuffer, (_colorIndex + 2) * Float32Array.BYTES_PER_ELEMENT, b);
        clay.buffers.ArrayBufferIO.setFloat32(_colorBuffer, (_colorIndex + 3) * Float32Array.BYTES_PER_ELEMENT, a);
        #else
        _colorList[_colorIndex] = r;
        _colorList[_colorIndex + 1] = g;
        _colorList[_colorIndex + 2] = b;
        _colorList[_colorIndex + 3] = a;
        #end
        _colorIndex += 4;
        _numColors++;

    }

    #if !ceramic_debug_draw_backend inline #end public function hasAnythingToFlush():Bool {

        return _numPos > 0;

    }

    /**
     * Checks if the current batch should be flushed before adding more vertices.
     *
     * Returns true if adding the specified number of vertices or indices
     * would exceed buffer capacity, indicating that the current batch
     * should be sent to the GPU before continuing.
     *
     * @param numVerticesAfter Number of vertices to be added
     * @param numIndicesAfter Number of indices to be added
     * @param customFloatAttributesSize Size of custom attributes (unused)
     * @return True if flush is needed, false otherwise
     */
    #if !ceramic_debug_draw_backend inline #end public function shouldFlush(numVerticesAfter:Int, numIndicesAfter:Int, customFloatAttributesSize:Int):Bool {

        return (_numPos + numVerticesAfter > _maxVerts || _numIndices + numIndicesAfter > MAX_INDICES);

    }

    #if !ceramic_debug_draw_backend inline #end public function remainingVertices():Int {

        return _maxVerts - _numPos;

    }

    #if !ceramic_debug_draw_backend inline #end public function remainingIndices():Int {

        return MAX_INDICES - _numIndices;

    }

    static var debugShader:clay.graphics.Shader = null;

    /**
     * Flushes the current batch of vertices to the GPU.
     *
     * This is the core rendering method that:
     * 1. Creates GPU buffers from the accumulated vertex data
     * 2. Configures vertex attributes for the shader
     * 3. Handles multi-texture batching if supported
     * 4. Sets up custom shader attributes
     * 5. Issues the draw call to render all triangles/lines
     * 6. Cleans up temporary buffers
     * 7. Prepares for the next batch
     *
     * The method uses temporary GPU buffers that are deleted after
     * rendering to avoid memory leaks. Buffer data is uploaded as
     * STREAM_DRAW for optimal performance with dynamic geometry.
     */
    #if !ceramic_debug_draw_backend inline #end public function flush():Void {

        var batchMultiTexture = _batchMultiTexture;

        // fromBuffer takes byte length, so floats * 4
        #if cpp
        var pos = Float32Array.fromBuffer(_posBuffer, 0, _posIndex * 4, _viewPosBufferView);
        var uvs = Float32Array.fromBuffer(_uvBuffer, 0, _uvIndex * 4, _viewUvsBufferView);
        var colors = Float32Array.fromBuffer(_colorBuffer, 0, _colorIndex * 4, _viewColorsBufferView);
        var indices = Uint16Array.fromBuffer(_indiceBuffer, 0, _numIndices * 2, _viewIndicesBufferView);
        #else
        var pos = Float32Array.fromBuffer(_posList.buffer, 0, _posIndex * 4);
        var uvs = Float32Array.fromBuffer(_uvList.buffer, 0, _uvIndex * 4);
        var colors = Float32Array.fromBuffer(_colorList.buffer, 0, _colorIndex * 4);
        var indices = Uint16Array.fromBuffer(_indiceList.buffer, 0, _numIndices * 2);
        #end

        // var posArray = [];
        // for (i in 0..._posIndex) {
        //     posArray.push(pos[i]);
        // }
        // trace('pos: $posArray');
        // var uvArray = [];
        // for (i in 0..._uvIndex) {
        //     uvArray.push(uvs[i]);
        // }
        // trace('uv: $uvArray');
        // var colorArray = [];
        // for (i in 0..._colorIndex) {
        //     colorArray.push(colors[i]);
        // }
        // trace('color: $colorArray');
        // var indiceArray = [];
        // for (i in 0..._numIndices) {
        //     indiceArray.push(indices[i]);
        // }
        // trace('indice: $indiceArray');

        // Begin submit

        var pb = GL.createBuffer();
        var cb = GL.createBuffer();
        var tb = GL.createBuffer();
        var ib = GL.createBuffer();

        GL.enableVertexAttribArray(0);
        GL.enableVertexAttribArray(1);
        GL.enableVertexAttribArray(2);

        GL.bindBuffer(GL.ARRAY_BUFFER, pb);
        GL.vertexAttribPointer(ATTRIBUTE_POS, 3, GL.FLOAT, false, _posSize * 4, 0);
        GL.bufferData(GL.ARRAY_BUFFER, pos, GL.STREAM_DRAW);

        GL.bindBuffer(GL.ARRAY_BUFFER, tb);
        GL.vertexAttribPointer(ATTRIBUTE_UV, 2, GL.FLOAT, false, 0, 0);
        GL.bufferData(GL.ARRAY_BUFFER, uvs, GL.STREAM_DRAW);

        GL.bindBuffer(GL.ARRAY_BUFFER, cb);
        GL.vertexAttribPointer(ATTRIBUTE_COLOR, 4, GL.FLOAT, false, 0, 0);
        GL.bufferData(GL.ARRAY_BUFFER, colors, GL.STREAM_DRAW);

        var offset = 3;
        var n = ATTRIBUTE_COLOR + 1;
        var customGLBuffersLen:Int = 0;

        if (batchMultiTexture) {

            var b = GL.createBuffer();
            _customGLBuffers[customGLBuffersLen++] = b;

            GL.enableVertexAttribArray(n);
            GL.bindBuffer(GL.ARRAY_BUFFER, b);
            GL.vertexAttribPointer(n, 1, GL.FLOAT, false, _posSize * 4, offset * 4);
            GL.bufferData(GL.ARRAY_BUFFER, pos, GL.STREAM_DRAW);

            n++;
            offset++;

        }

        if (_activeShader != null && _activeShader.customAttributes != null) {

            var allAttrs = _activeShader.customAttributes;
            var start = customGLBuffersLen;
            var end = start + allAttrs.length;
            customGLBuffersLen += allAttrs.length;
            for (ii in start...end) {

                var attrIndex = ii - start;
                var attr = allAttrs.unsafeGet(attrIndex);

                var b = GL.createBuffer();
                _customGLBuffers[ii] = b;

                GL.enableVertexAttribArray(n);
                GL.bindBuffer(GL.ARRAY_BUFFER, b);
                GL.vertexAttribPointer(n, attr.size, GL.FLOAT, false, _posSize * 4, offset * 4);
                GL.bufferData(GL.ARRAY_BUFFER, pos, GL.STREAM_DRAW);

                n++;
                offset += attr.size;

            }
        }

        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ib);
        GL.bufferData(GL.ELEMENT_ARRAY_BUFFER, indices, GL.STREAM_DRAW);

        // Draw
        GL.drawElements(_primitiveType, _numIndices, GL.UNSIGNED_SHORT, 0);

        GL.deleteBuffer(pb);
        GL.deleteBuffer(cb);
        GL.deleteBuffer(tb);

        if (customGLBuffersLen > 0) {
            var n = ATTRIBUTE_COLOR + 1;
            for (ii in 0...customGLBuffersLen) {
                var b = _customGLBuffers.unsafeGet(ii);
                GL.deleteBuffer(b);
                GL.disableVertexAttribArray(n);
                n++;
            }
        }

        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, Graphics.NO_BUFFER);
        GL.deleteBuffer(ib);

        // End submit

        if (_currentRenderTarget != null) {
            _didUpdateCurrentRenderTarget = true;
        }

        pos = null;
        uvs = null;
        colors = null;
        indices = null;

        resetIndexes();

        prepareNextBuffers();

    }

}
