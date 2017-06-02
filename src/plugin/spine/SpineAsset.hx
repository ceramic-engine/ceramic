package plugin.spine;

import spine.atlas.*;
import spine.attachments.*;
import spine.*;
import haxe.io.Path;
import ceramic.Assets;
import ceramic.Quad;
import ceramic.Mesh;
import ceramic.Shortcuts.*;

using StringTools;

class SpineAsset extends Asset {

/// Properties

    public var json:String = null;

    public var atlas:Atlas = null;

    public var spineData:SpineData = null;

    public var scale:Float = 1.0;

    public var pages:Map<AtlasPage,ImageAsset> = new Map();

/// Internal

    var atlasAsset:TextAsset = null;

/// Lifecycle

    override public function new(name:String, ?options:AssetOptions) {

        super('spine', name, options);
        handleTexturesDensityChange = true;

        if (options.scale != null) {
            scale = Std.parseFloat(options.scale);
            if (Math.isNaN(scale)) {
                warning('Invalid scale option: ' + options.scale);
                scale = 1.0;
            }
        }

        assets = new Assets();

    } //name

    override public function load() {

        // Load spine data
        status = LOADING;
        log('Load spine $path');

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
            error('Failed to retrieve json path for spine: $path');
            emitComplete(false);
            return;
        }

        var jsonPathInfo = Assets.decodePath(jsonPath);
        var baseName = jsonPathInfo.name;

        var jsonAsset = new TextAsset(baseName + '.json');
        jsonAsset.handleTexturesDensityChange = false;
        jsonAsset.computePath(['json']);

        // Retrieve atlas asset
        //
        if (atlasAsset == null) {
            atlasAsset = new TextAsset(baseName + '.atlas');
            atlasAsset.handleTexturesDensityChange = false;
            atlasAsset.computePath(['atlas']);
            assets.addAsset(atlasAsset);
        }

        // Load json and atlas assets
        //
        var prevAsset = assets.addAsset(jsonAsset);

        // Remove previous json asset if different
        if (prevAsset != null) prevAsset.destroy();

        assets.onceComplete(this, function(success) {

            var json = jsonAsset.text;
            var atlas = atlasAsset.text;

            if (json != null && atlas != null) {

                // Keep prev pages
                var prevPages = pages;
                pages = new Map();

                // Create atlas, which will trigger page loads
                var spineAtlas = new Atlas(
                    atlas,
                    new SpineTextureLoader(this)
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

                        // Create final spine data with all info
                        spineData = new SpineData(
                            spineAtlas,
                            json,
                            name,
                            scale
                        );

                        // Destroy previous pages
                        if (prevPages != null) {
                            for (asset in prevPages) {
                                var texture = asset.texture;
                                for (visual in app.visuals) {
                                    if (Std.is(visual, Quad)) {
                                        var quad:Quad = cast visual;
                                        if (quad.texture == texture) {
                                            quad.texture = null;
                                        }
                                    }
                                    else if (Std.is(visual, Mesh)) {
                                        var mesh:Mesh = cast visual;
                                        if (mesh.texture == texture) {
                                            mesh.texture = null;
                                        }
                                    }
                                }
                                asset.destroy();
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
                        error('Failed to load spine pages at path: $path');
                        emitComplete(false);
                    }


                });

                assets.load();
                
            }
            else {
                status = BROKEN;
                error('Failed to load spine data at path: $path');
                emitComplete(false);
            }

        });

        assets.load();

    } //load

    function loadPage(page:AtlasPage, path:String):Void {

        path = Path.join([this.path, path]);
        var pathInfo = Assets.decodePath(path);
        var asset = new ImageAsset(pathInfo.name);
        asset.handleTexturesDensityChange = false;
        asset.path = pathInfo.path;

        assets.addAsset(asset);
        pages.set(page, asset);

    } //loadPage

    function unloadPage(page:AtlasPage):Void {

        var asset = pages.get(page);

        if (asset != null) {
            pages.remove(page);
            asset.destroy();

        } else {
            warning('Cannot unload spine page: ' + page);
        }

    } //loadPage

    override function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        if (status == READY) {
            // Only check if the asset is already loaded.
            // If it is currently loading, it will check
            // at load end anyway.
            checkTexturesDensity();
        }

    } //texturesDensityDidChange

    function checkTexturesDensity():Void {

        if (atlasAsset == null) return;

        var prevPath = atlasAsset.path;
        atlasAsset.computePath(['atlas']);
        var path = atlasAsset.path;

        if (prevPath != path) {
            log('Reload spine ($prevPath -> $path)');
            load();
        }

    } //checkTexturesDensity

    function destroy():Void {

        if (spineData != null) {
            spineData.destroy();
            spineData = null;
        }

    } //destroy

} //SpineAsset
