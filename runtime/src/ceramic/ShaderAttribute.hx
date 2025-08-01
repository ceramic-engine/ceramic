package ceramic;

/**
 * Defines a vertex attribute for shader programs.
 * 
 * Vertex attributes are per-vertex data passed from the CPU to the GPU.
 * Each attribute has a name (used in the shader) and a size (number of components).
 * 
 * Standard attributes in Ceramic:
 * - vertexPosition: vec3 (x, y, z)
 * - vertexTCoord: vec2 (u, v texture coordinates)
 * - vertexColor: vec4 (r, g, b, a)
 * 
 * Custom attributes can be added for advanced effects:
 * - Normal vectors for lighting
 * - Tangent vectors for normal mapping
 * - Additional texture coordinates
 * - Per-vertex animation data
 * 
 * @example
 * ```haxe
 * // Define custom attributes for a shader
 * var customAttrs:Array<ShaderAttribute> = [
 *     { size: 3, name: 'vertexNormal' },
 *     { size: 4, name: 'vertexTangent' },
 *     { size: 2, name: 'vertexTCoord2' }
 * ];
 * 
 * // Create shader with custom attributes
 * var shader = new Shader(backendShader, customAttrs);
 * ```
 * 
 * @see Shader
 * @see Mesh
 */
@:structInit
class ShaderAttribute {

    /**
     * Number of components in this attribute.
     * - 1 = single float
     * - 2 = vec2 (e.g., texture coordinates)
     * - 3 = vec3 (e.g., positions, normals)
     * - 4 = vec4 (e.g., colors with alpha)
     */
    public var size:Int;

    /**
     * The attribute name as used in the shader code.
     * Must match the attribute declaration in the vertex shader.
     * 
     * Example: 'vertexPosition' matches 'attribute vec3 vertexPosition;'
     */
    public var name:String;

    /**
     * Creates a new shader attribute definition.
     * @param size Number of components (1-4)
     * @param name Attribute name in shader code
     */
    public function new(size:Int, name:String) {

        this.size = size;
        this.name = name;

    }

/// Print

    function toString():String {

        return '' + {
            size: size,
            name: name
        };

    }

}
