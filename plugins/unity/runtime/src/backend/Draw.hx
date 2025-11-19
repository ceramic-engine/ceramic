package backend;

import ceramic.Float32;
import ceramic.Transform;
import cs.NativeArray;
import cs.StdTypes.Int16;
import cs.types.UInt16;
import unityengine.Color;
import unityengine.Mesh;
import unityengine.MeshTopology;
import unityengine.Vector2;
import unityengine.Vector3;
import unityengine.rendering.IndexFormat;
import unityengine.rendering.MeshUpdateFlags;
import unityengine.rendering.SubMeshDescriptor;
import unityengine.rendering.VertexAttribute;
import unityengine.rendering.VertexAttributeDescriptor;
import unityengine.rendering.VertexAttributeFormat;

using ceramic.Extensions;

#if unity_rendergraph
import backend.CeramicCommandBuffer as CommandBuffer;
import backend.CeramicCommandBufferPool as CommandBufferPool;
#else
import unityengine.rendering.CommandBuffer;
import unityengine.rendering.CommandBufferPool;
#end

#if unity_urp
import unityengine.rendering.universal.RenderingData;
import unityengine.rendering.universal.ScriptableRenderPass;
import unityengine.rendering.universal.ScriptableRenderer;
#end

#if !no_backend_docs
/**
 * Unity implementation of the Draw backend interface.
 *
 * This class handles all 2D rendering operations for Ceramic in Unity,
 * providing optimized mesh generation and GPU command batching. It bridges
 * Ceramic's rendering system with Unity's graphics pipeline, supporting
 * both the built-in render pipeline and Universal Render Pipeline (URP).
 *
 * Key features:
 * - Efficient mesh batching to minimize draw calls
 * - Dynamic vertex and index buffer management
 * - Command buffer optimization for GPU performance
 * - Support for multiple rendering modes (quads, meshes)
 * - Integration with Unity's material and shader system
 * - Render state management (blend modes, stencil, etc.)
 *
 * The implementation uses Unity's Mesh API with direct native array access
 * for maximum performance, avoiding managed memory allocations during rendering.
 *
 * @see spec.Draw The interface this class implements
 * @see ceramic.Renderer The high-level renderer this backend drives
 * @see backend.Textures Works closely with texture management
 */
#end
@:allow(backend.Backend)
class Draw #if !completion implements spec.Draw #end {

/// Public API

    #if !no_backend_docs
    /**
     * Creates a new Draw backend instance.
     * Initializes the Ceramic renderer and sets up command buffers
     * based on the active render pipeline.
     */
    #end
    public function new() {

        renderer = new ceramic.Renderer();

        #if !unity_urp
        // For built-in render pipeline, create a persistent command buffer
        commandBuffer = untyped __cs__('new UnityEngine.Rendering.CommandBuffer()');
        untyped __cs__('UnityEngine.Camera.main.AddCommandBuffer(UnityEngine.Rendering.CameraEvent.AfterEverything, (UnityEngine.Rendering.CommandBuffer){0})', commandBuffer);
        #end

    }

    #if !no_backend_docs
    /**
     * Determines the rendering type for a visual.
     *
     * This method is called when a visual is created to determine
     * how it should be rendered. The returned VisualItem is cached
     * and used throughout the visual's lifetime to optimize rendering.
     *
     * @param visual The visual to categorize
     * @return QUAD for Quad-based visuals, MESH for Mesh-based, NONE otherwise
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function getItem(visual:ceramic.Visual):VisualItem {

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
     * Main draw method that renders all visuals.
     *
     * In the Unity editor, rendering is wrapped in a try-catch to prevent
     * crashes during hot reload or when Unity's state is inconsistent.
     * In builds, rendering runs without the safety wrapper for performance.
     *
     * @param visuals Array of visuals to render in order
     */
    #end
    public function draw(visuals:Array<ceramic.Visual>):Void {

        var isEditor:Bool = untyped __cs__('UnityEngine.Application.isEditor');
        if (isEditor) {
            try {
                _draw(visuals);
            }
            catch (e:Dynamic) {}
        }
        else {
            _draw(visuals);
        }

    }

    #if !no_backend_docs
    /**
     * Internal draw implementation.
     *
     * Captures screen dimensions for URP and delegates to the Ceramic
     * renderer for visual processing. For URP, also manages render passes.
     *
     * @param visuals Array of visuals to render
     */
    #end
    function _draw(visuals:Array<ceramic.Visual>):Void {

        #if unity_urp
        // Store dimensions for render pass configuration
        widthOnDraw = ceramic.App.app.backend.screen.getWidth();
        heightOnDraw = ceramic.App.app.backend.screen.getHeight();
        #end

        // Process visuals through Ceramic's renderer
        renderer.render(true, visuals);

        #if unity_urp
        // Add render passes for URP pipeline
        if (urpRenderer != null) {
            addRenderPasses(urpRenderer, urpRenderingData);
        }
        #end

    }

    #if !no_backend_docs
    /**
     * Swap buffers (no-op in Unity).
     *
     * Unity handles buffer swapping automatically through its rendering
     * pipeline, so this method is not needed and remains empty.
     */
    #end
    public function swap():Void {

        // Unused in unity

    }

