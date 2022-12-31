package ceramic;

import ceramic.Assert.assert;
import tracker.Model;

using ceramic.Extensions;

class Tileset extends Model {

    /**
     * First global id. Maps to the first tile in this tileset.
     */
    @serialize public var firstGid:Int = 0;

    /**
     * The name of this tileset
     */
    @serialize public var name:String = null;

    /**
     * The (maximum) width of tiles in this tileset
     */
    @serialize public var tileWidth:Int = -1;

    /**
     * The (maximum) height of tiles in this tileset
     */
    @serialize public var tileHeight:Int = -1;

    /**
     * The spacing between tiles in this tileset
     */
    @serialize public var spacing:Int = 0;

    /**
     * The margin around the tiles in this tileset
     */
    @serialize public var margin:Int = 0;

    /**
     * The number of tiles in this tileset
     */
    @serialize public var tileCount:Int = 0;

    /**
     * The number of tile columns in this tileset
     */
    @serialize public var columns:Int = 0;

    /**
     * Horizontal offset. Used to specify an offset to be applied when drawing a tile.
     */
    @serialize public var tileOffsetX:Int = 0;

    /**
     * Vertical offset. Used to specify an offset to be applied when drawing a tile.
     */
    @serialize public var tileOffsetY:Int = 0;

    /**
     * The image used to display tiles in this tileset
     */
    @serialize public var image(default, set):TilesetImage = null;
    function set_image(image:TilesetImage):TilesetImage {
        if (image != this.image) {
            var prevImage = this.image;
            this.image = image;
            if (implicitImage && prevImage != null) {
                prevImage.destroy();
            }
            implicitImage = false;
        }
        return image;
    }

    /**
     * Orientation of the grid for the tiles in this tileset.
     * Only used in case of isometric orientation,
     * to determine how tile overlays for terrain an collision information are rendered.
     */
    @serialize public var gridOrientation:TilesetGridOrientation = ORTHOGONAL;

    /**
     * Width of a grid cell.
     * Only used in case of isometric orientation,
     * to determine how tile overlays for terrain an collision information are rendered.
     */
    @serialize public var gridCellWidth:Int = 0;

    /**
     * Height of a grid cell.
     * Only used in case of isometric orientation,
     * to determine how tile overlays for terrain an collision information are rendered.
     */
    @serialize public var gridCellHeight:Int = 0;

    /**
     * A mapping to access a given slope by it's tile index
     * without having to walk through the whole slope array
     */
    var slopesMapping:IntIntMap = null;

    /**
     * Internal: `true` if TilesetImage instance was created
     * implicitly from assigning a texture object.
     */
    var implicitImage:Bool = false;

    /**
     * The texture used to display tiles in this tileset.
     * This is a shorthand of `image.texture`
     */
    public var texture(get, set):Texture;
    inline function get_texture():Texture {
        return image != null ? unobservedImage.texture : null;
    }
    function set_texture(texture:Texture):Texture {
        if (texture != null) {
            if (unobservedImage == null || unobservedImage.texture != texture) {
                unobservedImage = new TilesetImage();
                implicitImage = true;
                unobservedImage.texture = texture;
            }
        }
        else {
            unobservedImage = null;
            implicitImage = false;
        }
        return texture;
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

/// Slopes

    /**
     * Slopes in this tileset or null if there is no slope.
     */
    @serialize public var slopes(default, set):ReadOnlyArray<TileSlope> = null;
    function set_slopes(slopes:ReadOnlyArray<TileSlope>):ReadOnlyArray<TileSlope> {
        if (this.slopes != slopes) {
            this.slopes = slopes;
            slopesMapping = null; // Slope mapping needs to be rebuilt at next query
        }
        return slopes;
    }

    /**
     * Add a slope to this tileset.
     */
    public extern inline overload function slope(slope:TileSlope):Void {
        _setSlope(slope.index, slope);
    }

    /**
     * Assign a slope to a given tile index.
     */
    public extern inline overload function slope(index:Int, slope:TileSlope):Void {
        if (slope != null)
            _setSlope(index, slope);
        else
            _removeSlope(index);
    }

    /**
     * Get a slope from a tile index or assign a slope to a given tile index.
     */
    public extern inline overload function slope(index:Int):TileSlope {
        return _getSlope(index);
    }

    function _setSlope(index:Int, slope:TileSlope) {

        assert(index >= 0, 'Invalid slope index: $index');

        if (slope.index != index) {
            slope = {
                index: index,
                y0: slope.y0,
                y1: slope.y1,
                rotation: slope.rotation
            };
        }

        var arrayIndex = -1;

        if (slopesMapping == null) {
            _buildSlopesMapping();
        }

        arrayIndex = slopesMapping.get(index) - 1;

        if (arrayIndex == -1) {
            arrayIndex = slopes.length;

            var nPlus1 = arrayIndex + 1;
            slopesMapping.set(index, nPlus1);
        }

        slopes.original[arrayIndex] = slope;
        dirty = true;

    }

    function _buildSlopesMapping() {

        var slopes = this.slopes;

        if (slopes != null) {
            slopesMapping = new IntIntMap();
            for (i in 0...slopes.length) {
                var slope = slopes.unsafeGet(i);
                if (slope != null) {
                    var iPlus1 = i + 1;
                    slopesMapping.set(slope.index, iPlus1);
                }
            }
        }
        else {
            if (slopesMapping != null)
                slopesMapping = null;
        }

    }

    function _removeSlope(index:Int) {

        if (slopesMapping != null) {
            var arrayIndex = slopesMapping.get(index) - 1;
            if (arrayIndex != -1) {
                slopesMapping.remove(index);
                slopes.original.splice(arrayIndex, 1);
                dirty = true;
            }
        }

    }

    function _getSlope(tileIndex:Int):TileSlope {

        if (slopes == null)
            return null;

        if (slopesMapping == null)
            _buildSlopesMapping();

        var arrayIndex = slopesMapping.get(tileIndex) - 1;

        if (arrayIndex != -1) {
            return slopes.unsafeGet(arrayIndex);
        }

        return null;

    }

/// Lifecycle

    override function destroy() {

        // To unbind tileset image/texture events
        image = null;

        super.destroy();

    }

}
