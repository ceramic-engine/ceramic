package ceramic;

/**
 * Defines the grid orientation for tiles within a tileset.
 * 
 * The grid orientation affects how tile overlays for terrain and collision information
 * are rendered in tilemap editors. This is primarily used when working with isometric
 * tilesets to ensure proper alignment of editor overlays with the tile graphics.
 * 
 * ## Grid Types
 * 
 * - **ORTHOGONAL**: Standard rectangular grid (default)
 * - **ISOMETRIC**: Diamond-shaped grid for isometric tiles
 * 
 * ## Usage Example
 * 
 * ```haxe
 * var tileset = new Tileset();
 * tileset.gridOrientation = ISOMETRIC;
 * tileset.gridCellWidth = 64;  // Width of isometric grid cell
 * tileset.gridCellHeight = 32; // Height of isometric grid cell
 * ```
 * 
 * ## Note
 * 
 * This setting only affects how tiles are displayed in editors and does not
 * change the actual rendering of tiles in the game. The tilemap's orientation
 * (TilemapOrientation) determines the actual tile layout.
 * 
 * @see Tileset
 * @see TilemapOrientation
 */
enum TilesetGridOrientation {

    /**
     * Standard rectangular grid orientation.
     * Tiles are aligned in a regular grid pattern with no offset.
     * This is the default and most common orientation.
     */
    ORTHOGONAL;

    /**
     * Isometric (diamond-shaped) grid orientation.
     * Used for tilesets containing isometric tiles where the grid
     * cells are rotated 45 degrees to form diamonds.
     */
    ISOMETRIC;

}
