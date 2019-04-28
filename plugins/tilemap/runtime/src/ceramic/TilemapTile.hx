package ceramic;

abstract TilemapTile(Int) from Int to Int {

    // Some portions of this code come from https://github.com/Yanrishatum/haxe-format-tiled
    
    private inline static var HORIZONTAL_FLIP:Int = 0x80000000;
    private inline static var VERTICAL_FLIP:Int = 0x40000000;
    private inline static var DIAGONAL_FLIP:Int = 0x20000000;
    private inline static var FLAGS_MASK:Int = 0x1FFFFFFF;
    private inline static var FLAGS_ONLY:Int = 0xE0000000;

    inline public function new(value:Int) {

        this = value;

    } //new
  
    /** Global tile id */
    public var gid(get, set):Int;
    inline function get_gid():Int {
        return this & FLAGS_MASK;
    }
    inline function set_gid(gid:Int):Int {
        return (this = (this & FLAGS_ONLY) | (gid & FLAGS_MASK));
    }

    /** Is tile flipped horizontally */
    public var horizontalFlip(get, set):Bool;
    inline function get_horizontalFlip():Bool {
        return (this & HORIZONTAL_FLIP) != 0;
    }
    inline function set_horizontalFlip(value:Bool):Bool {
        this = value ? this | HORIZONTAL_FLIP : this & ~HORIZONTAL_FLIP;
        return value;
    }

    /** Is tile flipped vertically */
    public var verticalFlip(get, set):Bool;
    inline function get_verticalFlip():Bool {
        return (this & VERTICAL_FLIP) != 0;
    }
    inline function set_verticalFlip(value:Bool):Bool {
        this = value ? this | VERTICAL_FLIP : this & ~VERTICAL_FLIP;
        return value;
    }

    /** Is tile flipped diagonally */
    public var diagonalFlip(get, set):Bool;
    inline function get_diagonalFlip():Bool {
        return (this & DIAGONAL_FLIP) != 0;
    }
    inline function set_diagonalFlip(value:Bool):Bool {
        this = value ? this | DIAGONAL_FLIP : this & ~DIAGONAL_FLIP;
        return value;
    }

} //TilemapTile
