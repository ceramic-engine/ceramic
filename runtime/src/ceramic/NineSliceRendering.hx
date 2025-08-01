package ceramic;

/**
 * Defines how a slice (from a `NineSlice` object) should be rendered.
 * 
 * This enum controls the rendering behavior for the edge and center
 * sections of a nine-slice graphic. Each section can be rendered
 * differently to achieve various visual effects.
 * 
 * @see NineSlice
 */
enum abstract NineSliceRendering(Int) from Int to Int {

    /**
     * The slice should not be rendered at all.
     * Useful for creating frames with transparent centers or
     * when you only want to render specific parts of the nine-slice.
     */
    var NONE = 0;

    /**
     * The slice should be stretched to fill the area.
     * This is the default and most common mode. The texture
     * is scaled to fit the target dimensions, which works
     * well for most UI elements like buttons and panels.
     */
    var STRETCH = 1;

    /**
     * The slice should be repeated to cover the area.
     * The texture is tiled at its original size to fill
     * the space. Good for patterns, decorative borders,
     * or textured backgrounds.
     */
    var REPEAT = 2;

    /**
     * The slice should be repeated and mirrored to cover the area.
     * Similar to REPEAT, but alternating tiles are flipped to
     * create seamless patterns. Helps avoid visible seams in
     * tiling textures.
     */
    var MIRROR = 3;

}