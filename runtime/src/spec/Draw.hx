package spec;

import backend.VisualItem;

interface Draw {

    function draw(visuals:Array<ceramic.Visual>):Void;

    function swap():Void;

    function getItem(visual:ceramic.Visual):VisualItem;

    function initBuffers(maxVerts:Int):Void;

    function beginRender():Void;

    function setRenderTarget(renderTarget:ceramic.RenderTexture, force:Bool = false):Void;

    function useShader(shader:backend.Shader):Void;

    function clear():Void;

    function enableBlending():Void;

    function disableBlending():Void;
    
    function setBlendFuncSeparate(srcRgb:backend.BlendMode, dstRgb:backend.BlendMode, srcAlpha:backend.BlendMode, dstAlpha:backend.BlendMode):Void;

    function getActiveTexture():Int;

    function setActiveTexture(slot:Int):Void;

    function textureBackendItemMatchesId(backendItem:backend.Texture, textureId:backend.TextureId):Bool;

    function getTextureId(backendItem:backend.Texture):backend.TextureId;

    function bindTexture(backendItem:backend.Texture):Void;

    function bindNoTexture():Void;

    function setRenderWireframe(value:Bool):Void;

    function beginDrawQuad(quad:ceramic.Quad):Void;

    function endDrawQuad():Void;

    function beginDrawMesh(mesh:ceramic.Mesh):Void;

    function endDrawMesh():Void;

    function beginDrawingInStencilBuffer():Void;

    function endDrawingInStencilBuffer():Void;

    function drawWithStencilTest():Void;

    function drawWithoutStencilTest():Void;

#if ceramic_render_pos_indice

    // TODO?

#else
    function maxPosFloats():Int;

    function flush(posFloats:Int, uvFloats:Int, colorFloats:Int):Void;

    function getPosList():backend.ArrayBuffer;

    function putInPosList(posList:backend.ArrayBuffer, index:Int, value:Float):Void;

    function getUvList():backend.ArrayBuffer;

    function putInUvList(uvList:backend.ArrayBuffer, index:Int, value:Float):Void;

    function getColorList():backend.ArrayBuffer;

    function putInColorList(colorList:backend.ArrayBuffer, index:Int, value:Float):Void;
#end

}
