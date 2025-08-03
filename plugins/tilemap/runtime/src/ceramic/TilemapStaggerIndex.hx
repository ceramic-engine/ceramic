package ceramic;

/**
 * Defines which rows or columns are staggered in hexagonal and staggered tilemaps.
 * 
 * The stagger index determines whether odd or even rows/columns are offset when
 * using STAGGERED or HEXAGONAL tilemap orientations. This works in conjunction
 * with TilemapStaggerAxis to define the exact staggering pattern.
 * 
 * ## Stagger Patterns
 * 
 * With AXIS_Y and ODD:
 * ```
 * Row 0: [A] [B] [C]    <- Even row (not offset)
 * Row 1:   [D] [E] [F]  <- Odd row (offset)
 * Row 2: [G] [H] [I]    <- Even row (not offset)
 * ```
 * 
 * With AXIS_Y and EVEN:
 * ```
 * Row 0:   [A] [B] [C]  <- Even row (offset)
 * Row 1: [D] [E] [F]    <- Odd row (not offset)
 * Row 2:   [G] [H] [I]  <- Even row (offset)
 * ```
 * 
 * ## Usage Example
 * 
 * ```haxe
 * var tilemapData = new TilemapData();
 * tilemapData.orientation = HEXAGONAL;
 * tilemapData.staggerAxis = AXIS_Y;
 * tilemapData.staggerIndex = ODD; // Odd rows will be offset
 * 
 * // For a different pattern:
 * tilemapData.staggerIndex = EVEN; // Even rows will be offset
 * ```
 * 
 * @see TilemapData
 * @see TilemapStaggerAxis
 * @see TilemapOrientation
 */
enum TilemapStaggerIndex {

    /**
     * Odd rows or columns are staggered (offset).
     * When using AXIS_Y, odd-numbered rows (1, 3, 5...) are offset.
     * When using AXIS_X, odd-numbered columns (1, 3, 5...) are offset.
     */
    ODD;

    /**
     * Even rows or columns are staggered (offset).
     * When using AXIS_Y, even-numbered rows (0, 2, 4...) are offset.
     * When using AXIS_X, even-numbered columns (0, 2, 4...) are offset.
     */
    EVEN;

}
