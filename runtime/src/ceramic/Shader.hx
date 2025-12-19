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

/// Properties

    /**
     * The backend-specific shader implementation.
     * Used internally by the rendering system.
     */
    public var backendItem(default, set):backend.Shader = null;
    function set_backendItem(backendItem:backend.Shader):backend.Shader {
        if (this.backendItem != backendItem) {
            this.backendItem = backendItem;
            if (backendItem != null) {
                this.customFloatAttributesSize = app.backend.shaders.customFloatAttributesSize(backendItem);
            }
        }
        return backendItem;
    }

    /**
     * The shader asset this shader was loaded from.
     * Null if created programmatically.
     */
    public var asset:ShaderAsset;

    /**
     * All vertex attributes used by this shader (except texture slot attribute)
     * Includes standard attributes (position, texCoord, color)
     * plus any custom attributes.
     */
    public var attributes:ReadOnlyArray<ShaderAttribute>;

    /**
     * Base standard vertex attributes (position, texCoord, color),
     * without any custom attribute.
     */
    public var baseAttributes:ReadOnlyArray<ShaderAttribute>;

    /**
     * Custom vertex attributes beyond the standard ones.
     * Used for passing additional per-vertex data to shaders.
     */
    public var customAttributes:ReadOnlyArray<ShaderAttribute>;

    /**
     * Vertex attribute used to store texture slot (if the shader is a multi-texture shader).
     */
    public var textureIdAttribute:ShaderAttribute;

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
    public function new(customAttributes:ReadOnlyArray<ShaderAttribute>, baseAttributes:ReadOnlyArray<ShaderAttribute>, textureIdAttribute:ShaderAttribute) {

        super();

        var attributes:Array<ShaderAttribute> = baseAttributes ?? [
            { size: 3, name: 'vertexPosition' },
            { size: 2, name: 'vertexTCoord' },
            { size: 4, name: 'vertexColor' }
        ];

        this.baseAttributes = [].concat(attributes);

        if (customAttributes != null) {
            for (i in 0...customAttributes.length) {
                var attribute = customAttributes.unsafeGet(i);
                attributes.push(attribute);
            }
        }

        this.attributes = attributes;
        this.customAttributes = customAttributes;
        this.textureIdAttribute = textureIdAttribute;

    }

    override function destroy() {

        super.destroy();

        if (asset != null) asset.destroy();

        if (backendItem != null) {
            app.backend.shaders.destroy(backendItem);
            backendItem = null;
        }
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

        var cloned = new Shader(customAttributes, baseAttributes, textureIdAttribute);
        cloned.backendItem = clonedBackendItem;

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
    public extern inline overload function setVec3(name:String, x:Float, y:Float, z:Float):Void {

        app.backend.shaders.setVec3(backendItem, name, x, y, z);

    }

    /**
     * Sets a vec3 uniform variable from a Color (RGB).
     * @param name The uniform variable name in the shader
     * @param color The color value (RGB components)
     */
    public extern inline overload function setVec3(name:String, color:Color):Void {

        app.backend.shaders.setVec3(backendItem, name, color.redFloat, color.greenFloat, color.blueFloat);

    }

    /**
     * Sets a vec4 uniform variable.
     * @param name The uniform variable name in the shader
     * @param x The x component
     * @param y The y component
     * @param z The z component
     * @param w The w component
     */
    public extern inline overload function setVec4(name:String, x:Float, y:Float, z:Float, w:Float):Void {

        app.backend.shaders.setVec4(backendItem, name, x, y, z, w);

    }

    /**
     * Sets a vec4 uniform variable from a Color (RGB + alpha=1.0).
     * @param name The uniform variable name in the shader
     * @param color The color value (RGB components, alpha set to 1.0)
     */
    public extern inline overload function setVec4(name:String, color:Color):Void {

        app.backend.shaders.setVec4(backendItem, name, color.redFloat, color.greenFloat, color.blueFloat, 1.0);

    }

    /**
     * Sets a vec4 uniform variable from an AlphaColor (RGBA).
     * @param name The uniform variable name in the shader
     * @param color The color value with alpha (RGBA components)
     */
    public extern inline overload function setVec4(name:String, color:AlphaColor):Void {

        app.backend.shaders.setVec4(backendItem, name, color.redFloat, color.greenFloat, color.blueFloat, color.alphaFloat);

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
     * Resolve the texture slot for the given name
     * @param name The name of the texture uniform
     * @return The slot or `-1` if not found.
     */
    function resolveTextureSlot(name:String):Int {

        // Overrided by actual shader subclasses
        return -1;

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
    public function setTexture(name:String, slot:Int = -1, texture:Texture):Void {

        if (slot < 0) {
            slot = resolveTextureSlot(name);
        }

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
     * Sets a mat2 uniform variable (column-major order).
     * @param name The uniform mat2 variable name in the shader
     * @param m00 Column 0, row 0
     * @param m10 Column 0, row 1
     * @param m01 Column 1, row 0
     * @param m11 Column 1, row 1
     */
    inline public function setMat2(name:String, m00:Float, m10:Float, m01:Float, m11:Float):Void {

        app.backend.shaders.setMat2(backendItem, name, m00, m10, m01, m11);

    }

    /**
     * Sets a mat3 uniform variable (column-major order).
     * @param name The uniform mat3 variable name in the shader
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
    public extern inline overload function setMat3(name:String, m00:Float, m10:Float, m20:Float, m01:Float, m11:Float, m21:Float, m02:Float, m12:Float, m22:Float):Void {

        app.backend.shaders.setMat3(backendItem, name, m00, m10, m20, m01, m11, m21, m02, m12, m22);

    }

    /**
     * Sets a mat4 uniform variable (column-major order).
     * @param name The uniform mat4 variable name in the shader
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
    public extern inline overload function setMat4(name:String, m00:Float, m10:Float, m20:Float, m30:Float, m01:Float, m11:Float, m21:Float, m31:Float, m02:Float, m12:Float, m22:Float, m32:Float, m03:Float, m13:Float, m23:Float, m33:Float):Void {

        app.backend.shaders.setMat4(backendItem, name, m00, m10, m20, m30, m01, m11, m21, m31, m02, m12, m22, m32, m03, m13, m23, m33);

    }

    /**
     * Sets a mat3 uniform variable from a Transform.
     * Converts the 2D transform to a 3x3 matrix for the shader.
     * @param name The uniform mat3 variable name in the shader
     * @param transform The transform to convert to matrix
     */
    public extern inline overload function setMat3(name:String, transform:Transform):Void {

        // 2D affine transform as 3x3 matrix (column-major):
        // | a   c   tx |
        // | b   d   ty |
        // | 0   0   1  |
        app.backend.shaders.setMat3(backendItem, name,
            transform.a, transform.b, 0,
            transform.c, transform.d, 0,
            transform.tx, transform.ty, 1
        );

    }

    /**
     * Sets a mat4 uniform variable from a Transform.
     * Converts the 2D transform to a 4x4 matrix for the shader.
     * @param name The uniform mat4 variable name in the shader
     * @param transform The transform to convert to matrix
     */
    public extern inline overload function setMat4(name:String, transform:Transform):Void {

        // 2D affine transform embedded in 4x4 matrix (column-major):
        // | a   c   0   tx |
        // | b   d   0   ty |
        // | 0   0   1   0  |
        // | 0   0   0   1  |
        app.backend.shaders.setMat4(backendItem, name,
            transform.a, transform.b, 0, 0,
            transform.c, transform.d, 0, 0,
            0, 0, 1, 0,
            transform.tx, transform.ty, 0, 1
        );

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