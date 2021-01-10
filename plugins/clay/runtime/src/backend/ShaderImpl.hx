package backend;

import clay.graphics.Uniforms;

class ShaderImpl extends clay.graphics.Shader {

    public var customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute> = null;

    public var isBatchingMultiTexture:Bool = false;

    public function new() {

        super();

    }

    public function clone():ShaderImpl {

        // This might be optimized later, so that we don't need to recompile cloned shader code
        var shader = new ShaderImpl();
        shader.vertSource = vertSource;
        shader.fragSource = fragSource;
        shader.customAttributes = customAttributes;
        shader.isBatchingMultiTexture = isBatchingMultiTexture;
        shader.attributes = attributes;
        shader.textures = textures;
        shader.init();
        return shader;

    }

}