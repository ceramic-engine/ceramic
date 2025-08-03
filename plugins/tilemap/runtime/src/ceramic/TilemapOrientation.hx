package ceramic;

/**
 * Defines the projection orientation of a tilemap.
 * 
 * Different orientations affect how tiles are positioned and rendered in 2D space,
 * enabling various visual styles and gameplay perspectives. The orientation determines
 * the mathematical relationship between tile indices and their screen positions.
 * 
 * ## Orientation Types
 * 
 * - **ORTHOGONAL**: Standard grid layout where tiles are rectangular and aligned in rows/columns
 * - **ISOMETRIC**: Diamond-shaped tiles creating a 2.5D perspective effect
 * - **STAGGERED**: Offset grid where every other row/column is shifted (used for hex maps)
 * - **HEXAGONAL**: True hexagonal tiles with six sides
 * 
 * ## Usage Example
 * 
 * ```haxe
 * var tilemapData = new TilemapData();
 * tilemapData.orientation = ISOMETRIC; // Creates isometric perspective
 * 
 * // Different orientations require different tile positioning logic
 * switch (tilemapData.orientation) {
 *     case ORTHOGONAL:
 *         // Simple grid: x = column * tileWidth, y = row * tileHeight
 *     case ISOMETRIC:
 *         // Diamond layout with offset positioning
 *     case STAGGERED:
 *         // Every other row/column is offset
 *     case HEXAGONAL:
 *         // Six-sided tiles with special positioning
 * }
 * ```
 * 
 * @see TilemapData
 * @see TilemapStaggerAxis
 * @see TilemapStaggerIndex
 */
enum TilemapOrientation {

    /**
     * Standard rectangular grid layout.
     * Tiles are positioned in simple rows and columns with no offset.
     * This is the most common orientation for platformers and top-down games.
     */
    ORTHOGONAL;

    /**
     * Isometric (diamond-shaped) tile layout.
     * Creates a 2.5D perspective effect commonly used in strategy and simulation games.
     * Tiles are rotated 45 degrees and positioned to create depth illusion.
     */
    ISOMETRIC;

    /**
     * Staggered grid layout with offset rows or columns.
     * Every other row or column is shifted by half a tile width/height.
     * Often used as a simpler alternative to true hexagonal grids.
     */
    STAGGERED;

    /**
     * True hexagonal tile layout with six-sided tiles.
     * Provides more natural movement in six directions.
     * Common in strategy games and board game adaptations.
     */
    HEXAGONAL;

} //TilemapOrientation