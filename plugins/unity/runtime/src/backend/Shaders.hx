package backend;

import ceramic.Path;

using StringTools;

class Shaders implements spec.Shaders {

    public function new() {}

    public function load(path:String, ?customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>, _done:(shader:backend.Shader)->Void):Void {

        var done = function(shader:Shader) {
            ceramic.App.app.onceImmediate(function() {
                _done(shader);
                _done = null;
            });
        };

        var unityPath = Path.withoutExtension(path);
        var unityPathMultiTexture = unityPath + '_mt8';
        var unityShader:Dynamic = null;
        #if !ceramic_no_multitexture
        try {
            unityShader = untyped __cs__('UnityEngine.Shader.Find({0})', unityPathMultiTexture);
        }
        catch (e:Dynamic) {
            // No valid multi texture shader
            trace('Failed to load multi texture shader: $unityPathMultiTexture');
        }
        #end
        var isBatchingMultiTexture = (unityShader != null);
        if (!isBatchingMultiTexture) {
            unityShader = untyped __cs__('UnityEngine.Shader.Find({0})', unityPath);
        }

        if (unityShader != null) {
            var shader = new ShaderImpl(unityShader, customAttributes);
            shader.isBatchingMultiTexture = isBatchingMultiTexture;
            shader.path = path;
            done(shader);
        }
        else {
            done(null);
        }

    }

    inline public function destroy(shader:Shader):Void {

        // Shaders don't need to be unloaded

    }

    inline public function clone(shader:Shader):Shader {

        return ShaderImpl.clone(shader);

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

/// Public API

    inline public function setInt(shader:Shader, name:String, value:Int):Void {
        
        (shader:ShaderImpl).setInt(name, value);

    }

    inline public function setFloat(shader:Shader, name:String, value:Float):Void {
        
        (shader:ShaderImpl).setFloat(name, value);

    }

    inline public function setColor(shader:Shader, name:String, r:Float, g:Float, b:Float, a:Float):Void {
        
        (shader:ShaderImpl).setColor(name, r, g, b, a);

    }

    inline public function setVec2(shader:Shader, name:String, x:Float, y:Float):Void {
        
        (shader:ShaderImpl).setVec2(name, x, y);

    }

    inline public function setVec3(shader:Shader, name:String, x:Float, y:Float, z:Float):Void {
        
        (shader:ShaderImpl).setVec3(name, x, y, z);

    }

    inline public function setVec4(shader:Shader, name:String, x:Float, y:Float, z:Float, w:Float):Void {
        
        (shader:ShaderImpl).setVec4(name, x, y, z, w);

    }

    inline public function setFloatArray(shader:Shader, name:String, array:Array<Float>):Void {
        
        (shader:ShaderImpl).setFloatArray(name, array);

    }

    inline public function setTexture(shader:Shader, name:String, texture:backend.Texture):Void {
        
        (shader:ShaderImpl).setTexture(name, texture);

    }

    inline public function setMat4FromTransform(shader:Shader, name:String, transform:ceramic.Transform):Void {
        
        (shader:ShaderImpl).setMat4FromTransform(name, transform);

    }

    inline public function maxIfStatementsByFragmentShader():Int {

        return 8;

    }

    inline public function canBatchWithMultipleTextures(shader:Shader):Bool {
        
        return (shader:ShaderImpl).isBatchingMultiTexture;
        
    }

}
