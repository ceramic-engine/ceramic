package ceramic;

/**
 * Defines slope collision data for a tile in a tileset.
 *
 * **Warning: This is just a draft, don't use it!**
 *
 * TileSlope represents a sloped collision surface within a tile, useful for creating
 * smooth ramps, hills, and angled surfaces in platformers and other games with physics.
 * The slope is defined by two height values at the left and right edges of the tile.
 *
 * ## Slope Definition
 *
 * The slope is defined in normalized coordinates where:
 * - 0.0 = bottom of the tile
 * - 1.0 = top of the tile
 * - y0 = height at the left edge
 * - y1 = height at the right edge
 *
 * ## Usage Example
 *
 * ```haxe
 * // Create a 45-degree upward slope
 * var slope:TileSlope = {
 *     index: 5,      // Tile index in tileset
 *     y0: 0.0,       // Left edge at bottom
 *     y1: 1.0,       // Right edge at top
 *     rotation: 0    // No rotation
 * };
 *
 * // Create a downward slope
 * var downSlope:TileSlope = {
 *     index: 6,
 *     y0: 1.0,       // Left edge at top
 *     y1: 0.0,       // Right edge at bottom
 *     rotation: 0
 * };
 *
 * // Add to tileset
 * tileset.slope(slope);
 * ```
 *
 * @see Tileset
 */
@:structInit
class TileSlope {

    /**
     * The tile index within the tileset that this slope applies to.
     * This should match the tile's position in the tileset grid (0-based).
     */
    public var index(default, null):Int;

    /**
     * Rotation angle in degrees (0, 90, 180, or 270).
     * Allows reusing the same slope definition for different orientations.
     */
    public var rotation(default, null):Int;

    /**
     * The normalized height (0.0 to 1.0) at the left edge of the tile.
     * 0.0 represents the bottom of the tile, 1.0 represents the top.
     */
    public var y0(default, null):Float;

    /**
     * The normalized height (0.0 to 1.0) at the right edge of the tile.
     * 0.0 represents the bottom of the tile, 1.0 represents the top.
     */
    public var y1(default, null):Float;

}
