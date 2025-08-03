package backend;

import cs.NativeArray;
import unityengine.rendering.VertexAttributeDescriptor;

#if !no_backend_docs
/**
 * Represents a Unity material configuration for Ceramic rendering.
 * 
 * This class caches material state including textures, shaders, blend modes,
 * and stencil settings. It provides efficient comparison and updating of
 * Unity materials to minimize state changes during rendering.
 * 
 * Materials are reused when possible to reduce GPU state switches and
 * improve batching efficiency. The class tracks shader parameter versions
 * to only update Unity materials when parameters actually change.
 * 
 * @see backend.Materials Manages the pool of material instances
 * @see backend.Draw Uses materials for rendering operations
 */
#end
class MaterialData {

    #if !no_backend_docs
    /**
     * The underlying Unity Material object.
     * Stored as Dynamic to avoid direct Unity API dependencies.
     */
    #end
    public var material:Dynamic = null;

    #if !no_backend_docs
    /**
     * Array of textures used by this material.
     * Setting this property creates a defensive copy to prevent external modifications.
     */
    #end
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

    #if !no_backend_docs
    /**
     * The shader program used by this material.
     */
    #end
    public var shader:backend.Shader = null;

    #if !no_backend_docs
    /**
     * Source RGB blend factor for color blending.
     * Default: ONE (use source color as-is)
     */
    #end
    public var srcRgb:backend.BlendMode = ONE;

    #if !no_backend_docs
    /**
     * Destination RGB blend factor for color blending.
     * Default: ONE_MINUS_SRC_ALPHA (standard alpha blending)
     */
    #end
    public var dstRgb:backend.BlendMode = ONE_MINUS_SRC_ALPHA;

    #if !no_backend_docs
    /**
     * Source alpha blend factor.
     * Default: ONE (use source alpha as-is)
     */
    #end
    public var srcAlpha:backend.BlendMode = ONE;

    #if !no_backend_docs
    /**
     * Destination alpha blend factor.
     * Default: ONE_MINUS_SRC_ALPHA (standard alpha blending)
     */
    #end
    public var dstAlpha:backend.BlendMode = ONE_MINUS_SRC_ALPHA;

    #if !no_backend_docs
    /**
     * Stencil buffer state for masking operations.
     * Default: NONE (no stencil testing)
     */
    #end
    public var stencil:backend.StencilState = NONE;

    #if !no_backend_docs
    /**
     * Vertex attribute descriptors for the mesh using this material.
     * Defines the vertex buffer layout (position, UV, color, etc.)
     */
    #end
    public var vertexBufferAttributes:NativeArray<VertexAttributeDescriptor> = null;

    #if !no_backend_docs
    /**
     * Version number of shader parameters.
     * Used to detect when material properties need updating.
     */
    #end
    public var paramsVersion:Int = -1;

    #if !no_backend_docs
    /**
     * Creates a new MaterialData instance with default settings.
     */
    #end
    public function new() {}

    #if !no_backend_docs
    /**
     * Checks if this material matches the given configuration.
     * Used to determine if a material can be reused for rendering.
     * 
     * @param textures Array of textures to compare
     * @param shader Shader to compare
     * @param srcRgb Source RGB blend mode
     * @param dstRgb Destination RGB blend mode
     * @param srcAlpha Source alpha blend mode
     * @param dstAlpha Destination alpha blend mode
     * @param stencil Stencil state to compare
     * @return true if all parameters match this material's configuration
     */
    #end
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

    #if !no_backend_docs
    /**
     * Synchronizes shader parameters with the Unity material.
     * Only updates parameters if the shader's version has changed,
     * avoiding unnecessary GPU state changes.
     */
    #end
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
                for (textureName => val in shaderImpl.textureParams) {
                    final texture:TextureImpl = val;
                    if (texture.unityTexture != null) {
                        untyped __cs__('m.SetTexture({0}, (UnityEngine.Texture2D){1})', textureName, texture.unityTexture);
                    }
                    else if (texture.unityRenderTexture != null) {
                        untyped __cs__('m.SetTexture({0}, (UnityEngine.RenderTexture){1})', textureName, texture.unityRenderTexture);
                    }
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

    #if !no_backend_docs
    /**
     * Converts Ceramic blend mode to Unity's blend mode enum.
     * 
     * @param blending The Ceramic blend mode to convert
     * @return Corresponding Unity blend mode
     */
    #end
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