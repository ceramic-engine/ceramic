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
        dstAlpha:backend.BlendMode
        ):MaterialData {

        for (i in 0...repository.length) {
            var materialData = repository.unsafeGet(i);

            if (materialData.matches(texture, shader, srcRgb, dstRgb, srcAlpha, dstAlpha)) {
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

        untyped __cs__('UnityEngine.Material material = new UnityEngine.Material(UnityEngine.Shader.Find("Sprites/Default"))');
        
        materialData.material = untyped __cs__('material');
        repository.push(materialData);

        if (texture != null) {
            untyped __cs__('material.mainTexture = {1}', material, texture.unityTexture);
        }
        else {
            untyped __cs__('material.mainTexture = {1}', material, null);
        }

        return materialData;

    }

}