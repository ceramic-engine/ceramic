package backend;

import unityengine.Vector2Int;
import unityengine.Mesh;
import unityengine.Color;
import unityengine.Vector2;
import unityengine.Vector3;
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

    static var _maxVerts:Int = 0;
    static var _maxIndices:Int = 0;

    static var _meshes:Array<Mesh> = null;
    static var _currentMeshIndex:Int = -1;
    static var _currentMesh:Mesh = null;

    static var _meshVertices:NativeArray<Vector3> = null;
    static var _meshIndices:NativeArray<Int> = null;
    static var _meshUVs:NativeArray<Vector2> = null;
    static var _meshColors:NativeArray<Color> = null;

    static var _materials:Materials = new Materials();

    static var _materialCurrentTexture:backend.Texture = null;
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

    static var _numPos:Int = 0;
    static var _numIndices:Int = 0;
    static var _numUVs:Int = 0;
    static var _numColors:Int = 0;

    static var _numFloatAttributes:Int = 0;

    inline public function getNumPos():Int {

        return _numPos;

    }

    inline public function putPos(x:Float, y:Float, z:Float):Void {

        _numFloatAttributes = 0;
        _meshVertices[_numPos] = new Vector3(x, y, z);
        _numPos++;

    }

    inline public function putIndice(i:Int):Void {

        _meshIndices[_numIndices] = i;
        _numIndices++;

    }

    inline public function putUVs(uvX:Float, uvY:Float):Void {

        _meshUVs[_numUVs] = new Vector2(uvX, 1.0 - uvY);
        _numUVs++;

    }

    inline public function putColor(r:Float, g:Float, b:Float, a:Float):Void {

        _meshColors[_numColors] = new Color(r, g, b, a);
        _numColors++;

    }

    inline public function putFloatAttribute(value:Float):Void {

        _numFloatAttributes++;

        // TODO

    }

    inline public function initBuffers(maxVerts:Int):Void {

        _maxVerts = maxVerts;
        _maxIndices = Std.int(Math.floor(maxVerts / 3) * 3);

        if (_meshes == null) {
            _meshes = [];
        }

        _currentMeshIndex = -1;
        _currentMesh = null;

        prepareNextMesh();

    }

    function prepareNextMesh() {

        _currentMeshIndex++;
        var mesh = _meshes[_currentMeshIndex];
        if (mesh == null) {
            mesh = new Mesh();
            _meshes[_currentMeshIndex] = mesh;
            mesh.vertices = new NativeArray<Vector3>(_maxVerts);
            mesh.triangles = new NativeArray<Int>(_maxIndices);
            mesh.uv = new NativeArray<Vector2>(_maxVerts);
            mesh.colors = new NativeArray<Color>(_maxVerts);
        }

        _meshVertices = mesh.vertices;
        _meshIndices = mesh.triangles;
        _meshUVs = mesh.uv;
        _meshColors = mesh.colors;

        _currentMesh = mesh;

    }

    inline public function beginRender():Void {

        // Reset command buffer
        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        untyped __cs__('cmd.Clear()');

        _numPos = 0;
        _numIndices = 0;
        _numUVs = 0;
        _numColors = 0;

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
                    untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
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

    inline function updateViewMatrix(density:Float, width:Float, height:Float, ?transform:ceramic.Transform, flipY:Float = 1):Void {

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

        _materialCurrentShader = shader;

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

        // TODO
        return 0;
        /*
        return activeTextureSlot;
        */

    }

    inline public function setActiveTexture(slot:Int):Void {

        /*
        activeTextureSlot = slot;
        luxeRenderer.state.activeTexture(GL.TEXTURE0 + slot);
        */

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

        _materialCurrentTexture = backendItem;
        //_currentMaterial.mainTexture = backendItem.unityTexture;
        //untyped __cs__('((UnityEngine.Material){0}).mainTexture = {1}', _currentMaterial, backendItem.unityTexture);

    }

    inline public function bindNoTexture():Void {

        // TODO
        
        _materialCurrentTexture = null;
		//_currentMaterial.mainTexture = null;
        //untyped __cs__('((UnityEngine.Material){0}).mainTexture = null', _currentMaterial);

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

        // Clear before writing
        _materialStencilWrite = 2; 
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

        // Start writing
        _materialStencilWrite = 1;

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

    inline public function maxPosFloats():Int {

        // TODO

        return 0;//maxFloats;

    }

    inline public function shouldFlush(numVerticesAfter:Int, numIndicesAfter:Int, customFloatAttributesSize:Int):Bool {
        
        return (_numPos + numVerticesAfter > _maxVerts || _numIndices + numIndicesAfter > _maxIndices);

    }

    inline public function remainingVertices():Int {
        
        return _maxVerts - _numPos;

    }

    inline public function remainingIndices():Int {
        
        return _maxIndices - _numIndices;

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
            if (_stencilShader == null) {
                _stencilShader = ceramic.App.app.assets.shader('shader:stencil').backendItem;
            }
            shader = _stencilShader;
        }
        else if (_materialStencilTest) {
            stencil = TEST;
        }

        var material = _materials.get(
            _materialCurrentTexture,
            shader,
            _materialSrcRgb,
            _materialDstRgb,
            _materialSrcAlpha,
            _materialDstAlpha,
            stencil
        ).material;

        mesh.vertices = _meshVertices;
        mesh.triangles = _meshIndices;
        mesh.uv = _meshUVs;
        mesh.colors = _meshColors;
        
        //trace('DRAW MESH vertices=${_numPos} indices=${_numIndices} uvs=${_numUVs} colors=${_numColors}');
        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        untyped __cs__('cmd.DrawMesh({0}, (UnityEngine.Matrix4x4){1}, (UnityEngine.Material){2})', mesh, _currentMatrix, material);

        _numPos = 0;
        _numIndices = 0;
        _numUVs = 0;
        _numColors = 0;

        prepareNextMesh();

    }

/// Internal

    var renderer:ceramic.Renderer;

    var commandBuffer:Dynamic;

}