/// Rendering

    #if !no_backend_docs
    /**
     * Maximum size of the vertex buffer in floats.
     * Unity meshes support up to 65535 vertices, so we allocate
     * buffers large enough to handle worst-case vertex data.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end static var MAX_VERTS_SIZE:Int = 65536;

    #if !no_backend_docs
    /**
     * Maximum number of indices per mesh.
     * Limited to 16384 to ensure compatibility with 16-bit index buffers.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end static var MAX_INDICES:Int = 16384;

    #if !no_backend_docs
    /**
     * Tracks whether the stencil buffer needs clearing.
     * Set to true when stencil operations are performed.
     */
    #end
    static var _stencilBufferDirty:Bool = false;

    static var _maxVerts:Int = 0;

    static var _meshes:Array<Mesh> = null;
    static var _meshesVertices:Array<backend.Float32Array> = null;
    static var _meshesIndices:Array<backend.UInt16Array> = null;
    static var _currentMeshIndex:Int = -1;
    static var _currentMesh:Mesh = null;

    static var _meshVertices:backend.Float32Array = null;
    static var _meshIndices:backend.UInt16Array = null;

    static var _materials:Materials = new Materials();

    static var _activeTextureSlot:Int = 0;
    static var _materialCurrentTextures:NativeArray<backend.Texture> = null;
    static var _materialCurrentShader:backend.Shader = null;
    static var _materialSrcRgb:backend.BlendMode = ONE;
    static var _materialDstRgb:backend.BlendMode = ONE_MINUS_SRC_ALPHA;
    static var _materialSrcAlpha:backend.BlendMode = ONE;
    static var _materialDstAlpha:backend.BlendMode = ONE_MINUS_SRC_ALPHA;
    static var _materialStencilTest:Bool = false;
    static var _materialStencilWrite:Int = 0;

    static var _viewportDensity:Float = 1.0;

    static var _viewportWidth:Float = 0.0;

    static var _viewportHeight:Float = 0.0;

    static var _stencilShader:backend.Shader = null;

    static var _currentMatrix:Dynamic = null;

    static var _currentRenderTarget:ceramic.RenderTexture = null;

    static var _projectionMatrix:Dynamic = null;

    static var _modelViewMatrix:Dynamic = null;

    static var _modelViewTransform = new ceramic.Transform();

    static var _renderTargetTransform = new ceramic.Transform();

    static var _vertexSize:Int = 0;
    static var _numIndices:Int = 0;

    static var _numPos:Int = 0;
    static var _posIndex:Int = 0;

    static var _numUVs:Int = 0;
    static var _uvIndex:Int = 0;

    static var _numColors:Int = 0;
    static var _colorIndex:Int = 0;

    static var _floatAttributesIndex:Int = 0;
    static var _meshTopology:MeshTopology = MeshTopology.Triangles;

    #if !no_backend_docs
    /**
     * Gets the current number of positions in the vertex buffer.
     *
     * Used by the renderer to track vertex count for the current batch.
     *
     * @return The number of vertex positions added since the last flush
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function getNumPos():Int {

        return _numPos;

    }

    #if !no_backend_docs
    /**
     * Adds a vertex position to the current batch.
     *
     * Positions are stored in the vertex buffer with proper stride
     * based on the current vertex format. The z coordinate is used
     * for depth sorting within the same visual.
     *
     * @param x The x coordinate in screen space
     * @param y The y coordinate in screen space
     * @param z The z coordinate for depth (usually 0 or 1)
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function putPos(x:Float32, y:Float32, z:Float32):Void {

        _meshVertices[_posIndex] = x;
        _meshVertices[_posIndex+1] = y;
        _meshVertices[_posIndex+2] = z;
        _posIndex += _vertexSize;
        _numPos++;

    }

    #if !no_backend_docs
    /**
     * Adds a vertex position with texture slot for multi-texture batching.
     *
     * When the shader supports multiple textures in a single draw call,
     * this method stores which texture slot (0-7) this vertex should
     * sample from. This enables efficient batching of visuals with
     * different textures.
     *
     * @param x The x coordinate in screen space
     * @param y The y coordinate in screen space
     * @param z The z coordinate for depth
     * @param textureSlot The texture slot index (0-7)
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function putPosAndTextureSlot(x:Float32, y:Float32, z:Float32, textureSlot:Float32):Void {

        _meshVertices[_posIndex] = x;
        _meshVertices[_posIndex+1] = y;
        _meshVertices[_posIndex+2] = z;
        _meshVertices[_posIndex+3] = textureSlot;
        _posIndex += _vertexSize;
        _numPos++;

    }

    #if !no_backend_docs
    /**
     * Adds an index to the index buffer.
     *
     * Indices define the order in which vertices are connected to form
     * triangles or lines. Unity uses 16-bit indices, limiting meshes
     * to 65535 vertices.
     *
     * @param i The vertex index to add (0-based)
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function putIndice(i:Int):Void {

        _meshIndices[_numIndices] = untyped __cs__('(ushort){0}', i);
        _numIndices++;

    }

    #if !no_backend_docs
    /**
     * Adds texture coordinates to the vertex buffer.
     *
     * UV coordinates map vertices to texture pixels. The Y coordinate
     * is flipped (1.0 - uvY) because Unity's texture coordinate system
     * has Y=0 at the bottom, while Ceramic uses Y=0 at the top.
     *
     * @param uvX The horizontal texture coordinate (0-1)
     * @param uvY The vertical texture coordinate (0-1, flipped internally)
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function putUVs(uvX:Float, uvY:Float):Void {

        _meshVertices[_uvIndex] = uvX;
        _meshVertices[_uvIndex+1] = (1.0 - uvY);
        _numUVs++;
        _uvIndex += _vertexSize;

    }

    #if !no_backend_docs
    /**
     * Adds vertex color to the vertex buffer.
     *
     * Colors are stored as RGBA values in the 0-1 range and are
     * multiplied with texture colors in the shader. This enables
     * tinting and fading effects.
     *
     * @param r Red component (0-1)
     * @param g Green component (0-1)
     * @param b Blue component (0-1)
     * @param a Alpha component (0-1)
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function putColor(r:Float, g:Float, b:Float, a:Float):Void {

        _meshVertices[_colorIndex] = r;
        _meshVertices[_colorIndex+1] = g;
        _meshVertices[_colorIndex+2] = b;
        _meshVertices[_colorIndex+3] = a;
        _numColors++;
        _colorIndex += _vertexSize;

    }

    #if !no_backend_docs
    /**
     * Begins adding custom float attributes for the current vertex.
     *
     * Called before putFloatAttribute() to prepare for custom shader
     * attributes. This is a no-op in Unity as attributes are written
     * directly to the vertex buffer.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function beginFloatAttributes():Void {

        // Nothing to do here

    }

    #if !no_backend_docs
    /**
     * Adds a custom float attribute value for the current vertex.
     *
     * Custom attributes allow shaders to receive additional per-vertex
     * data beyond position, color, and UVs. The attribute count and
     * meaning are defined by the active shader.
     *
     * @param index The attribute index (0-based)
     * @param value The float value to store
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function putFloatAttribute(index:Int, value:Float):Void {

        _meshVertices[_floatAttributesIndex+index] = value;

    }

    #if !no_backend_docs
    /**
     * Completes custom float attributes for the current vertex.
     *
     * Advances the attribute pointer to the next vertex position
     * in the buffer, preparing for the next vertex's attributes.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function endFloatAttributes():Void {

        _floatAttributesIndex += _vertexSize;

    }

    #if !no_backend_docs
    /**
     * Initializes rendering buffers and state for a new frame.
     *
     * Creates mesh pools if needed, resets texture slots, and loads
     * the stencil shader. This method is called at the beginning of
     * each frame before any drawing operations.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function initBuffers():Void {

        if (_meshes == null) {
            _meshes = [];
            _meshesVertices = [];
            _meshesIndices = [];
            _materialCurrentTextures = new NativeArray(8);
        }

        _activeTextureSlot = 0;
        _currentMeshIndex = -1;
        _currentMesh = null;

        _stencilBufferDirty = false;

        if (_stencilShader == null) {
            _stencilShader = ceramic.App.app.assets.shader('shader:stencil').backendItem;
        }

        prepareNextMesh();

    }

    #if !no_backend_docs
    /**
     * Prepares the next mesh for rendering.
     *
     * Advances to the next mesh in the pool, creating a new one if needed.
     * Mesh pooling avoids garbage collection by reusing Unity Mesh objects
     * and their associated vertex/index buffers across frames.
     */
    #end
    function prepareNextMesh() {

        _currentMeshIndex++;
        var mesh = _meshes[_currentMeshIndex];
        if (mesh == null) {
            mesh = new Mesh();
            _meshes[_currentMeshIndex] = mesh;
            _meshesVertices[_currentMeshIndex] = new backend.Float32Array(MAX_VERTS_SIZE);
            _meshesIndices[_currentMeshIndex] = new backend.UInt16Array(MAX_INDICES);
        }

        _meshVertices = _meshesVertices.unsafeGet(_currentMeshIndex);
        _meshIndices = _meshesIndices.unsafeGet(_currentMeshIndex);

        _currentMesh = mesh;

    }

    #if !no_backend_docs
    /**
     * Resets vertex buffer indices for a new batch.
     *
     * Clears counters and sets up proper offsets based on whether
     * the current shader supports multi-texture batching. Multi-texture
     * shaders need an extra float per vertex for the texture slot.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end function resetIndexes():Void {

        _numIndices = 0;

        _numPos = 0;
        _posIndex = 0;

        if (ceramic.App.app.backend.shaders.canBatchWithMultipleTextures(_materialCurrentShader)) {
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

    #if !no_backend_docs
    /**
     * Begins a new rendering frame.
     *
     * Clears command buffers, sets up the camera for pixel-perfect 2D
     * rendering, and initializes transformation matrices. The camera's
     * orthographic size is set to half the pixel height for 1:1 pixel mapping.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function beginRender():Void {

        // Reset command buffer(s)
        #if unity_urp
        clearPendingCommandBuffers();
        #else
        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        untyped __cs__('cmd.Clear()');
        #end

        untyped __cs__('UnityEngine.Camera.main.orthographicSize = UnityEngine.Camera.main.pixelHeight * 0.5f');

        untyped __cs__('var cameraHeight = 2*UnityEngine.Camera.main.orthographicSize');
        untyped __cs__('var cameraWidth = cameraHeight*UnityEngine.Camera.main.aspect');

        if (_projectionMatrix == null) {
            _projectionMatrix = untyped __cs__('UnityEngine.Matrix4x4.identity');
        }
        if (_modelViewMatrix == null) {
            _modelViewMatrix = untyped __cs__('UnityEngine.Matrix4x4.identity');
        }

    }

    #if !no_backend_docs
    /**
     * Clears the screen and applies the background color.
     *
     * Uses the background color from app settings to clear both
     * color and depth buffers. The alpha is always set to 1.0
     * for the background.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function clearAndApplyBackground():Void {

        var bg = ceramic.App.app.settings.background;
        #if unity_rendergraph
        untyped __cs__('CeramicCommandBuffer cmd = (CeramicCommandBuffer){0}', commandBuffer);
        #else
        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        #end
        untyped __cs__('cmd.ClearRenderTarget(true, true, new UnityEngine.Color((float){0}, (float){1}, (float){2}, 1f), 1f)', bg.redFloat, bg.greenFloat, bg.blueFloat);

    }

    #if !no_backend_docs
    /**
     * Sets the current render target for off-screen rendering.
     *
     * When a render target is set, all subsequent draw calls render
     * to the texture instead of the screen. The method handles viewport
     * transformation, density scaling, and proper matrix setup for the
     * render target's dimensions.
     *
     * @param renderTarget The texture to render to, or null for screen
     * @param force Force update even if target hasn't changed
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function setRenderTarget(renderTarget:ceramic.RenderTexture, force:Bool = false):Void {

        if (_currentRenderTarget != renderTarget || force) {
            _currentRenderTarget = renderTarget;
            if (renderTarget != null) {

                var backendItem:TextureImpl = renderTarget.backendItem;
                var unityRenderTexture = backendItem.unityRenderTexture;

                #if unity_urp
                configureNextCommandBuffer(renderTarget);
                #if unity_rendergraph
                untyped __cs__('CeramicCommandBuffer cmd = (CeramicCommandBuffer){0}', commandBuffer);
                #else
                untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
                #end
                #else
                untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
                untyped __cs__('cmd.SetRenderTarget((UnityEngine.RenderTexture){0})', unityRenderTexture);
                #end

                untyped __cs__('var cameraHeight = 2*UnityEngine.Camera.main.orthographicSize');
                untyped __cs__('var cameraWidth = cameraHeight*UnityEngine.Camera.main.aspect');

                var camWidth:Int = untyped __cs__('(int)cameraWidth');
                var camHeight:Int = untyped __cs__('(int)cameraHeight');

                updateProjectionMatrix(
                    renderTarget.width,
                    renderTarget.height
                );

                // Not really ideal, we invert main camera transformation
                // because it is used for everything, including render targets
                // That works though

                var translateX = ((backendItem.width * camWidth / renderTarget.width) - backendItem.width) * 0.5;
                var translateY = ((backendItem.height * camHeight / renderTarget.height) - backendItem.height) * 0.5;

                var density = renderTarget.density;

                _renderTargetTransform.identity();
                _renderTargetTransform.scale(
                    density * camWidth / renderTarget.width,
                    density * camHeight / renderTarget.height
                );
                _renderTargetTransform.translate(-translateX, -translateY);

                _viewportDensity = renderTarget.density;
                _viewportWidth = renderTarget.width * _viewportDensity;
                _viewportHeight = renderTarget.height * _viewportDensity;

                updateViewMatrix(
                    density,
                    renderTarget.width,
                    renderTarget.height,
                    _renderTargetTransform,
                    1, 1
                );

                updateCurrentMatrix();

                if (renderTarget.clearOnRender || !backendItem.usedAsRenderTarget) {
                    // We force clearing render target if it's the first time we use it.
                    // This is to prevent a bug experienced on iOS (but not necessarily exclusive to iOS)
                    // where first draw is messed up if we don't clear before.
                    backendItem.usedAsRenderTarget = true;
                    untyped __cs__('cmd.ClearRenderTarget(true, true, new UnityEngine.Color(0f, 0f, 0f, 0f), 1f)');
                }

            } else {

                #if unity_urp
                configureNextCommandBuffer(null);
                #if unity_rendergraph
                untyped __cs__('CeramicCommandBuffer cmd = (CeramicCommandBuffer){0}', commandBuffer);
                #else
                untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
                #end
                #else
                untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
                untyped __cs__('cmd.SetRenderTarget(UnityEngine.Rendering.BuiltinRenderTextureType.CameraTarget)');
                #end

                updateProjectionMatrix(
                    ceramic.App.app.backend.screen.getWidth() * ceramic.App.app.backend.screen.getDensity(),
                    ceramic.App.app.backend.screen.getHeight() * ceramic.App.app.backend.screen.getDensity()
                );
                updateViewMatrix(
                    1,//ceramic.App.app.backend.screen.getDensity(),
                    ceramic.App.app.backend.screen.getWidth(),
                    ceramic.App.app.backend.screen.getHeight(),
                    @:privateAccess ceramic.App.app.screen.matrix
                );

                _viewportDensity = ceramic.App.app.backend.screen.getDensity();
                _viewportWidth = ceramic.App.app.backend.screen.getWidth() * _viewportDensity;
                _viewportHeight = ceramic.App.app.backend.screen.getHeight() * _viewportDensity;

                updateCurrentMatrix();
            }
        }

    }

    #if !no_backend_docs
    /**
     * Updates the projection matrix for 2D orthographic rendering.
     *
     * Creates a projection matrix that maps screen coordinates directly
     * to clip space, with Y-axis flipped to match Ceramic's coordinate
     * system (Y=0 at top).
     *
     * @param width The viewport width in pixels
     * @param height The viewport height in pixels
     */
    #end
    #if !ceramic_debug_draw_backend inline #end function updateProjectionMatrix(width:Float, height:Float):Void {

        // Making orthographic projection
        //
        untyped __cs__('
        UnityEngine.Matrix4x4 m = UnityEngine.Matrix4x4.identity;
        m[12] = (float){0} * -0.5f;
        m[13] = (float){1} * 0.5f;
        m[5] = m[5] * -1f;
        ', width, height);

        _projectionMatrix = untyped __cs__('m');

    }

    #if !no_backend_docs
    /**
     * Updates the view matrix with camera transformation.
     *
     * Applies density scaling and optional transformations to the view.
     * Can flip the view horizontally or vertically, which is used when
     * rendering to textures.
     *
     * @param density The pixel density multiplier
     * @param width The viewport width
     * @param height The viewport height
     * @param transform Optional camera transform to apply
     * @param flipX Horizontal flip factor (-1 to flip, 1 normal)
     * @param flipY Vertical flip factor (-1 to flip, 1 normal)
     */
    #end
    #if !ceramic_debug_draw_backend inline #end function updateViewMatrix(density:Float, width:Float, height:Float, ?transform:ceramic.Transform, flipX:Float = 1, flipY:Float = 1):Void {

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

        if (flipX == -1 || flipY == -1) {
            // Flip vertically/horizontally (may be needed when we are rendering to texture)
            _modelViewTransform.translate(
                -width * 0.5,
                -height * 0.5
            );
            _modelViewTransform.scale(flipX, flipY);
            _modelViewTransform.translate(
                width * 0.5,
                height * 0.5
            );
        }

        _modelViewTransform.invert();

        _modelViewMatrix = transformToMatrix4x4(_modelViewTransform);

    }

    #if !no_backend_docs
    /**
     * Updates the combined projection-view matrix.
     *
     * Multiplies the projection and model-view matrices to create
     * the final transformation matrix used for rendering.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end function updateCurrentMatrix():Void {

        untyped __cs__('UnityEngine.Matrix4x4 matrix = ((UnityEngine.Matrix4x4){0}) * ((UnityEngine.Matrix4x4){1})', _projectionMatrix, _modelViewMatrix);

        _currentMatrix = untyped __cs__('matrix');

    }

    #if !no_backend_docs
    /**
     * Converts a Ceramic Transform to a Unity Matrix4x4.
     *
     * Maps the 2D affine transformation (a,b,c,d,tx,ty) to a 4x4 matrix
     * suitable for Unity's rendering pipeline. The Z components are set
     * for identity transformation in the Z axis.
     *
     * @param transform The 2D transform to convert
     * @return A Unity Matrix4x4 representing the transformation
     */
    #end
    #if !ceramic_debug_draw_backend inline #end function transformToMatrix4x4(transform:Transform):Dynamic {

        untyped __cs__('UnityEngine.Matrix4x4 m = UnityEngine.Matrix4x4.identity');

        untyped __cs__('
        m[0] = (float){0}; m[4] = (float){1}; m[8] = 0f;  m[12] = (float){2};
        m[1] = (float){3}; m[5] = (float){4}; m[9] = 0f;  m[13] = (float){5};
        m[2] = 0f;  m[6] = 0f;  m[10] = 1f; m[14] = 0f;
        m[3] = 0f;  m[7] = 0f;  m[11] = 0f; m[15] = 1f;
        ', transform.a, transform.c, transform.tx, transform.b, transform.d, transform.ty);

        return untyped __cs__('m');

    }

    #if !no_backend_docs
    /**
     * Sets the active shader for subsequent draw operations.
     *
     * Configures vertex layout based on shader requirements, including
     * custom attributes and multi-texture support. When stencil writing
     * is active, overrides with the stencil shader.
     *
     * @param shader The shader implementation to use
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function useShader(shader:backend.ShaderImpl):Void {

        _materialCurrentShader = _materialStencilWrite != 0 ? _stencilShader : shader;

        var attributesSize = ceramic.App.app.backend.shaders.customFloatAttributesSize(_materialCurrentShader);
        if (attributesSize % 2 == 1) attributesSize++;

        _vertexSize = 9 + attributesSize + (ceramic.App.app.backend.shaders.canBatchWithMultipleTextures(_materialCurrentShader) ? 1 : 0);

        _maxVerts = Std.int(Math.floor(MAX_VERTS_SIZE / _vertexSize));

        if (_posIndex == 0) {
            resetIndexes();
        }

    }

    #if !no_backend_docs
    /**
     * Clears the current render target.
     *
     * Clears both color (to transparent white) and depth buffers.
     * Used when starting to render to a new target or clearing
     * specific regions.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function clear():Void {

        #if unity_rendergraph
        untyped __cs__('CeramicCommandBuffer cmd = (CeramicCommandBuffer){0}', commandBuffer);
        #else
        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        #end
        untyped __cs__('cmd.ClearRenderTarget(true, true, new UnityEngine.Color(1f, 1f, 1f, 0f), 1f)');

    }

    #if !no_backend_docs
    /**
     * Enables alpha blending (no-op in Unity).
     *
     * Unity always has blending enabled for transparent materials,
     * so this method is empty. Blend modes are controlled through
     * setBlendFuncSeparate() instead.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function enableBlending():Void {

        // Blending always enabled

    }

    #if !no_backend_docs
    /**
     * Disables alpha blending (no-op in Unity).
     *
     * Unity requires blending for proper 2D rendering with transparency,
     * so this method is empty. The framework always uses blended materials.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function disableBlending():Void {

        // Blending always enabled

    }

    #if !no_backend_docs
    /**
     * Sets the blend function for color and alpha channels separately.
     *
     * Configures how source pixels are blended with destination pixels.
     * These settings are applied when getting or creating materials,
     * allowing different blend modes for different draw calls.
     *
     * @param srcRgb Source blend factor for RGB channels
     * @param dstRgb Destination blend factor for RGB channels
     * @param srcAlpha Source blend factor for alpha channel
     * @param dstAlpha Destination blend factor for alpha channel
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function setBlendFuncSeparate(srcRgb:backend.BlendMode, dstRgb:backend.BlendMode, srcAlpha:backend.BlendMode, dstAlpha:backend.BlendMode):Void {

        _materialSrcRgb = srcRgb;
        _materialDstRgb = dstRgb;
        _materialSrcAlpha = srcAlpha;
        _materialDstAlpha = dstAlpha;

    }

    #if !no_backend_docs
    /**
     * Gets the currently active texture slot.
     *
     * Unity supports up to 8 texture slots (0-7) for multi-texture
     * batching in custom shaders.
     *
     * @return The active texture slot index (0-7)
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function getActiveTexture():Int {

        return _activeTextureSlot;

    }

    #if !no_backend_docs
    /**
     * Sets the active texture slot for subsequent texture bindings.
     *
     * When binding textures, they are assigned to the currently active
     * slot. This enables multi-texture rendering with custom shaders.
     *
     * @param slot The texture slot to activate (0-7)
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function setActiveTexture(slot:Int):Void {

        _activeTextureSlot = slot;

    }

    #if !no_backend_docs
    /**
     * Checks if a texture backend item matches a given texture ID.
     *
     * Used to verify texture identity without comparing object references,
     * which is important for texture caching and batching decisions.
     *
     * @param backendItem The texture to check
     * @param textureId The ID to compare against
     * @return True if the texture has the specified ID
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function textureBackendItemMatchesId(backendItem:backend.Texture, textureId:backend.TextureId):Bool {

        return (backendItem:TextureImpl).textureId == textureId;

    }

    #if !no_backend_docs
    /**
     * Gets the unique identifier for a texture.
     *
     * Each texture has a unique ID used for comparison and caching.
     * This avoids object reference comparisons which can be unreliable.
     *
     * @param backendItem The texture to get the ID from
     * @return The texture's unique identifier
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function getTextureId(backendItem:backend.Texture):backend.TextureId {

        return (backendItem:TextureImpl).textureId;

    }

    #if !no_backend_docs
    /**
     * Gets the width of a texture in pixels.
     *
     * Returns the logical width, which may differ from the actual
     * GPU texture width if the texture uses power-of-two padding.
     *
     * @param texture The texture to query
     * @return The texture width in pixels
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function getTextureWidth(texture:backend.Texture):Int {

        return (texture:TextureImpl).width;

    }

    #if !no_backend_docs
    /**
     * Gets the height of a texture in pixels.
     *
     * Returns the logical height, which may differ from the actual
     * GPU texture height if the texture uses power-of-two padding.
     *
     * @param texture The texture to query
     * @return The texture height in pixels
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function getTextureHeight(texture:backend.Texture):Int {

        return (texture:TextureImpl).height;

    }

    #if !no_backend_docs
    /**
     * Gets the actual GPU width of a texture.
     *
     * In Unity, textures don't require power-of-two dimensions,
     * so this returns the same value as getTextureWidth().
     *
     * @param texture The texture to query
     * @return The actual texture width on GPU
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function getTextureWidthActual(texture:backend.Texture):Int {

        return (texture:TextureImpl).width;

    }

    #if !no_backend_docs
    /**
     * Gets the actual GPU height of a texture.
     *
     * In Unity, textures don't require power-of-two dimensions,
     * so this returns the same value as getTextureHeight().
     *
     * @param texture The texture to query
     * @return The actual texture height on GPU
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function getTextureHeightActual(texture:backend.Texture):Int {

        return (texture:TextureImpl).height;

    }

    #if !no_backend_docs
    /**
     * Binds a texture to the current active texture slot.
     *
     * The texture will be used in the active slot for subsequent
     * draw operations. Multiple textures can be bound to different
     * slots for multi-texture rendering.
     *
     * @param backendItem The texture to bind
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function bindTexture(backendItem:backend.Texture):Void {

        _materialCurrentTextures[_activeTextureSlot] = backendItem;

    }

    #if !no_backend_docs
    /**
     * Unbinds the texture from the current active slot.
     *
     * Sets the active texture slot to null, which will cause
     * the shader to use a default white texture or skip
     * texture sampling for that slot.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function bindNoTexture():Void {

        _materialCurrentTextures[_activeTextureSlot] = null;

    }

    #if !no_backend_docs
    /**
     * Sets the primitive type for subsequent geometry.
     *
     * Determines whether vertices will be connected as triangles
     * (for filled shapes) or lines (for stroked shapes).
     *
     * @param primitiveType The primitive type (TRIANGLE or LINE)
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function setPrimitiveType(primitiveType:ceramic.RenderPrimitiveType):Void {

        _meshTopology = switch primitiveType {
            case LINE: MeshTopology.Lines;
            case _: MeshTopology.Triangles;
        }

    }

    #if !no_backend_docs
    /**
     * Begins drawing a Quad visual (no-op).
     *
     * Called before rendering a Quad's vertices. Currently empty
     * as no special setup is needed for quads in Unity.
     *
     * @param quad The quad being drawn
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function beginDrawQuad(quad:ceramic.Quad):Void {

    }

    #if !no_backend_docs
    /**
     * Ends drawing a Quad visual (no-op).
     *
     * Called after rendering a Quad's vertices. Currently empty
     * as no special cleanup is needed for quads in Unity.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function endDrawQuad():Void {

    }

    #if !no_backend_docs
    /**
     * Begins drawing a Mesh visual (no-op).
     *
     * Called before rendering a Mesh's vertices. Currently empty
     * as no special setup is needed for meshes in Unity.
     *
     * @param mesh The mesh being drawn
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function beginDrawMesh(mesh:ceramic.Mesh):Void {

    }

    #if !no_backend_docs
    /**
     * Ends drawing a Mesh visual (no-op).
     *
     * Called after rendering a Mesh's vertices. Currently empty
     * as no special cleanup is needed for meshes in Unity.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function endDrawMesh():Void {

    }

    #if !no_backend_docs
    /**
     * Enables scissor testing to clip rendering to a rectangle.
     *
     * Only pixels within the scissor rectangle will be rendered.
     * The rectangle is transformed by the current view matrix and
     * adjusted for pixel density. Coordinates are in screen space.
     *
     * @param x The left edge of the scissor rectangle
     * @param y The top edge of the scissor rectangle
     * @param width The width of the scissor rectangle
     * @param height The height of the scissor rectangle
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function enableScissor(x:Float, y:Float, width:Float, height:Float):Void {

        var density = _viewportDensity;
        var left = 0.0;
        var top = 0.0;
        var right = 0.0;
        var bottom = 0.0;

        if (_currentRenderTarget != null) {
            left = x * density;
            top = y * density;
            right = (x + width) * density;
            bottom = (y + height) * density;
        }
        else {
            left = _modelViewTransform.transformX(x, y) * density;
            top = _modelViewTransform.transformY(x, y) * density;
            right = _modelViewTransform.transformX(x + width, y + height) * density;
            bottom = _modelViewTransform.transformY(x + width, y + height) * density;
        }

        var singleX:Single = left;
        var singleY:Single = _viewportHeight - bottom;
        var singleW:Single = right - left;
        var singleH:Single = bottom - top;

        #if unity_rendergraph
        untyped __cs__('CeramicCommandBuffer cmd = (CeramicCommandBuffer){0}', commandBuffer);
        #else
        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        #end
        untyped __cs__('cmd.EnableScissorRect(new UnityEngine.Rect({0}, {1}, {2}, {3}))', singleX, singleY, singleW, singleH);

    }

    #if !no_backend_docs
    /**
     * Disables scissor testing.
     *
     * Restores full viewport rendering without clipping.
     * Should be called after scissor-clipped rendering is complete.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function disableScissor():Void {

        #if unity_rendergraph
        untyped __cs__('CeramicCommandBuffer cmd = (CeramicCommandBuffer){0}', commandBuffer);
        #else
        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        #end
        untyped __cs__('cmd.DisableScissorRect()');

    }

    #if !no_backend_docs
    /**
     * Begins drawing to the stencil buffer.
     *
     * Flushes any pending geometry, then clears the stencil buffer
     * if it's dirty by drawing a fullscreen quad. Subsequent draw
     * calls will write to the stencil buffer instead of color.
     * The stencil buffer is used for masking and clipping effects.
     */
    #end
    public function beginDrawingInStencilBuffer():Void {

        if (hasAnythingToFlush())
            flush();

        if (_stencilBufferDirty) {
            // Clear before writing
            _materialStencilWrite = 2;
            useShader(null);
            var w = ceramic.App.app.backend.screen.getWidth();
            var h = ceramic.App.app.backend.screen.getHeight();
            if (_currentRenderTarget != null) {
                w = Math.ceil(_currentRenderTarget.width);
                h = Math.ceil(_currentRenderTarget.height);
            }
            putPos(0, 0, 1);
            putPos(w, 0, 1);
            putPos(w, h, 1);
            putPos(0, h, 1);
            putIndice(0);
            putIndice(1);
            putIndice(2);
            putIndice(0);
            putIndice(2);
            putIndice(3);
            putUVs(0, 0);
            putUVs(0, 0);
            putUVs(0, 0);
            putUVs(0, 0);
            putColor(1, 1, 1, 1);
            putColor(1, 1, 1, 1);
            putColor(1, 1, 1, 1);
            putColor(1, 1, 1, 1);
            flush();
        }

        // Start writing
        _materialStencilWrite = 1;
        _stencilBufferDirty = true;

    }

    #if !no_backend_docs
    /**
     * Ends drawing to the stencil buffer.
     *
     * Stops writing to the stencil buffer. Subsequent draw calls
     * will render to the color buffer again.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function endDrawingInStencilBuffer():Void {

        _materialStencilWrite = 0;

    }

    #if !no_backend_docs
    /**
     * Enables stencil testing for subsequent draws.
     *
     * When enabled, pixels will only be drawn where the stencil
     * buffer has been written to. Used for masking effects.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function drawWithStencilTest():Void {

        _materialStencilTest = true;

    }

    #if !no_backend_docs
    /**
     * Disables stencil testing for subsequent draws.
     *
     * When disabled, pixels are drawn regardless of stencil buffer
     * contents. This is the default rendering mode.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function drawWithoutStencilTest():Void {

        _materialStencilTest = false;

    }

    #if !no_backend_docs
    /**
     * Checks if the current batch should be flushed before adding more geometry.
     *
     * Returns true if adding the specified vertices/indices would exceed
     * buffer limits. The renderer uses this to decide when to submit
     * the current batch and start a new one.
     *
     * @param numVerticesAfter Number of vertices to be added
     * @param numIndicesAfter Number of indices to be added
     * @param customFloatAttributesSize Size of custom attributes (unused)
     * @return True if flush is needed before adding more geometry
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function shouldFlush(numVerticesAfter:Int, numIndicesAfter:Int, customFloatAttributesSize:Int):Bool {

        return (_numPos + numVerticesAfter > _maxVerts || _numIndices + numIndicesAfter > MAX_INDICES);

    }

    #if !no_backend_docs
    /**
     * Gets the number of vertices that can be added before flush.
     *
     * Used by the renderer to optimize batching by filling buffers
     * as much as possible before submitting draw calls.
     *
     * @return Number of vertices that can still be added
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function remainingVertices():Int {

        return _maxVerts - _numPos;

    }

    #if !no_backend_docs
    /**
     * Gets the number of indices that can be added before flush.
     *
     * Used by the renderer to optimize batching by filling index
     * buffers as much as possible before submitting draw calls.
     *
     * @return Number of indices that can still be added
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function remainingIndices():Int {

        return MAX_INDICES - _numIndices;

    }

    #if !no_backend_docs
    /**
     * Checks if there's any geometry waiting to be rendered.
     *
     * Returns true if any vertices have been added since the last
     * flush. Used to avoid empty draw calls.
     *
     * @return True if there are vertices to render
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function hasAnythingToFlush():Bool {

        return _numPos > 0;

    }

    #if !no_backend_docs
    /**
     * Submits the current batch of geometry to the GPU.
     *
     * This is the core rendering method that:
     * 1. Uploads vertex and index data to the current Unity Mesh
     * 2. Gets or creates a Material with the current render state
     * 3. Issues a draw command through the command buffer
     * 4. Resets buffers and prepares for the next batch
     *
     * The method handles stencil states, multiple textures, custom
     * shaders, and blend modes through the material system.
     */
    #end
    #if !ceramic_debug_draw_backend inline #end public function flush():Void {

        var mesh = _currentMesh;

        var stencil:backend.StencilState = NONE;
        var shader:backend.Shader = _materialCurrentShader;

        if (_materialStencilWrite != 0) {
            stencil = _materialStencilWrite == 2 ? CLEAR : WRITE;
        }
        else if (_materialStencilTest) {
            stencil = TEST;
        }

        // final shaderImpl:backend.ShaderImpl = shader;
        // @:privateAccess if (!shaderImpl.isBatchingMultiTexture && shaderImpl.textureSlots != null) {
        //     var i = 0;
        //     while (i < shaderImpl.textureSlots.length && i < _materialCurrentTextures.length) {
        //         final textureInSlot = shaderImpl.textureSlots[i];
        //         if (textureInSlot != null) {
        //             trace("ASSIGN SLOT #" + i + " -> " + textureInSlot;)
        //             _materialCurrentTextures[i] = textureInSlot;
        //         }
        //         i++;
        //     }
        // }

        var materialData = _materials.get(
            _materialCurrentTextures,
            shader,
            _materialSrcRgb,
            _materialDstRgb,
            _materialSrcAlpha,
            _materialDstAlpha,
            stencil
        );

        var updateFlags:MeshUpdateFlags = untyped __cs__('UnityEngine.Rendering.MeshUpdateFlags.DontValidateIndices | UnityEngine.Rendering.MeshUpdateFlags.DontResetBoneBounds | UnityEngine.Rendering.MeshUpdateFlags.DontNotifyMeshUsers | UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds');

        // Vertex buffer layout (positions, colors, uvs & custom float attributes)
        mesh.SetVertexBufferParams(_numPos, materialData.vertexBufferAttributes);

        // Vertex buffer data
        mesh.SetVertexBufferData(_meshVertices, 0, 0, _numPos * _vertexSize, 0, updateFlags);

        // Index buffer layout
        mesh.SetIndexBufferParams(_numIndices, IndexFormat.UInt16);

        // Index buffer data
        mesh.SetIndexBufferData(_meshIndices, 0, 0, _numIndices, updateFlags);

        // Configure sub mesh
        mesh.subMeshCount = 1;
        var submesh:SubMeshDescriptor = new SubMeshDescriptor(
            0, _numIndices, _meshTopology
        );
        mesh.SetSubMesh(0, submesh, updateFlags);

        #if unity_rendergraph
        untyped __cs__('CeramicCommandBuffer cmd = (CeramicCommandBuffer){0}', commandBuffer);
        #else
        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        #end
        untyped __cs__('cmd.DrawMesh({0}, (UnityEngine.Matrix4x4){1}, (UnityEngine.Material){2})', mesh, _currentMatrix, materialData.material);

        resetIndexes();

        prepareNextMesh();

    }

