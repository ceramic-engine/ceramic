package ceramic;

/**
 * Defines the order in which tiles are rendered in a tilemap.
 * 
 * The render order determines the drawing sequence of tiles, which affects
 * their depth/layering when tiles overlap or when using isometric projections.
 * This is particularly important for proper visual layering in non-orthogonal
 * tilemap orientations.
 * 
 * ## Render Orders
 * 
 * - **RIGHT_DOWN**: Start top-left, go right then down (default for most games)
 * - **RIGHT_UP**: Start bottom-left, go right then up (useful for some isometric games)
 * - **LEFT_DOWN**: Start top-right, go left then down
 * - **LEFT_UP**: Start bottom-right, go left then up
 * 
 * ## Usage Example
 * 
 * ```haxe
 * var tilemapData = new TilemapData();
 * tilemapData.renderOrder = RIGHT_DOWN; // Standard left-to-right, top-to-bottom
 * 
 * // For isometric games, you might use:
 * tilemapData.orientation = ISOMETRIC;
 * tilemapData.renderOrder = RIGHT_UP; // Ensures proper depth sorting
 * ```
 * 
 * @see TilemapData
 * @see TilemapOrientation
 */
enum TilemapRenderOrder {

    /**
     * Render tiles from left to right, top to bottom.
     * This is the most common render order, starting at the top-left corner.
     * Tiles in lower rows will appear in front of tiles in higher rows.
     */
    RIGHT_DOWN;

    /**
     * Render tiles from left to right, bottom to top.
     * Starts at the bottom-left corner of the map.
     * Tiles in higher rows will appear in front of tiles in lower rows.
     */
    RIGHT_UP;

    /**
     * Render tiles from right to left, top to bottom.
     * Starts at the top-right corner of the map.
     * Tiles on the left will appear in front of tiles on the right.
     */
    LEFT_DOWN;

    /**
     * Render tiles from right to left, bottom to top.
     * Starts at the bottom-right corner of the map.
     * Combines the depth sorting of RIGHT_UP with right-to-left ordering.
     */
    LEFT_UP;

}
