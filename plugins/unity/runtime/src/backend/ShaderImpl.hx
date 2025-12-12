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
     * Cache for suffixed uniform names (name -> name_).
     * Avoids string allocation on every setter call.
     */
    #end
    static var suffixCache:Map<String, String> = new Map();

    #if !no_backend_docs
    /**
     * Cache for array-suffixed uniform names (name -> name_arr_).
     * Used for mat2/mat3 uniforms which are sent as float arrays.
     */
    #end
    static var arrSuffixCache:Map<String, String> = new Map();

    #if !no_backend_docs
    /**
     * Gets the suffixed name from cache, or creates and caches it.
     * @param name Original uniform name
     * @return Suffixed name (name_)
     */
    #end
    static function getSuffixedName(name:String):String {
        var cached = suffixCache.get(name);
        if (cached == null) {
            cached = name + "_";
            suffixCache.set(name, cached);
        }
        return cached;
    }

    #if !no_backend_docs
    /**
     * Gets the array-suffixed name from cache, or creates and caches it.
     * @param name Original uniform name
     * @return Array-suffixed name (name_arr_)
     */
    #end
    static function getArrSuffixedName(name:String):String {
        var cached = arrSuffixCache.get(name);
        if (cached == null) {
            cached = name + "_arr_";
            arrSuffixCache.set(name, cached);
        }
        return cached;
    }

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
     * 2x2 matrix uniform parameters (stored as float arrays).
     */
    #end
    var mat2Params:Map<String,cs.NativeArray<Single>> = null;

    #if !no_backend_docs
    /**
     * 3x3 matrix uniform parameters (stored as float arrays).
     */
    #end
    var mat3Params:Map<String,cs.NativeArray<Single>> = null;

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

        name = getSuffixedName(name);

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

        name = getSuffixedName(name);

        if (!floatParams.exists(name) || floatParams.get(name) != value) {
            floatParams.set(name, value);
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

        name = getSuffixedName(name);

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

        name = getSuffixedName(name);

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

        name = getSuffixedName(name);

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

        name = getSuffixedName(name);

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

        name = getSuffixedName(name);

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
     * Sets a 2x2 matrix uniform value (column-major order).
     * @param name Uniform name in the shader
     * @param m00 Column 0, row 0
     * @param m10 Column 0, row 1
     * @param m01 Column 1, row 0
     * @param m11 Column 1, row 1
     */
    #end
    public function setMat2(name:String, m00:Float, m10:Float, m01:Float, m11:Float):Void {

        if (mat2Params == null)
            mat2Params = new Map();

        name = getArrSuffixedName(name);

        var arr:cs.NativeArray<Single> = mat2Params.get(name);
        if (arr == null) {
            arr = new cs.NativeArray<Single>(4);
            mat2Params.set(name, arr);
        }

        arr[0] = m00;
        arr[1] = m10;
        arr[2] = m01;
        arr[3] = m11;

        paramsVersion++;
        if (paramsVersion > MAX_PARAMS_DIRTY)
            paramsVersion = 1;

    }

    #if !no_backend_docs
    /**
     * Sets a 3x3 matrix uniform value (column-major order).
     * @param name Uniform name in the shader
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
    public function setMat3(name:String, m00:Float, m10:Float, m20:Float, m01:Float, m11:Float, m21:Float, m02:Float, m12:Float, m22:Float):Void {

        if (mat3Params == null)
            mat3Params = new Map();

        name = getArrSuffixedName(name);

        var arr:cs.NativeArray<Single> = mat3Params.get(name);
        if (arr == null) {
            arr = new cs.NativeArray<Single>(9);
            mat3Params.set(name, arr);
        }

        arr[0] = m00;
        arr[1] = m10;
        arr[2] = m20;
        arr[3] = m01;
        arr[4] = m11;
        arr[5] = m21;
        arr[6] = m02;
        arr[7] = m12;
        arr[8] = m22;

        paramsVersion++;
        if (paramsVersion > MAX_PARAMS_DIRTY)
            paramsVersion = 1;

    }

    #if !no_backend_docs
    /**
     * Sets a 4x4 matrix uniform value (column-major order).
     * @param name Uniform name in the shader
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
    public function setMat4(name:String, m00:Float, m10:Float, m20:Float, m30:Float, m01:Float, m11:Float, m21:Float, m31:Float, m02:Float, m12:Float, m22:Float, m32:Float, m03:Float, m13:Float, m23:Float, m33:Float):Void {

        if (mat4Params == null)
            mat4Params = new Map();

        name = getSuffixedName(name);

        untyped __cs__('UnityEngine.Matrix4x4 m = UnityEngine.Matrix4x4.identity');

        untyped __cs__('
        m[0] = (float){0};  m[4] = (float){4};  m[8] = (float){8};   m[12] = (float){12};
        m[1] = (float){1};  m[5] = (float){5};  m[9] = (float){9};   m[13] = (float){13};
        m[2] = (float){2};  m[6] = (float){6};  m[10] = (float){10}; m[14] = (float){14};
        m[3] = (float){3};  m[7] = (float){7};  m[11] = (float){11}; m[15] = (float){15};
        ', m00, m10, m20, m30, m01, m11, m21, m31, m02, m12, m22, m32, m03, m13, m23, m33);

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
     * String representation for debugging.
     * @return Shader path description
     */
    #end
    function toString() {

        return 'Shader($path)';

    }

}
