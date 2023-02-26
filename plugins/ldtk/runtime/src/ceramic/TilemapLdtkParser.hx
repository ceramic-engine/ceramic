package ceramic;

import ceramic.LdtkData.LdtkTilesetDefinition;
import ceramic.Shortcuts.*;
import haxe.Json;

using ceramic.Extensions;

@:noCompletion
class TilemapLdtkParser {

    public function new() {

    }

    public function parseLdtk(rawLdtkData:String):LdtkData {

        var ldtkData:LdtkData = null;

        try {
            return new LdtkData(Json.parse(rawLdtkData));
        }
        catch (e:Dynamic) {
            log.error('Failed to parse raw LDtk data: ' + e);
            ldtkData = null;
        }

        return ldtkData;

    }

    public function loadLdtkTilemaps(ldtkData:LdtkData, ?loadTexture:(source:String, (texture:Texture)->Void)->Void):Void {

        if (ldtkData.externalLevels) {
            log.info('This LDtk project uses external levels');
            return;
        }

        // Parse tilesets
        var nextFirstGid = 0;
        var ceramicTilesets = [];
        if (ldtkData.defs.tilesets != null && ldtkData.defs.tilesets.length > 0) {
            var tilesetDefs = ldtkData.defs.tilesets;
            for (i in 0...tilesetDefs.length) {
                var ldtkTileset = tilesetDefs[i];
                var tileset = new Tileset();

                // LDtk doesn't have this notion of global tile id (gid)
                // and tileset "first gid", so we'll have to convert the
                // data to be compatible because that's what Ceramic needs.
                tileset.firstGid = nextFirstGid;

                tileset.name = ldtkTileset.identifier;
                tileset.tileWidth = ldtkTileset.tileGridSize;
                tileset.tileHeight = ldtkTileset.tileGridSize;
                tileset.spacing = ldtkTileset.spacing;
                tileset.margin = ldtkTileset.padding;
                tileset.tileCount = ldtkTileset.cWid * ldtkTileset.cHei;
                tileset.columns = ldtkTileset.cWid;

                if (ldtkTileset.relPath != null) {
                    var image = new TilesetImage();

                    // Need to cleanup images when destroying related tileset
                    tileset.onDestroy(image, function(_) image.destroy());

                    image.width = ldtkTileset.pxWid;
                    image.height = ldtkTileset.pxHei;
                    image.source = ldtkTileset.relPath;

                    if (loadTexture != null) {
                        (function(image:TilesetImage, source:String) {
                            loadTexture(source, function(texture:Texture) {
                                image.texture = texture;
                            });
                        })(image, ldtkTileset.relPath);
                    }

                    tileset.image = image;
                }

                ldtkTileset.ceramicTileset = tileset;
                tileset.ldtkTileset = ldtkTileset;
                nextFirstGid += tileset.tileCount;

                ceramicTilesets.push(tileset);
            }
        }
        else {
            log.warning('LDtk data has no tileset');
        }

        if (ldtkData.worlds != null && ldtkData.worlds.length > 0) {
            for (i in 0...ldtkData.worlds.length) {
                var world = ldtkData.worlds[i];

                for (j in 0...world.levels.length) {
                    var level = world.levels[j];

                    var tilemapData = new TilemapData();
                    var usedTilesets:Array<Tileset> = [];

                    tilemapData.backgroundColor = level.bgColor;
                    tilemapData.renderOrder = RIGHT_DOWN;
                    tilemapData.name = level.identifier;
                    tilemapData.width = level.pxWid;
                    tilemapData.height = level.pxHei;

                    // TODO bgPos + bgRelPath?

                    var tilemapLayers = [];
                    var tilemapWidth:Int = 0;
                    var tilemapHeight:Int = 0;
                    var k = level.layerInstances.length - 1;
                    while (k >= 0) {
                        var layerInstance = level.layerInstances[k];
                        var createTilemapLayer:Bool = switch layerInstance.def.type {
                            case IntGrid: layerInstance.tileset != null;
                            case Entities: false;
                            case Tiles: layerInstance.tileset != null;
                            case AutoLayer: layerInstance.tileset != null;
                        }

                        if (createTilemapLayer) {

                            var tilemapLayerData = new TilemapLayerData();

                            tilemapLayerData.name = layerInstance.def.identifier;
                            tilemapLayerData.tileWidth = layerInstance.def.gridSize;
                            tilemapLayerData.tileHeight = layerInstance.def.gridSize;
                            tilemapLayerData.opacity = layerInstance.opacity;
                            tilemapLayerData.extraOpacity = layerInstance.opacity;
                            tilemapLayerData.offsetX = layerInstance.pxOffsetX;
                            tilemapLayerData.offsetY = layerInstance.pxOffsetY;
                            tilemapLayerData.visible = layerInstance.visible;
                            tilemapLayerData.columns = layerInstance.cWid;
                            tilemapLayerData.rows = layerInstance.cHei;

                            if (layerInstance.tileset != null && layerInstance.tileset.ceramicTileset != null && usedTilesets.indexOf(layerInstance.tileset.ceramicTileset) == -1) {
                                usedTilesets.push(layerInstance.tileset.ceramicTileset);
                            }

                            switch layerInstance.def.type {
                                case Tiles:
                                    tilemapLayerData.tiles = convertLdtkTiles(layerInstance.gridTiles, layerInstance.tileset, layerInstance.cWid, layerInstance.cHei, layerInstance.def.gridSize);
                                case IntGrid | AutoLayer:
                                    if (layerInstance.def.autoSourceLayerDefUid != -1) {
                                        var autoSourceLayer = null;
                                        for (l in 0...level.layerInstances.length) {
                                            var aLayer = level.layerInstances[l];
                                            if (aLayer.def.uid == layerInstance.def.autoSourceLayerDefUid) {
                                                autoSourceLayer = aLayer;
                                                break;
                                            }
                                        }
                                        if (autoSourceLayer == null) {
                                            log.warning('Failed to resolve auto source layer for: ' + layerInstance.def.identifier);
                                        }
                                        tilemapLayerData.tiles = [].concat(autoSourceLayer.intGrid);
                                    }
                                    else {
                                        tilemapLayerData.tiles = [].concat(layerInstance.intGrid);
                                    }
                                    tilemapLayerData.computedTiles = convertLdtkTiles(layerInstance.autoLayerTiles, layerInstance.tileset, layerInstance.cWid, layerInstance.cHei, layerInstance.def.gridSize);
                                case _:
                            }

                            tilemapLayers.push(tilemapLayerData);
                            layerInstance.ceramicLayer = tilemapLayerData;
                            tilemapLayerData.ldtkLayer = layerInstance;
                        }

                        k--;
                    }

                    tilemapData.tilesets = usedTilesets;
                    tilemapData.layers = tilemapLayers;

                    level.ceramicTilemap = tilemapData;
                    tilemapData.ldtkLevel = level;
                }

            }
        }
        else {
            log.warning('LDtk data has no world');
        }

    }

