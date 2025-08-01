package ceramic;

import ceramic.Path;
import ceramic.Shortcuts.*;
import tracker.Observable;

using StringTools;

/**
 * Base class for all asset types in Ceramic.
 * 
 * Assets represent loadable resources like images, fonts, sounds, etc.
 * This class provides common functionality including:
 * - Path resolution based on density and variants
 * - Reference counting for memory management
 * - Hot reload support
 * - Asset lifecycle management
 * 
 * Asset subclasses should override the `load()` method to implement
 * specific loading logic for their asset type.
 * 
 * @see Assets
 */
@:allow(ceramic.Assets)
class Asset extends Entity implements Observable {

/// Events

    /**
     * Emitted when the asset finishes loading.
     * @param success True if the asset loaded successfully, false if it failed
     */
    @event function complete(success:Bool);

/// Properties

    /**
     * Asset kind identifier (e.g., 'image', 'font', 'sound').
     * Used to categorize assets and determine loading behavior.
     */
    public var kind(default,null):String;

    /**
     * Asset name without extension or variant.
     * Setting this triggers path recomputation.
     */
    public var name(default,set):String;

    /**
     * Optional variant suffix for the asset.
     * Useful for loading different versions of the same asset (e.g., 'large', 'small').
     */
    public var variant(default,set):String;

    /**
     * Full asset identifier including variant if provided.
     * Format: 'name' or 'name:variant'
     */
    public var fullName(default,null):String;

    /**
     * Resolved file path for this asset.
     * Automatically computed based on name, variant, density, and available files.
     */
    public var path(default,set):String;

    /**
     * All available file paths for this asset across different densities.
     * Useful for preloading multiple resolutions.
     */
    public var allPaths(default,null):Array<String>;

    /**
     * Asset target density matching the best available file.
     * Automatically set based on screen density and available asset files.
     * Default is 1.0.
     */
    public var density(default,null):Float = 1.0;

    /**
     * The Assets instance that owns this asset.
     * When the owner is destroyed, all its assets are destroyed too.
     */
    public var owner(default,null):Assets;

    /**
     * Optional runtime assets configuration for dynamic asset loading.
     * Used to compute paths when loading assets from custom directories.
     */
    public var runtimeAssets(default,set):RuntimeAssets;

    /**
     * Asset-specific loading options.
     * Content depends on asset type and backend implementation.
     * Common options include premultiplyAlpha for images, streaming for sounds, etc.
     */
    public var options(default,null):AssetOptions;

    /**
     * Sub-assets owned by this asset.
     * Some assets (like bitmap fonts) create this to manage their dependencies.
     * Automatically destroyed when the parent asset is destroyed.
     */
    public var assets(default,null):Assets = null;

    /**
     * Reference count for memory management.
     * - Call `retain()` to increase (claim ownership)
     * - Call `release()` to decrease (release ownership)
     * - Asset can be safely destroyed when refCount reaches 0
     * 
     * @example
     * ```haxe
     * var texture = assets.texture('hero');
     * texture.retain(); // refCount = 1
     * // ... use texture ...
     * texture.release(); // refCount = 0, can be cleaned up
     * ```
     */
    public var refCount(default,null):Int = 0;

    /**
     * Current loading status of the asset.
     * Observable property that triggers updates when status changes.
     * - NONE: Not loaded
     * - LOADING: Currently loading  
     * - READY: Successfully loaded
     * - BROKEN: Failed to load
     */
    @observe public var status:AssetStatus = NONE;

    var handleTexturesDensityChange(default,set):Bool = false;

    var hotReload(default,set):Bool = false;

    var customExtensions(default,null):Array<String> = null;

/// Lifecycle

    /**
     * Create a new asset.
     * @param kind The asset type identifier
     * @param name The asset name (without extension)
     * @param variant Optional variant suffix
     * @param options Loading options specific to the asset type
     */
    public function new(kind:String, name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        this.kind = kind;
        this.options = options != null ? options : {};
        this.name = name;
        this.variant = variant;

        computePath();

    }

