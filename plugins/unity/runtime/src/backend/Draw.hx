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

        //renderer = new ceramic.Renderer();

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

        //renderer.render(true, visuals);

    }

    public function swap():Void {

        // Unused in unity

    }

/// Rendering

    static var _maxVerts:Int = 0;

    static var _meshes:Array<Mesh> = null;
    static var _currentMeshIndex:Int = -1;
    static var _currentMesh:Mesh = null;

    static var _meshVertices:NativeArray<Vector3> = null;
    static var _meshIndices:NativeArray<Int> = null;
    static var _meshUVs:NativeArray<Vector2> = null;
    static var _meshColors:NativeArray<Color> = null;

    static var _numPos:Int = 0;
    static var _numIndices:Int = 0;
    static var _numUVs:Int = 0;
    static var _numColors:Int = 0;

    static var _numFloatAttributes:Int = 0;

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

        _meshUVs[_numUVs] = new Vector2(uvX, uvY);
        _numUVs++;

    }

    inline public function putColor(r:Float, g:Float, b:Float, a:Float):Void {

        _meshColors[_numUVs] = new Color(r, g, b, a);
        _numUVs++;

    }

    inline public function initBuffers(maxVerts:Int):Void {

        _maxVerts = maxVerts;

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
            mesh.triangles = new NativeArray<Int>(_maxVerts);
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

        _numPos = 0;
        _numIndices = 0;
        _numUVs = 0;
        _numColors = 0;

        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        untyped __cs__('cmd.Clear()');

        untyped __cs__('cmd.SetRenderTarget(UnityEngine.Rendering.BuiltinRenderTextureType.CameraTarget)');

        // TODO color
        untyped __cs__('cmd.ClearRenderTarget(true, true, new UnityEngine.Color(0.5f, 0.9f, 0.5f, 1f), 1f)');

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

    inline public function setRenderTarget(renderTarget:ceramic.RenderTexture, force:Bool = false):Void {

        // TODO

    }

    inline public function useShader(shader:backend.ShaderImpl):Void {

        // TODO

    }

    inline public function clear():Void {

        // TODO

    }

    inline public function enableBlending():Void {

        // TODO

    }

    inline public function disableBlending():Void {

        // TODO

    }

    inline public function setBlendFuncSeparate(srcRgb:backend.BlendMode, dstRgb:backend.BlendMode, srcAlpha:backend.BlendMode, dstAlpha:backend.BlendMode):Void {

        // TODO

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

    }

    inline public function bindNoTexture():Void {

        // TODO

    }

    inline public function setRenderWireframe(value:Bool):Void {

        // TODO

    }

    inline public function getPosList():ArrayBuffer {

        return null;

    }

    inline public function putInPosList(posList:ArrayBuffer, index:Int, value:Float):Void {

        //posList[index] = value;

    }

    inline public function getUvList():ArrayBuffer {

        return null;

    }

    inline public function putInUvList(uvList:ArrayBuffer, index:Int, value:Float):Void {

        //uvList[index] = value;

    }

    inline public function getColorList():ArrayBuffer {

        return null;

    }

    inline public function putInColorList(colorList:ArrayBuffer, index:Int, value:Float):Void {

        //

    }

    inline public function beginDrawQuad(quad:ceramic.Quad):Void {

    }

    inline public function endDrawQuad():Void {

    }

    inline public function beginDrawMesh(mesh:ceramic.Mesh):Void {

    }

    inline public function endDrawMesh():Void {

    }

    inline public function beginDrawingInStencilBuffer():Void {
        
        // TODO

    }

    inline public function endDrawingInStencilBuffer():Void {
        
        // TODO

    }

    inline public function drawWithStencilTest():Void {

        // TODO

    }

    inline public function drawWithoutStencilTest():Void {

        // TODO

    }

    inline public function maxPosFloats():Int {

        // TODO

        return 0;//maxFloats;

    }

    inline public function flush(posFloats:Int, uvFloats:Int, colorFloats:Int):Void {

        // TODO

    }

/// Internal

    //var renderer:ceramic.Renderer;

    var commandBuffer:Dynamic;

}
