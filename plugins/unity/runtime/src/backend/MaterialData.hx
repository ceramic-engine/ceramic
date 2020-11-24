package backend;

import unityengine.rendering.VertexAttributeDescriptor;
import cs.NativeArray;

class MaterialData {
    
    public var material:Dynamic = null;

    public var textures(default, set):NativeArray<backend.Texture> = null;
    inline function set_textures(textures:NativeArray<backend.Texture>):NativeArray<backend.Texture> {
        if (textures != null) {
            var copy:NativeArray<backend.Texture> = new NativeArray(textures.length);
            for (i in 0...textures.length) {
                copy[i] = textures[i];
            }
            this.textures = copy;
        }
        else {
            this.textures = null;
        }
        return this.textures;
    }

    public var shader:backend.Shader = null;

    public var srcRgb:backend.BlendMode = ONE;

    public var dstRgb:backend.BlendMode = ONE_MINUS_SRC_ALPHA;

    public var srcAlpha:backend.BlendMode = ONE;

    public var dstAlpha:backend.BlendMode = ONE_MINUS_SRC_ALPHA;

    public var stencil:backend.StencilState = NONE;

    public var vertexBufferAttributes:NativeArray<VertexAttributeDescriptor> = null;

    public var paramsVersion:Int = -1;

    public function new() {}

    inline public function matches(
        textures:NativeArray<backend.Texture>,
        shader:backend.Shader,
        srcRgb:backend.BlendMode,
        dstRgb:backend.BlendMode,
        srcAlpha:backend.BlendMode,
        dstAlpha:backend.BlendMode,
        stencil:backend.StencilState
        ):Bool {
        
        return this.texturesEqualTextures(textures)
            && this.shader == shader
            && this.srcRgb == srcRgb
            && this.dstRgb == dstRgb
            && this.srcAlpha == srcAlpha
            && this.dstAlpha == dstAlpha
            && this.stencil == stencil;
    }

    inline public function texturesEqualTextures(textures:NativeArray<backend.Texture>):Bool {

        var equals = false;

        if (this.textures != null && textures != null) {
            if (this.textures.length == textures.length) {
                equals = true;
                for (i in 0...this.textures.length) {
                    if (this.textures[i] != textures[i]) {
                        equals = false;
                        break;
                    }
                }
            }
        }
        else {
            equals = (this.textures == textures);
        }

        return equals;

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

            // Only needed to avoid compiled code to return null in function and let C# compiler screem
            default:
                unityengine.rendering.BlendMode.Zero;
        }

    }

}