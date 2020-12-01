package backend;

import unityengine.rendering.SubMeshDescriptor;
import cs.types.UInt16;
import unityengine.Mesh;
import unityengine.Color;
import unityengine.Vector2;
import unityengine.Vector3;
import unityengine.MeshTopology;
import unityengine.rendering.IndexFormat;
import unityengine.rendering.MeshUpdateFlags;
import unityengine.rendering.VertexAttributeDescriptor;
import unityengine.rendering.VertexAttribute;
import unityengine.rendering.VertexAttributeFormat;
import ceramic.Transform;
import cs.StdTypes.Int16;
import cs.NativeArray;

using ceramic.Extensions;

@:allow(backend.Backend)
class Draw #if !completion implements spec.Draw #end {

/// Public API

    public function new() {

        renderer = new ceramic.Renderer();

        commandBuffer = untyped __cs__('new UnityEngine.Rendering.CommandBuffer()');
        untyped __cs__('UnityEngine.Camera.main.AddCommandBuffer(UnityEngine.Rendering.CameraEvent.AfterEverything, (UnityEngine.Rendering.CommandBuffer){0})', commandBuffer);

    }

    inline public function getItem(visual:ceramic.Visual):VisualItem {

        // The backend decides how each visual should be drawn.
        // Instead of checking instance type at each draw iteration,
        // The backend provides/computes a VisualItem object when
        // a visual is instanciated that it can later re-use
        // at each draw iteration to read/store per visual data.

        if (Std.is(visual, ceramic.Quad)) {
            return QUAD;
        }
        else if (Std.is(visual, ceramic.Mesh)) {
            return MESH;
        }
        else {
            return NONE;
        }

    }

    public function draw(visuals:Array<ceramic.Visual>):Void {

        renderer.render(true, visuals);

    }

    public function swap():Void {

        // Unused in unity

    }