    /**
     * Load the asset.
     * Subclasses must override this method to implement actual loading logic.
     * Should set status to LOADING during load, then READY or BROKEN when complete.
     * Must call emitComplete() when finished.
     */
    public function load():Void {

        status = BROKEN;
        log.error('This asset as no load implementation.');
        emitComplete(false);

    }

    /**
     * Destroy this asset and clean up resources.
     * - Removes from owner Assets instance
     * - Destroys any sub-assets
     * - Should not be called directly if refCount > 0
     */
    override function destroy():Void {

        super.destroy();

        if (owner != null) {
            owner.removeAsset(this);
            owner = null;
        }

        if (assets != null) {
            assets.destroy();
            assets = null;
        }

    }

    /**
     * Compute the best file path for this asset based on available files and screen density.
     * Automatically called during initialization and when properties change.
     * 
     * @param extensions File extensions to look for (auto-detected if not provided)
     * @param dir Whether to look for directories instead of files
     * @param runtimeAssets Runtime assets configuration to use
     */
    public function computePath(?extensions:Array<String>, ?dir:Bool, ?runtimeAssets:RuntimeAssets):Void {

        // Runtime assets
        if (runtimeAssets == null && this.runtimeAssets != null) {
            runtimeAssets = this.runtimeAssets;
        }

        // Compute extensions list and dir flag
        //
        if (extensions == null) {
            extensions = switch (kind) {
                #if plugin_ase
                case 'image': app.backend.info.imageExtensions().concat(['ase', 'aseprite']);
                #else
                case 'image': app.backend.info.imageExtensions();
                #end
                case 'text': app.backend.info.textExtensions();
                case 'sound': app.backend.info.soundExtensions();
                case 'shader': app.backend.info.shaderExtensions();
                case 'font': ['fnt', 'ttf', 'otf'];
                case 'atlas': ['atlas'];
                case 'database': ['csv'];
                case 'fragments': ['fragments'];
                default: null;
            }
        }
        if (extensions == null || dir == null) {
            if (Assets.customAssetKinds.exists(kind)) {
                var kindInfo = Assets.customAssetKinds.get(kind);
                if (extensions == null) extensions = kindInfo.extensions;
                if (dir == null) dir = kindInfo.dir;
            }
        }
        if (extensions == null) extensions = [];
        if (customExtensions != null) {
            extensions = extensions.concat(customExtensions);
        }
        if (dir == null) dir = false;

        // Compute path
        //
        var targetDensity = screen.texturesDensity;
        var path = null;
        var allPaths = [];
        var bestPathInfo = null;

        var byName:Map<String,Array<String>> = dir ?
            runtimeAssets != null ?
                runtimeAssets.getLists().allDirsByName
            :
                Assets.allDirsByName
        :
            runtimeAssets != null ?
                runtimeAssets.getLists().allByName
            :
                Assets.allByName
        ;

        var name = this.name;

        // When the name is an absolute path, use it as path
        if (path == null && name != null && Path.isAbsolute(name)) {
            path = name;
        }

        if (extensions.length > 0) {

            // Remove extension in name, if any
            for (ext in extensions) {
                if (name.endsWith('.' + ext)) {
                    name = name.substr(0, name.length - ext.length - 1);
                    break;
                }
            }

            var resolvedPath = false;

            if (byName.exists(name)) {

                var list = byName.get(name);

                for (ext in extensions) {

                    var bestDensity = 1.0;
                    var bestDensityDiff = 99999999999.0;

                    for (item in list) {
                        var pathInfo = Assets.decodePath(item);

                        if (pathInfo.extension == ext) {
                            if (!resolvedPath) {
                                var diff = Math.abs(targetDensity - pathInfo.density);
                                if (diff < bestDensityDiff) {
                                    bestDensityDiff = diff;
                                    bestDensity = pathInfo.density;
                                    path = pathInfo.path;
                                    bestPathInfo = pathInfo;
                                }
                            }
                            allPaths.push(pathInfo.path);
                        }
                    }

                    if (path != null) {
                        resolvedPath = true;
                    }
                }
            }
        }

        if (path == null) {
            path = name;
        }

        this.allPaths = allPaths;
        this.path = path; // sets density

        // Set additional options
        if (bestPathInfo != null && bestPathInfo.flags != null) {
            for (flag in bestPathInfo.flags.keys()) {
                if (!Reflect.hasField(options, flag)) {
                    Reflect.setField(options, flag, bestPathInfo.flags.get(flag));
                }
            }
        }

    }

