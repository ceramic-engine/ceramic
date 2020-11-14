package backend;

class MaterialData {
    
    public var material:Dynamic = null;

    public var texture:backend.Texture = null;

    public var shader:backend.Shader = null;

    public var srcRgb:backend.BlendMode = ONE;

    public var dstRgb:backend.BlendMode = ONE_MINUS_SRC_ALPHA;

    public var srcAlpha:backend.BlendMode = ONE;

    public var dstAlpha:backend.BlendMode = ONE_MINUS_SRC_ALPHA;

    public var paramsVersion:Int = -1;

    public function new() {}

    inline public function matches(
        texture:backend.Texture,
        shader:backend.Shader,
        srcRgb:backend.BlendMode,
        dstRgb:backend.BlendMode,
        srcAlpha:backend.BlendMode,
        dstAlpha:backend.BlendMode
        ):Bool {
        
        return this.texture == texture
            && this.shader == shader
            && this.srcRgb == srcRgb
            && this.dstRgb == dstRgb
            && this.srcAlpha == srcAlpha
            && this.dstAlpha == dstAlpha;
    }

    inline public function syncShaderParams():Void {

        var shaderImpl:ShaderImpl = shader;
        if (paramsVersion != shaderImpl.paramsVersion) {

            untyped __cs__('UnityEngine.Material m = (UnityEngine.Material){0}', material);

            if (shaderImpl.intParams != null) {
                for (name => val in shaderImpl.intParams) {
                    untyped __cs__('m.SetInt({0}, {1})', name, val);
                }
            }

            if (shaderImpl.floatParams != null) {
                for (name => val in shaderImpl.floatParams) {
                    untyped __cs__('m.SetFloat({0}, (float){1})', name, val);
                }
            }

            if (shaderImpl.colorParams != null) {
                for (name => val in shaderImpl.colorParams) {
                    untyped __cs__('m.SetColor({0}, {1})', name, val);
                }
            }

            if (shaderImpl.vec2Params != null) {
                for (name => val in shaderImpl.vec2Params) {
                    untyped __cs__('m.SetVector({0}, {1})', name, val);
                }
            }

            if (shaderImpl.vec3Params != null) {
                for (name => val in shaderImpl.vec3Params) {
                    untyped __cs__('m.SetVector({0}, {1})', name, val);
                }
            }

            if (shaderImpl.vec4Params != null) {
                for (name => val in shaderImpl.vec4Params) {
                    untyped __cs__('m.SetVector({0}, {1})', name, val);
                }
            }

            if (shaderImpl.floatArrayParams != null) {
                for (name => val in shaderImpl.floatArrayParams) {
                    untyped __cs__('m.SetFloatArray({0}, {1})', name, val);
                }
            }

            if (shaderImpl.textureParams != null) {
                for (name => val in shaderImpl.textureParams) {
                    untyped __cs__('m.SetTexture({0}, {1})', name, (val:TextureImpl).unityTexture);
                }
            }

            if (shaderImpl.mat4Params != null) {
                for (name => val in shaderImpl.mat4Params) {
                    untyped __cs__('m.SetMatrix({0}, (UnityEngine.Matrix4x4){1})', name, val);
                }
            }

            paramsVersion = shaderImpl.paramsVersion;

        }

    }

}