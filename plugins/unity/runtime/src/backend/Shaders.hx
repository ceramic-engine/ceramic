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
     * @param baseAttributes Base vertex attributes (position, texCoord, color)
     * @param customAttributes Custom vertex attributes beyond base ones (can be null)
     * @param textureIdAttribute Texture slot attribute for multi-texture batching (can be null)
     * @param _done Callback with loaded shader (null on failure)
     */
    #end
    public function load(path:String, baseAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>, customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>, textureIdAttribute:ceramic.ShaderAttribute, _done:(shader:backend.Shader)->Void):Void {

        var done = function(shader:Shader) {
            ceramic.App.app.onceImmediate(function() {
                _done(shader);
                _done = null;
            });
        };

        var unityPath = Path.withoutExtension(path);
        var unityShader:Dynamic = null;
        #if !ceramic_no_multitexture
        if (textureIdAttribute != null) {
            var unityPathMultiTexture = unityPath + '_mt8';
            try {
                unityShader = untyped __cs__('UnityEngine.Shader.Find({0})', unityPathMultiTexture);
            }
            catch (e:Dynamic) {
                // No valid multi texture shader
                trace('Failed to load multi texture shader: $unityPathMultiTexture');
            }
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
     * Sets a 2x2 matrix uniform value in the shader (column-major order).
     * @param shader Target shader
     * @param name Uniform name
     * @param m00 Column 0, row 0
     * @param m10 Column 0, row 1
     * @param m01 Column 1, row 0
     * @param m11 Column 1, row 1
     */
    #end
    inline public function setMat2(shader:Shader, name:String, m00:Float, m10:Float, m01:Float, m11:Float):Void {

        (shader:ShaderImpl).setMat2(name, m00, m10, m01, m11);

    }

    #if !no_backend_docs
    /**
     * Sets a 3x3 matrix uniform value in the shader (column-major order).
     * @param shader Target shader
     * @param name Uniform name
     * @param m00 Column 0, row 0
     * @param m10 Column 0, row 1
     * @param m20 Column 0, row 2
     * @param m01 Column 1, row 0
     * @param m11 Column 1, row 1
     * @param m21 Column 1, row 2
     * @param m02 Column 2, row 0
     * @param m12 Column 2, row 1
     * @param m22 Column 2, row 2
     */
    #end
    inline public function setMat3(shader:Shader, name:String, m00:Float, m10:Float, m20:Float, m01:Float, m11:Float, m21:Float, m02:Float, m12:Float, m22:Float):Void {

        (shader:ShaderImpl).setMat3(name, m00, m10, m20, m01, m11, m21, m02, m12, m22);

    }

    #if !no_backend_docs
    /**
     * Sets a 4x4 matrix uniform value in the shader (column-major order).
     * @param shader Target shader
     * @param name Uniform name
     * @param m00 Column 0, row 0
     * @param m10 Column 0, row 1
     * @param m20 Column 0, row 2
     * @param m30 Column 0, row 3
     * @param m01 Column 1, row 0
     * @param m11 Column 1, row 1
     * @param m21 Column 1, row 2
     * @param m31 Column 1, row 3
     * @param m02 Column 2, row 0
     * @param m12 Column 2, row 1
     * @param m22 Column 2, row 2
     * @param m32 Column 2, row 3
     * @param m03 Column 3, row 0
     * @param m13 Column 3, row 1
     * @param m23 Column 3, row 2
     * @param m33 Column 3, row 3
     */
    #end
    inline public function setMat4(shader:Shader, name:String, m00:Float, m10:Float, m20:Float, m30:Float, m01:Float, m11:Float, m21:Float, m31:Float, m02:Float, m12:Float, m22:Float, m32:Float, m03:Float, m13:Float, m23:Float, m33:Float):Void {

        (shader:ShaderImpl).setMat4(name, m00, m10, m20, m30, m01, m11, m21, m31, m02, m12, m22, m32, m03, m13, m23, m33);

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
