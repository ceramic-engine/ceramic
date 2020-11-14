package backend;

using ceramic.Extensions;

class ShaderImpl {

    public var path:String = null;

    public var unityShader:Dynamic = null;

    public var customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute> = null;

    var paramsDirty:Bool = false;

    var intParams:Map<String,Int> = null;

    var floatParams:Map<String,Float> = null;

    var colorParams:Map<String,unityengine.Color> = null;

    var vec2Params:Map<String,unityengine.Vector2> = null;

    var vec3Params:Map<String,unityengine.Vector3> = null;

    var vec4Params:Map<String,unityengine.Vector4> = null;

    var floatArrayParams:Map<String,cs.NativeArray<Float>> = null;

    var textureParams:Map<String,backend.Texture> = null;

    var mat4Params:Map<String,Dynamic> = null;

    public function new(unityShader:Dynamic, ?customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>) {

        this.unityShader = unityShader;
        this.customAttributes = customAttributes;

    }

    public static function clone(fromShader:ShaderImpl):ShaderImpl {

        var newShader = new ShaderImpl(fromShader.unityShader, fromShader.customAttributes);
        newShader.path = fromShader.path;

        return newShader;

    }

    public function setInt(name:String, value:Int):Void {
        
        if (intParams == null)
            intParams = new Map();

        if (!intParams.exists(name) || intParams.get(name) != value) {
            intParams.set(name, value);
            paramsDirty = true;
        }

    }

    public function setFloat(name:String, value:Float):Void {
        
        if (floatParams == null)
            floatParams = new Map();
        
        if (!floatParams.exists(name) || floatParams.get(name) != value) {
            floatParams.set(name, value);
            paramsDirty = true;
        }

    }

    public function setColor(name:String, r:Float, g:Float, b:Float, a:Float):Void {
        
        if (colorParams == null)
            colorParams = new Map();
        
        var unityColor = new unityengine.Color(r, g, b, a);
        if (!colorParams.exists(name) || colorParams.get(name) != unityColor) {
            colorParams.set(name, unityColor);
            paramsDirty = true;
        }

    }

    public function setVec2(name:String, x:Float, y:Float):Void {
        
        if (vec2Params == null)
            vec2Params = new Map();
        
        var unityVec2 = new unityengine.Vector2(x, y);
        if (!vec2Params.exists(name) || vec2Params.get(name) != unityVec2) {
            vec2Params.set(name, unityVec2);
            paramsDirty = true;
        }

    }

    public function setVec3(name:String, x:Float, y:Float, z:Float):Void {
        
        if (vec3Params == null)
            vec3Params = new Map();
        
        var unityVec3 = new unityengine.Vector3(x, y, z);
        if (!vec3Params.exists(name) || vec3Params.get(name) != unityVec3) {
            vec3Params.set(name, unityVec3);
            paramsDirty = true;
        }

    }

    public function setVec4(name:String, x:Float, y:Float, z:Float, w:Float):Void {
        
        if (vec4Params == null)
            vec4Params = new Map();
        
        var unityVec4 = new unityengine.Vector4(x, y, z, w);
        if (!vec4Params.exists(name) || vec4Params.get(name) != unityVec4) {
            vec4Params.set(name, unityVec4);
            paramsDirty = true;
        }

    }

    public function setFloatArray(name:String, array:Array<Float>):Void {
        
        if (floatArrayParams == null)
            floatArrayParams = new Map();
        
        var nativeArray = new cs.NativeArray(array.length);
        for (i in 0...array.length) {
            nativeArray[i] = array.unsafeGet(i);
        }
        if (!floatArrayParams.exists(name) || floatArrayParams.get(name) != nativeArray) {
            floatArrayParams.set(name, nativeArray);
            paramsDirty = true;
        }

    }

    public function setTexture(name:String, texture:backend.Texture):Void {
        
        if (textureParams == null)
            textureParams = new Map();
        
        if (!textureParams.exists(name) || textureParams.get(name) != texture) {
            textureParams.set(name, texture);
            paramsDirty = true;
        }

    }

    public function setMat4FromTransform(name:String, transform:ceramic.Transform):Void {
        
        if (mat4Params == null)
            mat4Params = new Map();
        
        untyped __cs__('UnityEngine.Matrix4x4 m = UnityEngine.Matrix4x4.identity');

        untyped __cs__('
        m[0] = (float){0}; m[4] = (float){1}; m[8] = 0f;  m[12] = (float){2};
        m[1] = (float){3}; m[5] = (float){4}; m[9] = 0f;  m[13] = (float){5};
        m[2] = 0f;  m[6] = 0f;  m[10] = 1f; m[14] = 0f;
        m[3] = 0f;  m[7] = 0f;  m[11] = 0f; m[15] = 1f;
        ', transform.a, transform.c, transform.tx, transform.b, transform.d, transform.ty);

        var unityMat4:Dynamic = untyped __cs__('m');
        
        if (!mat4Params.exists(name) || mat4Params.get(name) != unityMat4) {
            mat4Params.set(name, unityMat4);
            paramsDirty = true;
        }

    }

}
