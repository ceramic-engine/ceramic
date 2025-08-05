package ceramic;

import ceramic.Shortcuts.*;

using StringTools;

#if plugin_ase
import ase.Ase;
#end

/**
 * Asset type for loading image files as textures.
 * 
 * Supports various image formats including PNG, JPG, WebP (backend-dependent),
 * and Aseprite files (.ase/.aseprite) when the ase plugin is enabled.
 * 
 * Features:
 * - Automatic density selection based on screen resolution
 * - Hot reload support for development
 * - Texture replacement with automatic visual updates
 * - Integration with texture atlas packing
 * 
 * ```haxe
 * var assets = new Assets();
 * assets.addImage('hero.png');
 * assets.load();
 * 
 * // Access loaded texture
 * var texture = assets.texture('hero');
 * ```
 */
class ImageAsset extends Asset {

/// Events

    /**
     * Emitted when the texture is replaced (e.g., during hot reload).
     * All visuals using the previous texture are automatically updated.
     * @param newTexture The newly loaded texture
     * @param prevTexture The previous texture being replaced
     */
    @event function replaceTexture(newTexture:Texture, prevTexture:Texture);

/// Properties

    /**
     * The loaded texture instance.
     * Observable property that updates when the texture is loaded or replaced.
     * Null until the asset is successfully loaded.
     */
    @observe public var texture:Texture = null;

/// Internal

    @:allow(ceramic.Assets)
    var defaultImageOptions:AssetOptions = null;

    var reloadBecauseOfDensityChange:Bool = false;

    #if plugin_ase

    var aseTexWidth:Int = -1;

    var aseTexHeight:Int = -1;

    var asePadding:Int = 0;

    var aseSpacing:Int = 0;

    #end

/// Lifecycle

    /**
     * Create a new image asset.
     * @param name Image file name (with or without extension)
     * @param variant Optional variant suffix
     * @param options Loading options including:
     *                - premultiplyAlpha: Whether to premultiply alpha channel
     *                - width/height: For Aseprite grid texture loading
     *                - layers: Specific layers to load from Aseprite files
     */
    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('image', name, variant, options #if ceramic_debug_entity_allocs , pos #end);
        handleTexturesDensityChange = true;

    }

