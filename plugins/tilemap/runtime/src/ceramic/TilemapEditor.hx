package ceramic;

import ceramic.Shortcuts.*;

/**
 * Interactive tilemap editor component that enables in-game tile painting and erasing.
 * 
 * This component can be attached to a Tilemap entity to enable runtime editing functionality,
 * allowing users to paint tiles with left-click and erase them with right-click. It supports
 * continuous painting while dragging and interpolates between positions for smooth lines.
 * 
 * ## Usage Example
 * 
 * ```haxe
 * // Create a tilemap and enable editing
 * var tilemap = new Tilemap();
 * tilemap.tilemapData = myTilemapData;
 * 
 * // Attach editor to allow painting on the 'main' layer
 * var editor = new TilemapEditor('main', grassTile, emptyTile);
 * tilemap.component(editor);
 * 
 * // Listen for edit events
 * editor.onFill(this, index -> {
 *     trace('Filled tile at index: $index');
 * });
 * ```
 */
class TilemapEditor extends Entity implements Component {

    /**
     * Event emitted when a tile is filled with the fill value.
     * @param index The tile index that was filled
     */
    @event function fill(index:Int);

    /**
     * Event emitted when a tile is erased with the erase value.
     * @param index The tile index that was erased
     */
    @event function erase(index:Int);

    /**
     * Shared point instance for coordinate conversions.
     */
    static var _point = new Point(0, 0);

    /**
     * The tilemap entity this editor is attached to.
     * Set automatically when used as a component.
     */
    @entity var tilemap:Tilemap;

    /**
     * The name of the tilemap layer to edit.
     * Must match an existing layer in the tilemap data.
     */
    public var layerName:String;

    /**
     * The tile value to apply when filling (left-click).
     * This can be a tile ID from a tileset or a special value.
     */
    public var fillValue:TilemapTile;

    /**
     * The tile value to apply when erasing (right-click).
     * Typically 0 to represent an empty tile.
     */
    public var eraseValue:TilemapTile;

    /**
     * Whether editing is currently enabled.
     * Set to false to temporarily disable user interaction.
     */
    public var enabled:Bool = true;

    /**
     * ID of the button currently being held down (-1 if none).
     * 0 = left button, 2 = right button.
     */
    var buttonDownId:Int = -1;

    /**
     * The tile value being painted with the current button.
     * Cached to ensure consistency during drag operations.
     */
    var buttonDownValue:Int = -1;

    /**
     * Map tracking which tiles have been painted during the current drag.
     * Prevents painting the same tile multiple times in one stroke.
     */
    var hoveredTileIndexes:IntBoolMap = null;

    /**
     * Last painted X position in visual coordinates.
     * Used for interpolating smooth lines when dragging.
     */
    var lastPaintedX:Float = -1;

    /**
     * Last painted Y position in visual coordinates.
     * Used for interpolating smooth lines when dragging.
     */
    var lastPaintedY:Float = -1;

    /**
     * Creates a new tilemap editor.
     * @param layerName The name of the layer to edit (default: 'main')
     * @param fillValue The tile value for filling (default: 1)
     * @param eraseValue The tile value for erasing (default: 0)
     */
    public function new(layerName:String = 'main', fillValue:TilemapTile = 1, eraseValue:TilemapTile = 0) {

        super();

        this.layerName = layerName;
        this.fillValue = fillValue;
        this.eraseValue = eraseValue;

    }

    /**
     * Called when this editor is attached to a tilemap as a component.
     * Sets up the necessary event listeners for pointer interaction.
     */
    public function bindAsComponent() {

        tilemap.onPointerDown(this, handlePointerDown);
        tilemap.onPointerUp(this, handlePointerUp);

    }

