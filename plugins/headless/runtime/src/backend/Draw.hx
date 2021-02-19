package backend;

using ceramic.Extensions;

@:allow(backend.Backend)
class Draw #if !completion implements spec.Draw #end {

/// Public API

    public function new() {}

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

        // Unused in headless

    }

    public function swap():Void {

        // Unused in headless

    }

/// Rendering

    inline public function initBuffers(maxVerts:Int):Void {

        // Unused in headless

    }

    inline public function beginRender():Void {

        // Unused in headless

    }

    inline public function setRenderTarget(renderTarget:ceramic.RenderTexture, force:Bool = false):Void {

        // Unused in headless

    }

    inline public function useShader(shader:backend.ShaderImpl):Void {

        // Unused in headless

    }

    inline public function clear():Void {

        // Unused in headless

    }

    inline public function enableBlending():Void {

        // Unused in headless

    }

    inline public function disableBlending():Void {

        // Unused in headless

    }

    inline public function setBlendFuncSeparate(srcRgb:backend.BlendMode, dstRgb:backend.BlendMode, srcAlpha:backend.BlendMode, dstAlpha:backend.BlendMode):Void {

        // Unused in headless

    }

    inline public function getActiveTexture():Int {

        return 0;

    }

    inline public function setActiveTexture(slot:Int):Void {

        // Unused in headless

    }

    inline public function textureBackendItemMatchesId(backendItem:backend.Texture, textureId:backend.TextureId):Bool {

        return false;

    }

    inline public function getTextureId(backendItem:backend.Texture):backend.TextureId {

        return 0;

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

    inline public function setRenderWireframe(value:Bool):Void {

        // Unused in headless

    }

    inline public function getPosList():ArrayBuffer {

        return null;

    }

    inline public function putInPosList(posList:ArrayBuffer, index:Int, value:Float):Void {

        // Unused in headless

    }

    inline public function getUvList():ArrayBuffer {

        return null;

    }

    inline public function putInUvList(uvList:ArrayBuffer, index:Int, value:Float):Void {

        // Unused in headless

    }

    inline public function getColorList():ArrayBuffer {

        return null;

    }

    inline public function putInColorList(colorList:ArrayBuffer, index:Int, value:Float):Void {

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

    inline public function maxPosFloats():Int {

        return 0;

    }

    inline public function flush(posFloats:Int, uvFloats:Int, colorFloats:Int):Void {

        // Unused in headless

    }

}
