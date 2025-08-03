package backend;

import ceramic.Shortcuts.*;
import cs.NativeArray;
import unityengine.rendering.VertexAttribute;
import unityengine.rendering.VertexAttributeDescriptor;
import unityengine.rendering.VertexAttributeFormat;

using ceramic.Extensions;

#if !no_backend_docs
/**
 * Manages a pool of Unity materials for efficient rendering.
 * 
 * This class implements a material caching system that reuses Unity Material
 * objects when possible. By avoiding material creation and state changes,
 * it significantly improves rendering performance and reduces draw calls.
 * 
 * Materials are matched based on:
 * - Textures used
 * - Shader program
 * - Blend modes (source and destination for RGB and alpha)
 * - Stencil state
 * 
 * The system automatically creates appropriate vertex layouts based on
 * shader requirements and manages Unity-specific material properties.
 * 
 * @see MaterialData The material configuration class
 * @see backend.Draw Uses this system for batch rendering
 */
#end
class Materials {

    #if !no_backend_docs
    /**
     * Repository of cached material instances.
     * Materials are reused when their configuration matches.
     */
    #end
    var repository:Array<MaterialData>;

    #if !no_backend_docs
    /**
     * Creates a new Materials manager instance.
     */
    #end
    public function new() {

        repository = [];

    }

