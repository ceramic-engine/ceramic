package backend;

class MaterialData {
    
    public var material:Dynamic = null;

    public var texture:backend.Texture = null;

    public var shader:backend.Shader = null;

    public var srcRgb:backend.BlendMode = ONE;

    public var dstRgb:backend.BlendMode = ONE_MINUS_SRC_ALPHA;

    public var srcAlpha:backend.BlendMode = ONE;

    public var dstAlpha:backend.BlendMode = ONE_MINUS_SRC_ALPHA;

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

}