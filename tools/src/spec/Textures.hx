package spec;

import backend.Textures;

interface Textures {

    function load(name:String, ?options:LoadTextureOptions, done:Texture->Void):Void;  
    
    function destroy(texture:Texture):Void;

    function getWidth(texture:Texture):Int;

    function getHeight(texture:Texture):Int;

} //Textures
