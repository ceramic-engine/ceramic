package backend;

using ceramic.Extensions;

#if !no_backend_docs
/**
 * Concrete implementation of a Unity shader program.
 * Manages shader parameters, uniforms, and texture bindings.
 * Tracks parameter changes for efficient material updates.
 */
#end
@:allow(backend.MaterialData)
class ShaderImpl {

    #if !no_backend_docs
    /**
     * Maximum value for parameter version before wrapping.
     * Used to prevent integer overflow in long-running applications.
     */
    #end
    static final MAX_PARAMS_DIRTY:Int = 999999999;

    #if !no_backend_docs
    /**
     * Path to the shader resource file.
     */
    #end
    public var path:String = null;

    #if !no_backend_docs
    /**
     * Reference to the Unity Shader object.
     */
    #end
    public var unityShader:Dynamic = null;

    #if !no_backend_docs
    /**
     * Custom vertex attributes defined by this shader.
     */
    #end
    public var customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute> = null;

    #if !no_backend_docs
    /**
     * Whether this shader supports multi-texture batching.
     * Allows rendering with multiple textures in a single draw call.
     */
    #end
    public var isBatchingMultiTexture:Bool = false;

    #if !no_backend_docs
    /**
     * Version counter incremented when parameters change.
     * Used by MaterialData to detect when uniforms need updating.
     */
    #end
    var paramsVersion:Int = 0;

    #if !no_backend_docs
    /**
     * Integer uniform parameters.
     */
    #end
    var intParams:Map<String,Int> = null;

    #if !no_backend_docs
    /**
     * Float uniform parameters.
     */
    #end
    var floatParams:Map<String,Float> = null;

    #if !no_backend_docs
    /**
     * Color uniform parameters (RGBA).
     */
    #end
    var colorParams:Map<String,unityengine.Color> = null;

    #if !no_backend_docs
    /**
     * 2D vector uniform parameters.
     */
    #end
    var vec2Params:Map<String,unityengine.Vector2> = null;

    #if !no_backend_docs
    /**
     * 3D vector uniform parameters.
     */
    #end
    var vec3Params:Map<String,unityengine.Vector3> = null;

    #if !no_backend_docs
    /**
     * 4D vector uniform parameters.
     */
    #end
    var vec4Params:Map<String,unityengine.Vector4> = null;

    #if !no_backend_docs
    /**
     * Float array uniform parameters.
     */
    #end
    var floatArrayParams:Map<String,cs.NativeArray<Single>> = null;

    #if !no_backend_docs
    /**
     * Texture uniform parameters mapped by name.
     */
    #end
    var textureParams:Map<String,backend.Texture> = null;

    #if !no_backend_docs
    /**
     * Texture references indexed by slot number.
     * Used for multi-texture batching.
     */
    #end
    var textureSlots:Array<backend.Texture> = null;

    #if !no_backend_docs
    /**
     * 4x4 matrix uniform parameters.
     */
    #end
    var mat4Params:Map<String,unityengine.Matrix4x4> = null;

    #if !no_backend_docs
    /**
     * Creates a new shader implementation.
     * @param unityShader Unity Shader object
     * @param customAttributes Optional custom vertex attributes
     */
    #end
    public function new(unityShader:Dynamic, ?customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>) {

        this.unityShader = unityShader;
        this.customAttributes = customAttributes;

    }

    #if !no_backend_docs
    /**
     * Creates a copy of an existing shader.
     * Parameters are not copied, only the shader reference and attributes.
     * @param fromShader Source shader to clone
     * @return New shader instance with same Unity shader and attributes
     */
    #end
    public static function clone(fromShader:ShaderImpl):ShaderImpl {

        var newShader = new ShaderImpl(fromShader.unityShader, fromShader.customAttributes);
        newShader.path = fromShader.path;
        newShader.isBatchingMultiTexture = fromShader.isBatchingMultiTexture;

        return newShader;

    }

