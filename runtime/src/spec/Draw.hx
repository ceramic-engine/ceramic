package spec;

import backend.VisualItem;

interface Draw {

    function draw(visuals:Array<ceramic.Visual>):Void;

    function swap():Void;

    function initBuffers():Void;

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

    function enableScissor(x:Float, y:Float, width:Float, height:Float):Void;

    function disableScissor():Void;

    function getNumPos():Int;

    function putPos(x:Float, y:Float, z:Float):Void;

    function putPosAndTextureSlot(x:Float, y:Float, z:Float, textureSlot:Float):Void;

    function putIndice(i:Int):Void;

    function putUVs(uvX:Float, uvY:Float):Void;

    function putColor(r:Float, g:Float, b:Float, a:Float):Void;

    function beginFloatAttributes():Void;

    function putFloatAttribute(index:Int, value:Float):Void;

    function endFloatAttributes():Void;

    function clearAndApplyBackground():Void;

    function getTextureWidth(texture:backend.Texture):Int;

    function getTextureHeight(texture:backend.Texture):Int;

    function getTextureWidthActual(texture:backend.Texture):Int;

    function getTextureHeightActual(texture:backend.Texture):Int;

    function shouldFlush(numVerticesAfter:Int, numIndicesAfter:Int, customFloatAttributesSize:Int):Bool;

    function remainingVertices():Int;

    function remainingIndices():Int;

    function hasAnythingToFlush():Bool;

    function flush():Void;

}
