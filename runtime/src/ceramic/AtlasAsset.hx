package ceramic;

import ceramic.Path;
import ceramic.Shortcuts.*;

/**
 * Asset for loading texture atlases (sprite sheets with metadata).
 *
 * AtlasAsset handles loading of texture atlas files which contain multiple
 * packed textures/sprites along with their position metadata. It supports
 * both Spine/LibGDX atlas format (.atlas) and XML atlas formats.
 *
 * Features:
 * - Automatic texture loading for all atlas pages
 * - Hot-reload support for atlas files
 * - Density-aware loading (e.g., @2x variants)
 * - Automatic visual updates when atlas is reloaded
 * - Custom atlas parser support
 *
 * The loaded atlas can be used with Quad visuals to display specific regions:
 *
 * @example
 * ```haxe
 * // Load an atlas
 * var atlasAsset = new AtlasAsset('myAtlas');
 * atlasAsset.path = 'atlases/sprites.atlas';
 * atlasAsset.onComplete(this, success -> {
 *     if (success) {
 *         // Get a specific region from the atlas
 *         var region = atlasAsset.atlas.region('player_idle');
 *
 *         // Use it with a Quad
 *         var quad = new Quad();
 *         quad.tile = region;
 *
 *         // Use it with a Sprite
 *         // (requires sprite plugin) Sprite has better atlas region support than Quad:
 *         // region offsets are properly handled, allowing trimmed/packed sprites
 *         // to display correctly with their original bounds and pivot points.
 *         var sprite = new Sprite();
 *         sprite.region = region;
 *     }
 * });
 * assets.addAsset(atlasAsset);
 * assets.load();
 * ```
 *
 * @see TextureAtlas
 * @see TextureAtlasRegion
 * @see ImageAsset
 */
class AtlasAsset extends Asset {

/// Events

    /**
     * Emitted when the atlas is replaced (typically during hot-reload).
     * @param newAtlas The newly loaded atlas
     * @param prevAtlas The previous atlas that was replaced
     */
    @event function replaceAtlas(newAtlas:TextureAtlas, prevAtlas:TextureAtlas);

/// Properties

    /**
     * The loaded texture atlas containing all regions and pages.
     * Will be null until the asset is successfully loaded.
     */
    @observe public var atlas:TextureAtlas = null;

    /**
     * The raw text content of the atlas file.
     * Can be used to inspect the atlas metadata.
     */
    @observe public var text:String = null;

/// Internal

    /**
     * A custom atlas parsing method. Will be used over the default parsing if not null.
     * This allows you to provide your own atlas format parser.
     * The parser should take the raw atlas text and return a TextureAtlas instance.
     */
    var parseAtlas:(text:String)->TextureAtlas = null;

/// Lifecycle

    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('atlas', name, variant, options #if ceramic_debug_entity_allocs , pos #end);
        handleTexturesDensityChange = true;

        assets = new Assets();

    }

    /**
     * Loads the atlas asset.
     *
     * This method:
     * 1. Loads the atlas metadata file
     * 2. Parses the atlas format (auto-detects XML or text format)
     * 3. Loads all texture pages referenced in the atlas
     * 4. Updates existing visuals if this is a reload
     *
     * The loading process is asynchronous and will emit a complete event
     * when finished (either success or failure).
     */
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
        assets.addAsset(asset);
        asset.path = path;
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
                                var texture = asset.texture;
                                if (texture != null)
                                    texture.filter = newAtlas.pages[i].filter;
                                newAtlas.pages[i].texture = texture;
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

    /**
     * Called when the global texture density changes.
     * Triggers a reload if a different density variant exists.
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
     * Checks if the atlas needs to be reloaded due to texture density change.
     * If a different density variant exists (e.g., @2x version), it will reload the atlas.
     */
    function checkTexturesDensity():Void {

        if (owner == null || !owner.reloadOnTextureDensityChange)
            return;

        var prevPath = path;
        computePath();

        if (prevPath != path) {
            log.info('Reload atlas ($prevPath -> $path)');
            load();
        }

    }

    /**
     * Called when asset files change on disk (hot-reload support).
     * Automatically reloads the atlas if its file has been modified.
     * @param newFiles Map of current files and their modification times
     * @param previousFiles Map of previous files and their modification times
     */
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

        if (newTime != previousTime) {
            log.info('Reload atlas (file has changed)');
            load();
        }

    }

    /**
     * Destroys the atlas asset and its loaded atlas.
     * This will also destroy all texture pages associated with the atlas.
     */
    override function destroy():Void {

        super.destroy();

        if (atlas != null) {
            atlas.destroy();
            atlas = null;
        }

    }

}
