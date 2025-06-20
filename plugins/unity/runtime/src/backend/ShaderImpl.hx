package backend;

using ceramic.Extensions;

@:allow(backend.MaterialData)
class ShaderImpl {

    static final MAX_PARAMS_DIRTY:Int = 999999999;

    public var path:String = null;

    public var unityShader:Dynamic = null;

    public var customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute> = null;

    public var isBatchingMultiTexture:Bool = false;

    var paramsVersion:Int = 0;

    var intParams:Map<String,Int> = null;

    var floatParams:Map<String,Float> = null;

    var colorParams:Map<String,unityengine.Color> = null;

    var vec2Params:Map<String,unityengine.Vector2> = null;

    var vec3Params:Map<String,unityengine.Vector3> = null;

    var vec4Params:Map<String,unityengine.Vector4> = null;

    var floatArrayParams:Map<String,cs.NativeArray<Single>> = null;

    var textureParams:Map<String,backend.Texture> = null;

    var textureSlots:Array<backend.Texture> = null;

    var mat4Params:Map<String,unityengine.Matrix4x4> = null;

    public function new(unityShader:Dynamic, ?customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>) {

        this.unityShader = unityShader;
        this.customAttributes = customAttributes;

    }

    public static function clone(fromShader:ShaderImpl):ShaderImpl {

        var newShader = new ShaderImpl(fromShader.unityShader, fromShader.customAttributes);
        newShader.path = fromShader.path;
        newShader.isBatchingMultiTexture = fromShader.isBatchingMultiTexture;

        return newShader;

    }

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

    function sanitizeUniformName(name:String):String {

        // That keyword is reserved
        // TODO: more exhaustive list of keywords? (and without allocations)
        if (name == 'offset' || name == 'lighten' || name == 'overlay')
            return name + '_';

        return name;

    }

    function toString() {

        return 'Shader($path)';

    }

}
