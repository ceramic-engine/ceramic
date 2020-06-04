package ceramic.scriptable;

class ScriptableBlending {
    
    /** Automatic/default blending in ceramic. Internally, this translates to premultiplied alpha blending as textures
        are already transformed for this blending at asset copy phase, except in some situations (render to texture) where
        ceramic may use some more specific blendings as needed. */
    public static var AUTO:Int = 0;
    
    /** Explicit premultiplied alpha blending */
    public static var PREMULTIPLIED_ALPHA:Int = 1;
    
    /** Additive blending */
    public static var ADD:Int = 2;

    /** Set blending */
    public static var SET:Int = 4;

    /** Blending used by ceramic when rendering to texture. */
    public static var RENDER_TO_TEXTURE:Int = 5;
    
    /** Traditional alpha blending. This should only be used on very specific cases. Used instead of `NORMAL` blending
        when the visual is drawing a RenderTexture. */
    public static var ALPHA:Int = 3;

}
