package ceramic;

/**
 * Represents a single tile in a tilemap, storing both the tile ID and transformation flags.
 * 
 * TilemapTile is an abstract type over Int that encodes multiple pieces of information:
 * - The global tile ID (GID) referencing a tile in a tileset
 * - Horizontal flip flag
 * - Vertical flip flag
 * - Diagonal flip flag (for 90° rotations)
 * 
 * This encoding follows the Tiled Map Editor (TMX) format specification, where the
 * upper 3 bits store transformation flags and the lower 29 bits store the GID.
 * 
 * ## Bit Layout
 * 
 * ```
 * Bit 31: Horizontal flip
 * Bit 30: Vertical flip
 * Bit 29: Diagonal flip (swap X/Y axis)
 * Bits 0-28: Global tile ID (GID)
 * ```
 * 
 * ## Usage Example
 * 
 * ```haxe
 * // Create a tile with GID 42
 * var tile:TilemapTile = 42;
 * 
 * // Apply transformations
 * tile.horizontalFlip = true;
 * tile.verticalFlip = true;
 * 
 * // Rotate the tile
 * tile.rotateRight(); // 90° clockwise
 * 
 * // Get the actual tile ID
 * var gid = tile.gid; // Gets ID without flags
 * ```
 * 
 * @see TilemapLayerData
 * @see TilemapQuad
 */
abstract TilemapTile(Int) from Int to Int {

    // Some portions of this code come from https://github.com/Yanrishatum/haxe-format-tiled

    private inline static var HORIZONTAL_FLIP:Int = 0x80000000;
    private inline static var VERTICAL_FLIP:Int = 0x40000000;
    private inline static var DIAGONAL_FLIP:Int = 0x20000000;
    private inline static var FLAGS_MASK:Int = 0x1FFFFFFF;
    private inline static var FLAGS_ONLY:Int = 0xE0000000;

    /**
     * Creates a new TilemapTile with the given value.
     * The value can include both GID and transformation flags.
     * @param value The tile value (GID + optional flags)
     */
    inline public function new(value:Int) {

        this = value;

    }

    /**
     * Flips the tile horizontally.
     * When the tile is diagonally flipped (rotated), this affects the vertical flip instead.
     */
    inline public function flipX():Void {
        if (diagonalFlip) {
            verticalFlip = !verticalFlip;
        }
        else {
            horizontalFlip = !horizontalFlip;
        }
    }

    /**
     * Flips the tile vertically.
     * When the tile is diagonally flipped (rotated), this affects the horizontal flip instead.
     */
    inline public function flipY():Void {
        if (diagonalFlip) {
            horizontalFlip = !horizontalFlip;
        }
        else {
            verticalFlip = !verticalFlip;
        }
    }

    /**
     * Rotates the tile 90 degrees clockwise.
     * This is achieved by manipulating the combination of flip flags.
     * Multiple rotations can be combined to achieve 180° or 270° rotation.
     */
    inline public function rotateRight():Void {
        final hFlip = get_horizontalFlip();
        final vFlip = get_verticalFlip();
        final dFlip = get_diagonalFlip();
        switch [hFlip, vFlip, dFlip] {
            case [false, false, false]: // 0
                set_horizontalFlip(true);
                set_diagonalFlip(true);
            case [true, false, false]: // 0 + flip X
                set_verticalFlip(true);
                set_diagonalFlip(true);
            case [true, false, true]: // 90
                set_verticalFlip(true);
                set_diagonalFlip(false);
            case [true, true, true]: // 90 + flip X
                set_diagonalFlip(false);
            case [false, true, false]: // 180 + flip Y
                set_diagonalFlip(true);
            case [true, true, false]: // 180
                set_horizontalFlip(false);
                set_diagonalFlip(false);
            case [false, false, true]: // 270 + flip X
                set_horizontalFlip(true);
                set_diagonalFlip(false);
            case [false, true, true]: // 270
                set_verticalFlip(false);
                set_diagonalFlip(false);
        }
    }

    /**
     * Rotates the tile 90 degrees counter-clockwise.
     * This is achieved by manipulating the combination of flip flags.
     * Multiple rotations can be combined to achieve 180° or 270° rotation.
     */
    inline public function rotateLeft():Void {
        final hFlip = get_horizontalFlip();
        final vFlip = get_verticalFlip();
        final dFlip = get_diagonalFlip();
        switch [hFlip, vFlip, dFlip] {
            case [false, false, false]: // 0
                set_verticalFlip(true);
                set_diagonalFlip(true);
            case [true, false, false]: // 0 + flip X
                set_horizontalFlip(false);
                set_diagonalFlip(true);
            case [true, false, true]: // 90
                set_horizontalFlip(false);
                set_diagonalFlip(false);
            case [true, true, true]: // 90 + flip X
                set_verticalFlip(false);
                set_diagonalFlip(false);
            case [false, true, false]: // 180 + flip Y
                set_horizontalFlip(true);
                set_verticalFlip(false);
                set_diagonalFlip(true);
            case [true, true, false]: // 180
                set_verticalFlip(false);
                set_diagonalFlip(true);
            case [false, false, true]: // 270 + flip X
                set_horizontalFlip(true);
                set_verticalFlip(true);
                set_diagonalFlip(false);
            case [false, true, true]: // 270
                set_horizontalFlip(true);
                set_diagonalFlip(false);
        }
    }

    /**
     * Global tile id
     */
    public var gid(get, set):Int;
    inline function get_gid():Int {
        return this & FLAGS_MASK;
    }
    inline function set_gid(gid:Int):Int {
        return (this = (this & FLAGS_ONLY) | (gid & FLAGS_MASK));
    }

    /**
     * Is tile flipped horizontally
     */
    public var horizontalFlip(get, set):Bool;
    inline function get_horizontalFlip():Bool {
        return (this & HORIZONTAL_FLIP) != 0;
    }
    #if !completion inline #end function set_horizontalFlip(value:Bool):Bool {
        #if !completion
        this = value ? this | HORIZONTAL_FLIP : this & ~HORIZONTAL_FLIP;
        #end
        return value;
    }

    /**
     * Is tile flipped vertically
     */
    public var verticalFlip(get, set):Bool;
    inline function get_verticalFlip():Bool {
        return (this & VERTICAL_FLIP) != 0;
    }
    #if !completion inline #end function set_verticalFlip(value:Bool):Bool {
        #if !completion
        this = value ? this | VERTICAL_FLIP : this & ~VERTICAL_FLIP;
        #end
        return value;
    }

    /**
     * Is tile flipped diagonally
     */
    public var diagonalFlip(get, set):Bool;
    inline function get_diagonalFlip():Bool {
        return (this & DIAGONAL_FLIP) != 0;
    }
    #if !completion inline #end function set_diagonalFlip(value:Bool):Bool {
        #if !completion
        this = value ? this | DIAGONAL_FLIP : this & ~DIAGONAL_FLIP;
        #end
        return value;
    }

}
