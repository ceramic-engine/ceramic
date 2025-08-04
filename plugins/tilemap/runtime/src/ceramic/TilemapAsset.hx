package ceramic;

import ceramic.Asset;
import ceramic.AssetOptions;
import ceramic.Assets;
import ceramic.ImageAsset;
import ceramic.Mesh;
import ceramic.Path;
import ceramic.Quad;
import ceramic.ReadOnlyMap;
import ceramic.Shortcuts.*;
import ceramic.TextAsset;
import format.tmx.Data.TmxImage;
import format.tmx.Data.TmxMap;

using StringTools;
using ceramic.TilemapPlugin;

/**
 * Asset type for loading tilemap data from various formats (TMX, LDtk).
 * Handles loading of tilemap files, external tilesets, and associated textures.
 * 
 * Supported formats:
 * - TMX (Tiled Map Editor): XML-based format with optional external TSX tilesets
 * - LDtk (Level Designer Toolkit): JSON-based format with modern features
 * 
 * The asset automatically:
 * - Parses tilemap data into a unified TilemapData structure
 * - Loads required tileset textures
 * - Handles external tileset references
 * - Supports hot-reloading when files change
 * - Manages texture density changes for different screen resolutions
 * 
 * ## Usage Example:
 * ```haxe
 * // Load a TMX tilemap
 * assets.add(Tilemaps.LEVEL1);
 * assets.load();
 * 
 * // Access the tilemap data
 * var tilemapData = assets.tilemap(Tilemaps.LEVEL1).tilemapData;
 * 
 * // Create a visual from the data
 * var tilemap = new Tilemap();
 * tilemap.tilemapData = tilemapData;
 * ```
 * 
 * @see TilemapData The unified tilemap data structure
 * @see Tilemap The visual component for rendering tilemaps
 * @see TilemapParser For parsing tilemap formats
 */
class TilemapAsset extends Asset {

/// Properties

    /**
     * If the tilemap originates from a Tiled/TMX file, this contains
     * the raw TMX data structure. Useful for accessing custom properties,
     * object layers, or other TMX-specific features not converted to TilemapData.
     * 
     * This is null for non-TMX tilemaps.
     */
    @observe public var tmxMap:TmxMap = null;

    #if plugin_ldtk

    /**
     * If the tilemap originates from an LDtk file, this contains
     * the complete LDtk data structure. Provides access to:
     * - All levels in the project
     * - Entity instances
     * - Custom fields
     * - Generated tilemaps
     * 
     * This is null for non-LDtk tilemaps.
     */
    @:plugin('ldtk')
    @observe public var ldtkData:LdtkData = null;

    #end

    /**
     * The unified tilemap data that can be used with Ceramic's Tilemap visual.
     * This is the primary output of the asset, containing layers, tilesets,
     * and tile placement data in a format-agnostic structure.
     * 
     * For TMX files, this contains the first/main tilemap.
     * For LDtk files, access individual level tilemaps through ldtkData.
     */
    @observe public var tilemapData:TilemapData = null;

/// Internal

    /**
     * Cache for external TSX tileset data loaded from separate files.
     * Maps from tileset source path to raw XML content.
     */
    var tsxRawData:Map<String,String> = null;

    #if plugin_ldtk

    /**
     * List of external LDtk level file paths for hot-reload monitoring.
     */
    var ldtkExternalSources:Array<String> = null;

    #end

/// Lifecycle

    override public function new(name:String, ?variant:String, ?options:AssetOptions) {

        super('tilemap', name, variant, options);
        handleTexturesDensityChange = false;

        assets = new Assets();

    }