/// Universal Render Pipeline

#if unity_urp

    #if !no_backend_docs
    /**
     * The current URP scriptable renderer.
     * Set by the render feature during rendering.
     */
    #end
    var urpRenderer:ScriptableRenderer = null;

    #if !no_backend_docs
    /**
     * Current frame's rendering data from URP.
     * Contains camera and lighting information.
     */
    #end
    var urpRenderingData:RenderingData;

    #if !no_backend_docs
    /**
     * Pool of render passes for main camera rendering.
     * Reused across frames to avoid allocations.
     */
    #end
    var mainCameraRenderPasses:Array<CeramicRenderPass> = [];

    #if !no_backend_docs
    /**
     * Pool of render passes for render texture targets.
     * Each render texture gets its own pass.
     */
    #end
    var customTargetRenderPasses:Array<CeramicRenderPass> = [];

    #if !no_backend_docs
    /**
     * Command buffers waiting to be assigned to render passes.
     * Cleared after each frame.
     */
    #end
    var pendingCommandBuffers:Array<CommandBuffer> = [];

    #if !no_backend_docs
    /**
     * Render targets corresponding to pending command buffers.
     * Null entries indicate main camera rendering.
     */
    #end
    var pendingRenderTargets:Array<ceramic.RenderTexture> = [];

    #if !no_backend_docs
    /**
     * Screen width captured during draw for render pass setup.
     */
    #end
    var widthOnDraw:Int = -1;

    #if !no_backend_docs
    /**
     * Screen height captured during draw for render pass setup.
     */
    #end
    var heightOnDraw:Int = -1;

    #if !no_backend_docs
    /**
     * Clears the lists of pending command buffers and render targets.
     *
     * Called at the beginning of each frame to reset URP state.
     */
    #end
    function clearPendingCommandBuffers():Void {

        pendingCommandBuffers.setArrayLength(0);
        pendingRenderTargets.setArrayLength(0);

    }

    #if !no_backend_docs
    /**
     * Allocates a new command buffer for the next batch of draw commands.
     *
     * Gets a buffer from Unity's pool and tracks it along with its
     * target for later assignment to render passes.
     *
     * @param renderTarget The target texture, or null for screen
     */
    #end
    function configureNextCommandBuffer(renderTarget:ceramic.RenderTexture):Void {

        commandBuffer = CommandBufferPool.Get();
        pendingCommandBuffers.push(commandBuffer);
        pendingRenderTargets.push(renderTarget);

    }

    #if !no_backend_docs
    /**
     * Creates and enqueues render passes for all pending command buffers.
     *
     * This method is called by URP to add Ceramic's render passes to the
     * frame. It creates or reuses CeramicRenderPass instances for each
     * command buffer, configures their render targets, and enqueues them
     * with the scriptable renderer.
     *
     * @param renderer The URP scriptable renderer
     * @param renderingData Current frame's rendering data
     */
    #end
    function addRenderPasses(renderer:ScriptableRenderer, renderingData:RenderingData):Void {

        var nMain = 0;
        var nCustom = 0;

        for (i in 0...pendingCommandBuffers.length) {
            var cmd = pendingCommandBuffers.unsafeGet(i);
            var renderTarget = pendingRenderTargets.unsafeGet(i);

            if (renderTarget != null && renderTarget.destroyed) {
                // Skipping rendering these commands because
                // the related render target is already destroyed
                ceramic.Shortcuts.log.warning('Trying to render destroyed render texture: $renderTarget');
                continue;
            }

            // Get or create render pass
            var renderPass:CeramicRenderPass = null;
            if (renderTarget == null) {
                renderPass = mainCameraRenderPasses[nMain];
                if (renderPass == null) {
                    renderPass = new CeramicRenderPass();
                    mainCameraRenderPasses[nMain] = renderPass;
                }
                nMain++;
            }
            else {
                renderPass = customTargetRenderPasses[nCustom];
                if (renderPass == null) {
                    renderPass = new CeramicRenderPass();
                    customTargetRenderPasses[nCustom] = renderPass;
                }
                nCustom++;
            }

            // Update render pass command buffer
            #if !unity_rendergraph
            // When using render graph, the command buffer will be released from the render pass directly
            var prevCmd = renderPass.GetCommandBuffer();
            if (prevCmd != null) {
                CommandBufferPool.Release(prevCmd);
            }
            #end
            #if unity_rendergraph
            renderPass.SetCeramicCommandBuffer(cmd);
            #else
            renderPass.SetCommandBuffer(cmd);
            #end
            #if unity_6000
            if (renderTarget != null) {
                untyped __cs__('{0}.SetRenderTarget((UnityEngine.Rendering.RTHandle){1})', renderPass, renderTarget.backendItem.unityRtHandle);
                #if unity_rendergraph
                untyped __cs__('{0}.SetRenderTargetDepth((UnityEngine.Rendering.RTHandle){1})', renderPass, renderTarget.backendItem.unityRtHandleDepth);
                #end
            }
            else {
                untyped __cs__('{0}.SetRenderTarget(null)', renderPass);
                #if unity_rendergraph
                untyped __cs__('{0}.SetRenderTargetDepth(null)', renderPass);
                #end
            }
            #else
            if (renderTarget != null) {
                untyped __cs__('{0}.SetRenderTarget((UnityEngine.RenderTexture){1})', renderPass, renderTarget.backendItem.unityRenderTexture);
            }
            else {
                untyped __cs__('{0}.SetRenderTarget(UnityEngine.Rendering.BuiltinRenderTextureType.CameraTarget)', renderPass);
            }
            #end

            // Add render pass
            renderer.EnqueuePass(renderPass);
        }

        clearPendingCommandBuffers();

    }

    #if !no_backend_docs
    /**
     * Entry point called by CeramicRenderFeature in URP.
     *
     * This static method is invoked through reflection from the Unity
     * render feature. It stores the renderer and rendering data, then
     * triggers a render pass update to process Ceramic's visuals.
     *
     * @param renderer The URP scriptable renderer
     * @param renderingData Current frame's rendering data
     */
    #end
    @:keep
    public static function unityUrpAddRenderPasses(renderer:ScriptableRenderer, renderingData:RenderingData):Void {

        if (!Main.hasCriticalError() && ceramic.App.app != null && ceramic.App.app.backend != null) {
            if (ceramic.App.app.backend.draw != null) {
                ceramic.App.app.backend.draw.urpRenderer = renderer;
                ceramic.App.app.backend.draw.urpRenderingData = renderingData;
            }
            Main.renderPassUpdate();
        }

    }

#end

/// Internal

    #if !no_backend_docs
    /**
     * The Ceramic renderer that processes visuals into draw commands.
     * Handles visual sorting, culling, and batch optimization.
     */
    #end
    var renderer:ceramic.Renderer;

    #if !no_backend_docs
    /**
     * The current command buffer receiving draw commands.
     * For built-in pipeline, this is a single persistent buffer.
     * For URP, this changes per render pass.
     */
    #end
    var commandBuffer:CommandBuffer;

}
