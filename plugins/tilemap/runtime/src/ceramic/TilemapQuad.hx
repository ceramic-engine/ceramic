package ceramic;

class TilemapQuad extends Quad {

    static var pool(default, null):Pool<TilemapQuad> = null;

    public var index:Int = -1;

    public var column:Int = -1;

    public var row:Int = -1;

    public var tilemapTile:TilemapTile = 0;

    public static function get():TilemapQuad {

        var result:TilemapQuad = null;
        if (pool != null) {
            result = pool.get();
        }
        if (result == null) {
            result = new TilemapQuad();
        }
        else {
            result.active = true;
        }
        return result;

    }

    public function recycle():Void {

        if (this.parent != null) {
            this.parent.remove(this);
        }

        this.active = false;
        this.index = -1;
        this.column = -1;
        this.row = -1;
        this.tilemapTile = 0;

        if (pool == null) {
            pool = new Pool<TilemapQuad>();
        }

        pool.recycle(this);

    }

}
