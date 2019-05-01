package ceramic;

import format.tmx.Data.TmxImage;
import format.tmx.Data.TmxBaseLayer;
import format.tmx.Data.TmxLayer;
import format.tmx.Data.TmxMap;
import format.tmx.Data.TmxTileset;
import format.tmx.Reader as TmxReader;

import ceramic.Shortcuts.*;

class TilemapParser {

    public static function parseTmx(rawTmxData:String, ?resolveTsxRawData:String->String):TmxMap {

        // First, parse TMX tilemap data
        var tmxParser = new TilemapTmxParser();
        var tmxMap = tmxParser.parseTmx(rawTmxData, resolveTsxRawData);

        if (tmxMap == null) {
            warning('Failed to parse TMX data: result is null!');
            return null;
        }

        return tmxMap;

    } //parseTmx

    public static function tmxMapToTilemapData(tmxMap:TmxMap, ?loadTexture:TmxImage->(Texture->Void)->Void):TilemapData {

        var tilemapData = new TilemapData();

        tilemapData.width = tmxMap.width;
        tilemapData.height = tmxMap.height;

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
                warning('TMX map orientation is Unknown($value), using ORTHOGONAL in TilemapData');
        }

        tilemapData.tileWidth = tmxMap.tileWidth;
        tilemapData.tileHeight = tmxMap.tileHeight;

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
                    warning('TMX map render order is Unknown($value), using RIGHT_DOWN in TilemapData');
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
                    warning('TMX map stagger axis is Unknown($value), using AXIS_X in TilemapData');
            }
        }

        tilemapData.hexSideLength = tmxMap.hexSideLength;

        if (tmxMap.tilesets != null && tmxMap.tilesets.length > 0) {
            for (i in 0...tmxMap.tilesets.length) {
                var tmxTileset = tmxMap.tilesets[i];
                var tileset = new Tileset();

                // Need to cleanup tileset when destroying related tilemap,
                // because this tileset is embedded.
                // May handle this differently later if tilesets are shared
                // across multiple tilemaps
                tilemapData.onDestroy(tileset, function() tileset.destroy());

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

                if (tmxTileset.tileOffset != null) {
                    tileset.tileOffsetX = tmxTileset.tileOffset.x;
                    tileset.tileOffsetY = tmxTileset.tileOffset.y;
                }

                if (tmxTileset.image != null) {
                    var tmxImage = tmxTileset.image;
                    var image = new TilesetImage();

                    // Need to cleanup images when destroying related tileset
                    tileset.onDestroy(image, function() image.destroy());

                    if (tmxImage.width != null) {
                        image.width = tmxImage.width;
                    }

                    if (tmxImage.height != null) {
                        image.height = tmxImage.height;
                    }

                    if (tmxImage.source != null) {
                        image.source = tmxImage.source;
                    }

                    if (loadTexture != null) {
                        (function(image:TilesetImage, tmxImage:TmxImage) {
                            loadTexture(tmxImage, function(texture:Texture) {
                                image.texture = texture;
                            });
                        })(image, tmxImage);
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
            warning('TMX map has no tileset');
        }

        if (tmxMap.layers != null && tmxMap.layers.length > 0) {
            for (i in 0...tmxMap.layers.length) {
                var tmxLayer = tmxMap.layers[i];

                inline function copyTmxLayerData(tmxLayer:TmxBaseLayer, layer:TilemapLayerData) {
                    layer.name = tmxLayer.name;
                    if (tmxLayer.x != null) layer.x = Std.int(tmxLayer.x);
                    if (tmxLayer.y != null) layer.y = Std.int(tmxLayer.y);
                    if (tmxLayer.width != null) layer.width = tmxLayer.width;
                    if (tmxLayer.height != null) layer.height = tmxLayer.height;
                    if (tmxLayer.opacity != null) layer.opacity = tmxLayer.opacity;
                    if (tmxLayer.visible != null) layer.visible = tmxLayer.visible;
                    if (tmxLayer.offsetX != null) layer.offsetX = tmxLayer.offsetX;
                    if (tmxLayer.offsetY != null) layer.offsetY = tmxLayer.offsetY;
                }

                switch (tmxLayer) {
                    case LTileLayer(_layer):
                        var layer = new TilemapLayerData();
                        copyTmxLayerData(_layer, layer);
                        if (_layer.data != null && _layer.data.tiles != null) {
                            // Ceramic tilemap tile encoding follows TMX tile encoding,
                            // so we just have to copy the array as is
                            layer.tiles = cast [].concat(_layer.data.tiles);
                        }
                        else {
                            warning('TMX tile layer has no tile');
                        }
                        tilemapData.layers.push(layer);
                        
                    case LObjectGroup(group):
                    case LImageLayer(layer):
                    case LGroup(group):
                }
            }
        }
        else {
            warning('TMX map has no layer');
        }

        return tilemapData;

    } //tmxMapToTilemapData

} //TilemapParser

@:allow(ceramic.TilemapParser)
private class TilemapTmxParser {

    private var tsx:Map<String, TmxTileset> = null;

    private var r:TmxReader = null;

    private var resolveTsxRawData:String->String = null;

    public function new() {

    } //new

    public function parseTmx(rawTmxData:String, ?resolveTsxRawData:String->String):TmxMap {

        if (rawTmxData.length == 0) {
            throw "Tilemap: rawTmxData is 0 length";
        }

        this.resolveTsxRawData = resolveTsxRawData != null ? resolveTsxRawData : (function(_) { return null; });

        try
        {
            r = new TmxReader();
            r.resolveTSX = getTsx;
            tsx = new Map();
            return r.read(Xml.parse(rawTmxData));
        }
        catch (e:Dynamic)
        {
            error(e);
        }

        return null;

    } //parse

    function getTsx(name:String):TmxTileset {

        var cached:TmxTileset = tsx.get(name);
        if (cached != null) return cached;

        cached = r.readTSX(Xml.parse(resolveTsxRawData(name)));
        tsx.set(name, cached);

        return cached;

    } //getTsx

} //TilemapParser
