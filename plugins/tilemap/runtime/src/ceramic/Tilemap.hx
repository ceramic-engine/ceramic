package ceramic;

using ceramic.Extensions;

/**
 * A visual component that renders tilemap data composed of multiple layers.
 * Tilemaps are grid-based maps commonly used in 2D games for rendering
 * backgrounds, levels, and collision data.
 *
 * Features:
 * - Multi-layer rendering with depth control
 * - Tile clipping for culling optimization
 * - Collision detection support (with arcade plugin)
 * - Automatic layer management from TilemapData
 * - Per-layer and per-tilemap scaling
 *
 * Currently only supports ORTHOGONAL tile orientation. Other orientations
 * like isometric or hexagonal are not implemented.
 *
 * ## Usage Example:
 * ```haxe
 * var tilemap = new Tilemap();
 * tilemap.tilemapData = assets.tilemap("level1").tilemapData;
 * tilemap.pos(0, 0);
 * scene.add(tilemap);
 *
 * // Access specific layer
 * var collisionLayer = tilemap.layer("collision");
 *
 * // Enable collision detection (arcade plugin)
 * tilemap.collidableLayers = ["collision", "walls"];
 * ```
 *
 * @see TilemapData The data structure containing tilemap information
 * @see TilemapLayer Individual layer rendering component
 * @see TilemapAsset Asset type for loading tilemap files
 */
class Tilemap extends Quad {

    /**
     * Event fired when a layer visual is created for this tilemap.
     * Useful for customizing layer properties immediately after creation.
     *
     * @param tilemap The tilemap creating the layer
     * @param layer The newly created layer visual
     */
    @event function createLayer(tilemap:Tilemap, layer:TilemapLayer);

/// Properties

    /**
     * Controls pixel rounding for tile positioning.
     *
     * Values:
     * - 0: No rounding (tiles can be positioned at sub-pixel positions)
     * - 1: Round to nearest pixel (default, prevents tile seams)
     * - 2+: Round to nearest multiple of this value
     *
     * Pixel rounding helps prevent visual artifacts like gaps between tiles
     * when rendering at non-integer positions or scales.
     */
    public var roundTilesTranslation(default,set):Int = 1;
    function set_roundTilesTranslation(roundTilesTranslation:Int):Int {
        if (this.roundTilesTranslation == roundTilesTranslation) return roundTilesTranslation;
        this.roundTilesTranslation = roundTilesTranslation;
        contentDirty = true;
        for (i in 0...layers.length) {
            var layer = layers.unsafeGet(i);
            layer.contentDirty = true;
        }
        return roundTilesTranslation;
    }

    /**
     * The tilemap data to render. Contains layer information, tilesets,
     * and tile placement data. Setting this property triggers a complete
     * rebuild of the tilemap's visual layers.
     *
     * When null, the tilemap renders nothing and has zero size.
     */
    public var tilemapData(default,set):TilemapData = null;
    function set_tilemapData(tilemapData:TilemapData):TilemapData {
        if (this.tilemapData == tilemapData) return tilemapData;
        this.tilemapData = tilemapData;
        contentDirty = true;
        #if plugin_arcade
        collidableLayersDirty = true;
        #end
        for (i in 0...layers.length) {
            var layer = layers.unsafeGet(i);
            layer.contentDirty = true;
        }
        return tilemapData;
    }

    /**
     * Global scale factor applied to all tiles in the tilemap.
     * This scales the visual size of tiles without affecting the
     * logical grid dimensions.
     *
     * Special values:
     * - 1.0: Normal size (default)
     * - -1: Disables scale propagation to layers
     *
     * This is useful for implementing zoom or creating tilemaps
     * with different visual scales while maintaining the same data.
     */
    public var tileScale(default,set):Float = 1.0;
    function set_tileScale(tileScale:Float):Float {
        if (this.tileScale == tileScale) return tileScale;
        this.tileScale = tileScale;
        if (tileScale != -1) {
            for (i in 0...layers.length) {
                layers.unsafeGet(i).tileScale = tileScale;
            }
        }
        return tileScale;
    }

    /**
     * X coordinate (in tiles) where tile clipping begins.
     * Tiles outside the clipping rectangle are not rendered.
     *
     * Set to -1 to disable clipping on this axis (default).
     * Used for culling optimization in large tilemaps.
     */
    public var clipTilesX(default,set):Float = -1;
    function set_clipTilesX(clipTilesX:Float):Float {
        if (this.clipTilesX == clipTilesX) return clipTilesX;
        this.clipTilesX = clipTilesX;
        contentDirty = true;
        for (i in 0...layers.length) {
            var layer = layers.unsafeGet(i);
            layer.contentDirty = true;
        }
        return clipTilesX;
    }

