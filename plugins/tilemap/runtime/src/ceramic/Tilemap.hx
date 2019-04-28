package ceramic;

class Tilemap extends Visual {

    public var tilemapData(default,set):TilemapData = null;
    function set_tilemapData(tilemapData:TilemapData):TilemapData {
        if (this.tilemapData == tilemapData) return tilemapData;
        this.tilemapData = tilemapData;
        return tilemapData;
    }

    public function new() {

        super();

    } //new

} //Tilemap
