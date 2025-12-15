package spec;

import backend.Shader;
import backend.Texture;

/**
 * Backend interface for GPU shader program management.
 *
 * This interface handles loading, compiling, and managing shader programs
 * that run on the GPU. Shaders control how vertices are transformed and
 * how pixels are colored during rendering.
 *
 * Shaders can have uniform parameters (shared across all vertices/pixels) and
 * custom vertex attributes (per-vertex data). The interface provides methods
 * to set various types of uniform values.
 */
interface Shaders {

    /**
     * Destroys a shader program and frees its GPU resources.
     * After calling this, the shader should not be used.
     * @param shader The shader to destroy
     */
    function destroy(shader:Shader):Void;

    /**
     * Loads a shader from a file (can be precompiled or be compiled on the fly).
     * The file format depends on the backend.
     * @param path Path to the shader file (relative to assets)
     * @param baseAttributes Base vertex attributes (position, texCoord, color)
     * @param customAttributes Custom vertex attributes beyond base ones (can be null)
     * @param textureIdAttribute Texture slot attribute for multi-texture batching (can be null)
     * @param done Callback invoked with the compiled shader or null on failure
     */
    function load(path:String, baseAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>, customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>, textureIdAttribute:ceramic.ShaderAttribute, done:(shader:backend.Shader)->Void):Void;

    /**
     * Creates a copy of a shader with its own uniform values.
     * The GPU program is shared, but uniform values can be set independently.
     * @param shader The shader to clone
     * @return A new shader instance sharing the same GPU program
     */
    function clone(shader:Shader):Shader;

/// Public API

    /**
     * Sets an integer uniform value in the shader.
     * @param shader The shader to modify
     * @param name The uniform variable name
     * @param value The integer value to set
     */
    function setInt(shader:Shader, name:String, value:Int):Void;

    /**
     * Sets a float uniform value in the shader.
     * @param shader The shader to modify
     * @param name The uniform variable name
     * @param value The float value to set
     */
    function setFloat(shader:Shader, name:String, value:Float):Void;

    /**
     * Sets a 2D vector uniform value in the shader.
     * @param shader The shader to modify
     * @param name The uniform variable name
     * @param x X component
     * @param y Y component
     */
    function setVec2(shader:Shader, name:String, x:Float, y:Float):Void;

    /**
     * Sets a 3D vector uniform value in the shader.
     * @param shader The shader to modify
     * @param name The uniform variable name
     * @param x X component
     * @param y Y component
     * @param z Z component
     */
    function setVec3(shader:Shader, name:String, x:Float, y:Float, z:Float):Void;

    /**
     * Sets a 4D vector uniform value in the shader.
     * @param shader The shader to modify
     * @param name The uniform variable name
     * @param x X component
     * @param y Y component
     * @param z Z component
     * @param w W component
     */
    function setVec4(shader:Shader, name:String, x:Float, y:Float, z:Float, w:Float):Void;

    /**
     * Sets an array of float uniform values in the shader.
     * Used for uniform float arrays in GLSL.
     * @param shader The shader to modify
     * @param name The uniform array variable name
     * @param array The array of float values
     */
    function setFloatArray(shader:Shader, name:String, array:Array<Float>):Void;

    /**
     * Binds a texture to a shader sampler uniform.
     * @param shader The shader to modify
     * @param name The sampler uniform variable name
     * @param slot The texture unit slot (0-15 typically)
     * @param texture The texture to bind
     */
    function setTexture(shader:Shader, name:String, slot:Int, texture:Texture):Void;

    /**
     * Sets a 2x2 matrix uniform value in the shader (column-major order).
     * @param shader The shader to modify
     * @param name The uniform variable name
     * @param m00 Column 0, row 0
     * @param m10 Column 0, row 1
     * @param m01 Column 1, row 0
     * @param m11 Column 1, row 1
     */
    function setMat2(shader:Shader, name:String, m00:Float, m10:Float, m01:Float, m11:Float):Void;

    /**
     * Sets a 3x3 matrix uniform value in the shader (column-major order).
     * @param shader The shader to modify
     * @param name The uniform variable name
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
    function setMat3(shader:Shader, name:String, m00:Float, m10:Float, m20:Float, m01:Float, m11:Float, m21:Float, m02:Float, m12:Float, m22:Float):Void;

    /**
     * Sets a 4x4 matrix uniform value in the shader (column-major order).
     * @param shader The shader to modify
     * @param name The uniform variable name
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
    function setMat4(shader:Shader, name:String, m00:Float, m10:Float, m20:Float, m30:Float, m01:Float, m11:Float, m21:Float, m31:Float, m02:Float, m12:Float, m22:Float, m32:Float, m03:Float, m13:Float, m23:Float, m33:Float):Void;

    /**
     * Gets the total size of custom float attributes per vertex.
     * This is the sum of all custom attribute sizes defined for the shader.
     * @param shader The shader to query
     * @return The number of floats per vertex for custom attributes
     */
    function customFloatAttributesSize(shader:Shader):Int;

    /**
     * Gets the maximum number of if statements supported in fragment shaders.
     * This varies by GPU and affects shader complexity limits.
     * @return The maximum if statement count, or -1 if unlimited
     */
    function maxIfStatementsByFragmentShader():Int;

    /**
     * Checks if the shader supports batching with multiple textures.
     * When true, the shader can render geometry using different textures
     * in a single draw call by using texture arrays or multi-texturing.
     * @param shader The shader to check
     * @return True if multi-texture batching is supported
     */
    function canBatchWithMultipleTextures(shader:Shader):Bool;

    /**
     * Checks if the backend supports hot-reloading of shader files.
     * When true, shaders can include a `?hot=timestamp` query parameter
     * to bypass caching and force reloading during development.
     * @return True if hot-reload paths are supported, false otherwise
     */
    function supportsHotReloadPath():Bool;

}
