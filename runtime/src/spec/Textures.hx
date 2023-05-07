package spec;

import backend.LoadTextureOptions;
import backend.Texture;
import ceramic.ImageType;
import haxe.io.Bytes;

interface Textures {

    function load(path:String, ?options:LoadTextureOptions, done:Texture->Void):Void;

    function loadFromBytes(bytes:Bytes, type:ImageType, ?options:LoadTextureOptions, done:Texture->Void):Void;

/// Textures

    /**
     * Returns `true` if paths with `?hot=...` are supported on this backend
     * @return Bool
     */
    function supportsHotReloadPath():Bool;

    function createTexture(width:Int, height:Int, pixels:ceramic.UInt8Array):Texture;

    function destroyTexture(texture:Texture):Void;

    function getTextureId(texture:Texture):backend.TextureId;

    function getTextureWidth(texture:Texture):Int;

    function getTextureHeight(texture:Texture):Int;

    function getTextureWidthActual(texture:Texture):Int;

    function getTextureHeightActual(texture:Texture):Int;

    function fetchTexturePixels(texture:Texture, ?result:ceramic.UInt8Array):ceramic.UInt8Array;

    function submitTexturePixels(texture:Texture, pixels:ceramic.UInt8Array):Void;

    function setTextureFilter(texture:Texture, filter:ceramic.TextureFilter):Void;

    function setTextureWrapS(texture: Texture, wrap: ceramic.TextureWrap):Void;

    function setTextureWrapT(texture: Texture, wrap: ceramic.TextureWrap):Void;

    function createRenderTarget(width:Int, height:Int, depth:Bool, stencil:Bool, antialiasing:Int):Texture;

    /**
     * If this returns a value above 1, that means this backend supports multi-texture batching.
     */
    function maxTexturesByBatch():Int;

    function getTextureIndex(texture:Texture):Int;

    function textureToPng(texture:Texture, reversePremultiplyAlpha:Bool = true, ?path:String, done:(?data:Bytes)->Void):Void;

    function pixelsToPng(width:Int, height:Int, pixels:ceramic.UInt8Array, ?path:String, done:(?data:Bytes)->Void):Void;

}
