package ceramic;

import tracker.Model;

using ceramic.Extensions;

/**
 * Tilemap data.
 * Strongly inspired from Tiled TMX format.
 * (https://doc.mapeditor.org/en/stable/reference/tmx-map-format/).
 * 
 * This is a `Model` class, which make it suitable for (optional) serialization
 * and observable data.
 */
class TilemapData extends Model {

/// Main properties

    /**
     * Map orientation, can be `ORTHOGONAL`, `ISOMETRIC`, `STAGGERED` or `HEXAGONAL`.
     */
    @serialize public var orientation:TilemapOrientation = ORTHOGONAL;

    /**
     * The width of a tile
     */
    @serialize public var tileWidth:Int = -1;

    /**
     * The height of a tile
     */
    @serialize public var tileHeight:Int = -1;

    /**
     * The map width in tiles
     */
    @serialize public var width:Int = -1;

    /**
     * The map height in tiles
     */
    @serialize public var height:Int = -1;

    /**
     * The order in which tiles on tile layers are rendered.
     * In all cases, the map is drawn row-by-row.
     */
    @serialize public var renderOrder:TilemapRenderOrder = RIGHT_DOWN;

    /**
     * Only for hexagonal maps. Determines the width or height
     * (depending on the staggered axis) of the tile's edge
     */
    @serialize public var hexSideLength:Int = -1;

    /**
     * For staggered and hexagonal maps, determines which axis (x or y) is staggered.
     */
    @serialize public var staggerAxis:TilemapStaggerAxis = AXIS_X;

    /**
     * For staggered and hexagonal maps, determines whether the
     * `EVEN` or `ODD` indexes along the staggered axis are shifted.
     */
    @serialize public var staggerIndex:TilemapStaggerIndex = ODD;

    /**
     * The background color of the map.
     */
    @serialize public var backgroundColor:AlphaColor = new AlphaColor(Color.WHITE, 0);

/// Sub objects
    
    @serialize public var tilesets:Array<Tileset> = [];
    
    @serialize public var layers:Array<TilemapLayerData> = [];

/// Related asset

    public var asset:TilemapAsset;

/// Lifecycle

    override function destroy() {

        super.destroy();

        if (asset != null) {
            asset.destroy();
            asset = null;
        }

        for (i in 0...layers.length) {
            layers[i].destroy();
        }
        layers = null;
        
    }

/// Helpers

    inline public function tilesetForGid(gid:Int):Tileset {

        var t = tilesets.length - 1;
        var result:Tileset = null;
        while (t >= 0) {
            var tileset = tilesets.unsafeGet(t);
            if (gid >= tileset.firstGid) {
                result = tileset;
                break;
            }
            t--;
        }
        return result;

    }

    public function layer(name:String):TilemapLayerData {

        var layers = this.layers;
        for (i in 0...layers.length) {
            var layer = layers.unsafeGet(i);
            if (layer.name == name) {
                return layer;
            }
        }

        return null;

    }

    public function setTexturesFilter(filter:TextureFilter):Void {

        for (i in 0...tilesets.length) {
            var tileset = tilesets.unsafeGet(i);
            if (tileset.image != null) {
                if (tileset.image.texture != null) {
                    tileset.image.texture.filter = filter;
                }
            }
        }

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

    /**
     * A shorthand to set `width` and `height`
     * @param width 
     * @param height 
     */
    public function size(width:Int, height:Int):Void {
        this.width = width;
        this.height = height;
    }

/// Print

    override function toString():String {
        
        return '' + {
            orientation: orientation,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            width: width,
            height: height,
            renderOrder: renderOrder,
            hexSideLength: hexSideLength,
            staggerAxis: staggerAxis,
            staggerIndex: staggerIndex,
            backgroundColor: backgroundColor.toString(),
            tilesets: tilesets,
            layers: layers,
        }

    }

} //TilemapData