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
import haxe.Json;
import spine.support.graphics.TextureAtlas;
import spine.support.utils.JsonValue;

using StringTools;

/**
 * Asset loader for Spine 2D skeletal animation data.
 * 
 * This asset handles loading Spine JSON files along with their associated
 * texture atlases and images. It automatically manages:
 * - JSON skeleton data parsing
 * - Atlas file loading with texture page management
 * - Hot-reloading when source files change
 * - Texture density switching for different screen resolutions
 * - Spine data lifecycle and memory management
 * 
 * ## File Structure
 * 
 * A typical Spine asset folder contains:
 * - `skeleton.json` - The skeleton and animation data
 * - `skeleton.atlas` - Texture atlas definition
 * - `skeleton.png` - One or more texture pages
 * 
 * ## Usage Example
 * 
 * ```haxe
 * var spineAsset = assets.spine('hero');
 * var spine = new Spine();
 * spine.spineData = spineAsset.spineData;
 * ```
 * 
 * @see SpineData
 * @see Spine
 */
class SpineAsset extends Asset {

/// Events

    /**
     * Emitted when the spine data is replaced during hot-reload.
     * This allows Spine instances to update their data automatically.
     * 
     * @param newSpineData The newly loaded spine data
     * @param prevSpineData The previous spine data being replaced
     */
    @event function replaceSpineData(newSpineData:SpineData, prevSpineData:SpineData);

/// Properties

    /**
     * The raw JSON string containing the skeleton data.
     * Available after the asset is loaded.
     */
    public var json:String = null;

    /**
     * The parsed texture atlas containing all texture regions.
     * Maps skeleton attachments to texture coordinates.
     */
    public var atlas:TextureAtlas = null;

    /**
     * The fully loaded Spine data ready for use in animations.
     * Contains skeleton structure, animations, and texture references.
     */
    @observe public var spineData:SpineData = null;

    /**
     * Scale factor applied to the skeleton data.
     * Use this to adjust the size of Spine animations at load time.
     * Default is 1.0.
     */
    public var scale:Float = 1.0;

    /**
     * Map of atlas pages to their corresponding image assets.
     * Used internally to manage texture loading and lifecycle.
     */
    public var pages:Map<AtlasPage,ImageAsset> = new Map();

/// Internal

    var atlasAsset:TextAsset = null;

/// Lifecycle

    /**
     * Creates a new Spine asset.
     * 
     * @param name The asset name (typically the folder name containing Spine files)
     * @param variant Optional variant for different asset versions
     * @param options Asset loading options, including scale factor
     */
    override public function new(name:String, ?variant:String, ?options:AssetOptions) {

        super('spine', name, variant, options);
        handleTexturesDensityChange = true;

        if (this.options.scale != null) {
            scale = Std.parseFloat(''+options.scale);
            if (Math.isNaN(scale)) {
                ceramic.App.app.logger.warning('Invalid scale option: ' + options.scale);
                scale = 1.0;
            }
        }

        assets = new Assets();

    }

    /**
     * Loads the Spine asset files.
     * 
     * This method:
     * 1. Discovers JSON and atlas files in the asset folder
     * 2. Loads the JSON skeleton data
     * 3. Loads the atlas file and its texture pages
     * 4. Creates the SpineData instance
     * 5. Handles hot-reload if files were previously loaded
     */
    override public function load() {

        if (owner != null) {
            assets.inheritRuntimeAssetsFromAssets(owner);
            assets.loadMethod = owner.loadMethod;
            assets.scheduleMethod = owner.scheduleMethod;
            assets.delayBetweenXAssets = owner.delayBetweenXAssets;
        }

        // Load spine data
        status = LOADING;
        ceramic.App.app.logger.info('Load spine $path');

        // Use runtime assets if provided
        assets.runtimeAssets = runtimeAssets;

        // Retrieve json asset
        //
        var prefix = path + '/';
        var jsonPath = null;
        var rawAtlasPaths:Array<String> = [];
        for (entry in Assets.all) {
            if (entry.startsWith(prefix)) {
                var lowerCaseEntry = entry.toLowerCase();
                if (jsonPath == null && lowerCaseEntry.endsWith('.json')) {
                    jsonPath = entry;
                }
                if (lowerCaseEntry.endsWith('.atlas')) {
                    rawAtlasPaths.push(entry);
                }
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
            var atlasPath = null;
            for (rawAtlasPath in rawAtlasPaths) {
                if (Assets.assetNameFromPath(rawAtlasPath) == baseName) {
                    atlasPath = baseName + '.atlas';
                    break;
                }
            }
            if (atlasPath == null && rawAtlasPaths.length > 0) {
                atlasPath = Assets.assetNameFromPath(rawAtlasPaths[0]) + '.atlas';
            }
            else {
                atlasPath = baseName + '.atlas';
            }
            atlasAsset = new TextAsset(atlasPath);
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
                            new JsonDynamic(Json.parse(json.getContent())),
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
                                if (Std.isOfType(visual, Spine)) {
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

    /**
     * Loads a texture page for the atlas.
     * 
     * Called by the SpineTextureLoader when the atlas references a texture.
     * Creates an ImageAsset for each texture page and tracks it.
     * 
     * @param page The atlas page to load
     * @param path The texture file path
     * @param basePath Optional base directory path
     */
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

    /**
     * Unloads a texture page from memory.
     * 
     * Removes the page from tracking and destroys its image asset.
     * 
     * @param page The atlas page to unload
     */
    function unloadPage(page:AtlasPage):Void {

        var asset = pages.get(page);

        if (asset != null) {
            pages.remove(page);
            asset.destroy();

        } else {
            ceramic.App.app.logger.warning('Cannot unload spine page: ' + page);
        }

    }

    /**
     * Called when the texture density changes (e.g., switching to @2x textures).
     * Triggers a reload if the atlas path changes due to density.
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
     * Checks if texture density change requires reloading the asset.
     * This happens when different density atlases are available.
     */
    function checkTexturesDensity():Void {

        if (owner == null || !owner.reloadOnTextureDensityChange)
            return;

        if (atlasAsset == null) return;

        var prevPath = atlasAsset.path;
        atlasAsset.computePath(['atlas']);
        var path = atlasAsset.path;

        if (prevPath != path) {
            ceramic.App.app.logger.info('Reload spine ($prevPath -> $path)');
            load();
        }

    }

    /**
     * Handles hot-reload when asset files change on disk.
     * Automatically reloads the Spine data when source files are modified.
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
            log.info('Reload spine (file has changed)');
            load();
        }

    }

    /**
     * Cleans up the asset and releases all resources.
     * Destroys the SpineData and all associated textures.
     */
    override function destroy():Void {

        super.destroy();

        if (spineData != null) {
            spineData.destroy();
            spineData = null;
        }

    }

}
