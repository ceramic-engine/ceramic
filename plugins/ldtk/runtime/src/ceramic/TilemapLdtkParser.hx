package ceramic;

import ceramic.LdtkData.LdtkLayerInstance;
import ceramic.LdtkData.LdtkLevel;
import ceramic.LdtkData.LdtkTilesetDefinition;
import ceramic.Shortcuts.*;
import haxe.DynamicAccess;
import haxe.Json;

using ceramic.Extensions;

/**
 * Parser that converts LDtk level data into Ceramic tilemap data structures.
 *
 * This class handles:
 * - Parsing raw LDtk JSON data
 * - Converting LDtk tilesets to Ceramic tilesets with proper GID mapping
 * - Converting LDtk layers (Tiles, IntGrid, AutoLayer, Entities) to tilemap layers
 * - Loading external level data for multi-file projects
 * - Optimizing tile stacking for rendering performance
 *
 * The parser maintains compatibility between LDtk's tile ID system and
 * Ceramic's global tile ID (GID) system.
 *
 * @see LdtkData
 * @see Tilemap
 */
@:noCompletion
class TilemapLdtkParser {

    /**
     * When `true` (default), tiles whose pixels are all fully transparent are not
     * converted at all: they render nothing, so dropping them saves geometry and keeps
     * them from taking a stacking slot. Requires tileset pixels to have been read
     * (see `computeTilesetsPixelData()`), otherwise no tile is considered empty.
     * Set to `false` if a project relies on invisible tiles as data markers.
     */
    public var skipEmptyTiles:Bool = true;

    public function new() {

    }

    /**
     * Parses raw LDtk JSON data into an LdtkData structure.
     * @param rawLdtkData The raw JSON string from an LDtk project file
     * @param loadExternalLdtkLevelData Callback to load external level files (for multi-file projects)
     * @return The parsed LdtkData object, or null if parsing fails
     */
    public function parseLdtk(rawLdtkData:String, loadExternalLdtkLevelData:(source:String, callback:(rawLevelData:String)->Void)->Void):LdtkData {

        var ldtkData:LdtkData = null;

        try {
            return new LdtkData(Json.parse(rawLdtkData), function(source:String, callback:(rawLevelData:DynamicAccess<Dynamic>)->Void) {
                loadExternalLdtkLevelData(source, (rawLevelData) -> {
                    callback(Json.parse(rawLevelData));
                });
            }, loadLdtkLevelTilemap);
        }
        catch (e:Dynamic) {
            log.error('Failed to parse raw LDtk data: ' + e);
            ldtkData = null;
        }

        return ldtkData;

    }

