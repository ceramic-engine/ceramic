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
 * Ceramic supports two shader models:
 * - Combined shader files (default): Single file with both vertex and fragment shaders
 * - Separate vert/frag files: When ceramic_shader_vert_frag flag is enabled
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

#if ceramic_shader_vert_frag
    /**
     * Creates a shader from vertex and fragment shader source code.
     * Available when ceramic_shader_vert_frag compilation flag is set.
     * @param vertSource GLSL source code for the vertex shader
     * @param fragSource GLSL source code for the fragment shader
     * @param customAttributes Optional array of custom vertex attributes
     * @return The compiled shader program, or null on compilation failure
     */
    function fromSource(vertSource:String, fragSource:String, ?customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>):Shader;
#else
    /**
     * Loads a shader from a file (can be precompiled or be compiled on the fly).
     * The file format depends on the backend.
     * @param path Path to the shader file (relative to assets)
     * @param customAttributes Optional array of custom vertex attributes
     * @param options Optional loading configuration
     * @param done Callback invoked with the compiled shader or null on failure
     */
    function load(path:String, ?customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>, ?options:backend.LoadShaderOptions, done:(shader:backend.Shader)->Void):Void;
#end

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
     * Sets a color uniform value in the shader (as vec4).
     * @param shader The shader to modify
     * @param name The uniform variable name
     * @param r Red component (0.0 to 1.0)
     * @param g Green component (0.0 to 1.0)
     * @param b Blue component (0.0 to 1.0)
     * @param a Alpha component (0.0 to 1.0)
     */
    function setColor(shader:Shader, name:String, r:Float, g:Float, b:Float, a:Float):Void;

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
