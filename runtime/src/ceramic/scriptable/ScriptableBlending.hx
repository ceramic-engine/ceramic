package ceramic.scriptable;

/**
 * Scriptable wrapper for Blending enum to expose blending modes to scripts.
 * 
 * This class provides constants representing different pixel blending modes
 * that can be used when rendering visuals. In scripts, this type is exposed
 * as `Blending` (without the Scriptable prefix).
 * 
 * Blending modes control how pixels from a source (the visual being drawn)
 * are combined with pixels from the destination (what's already on screen).
 * 
 * ## Usage in Scripts
 * 
 * ```hscript
 * // Set a visual to use additive blending
 * myVisual.blending = Blending.ADD;
 * 
 * // Reset to default blending
 * myVisual.blending = Blending.AUTO;
 * ```
 * 
 * ## Available Modes
 * 
 * - **AUTO**: Default blending, automatically chosen by Ceramic
 * - **PREMULTIPLIED_ALPHA**: Standard premultiplied alpha blending
 * - **ADD**: Additive blending (brightens the destination)
 * - **ALPHA**: Traditional alpha blending (rarely needed)
 * - **SET**: Replace destination pixels without blending
 * - **RENDER_TO_TEXTURE**: Special mode for render textures
 * 
 * @see ceramic.Blending The actual implementation
 * @see ceramic.Visual For setting blending on visuals
 */
class ScriptableBlending {
    
    /**
     * Automatic/default blending in ceramic. Internally, this translates to premultiplied alpha blending as textures
     * are already transformed for this blending at asset copy phase, except in some situations (render to texture) where
     * ceramic may use some more specific blendings as needed.
     */
    public static var AUTO:Int = 0;
    
    /**
     * Explicit premultiplied alpha blending
     */
    public static var PREMULTIPLIED_ALPHA:Int = 1;
    
    /**
     * Additive blending
     */
    public static var ADD:Int = 2;

    /**
     * Set blending
     */
    public static var SET:Int = 4;

    /**
     * Blending used by ceramic when rendering to texture.
     */
    public static var RENDER_TO_TEXTURE:Int = 5;
    
    /**
     * Traditional alpha blending. This should only be used on very specific cases. Used instead of `NORMAL` blending
     * when the visual is drawing a RenderTexture.
     */
    public static var ALPHA:Int = 3;

}
