package spec;

import backend.Textures;

interface Textures {

    function load(path:String, ?options:LoadTextureOptions, done:Texture->Void):Void;

    function createRenderTexture(width:Int, height:Int):Texture;
    
    function destroy(texture:Texture):Void;

    function getWidth(texture:Texture):Int;

    function getHeight(texture:Texture):Int;

} //Textures