    override public function load() {

        if (owner != null) {
            assets.inheritRuntimeAssetsFromAssets(owner);
            assets.loadMethod = owner.loadMethod;
            assets.scheduleMethod = owner.scheduleMethod;
            assets.delayBetweenXAssets = owner.delayBetweenXAssets;
        }

        // Load tilemap data
        status = LOADING;
        ceramic.App.app.logger.info('Load tilemap $path');

        // Use runtime assets if provided
        assets.runtimeAssets = runtimeAssets;

        var isTiledMap = path.toLowerCase().endsWith('.tmx');

        #if plugin_ldtk
        var isLdtk = path.toLowerCase().endsWith('.ldtk');
        #end

        if (isTiledMap) {
            loadTmxTiledMap();
        }
        #if plugin_ldtk
        else if (isLdtk) {
            loadLdtk();
        }
        #end
        else {
            status = BROKEN;
            ceramic.App.app.logger.error('Unknown format for tilemap data at path: $path');
            emitComplete(false);
        }

    }

/// Tiled Map Editor format (TMX & TSX)

    /**
     * Loads a TMX (Tiled Map Editor) format tilemap.
     * Handles:
     * 1. Loading the main TMX file
     * 2. Loading external TSX tilesets if referenced
     * 3. Parsing the XML data into TmxMap structure
     * 4. Converting to unified TilemapData
     * 5. Loading all required textures
     */
    function loadTmxTiledMap() {

        // Load tmx asset
        //
        var tmxAsset = new TextAsset(path);
        var prevAsset = assets.addAsset(tmxAsset);
        tmxAsset.computePath(['tmx'], false, runtimeAssets);

        // Remove previous json asset if different
        if (prevAsset != null) prevAsset.destroy();

        assets.onceComplete(this, function(success) {

            var rawTmxData = tmxAsset.text;
            tmxAsset.destroy();

            if (rawTmxData != null && rawTmxData.length > 0) {

                // Load external tileset raw data (if any)
                loadExternalTsxTilesetData(rawTmxData, function(isSuccess) {

                    if (isSuccess) {

                        var tilemapParser = owner.getTilemapParser();
                        tmxMap = tilemapParser.parseTmx(rawTmxData, Path.directory(path), resolveTsxRawData);
                        tilemapData = tilemapParser.tmxMapToTilemapData(tmxMap, loadTextureFromSource);

                        if (tilemapData != null) {

                            // Link the tilemap data to this asset so that
                            // destroying one will destroy the other
                            tilemapData.asset = this;

                            // Run load of assets again to load textures
                            assets.onceComplete(this, function(isSuccess) {

                                if (isSuccess) {

                                    // Success
                                    status = READY;
                                    emitComplete(true);
                                    if (handleTexturesDensityChange) {
                                        checkTexturesDensity();
                                    }
                                }
                                else {
                                    status = BROKEN;
                                    ceramic.App.app.logger.error('Failed to load tilemap textures at path: $path');
                                    emitComplete(false);
                                }

                            });

                            assets.load(false);

                        }
                        else {
                            status = BROKEN;
                            ceramic.App.app.logger.error('Failed to load tilemap data at path: $path');
                            emitComplete(false);
                        }

                    }
                    else {
                        status = BROKEN;
                        ceramic.App.app.logger.error('Failed to load external tilesets of map: $path');
                        emitComplete(false);
                    }

                });

            }
            else {
                status = BROKEN;
                ceramic.App.app.logger.error('Failed to load raw tilemap data at path: $path');
                emitComplete(false);
            }

        });

        assets.load();

    }

