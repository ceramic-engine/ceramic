package ceramic;

import tracker.Model;

using ceramic.Extensions;

#if plugin_ldtk
import ceramic.LdtkData;
#end

/**
 * Unified tilemap data structure that represents a tile-based map.
 * This format is inspired by the Tiled TMX format but provides a
 * format-agnostic representation that can be populated from various sources.
 *
 * Key features:
 * - Multi-layer support with different tile sizes per layer
 * - Multiple tilesets with automatic GID resolution
 * - Support for various map orientations (orthogonal, isometric, etc.)
 * - Observable properties for reactive updates
 * - Serializable for save/load functionality
 *
 * Ceramic's built-in tilemap visual only supports orthogonal maps,
 * but this data model supports:
 * - Orthogonal maps (standard grid-based)
 * - Isometric maps (diamond-shaped tiles)
 * - Hexagonal maps (honeycomb pattern)
 * - Staggered maps (offset rows/columns)
 *
 * This is a `Model` class from the Tracker framework, providing:
 * - Automatic serialization support
 * - Observable properties with @observe
 * - Computed properties with @compute
 * - Change notifications
 *
 * Reference: https://doc.mapeditor.org/en/stable/reference/tmx-map-format/
 *
 * @see Tilemap Visual component for rendering this data
 * @see TilemapLayerData Individual layer data
 * @see Tileset Tileset definitions
 */
class TilemapData extends Model {

    #if plugin_ldtk

    /**
     * Reference to the LDtk level this tilemap data was generated from.
     * Only set when the tilemap originates from an LDtk file.
     * Provides access to the original LDtk-specific data.
     */
    @:plugin('ldtk')
    @observe public var ldtkLevel:LdtkLevel = null;

    #end

/// Main properties

    /**
     * Optional name identifier for this tilemap.
     * Useful for debugging and when managing multiple tilemaps.
     */
    @serialize public var name:String = null;

    /**
     * Map orientation type that determines how tiles are arranged and rendered.
     *
     * - ORTHOGONAL: Standard grid layout (most common)
     * - ISOMETRIC: Diamond-shaped tiles for 2.5D appearance
     * - STAGGERED: Offset rows or columns
     * - HEXAGONAL: Hexagon-shaped tiles
     *
     * Note: Currently only ORTHOGONAL is fully supported by the renderer.
     */
    @serialize public var orientation:TilemapOrientation = ORTHOGONAL;

    /**
     * Total width of the map in pixels.
     * This is typically calculated as: columns × tileWidth
     */
    @serialize public var width:Int = -1;

    /**
     * Total height of the map in pixels.
     * This is typically calculated as: rows × tileHeight
     */
    @serialize public var height:Int = -1;

    /**
     * Determines the order in which tiles are rendered within each layer.
     * Affects which tiles appear on top when they overlap.
     *
     * - RIGHT_DOWN: Left to right, top to bottom (default)
     * - RIGHT_UP: Left to right, bottom to top
     * - LEFT_DOWN: Right to left, top to bottom
     * - LEFT_UP: Right to left, bottom to top
     */
    @serialize public var renderOrder:TilemapRenderOrder = RIGHT_DOWN;

    /**
     * For hexagonal maps only: The length of the hex tile edge in pixels.
     * This determines the size of the hexagon sides.
     * Set to -1 for non-hexagonal maps.
     */
    @serialize public var hexSideLength:Int = -1;

    /**
     * For staggered and hexagonal maps: Which axis has alternating offsets.
     * - AXIS_X: Alternating columns are offset (vertical hex)
     * - AXIS_Y: Alternating rows are offset (horizontal hex)
     */
    @serialize public var staggerAxis:TilemapStaggerAxis = AXIS_X;

    /**
     * For staggered and hexagonal maps: Which indices are shifted.
     * - ODD: Odd rows/columns are offset (1, 3, 5...)
     * - EVEN: Even rows/columns are offset (0, 2, 4...)
     */
    @serialize public var staggerIndex:TilemapStaggerIndex = ODD;

