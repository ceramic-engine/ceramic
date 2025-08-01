package ceramic;

/**
 * Blending modes that control how pixels are combined when drawing.
 * 
 * Blending determines how source pixels (what you're drawing) are combined
 * with destination pixels (what's already on screen). Different modes create
 * different visual effects.
 * 
 * Ceramic uses premultiplied alpha by default for better compositing results.
 * Most users should stick with AUTO blending unless specific effects are needed.
 * 
 * @see Visual.blending
 */
enum abstract Blending(Int) from Int to Int {

    /**
     * Automatic/default blending in ceramic.
     * 
     * Internally uses premultiplied alpha blending, as textures are
     * pre-processed for this mode during asset loading. In special cases
     * (like render-to-texture), Ceramic automatically selects the most
     * appropriate blending mode.
     * 
     * This is the recommended mode for most use cases as it provides:
     * - Correct transparency compositing
     * - Better anti-aliasing on edges
     * - Consistent results across different backgrounds
     * 
     * Formula: result = source + dest * (1 - source.alpha)
     */
    var AUTO = 0;

    /**
     * Explicit premultiplied alpha blending.
     * 
     * Same as AUTO but explicitly specified. Use when you need to ensure
     * premultiplied alpha blending regardless of context.
     * 
     * RGB values are pre-multiplied by alpha during asset processing,
     * resulting in better edge quality and compositing.
     * 
     * Formula: result = source + dest * (1 - source.alpha)
     */
    var PREMULTIPLIED_ALPHA = 1;

    /**
     * Additive blending.
     * 
     * Adds source pixels to destination pixels, creating bright/glowing effects.
     * Perfect for:
     * - Light effects and glows
     * - Fire, explosions, energy beams
     * - Particle effects
     * - Magic spell visuals
     * 
     * Note: Results in brighter colors, can easily saturate to white.
     * 
     * Formula: result = source + dest
     */
    var ADD = 2;

    /**
     * Set blending (replace mode).
     * 
     * Completely replaces destination pixels with source pixels,
     * ignoring what was previously drawn. No transparency or blending.
     * 
     * Use cases:
     * - Clearing areas to specific colors
     * - Masks and stencil-like effects
     * - Overwriting render texture contents
     * 
     * Formula: result = source
     */
    var SET = 4;

    /**
     * Special blending mode for render-to-texture operations.
     * 
     * Used internally by Ceramic when rendering to RenderTexture objects.
     * Ensures correct alpha channel handling in off-screen buffers.
     * 
     * Generally not used directly by user code.
     */
    var RENDER_TO_TEXTURE = 5;

    /**
     * Special blending mode for render-to-texture alpha operations.
     * 
     * Variant of RENDER_TO_TEXTURE with different alpha handling.
     * Used internally for specific render texture scenarios.
     * 
     * Generally not used directly by user code.
     */
    var RENDER_TO_TEXTURE_ALPHA = 6;

    /**
     * Traditional (non-premultiplied) alpha blending.
     * 
     * Uses standard alpha blending without premultiplication. This mode
     * can cause dark halos around transparent edges and is generally
     * not recommended.
     * 
     * Only use when:
     * - Working with textures that aren't premultiplied
     * - Specific compatibility requirements
     * - Drawing RenderTextures in special cases
     * 
     * Formula: result = source * source.alpha + dest * (1 - source.alpha)
     */
    var ALPHA = 3;

}
