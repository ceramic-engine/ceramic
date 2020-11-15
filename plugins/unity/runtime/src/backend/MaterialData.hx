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

    public static function blendingToUnityBlending(blending:backend.BlendMode):unityengine.rendering.BlendMode {

        return switch blending {
            case ZERO:
                unityengine.rendering.BlendMode.Zero;
            case ONE:
                unityengine.rendering.BlendMode.One;
            case SRC_COLOR:
                unityengine.rendering.BlendMode.SrcColor;
            case ONE_MINUS_SRC_COLOR:
                unityengine.rendering.BlendMode.OneMinusSrcColor;
            case SRC_ALPHA:
                unityengine.rendering.BlendMode.SrcAlpha;
            case ONE_MINUS_SRC_ALPHA:
                unityengine.rendering.BlendMode.OneMinusSrcAlpha;
            case DST_ALPHA:
                unityengine.rendering.BlendMode.DstAlpha;
            case ONE_MINUS_DST_ALPHA:
                unityengine.rendering.BlendMode.OneMinusDstAlpha;
            case DST_COLOR:
                unityengine.rendering.BlendMode.DstColor;
            case ONE_MINUS_DST_COLOR:
                unityengine.rendering.BlendMode.OneMinusDstColor;
            case SRC_ALPHA_SATURATE:
                unityengine.rendering.BlendMode.SrcAlphaSaturate;
        }

    }

}