    /**
     * Y coordinate (in tiles) where tile clipping begins.
     * Tiles outside the clipping rectangle are not rendered.
     *
     * Set to -1 to disable clipping on this axis (default).
     * Used for culling optimization in large tilemaps.
     */
    public var clipTilesY(default,set):Float = -1;
    function set_clipTilesY(clipTilesY:Float):Float {
        if (this.clipTilesY == clipTilesY) return clipTilesY;
        this.clipTilesY = clipTilesY;
        contentDirty = true;
        for (i in 0...layers.length) {
            var layer = layers.unsafeGet(i);
            layer.contentDirty = true;
        }
        return clipTilesY;
    }

    /**
     * Width (in tiles) of the clipping rectangle.
     * Only tiles within this width from clipTilesX are rendered.
     *
     * Set to -1 to disable width clipping (default).
     * Used for culling optimization in large tilemaps.
     */
    public var clipTilesWidth(default,set):Float = -1;
    function set_clipTilesWidth(clipTilesWidth:Float):Float {
        if (this.clipTilesWidth == clipTilesWidth) return clipTilesWidth;
        this.clipTilesWidth = clipTilesWidth;
        contentDirty = true;
        for (i in 0...layers.length) {
            var layer = layers.unsafeGet(i);
            layer.contentDirty = true;
        }
        return clipTilesWidth;
    }

    /**
     * Height (in tiles) of the clipping rectangle.
     * Only tiles within this height from clipTilesY are rendered.
     *
     * Set to -1 to disable height clipping (default).
     * Used for culling optimization in large tilemaps.
     */
    public var clipTilesHeight(default,set):Float = -1;
    function set_clipTilesHeight(clipTilesHeight:Float):Float {
        if (this.clipTilesHeight == clipTilesHeight) return clipTilesHeight;
        this.clipTilesHeight = clipTilesHeight;
        contentDirty = true;
        for (i in 0...layers.length) {
            var layer = layers.unsafeGet(i);
            layer.contentDirty = true;
        }
        return clipTilesHeight;
    }

    /**
     * Array of TilemapLayer visuals managed by this tilemap.
     * Layers are automatically created, updated, and destroyed
     * based on the tilemapData. Direct manipulation is not recommended.
     *
     * Use the `layer(name)` method to access specific layers by name.
     */
    public var layers:Array<TilemapLayer> = [];

/// Overrides

    override function get_width():Float {
        if (contentDirty) computeContent();
        return super.get_width();
    }

    override function get_height():Float {
        if (contentDirty) computeContent();
        return super.get_height();
    }

/// Lifecycle

    public function new() {

        super();

        transparent = true;

    }

    override function destroy() {

        var layers = this.layers;
        if (layers != null) {
            layers = [].concat(layers);
            for (i in 0...layers.length) {
                var layer = layers.unsafeGet(i);
                layer.destroy();
            }
        }

        super.destroy();

    }

/// Display

    /**
     * Computes the tilemap's visual content based on its data.
     * This method:
     * - Sets the tilemap size from data dimensions
     * - Applies background color if specified
     * - Creates or updates layer visuals
     * - Removes unused layers
     */
    override function computeContent() {

        if (tilemapData == null) {
            width = 0;
            height = 0;
            transparent = true;
            color = Color.WHITE;
            contentDirty = false;
            return;
        }

        // Update size
        size(
            tilemapData.width,
            tilemapData.height
        );

        if (tilemapData.backgroundColor != AlphaColor.NONE && tilemapData.backgroundColor.alpha > 0) {
            transparent = false;
            alpha = tilemapData.backgroundColor.alphaFloat;
            color = tilemapData.backgroundColor.rgb;
        }
        else {
            transparent = true;
            color = Color.WHITE;
        }

        computeLayers();

        contentDirty = false;

    }

    /**
     * Creates, updates, or removes layer visuals to match the tilemap data.
     * Ensures each data layer has a corresponding visual layer and removes
     * any visual layers that no longer have data.
     *
     * Fires the `createLayer` event for newly created layers.
     */
    function computeLayers() {

        var usedLayers = 0;
        var tileScale = this.tileScale;

        for (l in 0...tilemapData.layers.length) {
            var layerData = tilemapData.layers.unsafeGet(l);
            var isNew = false;

            var layer:TilemapLayer = usedLayers < layers.length ? layers[usedLayers] : null;
            if (layer == null) {
                isNew = true;
                layer = new TilemapLayer();
                layer.tilemap = this;
                if (tileScale != -1) layer.tileScale = tileScale;
                layer.depthRange = 1;
                layers.push(layer);
                add(layer);
            }
            usedLayers++;

            if (layerData.explicitDepth != null) {
                layer.depth = layerData.explicitDepth;
            }
            else {
                layer.depth = l + 1;
            }
            layer.layerData = layerData;

            if (isNew)
                emitCreateLayer(this, layer);
        }

        // Remove unused layers
        while (usedLayers < layers.length) {
            var layer = layers.pop();
            layer.destroy();
        }

    }

/// Clip