    /**
     * Loads and converts all tilesets and tilemaps from LDtk data.
     *
     * This method:
     * - Converts LDtk tilesets to Ceramic tilesets with proper GID assignment
     * - Loads tileset textures through the provided callback
     * - Creates tilemap data for all levels (if not using external levels)
     *
     * @param ldtkData The parsed LDtk data
     * @param loadTexture Optional callback to load tileset textures
     * @param skip Array of texture paths to skip loading
     */
    public function loadLdtkTilemaps(ldtkData:LdtkData, ?loadTexture:(source:String, configureAsset:(asset:ImageAsset)->Void, done:(texture:Texture)->Void)->Void, skip:Array<String>):Void {

        if (ldtkData.externalLevels) {
            log.info('This LDtk project uses external levels');
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

                    // A texture that is deliberately not loaded must not be reported
                    // as a failure when reading pixels back later
                    ldtkTileset.textureSkipped = loadTexture == null || (skip != null && skip.contains(ldtkTileset.relPath));

                    if (loadTexture != null) {
                        if (skip == null || !skip.contains(ldtkTileset.relPath)) {
                            (function(image:TilesetImage, ldtkTileset:LdtkTilesetDefinition) {
                                loadTexture(ldtkTileset.relPath, function(asset:ImageAsset) {
                                    #if plugin_ase
                                    @:privateAccess asset.aseTexWidth = ldtkTileset.pxWid;
                                    @:privateAccess asset.aseTexHeight = ldtkTileset.pxHei;
                                    @:privateAccess asset.asePadding = ldtkTileset.padding;
                                    @:privateAccess asset.aseSpacing = ldtkTileset.spacing;
                                    #end
                                }, function(texture:Texture) {
                                    image.texture = texture;
                                });
                            })(image, ldtkTileset);
                        }
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

    }

    /**
     * Builds the tilemap data of every level.
     *
     * Meant to run once tileset textures are loaded and `computeTilesetsPixelData()`
     * has succeeded, so that tile filtering can rely on actual pixels.
     *
     * @param ldtkData The parsed LDtk data
     */
    public function loadLdtkLevelTilemaps(ldtkData:LdtkData):Void {

        if (!ldtkData.externalLevels && ldtkData.worlds != null && ldtkData.worlds.length > 0) {
            for (i in 0...ldtkData.worlds.length) {
                var world = ldtkData.worlds[i];

                for (j in 0...world.levels.length) {
                    var level = world.levels[j];

                    loadLdtkLevelTilemap(level);
                }

            }
        }
        else {
            log.warning('LDtk data has no world');
        }

    }

    /**
     * Reads back each tileset texture once and records, per tile, whether it is fully
     * transparent or fully opaque. Results are cached on `LdtkTilesetDefinition`, which
     * survives level unload/reload, so this runs once per asset load.
     *
     * The cache is refreshed when a tileset texture is hot reloaded, so later conversions
     * see the new image. Already converted levels keep their tiles until they are converted
     * again: unloading them here would destroy tilemap data a displayed `Tilemap` may still use.
     *
     * Tilesets without a texture (skipped, or no image) are left unknown. When the backend
     * can't read pixels back, nothing is computed and no tile gets filtered. Otherwise a
     * failed read is a failed asset load.
     *
     * @param ldtkData The parsed LDtk data, with tileset textures loaded
     * @return `false` if a texture that should be readable could not be read
     */
    public function computeTilesetsPixelData(ldtkData:LdtkData):Bool {

        if (!app.backend.textures.supportsFetchTexturePixels()) {
            log.info('Backend cannot read texture pixels: LDtk empty tiles will not be filtered');
            return true;
        }

        var defs = ldtkData.defs.tilesets;
        if (defs == null) return true;

        for (t in 0...defs.length) {
            var ldtkTileset = defs[t];
            if (ldtkTileset.textureSkipped || ldtkTileset.relPath == null) continue;

            var tileset = ldtkTileset.ceramicTileset;
            var texture:Texture = (tileset != null && tileset.image != null) ? tileset.image.texture : null;
            if (texture == null || texture.destroyed) {
                log.error('LDtk tileset ${ldtkTileset.identifier} has no loaded texture');
                return false;
            }

            if (!readTilesetPixelData(ldtkTileset, texture)) {
                return false;
            }

            // Keep the cache in sync with hot reloaded textures. Bound to the tileset, so the
            // subscription goes away with it when the LDtk data is rebuilt.
            if (texture.asset != null) {
                texture.asset.onReplaceTexture(tileset, function(newTexture:Texture, prevTexture:Texture) {
                    var prevEmpty = ldtkTileset.emptyTiles;
                    var prevOpaque = ldtkTileset.opaqueTilesFromPixels;
                    if (newTexture == null || !readTilesetPixelData(ldtkTileset, newTexture)) {
                        // Can't fail the asset anymore: fall back to "unknown", which filters nothing
                        ldtkTileset.emptyTiles = null;
                        ldtkTileset.opaqueTilesFromPixels = null;
                        log.error('Failed to refresh pixel data of LDtk tileset ${ldtkTileset.identifier} after texture reload');
                    }
                    // Levels converted with the previous data are now stale: let listeners rebuild them
                    if (!sameTileFlags(prevEmpty, ldtkTileset.emptyTiles) || !sameTileFlags(prevOpaque, ldtkTileset.opaqueTilesFromPixels)) {
                        log.debug('LDtk tileset ${ldtkTileset.identifier}: pixel data changed, notifying');
                        ldtkData.notifyTilesetsPixelDataChange();
                    }
                });
            }
        }

        return true;

    }

    static function sameTileFlags(a:haxe.ds.Vector<Bool>, b:haxe.ds.Vector<Bool>):Bool {

        if (a == b) return true;
        if (a == null || b == null || a.length != b.length) return false;
        for (i in 0...a.length) {
            if (a[i] != b[i]) return false;
        }
        return true;

    }

    /**
     * Reads the pixels of one tileset texture and fills `emptyTiles` and
     * `opaqueTilesFromPixels` of its definition.
     *
     * @param ldtkTileset The tileset definition to fill
     * @param texture Its loaded texture
     * @return `false` if pixels could not be read
     */
    function readTilesetPixelData(ldtkTileset:LdtkTilesetDefinition, texture:Texture):Bool {

        var pixels:ceramic.UInt8Array = null;
        try {
            pixels = texture.fetchPixels();
        }
        catch (e:Dynamic) {
            log.error('Failed to read pixels of LDtk tileset ${ldtkTileset.identifier}: $e');
            return false;
        }

        var texW = texture.nativeWidth;
        var texH = texture.nativeHeight;
        if (pixels == null || pixels.length < texW * texH * 4) {
            log.error('Failed to read pixels of LDtk tileset ${ldtkTileset.identifier}');
            return false;
        }

        var density = texture.density;
        var grid = ldtkTileset.tileGridSize;
        var count = ldtkTileset.cWid * ldtkTileset.cHei;
        var stride = grid + ldtkTileset.spacing;
        var fw = Math.round(grid * density);
        var fh = Math.round(grid * density);
        var empty = new haxe.ds.Vector<Bool>(count);
        var opaque = new haxe.ds.Vector<Bool>(count);
        var numEmpty = 0;
        var numOpaque = 0;

        for (i in 0...count) {
            var fx = Math.round(((i % ldtkTileset.cWid) * stride + ldtkTileset.padding) * density);
            var fy = Math.round((Std.int(i / ldtkTileset.cWid) * stride + ldtkTileset.padding) * density);

            // A tile outside the texture is neither empty nor opaque: unchanged behavior
            if (fx < 0 || fy < 0 || fx + fw > texW || fy + fh > texH) {
                empty[i] = false;
                opaque[i] = false;
                continue;
            }

            var allZero = true;
            var allFull = true;
            var y = fy;
            while ((allZero || allFull) && y < fy + fh) {
                // Only the alpha byte matters: pixels are premultiplied, so alpha 0
                // means no contribution whatever the blending
                var p = (y * texW + fx) * 4 + 3;
                var end = p + fw * 4;
                while (p < end) {
                    var a = pixels[p];
                    if (a != 0) allZero = false;
                    if (a != 255) allFull = false;
                    if (!allZero && !allFull) break;
                    p += 4;
                }
                y++;
            }
            empty[i] = allZero;
            opaque[i] = allFull;
            if (allZero) numEmpty++;
            if (allFull) numOpaque++;
        }

        ldtkTileset.emptyTiles = empty;
        ldtkTileset.opaqueTilesFromPixels = opaque;
        log.debug('LDtk tileset ${ldtkTileset.identifier}: $numEmpty empty and $numOpaque opaque tiles out of $count');

        return true;

    }

    /**
     * Converts an LDtk level into Ceramic tilemap data.
     *
     * This method:
     * - Creates TilemapData with level properties
     * - Converts each layer instance to TilemapLayerData
     * - Handles different layer types (Tiles, IntGrid, AutoLayer, Entities)
     * - Optimizes tile stacking and alpha blending
     *
     * The resulting tilemap data is stored in level.ceramicTilemap.
     *
     * @param level The LDtk level to convert
     */
    public function loadLdtkLevelTilemap(level:LdtkLevel):Void {

        var tilemapData = new TilemapData();
        var usedTilesets:Array<Tileset> = [];

        tilemapData.backgroundColor = level.bgColor.toAlphaColor();
        tilemapData.renderOrder = RIGHT_DOWN;
        tilemapData.name = level.identifier;
        tilemapData.width = level.pxWid;
        tilemapData.height = level.pxHei;

        // TODO bgPos + bgRelPath?

        var tilemapLayers = [];
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
                    var tilesAlpha:Array<Float> = [];
                    var tilesOffsetX:Array<Int> = [];
                    var tilesOffsetY:Array<Int> = [];
                    tilemapLayerData.tiles = convertLdtkTiles(layerInstance.gridTiles, layerInstance.tileset, layerInstance.cWid, layerInstance.cHei, layerInstance.def.gridSize, tilesAlpha, tilesOffsetX, tilesOffsetY, skipEmptyTiles);
                    if (!allEqual(tilesAlpha, 1.0)) {
                        tilemapLayerData.tilesAlpha = tilesAlpha;
                    }
                    if (!allEqual(tilesOffsetX, 0)) {
                        tilemapLayerData.tilesOffsetX = tilesOffsetX;
                    }
                    if (!allEqual(tilesOffsetY, 0)) {
                        tilemapLayerData.tilesOffsetY = tilesOffsetY;
                    }

                case IntGrid | AutoLayer:
                    if (layerInstance.def.autoSourceLayerDefUid != -1 && resolveAutoSourceLayer(level, layerInstance) == null) {
                        log.warning('Failed to resolve auto source layer for: ' + layerInstance.def.identifier);
                    }
                    fillAutoLayerData(level, layerInstance, tilemapLayerData, skipEmptyTiles);
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

    static function resolveAutoSourceLayer(level:LdtkLevel, layerInstance:LdtkLayerInstance):LdtkLayerInstance {

        if (layerInstance.def.autoSourceLayerDefUid == -1)
            return layerInstance;
        for (l in 0...level.layerInstances.length) {
            var aLayer = level.layerInstances[l];
            if (aLayer.def.uid == layerInstance.def.autoSourceLayerDefUid) {
                return aLayer;
            }
        }
        return null;

    }

    /**
     * Fills the tiles of an auto layer's `TilemapLayerData` from the IntGrid of its source layer
     * and from its current `autoLayerTiles`.
     */
    static function fillAutoLayerData(level:LdtkLevel, layerInstance:LdtkLayerInstance, tilemapLayerData:TilemapLayerData, skipEmptyTiles:Bool):Void {

        var sourceLayer = resolveAutoSourceLayer(level, layerInstance);
        tilemapLayerData.tiles = sourceLayer != null && sourceLayer.intGrid != null ? [].concat(sourceLayer.intGrid) : null;

        var tilesAlpha:Array<Float> = [];
        var tilesOffsetX:Array<Int> = [];
        var tilesOffsetY:Array<Int> = [];
        tilemapLayerData.computedTiles = convertLdtkTiles(layerInstance.autoLayerTiles, layerInstance.tileset, layerInstance.cWid, layerInstance.cHei, layerInstance.def.gridSize, tilesAlpha, tilesOffsetX, tilesOffsetY, skipEmptyTiles);
        tilemapLayerData.shouldRenderTiles = (tilemapLayerData.computedTiles != null);
        tilemapLayerData.computedTilesAlpha = !allEqual(tilesAlpha, 1.0) ? tilesAlpha : null;
        tilemapLayerData.computedTilesOffsetX = !allEqual(tilesOffsetX, 0) ? tilesOffsetX : null;
        tilemapLayerData.computedTilesOffsetY = !allEqual(tilesOffsetY, 0) ? tilesOffsetY : null;

    }

    /**
     * Rebuilds the `TilemapLayerData` of an auto layer after its `autoLayerTiles` or IntGrid changed
     * (see `LdtkRuleRunner`). Visuals displaying this data must then be marked dirty.
     */
    public static function refreshAutoLayerData(layerInstance:LdtkLayerInstance, skipEmptyTiles:Bool = true):Void {

        if (layerInstance.ceramicLayer == null || layerInstance.level == null)
            return;
        fillAutoLayerData(layerInstance.level, layerInstance, layerInstance.ceramicLayer, skipEmptyTiles);

    }

    /**
     * Converts LDtk tile data to Ceramic tilemap tiles.
     *
     * LDtk stores tiles as flat arrays with [tileId, flipBits, x, y, srcX, srcY, alpha]
     * for each tile. This method converts that to Ceramic's TilemapTile format.
     *
     * Special handling:
     * - Stacks multiple tiles at the same position
     * - Optimizes opaque tiles by removing hidden tiles beneath
     * - Preserves tile offsets and alpha values
     *
     * @param ldtkTiles Raw tile data from LDtk (7 integers per tile)
     * @param tileset The tileset definition for GID mapping
     * @param cols Number of columns in the layer
     * @param rows Number of rows in the layer
     * @param gridSize The grid cell size in pixels
     * @param tilesAlpha Output array for tile alpha values
     * @param tilesOffsetX Output array for tile X offsets
     * @param tilesOffsetY Output array for tile Y offsets
     * @return Array of TilemapTile objects, or null if no tiles
     */
    static function convertLdtkTiles(ldtkTiles:Array<Int>, tileset:LdtkTilesetDefinition, cols:Int, rows:Int, gridSize:Int, tilesAlpha:Array<Float>, tilesOffsetX:Array<Int>, tilesOffsetY:Array<Int>, skipEmptyTiles:Bool):Array<TilemapTile> {

        if (ldtkTiles == null || ldtkTiles.length == 0)
            return null;

        var result:Array<TilemapTile> = [];
        var firstGid:Int = tileset != null && tileset.ceramicTileset != null ? tileset.ceramicTileset.firstGid : 0;
        var i:Int = 0;
        var end:Int = ldtkTiles.length - 5;
        var numTiles:Int = cols * rows;
        var needsCleanup:Bool = false;

        for (n in 0...numTiles) {
            result[n] = 0;
            tilesAlpha[n] = 1.0;
            tilesOffsetX[n] = 0;
            tilesOffsetY[n] = 0;
        }

        while (i < end) {

            var tileId:Int = ldtkTiles[i];
            var flipBits:Int = ldtkTiles[i + 1];
            var col:Int = Math.round(ldtkTiles[i + 2] * 1.0 / gridSize);
            var row:Int = Math.round(ldtkTiles[i + 3] * 1.0 / gridSize);
            var offsetX:Int = ldtkTiles[i + 2] - col * gridSize;
            var offsetY:Int = ldtkTiles[i + 3] - row * gridSize;
            var alpha:Float = ldtkTiles[i + 6] * 1.0 / 4096.0;

            if (col >= 0 && col < cols && row >= 0 && row < rows) {
                // Some tiles generated by LDtk could be out of bounds,
                // that is why we check that the computed col & row
                // is within those bounds before proceeding

                var tile:TilemapTile = 0;
                tile.gid = (firstGid + tileId);
                tile.horizontalFlip = (flipBits & 1 != 0);
                tile.verticalFlip = (flipBits & 2 != 0);

                // A tile with no visible pixel renders nothing: don't store it, so it takes no
                // stacking slot and doesn't keep an opaque tile placed later from discarding what's behind
                var isEmpty = skipEmptyTiles && (alpha <= 0 || tileset.isTileEmpty(tileId));

                if (!isEmpty) {
                    var isOpaque = alpha == 1.0 && offsetX == 0 && offsetY == 0 && tileset.isTileOpaque(tileId);

                    var index = row * cols + col;
                    if (isOpaque) {
                        // Stacking opaque tile, so we can discard any tile behind that doesn't have offsets
                        while (result[index] != 0) {
                            if (tilesOffsetX[index] == 0 && tilesOffsetY[index] == 0) {
                                // Found tile without offsets, discard it and shift all tiles above it downwards
                                needsCleanup = true;
                                var indexTarget = index;
                                var indexSource = index + numTiles;
                                while (indexSource < result.length) {
                                    result[indexTarget] = result[indexSource];
                                    tilesOffsetX[indexTarget] = tilesOffsetX[indexSource];
                                    tilesOffsetY[indexTarget] = tilesOffsetY[indexSource];

                                    indexTarget = indexSource;
                                    indexSource += numTiles;
                                }
                                result[indexTarget] = 0;
                                tilesOffsetX[indexTarget] = 0;
                                tilesOffsetY[indexTarget] = 0;
                            } else {
                                // Found tile with offsets, leave it in and stack on top
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
                    tilesAlpha[index] = alpha;
                    tilesOffsetX[index] = offsetX;
                    tilesOffsetY[index] = offsetY;
                }
            }

            i += 7;
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

/**
 * Checks if all elements in an array are equal to a given value.
 * Used to optimize tilemap data by avoiding storing default values.
 * @param array The array to check
 * @param value The value to compare against
 * @return True if all elements equal the value
 */
@generic
function allEqual<T>(array:Array<T>, value:T): Bool {
    for (i in 0...array.length) {
        if (array[i] != value) {
            return false;
        }
    }
    return true;
}