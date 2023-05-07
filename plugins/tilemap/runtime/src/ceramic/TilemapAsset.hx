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

class TilemapAsset extends Asset {

/// Properties

    /**
     * If the tilemap originates from a Tiled/TMX file, this will
     * contain the TMX data that you can use for custom logic etc...
     */
    @observe public var tmxMap:TmxMap = null;

    #if plugin_ldtk

    /**
     * If the tilemap data originates from an LDtk file, this will
     * contain the LDtk data that you can use for custom logic and access generated tilemaps
     */
    @observe public var ldtkData:LdtkData = null;

    #end

    /**
     * The tilemap data that can be used with a Ceramic `Tilemap` visual.
     */
    @observe public var tilemapData:TilemapData = null;

/// Internal

    var tsxRawData:Map<String,String> = null;

    #if plugin_ldtk

    var ldtkExternalSources:Array<String> = null;

    #end

/// Lifecycle

    override public function new(name:String, ?options:AssetOptions) {

        super('tilemap', name, options);
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

    function addTilesetTextAsset(textAssets:Assets, source:String):Void {

        var path = Path.join([Path.directory(this.path), source]);
        var pathInfo = Assets.decodePath(path);
        var asset = new TextAsset(pathInfo.name);
        asset.path = pathInfo.path;

        textAssets.addAsset(asset);

    }

    function resolveTsxRawData(name:String, cwd:String):String {

        if (tsxRawData != null) {
            return tsxRawData.get(name);
        }

        return null;

    }

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

                    tilemapParser.loadLdtkTilemaps(ldtkData, loadTextureFromSource);

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

    override function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        if (status == READY) {
            // Only check if the asset is already loaded.
            // If it is currently loading, it will check
            // at load end anyway.
            checkTexturesDensity();
        }

    }

    function checkTexturesDensity():Void {

        // This is called, but we don't need to do anything so far,
        // as tileset textures are already updating themselfes as needed

    }

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

        if (newTime > previousTime) {
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

                    if (newTime > previousTime) {
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