    /**
     * Handles pointer down events to start tile painting or erasing.
     * Left-click starts filling tiles, right-click starts erasing.
     * @param info Touch/mouse event information
     */
    function handlePointerDown(info:TouchInfo) {

        if (!enabled)
            return;

        if (info.buttonId == 0 || info.buttonId == 2) {

            // Left click: fill
            // Right click: erase

            var tilemapData = tilemap.tilemapData;
            if (tilemapData != null) {
                var layerData = tilemapData.layer(layerName);
                var layer = tilemap.layer(layerName);
                if (layerData != null && layer != null) {
                    layer.screenToVisual(info.x, info.y, _point);
                    lastPaintedX = _point.x;
                    lastPaintedY = _point.y;
                    var index = tileIndexAtPosition(tilemapData, layerData, _point.x, _point.y);

                    if (index >= 0 && index < layerData.tiles.length) {

                        hoveredTileIndexes = new IntBoolMap();
                        hoveredTileIndexes.set(index, true);
                        buttonDownId = info.buttonId;
                        screen.onPointerMove(this, handlePointerMove);

                        // Update tile
                        var tiles = [].concat(layerData.tiles.original);
                        if (buttonDownId == 0) {
                            tiles[index] = fillValue;
                            buttonDownValue = fillValue;
                        }
                        else {
                            tiles[index] = eraseValue;
                            buttonDownValue = eraseValue;
                        }
                        layerData.tiles = tiles;
                        if (buttonDownId == 0) {
                            emitFill(index);
                        }
                        else {
                            emitErase(index);
                        }

                        var layer = tilemap.layer(layerName);
                        if (layer != null) {
                            layer.contentDirty = true;
                        }
                    }
                }
            }
        }

    }

    /**
     * Handles pointer up events to stop tile painting or erasing.
     * Cleans up the drag state when the mouse button is released.
     * @param info Touch/mouse event information
     */
    function handlePointerUp(info:TouchInfo) {

        if (info.buttonId == buttonDownId) {
            buttonDownId = -1;
            buttonDownValue = -1;
            hoveredTileIndexes = null;
        }

    }

    /**
     * Handles pointer move events during tile painting or erasing.
     * Interpolates between the last and current positions to paint smooth lines,
     * ensuring no tiles are missed when moving the pointer quickly.
     * @param info Touch/mouse event information
     */
    function handlePointerMove(info:TouchInfo) {

        if (buttonDownId != -1 && hoveredTileIndexes != null) {
            var tilemapData = tilemap.tilemapData;
            if (tilemapData != null) {
                var layerData = tilemapData.layer(layerName);
                var layer = tilemap.layer(layerName);
                if (layerData != null && layer != null) {
                    layer.screenToVisual(info.x, info.y, _point);

                    var paintedX = _point.x;
                    var paintedY = _point.y;

                    var numSteps = Std.int(Math.max(1, Math.max(Math.abs(paintedX - lastPaintedX), Math.abs(paintedY - lastPaintedY))));

                    for (i in 0...numSteps) {

                        var x = lastPaintedX + (paintedX - lastPaintedX) * i / numSteps;
                        var y = lastPaintedY + (paintedY - lastPaintedY) * i / numSteps;

                        var index = tileIndexAtPosition(tilemapData, layerData, x, y);

                        if (index >= 0 && index < layerData.tiles.length) {
                            if (!hoveredTileIndexes.exists(index)) {
                                hoveredTileIndexes.set(index, true);

                                // Update tile
                                var tiles = [].concat(layerData.tiles.original);
                                tiles[index] = buttonDownValue;
                                layerData.tiles = tiles;

                                if (buttonDownValue == fillValue) {
                                    emitFill(index);
                                }
                                else {
                                    emitErase(index);
                                }

                                var layer = tilemap.layer(layerName);
                                if (layer != null) {
                                    layer.contentDirty = true;
                                }
                            }
                        }
                    }

                    lastPaintedX = paintedX;
                    lastPaintedY = paintedY;
                }
            }
        }

    }

    /**
     * Calculates the tile index at a given position in visual coordinates.
     * Takes into account layer offsets and tile dimensions.
     * @param tilemapData The tilemap data containing layer information
     * @param layerData The specific layer data to check against
     * @param x The X position in visual coordinates
     * @param y The Y position in visual coordinates
     * @return The tile index at the position, or -1 if outside bounds
     */
    static function tileIndexAtPosition(tilemapData:TilemapData, layerData:TilemapLayerData, x:Float, y:Float):Int {

        var tileWidth = layerData.tileWidth;
        var tileHeight = layerData.tileHeight;
        x -= layerData.offsetX + layerData.x * tileWidth;
        y -= layerData.offsetY + layerData.y * tileHeight;
        var index = -1;
        if (x >= 0 && x < layerData.columns * tileWidth) {
            if (y >= 0 && y < layerData.rows * tileHeight) {
                var column:Int = Math.floor(x / tileWidth);
                var row:Int = Math.floor(y / tileHeight);
                index = row * layerData.columns + column;
            }
        }
        return index;

    }

}