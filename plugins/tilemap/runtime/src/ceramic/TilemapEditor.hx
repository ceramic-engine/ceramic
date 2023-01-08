package ceramic;

import ceramic.Shortcuts.*;

class TilemapEditor extends Entity implements Component {

    @event function fill(index:Int);

    @event function erase(index:Int);

    static var _point = new Point(0, 0);

    @entity var tilemap:Tilemap;

    public var layerName:String;

    public var fillValue:TilemapTile;

    public var eraseValue:TilemapTile;

    public var enabled:Bool = true;

    var buttonDownId:Int = -1;

    var buttonDownValue:Int = -1;

    var hoveredTileIndexes:IntBoolMap = null;

    var lastPaintedX:Float = -1;

    var lastPaintedY:Float = -1;

    public function new(layerName:String = 'main', fillValue:TilemapTile = 1, eraseValue:TilemapTile = 0) {

        super();

        this.layerName = layerName;
        this.fillValue = fillValue;
        this.eraseValue = eraseValue;

    }

    public function bindAsComponent() {

        tilemap.onPointerDown(this, handlePointerDown);
        tilemap.onPointerUp(this, handlePointerUp);

    }

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

    function handlePointerUp(info:TouchInfo) {

        if (info.buttonId == buttonDownId) {
            buttonDownId = -1;
            buttonDownValue = -1;
            hoveredTileIndexes = null;
        }

    }

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

    static function tileIndexAtPosition(tilemapData:TilemapData, layerData:TilemapLayerData, x:Float, y:Float):Int {

        var tileWidth = tilemapData.tileWidth;
        var tileHeight = tilemapData.tileHeight;
        x -= layerData.offsetX + layerData.x * tileWidth;
        y -= layerData.offsetY + layerData.y * tileHeight;
        var index = -1;
        if (x >= 0 && x < layerData.width * tileWidth) {
            if (y >= 0 && y < layerData.height * tileHeight) {
                var column:Int = Math.floor(x / tileWidth);
                var row:Int = Math.floor(y / tileHeight);
                index = row * layerData.width + column;
            }
        }
        return index;

    }

}