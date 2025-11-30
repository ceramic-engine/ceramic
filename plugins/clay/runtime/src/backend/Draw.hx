package backend;

import ceramic.Float32;
import clay.Clay;
import clay.GraphicsBatcher;

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
 * The class uses GraphicsBatcher for low-level batching operations and provides
 * platform-specific optimizations for different targets (web, desktop, mobile).
 */
class Draw #if !completion implements spec.Draw #end {

    /**
     * The Ceramic renderer instance used for high-level rendering operations.
     */
    var renderer:ceramic.Renderer = new ceramic.Renderer();

    /**
     * The graphics batcher instance for batched rendering operations.
     * Stored in a static field for performance, since there's only one Draw instance.
     */
    public var batcher(get, set):GraphicsBatcher;
    static var _batcher:GraphicsBatcher = null;
    inline function get_batcher():GraphicsBatcher {
        return _batcher;
    }
    inline function set_batcher(batcher:GraphicsBatcher):GraphicsBatcher {
        return _batcher = batcher;
    }

/// Public API

    /**
     * Creates a new Draw backend instance.
     * Initializes the Ceramic renderer for handling visual rendering.
     */
    public function new() {

        renderer = new ceramic.Renderer();
        batcher = new GraphicsBatcher();

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

    static var _activeTextureSlot:Int = 0;

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

    static var _drawingInStencilBuffer:Bool = false;

    /**
     * Initializes the vertex and index buffers for rendering.
     *
     * This method sets up the buffer management system and prepares
     * the first set of buffers for use. Should be called before any
     * rendering operations begin.
     */
    #if !ceramic_debug_draw_backend inline #end public function initBuffers():Void {

        _activeTextureSlot = 0;
        batcher.initBuffers();

        // Set up default texture for web targets
        #if web
        var backendItem = ceramic.App.app.defaultWhiteTexture.backendItem;
        GraphicsBatcher.defaultTextureId = (backendItem:clay.graphics.Texture).textureId;
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

        batcher.beginRender();

    }

    /**
     * Ends the current rendering frame.
     *
     * Performs any cleanup or finalization needed after all draw operations.
     */
    #if !ceramic_debug_draw_backend inline #end public function endRender():Void {

        batcher.endRender();

    }

    /**
     * Clears the current render target to transparent white.
     *
     * This method clears the color buffer with a transparent white background.
     * When rendering to a texture, this marks the render target as updated.
     */
    #if !ceramic_debug_draw_backend inline #end public function clear():Void {

        batcher.clear(
            _whiteTransparentColor.redFloat,
            _whiteTransparentColor.greenFloat,
            _whiteTransparentColor.blueFloat,
            _whiteTransparentColor.alpha,
            false
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

        batcher.clear(
            background.redFloat,
            background.greenFloat,
            background.blueFloat,
            1,
            false
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

        batcher.enableBlending();

    }

    /**
     * Disables alpha blending.
     *
     * When disabled, pixels are rendered opaque regardless of alpha values.
     * This can improve performance when rendering fully opaque content.
     */
    #if !ceramic_debug_draw_backend inline #end public function disableBlending():Void {

        batcher.disableBlending();

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
        batcher.setActiveTexture(slot);

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

        batcher.setPrimitiveType(switch primitiveType {
            case LINE: 1;
            case _: 0;
        });

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
                    batcher.blitRenderTargetBuffers(clayRenderTexture.renderTarget, clayRenderTexture.width, clayRenderTexture.height);
                }
            }

            _currentRenderTarget = renderTarget;
            _didUpdateCurrentRenderTarget = true;

            if (renderTarget != null) {
                var renderTexture:clay.graphics.RenderTexture = cast renderTarget.backendItem;

                batcher.setRenderTarget(renderTexture.renderTarget);

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
                batcher.setViewport(
                    0, 0,
                    Std.int(renderTarget.width * renderTarget.density),
                    Std.int(renderTarget.height * renderTarget.density)
                );

                if (renderTarget.clearOnRender) {
                    batcher.clear(
                        _blackTransparentColor.redFloat,
                        _blackTransparentColor.greenFloat,
                        _blackTransparentColor.blueFloat,
                        _blackTransparentColor.alphaFloat,
                        false
                    );

                    _didUpdateCurrentRenderTarget = true;
                }

            } else {

                batcher.setRenderTarget(null);

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
                batcher.setViewport(
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

        var floatAttributesSize = shadersBackend.customFloatAttributesSize(_activeShader);
        var batchMultiTexture = shadersBackend.canBatchWithMultipleTextures(_activeShader);

        batcher.setCustomAttributes(_activeShader != null ? _activeShader.customAttributes : null);
        batcher.setVertexLayout(batchMultiTexture, floatAttributesSize);

        (shader:ShaderImpl).activate();

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

        batcher.setBlendFuncSeparate(
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

        var density = _viewportDensity;
        var left = _modelViewTransform.transformX(x, y) * density;
        var top = _modelViewTransform.transformY(x, y) * density;
        var right = _modelViewTransform.transformX(x + width, y + height) * density;
        var bottom = _modelViewTransform.transformY(x + width, y + height) * density;

        if (_currentRenderTarget != null) {
            batcher.enableScissor(left, _viewportHeight - top, right - left, top - bottom);
        }
        else {
            batcher.enableScissor(left, _viewportHeight - bottom, right - left, bottom - top);
        }

    }

    /**
     * Disables scissor testing.
     *
     * After calling this, rendering is no longer clipped to a rectangular area.
     */
    #if !ceramic_debug_draw_backend inline #end public function disableScissor():Void {

        batcher.disableScissor();

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

        batcher.enableStencilTest();

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

        batcher.disableStencilTest();

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
        batcher.beginStencilWrite();

    }

    #if !ceramic_debug_draw_backend inline #end public function endDrawingInStencilBuffer():Void {

        _drawingInStencilBuffer = false;
        batcher.endStencilWrite();

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

        batcher.bindTexture((backendItem:clay.graphics.Texture).textureId);

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

        batcher.bindNoTexture();

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

        return batcher.getNumVertices();

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

        batcher.putVertex(x, y, z);

    }

    #if !ceramic_debug_draw_backend inline #end public function putPosAndTextureSlot(x:Float32, y:Float32, z:Float32, textureSlot:Float32):Void {

        batcher.putVertexWithTextureSlot(x, y, z, textureSlot);

    }

    #if !ceramic_debug_draw_backend inline #end public function beginFloatAttributes():Void {

        // Nothing to do here

    }

    #if !ceramic_debug_draw_backend inline #end public function putFloatAttribute(index:Int, value:Float):Void {

        batcher.putFloatAttribute(index, value);

    }

    #if !ceramic_debug_draw_backend inline #end public function endFloatAttributes():Void {

        batcher.endFloatAttributes();

    }

    #if !ceramic_debug_draw_backend inline #end public function putIndice(i:Int):Void {

        batcher.putIndex(i);

    }

    #if !ceramic_debug_draw_backend inline #end public function putUVs(uvX:Float, uvY:Float):Void {

        batcher.putUVs(uvX, uvY);

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

        batcher.putColor(r, g, b, a);

    }

    #if !ceramic_debug_draw_backend inline #end public function hasAnythingToFlush():Bool {

        return batcher.hasAnythingToFlush();

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

        return batcher.shouldFlush(numVerticesAfter, numIndicesAfter);

    }

    #if !ceramic_debug_draw_backend inline #end public function remainingVertices():Int {

        return batcher.remainingVertices();

    }

    #if !ceramic_debug_draw_backend inline #end public function remainingIndices():Int {

        return batcher.remainingIndices();

    }

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

        batcher.flush();

        if (_currentRenderTarget != null) {
            _didUpdateCurrentRenderTarget = true;
        }

    }

}
