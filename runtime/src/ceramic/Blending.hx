package ceramic;

@:enum abstract Blending(Int) from Int to Int {
    
    /** Default blending in ceramic. Internally, this translates to premultiplied alpha blending as textures
        are automatically converted to their premultiplied-alpha versions at build time. */
    var NORMAL = 0;
    
    /** Forced premultiplied alpha blending */
    var PREMULTIPLIED_ALPHA = 1;
    
    /** Additive blending */
    var ADD = 2;

    /** Set blending */
    var SET = 4;
    
    /** Traditional alpha blending. This should only be used on very specific cases. Used instead of `NORMAL` blending
        when the visual is drawing a RenderTexture. */
    var ALPHA = 3;

} //Blending
