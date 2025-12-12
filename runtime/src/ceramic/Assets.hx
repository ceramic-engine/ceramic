package ceramic;

import ceramic.Path;
import ceramic.Shortcuts.*;
import haxe.DynamicAccess;
import haxe.io.Bytes;

using StringTools;
using ceramic.Extensions;

/**
 * The main asset management class for Ceramic framework.
 *
 * Handles loading, managing, and hot-reloading of various asset types including:
 * - Images/Textures
 * - Fonts (bitmap and TTF/OTF)
 * - Atlases (texture atlases)
 * - Text files
 * - Binary data
 * - Sounds/Audio
 * - Databases (CSV)
 * - Fragments (JSON-based UI/game fragments)
 * - Shaders
 *
 * Features:
 * - Reference counting for memory management
 * - Asset variants and density handling for multi-resolution support
 * - Hot reloading when watching directories
 * - Parent-child asset relationships
 * - Custom asset type registration
 * - Parallel/serial loading strategies
 *
 * ```haxe
 * var assets = new Assets();
 * assets.addImage('hero.png');
 * assets.addFont('main.fnt');
 * assets.load();
 * ```
 */
@:allow(ceramic.Asset)
class Assets extends Entity {

    /**
     * All active Assets instances in the application.
     * Read-only array to prevent external modification.
     */
    public static var instances:ReadOnlyArray<Assets> = [];

    /**
     * All available asset paths in the project.
     */
    public static var all:Array<String> = [];

    /**
     * All available directory paths in the project.
     */
    public static var allDirs:Array<String> = [];

    /**
     * Map of asset names to their available file paths.
     * Useful for finding all variants of an asset.
     */
    public static var allByName:Map<String,Array<String>> = new Map();

    /**
     * Map of directory names to their paths.
     */
    public static var allDirsByName:Map<String,Array<String>> = new Map();

/// Events

    /**
     * Emitted when all assets have finished loading.
     * @param success True if all assets loaded successfully, false if any failed
     */
    @event function complete(success:Bool);

    /**
     * Emitted when an individual asset is updated (loaded, reloaded, etc).
     * @param asset The asset that was updated
     */
    @event function update(asset:Asset);

    /**
     * Emitted during loading to report progress.
     * @param loaded Number of assets loaded so far
     * @param total Total number of assets to load
     * @param success True if all loaded assets succeeded so far
     */
    @event function progress(loaded:Int, total:Int, success:Bool);

    /**
     * Emitted when watched asset files change on disk.
     * @param newFiles Map of file paths to their modification times after change
     * @param previousFiles Map of file paths to their modification times before change
     */
    @event function assetFilesChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>);

/// Properties

    var addedAssets:Array<Asset> = [];

    var assetsByKindAndName:Map<String,Map<String,Asset>> = new Map();

    public var immediate(default,null) = new Immediate();

    /**
     * If set, will be provided to each added asset in this `Assets` instance.
     * Used for runtime asset loading from file system.
     */
    public var runtimeAssets:RuntimeAssets = null;

    /**
     * Default options applied to all image assets added to this instance.
     * Can be overridden per asset.
     */
    public var defaultImageOptions:AssetOptions = null;

    /**
     * The loading method to use (SYNC or ASYNC).
     * SYNC blocks until loading completes, ASYNC loads in background.
     */
    public var loadMethod:AssetsLoadMethod = SYNC;

    /**
     * The scheduling method for loading multiple assets.
     * PARALLEL loads all at once, SERIAL loads one at a time.
     */
    public var scheduleMethod:AssetsScheduleMethod = PARALLEL;

    /**
     * If > 0, adds a delay every X assets when loading in parallel.
     * Useful to avoid overwhelming the system with too many concurrent loads.
     */
    public var delayBetweenXAssets:Int = -1;

    /**
     * Whether to automatically reload assets when texture density changes.
     * Useful for supporting multiple screen resolutions.
     */
    public var reloadOnTextureDensityChange = true;

    /**
     * If provided, when requesting an asset, it will also check if the parent `Assets`
     * instance has it and return it if that's the case.
     */
    public var parent:Assets = null;

    /**
     * A shared texture atlas packer that can be used to merge smaller textures together.
     * Also required when loading some kind of assets, like `.ase`/`.aseprite` files.
     */
    public var atlasPacker:TextureAtlasPacker = null;

/// Internal

    private var pendingAtlasPackers:Array<TextureAtlasPacker> = null;

    static var customAssetKinds:Map<String,CustomAssetKind> = new Map();

    static var reloadCountByRealAssetPath:Map<String, Int> = null;

    static var lastModifiedByRealAssetPath:Map<String, Float> = null;