    /**
     * Loads external TSX tileset files referenced by the TMX map.
     * TSX files allow sharing tilesets between multiple maps.
     * 
     * This method:
     * - Parses the TMX to find external tileset references
     * - Checks the cache for already-loaded TSX data
     * - Loads any missing TSX files
     * - Caches the results for future use
     * 
     * @param rawTmxData The raw TMX XML content
     * @param done Callback with success status
     */
    function loadExternalTsxTilesetData(rawTmxData:String, done:Bool->Void) {

        var tilemapParser = owner.getTilemapParser();
        var rawTsxCache = owner.getRawTsxCache();
        var sources = tilemapParser.parseExternalTilesetNames(rawTmxData);

        if (sources == null || sources.length == 0) {
            done(true);
            return;
        }

        inline function sourceToCacheKey(source:String):String {
            return Path.join([Path.directory(this.path), source]);
        }

        var textAssets:Assets = null;

        if (tsxRawData == null)
            tsxRawData = new Map<String,String>();

        for (source in sources) {
            var existingData = null;
            var key = sourceToCacheKey(source);
            existingData = rawTsxCache.get(key);
            if (existingData != null) {
                tsxRawData.set(source, existingData);
            }
            else {
                if (textAssets == null)
                    textAssets = new Assets();
                addTilesetTextAsset(textAssets, source);
            }
        }

        if (textAssets != null) {
            // Need to load new data
            textAssets.onceComplete(this, function(isSuccess) {

                if (!isSuccess) {
                    textAssets.destroy();
                    done(false);
                    return;
                }

                for (source in sources) {
                    var pathInfo = Assets.decodePath(Path.join([Path.directory(this.path), source]));
                    var data = textAssets.text(pathInfo.name);
                    var key = sourceToCacheKey(source);
                    tsxRawData.set(source, data);
                    rawTsxCache.set(key, data);
                }

                textAssets.destroy();
                done(true);
            });

            textAssets.load();
        }
        else {
            // Everything already cached
            done(true);
        }

    }

    /**
     * Adds a text asset for loading an external TSX tileset file.
     * 
     * @param textAssets The Assets instance to add the asset to
     * @param source The relative path to the TSX file from the TMX location
     */
    function addTilesetTextAsset(textAssets:Assets, source:String):Void {

        var path = Path.join([Path.directory(this.path), source]);
        var pathInfo = Assets.decodePath(path);
        var asset = new TextAsset(pathInfo.name);
        asset.path = pathInfo.path;

        textAssets.addAsset(asset);

    }

    /**
     * Resolves raw TSX data from the cache by filename.
     * Called by the parser when it encounters an external tileset reference.
     * 
     * @param name The TSX filename to resolve
     * @param cwd The current working directory (unused but part of parser interface)
     * @return The raw TSX XML content, or null if not loaded
     */
    function resolveTsxRawData(name:String, cwd:String):String {

        if (tsxRawData != null) {
            return tsxRawData.get(name);
        }

        return null;

    }

    /**
     * Loads a texture from a source path, used by tileset loading.
     * 
     * This method:
     * - Checks if the texture is already loaded
     * - Creates an ImageAsset if needed
     * - Configures the asset (e.g., for filtering)
     * - Shares loaded textures with the owner Assets instance
     * - Sets NEAREST filter by default (pixel-perfect for tilemaps)
     * 
     * @param source The relative path to the image file
     * @param configureAsset Optional callback to configure the ImageAsset
     * @param done Callback that receives the loaded texture (or null on failure)
     */
    function loadTextureFromSource(source:String, configureAsset:(asset:ImageAsset)->Void, done:(texture:Texture)->Void):Void {

        if (source != null) {
            var pathInfo = Assets.decodePath(Path.join([Path.directory(this.path), source]));

            // Check if asset is already available
            var texture = owner.texture(pathInfo.name);

            if (texture == null) {

                var asset = owner.imageAsset(pathInfo.name);

                if (asset != null) {

                    switch asset.status {
                        case NONE | LOADING:
                            asset.onceComplete(this, function(isSuccess) {
                                if (isSuccess) {
                                    var texture = owner.texture(asset.name);
                                    done(texture);
                                }
                                else {
                                    done(null);
                                }
                            });
                        case READY | BROKEN:
                            done(null);
                    }

                }
                else {

                    // Texture not already loaded, load it!

                    var asset = new ImageAsset(pathInfo.name);
                    if (configureAsset != null) {
                        configureAsset(asset);
                    }
                    asset.handleTexturesDensityChange = true;
                    asset.onDestroy(this, function(_) {
                        // Should we do some cleanup here?
                    });
                    assets.addAsset(asset);
                    assets.onceComplete(this, function(isSuccess) {
                        if (isSuccess) {
                            var texture = assets.texture(asset.name);

                            // NEAREST is usually preferred for tilemaps so use that by default,
                            // although it is still possible to set it to LINEAR manually after
                            texture.filter = NEAREST;

                            // Share this texture with owner `Assets` instance
                            // so that it can be reused later
                            owner.addAsset(asset);

                            done(texture);
                        }
                    });
                }
            }
            else {

                // Texture already loaded, use it :)
                done(texture);
            }
        }
        else {
            log.warning('Cannot load texture for source: $source');
        }

    }

#if plugin_ldtk

/// LDtk

