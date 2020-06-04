package ceramic;

import spine.support.graphics.TextureAtlas;
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

class SpineAsset extends Asset {

/// Events

    @event function replaceSpineData(newSpineData:SpineData, prevSpineData:SpineData);

/// Properties

    public var json:String = null;

    public var atlas:TextureAtlas = null;

    @observe public var spineData:SpineData = null;

    public var scale:Float = 1.0;

    public var pages:Map<AtlasPage,ImageAsset> = new Map();

/// Internal

    var atlasAsset:TextAsset = null;

/// Lifecycle

    override public function new(name:String, ?options:AssetOptions) {

        super('spine', name, options);
        handleTexturesDensityChange = true;

        if (this.options.scale != null) {
            scale = Std.parseFloat(options.scale);
            if (Math.isNaN(scale)) {
                ceramic.App.app.logger.warning('Invalid scale option: ' + options.scale);
                scale = 1.0;
            }
        }

        assets = new Assets();

    }

    override public function load() {

        // Load spine data
        status = LOADING;
        ceramic.App.app.logger.info('Load spine $path');

        // Use runtime assets if provided
        assets.runtimeAssets = runtimeAssets;

        // Retrieve json asset
        //
        var prefix = path + '/';
        var jsonPath = null;
        for (entry in Assets.all) {
            if (entry.startsWith(prefix) && entry.toLowerCase().endsWith('.json')) {
                jsonPath = entry;
                break;
            }
        }
        
        if (jsonPath == null) {
            status = BROKEN;
            ceramic.App.app.logger.error('Failed to retrieve json path for spine: $path');
            emitComplete(false);
            return;
        }

        var jsonPathInfo = Assets.decodePath(jsonPath);
        var baseName = jsonPathInfo.name;

        var jsonAsset = new TextAsset(baseName + '.json');
        jsonAsset.handleTexturesDensityChange = false;

        // Retrieve atlas asset
        //
        if (atlasAsset == null) {
            atlasAsset = new TextAsset(baseName + '.atlas');
            atlasAsset.handleTexturesDensityChange = false;
            assets.addAsset(atlasAsset);
            atlasAsset.computePath(['atlas'], false, runtimeAssets);
        }

        // Load json and atlas assets
        //
        var prevAsset = assets.addAsset(jsonAsset);
        jsonAsset.computePath(['json'], false, runtimeAssets);

        // Remove previous json asset if different
        if (prevAsset != null) prevAsset.destroy();

        var handleAssetsComplete:Bool->Void = null;
        handleAssetsComplete = function(success) {

            var json = new SpineFile(jsonAsset.path, jsonAsset.text);
            var atlas = atlasAsset.text;

            if (atlas != null && atlas.trim().startsWith('alias:')) {
                assets.onceComplete(this, handleAssetsComplete);

                var realAtlasInfo = Assets.decodePath(atlas.trim().substring('alias:'.length));
                log.info('Atlas ${baseName + '.atlas'} is an alias for: ${realAtlasInfo.name + '.atlas'}');
                atlasAsset = new TextAsset(realAtlasInfo.name + '.atlas');
                atlasAsset.handleTexturesDensityChange = false;
                assets.addAsset(atlasAsset);
                atlasAsset.computePath(['atlas'], false, runtimeAssets);

                assets.load();
                return;
            }

            if (json != null && atlas != null) {

                // Keep prev pages
                var prevPages = pages;
                pages = new Map();

                // Create atlas, which will trigger page loads
                var spineAtlas = new TextureAtlas(
                    atlas,
                    new SpineTextureLoader(this, Path.directory(atlasAsset.path))
                );

                // Load pages
                assets.onceComplete(this, function(success) {

                    if (success) {

                        // Fill page info
                        for (page in pages.keys()) {
                            var asset = pages.get(page);
                            page.rendererObject = asset.texture;
                            page.width = Std.int(asset.texture.width);
                            page.height = Std.int(asset.texture.height);
                        }

                        // Keep prev spine data to update it
                        var prevSpineData = spineData;

                        // Create final spine data with all info
                        spineData = new SpineData(
                            spineAtlas,
                            json,
                            scale
                        );
                        spineData.asset = this;

                        // Destroy previous pages
                        if (prevPages != null) {
                            for (asset in prevPages) {
                                var texture = asset.texture;
                                for (visual in [].concat(ceramic.App.app.visuals)) {
                                    if (visual.asQuad != null) {
                                        var quad = visual.asQuad;
                                        if (quad.texture == texture) {
                                            quad.texture = null;
                                        }
                                    }
                                    else if (visual.asMesh != null) {
                                        var mesh = visual.asMesh;
                                        if (mesh.texture == texture) {
                                            mesh.texture = null;
                                        }
                                    }
                                }
                                asset.destroy();
                            }
                        }

                        // Update prev spine data
                        if (prevSpineData != null) {

                            // When replacing the spine data, emit an event to notify about it
                            emitReplaceSpineData(this.spineData, prevSpineData);

                            for (visual in [].concat(ceramic.App.app.visuals)) {
                                if (Std.is(visual, Spine)) {
                                    var spine:Spine = cast visual;
                                    if (spine.spineData == prevSpineData) {
                                        spine.spineData = spineData;
                                    }
                                }
                            }
                        }

                        // Success
                        status = READY;
                        emitComplete(true);
                        if (handleTexturesDensityChange) {
                            checkTexturesDensity();
                        }

                    }
                    else {

                        status = BROKEN;
                        ceramic.App.app.logger.error('Failed to load spine pages at path: $path');
                        emitComplete(false);
                    }


                });

                assets.load();
                
            }
            else {
                status = BROKEN;
                ceramic.App.app.logger.error('Failed to load spine data at path: $path');
                emitComplete(false);
            }

        };
        assets.onceComplete(this, handleAssetsComplete);

        assets.load();

    }

    function loadPage(page:AtlasPage, path:String, ?basePath:String):Void {
        
        log.info('Load atlas page ${page.name} / $path / $basePath');

        path = Path.join([(basePath != null ? basePath : this.path), path]);
        var pathInfo = Assets.decodePath(path);
        var asset = new ImageAsset(pathInfo.name);
        asset.density = 1;
        asset.handleTexturesDensityChange = false;
        asset.path = pathInfo.path;
        asset.onDestroy(this, function(_) {
            if (pages.get(page) == asset) {
                pages.remove(page);
            }
        });

        assets.addAsset(asset);
        pages.set(page, asset);

    }

    function unloadPage(page:AtlasPage):Void {

        var asset = pages.get(page);

        if (asset != null) {
            pages.remove(page);
            asset.destroy();

        } else {
            ceramic.App.app.logger.warning('Cannot unload spine page: ' + page);
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

        if (atlasAsset == null) return;

        var prevPath = atlasAsset.path;
        atlasAsset.computePath(['atlas']);
        var path = atlasAsset.path;

        if (prevPath != path) {
            ceramic.App.app.logger.info('Reload spine ($prevPath -> $path)');
            load();
        }

    }

    override function assetFilesDidChange(newFiles:ImmutableMap<String, Float>, previousFiles:ImmutableMap<String, Float>):Void {

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
            log.info('Reload spine (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        if (spineData != null) {
            spineData.destroy();
            spineData = null;
        }

    }

}
