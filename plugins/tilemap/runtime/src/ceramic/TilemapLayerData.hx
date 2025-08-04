package ceramic;

import tracker.Model;

using ceramic.Extensions;

#if plugin_ldtk
import ceramic.LdtkData;
#end

/**
 * Data model representing a single layer within a tilemap.
 * 
 * TilemapLayerData holds all the information needed to render and interact with a tilemap layer,
 * including tile indices, dimensions, positioning, and visual properties. This is a reactive Model
 * that notifies observers when properties change, allowing TilemapLayer visuals to update automatically.
 * 
 * ## Features
 * 
 * - **Tile Storage**: Holds tile indices referencing tilesets via global IDs (GIDs)
 * - **Auto-tiling Support**: Can store both original and computed tiles after auto-tiling
 * - **Per-tile Properties**: Supports per-tile alpha and offset values
 * - **Layer Properties**: Position, size, visibility, opacity, and blending modes
 * - **Reactive Updates**: Extends Model for automatic change notifications
 * 
 * ## Usage Example
 * 
 * ```haxe
 * // Create a new layer data
 * var layer = new TilemapLayerData();
 * layer.name = 'collision';
 * layer.grid(20, 15); // 20x15 tiles
 * layer.tileSize(32, 32); // 32x32 pixel tiles
 * 
 * // Set tiles (array of TilemapTile values)
 * var tiles = [];
 * for (i in 0...300) {
 *     tiles.push(i == 150 ? 1 : 0); // Single tile in center
 * }
 * layer.tiles = tiles;
 * 
 * // Configure visual properties
 * layer.opacity = 0.8;
 * layer.color = Color.RED;
 * ```
 * 
 * @see TilemapData
 * @see TilemapLayer
 * @see TilemapTile
 */
class TilemapLayerData extends Model {

    #if plugin_ldtk

    /**
     * Reference to the source LDtk layer instance when this layer was imported from LDtk.
     * Provides access to additional LDtk-specific data and properties.
     */
    @:plugin('ldtk')
    @observe public var ldtkLayer:LdtkLayerInstance = null;

    #end

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
    @serialize public var columns:Int = 0;

    /**
     * The height of the layer in tiles
     */
    @serialize public var rows:Int = 0;

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
     * Explicit depth, or null of that should be computed by `Tilemap` instead
     */
    @serialize public var explicitDepth:Null<Float> = null;

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
     * Tiles
     */
    @serialize public var tiles:ReadOnlyArray<TilemapTile> = null;

    /**
     * Per-tile alpha, or null if there is no custom alpha per tile
     */
    @serialize public var tilesAlpha:ReadOnlyArray<Float> = null;

    /**
     * Per-tile x offset in pixels, or null if there is no offset
     */
    @serialize public var tilesOffsetX:ReadOnlyArray<Int> = null;

    /**
     * Per-tile y offset in pixels, or null if there is no offset
     */
    @serialize public var tilesOffsetY:ReadOnlyArray<Int> = null;

    /**
     * Computed tiles, after applying auto-tiling (if any).
     * Will be `null` if no auto-tiling is used.
     */
    @observe public var computedTiles:ReadOnlyArray<TilemapTile> = null;

    /**
     * Per-computed tile alpha, or null if there is no custom alpha per computed tile
     */
    @observe public var computedTilesAlpha:ReadOnlyArray<Float> = null;

    /**
     * Per-computed tile x offset in pixels, or null if there is no offset per computed tile
     */
    @observe public var computedTilesOffsetX:ReadOnlyArray<Int> = null;

    /**
     * Per-computed tile y offset in pixels, or null if there is no offset per computed tile
     */
    @observe public var computedTilesOffsetY:ReadOnlyArray<Int> = null;

    /**
     * Is `true` if this layer has tiles. Some layers don't have tile and
     * don't need to be rendered with tilemap layer quads, but are still
     * available as containers to add custom objects (like LDtk entities).
     * @return Bool
     */
    @compute public function hasTiles():Bool {

        return (
            (tiles != null && tiles.length > 0) ||
            (computedTiles != null && computedTiles.length > 0)
        );

    }

    /**
     * Is `true` (default) if this layer should have its tiles rendered (if any).
     */
    @serialize public var shouldRenderTiles:Bool = true;

    /**
     * The width of a tile in this layer
     */
    @serialize public var tileWidth:Int = -1;

    /**
     * The height of a tile in this layer
     */
    @serialize public var tileHeight:Int = -1;

    /**
     * A shorthand to set `columns` and `rows`
     * @param columns
     * @param rows
     */
    public function grid(columns:Int, rows:Int):Void {
        this.columns = columns;
        this.rows = rows;
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

    /**
     * A shorthand to set `tileWidth` and `tileHeight`
     * @param tileWidth
     * @param tileHeight
     */
    public function tileSize(tileWidth:Int, tileHeight:Int):Void {
        this.tileWidth = tileWidth;
        this.tileHeight = tileHeight;
    }

/// Helpers

    /**
     * Converts column and row coordinates to a tile index.
     * @param column The column position (0-based)
     * @param row The row position (0-based)
     * @return The tile index in the flat tiles array
     */
    #if !debug inline #end public function indexFromColumnAndRow(column:Int, row:Int):Int {

        return row * columns + column;

    }

    /**
     * Retrieves the tile at the specified column and row position from the tiles array.
     * @param column The column position (0-based)
     * @param row The row position (0-based)
     * @return The TilemapTile at the position
     */
    #if !debug inline #end public function tileByColumnAndRow(column:Int, row:Int):TilemapTile {

        var index = indexFromColumnAndRow(column, row);
        return tiles.unsafeGet(index);

    }

    /**
     * Retrieves the computed tile at the specified column and row position.
     * Used when auto-tiling has been applied to get the final tile value.
     * @param column The column position (0-based)
     * @param row The row position (0-based)
     * @return The computed TilemapTile at the position
     */
    #if !debug inline #end public function computedTileByColumnAndRow(column:Int, row:Int):TilemapTile {

        var index = indexFromColumnAndRow(column, row);
        return computedTiles.unsafeGet(index);

    }

    /**
     * Gets the column position from a tile index.
     * @param index The tile index in the flat array
     * @return The column position (0-based)
     */
    #if !debug inline #end public function columnAtIndex(index:Int):Int {

        return index % columns;

    }

    /**
     * Gets the row position from a tile index.
     * @param index The tile index in the flat array
     * @return The row position (0-based)
     */
    #if !debug inline #end public function rowAtIndex(index:Int):Int {

        return Math.floor(index / columns);

    }

}
