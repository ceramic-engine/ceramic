package backend;

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
        texture:backend.Texture,
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
            untyped __cs__('material.mainTexture = {0}', texture.unityTexture);
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

        return materialData;

    }

}