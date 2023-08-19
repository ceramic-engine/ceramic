package ceramic;

@:structInit
class AutoTile {

    /**
     * The kind of autotile. Depending on this, the autotile
     * will use more or less tiles on the source tileset
     */
    public var kind:AutoTileKind;

    /**
     * The main gid of this autotile. This is usually the gid that
     * shows a tile that doesn't have any auto tiling transformation.
     */
    public var gid:Int;

    /**
     * If set to `true` (default), bounds of the tilemap are considered
     * "filled" with the same tile and will affect how the auto tiling is computed.
     * Set it to false if you don't want your tiles to look "connected" with the map bounds.
     */
    public var bounds:Bool = true;

    /**
     * The tileset holding this autotile. Required when using `TILESETTER_BLOB_47` kind.
     */
    public var tileset:Tileset = null;

    /**
     * Column in the tileset matching the main gid of this autotile.
     * Available when a `tileset` option is provided.
     */
    public var column(default, null):Int = -1;

    /**
     * Row in the tileset matching the main gid of this autotile.
     * Available when a `tileset` option is provided.
     */
    public var row(default, null):Int = -1;

    /**
     * Will compute additional values like `row` and `column`
     * from the existing data. Automatically called by `AutoTiler`.
     */
    public function computeValues() {

        if (tileset != null) {
            column = tileset.columnForGid(gid);
            row = tileset.rowForGid(gid);
        }

    }

}
