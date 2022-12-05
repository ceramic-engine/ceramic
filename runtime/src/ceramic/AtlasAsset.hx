package ceramic;

import ceramic.Path;
import ceramic.Shortcuts.*;

class AtlasAsset extends Asset {

/// Events

    @event function replaceAtlas(newAtlas:TextureAtlas, prevAtlas:TextureAtlas);

/// Properties

    @observe public var atlas:TextureAtlas = null;

    @observe public var text:String = null;

/// Internal

    /**
     * A custom atlas parsing method. Will be used over the default parsing if not null
     */
    var parseAtlas:(text:String)->TextureAtlas = null;

/// Lifecycle

    override public function new(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('atlas', name, options #if ceramic_debug_entity_allocs , pos #end);
        handleTexturesDensityChange = true;

        assets = new Assets();

    }

    override public function load() {

        if (owner != null) {
            assets.inheritRuntimeAssetsFromAssets(owner);
            assets.loadMethod = owner.loadMethod;
            assets.scheduleMethod = owner.scheduleMethod;
            assets.delayBetweenXAssets = owner.delayBetweenXAssets;
        }

        // Create array of assets to destroy after load
        var toDestroy:Array<Asset> = [];
        for (asset in assets) {
            toDestroy.push(asset);
        }

        // Load atlas data
        status = LOADING;

        if (path == null) {
            log.warning('Cannot load atlas asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        log.info('Load atlas $path');

        // Use runtime assets if provided
        assets.runtimeAssets = runtimeAssets;

        var asset = new TextAsset(name);
        asset.handleTexturesDensityChange = false;
        asset.path = path;
        assets.addAsset(asset);
        assets.onceComplete(this, function(success) {

            text = asset.text;

            if (text != null) {

                try {
                    var newAtlas = parseAtlas != null ? parseAtlas(text) : TextureAtlasParser.parse(text);
                    newAtlas.id = 'atlas:' + path;

                    // Load textures
                    var assetList:Array<ImageAsset> = [];

                    for (i in 0...newAtlas.pages.length) {

                        var page = newAtlas.pages[i];

                        var imagePath = page.name;
                        var directory = Path.directory(path);
                        if (directory != null && directory.length > 0) {
                            imagePath = Path.join([directory, imagePath]);
                        }
                        var pathInfo = Assets.decodePath(imagePath);
                        var asset = new ImageAsset(pathInfo.name);

                        // Because it is handled at atlas level
                        asset.handleTexturesDensityChange = false;

                        asset.path = pathInfo.path;
                        assets.addAsset(asset);
                        assetList.push(asset);

                    }

                    assets.onceComplete(this, function(success) {

                        if (success) {
                            // Update textures
                            for (i in 0...assetList.length) {
                                var asset = assetList[i];
                                newAtlas.pages[i].texture = asset.texture;
                            }

                            // Compute atlas frames with loaded textures
                            newAtlas.computeFrames();

                            var prevAtlas = this.atlas;

                            // Link the atlas to this asset so that
                            // destroying one will destroy the other
                            newAtlas.asset = this;

                            // Do the actual atlas replacement
                            this.atlas = newAtlas;

                            if (prevAtlas != null) {

                                // When replacing the atlas, emit an event to notify about it
                                emitReplaceAtlas(this.atlas, prevAtlas);

                                // Atlas was reloaded. Update related visuals
                                for (visual in [].concat(app.visuals)) {
                                    if (!visual.destroyed) {
                                        if (visual.asQuad != null) {
                                            var quad = visual.asQuad;
                                            if (quad.tile != null && quad.tile is TextureAtlasRegion) {
                                                var prevRegion:TextureAtlasRegion = cast quad.tile;
                                                if (prevRegion != null && prevRegion.atlas == prevAtlas) {
                                                    var regionName = prevRegion.name;
                                                    if (regionName != null) {
                                                        var newRegion = newAtlas.region(regionName);
                                                        if (newRegion != null) {
                                                            quad.tile = newRegion;
                                                        }
                                                        else {
                                                            quad.tile = null;
                                                        }
                                                    }
                                                    else {
                                                        quad.tile = null;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Set asset to null because we don't want it
                                // to be destroyed when destroying the atlas.
                                prevAtlas.asset = null;
                                // Destroy previous atlas
                                prevAtlas.destroy();
                            }

                            // Destroy unused assets
                            for (asset in toDestroy) {
                                if (Std.isOfType(asset, ImageAsset)) {
                                    // When it's an image, ensure we don't use it for the updated atlas, still.
                                    var imageAsset:ImageAsset = cast asset;
                                    if (assetList.indexOf(imageAsset) == -1) {
                                        asset.destroy();
                                    }
                                } else {
                                    asset.destroy();
                                }
                            }

                            status = READY;
                            emitComplete(true);
                            if (handleTexturesDensityChange) {
                                checkTexturesDensity();
                            }

                        }
                        else {
                            status = BROKEN;
                            log.error('Failed to load textures for atlas at path: $path');
                            emitComplete(false);
                        }

                    });

                    assets.load();

                } catch (e:Dynamic) {
                    status = BROKEN;
                    log.error('Failed to decode atlas data at path: $path');
                    emitComplete(false);
                }
            }
            else {
                status = BROKEN;
                log.error('Failed to load atlas data at path: $path');
                emitComplete(false);
            }
        });

        assets.load();

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

        var prevPath = path;
        computePath();

        if (prevPath != path) {
            log.info('Reload atlas ($prevPath -> $path)');
            load();
        }

    }

    override function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        if (!app.backend.texts.supportsHotReloadPath())
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
            log.info('Reload atlas (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        if (atlas != null) {
            atlas.destroy();
            atlas = null;
        }

    }

}
