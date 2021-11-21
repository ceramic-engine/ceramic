package ceramic;

@:enum abstract Blending(Int) from Int to Int {

    /**
     * Automatic/default blending in ceramic. Internally, this translates to premultiplied alpha blending as textures
     * are already transformed for this blending at asset copy phase, except in some situations (render to texture) where
     * ceramic may use some more specific blendings as needed.
     */
    var AUTO = 0;

    /**
     * Explicit premultiplied alpha blending
     */
    var PREMULTIPLIED_ALPHA = 1;

    /**
     * Additive blending
     */
    var ADD = 2;

    /**
     * Set blending
     */
    var SET = 4;

    /**
     * Blending used by ceramic when rendering to texture.
     */
    var RENDER_TO_TEXTURE = 5;

    /**
     * Blending used by ceramic when rendering to texture.
     */
    var RENDER_TO_TEXTURE_ALPHA = 6;

    /**
     * Traditional alpha blending. This should only be used on very specific cases. Used instead of `NORMAL` blending
     * when the visual is drawing a RenderTexture.
     */
    var ALPHA = 3;

}
