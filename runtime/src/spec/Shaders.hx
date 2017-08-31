package spec;

import backend.Shaders;

interface Shaders {

    function load(path:String, options:LoadShaderOptions, done:Shader->Void):Void;
    
    function destroy(shader:Shader):Void;

/// Public API

    function setInt(shader:Shader, name:String, value:Int):Void;

    function setFloat(shader:Shader, name:String, value:Float):Void;

    function setColor(shader:Shader, name:String, r:Float, g:Float, b:Float, a:Float):Void;

    function setVec2(shader:Shader, name:String, x:Float, y:Float):Void;

    function setVec3(shader:Shader, name:String, x:Float, y:Float, z:Float):Void;

    function setVec4(shader:Shader, name:String, x:Float, y:Float, z:Float, w:Float):Void;

    function setTexture(shader:Shader, name:String, texture:backend.Textures.Texture):Void;

} //Shaders
