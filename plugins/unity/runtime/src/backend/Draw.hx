package backend;

import unityengine.Vector2Int;
import unityengine.Mesh;
import unityengine.Color;
import unityengine.Vector2;
import cs.StdTypes.Int16;
import ceramic.RotateFrame;
import cs.NativeArray;
import unityengine.Vector3;

using ceramic.Extensions;

@:allow(backend.Backend)
class Draw #if !completion implements spec.Draw #end {

/// Public API

    public function new() {

        renderer = new ceramic.Renderer();

        commandBuffer = untyped __cs__('new UnityEngine.Rendering.CommandBuffer()');
        untyped __cs__('UnityEngine.Camera.main.AddCommandBuffer(UnityEngine.Rendering.CameraEvent.AfterEverything, (UnityEngine.Rendering.CommandBuffer){0})', commandBuffer);

    }

    /*inline*/ public function getItem(visual:ceramic.Visual):VisualItem {

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

    static var _currentMaterial:Dynamic = null;
    static var _currentMatrix:Dynamic = null;

    static var _numPos:Int = 0;
    static var _numIndices:Int = 0;
    static var _numUVs:Int = 0;
    static var _numColors:Int = 0;

    static var _numFloatAttributes:Int = 0;

    /*inline*/ public function getNumPos():Int {

        return _numPos;

    }

    /*inline*/ public function putPos(x:Float, y:Float, z:Float):Void {

        _numFloatAttributes = 0;
        _meshVertices[_numPos] = new Vector3(x, y, z);
        _numPos++;

    }

    /*inline*/ public function putIndice(i:Int):Void {

        _meshIndices[_numIndices] = i;
        _numIndices++;

    }

    /*inline*/ public function putUVs(uvX:Float, uvY:Float):Void {

        _meshUVs[_numUVs] = new Vector2(uvX, uvY);
        _numUVs++;

    }

    /*inline*/ public function putColor(r:Float, g:Float, b:Float, a:Float):Void {

        _meshColors[_numColors] = new Color(r, g, b, a);
        _numColors++;

    }

    /*inline*/ public function putFloatAttribute(value:Float):Void {

        _numFloatAttributes++;

        // TODO

    }

    /*inline*/ public function initBuffers(maxVerts:Int):Void {

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

    /*inline*/ public function beginRender():Void {

        _numPos = 0;
        _numIndices = 0;
        _numUVs = 0;
        _numColors = 0;

        //_currentMaterial = new Material(unityengine.Shader.Find("Sprites/Default"));
        _currentMaterial = untyped __cs__('new UnityEngine.Material(UnityEngine.Shader.Find("Sprites/Default"))');

		untyped __cs__('UnityEngine.Camera.main.orthographicSize = UnityEngine.Camera.main.pixelHeight * 0.5f');

		untyped __cs__('var cameraHeight = 2*UnityEngine.Camera.main.orthographicSize');
        untyped __cs__('var cameraWidth = cameraHeight*UnityEngine.Camera.main.aspect');

        // TODO no alloc
		untyped __cs__('UnityEngine.Matrix4x4 matrix = UnityEngine.Matrix4x4.identity');

		// Translate to top left and change from y down to y top
		untyped __cs__('matrix[12] = cameraWidth * -0.5f');
		untyped __cs__('matrix[13] = cameraHeight * 0.5f');
        untyped __cs__('matrix[5] = matrix[5] * -1f');
        
        _currentMatrix = untyped __cs__('matrix');
          
        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        untyped __cs__('cmd.Clear()');

        untyped __cs__('cmd.SetRenderTarget(UnityEngine.Rendering.BuiltinRenderTextureType.CameraTarget)');

        var bg = ceramic.App.app.settings.background;
        untyped __cs__('cmd.ClearRenderTarget(true, true, new UnityEngine.Color((float){0}, (float){1}, (float){2}, 1f), 1f)', bg.redFloat, bg.greenFloat, bg.blueFloat);
        
        // untyped __cs__('UnityEngine.Vector3[] meshVertices = new UnityEngine.Vector3[3]');
        // untyped __cs__('UnityEngine.Vector2[] meshUV = new UnityEngine.Vector2[3]');
        // untyped __cs__('int[] meshTriangles = new int[3]');

        // untyped __cs__('meshVertices[0] = new UnityEngine.Vector3(5, 5, 0);');
        // untyped __cs__('meshVertices[1] = new UnityEngine.Vector3(10, 4, 0);');
        // untyped __cs__('meshVertices[2] = new UnityEngine.Vector3(7, 9, 0);');

        // untyped __cs__('meshUV[0] = new UnityEngine.Vector2(0, 0);');
        // untyped __cs__('meshUV[1] = new UnityEngine.Vector2(0, 0);');
        // untyped __cs__('meshUV[2] = new UnityEngine.Vector2(0, 0);');

        // untyped __cs__('meshTriangles[0] = 0;');
        // untyped __cs__('meshTriangles[1] = 1;');
        // untyped __cs__('meshTriangles[2] = 2;');

        // untyped __cs__('UnityEngine.Mesh mesh = new UnityEngine.Mesh()');
        // untyped __cs__('mesh.vertices = meshVertices');
        // untyped __cs__('mesh.uv = meshUV');
        // untyped __cs__('mesh.triangles = meshTriangles');

        // /*
        // untyped __cs__('
        // UnityEngine.List<UnityEngine.Color32> colors = new UnityEngine.List<UnityEngine.Color32>();
        // for (int i = 0; i < 3; i++)
        // {
        //     colors.Add(new UnityEngine.Color32(128, 128, 128, 128));
        // }
        // ');
        // untyped __cs__('mesh.SetColors(colors)');
        // */

        // untyped __cs__('UnityEngine.Material material = new UnityEngine.Material(UnityEngine.Shader.Find("Unlit/Color"));');

        // untyped __cs__('cmd.DrawMesh(
        //     mesh,
        //     ((UnityEngine.MonoBehaviour){0}).transform.localToWorldMatrix,
        //     material,
        //     0,
        //     -1
        // );', Main.unityObject);

        // untyped __cs__('UnityEngine.Graphics.ExecuteCommandBuffer(cmd)');

        /*
        untyped __cs__('mesh.UV[0] = 0;');
        untyped __cs__('mesh.UV[1] = 0;');
        untyped __cs__('mesh.UV[2] = 0;');
        untyped __cs__('mesh.UV[3] = 0;');
        untyped __cs__('mesh.UV[4] = 0;');
        untyped __cs__('mesh.UV[5] = 0;');

        untyped __cs__('mesh.UV[0] = 0;');
        untyped __cs__('mesh.UV[1] = 0;');
        untyped __cs__('mesh.UV[2] = 0;');
        untyped __cs__('mesh.UV[3] = 0;');
        untyped __cs__('mesh.UV[4] = 0;');
        untyped __cs__('mesh.UV[5] = 0;');
        */

        // TODO
        /*
        defaultTransformScaleX = view.transform.scale.x;
        defaultTransformScaleY = view.transform.scale.y;
        defaultViewport = view.viewport;
        */

    }

    /*inline*/ public function setRenderTarget(renderTarget:ceramic.RenderTexture, force:Bool = false):Void {

        // TODO

        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        
        untyped __cs__('cmd.SetRenderTarget(UnityEngine.Rendering.BuiltinRenderTextureType.CameraTarget)');

    }

    /*inline*/ public function useShader(shader:backend.ShaderImpl):Void {

        // TODO

    }

    /*inline*/ public function clear():Void {

        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        untyped __cs__('cmd.ClearRenderTarget(true, true, new UnityEngine.Color(1f, 1f, 1f, 0f), 1f)');

    }

    /*inline*/ public function enableBlending():Void {

        // TODO

    }

    /*inline*/ public function disableBlending():Void {

        // TODO

    }

    /*inline*/ public function setBlendFuncSeparate(srcRgb:backend.BlendMode, dstRgb:backend.BlendMode, srcAlpha:backend.BlendMode, dstAlpha:backend.BlendMode):Void {

        // TODO

    }

    /*inline*/ public function getActiveTexture():Int {

        // TODO
        return 0;
        /*
        return activeTextureSlot;
        */

    }

    /*inline*/ public function setActiveTexture(slot:Int):Void {

        /*
        activeTextureSlot = slot;
        luxeRenderer.state.activeTexture(GL.TEXTURE0 + slot);
        */

    }

    /*inline*/ public function textureBackendItemMatchesId(backendItem:backend.Texture, textureId:backend.TextureId):Bool {

        return (backendItem:TextureImpl).textureId == textureId;

    }

    /*inline*/ public function getTextureId(backendItem:backend.Texture):backend.TextureId {

        return (backendItem:TextureImpl).textureId;

    }

    /*inline*/ public function getTextureWidth(texture:backend.Texture):Int {

        return (texture:TextureImpl).width;

    }

    /*inline*/ public function getTextureHeight(texture:backend.Texture):Int {

        return (texture:TextureImpl).height;

    }

    /*inline*/ public function getTextureWidthActual(texture:backend.Texture):Int {

        return (texture:TextureImpl).width;

    }

    /*inline*/ public function getTextureHeightActual(texture:backend.Texture):Int {

        return (texture:TextureImpl).height;

    }

    /*inline*/ public function bindTexture(backendItem:backend.Texture):Void {

        // TODO

        //_currentMaterial.mainTexture = backendItem.unityTexture;
        trace('BIND TEXTURE $backendItem');
        untyped __cs__('((UnityEngine.Material){0}).mainTexture = {1}', _currentMaterial, backendItem.unityTexture);

    }

    /*inline*/ public function bindNoTexture():Void {

        // TODO
        trace('BIND NO TEXTURE');

		//_currentMaterial.mainTexture = null;
        //untyped __cs__('((UnityEngine.Material){0}).mainTexture = null', _currentMaterial);

    }

    /*inline*/ public function setRenderWireframe(value:Bool):Void {

        // TODO

    }

    /*inline*/ public function beginDrawQuad(quad:ceramic.Quad):Void {

    }

    /*inline*/ public function endDrawQuad():Void {

    }

    /*inline*/ public function beginDrawMesh(mesh:ceramic.Mesh):Void {

    }

    /*inline*/ public function endDrawMesh():Void {

    }

    /*inline*/ public function beginDrawingInStencilBuffer():Void {
        
        // TODO

    }

    /*inline*/ public function endDrawingInStencilBuffer():Void {
        
        // TODO

    }

    /*inline*/ public function drawWithStencilTest():Void {

        // TODO

    }

    /*inline*/ public function drawWithoutStencilTest():Void {

        // TODO

    }

    /*inline*/ public function maxPosFloats():Int {

        // TODO

        return 0;//maxFloats;

    }

    /*inline*/ public function shouldFlush(numVerticesAfter:Int, numIndicesAfter:Int, customFloatAttributesSize:Int):Bool {
        
        return (_numPos + numVerticesAfter > _maxVerts || _numIndices + numIndicesAfter > _maxIndices);

    }

    inline public function hasAnythingToFlush():Bool {

        return _numPos > 0;

    }

    /*inline*/ public function flush():Void {

        var mesh = _currentMesh;

        mesh.vertices = _meshVertices;
        mesh.triangles = _meshIndices;
        mesh.uv = _meshUVs;
        mesh.colors = _meshColors;
        
        trace('DRAW MESH vertices=${_numPos} indices=${_numIndices} uvs=${_numUVs} colors=${_numColors}');
        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        untyped __cs__('cmd.DrawMesh({0}, (UnityEngine.Matrix4x4){1}, (UnityEngine.Material){2})', mesh, _currentMatrix, _currentMaterial);

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
