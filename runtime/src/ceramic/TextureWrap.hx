package ceramic;

/**
 * Texture wrapping modes for handling UV coordinates outside the 0-1 range.
 * 
 * TextureWrap determines how textures behave when UV coordinates exceed
 * their normal bounds during rendering. This is essential for:
 * - Tiling patterns and backgrounds
 * - Seamless textures
 * - Edge handling in texture atlases
 * - Special effects requiring texture repetition
 * 
 * The wrap mode affects both horizontal (U) and vertical (V) directions
 * independently, though Ceramic typically applies the same mode to both axes.
 * 
 * @example
 * ```haxe
 * // Create a tiling background
 * var background = new Quad();
 * background.texture = assets.texture('pattern.png');
 * background.texture.wrapS = REPEAT;
 * background.texture.wrapT = REPEAT;
 * 
 * // Scale UV coordinates to create tiling
 * background.scaleUV(10, 10); // 10x10 tile pattern
 * ```
 * 
 * @see Texture.wrapS Horizontal wrap mode property
 * @see Texture.wrapT Vertical wrap mode property
 */
enum abstract TextureWrap(Int) {

    /**
     * Clamps texture coordinates to the 0-1 range.
     * 
     * UV coordinates outside [0,1] are clamped to the nearest edge:
     * - Values < 0 become 0
     * - Values > 1 become 1
     * 
     * This causes the edge pixels to stretch when sampling beyond
     * the texture bounds. Most commonly used for:
     * - UI elements
     * - Sprites that shouldn't tile
     * - Texture atlas regions (prevents bleeding)
     * 
     * This is typically the default wrap mode.
     * 
     * @example
     * ```haxe
     * texture.wrapS = CLAMP;
     * texture.wrapT = CLAMP;
     * // UV 1.5 samples from the right edge
     * // UV -0.5 samples from the left edge
     * ```
     */
    var CLAMP = 0;

    /**
     * Repeats the texture infinitely in both directions.
     * 
     * UV coordinates wrap around:
     * - UV 1.5 becomes 0.5
     * - UV -0.3 becomes 0.7
     * - UV 3.2 becomes 0.2
     * 
     * Creates seamless tiling when the texture edges match.
     * Perfect for:
     * - Tiling backgrounds
     * - Repeating patterns
     * - Terrain textures
     * - Procedural materials
     * 
     * Note: Requires power-of-two texture dimensions on some GPUs.
     * 
     * @example
     * ```haxe
     * // Create an infinitely scrolling background
     * texture.wrapS = REPEAT;
     * texture.wrapT = REPEAT;
     * quad.scaleUV(5, 3); // Shows 5x3 tiles
     * ```
     */
    var REPEAT = 1;

    /**
     * Repeats the texture with mirroring at each boundary.
     * 
     * Alternates between normal and flipped texture on each tile:
     * - UV 0.0-1.0: Normal
     * - UV 1.0-2.0: Horizontally flipped
     * - UV 2.0-3.0: Normal again
     * 
     * Creates seamless patterns even with non-tileable textures.
     * Useful for:
     * - Symmetric patterns
     * - Kaleidoscope effects
     * - Reducing visible seams in tiled textures
     * 
     * Note: May require power-of-two texture dimensions on some GPUs.
     * 
     * @example
     * ```haxe
     * // Create a mirrored pattern
     * texture.wrapS = MIRROR;
     * texture.wrapT = MIRROR;
     * // Adjacent tiles will be flipped versions
     * ```
     */
    var MIRROR = 2;

}