    /**
     * Sets the tile clipping rectangle in a single call.
     * Tiles outside this rectangle are not rendered, improving
     * performance for large tilemaps where only a portion is visible.
     *
     * @param clipTilesX Starting X position in tiles (-1 to disable)
     * @param clipTilesY Starting Y position in tiles (-1 to disable)
     * @param clipTilesWidth Width in tiles (-1 to disable)
     * @param clipTilesHeight Height in tiles (-1 to disable)
     */
    public function clipTiles(clipTilesX, clipTilesY, clipTilesWidth, clipTilesHeight) {

        this.clipTilesX = clipTilesX;
        this.clipTilesY = clipTilesY;
        this.clipTilesWidth = clipTilesWidth;
        this.clipTilesHeight = clipTilesHeight;

    }

/// Helpers

    /**
     * Retrieves a layer by its name as defined in the tilemap data.
     * Returns null if no layer with the given name exists.
     *
     * @param name The layer name to search for
     * @return The TilemapLayer visual, or null if not found
     */
    public function layer(name:String):TilemapLayer {

        if (contentDirty)
            computeContent();

        for (i in 0...layers.length) {
            var layer = layers.unsafeGet(i);
            var layerData = layer.layerData;
            if (layerData != null && layerData.name == name)
                return layer;
        }

        return null;

    }

#if plugin_arcade

/// Arcade physics

    /**
     * Temporary array for tracking layers during collision updates.
     */
    static var _layers:Array<TilemapLayer> = [];

    /**
     * Array of layer names that should be used for collision detection.
     * Only layers whose names are in this array will participate in
     * physics collisions when using the arcade physics plugin.
     *
     * Example: `["collision", "walls", "platforms"]`
     */
    public var collidableLayers(default, set):ReadOnlyArray<String> = null;
    function set_collidableLayers(collidableLayers:ReadOnlyArray<String>):ReadOnlyArray<String> {
        if (this.collidableLayers == collidableLayers) return collidableLayers;
        this.collidableLayers = collidableLayers;
        collidableLayersDirty = true;
        return collidableLayers;
    }

    /**
     * Computed array of TilemapLayer instances that are marked as collidable.
     * Automatically updated when collidableLayers changes.
     */
    public var computedCollidableLayers(default, null):ReadOnlyArray<TilemapLayer> = null;

    /**
     * Internal flag indicating collidable layers need recomputation.
     */
    public var collidableLayersDirty:Bool = false;

    /**
     * When true, physics bodies are destroyed for tiles that are no longer
     * in collidable layers. This frees memory but has a performance cost.
     *
     * When false, physics bodies are kept even when layers become non-collidable,
     * trading memory for performance.
     */
    public var destroyUnusedBodies(default, set):Bool = false;
    function set_destroyUnusedBodies(destroyUnusedBodies:Bool):Bool {
        if (this.destroyUnusedBodies != destroyUnusedBodies) {
            this.destroyUnusedBodies = destroyUnusedBodies;
            collidableLayersDirty = true;
        }
        return destroyUnusedBodies;
    }

    /**
     * Computes which layers should be used for collision detection.
     * Called internally by the arcade physics system when needed.
     *
     * Matches layer names in collidableLayers array with actual layers
     * and marks them as collidable. Optionally cleans up physics bodies
     * on layers that are no longer collidable.
     */
    @:allow(ceramic.ArcadeWorld)
    function computeCollidableLayers():Void {

        if (contentDirty)
            computeContent();

        var result:Array<TilemapLayer> = null;
        var len = layers.length;

        // Keep track of layers already collidable if needed
        if (destroyUnusedBodies) {
            for (i in 0...len) {
                var layer = layers.unsafeGet(i);
                if (layer.collidable) {
                    // Layer already collidable, keep it in array so that
                    // we clean it if not collidable anymore afterwards
                    _layers[i] = layer;
                    // Temporary mark layer as non collidable, if will be re-marked as collidable
                    // if still relevant in the next loop
                    layer.collidable = false;
                }
                else {
                    // No need to check this layer after as it was not collidable before
                    _layers[i] = null;
                }
            }
        }

        if (layers != null && layers.length > 0 && collidableLayers != null && collidableLayers.length > 0) {
            for (i in 0...collidableLayers.length) {
                var name = collidableLayers.unsafeGet(i);
                for (l in 0...layers.length) {
                    var layer = layers.unsafeGet(l);
                    var layerData = layer.layerData;
                    if (layerData != null && layerData.name == name) {
                        // Mark layer as collidable
                        layer.collidable = true;
                        if (result == null) {
                            result = [];
                        }
                        result.push(layer);
                    }
                }
            }
        }

        // Destroy arcade tiles on layers that are not collidable anymore, if any
        if (destroyUnusedBodies) {
            for (i in 0...len) {
                var layer = _layers.unsafeGet(i);
                if (layer != null && !layer.collidable) {
                    // Layer not collidable anymore, cleanup arcade tiles
                    layer.clearArcadeTiles();
                }
                _layers.unsafeSet(i, null);
            }
        }

        computedCollidableLayers = result;
        collidableLayersDirty = false;

    }

