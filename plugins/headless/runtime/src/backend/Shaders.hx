package backend;

import ceramic.Path;

using StringTools;

#if !no_backend_docs
/**
 * Shader management system for the headless backend.
 * 
 * This class implements the Ceramic shader specification but provides
 * mock functionality since no actual GPU shaders are compiled or used
 * in headless mode. It maintains shader objects and their metadata
 * for API compatibility and buffer calculations.
 * 
 * All shader operations return valid objects and maintain state but
 * don't perform actual GPU compilation or uniform setting.
 */
#end
class Shaders implements spec.Shaders {

    #if !no_backend_docs
    /**
     * Creates a new headless shader management system.
     */
    #end
    public function new() {}

    #if !no_backend_docs
    /**
     * Creates a shader from vertex and fragment source code.
     * 
     * In headless mode, this creates a mock shader object without
     * actually compiling the shader source.
     * 
     * @param vertSource Vertex shader source code (ignored)
     * @param fragSource Fragment shader source code (ignored)
     * @param customAttributes Optional custom vertex attributes
     * @return A mock shader implementation
     */
    #end
    inline public function fromSource(vertSource:String, fragSource:String, ?customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>):Shader {

        return new ShaderImpl(customAttributes);

    }

    #if !no_backend_docs
    /**
     * Destroys a shader and frees its resources.
     * 
     * In headless mode, this is a no-op since no GPU resources are allocated.
     * 
     * @param shader The shader to destroy
     */
    #end
    inline public function destroy(shader:Shader):Void {

        //

    }

    #if !no_backend_docs
    /**
     * Creates a copy of an existing shader.
     * 
     * @param shader The shader to clone
     * @return A new shader instance
     */
    #end
    inline public function clone(shader:Shader):Shader {

        return new ShaderImpl();

    }

/// Public API

    #if !no_backend_docs
    /**
     * Sets an integer uniform value on the shader.
     * 
     * @param shader The shader to modify
     * @param name The uniform variable name
     * @param value The integer value to set
     */
    #end
    inline public function setInt(shader:Shader, name:String, value:Int):Void {

        //

    }

    #if !no_backend_docs
    /**
     * Sets a float uniform value on the shader.
     * 
     * @param shader The shader to modify
     * @param name The uniform variable name
     * @param value The float value to set
     */
    #end
    inline public function setFloat(shader:Shader, name:String, value:Float):Void {

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

    inline public function setTexture(shader:Shader, name:String, slot:Int, texture:backend.Texture):Void {

        //

    }

    inline public function setMat2(shader:Shader, name:String, m00:Float, m10:Float, m01:Float, m11:Float):Void {

        //

    }

    inline public function setMat3(shader:Shader, name:String, m00:Float, m10:Float, m20:Float, m01:Float, m11:Float, m21:Float, m02:Float, m12:Float, m22:Float):Void {

        //

    }

    inline public function setMat4(shader:Shader, name:String, m00:Float, m10:Float, m20:Float, m30:Float, m01:Float, m11:Float, m21:Float, m31:Float, m02:Float, m12:Float, m22:Float, m32:Float, m03:Float, m13:Float, m23:Float, m33:Float):Void {

        //

    }

    #if !no_backend_docs
    /**
     * Calculates the total size of custom float attributes for a shader.
     * 
     * This is used by the draw system to determine vertex buffer layout
     * and sizing, even in headless mode where the values are needed
     * for proper buffer management.
     * 
     * @param shader The shader to analyze
     * @return Total size of custom attributes in floats
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

    #if !no_backend_docs
    /**
     * Gets the maximum number of if statements supported in fragment shaders.
     * 
     * @return Always 0 in headless mode since no actual shaders are compiled
     */
    #end
    public function maxIfStatementsByFragmentShader():Int {

        return 0;

    }

    #if !no_backend_docs
    /**
     * Determines if a shader can batch multiple textures in a single draw call.
     * 
     * @param shader The shader to check
     * @return Always false in headless mode
     */
    #end
    public function canBatchWithMultipleTextures(shader:Shader):Bool {

        return false;

    }

    #if !no_backend_docs
    /**
     * Indicates whether this backend supports hot reloading of shader assets.
     * 
     * @return Always false for the headless backend
     */
    #end
    inline public function supportsHotReloadPath():Bool {

        return false;

    }

}