    /**
     * Load the image file and create a texture.
     * Handles density selection, hot reload, and visual updates.
     * Emits complete event when finished.
     */
    override public function load() {

        status = LOADING;

        var reloadBecauseOfDensityChange = this.reloadBecauseOfDensityChange;
        this.reloadBecauseOfDensityChange = false;

        if (path == null) {
            log.warning('Cannot load image asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        var loadOptions:AssetOptions = {};
        if (owner != null) {
            loadOptions.immediate = owner.immediate;
            loadOptions.loadMethod = owner.loadMethod;
        }
        if (defaultImageOptions != null) {
            for (key in Reflect.fields(defaultImageOptions)) {
                Reflect.setField(loadOptions, key, Reflect.field(defaultImageOptions, key));
            }
        }
        if (options != null) {
            for (key in Reflect.fields(options)) {
                Reflect.setField(loadOptions, key, Reflect.field(options, key));
            }
        }

        loadTexture(path, loadOptions, function(newTexture, backendPath) {

            if (newTexture != null) {


                var prevTexture = this.texture;
                newTexture.id = 'texture:' + backendPath;
                this.texture = newTexture;

                // Link the texture to this asset so that
                // destroying one will destroy the other
                this.texture.asset = this;

                if (prevTexture != null) {

                    // Use same filter as previous texture
                    this.texture.filter = prevTexture.filter;

                    // When replacing the texture, emit an event to notify about it
                    emitReplaceTexture(this.texture, prevTexture);

                    // Texture was reloaded. Update related visuals
                    for (visual in [].concat(app.visuals)) {
                        if (!visual.destroyed) {
                            if (visual.asQuad != null) {
                                var quad = visual.asQuad;
                                if (quad.texture == prevTexture) {

                                    // Update texture but keep same frame
                                    //
                                    var frameX = quad.frameX;
                                    var frameY = quad.frameY;
                                    var frameWidth = quad.frameWidth;
                                    var frameHeight = quad.frameHeight;

                                    quad.texture = this.texture;

                                    // We keep the frame, unless image
                                    // is being hot-reloaded and its frame is all texture area
                                    if (reloadBecauseOfDensityChange
                                        || frameX != 0 || frameY != 0
                                        || frameWidth != prevTexture.width
                                        || frameHeight != prevTexture.height
                                    ) {
                                        // Frame was reset by texture assign.
                                        // Put it back to what it was.
                                        quad.frameX = frameX;
                                        quad.frameY = frameY;
                                        quad.frameWidth = frameWidth;
                                        quad.frameHeight = frameHeight;
                                    }
                                }
                            }
                            else if (visual.asMesh != null) {
                                var mesh = visual.asMesh;
                                if (mesh.texture == prevTexture) {
                                    mesh.texture = this.texture;
                                }
                            }
                        }
                    }

                    // Set asset to null because we don't want it
                    // to be destroyed when destroying the texture.
                    prevTexture.asset = null;
                    // Destroy texture
                    prevTexture.destroy();
                }

                status = READY;
                emitComplete(true);
                if (handleTexturesDensityChange) {
                    checkTexturesDensity();
                }
            }
            else {
                log.warning('Failed to decode texture');
                status = BROKEN;
                emitComplete(false);
            }

        });

    }

    function loadTexture(path:String, loadOptions:AssetOptions, callback:(texture:Texture, backendPath:String)->Void) {

        // Add reload count if any
        var backendPath = path;
        var realPath = Assets.realAssetPath(backendPath, runtimeAssets);
        var assetReloadedCount = Assets.getReloadCount(realPath);
        if (app.backend.textures.supportsHotReloadPath() && assetReloadedCount > 0) {
            realPath += '?hot=' + assetReloadedCount;
            backendPath += '?hot=' + assetReloadedCount;
        }

        log.info('Load image $backendPath (density=$density)');

        #if plugin_ase
        if (path != null && (path.toLowerCase().endsWith('.ase') || path.toLowerCase().endsWith('.aseprite'))) {

            app.backend.binaries.load(realPath, loadOptions, function(bytes) {

                if (bytes != null) {
                    try {

                        if (options != null && options.width != null && options.height != null) {
                            aseTexWidth = options.width;
                            aseTexHeight = options.height;
                        }

                        final loadGridTexture = (aseTexWidth > 0 && aseTexHeight > 0);

                        // Decode ase data, but once we have our texture, destroy that ase data
                        var ase:Ase = Ase.fromBytes(bytes);
                        var asepriteData = AsepriteParser.parseAse(ase, backendPath, null, loadGridTexture ? -1 : 0, {
                            layers: options?.layers
                        });

                        var texture:Texture = if (loadGridTexture) {
                            AsepriteParser.parseGridTextureFromAsepriteData(
                                asepriteData, 0, asepriteData.frames.length + 1,
                                aseTexWidth, aseTexHeight, aseSpacing, asePadding,
                                density
                            );
                        }
                        else {
                            AsepriteParser.parseTextureFromAsepriteData(asepriteData, 0, density);
                        }

                        asepriteData.destroy();

                        callback(texture, backendPath);
                    }
                    catch (e:Dynamic) {
                        status = BROKEN;
                        log.error('Failed to decode ase image at path: $path ($e)');
                        emitComplete(false);
                    }
                }
                else {
                    status = BROKEN;
                    log.error('Failed to load ase image at path: $path');
                    emitComplete(false);
                }

            });

        }
        else {
        #end

            app.backend.textures.load(realPath, loadOptions, function(image) {

                if (image != null) {

                    var newTexture = new Texture(image, density);
                    callback(newTexture, backendPath);

                }
                else {
                    status = BROKEN;
                    log.error('Failed to load texture at path: $path');
                    emitComplete(false);
                }

            });

        #if plugin_ase
        }
        #end

    }

    /**
     * Handle screen density changes by reloading the texture at appropriate resolution.
     * Only triggers if the asset is already loaded and a better resolution is available.
     */
    override function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        if (status == READY) {
            // Only check if the asset is already loaded.
            // If it is currently loading, it will check
            // at load end anyway.
            checkTexturesDensity();
        }

    }

    function checkTexturesDensity():Void {

        if (owner == null || !owner.reloadOnTextureDensityChange)
            return;

        var prevPath = path;
        computePath();

        if (prevPath != path) {
            log.info('Reload texture ($prevPath -> $path)');
            reloadBecauseOfDensityChange = true;
            load();
        }

    }

    /**
     * Handle file system changes for hot reload.
     * Automatically reloads the texture when the source file is modified.
     */
    override function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        if (!app.backend.textures.supportsHotReloadPath())
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
            log.info('Reload texture (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        if (texture != null) {
            texture.destroy();
            texture = null;
        }

    }

}
