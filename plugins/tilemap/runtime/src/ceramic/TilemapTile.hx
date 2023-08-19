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

    }

    inline public function flipX():Void {
        if (diagonalFlip) {
            verticalFlip = !verticalFlip;
        }
        else {
            horizontalFlip = !horizontalFlip;
        }
    }

    inline public function flipY():Void {
        if (diagonalFlip) {
            horizontalFlip = !horizontalFlip;
        }
        else {
            verticalFlip = !verticalFlip;
        }
    }

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