/// Lifecycle

    public function new() {

        super();

        instances.original.push(this);

    }

    static var _instances:Array<Assets> = [];

    public static function flushAllInstancesImmediate():Void {

        var len = instances.length;
        for (i in 0...len) {
            _instances[i] = instances.unsafeGet(i);
        }
        for (i in 0...len) {
            var assets = _instances.unsafeGet(i);
            _instances.unsafeSet(i, null);
            if (!assets.destroyed) {
                assets.immediate.flush();
            }
        }

    }

    override function destroy() {

        super.destroy();

        instances.original.remove(this);

        for (asset in [].concat(addedAssets)) {
            asset.offDestroy(assetDestroyed);
            asset.destroy();
        }
        addedAssets = null;
        assetsByKindAndName = null;

        if (atlasPacker != null) {
            var _atlasPacker = atlasPacker;
            atlasPacker = null;
            _atlasPacker.destroy();
        }

        if (pendingAtlasPackers != null) {
            var _pendingAtlasPackers = pendingAtlasPackers;
            pendingAtlasPackers = null;
            for (i in 0..._pendingAtlasPackers.length) {
                _pendingAtlasPackers[i].destroy();
            }
        }

    }

    /**
     * Destroy assets that have their refCount at `0`.
     * This is useful for cleaning up unused assets to free memory.
     * Assets with refCount > 0 are still in use and won't be destroyed.
     */
    public function flush() {

        for (asset in [].concat(addedAssets)) {
            if (asset.refCount == 0) asset.destroy();
        }

    }

