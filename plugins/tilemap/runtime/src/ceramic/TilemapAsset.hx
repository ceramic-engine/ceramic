package ceramic;

import format.tmx.Data.TmxImage;
import format.tmx.Data.TmxMap;
import haxe.io.Path;
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

/// Lifecycle

    override public function new(name:String, ?options:AssetOptions) {

        super('tilemap', name, options);
        handleTexturesDensityChange = true;

        assets = new Assets();

    } //name

    override public function load() {

        // Load tilemap data
        status = LOADING;
        ceramic.App.app.logger.log('Load tilemap $path');

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

                tmxMap = TilemapParser.parseTmx(rawTmxData);
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
                ceramic.App.app.logger.error('Failed to load raw tilemap data at path: $path');
                emitComplete(false);
            }

        });

        assets.load();

    } //load

    function loadTextureFromTmxImage(tmxImage:TmxImage, done:Texture->Void):Void {

        if (tmxImage.source != null) {
            var path = tmxImage.source;
            var pathInfo = Assets.decodePath(path);
            var asset = new ImageAsset(pathInfo.name);
            asset.handleTexturesDensityChange = false;
            asset.path = pathInfo.path;
            asset.onDestroy(this, function() {
                // Should we do some cleanup here?
            });
            assets.addAsset(asset);
            assets.onceComplete(this, function(isSuccess) {
                if (isSuccess) {
                    var texture = assets.texture(asset.name);
                    done(texture);
                }
            });
        }
        else if (tmxImage.data != null) {
            warning('Loading TMX embedded images is not supported.');
        }
        else {
            warning('Cannot load texture for TMX image: $tmxImage');
        }

    } //loadTextureFromTmxImage

    override function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        if (status == READY) {
            // Only check if the asset is already loaded.
            // If it is currently loading, it will check
            // at load end anyway.
            checkTexturesDensity();
        }

    } //texturesDensityDidChange

    function checkTexturesDensity():Void {

        // TODO, for now it keeps the same texture always
        // but we should be able to improve this to resolved higher density of images

    } //checkTexturesDensity

    override function destroy():Void {

        if (tilemapData != null) {
            tilemapData.destroy();
            tilemapData = null;
        }

        if (tmxMap != null) {
            tmxMap = null;
        }

    } //destroy

} //TilemapAsset
