package backend;

import unityengine.rendering.VertexAttributeDescriptor;
import unityengine.rendering.VertexAttribute;
import unityengine.rendering.VertexAttributeFormat;
import cs.NativeArray;

using ceramic.Extensions;

class Materials {

    var repository:Array<MaterialData>;

    public function new() {

        repository = [];

    }

    /**
     * Provide a MaterialData object that matches the given params.
     * If such material doesn't exist yet, creates and instance
     */
    public function get(
        texture:backend.TextureImpl,
        shader:backend.Shader,
        srcRgb:backend.BlendMode,
        dstRgb:backend.BlendMode,
        srcAlpha:backend.BlendMode,
        dstAlpha:backend.BlendMode,
        stencil:backend.StencilState
        ):MaterialData {

        for (i in 0...repository.length) {
            var materialData = repository.unsafeGet(i);

            if (materialData.matches(texture, shader, srcRgb, dstRgb, srcAlpha, dstAlpha, stencil)) {
                materialData.syncShaderParams();
                return materialData;
            }
        }

        // Nothing found, create a new one
        var materialData = new MaterialData();
        materialData.texture = texture;
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

        if (texture != null) {
            if (texture.unityTexture != null) {
                untyped __cs__('material.mainTexture = (UnityEngine.Texture2D){0}', texture.unityTexture);
            }
            else if (texture.unityRenderTexture != null) {
                untyped __cs__('material.mainTexture = (UnityEngine.RenderTexture){0}', texture.unityRenderTexture);
            }
        }
        else {
            untyped __cs__('material.mainTexture = {0}', null);
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

        var attributesSize = ceramic.App.app.backend.shaders.customFloatAttributesSize(shader);
        var attributesEntries = Std.int(Math.ceil(attributesSize / 2));

        var vertexBufferAttributes:NativeArray<VertexAttributeDescriptor> = new NativeArray(3 + attributesEntries);
        vertexBufferAttributes[0] = new VertexAttributeDescriptor(
            VertexAttribute.Position, VertexAttributeFormat.Float32, 3, 0
        );
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

        // TODO handle shader custom attributes

        return materialData;

    }

}