    /**
     * Loads an LDtk (Level Designer Toolkit) format tilemap project.
     * 
     * Handles:
     * 1. Loading the main .ldtk JSON file
     * 2. Loading external level files if the project uses them
     * 3. Parsing the LDtk data structure
     * 4. Loading tileset textures for all levels
     * 5. Generating TilemapData for each level
     * 
     * The `skip` option in AssetOptions can exclude specific levels from loading.
     */
    function loadLdtk() {

        // Load ldtk asset
        //
        var ldtkAsset = new TextAsset(path);
        var prevAsset = assets.addAsset(ldtkAsset);
        ldtkAsset.computePath(['ldtk'], false, runtimeAssets);

        // Remove previous json asset if different
        if (prevAsset != null) prevAsset.destroy();

        assets.onceComplete(this, function(success) {

            var rawLdtkData = ldtkAsset.text;
            ldtkAsset.destroy();

            if (rawLdtkData != null && rawLdtkData.length > 0) {

                var tilemapParser = owner.getTilemapParser();
                ldtkData = tilemapParser.parseLdtk(rawLdtkData, loadExternalLdtkLevelData);

                if (ldtkData == null) {
                    status = BROKEN;
                    ceramic.App.app.logger.error('Failed to load because of invalid LDtk data');
                    emitComplete(false);
                    return;
                }

                try {

                    var skip:Array<String> = null;
                    if (options != null && options.skip != null && options.skip is Array) {
                        skip = options.skip;
                    }

                    tilemapParser.loadLdtkTilemaps(ldtkData, loadTextureFromSource, skip);

                    // Link the ldtk data to this asset so that
                    // destroying one will destroy the other
                    ldtkData.asset = this;

                    // Run load of assets again to load textures
                    assets.onceComplete(this, function(isSuccess) {

                        if (isSuccess) {

                            // Success
                            status = READY;
                            emitComplete(true);
                            if (handleTexturesDensityChange) {
                                checkTexturesDensity();
                            }
                        }
                        else {
                            status = BROKEN;
                            ceramic.App.app.logger.error('Failed to load tilemap textures at path: $path');
                            emitComplete(false);
                        }

                    });

                    assets.load(false);

                }
                catch (e:Dynamic) {
                    status = BROKEN;
                    ceramic.App.app.logger.error('Error when loading LDtk tilemaps: ' + e);
                    ceramic.App.app.logger.error('Failed to load tilemap data at path: $path');
                    emitComplete(false);
                }

            }
            else {
                status = BROKEN;
                ceramic.App.app.logger.error('Failed to load raw tilemap data at path: $path');
                emitComplete(false);
            }

        });

        assets.load();

    }

