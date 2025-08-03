package backend;

import ceramic.Path;

using StringTools;

#if !no_backend_docs
/**
 * Unity backend implementation for shader management.
 * Handles loading Unity shaders, setting uniforms, and multi-texture batching.
 * Automatically attempts to load multi-texture variants (with '_mt8' suffix) for better performance.
 */
#end
class Shaders implements spec.Shaders {

    #if !no_backend_docs
    /**
     * Creates a new Shaders manager instance.
     */
    #end
    public function new() {}

    #if !no_backend_docs
    /**
     * Loads a shader from the Unity Resources system.
     * First attempts to load a multi-texture variant (path + '_mt8'), then falls back to the standard shader.
     * @param path Shader resource path (without extension)
     * @param customAttributes Optional custom vertex attributes
     * @param options Loading options (currently unused)
     * @param _done Callback with loaded shader (null on failure)
     */
    #end
    public function load(path:String, ?customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>, ?options:LoadShaderOptions, _done:(shader:backend.Shader)->Void):Void {

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

    #if !no_backend_docs
    /**
     * Destroys a shader.
     * Note: Unity shaders don't need explicit cleanup.
     * @param shader Shader to destroy
     */
    #end
    inline public function destroy(shader:Shader):Void {

        // Shaders don't need to be unloaded

    }

    #if !no_backend_docs
    /**
     * Creates a copy of a shader.
     * The clone shares the same Unity shader but has independent parameters.
     * @param shader Source shader to clone
     * @return New shader instance
     */
    #end
    inline public function clone(shader:Shader):Shader {

        return ShaderImpl.clone(shader);

    }

    #if !no_backend_docs
    /**
     * Calculates the total size of custom float attributes for a shader.
     * Used for vertex buffer allocation.
     * @param shader Shader to analyze
     * @return Total number of floats needed for custom attributes
     */
    #end
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

    #if !no_backend_docs
    /**
     * Sets an integer uniform on the shader.
     * @param shader Target shader
     * @param name Uniform name
     * @param value Integer value
     */
    #end
    inline public function setInt(shader:Shader, name:String, value:Int):Void {

        (shader:ShaderImpl).setInt(name, value);

    }

    #if !no_backend_docs
    /**
     * Sets a float uniform on the shader.
     * @param shader Target shader
     * @param name Uniform name
     * @param value Float value
     */
    #end
    inline public function setFloat(shader:Shader, name:String, value:Float):Void {

        (shader:ShaderImpl).setFloat(name, value);

    }

    #if !no_backend_docs
    /**
     * Sets a color uniform on the shader.
     * @param shader Target shader
     * @param name Uniform name
     * @param r Red component (0-1)
     * @param g Green component (0-1)
     * @param b Blue component (0-1)
     * @param a Alpha component (0-1)
     */
    #end
    inline public function setColor(shader:Shader, name:String, r:Float, g:Float, b:Float, a:Float):Void {

        (shader:ShaderImpl).setColor(name, r, g, b, a);

    }

    #if !no_backend_docs
    /**
     * Sets a 2D vector uniform on the shader.
     * @param shader Target shader
     * @param name Uniform name
     * @param x X component
     * @param y Y component
     */
    #end
    inline public function setVec2(shader:Shader, name:String, x:Float, y:Float):Void {

        (shader:ShaderImpl).setVec2(name, x, y);

    }

    #if !no_backend_docs
    /**
     * Sets a 3D vector uniform on the shader.
     * @param shader Target shader
     * @param name Uniform name
     * @param x X component
     * @param y Y component
     * @param z Z component
     */
    #end
    inline public function setVec3(shader:Shader, name:String, x:Float, y:Float, z:Float):Void {

        (shader:ShaderImpl).setVec3(name, x, y, z);

    }

    #if !no_backend_docs
    /**
     * Sets a 4D vector uniform on the shader.
     * @param shader Target shader
     * @param name Uniform name
     * @param x X component
     * @param y Y component
     * @param z Z component
     * @param w W component
     */
    #end
    inline public function setVec4(shader:Shader, name:String, x:Float, y:Float, z:Float, w:Float):Void {

        (shader:ShaderImpl).setVec4(name, x, y, z, w);

    }

    #if !no_backend_docs
    /**
     * Sets a float array uniform on the shader.
     * @param shader Target shader
     * @param name Uniform name
     * @param array Array of float values
     */
    #end
    inline public function setFloatArray(shader:Shader, name:String, array:Array<Float>):Void {

        (shader:ShaderImpl).setFloatArray(name, array);

    }

    #if !no_backend_docs
    /**
     * Sets a texture uniform on the shader.
     * @param shader Target shader
     * @param name Uniform name
     * @param slot Texture unit slot (0-based)
     * @param texture Texture to bind
     */
    #end
    inline public function setTexture(shader:Shader, name:String, slot:Int, texture:backend.Texture):Void {

        (shader:ShaderImpl).setTexture(name, slot, texture);

    }

    #if !no_backend_docs
    /**
     * Sets a 4x4 matrix uniform from a 2D transform.
     * @param shader Target shader
     * @param name Uniform name
     * @param transform 2D transform to convert
     */
    #end
    inline public function setMat4FromTransform(shader:Shader, name:String, transform:ceramic.Transform):Void {

        (shader:ShaderImpl).setMat4FromTransform(name, transform);

    }

    #if !no_backend_docs
    /**
     * Gets the maximum number of if statements supported in fragment shaders.
     * Used for shader complexity limits.
     * @return Maximum if statements (8 for Unity)
     */
    #end
    inline public function maxIfStatementsByFragmentShader():Int {

        return 8;

    }

    #if !no_backend_docs
    /**
     * Checks if a shader supports multi-texture batching.
     * Multi-texture shaders can render with up to 8 textures in one draw call.
     * @param shader Shader to check
     * @return True if shader supports multi-texture batching
     */
    #end
    inline public function canBatchWithMultipleTextures(shader:Shader):Bool {

        return (shader:ShaderImpl).isBatchingMultiTexture;

    }

    #if !no_backend_docs
    /**
     * Checks if hot reload is supported for shader paths.
     * Unity backend doesn't support shader hot reload.
     * @return Always false for Unity
     */
    #end
    inline public function supportsHotReloadPath():Bool {

        return false;

    }

}
