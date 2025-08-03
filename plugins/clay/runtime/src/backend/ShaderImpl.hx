package backend;

import clay.graphics.Uniforms;

/**
 * Clay backend implementation of GPU shader programs.
 * 
 * This class extends Clay's base Shader class to add Ceramic-specific
 * functionality like custom vertex attributes and multi-texture batching
 * support. It manages the compiled shader code and provides cloning
 * capabilities for shader reuse.
 * 
 * Shaders in Ceramic consist of:
 * - Vertex shader: Transforms vertices from model to screen space
 * - Fragment shader: Calculates the color of each pixel
 * - Custom attributes: Additional per-vertex data
 * - Uniforms: Global shader parameters
 * 
 * @see ceramic.Shader For the high-level shader API
 * @see ceramic.ShaderAttribute For custom vertex attributes
 */
class ShaderImpl extends clay.graphics.Shader {

    /**
     * Custom vertex attributes defined for this shader.
     * These allow passing additional per-vertex data beyond
     * the standard position, color, and texture coordinates.
     */
    public var customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute> = null;

    /**
     * Whether this shader supports multi-texture batching.
     * When true, the shader can render multiple textures in a single draw call,
     * improving performance for complex scenes with many different textures.
     */
    public var isBatchingMultiTexture:Bool = false;

    public function new() {

        super();

    }

    /**
     * Creates a deep copy of this shader.
     * 
     * The cloned shader will have the same source code, attributes,
     * and settings but will be a separate GPU resource. This is useful
     * for creating shader variations or when multiple materials need
     * similar but independent shaders.
     * 
     * Note: Currently recompiles the shader source. Future optimization
     * could share compiled shader programs between clones.
     * 
     * @return A new ShaderImpl instance with the same configuration
     */
    public function clone():ShaderImpl {

        // This might be optimized later, so that we don't need to recompile cloned shader code
        var shader = new ShaderImpl();
        shader.vertSource = vertSource;
        shader.fragSource = fragSource;
        shader.customAttributes = customAttributes;
        shader.isBatchingMultiTexture = isBatchingMultiTexture;
        shader.attributes = attributes;
        shader.textures = textures;
        shader.init();
        return shader;

    }

}