    function convertLdtkTiles(ldtkTiles:Array<Int>, tileset:LdtkTilesetDefinition, cols:Int, rows:Int, gridSize:Int):Array<TilemapTile> {

        var result:Array<TilemapTile> = [];
        var firstGid:Int = tileset != null && tileset.ceramicTileset != null ? tileset.ceramicTileset.firstGid : 0;
        var i:Int = 0;
        var end:Int = ldtkTiles.length - 5;
        var numTiles:Int = cols * rows;

        for (n in 0...numTiles) {
            result[n] = 0;
        }

        while (i < end) {

            var tileId:Int = ldtkTiles[i];
            var flipBits:Int = ldtkTiles[i + 1];
            var col:Int = Math.round(ldtkTiles[i + 2] * 1.0 / gridSize);
            var row:Int = Math.round(ldtkTiles[i + 3] * 1.0 / gridSize);

            var tile:TilemapTile = 0;
            tile.gid = (firstGid + tileId);
            tile.horizontalFlip = (flipBits == 1 || flipBits == 3);
            tile.verticalFlip = (flipBits == 2 || flipBits == 3);

            var index = row * cols + col;
            while (result[index] != 0) {
                index += numTiles;
                if (index >= result.length) {
                    var start:Int = result.length;
                    var end:Int = start + numTiles;
                    for (n in start...end) {
                        result[n] = 0;
                    }
                }
            }

            result[index] = tile;

            i += 6;
        }

        return result;

    }

}