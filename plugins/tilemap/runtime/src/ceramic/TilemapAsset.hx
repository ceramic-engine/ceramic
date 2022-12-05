package ceramic;

import ceramic.Asset;
import ceramic.AssetOptions;
import ceramic.Assets;
import ceramic.ImageAsset;
import ceramic.Mesh;
import ceramic.Path;
import ceramic.Quad;
import ceramic.Shortcuts.*;
import ceramic.TextAsset;
import format.tmx.Data.TmxImage;
import format.tmx.Data.TmxMap;

using StringTools;
using ceramic.TilemapPlugin;

class TilemapAsset extends Asset {

/// Properties

    @observe public var tmxMap:TmxMap = null;

    @observe public var tilemapData:TilemapData = null;

/// Internal

    var tmxAsset:TextAsset = null;

    var tsxRawData:Map<String,String> = null;

    // TODO cache external tileset so that we don't need to reload that for every tilemap

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

        if (isTiledMap) {
            loadTmxTiledMap();
        }
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
        tmxAsset = new TextAsset(path);
        var prevAsset = assets.addAsset(tmxAsset);
        tmxAsset.computePath(['tmx'], false, runtimeAssets);

        // Remove previous json asset if different
        if (prevAsset != null) prevAsset.destroy();

        assets.onceComplete(this, function(success) {

            var rawTmxData = tmxAsset.text;

            if (rawTmxData != null && rawTmxData.length > 0) {

                // Load external tileset raw data (if any)
                loadExternalTsxTilesetData(rawTmxData, function(isSuccess) {

                    if (isSuccess) {

                        var tilemapParser = owner.getTilemapParser();
                        tmxMap = tilemapParser.parseTmx(rawTmxData, Path.directory(path), resolveTsxRawData);
                        tilemapData = tilemapParser.tmxMapToTilemapData(tmxMap, loadTextureFromTmxImage);

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

    function loadTextureFromTmxImage(tmxImage:TmxImage, done:Texture->Void):Void {

        if (tmxImage.source != null) {
            var pathInfo = Assets.decodePath(Path.join([Path.directory(this.path), tmxImage.source]));

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
        else if (tmxImage.data != null) {
            log.warning('Loading TMX embedded images is not supported.');
        }
        else {
            log.warning('Cannot load texture for TMX image: $tmxImage');
        }

    }

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
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        if (tilemapData != null) {
            tilemapData.destroy();
            tilemapData = null;
        }

        if (tmxMap != null) {
            tmxMap = null;
        }

    }

}
