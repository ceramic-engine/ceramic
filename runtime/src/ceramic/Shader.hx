package ceramic;

import ceramic.AlphaColor;
import ceramic.Assets;
import ceramic.Color;
import ceramic.Shortcuts.*;
import ceramic.Texture;

using StringTools;

/**
 * Represents a GPU shader program for custom rendering effects.
 * 
 * Shaders are programs that run on the GPU to transform vertices and
 * calculate pixel colors. Ceramic uses shaders for all rendering, from
 * basic sprite drawing to complex visual effects.
 * 
 * Key features:
 * - Support for vertex and fragment shaders
 * - Uniform variables for passing data to shaders
 * - Multiple texture slot support
 * - Custom vertex attributes
 * - Automatic shader compilation and linking
 * 
 * Common uses:
 * - Visual effects (blur, glow, distortion)
 * - Color manipulation (hue shift, contrast)
 * - Custom rendering techniques
 * - Post-processing filters
 * - Special material effects
 * 
 * Ceramic provides several built-in shaders:
 * - 'shader:textured' - Standard textured rendering (default)
 * - 'shader:pixelArt' - High-quality pixel art scaling
 * - Various effect shaders depending on plugins
 * 
 * ```haxe
 * // Load and apply a custom shader
 * var shader = assets.shader('myEffect').clone();
 * shader.setFloat('intensity', 0.5);
 * shader.setVec2('resolution', screen.width, screen.height);
 * myVisual.shader = shader;
 * 
 * // Create shader from source (if supported)
 * #if ceramic_shader_vert_frag
 * var customShader = Shader.fromSource(
 *     vertexShaderCode,
 *     fragmentShaderCode
 * );
 * #end
 * 
 * // Animate shader uniforms
 * app.onUpdate(this, delta -> {
 *     shader.setFloat('time', Timer.now);
 *     shader.setColor('tint', Color.fromHSB(
 *         (Timer.now * 60) % 360, 1, 1
 *     ));
 * });
 * ```
 * 
 * @see ShaderAsset
 * @see Visual.shader
 * @see ShaderAttribute
 */
class Shader extends Entity {

/// Static helpers

#if ceramic_shader_vert_frag
    /**
     * Creates a shader from vertex and fragment shader source code.
     * 
     * The expected shading language depends on the backend:
     * - Clay/Web backends: GLSL ES
     * - Unity backend: Unity shader language
     * - Future backends may support different languages
     * 
     * This method is only available when the backend supports
     * runtime shader compilation (ceramic_shader_vert_frag flag).
     * 
     * @param vertSource Vertex shader source code
     * @param fragSource Fragment shader source code
     * @return New shader instance, or null if compilation fails
     */
    public static function fromSource(vertSource:String, fragSource:String):Shader {

        var backendItem = app.backend.shaders.fromSource(vertSource, fragSource);
        if (backendItem == null) return null;

        return new Shader(backendItem);

    }
#end

/// Properties

    /**
     * The backend-specific shader implementation.
     * Used internally by the rendering system.
     */
    public var backendItem:backend.Shader;

    /**
     * The shader asset this shader was loaded from.
     * Null if created programmatically.
     */
    public var asset:ShaderAsset;

    /**
     * All vertex attributes used by this shader.
     * Includes standard attributes (position, texCoord, color)
     * plus any custom attributes.
     */
    public var attributes:ReadOnlyArray<ShaderAttribute>;

    /**
     * Custom vertex attributes beyond the standard ones.
     * Used for passing additional per-vertex data to shaders.
     */
    public var customAttributes:ReadOnlyArray<ShaderAttribute>;

    /**
     * Total size of custom float attributes in the vertex buffer.
     * Calculated from customAttributes array.
     */
    public var customFloatAttributesSize(default, null):Int;

    var textureSlots:IntMap<Texture> = null;

    @:allow(ceramic.App)
    var usedTextures:Array<Texture> = null;

/// Lifecycle

    /**
     * Creates a new shader instance.
     * 
     * Standard vertex attributes are automatically included:
     * - vertexPosition (vec3): Vertex position in model space
     * - vertexTCoord (vec2): Texture coordinates
     * - vertexColor (vec4): Vertex color with alpha
     * 
     * @param backendItem Backend-specific shader implementation
     * @param customAttributes Optional additional vertex attributes
     */
    public function new(backendItem:backend.Shader, ?customAttributes:ReadOnlyArray<ShaderAttribute>) {

        super();

        this.backendItem = backendItem;

        var attributes:Array<ShaderAttribute> = [
            { size: 3, name: 'vertexPosition' },
            { size: 2, name: 'vertexTCoord' },
            { size: 4, name: 'vertexColor' }
        ];

        if (customAttributes != null) {
            for (i in 0...customAttributes.length) {
                var attribute = customAttributes.unsafeGet(i);
                attributes.push(attribute);
            }
        }

        this.attributes = attributes;
        this.customAttributes = customAttributes;

        this.customFloatAttributesSize = app.backend.shaders.customFloatAttributesSize(backendItem);

    }

