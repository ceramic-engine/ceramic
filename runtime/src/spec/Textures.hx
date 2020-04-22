package spec;

import backend.UInt8Array;
import backend.Texture;
import backend.LoadTextureOptions;

interface Textures {

    function load(path:String, ?options:LoadTextureOptions, done:Texture->Void):Void;

/// Textures

    /**
     * Returns `true` if paths with `?hot=...` are supported on this backend
     * @return Bool
     */
    function supportsHotReloadPath():Bool;

    function createTexture(width:Int, height:Int, pixels:ceramic.UInt8Array):Texture;
    
    function destroyTexture(texture:Texture):Void;

    function getTextureWidth(texture:Texture):Int;

    function getTextureHeight(texture:Texture):Int;

    function fetchTexturePixels(texture:Texture, ?result:ceramic.UInt8Array):ceramic.UInt8Array;

    function submitTexturePixels(texture:Texture, pixels:ceramic.UInt8Array):Void;

    function setTextureFilter(texture:Texture, filter:ceramic.TextureFilter):Void;

    function createRenderTarget(width:Int, height:Int):Texture;

}