    /**
     * Loads an external LDtk level file (.ldtkl).
     * Used when LDtk projects are configured to save levels in separate files.
     * 
     * @param source The path to the external level file
     * @param callback Receives the raw level JSON data, or null on failure
     */
    function loadExternalLdtkLevelData(source:String, callback:(rawLevelData:String)->Void):Void {

        log.info('Load external LDtk level $source');

        // Load ldtk external level asset
        //
        var ldtkAsset = new TextAsset(source);
        var prevAsset = assets.addAsset(ldtkAsset);
        ldtkAsset.computePath(['ldtkl'], false, runtimeAssets);

        if (ldtkExternalSources == null)
            ldtkExternalSources = [];
        if (!ldtkExternalSources.contains(ldtkAsset.path)) {
            ldtkExternalSources.push(ldtkAsset.path);
        }

        // Remove previous json asset if different
        if (prevAsset != null) prevAsset.destroy();

        assets.onceComplete(this, function(success) {

            var rawLdtkData = ldtkAsset.text;
            ldtkAsset.destroy();

            if (rawLdtkData != null && rawLdtkData.length > 0) {
                try {
                    callback(rawLdtkData);
                }
                catch (e:Dynamic) {
                    ceramic.App.app.logger.error('Error when loading external LDtk level: ' + e);
                    callback(null);
                }
            }
            else {
                ceramic.App.app.logger.error('Failed to load raw external LDtk level at path: $source');
                callback(null);
            }

        });

        assets.load();

    }

#end

    /**
     * Handles texture density changes for responsive asset loading.
     * Called when the screen density changes (e.g., moving between displays).
     * 
     * @param newDensity The new texture density multiplier
     * @param prevDensity The previous texture density multiplier
     */
    override function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        if (status == READY) {
            // Only check if the asset is already loaded.
            // If it is currently loading, it will check
            // at load end anyway.
            checkTexturesDensity();
        }

    }

    /**
     * Checks and updates textures for the current screen density.
     * Currently a no-op as tileset textures handle density changes themselves,
     * but kept for potential future use.
     */
    function checkTexturesDensity():Void {

        // This is called, but we don't need to do anything so far,
        // as tileset textures are already updating themselfes as needed

    }

    /**
     * Handles file change notifications for hot-reloading.
     * Automatically reloads the tilemap when:
     * - The main tilemap file changes
     * - Any external level files change (LDtk)
     * - Any referenced tileset files change
     * 
     * @param newFiles Map of current file paths to modification times
     * @param previousFiles Map of previous file paths to modification times
     */
    override function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        if (!app.backend.texts.supportsHotReloadPath() && !app.backend.textures.supportsHotReloadPath())
            return;

        var previousTime:Float = -1;
        if (previousFiles.exists(path)) {
            previousTime = previousFiles.get(path);
        }
        var newTime:Float = -1;
        if (newFiles.exists(path)) {
            newTime = newFiles.get(path);
        }

        if (newTime != previousTime) {
            log.info('Reload tilemap (file has changed)');
            #if plugin_ldtk
            ldtkExternalSources = null;
            #end
            load();
        }
        #if plugin_ldtk
        else {

            if (ldtkExternalSources != null) {
                for (i in 0...ldtkExternalSources.length) {
                    var source = ldtkExternalSources[i];

                    var previousTime:Float = -1;
                    if (previousFiles.exists(source)) {
                        previousTime = previousFiles.get(source);
                    }
                    var newTime:Float = -1;
                    if (newFiles.exists(source)) {
                        newTime = newFiles.get(source);
                    }

                    if (newTime != previousTime) {
                        log.info('Reload tilemap (external file has changed)');
                        ldtkExternalSources = null;
                        load();
                        return;
                    }
                }
            }
        }
        #end

    }

    /**
     * Cleans up the tilemap asset and all associated data.
     * Destroys:
     * - The TilemapData instance
     * - The LDtk data (if applicable)
     * - References to TMX data
     * - All loaded textures and sub-assets
     */
    override function destroy():Void {

        super.destroy();

        if (tilemapData != null) {
            tilemapData.destroy();
            tilemapData = null;
        }

        #if plugin_ldtk

        if (ldtkData != null) {
            ldtkData.destroy();
            ldtkData = null;
        }

        #end

        if (tmxMap != null) {
            tmxMap = null;
        }

    }

}
