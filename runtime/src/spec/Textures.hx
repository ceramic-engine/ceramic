package spec;

import backend.UInt8Array;
import backend.Texture;
import backend.LoadTextureOptions;

interface Textures {

    function load(path:String, ?options:LoadTextureOptions, done:Texture->Void):Void;

/// Textures

    function createTexture(width:Int, height:Int, pixels:ceramic.UInt8Array):Texture;
    
    function destroyTexture(texture:Texture):Void;

    function getTextureWidth(texture:Texture):Int;

    function getTextureHeight(texture:Texture):Int;

    function getTexturePixels(texture:Texture):UInt8Array;

    function setTextureFilter(texture:Texture, filter:ceramic.TextureFilter):Void;

    function createRenderTarget(width:Int, height:Int):Texture;

} //Textures
