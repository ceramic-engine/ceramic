package ceramic;

import format.tmx.Data.TmxImage;
import format.tmx.Data.TmxMap;
import ceramic.Path;
import ceramic.Asset;
import ceramic.ImageAsset;
import ceramic.TextAsset;
import ceramic.Assets;
import ceramic.AssetOptions;
import ceramic.Quad;
import ceramic.Mesh;
import ceramic.Shortcuts.*;

using StringTools;

class TilemapAsset extends Asset {

/// Properties

    public var tmxMap:TmxMap = null;

    public var tilemapData:TilemapData = null;

/// Internal

    var tmxAsset:TextAsset = null;

    var tsxRawData:Map<String,String> = null;

/// Lifecycle

    override public function new(name:String, ?options:AssetOptions) {

        super('tilemap', name, options);
        handleTexturesDensityChange = false;

        assets = new Assets();

    }

    override public function load() {

        // Load tilemap data
        status = LOADING;
        ceramic.App.app.logger.info('Load tilemap $path');

        // Use runtime assets if provided
        assets.runtimeAssets = runtimeAssets;

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
                loadExternalTilesetData(rawTmxData, function(isSuccess) {
                        
                    if (isSuccess) {

                        tmxMap = TilemapParser.parseTmx(rawTmxData, resolveTsxRawData);
                        tilemapData = TilemapParser.tmxMapToTilemapData(tmxMap, loadTextureFromTmxImage);

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

                            assets.load();

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

    function loadExternalTilesetData(rawTmxData:String, done:Bool->Void) {

        var sources = TilemapParser.parseExternalTilesetNames(rawTmxData);

        if (sources == null || sources.length == 0) {
            done(true);
            return;
        }

        var textAssets = new Assets();

        for (source in sources) {
            addTilesetTextAsset(textAssets, source);
        }

        textAssets.onceComplete(this, function(isSuccess) {

            if (!isSuccess) {
                textAssets.destroy();
                done(false);
                return;
            }

            if (tsxRawData == null) tsxRawData = new Map<String,String>();

            for (source in sources) {
                
                var pathInfo = Assets.decodePath(source);
                tsxRawData.set(source, textAssets.text(pathInfo.name));
            }

            textAssets.destroy();
            done(true);
        });

        textAssets.load();

    }

    function addTilesetTextAsset(textAssets:Assets, source:String):Void {

        var path = Path.join([Path.directory(this.path), source]);

        var pathInfo = Assets.decodePath(path);
        var asset = new TextAsset(pathInfo.name);
        asset.path = pathInfo.path;

        textAssets.addAsset(asset);

    }

    function resolveTsxRawData(name:String):String {

        if (tsxRawData != null) {
            return tsxRawData.get(name);
        }

        return null;

    }

    function loadTextureFromTmxImage(tmxImage:TmxImage, done:Texture->Void):Void {

        if (tmxImage.source != null) {
            var path = tmxImage.source;
            var pathInfo = Assets.decodePath(path);
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

                    done(texture);
                }
            });
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

        // TODO, for now it keeps the same texture always
        // but we should be able to improve this to resolved higher density of images

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