    #if !no_backend_docs
    /**
     * Sets an integer uniform parameter.
     * @param name Uniform name in the shader
     * @param value Integer value
     */
    #end
    public function setInt(name:String, value:Int):Void {

        if (intParams == null)
            intParams = new Map();

        name = sanitizeUniformName(name);

        if (!intParams.exists(name) || intParams.get(name) != value) {
            intParams.set(name, value);
            paramsVersion++;
            if (paramsVersion > MAX_PARAMS_DIRTY)
                paramsVersion = 1;
        }

    }

    #if !no_backend_docs
    /**
     * Sets a float uniform parameter.
     * @param name Uniform name in the shader
     * @param value Float value
     */
    #end
    public function setFloat(name:String, value:Float):Void {

        if (floatParams == null)
            floatParams = new Map();

        name = sanitizeUniformName(name);

        if (!floatParams.exists(name) || floatParams.get(name) != value) {
            floatParams.set(name, value);
            paramsVersion++;
            if (paramsVersion > MAX_PARAMS_DIRTY)
                paramsVersion = 1;
        }

    }

    #if !no_backend_docs
    /**
     * Sets a color uniform parameter.
     * @param name Uniform name in the shader
     * @param r Red component (0-1)
     * @param g Green component (0-1)
     * @param b Blue component (0-1)
     * @param a Alpha component (0-1)
     */
    #end
    public function setColor(name:String, r:Float, g:Float, b:Float, a:Float):Void {

        if (colorParams == null)
            colorParams = new Map();

        name = sanitizeUniformName(name);

        var unityColor = new unityengine.Color(r, g, b, a);
        if (!colorParams.exists(name) || colorParams.get(name) != unityColor) {
            colorParams.set(name, unityColor);
            paramsVersion++;
            if (paramsVersion > MAX_PARAMS_DIRTY)
                paramsVersion = 1;
        }

    }

    #if !no_backend_docs
    /**
     * Sets a 2D vector uniform parameter.
     * @param name Uniform name in the shader
     * @param x X component
     * @param y Y component
     */
    #end
    public function setVec2(name:String, x:Float, y:Float):Void {

        if (vec2Params == null)
            vec2Params = new Map();

        name = sanitizeUniformName(name);

        var unityVec2 = new unityengine.Vector2(x, y);
        if (!vec2Params.exists(name) || vec2Params.get(name) != unityVec2) {
            vec2Params.set(name, unityVec2);
            paramsVersion++;
            if (paramsVersion > MAX_PARAMS_DIRTY)
                paramsVersion = 1;
        }

    }

    #if !no_backend_docs
    /**
     * Sets a 3D vector uniform parameter.
     * @param name Uniform name in the shader
     * @param x X component
     * @param y Y component
     * @param z Z component
     */
    #end
    public function setVec3(name:String, x:Float, y:Float, z:Float):Void {

        if (vec3Params == null)
            vec3Params = new Map();

        name = sanitizeUniformName(name);

        var unityVec3 = new unityengine.Vector3(x, y, z);
        if (!vec3Params.exists(name) || vec3Params.get(name) != unityVec3) {
            vec3Params.set(name, unityVec3);
            paramsVersion++;
            if (paramsVersion > MAX_PARAMS_DIRTY)
                paramsVersion = 1;
        }

    }

    #if !no_backend_docs
    /**
     * Sets a 4D vector uniform parameter.
     * @param name Uniform name in the shader
     * @param x X component
     * @param y Y component
     * @param z Z component
     * @param w W component
     */
    #end
    public function setVec4(name:String, x:Float, y:Float, z:Float, w:Float):Void {

        if (vec4Params == null)
            vec4Params = new Map();

        name = sanitizeUniformName(name);

        var unityVec4 = new unityengine.Vector4(x, y, z, w);
        if (!vec4Params.exists(name) || vec4Params.get(name) != unityVec4) {
            vec4Params.set(name, unityVec4);
            paramsVersion++;
            if (paramsVersion > MAX_PARAMS_DIRTY)
                paramsVersion = 1;
        }

    }