/// Rendering

    inline static var MAX_VERTS_SIZE:Int = 65536;
    inline static var MAX_INDICES:Int = 16384;

    static var _stencilBufferDirty:Bool = false;

    static var _maxVerts:Int = 0;

    static var _meshes:Array<Mesh> = null;
    static var _meshesVertices:Array<backend.Float32Array> = null;
    static var _meshesIndices:Array<backend.UInt16Array> = null;
    static var _currentMeshIndex:Int = -1;
    static var _currentMesh:Mesh = null;

    static var _meshVertices:backend.Float32Array = null;
    static var _meshIndices:backend.UInt16Array = null;
    //static var _meshUVs:NativeArray<Vector2> = null;
    //static var _meshColors:NativeArray<Color> = null;

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

    static var _stencilShader:backend.Shader;

    //static var _currentMaterial:Dynamic = null;
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

    inline public function getNumPos():Int {

        return _numPos;

    }

    inline public function putPos(x:Float, y:Float, z:Float):Void {

        _meshVertices[_posIndex] = x;
        _meshVertices[_posIndex+1] = y;
        _meshVertices[_posIndex+2] = z;
        _posIndex += _vertexSize;
        _numPos++;

    }

    inline public function putPosAndTextureSlot(x:Float, y:Float, z:Float, textureSlot:Float):Void {

        _meshVertices[_posIndex] = x;
        _meshVertices[_posIndex+1] = y;
        _meshVertices[_posIndex+2] = z;
        _meshVertices[_posIndex+3] = textureSlot;
        _posIndex += _vertexSize;
        _numPos++;

    }

    inline public function putIndice(i:Int):Void {

        _meshIndices[_numIndices] = untyped __cs__('(ushort){0}', i);
        _numIndices++;

    }

    inline public function putUVs(uvX:Float, uvY:Float):Void {

        //_meshUVs[_numUVs] = new Vector2(uvX, 1.0 - uvY);
        _meshVertices[_uvIndex] = uvX;
        _meshVertices[_uvIndex+1] = (1.0 - uvY);
        _numUVs++;
        _uvIndex += _vertexSize;

    }

    inline public function putColor(r:Float, g:Float, b:Float, a:Float):Void {

        //_meshColors[_numColors] = new Color(r, g, b, a);
        _meshVertices[_colorIndex] = r;
        _meshVertices[_colorIndex+1] = g;
        _meshVertices[_colorIndex+2] = b;
        _meshVertices[_colorIndex+3] = a;
        _numColors++;
        _colorIndex += _vertexSize;

    }

    inline public function beginFloatAttributes():Void {

        // Nothing to do here

    }

    inline public function putFloatAttribute(index:Int, value:Float):Void {

        _meshVertices[_floatAttributesIndex+index] = value;

    }

    inline public function endFloatAttributes():Void {

        _floatAttributesIndex += _vertexSize;

    }

    inline public function initBuffers():Void {

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

    function prepareNextMesh() {

        _currentMeshIndex++;
        var mesh = _meshes[_currentMeshIndex];
        if (mesh == null) {
            mesh = new Mesh();
            _meshes[_currentMeshIndex] = mesh;
            _meshesVertices[_currentMeshIndex] = new backend.Float32Array(MAX_VERTS_SIZE);
            _meshesIndices[_currentMeshIndex] = new backend.UInt16Array(MAX_INDICES);

            //mesh.vertices = new NativeArray<Vector3>(_maxVerts);
            //mesh.triangles = new NativeArray<Int>(MAX_INDICES);
            //mesh.uv = new NativeArray<Vector2>(_maxVerts);
            //mesh.colors = new NativeArray<Color>(_maxVerts);
        }

        //_meshVertices = mesh.vertices;
        _meshVertices = _meshesVertices[_currentMeshIndex];
        _meshIndices = _meshesIndices[_currentMeshIndex];
        //_meshIndices = mesh.triangles;
        //_meshUVs = mesh.uv;
        //_meshColors = mesh.colors;

        _currentMesh = mesh;

    }

    inline function resetIndexes():Void {

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

    inline public function beginRender():Void {

        // Reset command buffer
        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        untyped __cs__('cmd.Clear()');

        //_currentMaterial = new Material(unityengine.Shader.Find("Sprites/Default"));
        //_currentMaterial = untyped __cs__('new UnityEngine.Material(UnityEngine.Shader.Find("Sprites/Default"))');

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

    inline public function clearAndApplyBackground():Void {

        var bg = ceramic.App.app.settings.background;
        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        untyped __cs__('cmd.ClearRenderTarget(true, true, new UnityEngine.Color((float){0}, (float){1}, (float){2}, 1f), 1f)', bg.redFloat, bg.greenFloat, bg.blueFloat);
        
    }

    inline public function setRenderTarget(renderTarget:ceramic.RenderTexture, force:Bool = false):Void {

        if (_currentRenderTarget != renderTarget || force) {
            _currentRenderTarget = renderTarget;
            if (renderTarget != null) {

                // TODO update unity render target
                //var renderTexture:backend.impl.CeramicRenderTexture = cast renderTarget.backendItem;
                //luxeRenderer.target = renderTexture;
                var backendItem:TextureImpl = renderTarget.backendItem;
                var unityRenderTexture = backendItem.unityRenderTexture;

                untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
                untyped __cs__('cmd.SetRenderTarget((UnityEngine.RenderTexture){0})', unityRenderTexture);

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

                updateViewMatrix(
                    density,
                    renderTarget.width,
                    renderTarget.height,
                    _renderTargetTransform,
                    1, 1
                );

                updateCurrentMatrix();

                // TODO Update unity camera matrix
                // GL.viewport(
                //     0, 0,
                //     Std.int(renderTarget.width * renderTarget.density),
                //     Std.int(renderTarget.height * renderTarget.density)
                // );
                // TODO clear
                //if (renderTarget.clearOnRender) Luxe.renderer.clear(blackTransparentColor);
                if (renderTarget.clearOnRender) {
                    untyped __cs__('cmd.ClearRenderTarget(true, true, new UnityEngine.Color(0f, 0f, 0f, 0f), 1f)');
                }
                
            } else {
                // TODO update unity render target
                //luxeRenderer.target = null;
          
                untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
                untyped __cs__('cmd.SetRenderTarget(UnityEngine.Rendering.BuiltinRenderTextureType.CameraTarget)');
                
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

                updateCurrentMatrix();

                // TODO Update unity camera matrix
                // GL.viewport(
                //     0, 0,
                //     Std.int(ceramic.App.app.backend.screen.getWidth() * ceramic.App.app.backend.screen.getDensity()),
                //     Std.int(ceramic.App.app.backend.screen.getHeight() * ceramic.App.app.backend.screen.getDensity())
                // );
            }
        }

    }

    inline function updateProjectionMatrix(width:Float, height:Float):Void {

        // // Making orthographic projection
        // //

        // var left = 0.0;
        // var top = 0.0;
        // var right = width;
        // var bottom = height;
        // var near = 1000.0;
        // var far = -1000.0;

        // var w = right - left;
        // var h = top - bottom;
        // var p = far - near;

        // var tx = (right + left)   / w;
        // var ty = (top   + bottom) / h;
        // var tz = (far   + near)   / p;

        // untyped __cs__('UnityEngine.Matrix4x4 m = UnityEngine.Matrix4x4.identity');

        // untyped __cs__('
        // m[0] = (float)(2.0 / {0});  m[4] = 0f;      m[8] = 0f;       m[12] = (float)-{1};
        // m[1] = 0f;      m[5] = (float)(2.0 / {2});  m[9] = 0f;       m[13] = (float)-{3};
        // m[2] = 0f;      m[6] = 0f;        m[10] = (float)(-2 / {4}); m[14] = (float)-{5};
        // m[3] = 0f;      m[7] = 0f;        m[11] = 0f;      m[15] = 1f;
        // ', w, tx, h, ty, p, tz);

        untyped __cs__('
        UnityEngine.Matrix4x4 m = UnityEngine.Matrix4x4.identity;
		m[12] = (float){0} * -0.5f;
		m[13] = (float){1} * 0.5f;
        m[5] = m[5] * -1f;
        ', width, height);

        _projectionMatrix = untyped __cs__('m');

    }

    inline function updateViewMatrix(density:Float, width:Float, height:Float, ?transform:ceramic.Transform, flipX:Float = 1, flipY:Float = 1):Void {

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

    inline function updateCurrentMatrix():Void {

        untyped __cs__('UnityEngine.Matrix4x4 matrix = ((UnityEngine.Matrix4x4){0}) * ((UnityEngine.Matrix4x4){1})', _projectionMatrix, _modelViewMatrix);
        
        _currentMatrix = untyped __cs__('matrix');

    }

    inline function transformToMatrix4x4(transform:Transform):Dynamic {

        untyped __cs__('UnityEngine.Matrix4x4 m = UnityEngine.Matrix4x4.identity');

        untyped __cs__('
        m[0] = (float){0}; m[4] = (float){1}; m[8] = 0f;  m[12] = (float){2};
        m[1] = (float){3}; m[5] = (float){4}; m[9] = 0f;  m[13] = (float){5};
        m[2] = 0f;  m[6] = 0f;  m[10] = 1f; m[14] = 0f;
        m[3] = 0f;  m[7] = 0f;  m[11] = 0f; m[15] = 1f;
        ', transform.a, transform.c, transform.tx, transform.b, transform.d, transform.ty);

        return untyped __cs__('m');

    }

    inline public function useShader(shader:backend.ShaderImpl):Void {

        _materialCurrentShader = _materialStencilWrite != 0 ? _stencilShader : shader;

        var attributesSize = ceramic.App.app.backend.shaders.customFloatAttributesSize(_materialCurrentShader);
        if (attributesSize % 2 == 1) attributesSize++;

        _vertexSize = 9 + attributesSize + (ceramic.App.app.backend.shaders.canBatchWithMultipleTextures(_materialCurrentShader) ? 1 : 0);

        _maxVerts = Std.int(Math.floor(MAX_VERTS_SIZE / _vertexSize));

        if (_posIndex == 0) {
            resetIndexes();
        }

    }

    inline public function clear():Void {

        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        untyped __cs__('cmd.ClearRenderTarget(true, true, new UnityEngine.Color(1f, 1f, 1f, 0f), 1f)');

    }

    inline public function enableBlending():Void {

        // Blending always enabled

    }

    inline public function disableBlending():Void {

        // Blending always enabled

    }

    inline public function setBlendFuncSeparate(srcRgb:backend.BlendMode, dstRgb:backend.BlendMode, srcAlpha:backend.BlendMode, dstAlpha:backend.BlendMode):Void {

        _materialSrcRgb = srcRgb;
        _materialDstRgb = dstRgb;
        _materialSrcAlpha = srcAlpha;
        _materialDstAlpha = dstAlpha;

    }

    inline public function getActiveTexture():Int {

        return _activeTextureSlot;

    }

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

        // TODO

        _materialCurrentTextures[_activeTextureSlot] = backendItem;

    }

    inline public function bindNoTexture():Void {
        
        _materialCurrentTextures[_activeTextureSlot] = null;

    }

    inline public function setRenderWireframe(value:Bool):Void {

        // TODO

    }

    inline public function beginDrawQuad(quad:ceramic.Quad):Void {

    }

    inline public function endDrawQuad():Void {

    }

    inline public function beginDrawMesh(mesh:ceramic.Mesh):Void {

    }

    inline public function endDrawMesh():Void {

    }

    public function beginDrawingInStencilBuffer():Void {

        if (hasAnythingToFlush())
            flush();

        if (_stencilBufferDirty) {
            // Clear before writing
            _materialStencilWrite = 2;
            useShader(null);
            var w = ceramic.App.app.backend.screen.getWidth();
            var h = ceramic.App.app.backend.screen.getHeight();
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

    inline public function endDrawingInStencilBuffer():Void {
        
        _materialStencilWrite = 0;

    }

    inline public function drawWithStencilTest():Void {

        _materialStencilTest = true;

    }

    inline public function drawWithoutStencilTest():Void {

        _materialStencilTest = false;

    }

    inline public function shouldFlush(numVerticesAfter:Int, numIndicesAfter:Int, customFloatAttributesSize:Int):Bool {
        
        return (_numPos + numVerticesAfter > _maxVerts || _numIndices + numIndicesAfter > MAX_INDICES);

    }

    inline public function remainingVertices():Int {
        
        return _maxVerts - _numPos;

    }

    inline public function remainingIndices():Int {
        
        return MAX_INDICES - _numIndices;

    }

    inline public function hasAnythingToFlush():Bool {

        return _numPos > 0;

    }

    inline public function flush():Void {

        var mesh = _currentMesh;

        var stencil:backend.StencilState = NONE;
        var shader:backend.Shader = _materialCurrentShader;

        if (_materialStencilWrite != 0) {
            stencil = _materialStencilWrite == 2 ? CLEAR : WRITE;
        }
        else if (_materialStencilTest) {
            stencil = TEST;
        }

        var materialData = _materials.get(
            _materialCurrentTextures,
            shader,
            _materialSrcRgb,
            _materialDstRgb,
            _materialSrcAlpha,
            _materialDstAlpha,
            stencil
        );

        //mesh.vertices = _meshVertices;
        //mesh.triangles = _meshIndices;
        //mesh.uv = _meshUVs;
        //mesh.colors = _meshColors;

        var updateFlags:MeshUpdateFlags = untyped __cs__('UnityEngine.Rendering.MeshUpdateFlags.DontValidateIndices | UnityEngine.Rendering.MeshUpdateFlags.DontResetBoneBounds | UnityEngine.Rendering.MeshUpdateFlags.DontNotifyMeshUsers | UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds');

        // Vertex buffer layout (positions, colors, uvs & custom float attributes)
        mesh.SetVertexBufferParams(_numPos, materialData.vertexBufferAttributes);

        // Vertex buffer data
        mesh.SetVertexBufferData(_meshVertices, 0, 0, _numPos * _vertexSize, 0, updateFlags); // TODO change flags to remove checks

        // Index buffer layout
        mesh.SetIndexBufferParams(_numIndices, IndexFormat.UInt16);

        // Index buffer data
        mesh.SetIndexBufferData(_meshIndices, 0, 0, _numIndices, updateFlags); // TODO change flags to remove checks

        // Configure sub mesh
        mesh.subMeshCount = 1;
        var submesh:SubMeshDescriptor = new SubMeshDescriptor(
            0, _numIndices, MeshTopology.Triangles
        );
        mesh.SetSubMesh(0, submesh, updateFlags);

        //trace('DRAW MESH vertices=${_numPos} indices=${_numIndices} uvs=${_numUVs} colors=${_numColors}');
        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        untyped __cs__('cmd.DrawMesh({0}, (UnityEngine.Matrix4x4){1}, (UnityEngine.Material){2})', mesh, _currentMatrix, materialData.material);

        resetIndexes();

        prepareNextMesh();

    }

/// Internal

    var renderer:ceramic.Renderer;

    var commandBuffer:Dynamic;

}
