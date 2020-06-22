package spec;

import backend.LoadShaderOptions;
import backend.Shader;
import backend.Texture;

interface Shaders {
    
    function destroy(shader:Shader):Void;
    
    function fromSource(vertSource:String, fragSource:String, ?customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>):Shader;
    
    function clone(shader:Shader):Shader;

/// Public API

    function setInt(shader:Shader, name:String, value:Int):Void;

    function setFloat(shader:Shader, name:String, value:Float):Void;

    function setColor(shader:Shader, name:String, r:Float, g:Float, b:Float, a:Float):Void;

    function setVec2(shader:Shader, name:String, x:Float, y:Float):Void;

    function setVec3(shader:Shader, name:String, x:Float, y:Float, z:Float):Void;

    function setVec4(shader:Shader, name:String, x:Float, y:Float, z:Float, w:Float):Void;

    function setFloatArray(shader:Shader, name:String, array:Array<Float>):Void;

    function setTexture(shader:Shader, name:String, texture:Texture):Void;

    function customFloatAttributesSize(shader:Shader):Int;

}
