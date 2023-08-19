package ceramic;

import ceramic.Shortcuts.*;
import format.tmx.Data.TmxBaseLayer;
import format.tmx.Data.TmxImage;
import format.tmx.Data.TmxImage;
import format.tmx.Data.TmxLayer;
import format.tmx.Data.TmxMap;
#if (haxe_ver >= 4)
import haxe.xml.Access as Fast;
#else
import haxe.xml.Fast;
#end

class TilemapParser {

    var tmxParser:TilemapTmxParser = null;

    #if plugin_ldtk
    var ldtkParser:TilemapLdtkParser = null;
    #end

    public function new() {}

    /**
     * Clear cached data (if any).
     * Only tileset data is cached because it can be shared between maps.
     * Normally not needed to clear manually unless working with a lot of different tilesets.
     */
    public function clearCache():Void {

        if (tmxParser != null) {
            tmxParser.clearCache();
        }

    }

    /**
     * Parse TMX Tilemap (Tiled Map Editor format)
     * @param rawTmxData Raw TMX data as string
     * @param cwd Current working directory. Needed to identify cached tileset relative to their tilemap
     * @param resolveTsxRawData A method to resolve TSX Tileset data that are not embedded in TMX data (optional)
     * @return The TMX map data
     */
    public function parseTmx(rawTmxData:String, ?cwd:String, ?resolveTsxRawData:(name:String,cwd:String)->String):TmxMap {

        // First, parse TMX tilemap data
        if (tmxParser == null) {
            tmxParser = new TilemapTmxParser();
        }
        if (cwd == null) {
            cwd = '.';
        }
        var tmxMap = tmxParser.parseTmx(rawTmxData, cwd, resolveTsxRawData);

        if (tmxMap == null) {
            log.warning('Failed to parse TMX data: result is null!');
            return null;
        }

        return tmxMap;

    }

    public function parseExternalTilesetNames(rawTmxData:String):Array<String> {

        var xml = Xml.parse(rawTmxData);

        var map:Fast = new Fast(xml).node.map;

        var result:Array<String> = [];

        for (element in map.elements)
        {
            switch (element.name)
            {
                case "tileset":
                    var input:Fast = element;
                    if (input.has.source) {
                        var source:String = input.att.source;
                        if (result.indexOf(source) == -1) {
                            result.push(source);
                        }
                    }
            }
        }

        return result;

    }

