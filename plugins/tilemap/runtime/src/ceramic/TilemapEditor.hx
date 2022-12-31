package ceramic;

import ceramic.Shortcuts.*;

class TilemapEditor extends Entity implements Component {

    static var _point = new Point(0, 0);

    @entity var tilemap:Tilemap;

    public var layerName:String;

    public var fillValue:TilemapTile;

    public var emptyValue:TilemapTile;

    var isLeftButtonDown:Bool = false;

    var leftButtonTileValue:TilemapTile = 0;

    var hoveredTileIndexes:IntBoolMap = null;

    var lastPaintedX:Float = -1;

    var lastPaintedY:Float = -1;

    public function new(layerName:String = 'main', fillValue:TilemapTile = 1, emptyValue:TilemapTile = 0) {

        super();

        this.layerName = layerName;
        this.fillValue = fillValue;
        this.emptyValue = emptyValue;

    }

    public function bindAsComponent() {

        tilemap.onPointerDown(this, handlePointerDown);
        tilemap.onPointerUp(this, handlePointerUp);

    }

    function handlePointerDown(info:TouchInfo) {

        if (info.buttonId == 0) {
            // Left click
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
                        isLeftButtonDown = true;
                        screen.onPointerMove(this, handlePointerMove);

                        // Update tile
                        var tiles = [].concat(layerData.tiles.original);
                        if (tiles[index] != fillValue) {
                            tiles[index] = fillValue;
                            leftButtonTileValue = fillValue;
                        }
                        else {
                            tiles[index] = emptyValue;
                            leftButtonTileValue = emptyValue;
                        }
                        layerData.tiles = tiles;

                        var layer = tilemap.layer(layerName);
                        if (layer != null) {
                            layer.contentDirty = true;
                        }
                    }
                }
            }
        }
        else if (info.buttonId == 2) {
            // Right click
        }

    }

    function handlePointerUp(info:TouchInfo) {

        if (info.buttonId == 0) {
            isLeftButtonDown = false;
            hoveredTileIndexes = null;
        }

    }

    function handlePointerMove(info:TouchInfo) {

        if (isLeftButtonDown && hoveredTileIndexes != null) {
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
                                tiles[index] = leftButtonTileValue;
                                layerData.tiles = tiles;

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