    override function destroy() {

        super.destroy();

        if (asset != null) asset.destroy();

        app.backend.shaders.destroy(backendItem);
        backendItem = null;
        attributes = null;

    }

    /**
     * Creates a copy of this shader with independent uniform values.
     * 
     * Useful when you need multiple instances of the same shader
     * with different parameters.
     * 
     * @return A new shader instance with the same program but separate uniforms
     */
    public function clone():Shader {

        var clonedBackendItem = app.backend.shaders.clone(backendItem);
        var cloned = new Shader(clonedBackendItem, customAttributes);

        return cloned;

    }

/// Public API

    /**
     * Sets an integer uniform variable.
     * @param name The uniform variable name in the shader
     * @param value The integer value to set
     */
    inline public function setInt(name:String, value:Int):Void {

        app.backend.shaders.setInt(backendItem, name, value);

    }

    /**
     * Sets a float uniform variable.
     * @param name The uniform variable name in the shader
     * @param value The float value to set
     */
    inline public function setFloat(name:String, value:Float):Void {

        app.backend.shaders.setFloat(backendItem, name, value);

    }

    /**
     * Sets a color uniform variable (RGB with full alpha).
     * The color is passed as vec4 with alpha = 1.0.
     * @param name The uniform variable name in the shader
     * @param color The color value (alpha ignored)
     */
    inline public function setColor(name:String, color:Color):Void {

        app.backend.shaders.setColor(backendItem, name, color.redFloat, color.greenFloat, color.blueFloat, 1.0);

    }

    /**
     * Sets a color uniform variable with alpha (RGBA).
     * The color is passed as vec4 including alpha channel.
     * @param name The uniform variable name in the shader
     * @param color The color value with alpha
     */
    inline public function setAlphaColor(name:String, color:AlphaColor):Void {

        app.backend.shaders.setColor(backendItem, name, color.redFloat, color.greenFloat, color.blueFloat, color.alphaFloat);

    }

    /**
     * Sets a vec2 uniform variable.
     * @param name The uniform variable name in the shader
     * @param x The x component
     * @param y The y component
     */
    inline public function setVec2(name:String, x:Float, y:Float):Void {

        app.backend.shaders.setVec2(backendItem, name, x, y);

    }

    /**
     * Sets a vec3 uniform variable.
     * @param name The uniform variable name in the shader
     * @param x The x component
     * @param y The y component
     * @param z The z component
     */
    inline public function setVec3(name:String, x:Float, y:Float, z:Float):Void {

        app.backend.shaders.setVec3(backendItem, name, x, y, z);

    }

    /**
     * Sets a vec4 uniform variable.
     * @param name The uniform variable name in the shader
     * @param x The x component
     * @param y The y component
     * @param z The z component
     * @param w The w component
     */
    inline public function setVec4(name:String, x:Float, y:Float, z:Float, w:Float):Void {

        app.backend.shaders.setVec4(backendItem, name, x, y, z, w);

    }

    /**
     * Sets a float array uniform variable.
     * Useful for passing multiple values or matrices.
     * @param name The uniform variable name in the shader
     * @param array The array of float values
     */
    inline public function setFloatArray(name:String, array:Array<Float>):Void {

        app.backend.shaders.setFloatArray(backendItem, name, array);

    }

    /**
     * Sets a texture uniform variable.
     * 
     * Textures are bound to numbered slots (0, 1, 2, etc.).
     * Slot 0 is typically used for the main texture.
     * 
     * @param name The uniform sampler2D variable name in the shader
     * @param slot The texture slot index (0-based)
     * @param texture The texture to bind, or null to unbind
     */
    public function setTexture(name:String, slot:Int, texture:Texture):Void {

        if (textureSlots == null) {
            textureSlots = new IntMap();
            usedTextures = [];
        }

        // Remove previous texture (if any) at slot
        final prevTexture = textureSlots.get(slot);
        if (prevTexture != null) {
            usedTextures.splice(usedTextures.indexOf(prevTexture), 1);
        }

        // Add new texture (if any) at slot
        textureSlots.set(slot, texture);
        if (texture != null) {
            usedTextures.push(texture);
        }

        app.backend.shaders.setTexture(backendItem, name, slot, texture?.backendItem);

    }

    /**
     * Sets a mat4 uniform variable from a Transform.
     * Converts the transform to a 4x4 matrix for the shader.
     * @param name The uniform mat4 variable name in the shader
     * @param transform The transform to convert to matrix
     */
    inline public function setMat4FromTransform(name:String, transform:Transform):Void {

        app.backend.shaders.setMat4FromTransform(backendItem, name, transform);

    }

/// Print

    override function toString():String {

        if (id != null) {
            var name = id;
            if (name.startsWith('shader:')) name = name.substr(7);
            if (asset != null && asset.options.vertId != null || asset.options.fragId != null) {
                var vertId = asset.options.vertId != null ? asset.options.vertId : 'default';
                var fragId = asset.options.fragId != null ? asset.options.fragId : 'default';
                return 'Shader($name $vertId $fragId)';
            }
            else {
                return 'Shader($name)';
            }
        } else {
            return 'Shader()';
        }

    }

} //Shader