    #if !no_backend_docs
    /**
     * Provide a MaterialData object that matches the given params.
     * If such material doesn't exist yet, creates and instance
     */
    #end
    public function get(
        textures:NativeArray<backend.Texture>,
        shader:backend.Shader,
        srcRgb:backend.BlendMode,
        dstRgb:backend.BlendMode,
        srcAlpha:backend.BlendMode,
        dstAlpha:backend.BlendMode,
        stencil:backend.StencilState
        ):MaterialData {

        for (i in 0...repository.length) {
            var materialData = repository.unsafeGet(i);

            if (materialData.matches(textures, shader, srcRgb, dstRgb, srcAlpha, dstAlpha, stencil)) {
                materialData.syncShaderParams();
                return materialData;
            }
        }

        // Nothing found, create a new one
        var materialData = new MaterialData();
        materialData.textures = textures;
        materialData.shader = shader;
        materialData.srcRgb = srcRgb;
        materialData.dstRgb = dstRgb;
        materialData.srcAlpha = srcAlpha;
        materialData.dstAlpha = dstAlpha;
        materialData.stencil = stencil;

        var shaderImpl:ShaderImpl = shader;

        untyped __cs__('UnityEngine.Material material = new UnityEngine.Material((UnityEngine.Shader){0})', shaderImpl.unityShader);

        materialData.material = untyped __cs__('material');
        repository.push(materialData);

        var mainTexture:TextureImpl = textures[0];
        if (mainTexture != null) {
            if (mainTexture.unityTexture != null) {
                untyped __cs__('material.mainTexture = (UnityEngine.Texture2D){0}', mainTexture.unityTexture);
            }
            else if (mainTexture.unityRenderTexture != null) {
                untyped __cs__('material.mainTexture = (UnityEngine.RenderTexture){0}', mainTexture.unityRenderTexture);
            }
        }
        else {
            untyped __cs__('material.mainTexture = {0}', null);
        }

        for (i in 1...textures.length) {
            var texture:TextureImpl = textures[i];
            if (texture != null) {
                var textureName = '_Tex' + i;
                if (texture.unityTexture != null) {
                    untyped __cs__('material.SetTexture({0}, (UnityEngine.Texture2D){1})', textureName, texture.unityTexture);
                }
                else if (texture.unityRenderTexture != null) {
                    untyped __cs__('material.SetTexture({0}, (UnityEngine.RenderTexture){1})', textureName, texture.unityRenderTexture);
                }
            }
        }

        materialData.syncShaderParams();

        untyped __cs__('material.SetInt("_SrcBlendRgb", (int){0})', MaterialData.blendingToUnityBlending(materialData.srcRgb));
        untyped __cs__('material.SetInt("_DstBlendRgb", (int){0})', MaterialData.blendingToUnityBlending(materialData.dstRgb));
        untyped __cs__('material.SetInt("_SrcBlendAlpha", (int){0})', MaterialData.blendingToUnityBlending(materialData.srcAlpha));
        untyped __cs__('material.SetInt("_DstBlendAlpha", (int){0})', MaterialData.blendingToUnityBlending(materialData.dstAlpha));

        switch stencil {
            case NONE:
                untyped __cs__('material.SetInt("_StencilRef", (int){0})', 1);
                untyped __cs__('material.SetInt("_StencilOp", (int){0})', unityengine.rendering.StencilOp.Keep);
                untyped __cs__('material.SetInt("_StencilComp", (int){0})', unityengine.rendering.CompareFunction.Always);
            case TEST:
                untyped __cs__('material.SetInt("_StencilRef", (int){0})', 1);
                untyped __cs__('material.SetInt("_StencilOp", (int){0})', unityengine.rendering.StencilOp.Keep);
                untyped __cs__('material.SetInt("_StencilComp", (int){0})', unityengine.rendering.CompareFunction.Equal);
            case WRITE:
                untyped __cs__('material.SetInt("_StencilRef", (int){0})', 1);
                untyped __cs__('material.SetInt("_StencilOp", (int){0})', unityengine.rendering.StencilOp.Replace);
                untyped __cs__('material.SetInt("_StencilComp", (int){0})', unityengine.rendering.CompareFunction.Always);
                untyped __cs__('material.SetInt("_StencilReadMask", (int){0})', 0xFF);
                untyped __cs__('material.SetInt("_StencilWriteMask", (int){0})', 0xFF);
            case CLEAR:
                untyped __cs__('material.SetInt("_StencilRef", (int){0})', 0);
                untyped __cs__('material.SetInt("_StencilOp", (int){0})', unityengine.rendering.StencilOp.Replace);
                untyped __cs__('material.SetInt("_StencilComp", (int){0})', unityengine.rendering.CompareFunction.Always);
                untyped __cs__('material.SetInt("_StencilReadMask", (int){0})', 0xFF);
                untyped __cs__('material.SetInt("_StencilWriteMask", (int){0})', 0xFF);
        }

        var backendShaders = ceramic.App.app.backend.shaders;

        var attributesSize = backendShaders.customFloatAttributesSize(shader);
        var attributesEntries = Std.int(Math.ceil(attributesSize / 2));

        var canBatchMultipleTextures = backendShaders.canBatchWithMultipleTextures(shader);

        var vertexBufferAttributes:NativeArray<VertexAttributeDescriptor> = new NativeArray(3 + attributesEntries);
        if (canBatchMultipleTextures) {
            vertexBufferAttributes[0] = new VertexAttributeDescriptor(
                VertexAttribute.Position, VertexAttributeFormat.Float32, 4, 0
            );
        }
        else {
            vertexBufferAttributes[0] = new VertexAttributeDescriptor(
                VertexAttribute.Position, VertexAttributeFormat.Float32, 3, 0
            );
        }
        vertexBufferAttributes[1] = new VertexAttributeDescriptor(
            VertexAttribute.Color, VertexAttributeFormat.Float32, 4, 0
        );
        vertexBufferAttributes[2] = new VertexAttributeDescriptor(
            VertexAttribute.TexCoord0, VertexAttributeFormat.Float32, 2, 0
        );
        for (i in 0...attributesEntries) {
            switch i {
                case 0:
                    vertexBufferAttributes[3] = new VertexAttributeDescriptor(
                        VertexAttribute.TexCoord1, VertexAttributeFormat.Float32, 2, 0
                    );
                case 1:
                    vertexBufferAttributes[4] = new VertexAttributeDescriptor(
                        VertexAttribute.TexCoord2, VertexAttributeFormat.Float32, 2, 0
                    );
                case 2:
                    vertexBufferAttributes[5] = new VertexAttributeDescriptor(
                        VertexAttribute.TexCoord3, VertexAttributeFormat.Float32, 2, 0
                    );
                case 3:
                    vertexBufferAttributes[6] = new VertexAttributeDescriptor(
                        VertexAttribute.TexCoord4, VertexAttributeFormat.Float32, 2, 0
                    );
                case 4:
                    vertexBufferAttributes[4] = new VertexAttributeDescriptor(
                        VertexAttribute.TexCoord5, VertexAttributeFormat.Float32, 2, 0
                    );
                case 5:
                    vertexBufferAttributes[5] = new VertexAttributeDescriptor(
                        VertexAttribute.TexCoord6, VertexAttributeFormat.Float32, 2, 0
                    );
                case 6:
                    vertexBufferAttributes[6] = new VertexAttributeDescriptor(
                        VertexAttribute.TexCoord7, VertexAttributeFormat.Float32, 2, 0
                    );
                default:
                    throw 'Too many custom float attributes in shader: $shader';
            }
        }
        materialData.vertexBufferAttributes = vertexBufferAttributes;

        return materialData;

    }

}