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
        var nextFirstGid = 1;
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

                    tilemapData.backgroundColor = level.bgColor.toAlphaColor();
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

                        var tilemapLayerData = new TilemapLayerData();

                        tilemapLayerData.name = layerInstance.def.identifier;
                        tilemapLayerData.tileWidth = layerInstance.def.gridSize;
                        tilemapLayerData.tileHeight = layerInstance.def.gridSize;
                        tilemapLayerData.opacity = layerInstance.opacity;
                        tilemapLayerData.extraOpacity = layerInstance.opacity;
                        tilemapLayerData.offsetX = layerInstance.pxTotalOffsetX;
                        tilemapLayerData.offsetY = layerInstance.pxTotalOffsetY;
                        tilemapLayerData.visible = layerInstance.visible;
                        tilemapLayerData.columns = layerInstance.cWid;
                        tilemapLayerData.rows = layerInstance.cHei;

                        tilemapLayerData.shouldRenderTiles = (layerInstance.tileset != null);

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
                            case Entities:
                                // Do not assign tiles
                        }

                        tilemapLayers.push(tilemapLayerData);
                        layerInstance.ceramicLayer = tilemapLayerData;
                        tilemapLayerData.ldtkLayer = layerInstance;

                        k--;
                    }

                    // Tilesets must be ordered by first gid
                    usedTilesets.sort((a, b) -> {
                        return a.firstGid - b.firstGid;
                    });

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
        var needsCleanup:Bool = false;

        for (n in 0...numTiles) {
            result[n] = 0;
        }

        while (i < end) {

            var tileId:Int = ldtkTiles[i];
            var flipBits:Int = ldtkTiles[i + 1];
            var col:Int = Math.round(ldtkTiles[i + 2] * 1.0 / gridSize);
            var row:Int = Math.round(ldtkTiles[i + 3] * 1.0 / gridSize);

            if (col >= 0 && col < cols && row >= 0 && row < rows) {
                // Some tiles generated by LDtk could be out of bounds,
                // that is why we check that the computed col & row
                // is within those bounds before proceeding

                var tile:TilemapTile = 0;
                tile.gid = (firstGid + tileId);
                tile.horizontalFlip = (flipBits & 1 != 0);
                tile.verticalFlip = (flipBits & 2 != 0);

                var averageColor = tileset.averageColor(tileId);
                var isOpaque = averageColor != AlphaColor.NONE && averageColor.alpha == 0xFF;

                var index = row * cols + col;
                if (isOpaque) {
                    // Stacking opaque tile, so we can discard any tile behind
                    var indexAbove = index + numTiles;
                    while (indexAbove < result.length) {
                        needsCleanup = true;
                        result[indexAbove] = 0;
                        indexAbove += numTiles;
                    }
                }
                else {
                    // Stacking translucent tile
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
                }

                result[index] = tile;
            }

            i += 6;
        }

        // In case we stacked opaque tiles, we might need to remove unused space in array
        if (needsCleanup) {
            i = result.length - 1;
            var steps:Int = 0;

            while (i >= numTiles) {
                if (result[i] != 0) {
                    break;
                }
                steps++;
                if (steps == numTiles) {
                    steps = 0;
                    result.setArrayLength(i);
                }
                i--;
            }
        }

        return result;

    }

}
