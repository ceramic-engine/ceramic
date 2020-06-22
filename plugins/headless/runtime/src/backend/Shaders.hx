package backend;

import ceramic.Path;

using StringTools;

class Shaders implements spec.Shaders {

    public function new() {}

    inline public function fromSource(vertSource:String, fragSource:String, ?customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>):Shader {

        return new ShaderImpl(customAttributes);

    }

    inline public function destroy(shader:Shader):Void {

        //

    }

    inline public function clone(shader:Shader):Shader {

        return new ShaderImpl();

    }

/// Public API

    inline public function setInt(shader:Shader, name:String, value:Int):Void {
        
        //

    }

    inline public function setFloat(shader:Shader, name:String, value:Float):Void {
        
        //

    }

    inline public function setColor(shader:Shader, name:String, r:Float, g:Float, b:Float, a:Float):Void {
        
        //

    }

    inline public function setVec2(shader:Shader, name:String, x:Float, y:Float):Void {
        
        //

    }

    inline public function setVec3(shader:Shader, name:String, x:Float, y:Float, z:Float):Void {
        
        //

    }

    inline public function setVec4(shader:Shader, name:String, x:Float, y:Float, z:Float, w:Float):Void {
        
        //

    }

    inline public function setFloatArray(shader:Shader, name:String, array:Array<Float>):Void {
        
        //

    }

    inline public function setTexture(shader:Shader, name:String, texture:backend.Texture):Void {
        
        //

    }

    inline public function setMat4FromTransform(shader:Shader, name:String, transform:ceramic.Transform):Void {
        
        //

    }

    inline public function customFloatAttributesSize(shader:ShaderImpl):Int {

        var customFloatAttributesSize = 0;

        var allAttrs = shader.customAttributes;
        if (allAttrs != null) {
            for (ii in 0...allAttrs.length) {
                var attr = allAttrs.unsafeGet(ii);
                customFloatAttributesSize += attr.size;
            }
        }

        return customFloatAttributesSize;

    }

}