/// Add assets to load

    public function hasAsset(asset:Asset):Bool {
        return addedAssets.contains(asset);
    }

    // public extern inline overload function add(id:AssetId<Dynamic>, variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {
    //     _add(id, variant, options #if ceramic_debug_entity_allocs , pos #end);
    // }

    // public extern inline overload function add(id:AssetId<Dynamic>, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {
    //     _add(id, null, options #if ceramic_debug_entity_allocs , pos #end);
    // }

    #if plugin_shade

    public extern inline overload function add(shader:Class<shade.Shader>, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {
        var className = Type.getClassName(shader);
        var dotIndex = className.lastIndexOf('.');
        if (dotIndex != -1) {
            className = className.substr(dotIndex + 1);
        }
        final id = 'shader:' + className.charAt(0).toLowerCase() + className.substr(1);
        return _add(id, null, options #if ceramic_debug_entity_allocs , pos #end);
    }

    #end

    public extern inline overload function add(id:AssetId<Dynamic>, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {
        return _add(id, variant, options #if ceramic_debug_entity_allocs , pos #end);
    }

    function _add(id:AssetId<Dynamic>, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {

        var value:String = Std.isOfType(id, String) ? cast id : cast Reflect.field(id, '_id');
        var colonIndex = value.indexOf(':');

        if (colonIndex == -1) {
            throw "Assets: invalid asset id: " + id;
        }

        var kind = value.substr(0, colonIndex);
        var name = value.substr(colonIndex + 1);

        switch (kind) {
            case 'image': addImage(name, variant, options #if ceramic_debug_entity_allocs , pos #end);
            case 'text': addText(name, variant, options #if ceramic_debug_entity_allocs , pos #end);
            case 'binary': addBinary(name, variant, options #if ceramic_debug_entity_allocs , pos #end);
            case 'sound': addSound(name, variant, options #if ceramic_debug_entity_allocs , pos #end);
            case 'database': addDatabase(name, variant, options #if ceramic_debug_entity_allocs , pos #end);
            case 'fragments': addFragments(name, variant, options #if ceramic_debug_entity_allocs , pos #end);
            case 'font': addFont(name, variant, options #if ceramic_debug_entity_allocs , pos #end);
            case 'atlas': addAtlas(name, variant, options #if ceramic_debug_entity_allocs , pos #end);
            case 'shader': addShader(name, variant, options #if ceramic_debug_entity_allocs , pos #end);
            default:
                if (customAssetKinds.exists(kind)) {
                    customAssetKinds.get(kind).add(this, name, variant, options);
                } else {
                    throw "Assets: invalid asset kind (" + kind + ") for id: " + id;
                }
        }

    }

    /**
     * Add all assets matching given path pattern (if provided).
     * Automatically detects asset types based on file extensions.
     * @param pathPattern Optional regex pattern to filter asset paths
     * ```haxe
     * // Add all assets
     * assets.addAll();
     * // Add only assets in 'sprites' folder
     * assets.addAll(~/^sprites\/.*$/);
     * ```
     */
    public function addAll(?pathPattern:EReg):Void {

        var info = app.backend.info;
        var imageExtensions = info.imageExtensions();
        #if plugin_ase
        imageExtensions = imageExtensions.concat(['ase', 'aseprite']);
        #end
        var textExtensions = info.textExtensions();
        var soundExtensions = info.soundExtensions();
        var shaderExtensions = info.shaderExtensions();
        var fontExtensions = ['fnt', 'ttf', 'otf'];
        var atlasExtensions = ['atlas'];
        var databaseExtensions = ['csv'];
        var fragmentsExtensions = ['fragments'];

        var customKindsExtensions = [];
        var customKindsAdd = [];
        for (value in customAssetKinds) {
            customKindsExtensions.push(value.extensions);
            customKindsAdd.push(value.add);
        }

        var allByName = Assets.allByName;
        if (runtimeAssets != null) {
            allByName = runtimeAssets.getLists().allByName;
        }

        for (name => paths in allByName) {

            // Check pattern, if any
            if (pathPattern != null) {
                var matches = false;
                for (i in 0...paths.length) {
                    if (pathPattern.match(paths.unsafeGet(i))) {
                        matches = true;
                        break;
                    }
                }
                if (!matches)
                    continue;
            }

            var assetExtension = Path.extension(paths[0]);

            var didAdd = false;
            for (i in 0...imageExtensions.length) {
                if (imageExtensions.unsafeGet(i) == assetExtension) {
                    addImage(name);
                    didAdd = true;
                    break;
                }
            }

            if (!didAdd) {
                for (i in 0...soundExtensions.length) {
                    if (soundExtensions.unsafeGet(i) == assetExtension) {
                        addSound(name);
                        didAdd = true;
                        break;
                    }
                }
            }

            if (!didAdd) {
                for (i in 0...shaderExtensions.length) {
                    if (shaderExtensions.unsafeGet(i) == assetExtension) {
                        addShader(name);
                        didAdd = true;
                        break;
                    }
                }
            }

            if (!didAdd) {
                for (i in 0...fontExtensions.length) {
                    if (fontExtensions.unsafeGet(i) == assetExtension) {
                        addFont(name);
                        didAdd = true;
                        break;
                    }
                }
            }

            if (!didAdd) {
                for (i in 0...atlasExtensions.length) {
                    if (atlasExtensions.unsafeGet(i) == assetExtension) {
                        addAtlas(name);
                        didAdd = true;
                        break;
                    }
                }
            }

            if (!didAdd) {
                for (i in 0...databaseExtensions.length) {
                    if (databaseExtensions.unsafeGet(i) == assetExtension) {
                        addDatabase(name);
                        didAdd = true;
                        break;
                    }
                }
            }

            if (!didAdd) {
                for (i in 0...fragmentsExtensions.length) {
                    if (fragmentsExtensions.unsafeGet(i) == assetExtension) {
                        addFragments(name);
                        didAdd = true;
                        break;
                    }
                }
            }

            if (!didAdd) {
                for (j in 0...customKindsExtensions.length) {
                    var extensions = customKindsExtensions.unsafeGet(j);
                    for (i in 0...extensions.length) {
                        if (extensions.unsafeGet(i) == assetExtension) {
                            var add = customKindsAdd.unsafeGet(j);
                            add(this, null, name, null);
                            didAdd = true;
                            break;
                        }
                    }
                    if (didAdd)
                        break;
                }
            }

            if (!didAdd) {
                for (i in 0...textExtensions.length) {
                    if (textExtensions.unsafeGet(i) == assetExtension) {
                        addText(name);
                        didAdd = true;
                        break;
                    }
                }
            }
        }

    }

    public function addImage(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {

        if (name.startsWith('image:')) name = name.substr(6);
        addAsset(new ImageAsset(name, variant, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addFont(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {

        if (name.startsWith('font:')) name = name.substr(5);
        addAsset(new FontAsset(name, variant, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addAtlas(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {

        if (name.startsWith('atlas:')) name = name.substr(6);
        addAsset(new AtlasAsset(name, variant, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addText(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {

        if (name.startsWith('text:')) name = name.substr(5);
        addAsset(new TextAsset(name, variant, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addBinary(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {

        if (name.startsWith('binary:')) name = name.substr(7);
        addAsset(new BinaryAsset(name, variant, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addSound(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {

        if (name.startsWith('sound:')) name = name.substr(6);
        addAsset(new SoundAsset(name, variant, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addDatabase(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {

        if (name.startsWith('database:')) name = name.substr(9);
        addAsset(new DatabaseAsset(name, variant, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addFragments(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {

        if (name.startsWith('fragments:')) name = name.substr(10);
        addAsset(new FragmentsAsset(name, variant, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addShader(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {

        if (name.startsWith('shader:')) name = name.substr(7);
        addAsset(new ShaderAsset(name, variant, options #if ceramic_debug_entity_allocs , pos #end));

    }

    /**
     * Add the given asset to this Assets instance.
     * If an asset with the same kind and name already exists, it will be replaced.
     * @param asset The asset to add
     * @return The previous asset if one was replaced, null otherwise
     */
    public function addAsset(asset:Asset):Asset {

        if (!assetsByKindAndName.exists(asset.kind)) assetsByKindAndName.set(asset.kind, new Map());
        var byName = assetsByKindAndName.get(asset.kind);

        if (Std.isOfType(asset, ImageAsset)) {
            var imageAsset:ImageAsset = cast asset;
            imageAsset.defaultImageOptions = defaultImageOptions;
        }

        var previousAsset = byName.get(asset.fullName);
        if (previousAsset != null) {
            if (previousAsset != asset) {
                App.app.logger.info('Replace $previousAsset with $asset');
                removeAsset(previousAsset);
            } else {
                App.app.logger.warning('Cannot add asset $asset because it is already added for name: ${asset.fullName}.');
                return previousAsset;
            }
        }

        asset.onDestroy(this, assetDestroyed);

        byName.set(asset.fullName, asset);

        // Asset was associated with another `Assets` owner.
        // Remove ownership so that we can safely associate it to new instance
        if (asset.owner != null && asset.owner != this) {
            asset.owner.removeAsset(asset);
        }

        addedAssets.push(asset);
        asset.owner = this;
        asset.runtimeAssets = this.runtimeAssets;
        asset.hotReload = this.hotReload;

        return previousAsset;

    }

    function assetDestroyed(_) {

        var toDestroy:Array<Asset> = null;
        for (asset in addedAssets) {
            if (asset.destroyed) {
                if (toDestroy == null) toDestroy = [];
                toDestroy.push(asset);
            }
        }
        if (toDestroy != null) {
            for (asset in toDestroy) {
                removeAsset(asset);
            }
        }

    }

    public function imageAsset(name:Either<String,AssetId<String>>, ?variant:String):ImageAsset {
        return cast asset(name, 'image', variant);
    }

    public function fontAsset(name:Either<String,AssetId<String>>, ?variant:String):FontAsset {
        return cast asset(name, 'font', variant);
    }

    public function atlasAsset(name:Either<String,AssetId<String>>, ?variant:String):AtlasAsset {
        return cast asset(name, 'atlas', variant);
    }

    public function textAsset(name:Either<String,AssetId<String>>, ?variant:String):TextAsset {
        return cast asset(name, 'text', variant);
    }

    public function soundAsset(name:Either<String,AssetId<String>>, ?variant:String):SoundAsset {
        return cast asset(name, 'sound', variant);
    }

    public function databaseAsset(name:Either<String,AssetId<String>>, ?variant:String):DatabaseAsset {
        return cast asset(name, 'database', variant);
    }

    public function fragmentsAsset(name:Either<String,AssetId<String>>, ?variant:String):FragmentsAsset {
        return cast asset(name, 'fragments', variant);
    }

    public function shaderAsset(name:Either<String,AssetId<String>>, ?variant:String):ShaderAsset {
        return cast asset(name, 'shader', variant);
    }

    public function asset(idOrName:Dynamic, ?kind:String, ?variant:String):Asset {

        var value:String = Std.isOfType(idOrName, String) ? cast idOrName : cast Reflect.field(idOrName, '_id');
        var colonIndex = value.indexOf(':');

        var name:String = value;

        if (colonIndex != -1) {
            name = value.substring(colonIndex + 1);
            kind = value.substring(0, colonIndex);
        }

        if (variant != null) {
            name += ':' + variant;
        }

        if (kind == null) return parent != null ? parent.asset(idOrName, kind, variant) : null;
        var byName = assetsByKindAndName.get(kind);
        if (byName == null) return parent != null ? parent.asset(idOrName, kind, variant) : null;
        var result = byName.get(name);
        if (result == null) return parent != null ? parent.asset(idOrName, kind, variant) : null;
        return result;

    }

    public function removeAsset(asset:Asset):Void {

        asset.offDestroy(assetDestroyed);

        var byName = assetsByKindAndName.get(asset.kind);
        var toRemove = byName.get(asset.fullName);

        if (asset != toRemove) {
            throw 'Cannot remove asset $asset if it was not added at the first place (existing: $toRemove).';
        }

        addedAssets.remove(asset);
        byName.remove(asset.fullName);
        asset.owner = null;

    }

    /**
     * Move all assets owned by this `Assets` instance
     * to the given `toAssets` object.
     * Useful for transferring assets between scenes or asset groups.
     * @param toAssets The target Assets instance to move assets to
     */
    public function moveAll(toAssets:Assets):Void {

        var toMove = [].concat(addedAssets);
        for (i in 0...toMove.length) {
            final asset = toMove[i];
            removeAsset(asset);
            toAssets.addAsset(asset);
        }

    }

/// Load

    /**
     * Returns `true` if there are assets that should be loaded.
     * Checks for assets with status NONE (not yet loaded).
     * @return True if there are unloaded assets, false otherwise
     */
    public function hasAnythingToLoad():Bool {

        for (i in 0...addedAssets.length) {
            var asset = addedAssets.unsafeGet(i);
            if (asset.status == NONE) {
                return true;
            }
        }

        return false;

    }

    public function countAssetsWithStatus(status:AssetStatus):Int {

        var result = 0;
        var assets = this.addedAssets;
        for (i in 0...addedAssets.length) {
            if (addedAssets.unsafeGet(i).status == status) {
                result++;
            }
        }
        return result;

    }

    /**
     * Load all assets that have been added to this instance.
     * Emits progress events during loading and complete event when finished.
     * @param warnIfNothingToLoad If true, logs a warning when there are no assets to load
     * @param pos Source position for debugging (automatically provided)
     */
    public function load(warnIfNothingToLoad:Bool = true, ?pos:haxe.PosInfos):Void {

        var total = 0;
        var pending = 0;
        var allSuccess = true;
        var addedAssets = [].concat(this.addedAssets);

        // Prepare loading
        for (asset in addedAssets) {

            if (asset.status == NONE) {

                asset.onceComplete(this, function(success) {

                    if (!success) {
                        allSuccess = false;
                        App.app.logger.error('Failed to load asset ${asset.name} ($asset)', pos);
                    }

                    pending--;

                    emitProgress(total - pending, total, allSuccess);

                    if (pending == 0) {
                        _prepareComplete(allSuccess);
                    }

                });
                pending++;
                total++;

            }

        }

        // Load
        if (pending > 0) {

            if (scheduleMethod == SERIAL) {
                var numComplete = 0;
                var toLoad = [];
                for (asset in addedAssets) {
                    if (asset.status == NONE) {
                        toLoad.push(asset);
                    }
                }
                _loadNextSerial(toLoad, numComplete);

                immediate.flush();
            }
            // ScheduleMethod == PARALLEL
            else {

                if (delayBetweenXAssets > 0) {

                    var numStarted = 0;
                    var toLoad = [];
                    for (asset in addedAssets) {
                        if (asset.status == NONE) {
                            toLoad.push(asset);
                        }
                    }
                    _loadNextParallel(toLoad, numStarted);

                }
                else {

                    for (asset in addedAssets) {

                        if (asset.status == NONE) {
                            asset.load();
                        }

                    }
                }

                immediate.flush();
            }

        } else {

            if (warnIfNothingToLoad) {
                App.app.logger.warning('There was no asset to load.', pos);
            }
            _prepareComplete(true);

        }

    }

    private function _prepareComplete(allSuccess:Bool):Void {

        if (pendingAtlasPackers != null && pendingAtlasPackers.length > 0) {
            _packNextAtlasPacker(() -> _prepareComplete(allSuccess));
        }
        else {
            emitComplete(true);
        }

    }

    private function _packNextAtlasPacker(done:()->Void):Void {

        var atlasPacker = pendingAtlasPackers.shift();
        atlasPacker.pack(atlas -> done());

    }

    function addPendingAtlasPacker(atlasPacker:TextureAtlasPacker):Void {

        if (pendingAtlasPackers == null)
            pendingAtlasPackers = [];

        if (!pendingAtlasPackers.contains(atlasPacker))
            pendingAtlasPackers.push(atlasPacker);

    }

    private function _loadNextSerial(toLoad:Array<Asset>, numComplete:Int):Void {

        var asset = toLoad.shift();
        if (asset.status == NONE) {
            asset.load();
            asset.onceComplete(this, function(success) {
                _assetCompleteSerial(success, toLoad, numComplete);
            });
        }
        else {
            if (toLoad.length > 0) {
                _loadNextSerial(toLoad, numComplete);
            }
        }

    }

    private function _assetCompleteSerial(success:Bool, toLoad:Array<Asset>, numComplete:Int):Void {

        numComplete++;
        if (toLoad.length > 0) {
            if (delayBetweenXAssets > 0 && numComplete > 0 && (numComplete % delayBetweenXAssets) == 0) {
                app.onceXUpdates(this, 2, () -> {
                    _loadNextSerial(toLoad, numComplete);
                });
            }
            else {
                _loadNextSerial(toLoad, numComplete);
            }
        }

    }

    private function _loadNextParallel(toLoad:Array<Asset>, numStarted:Int):Void {

        if (toLoad.length > 0) {
            numStarted++;
            if (numStarted > 1 && (numStarted % delayBetweenXAssets) == 0) {
                app.onceXUpdates(this, 2, () -> {
                    var asset = toLoad.shift();
                    asset.load();
                    _loadNextParallel(toLoad, numStarted);
                });
            }
            else {
                var asset = toLoad.shift();
                asset.load();
                _loadNextParallel(toLoad, numStarted);
            }
        }
    }

/// Ensure

    /**
     * Ensures and asset is loaded and return it on the callback.
     * This will check if the requested asset is currently being loaded,
     * already loaded or should be added and loaded. In all cases, it will try
     * its best to deliver the requested asset or `null` if something went wrong.
     */
    public function ensure(id:AssetId<Dynamic>, ?variant:String, ?options:AssetOptions, done:Asset->Void):Void {

        // Asset already added?
        var existing = this.asset(id, null, variant);
        var asset:Asset = null;

        if (existing == null) {
            // No? Add it and get it back
            add(id, variant, options);
            asset = this.asset(id, null, variant);
        } else {
            // Yes, use it
            asset = existing;
        }

        if (asset == null) {
            // Asset is null? It seems invalid then
            done(null);
            return;
        }

        // Depending on asset status, do the right thing
        if (asset.status == READY) {
            // Already available
            done(asset);
        }
        else if (asset.status == LOADING || asset.status == NONE) {
            // Wait until asset is loaded
            asset.onceComplete(null, function(success) {
                if (success) {
                    done(asset);
                }
                else {
                    done(null);
                }
            });

            if (asset.status == NONE) {
                // Start loading
                this.load();
            }
        }
        else {
            // Broken?
            done(null);
        }

    }

    public function ensureImage(name:Either<String,AssetId<String>>, ?variant:String, ?options:AssetOptions, done:ImageAsset->Void):Void {

        var _name:String = cast name;
        if (!StringTools.startsWith(_name, 'image:')) _name = 'image:' + _name;
        ensure(_name, variant, options, function(asset) {
            done(Std.isOfType(asset, ImageAsset) ? cast asset : null);
        });

    }

    public function ensureFont(name:Either<String,AssetId<String>>, ?variant:String, ?options:AssetOptions, done:FontAsset->Void):Void {

        var _name:String = cast name;
        if (!StringTools.startsWith(_name, 'font:')) _name = 'font:' + _name;
        ensure(_name, variant, options, function(asset) {
            done(Std.isOfType(asset, FontAsset) ? cast asset : null);
        });

    }

    public function ensureAtlas(name:Either<String,AssetId<String>>, ?variant:String, ?options:AssetOptions, done:AtlasAsset->Void):Void {

        var _name:String = cast name;
        if (!StringTools.startsWith(_name, 'atlas:')) _name = 'atlas:' + _name;
        ensure(_name, variant, options, function(asset) {
            done(Std.isOfType(asset, AtlasAsset) ? cast asset : null);
        });

    }

    public function ensureText(name:Either<String,AssetId<String>>, ?variant:String, ?options:AssetOptions, done:TextAsset->Void):Void {

        var _name:String = cast name;
        if (!StringTools.startsWith(_name, 'text:')) _name = 'text:' + _name;
        ensure(_name, variant, options, function(asset) {
            done(Std.isOfType(asset, TextAsset) ? cast asset : null);
        });

    }

    public function ensureSound(name:Either<String,AssetId<String>>, ?variant:String, ?options:AssetOptions, done:SoundAsset->Void):Void {

        var _name:String = cast name;
        if (!StringTools.startsWith(_name, 'sound:')) _name = 'sound:' + _name;
        ensure(_name, variant, options, function(asset) {
            done(Std.isOfType(asset, SoundAsset) ? cast asset : null);
        });

    }

    public function ensureDatabase(name:Either<String,AssetId<String>>, ?variant:String, ?options:AssetOptions, done:DatabaseAsset->Void):Void {

        var _name:String = cast name;
        if (!StringTools.startsWith(_name, 'database:')) _name = 'database:' + _name;
        ensure(_name, variant, options, function(asset) {
            done(Std.isOfType(asset, DatabaseAsset) ? cast asset : null);
        });

    }

    public function ensureShader(name:Either<String,AssetId<String>>, ?variant:String, ?options:AssetOptions, done:ShaderAsset->Void):Void {

        var _name:String = cast name;
        if (!StringTools.startsWith(_name, 'shader:')) _name = 'shader:' + _name;
        ensure(_name, variant, options, function(asset) {
            done(Std.isOfType(asset, ShaderAsset) ? cast asset : null);
        });

    }

/// Get

    /**
     * Get a loaded texture by name.
     * @param name The texture name or asset ID
     * @param variant Optional variant suffix
     * @return The texture, or null if not found
     */
    public function texture(name:Either<String,AssetId<String>>, ?variant:String):Texture {

        var realName:String = cast name;
        if (realName.startsWith('image:')) realName = realName.substr(6);
        if (variant != null) realName += ':' + variant;

        if (!assetsByKindAndName.exists('image')) return parent != null ? parent.texture(name, variant) : null;
        var asset:ImageAsset = cast assetsByKindAndName.get('image').get(realName);
        if (asset == null) return parent != null ? parent.texture(name, variant) : null;

        return asset.texture;

    }

    /**
     * Get a loaded font by name.
     * @param name The font name or asset ID
     * @param variant Optional variant suffix
     * @return The font, or null if not found
     */
    public function font(name:Either<String,AssetId<String>>, ?variant:String):BitmapFont {

        var realName:String = cast name;
        if (realName.startsWith('font:')) realName = realName.substr(5);
        if (variant != null) realName += ':' + variant;

        if (!assetsByKindAndName.exists('font')) return parent != null ? parent.font(name, variant) : null;
        var asset:FontAsset = cast assetsByKindAndName.get('font').get(realName);
        if (asset == null) return parent != null ? parent.font(name, variant) : null;

        return asset.font;

    }

    public function atlas(name:Either<String,AssetId<String>>, ?variant:String):TextureAtlas {

        var realName:String = cast name;
        if (realName.startsWith('atlas:')) realName = realName.substr(6);
        if (variant != null) realName += ':' + variant;

        if (!assetsByKindAndName.exists('atlas')) return parent != null ? parent.atlas(name, variant) : null;
        var asset:AtlasAsset = cast assetsByKindAndName.get('atlas').get(realName);
        if (asset == null) return parent != null ? parent.atlas(name, variant) : null;

        return asset.atlas;

    }

    /**
     * Get a loaded sound by name.
     * @param name The sound name or asset ID
     * @param variant Optional variant suffix
     * @return The sound, or null if not found
     */
    public function sound(name:Either<String,AssetId<String>>, ?variant:String):Sound {

        var realName:String = cast name;
        if (realName.startsWith('sound:')) realName = realName.substr(6);
        if (variant != null) realName += ':' + variant;

        if (!assetsByKindAndName.exists('sound')) return parent != null ? parent.sound(name, variant) : null;
        var asset:SoundAsset = cast assetsByKindAndName.get('sound').get(realName);
        if (asset == null) return parent != null ? parent.sound(name, variant) : null;

        return asset.sound;

    }

    /**
     * Get loaded text content by name.
     * @param name The text asset name or asset ID
     * @param variant Optional variant suffix
     * @return The text content, or null if not found
     */
    public function text(name:Either<String,AssetId<String>>, ?variant:String):String {

        var realName:String = cast name;
        if (realName.startsWith('text:')) realName = realName.substr(5);
        if (variant != null) realName += ':' + variant;

        if (!assetsByKindAndName.exists('text')) return parent != null ? parent.text(name, variant) : null;
        var asset:TextAsset = cast assetsByKindAndName.get('text').get(realName);
        if (asset == null) return parent != null ? parent.text(name, variant) : null;

        return asset.text;

    }

    public function bytes(name:Either<String,AssetId<String>>, ?variant:String):Bytes {

        var realName:String = cast name;
        if (realName.startsWith('binary:')) realName = realName.substr(7);
        if (variant != null) realName += ':' + variant;

        if (!assetsByKindAndName.exists('binary')) return parent != null ? parent.bytes(name, variant) : null;
        var asset:BinaryAsset = cast assetsByKindAndName.get('binary').get(realName);
        if (asset == null) return parent != null ? parent.bytes(name, variant) : null;

        return asset.bytes;

    }

    /**
     * Get a loaded shader by name.
     * @param name The shader name or asset ID
     * @param variant Optional variant suffix
     * @return The shader, or null if not found
     */
    public function shader(name:Either<String,AssetId<String>>, ?variant:String):Shader {

        var realName:String = cast name;
        if (realName.startsWith('shader:')) realName = realName.substr(7);
        if (variant != null) realName += ':' + variant;

        if (!assetsByKindAndName.exists('shader')) return parent != null ? parent.shader(name, variant) : null;
        var asset:ShaderAsset = cast assetsByKindAndName.get('shader').get(realName);
        if (asset == null) return parent != null ? parent.shader(name, variant) : null;

        return asset.shader;

    }

    public function database(name:Either<String,AssetId<String>>, ?variant:String):Array<DynamicAccess<String>> {

        var realName:String = cast name;
        if (realName.startsWith('database:')) realName = realName.substr(9);
        if (variant != null) realName += ':' + variant;

        if (!assetsByKindAndName.exists('database')) return parent != null ? parent.database(name, variant) : null;
        var asset:DatabaseAsset = cast assetsByKindAndName.get('database').get(realName);
        if (asset == null) return parent != null ? parent.database(name, variant) : null;

        return asset.database;

    }

    public function fragments(name:Either<String,AssetId<String>>, ?variant:String):DynamicAccess<FragmentData> {

        var realName:String = cast name;
        if (realName.startsWith('fragments:')) realName = realName.substr(10);
        if (variant != null) realName += ':' + variant;

        if (!assetsByKindAndName.exists('fragments')) return parent != null ? parent.fragments(name, variant) : null;
        var asset:FragmentsAsset = cast assetsByKindAndName.get('fragments').get(realName);
        if (asset == null) return parent != null ? parent.fragments(name, variant) : null;

        return asset.fragments;

    }

/// Iterator

    public function iterator():Iterator<Asset> {

        var list:Array<Asset> = [];

        for (byName in assetsByKindAndName) {
            for (asset in byName) {
                list.push(asset);
            }
        }

        return list.iterator();

    }

/// Watching assets

    /**
     * Set to `true` to enable hot reload.
     * When enabled and used with `watchDirectory()`, assets will automatically
     * reload when their files change on disk.
     * Note: this won't do anything unless used in pair with `watchDirectory(path)`
     */
    public var hotReload(default, set):Bool = false;

    function set_hotReload(hotReload:Bool):Bool {
        if (this.hotReload == hotReload) return hotReload;
        this.hotReload = hotReload;
        for (asset in addedAssets) {
            asset.hotReload = hotReload;
        }
        return hotReload;
    }

    /**
     * Watch the given asset directory for changes.
     * Any file change will fire `assetFilesChange` event and optionally trigger hot reload.
     *
     * This is particularly useful during development to see asset changes without restarting.
     * Behavior may differ depending on the platform.
     *
     * @param path The assets path to watch. If null, uses the default assets path from project configuration.
     *             You can use `ceramic.macros.DefinesMacro.getJsonDefine('assets_path')` to get the default.
     * @param hotReload If true (default), assets will automatically reload when their files change
     * @return WatchDirectory instance used internally
     *
     * ```haxe
     * // Watch default assets directory with hot reload
     * assets.watchDirectory();
     *
     * // Watch custom path without hot reload
     * assets.watchDirectory('/path/to/assets', false);
     * ```
     *
     * Note: When using web target via electron, add `ceramic_use_electron` define.
     */
    public function watchDirectory(?path:String, hotReload:Bool = true):WatchDirectory {

        if (runtimeAssets != null) {
            throw 'There is already an instance of RuntimeAssets assigned. Cannot watch a directory, which also need its own instance';
        }

        if (path == null) {
            #if (web && !ceramic_use_electron)
            throw 'Cannot watch directory when using web target! (unless using electron runner and `ceramic_use_electron` define)';
            #else
            path = ceramic.macros.DefinesMacro.getJsonDefine('assets_path');
            #end
        }

        // Pre-multiply images alpha on the fly because we are reading from source assets
        if (defaultImageOptions == null) {
            defaultImageOptions = {};
        }
        defaultImageOptions.premultiplyAlpha = true;

        if (hotReload) {
            this.hotReload = hotReload;
        }

        // Needed to find new assets
        runtimeAssets = RuntimeAssets.fromPath(path);

        // Watch directory
        var watch = new WatchDirectory();
        watch.watchDirectory(path);
        watch.onDirectoryChange(this, (_, newFiles, previousFiles) -> {
            if (runtimeAssets == null) {
                log.warning('Missing instance of RuntimeAssets when watched directory changed (path: $path)');
            }
            else {
                runtimeAssets.reset(Files.getFlatDirectory(path), path);
            }

            // Init last modified by real asset path if needed
            if (lastModifiedByRealAssetPath == null) {
                lastModifiedByRealAssetPath = new Map();
                for (key => value in previousFiles) {
                    var realPathKey = realAssetPath(key, runtimeAssets);
                    lastModifiedByRealAssetPath.set(realPathKey, value);
                }
            }

            // Create new list and increment reload counts if any relevant changes
            var newLastModifiedByRealAssetPath = new Map();
            for (key => value in newFiles) {
                var realPathKey = realAssetPath(key, runtimeAssets);
                newLastModifiedByRealAssetPath.set(realPathKey, value);
                if (lastModifiedByRealAssetPath.exists(realPathKey)) {
                    if (value != lastModifiedByRealAssetPath.get(realPathKey)) {
                        incrementReloadCount(realPathKey);
                    }
                }
            }
            lastModifiedByRealAssetPath = newLastModifiedByRealAssetPath;

            // Emit event to trigger chain of hot reload (if enabled)
            // or any custom behavior
            emitAssetFilesChange(newFiles, previousFiles);
        });
        onDestroy(watch, _ -> {
            watch.destroy();
        });

        return watch;

    }

    /**
     * Inherit runtime asset settings from parent assets instance.
     * Used internally to ensure sub-instances of `Assets` inherit live reload settings
     * and runtime assets configuration from their parent.
     * @param assets The parent Assets instance to inherit settings from
     */
    @:noCompletion public function inheritRuntimeAssetsFromAssets(assets:Assets):Void {

        runtimeAssets = assets.runtimeAssets;
        defaultImageOptions = assets.defaultImageOptions;

    }

/// Static helpers

    /**
     * Decode an asset path to extract information about density, variant, etc.
     * @param path The asset path to decode
     * @return AssetPathInfo object containing parsed path information
     */
    public static function decodePath(path:String):AssetPathInfo {

        return new AssetPathInfo(path);

    }

    /**
     * Register a custom asset kind that can be loaded by the asset system.
     * @param kind The unique identifier for this asset type (e.g., 'sprite', 'level')
     * @param add Function that handles adding this asset type to an Assets instance
     * @param extensions File extensions associated with this asset type
     * @param dir Whether this asset type is directory-based
     * @param types Additional type information for the asset kind
     */
    public static function addAssetKind(kind:String, add:(assets:Assets, name:String, variant:String, options:AssetOptions)->Void, extensions:Array<String>, dir:Bool, types:Array<String>):Void {

        customAssetKinds.set(kind, {
            kind: kind,
            add: add,
            extensions: extensions,
            dir: dir,
            types: types
        });

    }

    /**
     * Get the base assets path for the current platform.
     * @return The platform-specific assets path
     */
    inline public static function getAssetsPath():String {

        return Platform.getAssetsPath();

    }

    /**
     * Get the asset name associated with a given file path.
     * @param path The file path to look up
     * @return The asset name, or null if no asset uses this path
     */
    public static function assetNameFromPath(path:String):String {

        for (name in Assets.allByName.keys()) {
            var list = Assets.allByName.get(name);
            for (i in 0...list.length) {
                if (list[i] == path) {
                    return name;
                }
            }
        }

        return null;

    }

    public static function realAssetPath(path:String, ?runtimeAssets:RuntimeAssets):String {

        if (runtimeAssets != null) {
            if (runtimeAssets.path != null) {
                return ceramic.Path.join([runtimeAssets.path, path]);
            }
            else {
                return path;
            }
        }
        else {
            var assetsPrefix:String = ceramic.macros.DefinesMacro.getDefine('ceramic_assets_prefix');
            if (assetsPrefix != null) {
                return assetsPrefix + path;
            }
            else {
                return path;
            }
        }

    }

/// Reload count

    static function incrementReloadCount(realAssetPath:String) {

        realAssetPath = Path.normalize(realAssetPath);

        if (Assets.reloadCountByRealAssetPath == null)
            Assets.reloadCountByRealAssetPath = new Map();

        if (Assets.reloadCountByRealAssetPath.exists(realAssetPath)) {
            Assets.reloadCountByRealAssetPath.set(realAssetPath, Assets.reloadCountByRealAssetPath.get(realAssetPath) + 1);
        }
        else {
            Assets.reloadCountByRealAssetPath.set(realAssetPath, 1);
        }

    }

    public static function getReloadCount(realAssetPath:String):Int {

        realAssetPath = Path.normalize(realAssetPath);

        if (Assets.reloadCountByRealAssetPath == null || !Assets.reloadCountByRealAssetPath.exists(realAssetPath))
            return 0;

        return Assets.reloadCountByRealAssetPath.get(realAssetPath);

    }

}