    /**
     * Checks if there is a tile at the given world position.
     *
     * @param x World X coordinate to check
     * @param y World Y coordinate to check
     * @param layerName Optional layer name to check (checks all layers if null)
     * @param checkWithComputedTiles If true, checks computed tiles (after auto-tiling)
     *                               instead of raw tile data
     * @return true if at least one non-empty tile exists at the position
     */
    public function hasTileAtPosition(x:Float, y:Float, ?layerName:String, checkWithComputedTiles:Bool = false):Bool {

        var result:Bool = false;

        var tilemapData = this.tilemapData;
        if (tilemapData != null) {

            var layers = this.layers;
            if (layers != null) {
                for (i in 0...layers.length) {
                    var layer = layers.unsafeGet(i);
                    var layerData = layer.layerData;
                    if (layerData != null && (layerName == null || layerData.name == layerName)) {

                        var tileWidth = layerData.tileWidth;
                        var tileHeight = layerData.tileHeight;

                        var offsetX = layerData.offsetX + layerData.x * tileWidth;
                        var offsetY = layerData.offsetY + layerData.y * tileHeight;

                        var column = Math.floor((x - offsetX) / tileWidth);
                        var row = Math.floor((y - offsetY) / tileHeight);

                        if (column >= 0 && column < layerData.columns && row >= 0 && row < layerData.rows) {
                            var tile = checkWithComputedTiles ? layerData.computedTileByColumnAndRow(column, row) : layerData.tileByColumnAndRow(column, row);
                            var gid = tile.gid;
                            if (gid > 0) {
                                result = true;
                                break;
                            }
                        }
                    }
                }
            }
        }

        return result;

    }

    /**
     * Checks if collision should occur at the given world position.
     * Only checks layers marked as collidable.
     *
     * @param x World X coordinate to check
     * @param y World Y coordinate to check
     * @param direction Direction of movement to check collision for.
     *                  Used to determine which collision edges to check.
     * @param layerName Optional specific layer to check (checks all collidable layers if null)
     * @return true if collision should occur at this position
     */
    public function shouldCollideAtPosition(x:Float, y:Float, direction:arcade.Direction = NONE, ?layerName:String):Bool {

        var result:Bool = false;

        if (collidableLayersDirty)
            computeCollidableLayers();

        var tilemapData = this.tilemapData;
        if (tilemapData != null) {

            var computedCollidableLayers = this.computedCollidableLayers;
            if (computedCollidableLayers != null) {
                for (i in 0...computedCollidableLayers.length) {
                    var layer = computedCollidableLayers.unsafeGet(i);

                    var layerData = layer.layerData;
                    if (layerData != null && (layerName == null || layerData.name == layerName)) {

                        var tiles = layer.checkCollisionWithComputedTiles ? layerData.computedTiles : layerData.tiles;
                        if (tiles != null) {

                            var tileWidth = layerData.tileWidth;
                            var tileHeight = layerData.tileHeight;

                            var checkLayer:Bool = switch direction {
                                case NONE: layer.checkCollisionUp || layer.checkCollisionRight || layer.checkCollisionDown || layer.checkCollisionLeft;
                                case LEFT: layer.checkCollisionRight;
                                case RIGHT: layer.checkCollisionLeft;
                                case UP: layer.checkCollisionDown;
                                case DOWN: layer.checkCollisionUp;
                            }

                            if (checkLayer) {
                                var offsetX = layerData.offsetX + layerData.x * tileWidth;
                                var offsetY = layerData.offsetY + layerData.y * tileHeight;

                                var column = Math.floor((x - offsetX) / tileWidth);
                                var row = Math.floor((y - offsetY) / tileHeight);

                                if (column >= 0 && column < layerData.columns && row >= 0 && row < layerData.rows) {
                                    var tile = layer.checkCollisionWithComputedTiles ? layerData.computedTileByColumnAndRow(column, row) : layerData.tileByColumnAndRow(column, row);
                                    var gid = tile.gid;
                                    if (layer.checkCollisionValues != null) {
                                        if (layer.checkCollisionValues.contains(gid)) {
                                            result = true;
                                            break;
                                        }
                                    }
                                    else {
                                        if (gid > 0) {
                                            result = true;
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        return result;

    }

#end

}