    function set_path(path:String):String {

        if (this.path == path) return path;

        // Loaded data doesn't match path anymore
        if (status == READY) status = NONE;

        this.path = path;

        if (path == null) {
            density = 1.0;
        } else {
            density = Assets.decodePath(path).density;
        }

        return path;

    }

    function set_name(name:String):String {

        if (this.name == name) return name;

        this.name = name;

        fullName = variant != null ? '$name:$variant' : name;
        id = 'asset:$kind:$fullName';

        return name;

    }

    function set_variant(variant:String):String {

        if (this.variant == variant) return variant;

        this.variant = variant;

        fullName = variant != null ? '$name:$variant' : name;
        id = 'asset:$kind:$fullName';

        return name;

    }

    function set_runtimeAssets(runtimeAssets:RuntimeAssets):RuntimeAssets {

        if (this.runtimeAssets == runtimeAssets) return runtimeAssets;

        this.runtimeAssets = runtimeAssets;
        computePath();

        return runtimeAssets;

    }

    function set_handleTexturesDensityChange(value:Bool):Bool {

        if (handleTexturesDensityChange == value) return value;
        handleTexturesDensityChange = value;

        if (value) {
            screen.onTexturesDensityChange(this, texturesDensityDidChange);
        }
        else {
            screen.offTexturesDensityChange(texturesDensityDidChange);
        }

        return value;

    }

    /**
     * Called when screen texture density changes.
     * Subclasses can override to handle density changes (e.g., reload at new resolution).
     * @param newDensity The new texture density
     * @param prevDensity The previous texture density
     */
    function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        // Override

    }

    function set_hotReload(value:Bool):Bool {

        if (hotReload == value) return value;
        hotReload = value;

        if (value) {
            owner.onAssetFilesChange(this, assetFilesDidChange);
        }
        else {
            owner.offAssetFilesChange(assetFilesDidChange);
        }

        return value;

    }

    /**
     * Called when watched asset files change on disk.
     * Subclasses can override to implement hot reload behavior.
     * @param newFiles Map of file paths to modification times after change
     * @param previousFiles Map of file paths to modification times before change
     */
    function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        // Override

    }

/// Print

    /**
     * String representation of the asset for debugging.
     * @return String in format "AssetType(name:variant path)" or "AssetType(name:variant)"
     */
    override function toString():String {

        var className = className();

        if (path != null && path.trim() != '') {
            return '$className($fullName $path)';
        } else {
            return '$className($fullName)';
        }

    }

/// Complete event hook

    inline function willEmitComplete(success:Bool) {

        if (success && owner != null) {
            owner.emitUpdate(this);
        }

    }

/// Reference counting

    /**
     * Increase the reference count by 1.
     * Call this when you start using an asset to prevent it from being destroyed.
     * Must be balanced with a corresponding `release()` call.
     * 
     * @see release
     */
    public function retain():Void {

        #if ceramic_debug_refcount
        ceramic.Utils.printStackTrace();
        log.success('RETAIN ' + this + ' $refCount + 1');
        #end
        refCount++;

    }

    /**
     * Decrease the reference count by 1.
     * Call this when you're done using an asset.
     * When refCount reaches 0, the asset can be safely destroyed.
     * 
     * Warning: Calling release() when refCount is already 0 will log a warning.
     * 
     * @see retain
     */
    public function release():Void {

        #if ceramic_debug_refcount
        ceramic.Utils.printStackTrace();
        log.success('RELEASE ' + this + ' $refCount - 1');
        #end
        if (refCount == 0) {
            log.warning('Called release() on asset ' + this + ' when its refCount is already 0 (destroyed=${destroyed})');
        }
        else {
            refCount--;
        }

    }

}
