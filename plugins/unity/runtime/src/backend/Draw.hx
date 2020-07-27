package backend;

import ceramic.RotateFrame;

using ceramic.Extensions;

@:allow(backend.Backend)
class Draw #if !completion implements spec.Draw #end {

/// Public API

    public function new() {

        renderer = new ceramic.Renderer();

        commandBuffer = untyped __cs__('new UnityEngine.Rendering.CommandBuffer()');
        untyped __cs__('UnityEngine.Camera.main.AddCommandBuffer(UnityEngine.Rendering.CameraEvent.BeforeDepthTexture, (UnityEngine.Rendering.CommandBuffer){0})', commandBuffer);

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

    var maxFloats:Int;

    inline public function initBuffers(maxVerts:Int):Void {

        maxFloats = maxVerts * 4;

        // TODO
        /*
        if (posList == null) {

            maxFloats = maxVerts * 4;

            posList = new Float32Array(maxFloats);
            uvList = new Float32Array(maxFloats);
            colorList = new Float32Array(maxFloats);

        }
        */

    }

    inline public function beginRender():Void {

        untyped __cs__('UnityEngine.Rendering.CommandBuffer cmd = (UnityEngine.Rendering.CommandBuffer){0}', commandBuffer);
        untyped __cs__('cmd.Clear()');

        untyped __cs__('cmd.SetRenderTarget(UnityEngine.Rendering.BuiltinRenderTextureType.CameraTarget)');

        untyped __cs__('UnityEngine.Vector3[] meshVertices = new UnityEngine.Vector3[3]');
        untyped __cs__('UnityEngine.Vector2[] meshUV = new UnityEngine.Vector2[3]');
        untyped __cs__('int[] meshTriangles = new int[3]');

        untyped __cs__('meshVertices[0] = new UnityEngine.Vector3(5, 5, 0);');
        untyped __cs__('meshVertices[1] = new UnityEngine.Vector3(10, 4, 0);');
        untyped __cs__('meshVertices[2] = new UnityEngine.Vector3(7, 9, 0);');

        untyped __cs__('meshUV[0] = new UnityEngine.Vector2(0, 0);');
        untyped __cs__('meshUV[1] = new UnityEngine.Vector2(0, 0);');
        untyped __cs__('meshUV[2] = new UnityEngine.Vector2(0, 0);');

        untyped __cs__('meshTriangles[0] = 0;');
        untyped __cs__('meshTriangles[1] = 1;');
        untyped __cs__('meshTriangles[2] = 2;');

        untyped __cs__('UnityEngine.Mesh mesh = new UnityEngine.Mesh()');
        untyped __cs__('mesh.vertices = meshVertices');
        untyped __cs__('mesh.uv = meshUV');
        untyped __cs__('mesh.triangles = meshTriangles');

        /*
        untyped __cs__('
        UnityEngine.List<UnityEngine.Color32> colors = new UnityEngine.List<UnityEngine.Color32>();
        for (int i = 0; i < 3; i++)
        {
            colors.Add(new UnityEngine.Color32(128, 128, 128, 128));
        }
        ');
        untyped __cs__('mesh.SetColors(colors)');
        */

        untyped __cs__('UnityEngine.Material material = new UnityEngine.Material(UnityEngine.Shader.Find("Unlit/Color"));');

        untyped __cs__('cmd.DrawMesh(
            mesh,
            ((UnityEngine.MonoBehaviour){0}).transform.localToWorldMatrix,
            material,
            0,
            -1
        );', Main.unityObject);

        untyped __cs__('UnityEngine.Graphics.ExecuteCommandBuffer(cmd)');

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

    inline public function getPosList():Float32Array {

        return null;

    }

    inline public function putInPosList(posList:Float32Array, index:Int, value:Float):Void {

        //posList[index] = value;

    }

    inline public function getUvList():Float32Array {

        return null;

    }

    inline public function putInUvList(uvList:Float32Array, index:Int, value:Float):Void {

        //uvList[index] = value;

    }

    inline public function getColorList():Float32Array {

        return null;

    }

    inline public function putInColorList(colorList:Float32Array, index:Int, value:Float):Void {

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

        return maxFloats;

    }

    inline public function flush(posFloats:Int, uvFloats:Int, colorFloats:Int):Void {

        // TODO

    }

/// Internal

    var renderer:ceramic.Renderer;

    var commandBuffer:Dynamic;

}
