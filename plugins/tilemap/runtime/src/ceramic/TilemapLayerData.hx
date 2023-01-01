package ceramic;

import tracker.Model;

using ceramic.Extensions;

class TilemapLayerData extends Model {

    /**
     * The name of the layer
     */
    @serialize public var name:String = null;

    /**
     * The x position of the layer in tiles
     */
    @serialize public var x:Int = 0;

    /**
     * The y position of the layer in tiles
     */
    @serialize public var y:Int = 0;

    /**
     * The width of the layer in tiles
     */
    @serialize public var width:Int = 0;

    /**
     * The height of the layer in tiles
     */
    @serialize public var height:Int = 0;

    /**
     * The opacity of the layer
     */
    @serialize public var opacity:Float = 1;

    /**
     * Whether this layer is visible or not
     */
    @serialize public var visible:Bool = true;

    /**
     * X offset for this layer in points.
     */
    @serialize public var offsetX:Int = 0;

    /**
     * Y offset for this layer in points.
     */
    @serialize public var offsetY:Int = 0;

    /**
     * Tiles
     */
    @serialize public var tiles:ReadOnlyArray<TilemapTile> = null;

    /**
     * Tile default blending
     */
    @serialize public var blending:Blending = AUTO;

    /**
     * Tile default (tint) color
     */
    @serialize public var color:Color = Color.WHITE;

    /**
     * Extra tile default blending
     */
    @serialize public var extraBlending:Blending = AUTO;

    /**
     * Extra tile default alpha
     */
    @serialize public var extraOpacity:Float = 1;

    /**
     * Computed tiles, after applying auto-tiling (if any).
     * Will be `null` if no auto-tiling is used.
     */
    @observe public var computedTiles:ReadOnlyArray<TilemapTile> = null;

    /**
     * A shorthand to set `width` and `height`
     * @param width
     * @param height
     */
    public function size(width:Int, height:Int):Void {
        this.width = width;
        this.height = height;
    }

    /**
     * A shorthand to set `x` and `y`
     * @param width
     * @param height
     */
    public function pos(x:Int, y:Int):Void {
        this.x = x;
        this.y = y;
    }

    /**
     * A shorthand to set `offsetX` and `offsetY`
     * @param width
     * @param height
     */
    public function offset(offsetX:Int, offsetY:Int):Void {
        this.offsetX = offsetX;
        this.offsetY = offsetY;
    }

/// Helpers

    inline public function tileByColumnAndRow(column:Int, row:Int):TilemapTile {

        var index = row * width + column;
        return tiles.unsafeGet(index);

    }

    inline public function columnAtIndex(index:Int):Int {

        return index % width;

    }

    inline public function rowAtIndex(index:Int):Int {

        return Math.floor(index / height);

    }

}