    #if !no_backend_docs
    /**
     * Sets a float array uniform parameter.
     * @param name Uniform name in the shader
     * @param array Array of float values
     */
    #end
    public function setFloatArray(name:String, array:Array<Float>):Void {

        if (floatArrayParams == null)
            floatArrayParams = new Map();

        name = sanitizeUniformName(name);

        var nativeArray = new cs.NativeArray<Single>(array.length);
        for (i in 0...array.length) {
            nativeArray[i] = array.unsafeGet(i);
        }
        if (!floatArrayParams.exists(name) || floatArrayParams.get(name) != nativeArray) {
            floatArrayParams.set(name, nativeArray);
            paramsVersion++;
            if (paramsVersion > MAX_PARAMS_DIRTY)
                paramsVersion = 1;
        }

    }

    #if !no_backend_docs
    /**
     * Sets a texture uniform parameter.
     * @param name Uniform name in the shader
     * @param slot Texture unit slot (0-based)
     * @param texture Texture to bind
     */
    #end
    public function setTexture(name:String, slot:Int, texture:backend.Texture):Void {

        if (textureParams == null)
            textureParams = new Map();
        if (textureSlots == null)
            textureSlots = [];

        name = sanitizeUniformName(name);

        if (!textureParams.exists(name) || textureParams.get(name) != texture) {
            textureParams.set(name, texture);
            textureSlots[slot] = texture;
            paramsVersion++;
            if (paramsVersion > MAX_PARAMS_DIRTY)
                paramsVersion = 1;
        }

    }

    #if !no_backend_docs
    /**
     * Sets a 4x4 matrix uniform from a 2D transform.
     * Converts the 2D affine transform to a 4x4 matrix.
     * @param name Uniform name in the shader
     * @param transform 2D transform to convert
     */
    #end
    public function setMat4FromTransform(name:String, transform:ceramic.Transform):Void {

        if (mat4Params == null)
            mat4Params = new Map();

        name = sanitizeUniformName(name);

        untyped __cs__('UnityEngine.Matrix4x4 m = UnityEngine.Matrix4x4.identity');

        untyped __cs__('
        m[0] = (float){0}; m[4] = (float){1}; m[8] = 0f;  m[12] = (float){2};
        m[1] = (float){3}; m[5] = (float){4}; m[9] = 0f;  m[13] = (float){5};
        m[2] = 0f;  m[6] = 0f;  m[10] = 1f; m[14] = 0f;
        m[3] = 0f;  m[7] = 0f;  m[11] = 0f; m[15] = 1f;
        ', transform.a, transform.c, transform.tx, transform.b, transform.d, transform.ty);

        var unityMat4:unityengine.Matrix4x4 = untyped __cs__('m');

        if (!mat4Params.exists(name) || mat4Params.get(name) != unityMat4) {
            mat4Params.set(name, unityMat4);
            paramsVersion++;
            if (paramsVersion > MAX_PARAMS_DIRTY)
                paramsVersion = 1;
        }

    }

    #if !no_backend_docs
    /**
     * Sanitizes uniform names to avoid shader keyword conflicts.
     * Appends underscore to reserved words.
     * @param name Original uniform name
     * @return Sanitized name safe for shader use
     */
    #end
    function sanitizeUniformName(name:String):String {

        // That keyword is reserved
        // TODO: more exhaustive list of keywords? (and without allocations)
        if (name == 'offset' || name == 'lighten' || name == 'overlay')
            return name + '_';

        return name;

    }

    #if !no_backend_docs
    /**
     * String representation for debugging.
     * @return Shader path description
     */
    #end
    function toString() {

        return 'Shader($path)';

    }

}
