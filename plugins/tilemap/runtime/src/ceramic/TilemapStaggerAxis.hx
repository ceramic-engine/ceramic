package ceramic;

/**
 * Defines the stagger axis for hexagonal and staggered tilemaps.
 * 
 * The stagger axis determines which direction (horizontal or vertical) the
 * alternating rows or columns are offset in staggered and hexagonal tile layouts.
 * This setting only applies when the tilemap orientation is STAGGERED or HEXAGONAL.
 * 
 * ## Stagger Axis Options
 * 
 * - **AXIS_X**: Stagger along the X axis (alternating columns are offset)
 * - **AXIS_Y**: Stagger along the Y axis (alternating rows are offset)
 * 
 * ## Visual Examples
 * 
 * AXIS_Y (rows offset):
 * ```
 * [1] [2] [3]
 *   [4] [5] [6]
 * [7] [8] [9]
 * ```
 * 
 * AXIS_X (columns offset):
 * ```
 * [1]   [3]   [5]
 *   [2]   [4]   [6]
 * ```
 * 
 * ## Usage Example
 * 
 * ```haxe
 * var tilemapData = new TilemapData();
 * tilemapData.orientation = HEXAGONAL;
 * tilemapData.staggerAxis = AXIS_Y; // Offset every other row
 * tilemapData.staggerIndex = ODD; // Offset odd rows
 * ```
 * 
 * @see TilemapData
 * @see TilemapOrientation
 * @see TilemapStaggerIndex
 */
enum TilemapStaggerAxis {

    /**
     * Stagger along the X axis.
     * Alternating columns are offset vertically.
     * Commonly used for vertically oriented hexagonal tiles.
     */
    AXIS_X;

    /**
     * Stagger along the Y axis.
     * Alternating rows are offset horizontally.
     * The most common choice for hexagonal tiles with points up/down.
     */
    AXIS_Y;

}