    public function tmxMapToTilemapData(tmxMap:TmxMap, ?loadTexture:(source:String, configureAsset:(asset:ImageAsset)->Void, done:(texture:Texture)->Void)->Void):TilemapData {

        var tilemapData = new TilemapData();

        tilemapData.width = tmxMap.width * tmxMap.tileWidth;
        tilemapData.height = tmxMap.height * tmxMap.tileHeight;

        switch (tmxMap.orientation) {
            case Orthogonal:
                tilemapData.orientation = ORTHOGONAL;
            case Isometric:
                tilemapData.orientation = ISOMETRIC;
            case Staggered:
                tilemapData.orientation = STAGGERED;
            case Hexagonal:
                tilemapData.orientation = HEXAGONAL;
            case Unknown(value):
                tilemapData.orientation = ORTHOGONAL;
                log.warning('TMX map orientation is Unknown($value), using ORTHOGONAL in TilemapData');
        }

        tilemapData.backgroundColor = tmxMap.backgroundColor;

        if (tmxMap.renderOrder != null) {
            switch (tmxMap.renderOrder) {
                case RightDown:
                    tilemapData.renderOrder = RIGHT_DOWN;
                case RightUp:
                    tilemapData.renderOrder = RIGHT_UP;
                case LeftDown:
                    tilemapData.renderOrder = LEFT_DOWN;
                case LeftUp:
                    tilemapData.renderOrder = LEFT_UP;
                case Unknown(value):
                    tilemapData.renderOrder = RIGHT_DOWN;
                    log.warning('TMX map render order is Unknown($value), using RIGHT_DOWN in TilemapData');
            }
        }

        if (tmxMap.staggerAxis != null) {
            switch (tmxMap.staggerAxis) {
                case AxisX:
                    tilemapData.staggerAxis = AXIS_X;
                case AxisY:
                    tilemapData.staggerAxis = AXIS_Y;
                case Unknown(value):
                    tilemapData.staggerAxis = AXIS_X;
                    log.warning('TMX map stagger axis is Unknown($value), using AXIS_X in TilemapData');
            }
        }

        tilemapData.hexSideLength = tmxMap.hexSideLength;

        if (tmxMap.tilesets != null && tmxMap.tilesets.length > 0) {
            for (i in 0...tmxMap.tilesets.length) {
                var tmxTileset = tmxMap.tilesets[i];
                var tileset = new Tileset();

                // Need to cleanup tileset when destroying related tilemap
                tilemapData.onDestroy(tileset, function(_) {
                    tileset.destroy();
                });

                if (tmxTileset.firstGID != null) {
                    tileset.firstGid = tmxTileset.firstGID;
                }

                if (tmxTileset.name != null) {
                    tileset.name = tmxTileset.name;
                }

                if (tmxTileset.tileWidth != null) {
                    tileset.tileWidth = tmxTileset.tileWidth;
                }

                if (tmxTileset.tileHeight != null) {
                    tileset.tileHeight = tmxTileset.tileHeight;
                }

                if (tmxTileset.spacing != null) {
                    tileset.spacing = tmxTileset.spacing;
                }

                if (tmxTileset.margin != null) {
                    tileset.margin = tmxTileset.margin;
                }

                tileset.tileCount = tmxTileset.tileCount;

                tileset.columns = tmxTileset.columns;

                if (tmxTileset.image != null) {
                    var tmxImage = tmxTileset.image;
                    var image = new TilesetImage();

                    // Need to cleanup images when destroying related tileset
                    tileset.onDestroy(image, function(_) image.destroy());

                    if (tmxImage.width != null) {
                        image.width = tmxImage.width;
                    }

                    if (tmxImage.height != null) {
                        image.height = tmxImage.height;
                    }

                    if (tmxImage.source != null) {
                        image.source = tmxImage.source;

                        if (loadTexture != null) {
                            (function(image:TilesetImage, source:String) {
                                loadTexture(source, null, function(texture:Texture) {
                                    image.texture = texture;
                                });
                            })(image, tmxImage.source);
                        }
                    }
                    else if (tmxImage.data != null) {
                        log.warning('Loading TMX embedded images is not supported.');
                    }

                    tileset.image = image;

                    if (tileset.columns <= 0) {
                        // If needed, compute tileset columns from image
                        var cols = 0;
                        var usedWidth = 0;
                        var computedTileWidth = tileset.tileWidth + tileset.margin * 2;
                        if (computedTileWidth > 0) {
                            while (usedWidth + computedTileWidth <= image.width) {
                                cols++;
                                usedWidth += computedTileWidth + tileset.spacing;
                            }
                        }
                        tileset.columns = cols;
                    }
                }

                tilemapData.tilesets.push(tileset);
            }
        }
        else {
            log.warning('TMX map has no tileset');
        }

        if (tmxMap.layers != null && tmxMap.layers.length > 0) {
            for (i in 0...tmxMap.layers.length) {
                var tmxLayer = tmxMap.layers[i];

                inline function copyTmxLayerData(tmxLayer:TmxBaseLayer, layer:TilemapLayerData) {
                    layer.name = tmxLayer.name;
                    if (tmxLayer.x != null) layer.x = Std.int(tmxLayer.x);
                    if (tmxLayer.y != null) layer.y = Std.int(tmxLayer.y);
                    if (tmxLayer.width != null) layer.columns = tmxLayer.width;
                    if (tmxLayer.height != null) layer.rows = tmxLayer.height;
                    if (tmxLayer.opacity != null) layer.opacity = tmxLayer.opacity;
                    if (tmxLayer.visible != null) layer.visible = tmxLayer.visible;
                    if (tmxLayer.offsetX != null) layer.offsetX = tmxLayer.offsetX;
                    if (tmxLayer.offsetY != null) layer.offsetY = tmxLayer.offsetY;
                }

                switch (tmxLayer) {
                    case LTileLayer(_layer):
                        var layer = new TilemapLayerData();

                        // Tiled doesn't support layers with different tile size,
                        // so we simply use the same tile size of the map itself
                        // for each layer!
                        layer.tileWidth = tmxMap.tileWidth;
                        layer.tileHeight = tmxMap.tileHeight;

                        copyTmxLayerData(_layer, layer);
                        if (_layer.data != null && _layer.data.tiles != null) {
                            // Ceramic tilemap tile encoding follows TMX tile encoding,
                            // so we just have to copy the array as is
                            layer.tiles = cast [].concat(_layer.data.tiles);
                        }
                        else {
                            log.warning('TMX tile layer ${_layer.name} has no tile');
                        }
                        tilemapData.layers.push(layer);

                    case LObjectGroup(group):
                    case LImageLayer(layer):
                    case LGroup(group):
                }
            }
        }
        else {
            log.warning('TMX map has no layer');
        }

        return tilemapData;

    }

#if plugin_ldtk

    /**
     * Parse LDtk file
     * @param rawLdtkData Raw LDtk data as string
     * @return The LDtk parsed data
     */
    public function parseLdtk(rawLdtkData:String, loadExternalLdtkLevelData:(source:String, callback:(rawLevelData:String)->Void)->Void):LdtkData {

        // Parse LDtk data
        if (ldtkParser == null) {
            ldtkParser = new TilemapLdtkParser();
        }
        var ldtkData = ldtkParser.parseLdtk(rawLdtkData, loadExternalLdtkLevelData);

        if (ldtkData == null) {
            log.warning('Failed to parse LDtk data: result is null!');
            return null;
        }

        return ldtkData;

    }

    public function loadLdtkTilemaps(ldtkData:LdtkData, ?loadTexture:(source:String, configureAsset:(asset:ImageAsset)->Void, done:(texture:Texture)->Void)->Void, skip:Array<String>):Void {

        if (ldtkParser == null) {
            ldtkParser = new TilemapLdtkParser();
        }

        ldtkParser.loadLdtkTilemaps(ldtkData, loadTexture, skip);

    }

#end

}