    /**
     * Background color displayed behind all map layers.
     * Includes alpha channel for transparency.
     * Default is fully transparent (alpha = 0).
     */
    @serialize public var backgroundColor:AlphaColor = new AlphaColor(Color.WHITE, 0);

    /**
     * Computes the maximum tile width across all layers.
     * Useful for allocating buffers or determining map bounds.
     *
     * Some maps may have layers with different tile sizes
     * (e.g., detail layers with smaller tiles).
     *
     * @return The largest tileWidth value from all layers, or -1 if no layers
     */
    @compute public function maxTileWidth():Int {

        var result:Int = -1;

        var layers = this.layers;
        if (layers != null) {
            for (i in 0...layers.length) {
                var layer = layers.unsafeGet(i);
                var tileWidth = layer.tileWidth;
                if (tileWidth > result)
                    result = tileWidth;
            }
        }

        return result;

    }

    /**
     * Computes the maximum tile height across all layers.
     * Useful for allocating buffers or determining map bounds.
     *
     * Some maps may have layers with different tile sizes
     * (e.g., detail layers with smaller tiles).
     *
     * @return The largest tileHeight value from all layers, or -1 if no layers
     */
    @compute public function maxTileHeight():Int {

        var result:Int = -1;

        var layers = this.layers;
        if (layers != null) {
            for (i in 0...layers.length) {
                var layer = layers.unsafeGet(i);
                var tileHeight = layer.tileHeight;
                if (tileHeight > result)
                    result = tileHeight;
            }
        }

        return result;

    }

/// Sub objects

    /**
     * Array of tilesets used by this map.
     * Tilesets define the graphics and properties for tiles.
     *
     * Ordered by firstGid (ascending) for efficient GID lookups.
     * Each tileset handles a range of global tile IDs (GIDs).
     */
    @serialize public var tilesets:Array<Tileset> = [];

    /**
     * Array of layers that make up the map.
     * Layers are rendered in array order (first = bottom).
     *
     * Each layer can be:
     * - Tile layer: Grid of tile GIDs
     * - Object layer: Positioned objects (future)
     * - Image layer: Single background image (future)
     */
    @serialize public var layers:Array<TilemapLayerData> = [];

/// Related asset

    /**
     * Reference to the TilemapAsset that loaded this data.
     * When the asset is destroyed, this data is also destroyed.
     * Set automatically by TilemapAsset during loading.
     */
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

    /**
     * Finds the tileset that contains the given global tile ID (GID).
     * GIDs are globally unique across all tilesets in the map.
     *
     * @param gid The global tile ID to look up
     * @return The tileset containing this GID, or null if not found
     */
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

    /**
     * Retrieves a layer by its name.
     * Layer names should be unique within a tilemap.
     *
     * @param name The layer name to search for
     * @return The matching layer data, or null if not found
     */
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

    /**
     * Sets the texture filtering mode for all tileset textures.
     *
     * Common values:
     * - NEAREST: Pixel-perfect rendering (recommended for pixel art)
     * - LINEAR: Smooth/blurred rendering
     *
     * @param filter The texture filter to apply to all tilesets
     */
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
     * Convenience method to set both width and height at once.
     *
     * @param width The map width in pixels
     * @param height The map height in pixels
     */
    public function size(width:Int, height:Int):Void {
        this.width = width;
        this.height = height;
    }

    /**
     * Retrieves a tileset by its name.
     * Tileset names should be unique within a tilemap.
     *
     * @param name The tileset name to search for
     * @return The matching tileset, or null if not found
     */
    public function tileset(name:String):Tileset {
        for (i in 0...tilesets.length) {
            var tileset = tilesets.unsafeGet(i);
            if (tileset.name == name) {
                return tileset;
            }
        }
        return null;
    }

/// Print

    /**
     * Returns a string representation of the tilemap data for debugging.
     * Includes all major properties but excludes detailed tile data.
     *
     * @return Debug string showing map properties
     */
    override function toString():String {

        return '' + {
            orientation: orientation,
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