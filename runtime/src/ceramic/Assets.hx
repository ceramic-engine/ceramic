package ceramic;

import ceramic.Path;
import ceramic.Shortcuts.*;
import haxe.DynamicAccess;
import haxe.io.Bytes;

using StringTools;
using ceramic.Extensions;

@:allow(ceramic.Asset)
class Assets extends Entity {

    public static var all:Array<String> = [];

    public static var allDirs:Array<String> = [];

    public static var allByName:Map<String,Array<String>> = new Map();

    public static var allDirsByName:Map<String,Array<String>> = new Map();

/// Events

    @event function complete(success:Bool);

    @event function update(asset:Asset);

    @event function progress(loaded:Int, total:Int, success:Bool);

    @event function assetFilesChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>);

/// Properties

    var addedAssets:Array<Asset> = [];

    var assetsByKindAndName:Map<String,Map<String,Asset>> = new Map();

    /** If set, will be provided to each added asset in this `Assets` instance. */
    public var runtimeAssets:RuntimeAssets = null;

    public var defaultImageOptions:AssetOptions = null;

    /**
     * If set to `true`, will ensure asset loading is non blocking, at least between each asset.
     * This is useful when we need to update screen during asset loading
     */
    public var nonBlocking:Bool = false;

/// Internal

    static var customAssetKinds:Map<String,CustomAssetKind> = new Map();

    static var reloadCountByRealAssetPath:Map<String, Int> = null;

    static var lastModifiedByRealAssetPath:Map<String, Float> = null;

/// Lifecycle

    public function new() {

        super();

    }

    override function destroy() {

        super.destroy();

        for (asset in [].concat(addedAssets)) {
            asset.offDestroy(assetDestroyed);
            asset.destroy();
        }
        addedAssets = null;
        assetsByKindAndName = null;

    }

    /** Destroy assets that have their refCount at `0`. */
    public function flush() {

        for (asset in [].concat(addedAssets)) {
            if (asset.refCount == 0) asset.destroy();
        }

    }

/// Add assets to load

    public function add(id:AssetId<Dynamic>, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {

        var value:String = Std.isOfType(id, String) ? cast id : cast Reflect.field(id, '_id');
        var colonIndex = value.indexOf(':');

        if (colonIndex == -1) {
            throw "Assets: invalid asset id: " + id;
        }

        var kind = value.substr(0, colonIndex);
        var name = value.substr(colonIndex + 1);

        switch (kind) {
            case 'image': addImage(name, options #if ceramic_debug_entity_allocs , pos #end);
            case 'text': addText(name, options #if ceramic_debug_entity_allocs , pos #end);
            case 'binary': addBinary(name, options #if ceramic_debug_entity_allocs , pos #end);
            case 'sound': addSound(name, options #if ceramic_debug_entity_allocs , pos #end);
            case 'database': addDatabase(name, options #if ceramic_debug_entity_allocs , pos #end);
            case 'fragments': addFragments(name, options #if ceramic_debug_entity_allocs , pos #end);
            case 'font': addFont(name, options #if ceramic_debug_entity_allocs , pos #end);
            case 'shader': addShader(name, options #if ceramic_debug_entity_allocs , pos #end);
            default:
                if (customAssetKinds.exists(kind)) {
                    customAssetKinds.get(kind).add(this, name, options);
                } else {
                    throw "Assets: invalid asset kind (" + kind + ") for id: " + id;
                }
        }

    }

    /**
     * Add all assets matching given path pattern (if provided)
     * @param pathPattern 
     */
    public function addAll(?pathPattern:EReg):Void {

        var info = app.backend.info;
        var imageExtensions = info.imageExtensions();
        var textExtensions = info.textExtensions();
        var soundExtensions = info.soundExtensions();
        var shaderExtensions = info.shaderExtensions();
        var fontExtensions = ['fnt'];
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
                for (i in 0...textExtensions.length) {
                    if (textExtensions.unsafeGet(i) == assetExtension) {
                        addText(name);
                        didAdd = true;
                        break;
                    }
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
                            add(this, name);
                            didAdd = true;
                            break;
                        }
                    }
                    if (didAdd)
                        break;
                }
            }
        }

    }

    public function addImage(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {

        if (name.startsWith('image:')) name = name.substr(6);
        addAsset(new ImageAsset(name, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addFont(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {
        
        if (name.startsWith('font:')) name = name.substr(5);
        addAsset(new FontAsset(name, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addText(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {
        
        if (name.startsWith('text:')) name = name.substr(5);
        addAsset(new TextAsset(name, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addBinary(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {
        
        if (name.startsWith('binary:')) name = name.substr(7);
        addAsset(new BinaryAsset(name, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addSound(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {
        
        if (name.startsWith('sound:')) name = name.substr(6);
        addAsset(new SoundAsset(name, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addDatabase(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {
        
        if (name.startsWith('database:')) name = name.substr(9);
        addAsset(new DatabaseAsset(name, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addFragments(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {
        
        if (name.startsWith('fragments:')) name = name.substr(10);
        addAsset(new FragmentsAsset(name, options #if ceramic_debug_entity_allocs , pos #end));

    }

    public function addShader(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Void {
        
        if (name.startsWith('shader:')) name = name.substr(7);
        addAsset(new ShaderAsset(name, options #if ceramic_debug_entity_allocs , pos #end));

    }

    /** Add the given asset. If a previous asset was replaced, return it. */
    public function addAsset(asset:Asset):Asset {

        if (!assetsByKindAndName.exists(asset.kind)) assetsByKindAndName.set(asset.kind, new Map());
        var byName = assetsByKindAndName.get(asset.kind);

        if (Std.isOfType(asset, ImageAsset)) {
            var imageAsset:ImageAsset = cast asset;
            imageAsset.defaultImageOptions = defaultImageOptions;
        }

        var previousAsset = byName.get(asset.name);
        if (previousAsset != null) {
            if (previousAsset != asset) {
                App.app.logger.info('Replace $previousAsset with $asset');
                removeAsset(previousAsset);
            } else {
                App.app.logger.warning('Cannot add asset $asset because it is already added for name: ${asset.name}.');
                return previousAsset;
            }
        }

        asset.onDestroy(this, assetDestroyed);

        byName.set(asset.name, asset);

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

    public function imageAsset(name:Either<String,AssetId<String>>):ImageAsset {
        return cast asset(name, 'image');
    }

    public function fontAsset(name:Either<String,AssetId<String>>):FontAsset {
        return cast asset(name, 'font');
    }

    public function textAsset(name:Either<String,AssetId<String>>):TextAsset {
        return cast asset(name, 'text');
    }

    public function soundAsset(name:Either<String,AssetId<String>>):SoundAsset {
        return cast asset(name, 'sound');
    }

    public function databaseAsset(name:Either<String,AssetId<String>>):DatabaseAsset {
        return cast asset(name, 'database');
    }

    public function fragmentsAsset(name:Either<String,AssetId<String>>):FragmentsAsset {
        return cast asset(name, 'fragments');
    }

    public function shaderAsset(name:Either<String,AssetId<String>>):ShaderAsset {
        return cast asset(name, 'shader');
    }
    
    public function asset(idOrName:Dynamic, ?kind:String):Asset {

        var value:String = Std.isOfType(idOrName, String) ? cast idOrName : cast Reflect.field(idOrName, '_id');
        var colonIndex = value.indexOf(':');

        var name:String = value;

        if (colonIndex != -1) {
            name = value.substring(colonIndex + 1);
            kind = value.substring(0, colonIndex);
        }

        if (kind == null) return null;
        var byName = assetsByKindAndName.get(kind);
        if (byName == null) return null;
        return byName.get(name);

    }

    public function removeAsset(asset:Asset):Void {

        asset.offDestroy(assetDestroyed);

        var byName = assetsByKindAndName.get(asset.kind);
        var toRemove = byName.get(asset.name);

        if (asset != toRemove) {
            throw 'Cannot remove asset $asset if it was not added at the first place.';
        }

        addedAssets.remove(asset);
        byName.remove(asset.name);
        asset.owner = null;

    }

/// Load

    /**
     * Returns `true` if there are assets that should be loaded
     * @return Bool
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

    public function load(warnIfNothingToLoad:Bool = true, ?pos:haxe.PosInfos):Void {

        var total = 0;
        var pending = 0;
        var allSuccess = true;

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
                        emitComplete(allSuccess);
                    }

                });
                pending++;
                total++;

            }

        }

        // Load
        if (pending > 0) {

            if (nonBlocking) {
                var toLoad = [].concat(addedAssets);
                var loadNext:Void->Void = null;
                loadNext = function() {
                    var asset = toLoad.shift();
                    if (asset.status == NONE) {
                        asset.load();
                        asset.onceComplete(this, function(success) {
                            if (toLoad.length > 0) {
                                app.onceUpdate(this, function(delta) {
                                    app.onceUpdate(this, function(delta) {
                                        loadNext();
                                    });
                                });
                            }
                        });
                    }
                    else {
                        if (toLoad.length > 0) {
                            loadNext();
                        }
                    }
                }
                loadNext();
            }
            else {
                for (asset in addedAssets) {
    
                    if (asset.status == NONE) {
                        asset.load();
                    }
    
                }
            }

        } else {

            if (warnIfNothingToLoad) {
                App.app.logger.warning('There was no asset to load.', pos);
            }
            emitComplete(true);

        }

    }

/// Ensure

    /** Ensures and asset is loaded and return it on the callback.
        This will check if the requested asset is currently being loaded,
        already loaded or should be added and loaded. In all cases, it will try
        its best to deliver the requested asset or `null` if something went wrong. */
    public function ensure(id:AssetId<Dynamic>, ?options:AssetOptions, done:Asset->Void):Void {

        // Asset already added?
        var existing = this.asset(id);
        var asset:Asset = null;

        if (existing == null) {
            // No? Add it and get it back
            add(id, options);
            asset = this.asset(id);
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

    public function ensureImage(name:Either<String,AssetId<String>>, ?options:AssetOptions, done:ImageAsset->Void):Void {

        var _name:String = cast name;
        if (!StringTools.startsWith(_name, 'image:')) _name = 'image:' + _name;
        ensure(_name, options, function(asset) {
            done(Std.isOfType(asset, ImageAsset) ? cast asset : null);
        });

    }

    public function ensureFont(name:Either<String,AssetId<String>>, ?options:AssetOptions, done:FontAsset->Void):Void {

        var _name:String = cast name;
        if (!StringTools.startsWith(_name, 'font:')) _name = 'font:' + _name;
        ensure(_name, options, function(asset) {
            done(Std.isOfType(asset, FontAsset) ? cast asset : null);
        });

    }

    public function ensureText(name:Either<String,AssetId<String>>, ?options:AssetOptions, done:TextAsset->Void):Void {

        var _name:String = cast name;
        if (!StringTools.startsWith(_name, 'text:')) _name = 'text:' + _name;
        ensure(_name, options, function(asset) {
            done(Std.isOfType(asset, TextAsset) ? cast asset : null);
        });

    }

    public function ensureSound(name:Either<String,AssetId<String>>, ?options:AssetOptions, done:SoundAsset->Void):Void {

        var _name:String = cast name;
        if (!StringTools.startsWith(_name, 'sound:')) _name = 'sound:' + _name;
        ensure(_name, options, function(asset) {
            done(Std.isOfType(asset, SoundAsset) ? cast asset : null);
        });

    }

    public function ensureDatabase(name:Either<String,AssetId<String>>, ?options:AssetOptions, done:DatabaseAsset->Void):Void {

        var _name:String = cast name;
        if (!StringTools.startsWith(_name, 'database:')) _name = 'database:' + _name;
        ensure(_name, options, function(asset) {
            done(Std.isOfType(asset, DatabaseAsset) ? cast asset : null);
        });

    }

    public function ensureShader(name:Either<String,AssetId<String>>, ?options:AssetOptions, done:ShaderAsset->Void):Void {

        var _name:String = cast name;
        if (!StringTools.startsWith(_name, 'shader:')) _name = 'shader:' + _name;
        ensure(_name, options, function(asset) {
            done(Std.isOfType(asset, ShaderAsset) ? cast asset : null);
        });

    }

/// Get

    public function texture(name:Either<String,AssetId<String>>):Texture {

        var realName:String = cast name;
        if (realName.startsWith('image:')) realName = realName.substr(6);

        if (!assetsByKindAndName.exists('image')) return null;
        var asset:ImageAsset = cast assetsByKindAndName.get('image').get(realName);
        if (asset == null) return null;

        return asset.texture;

    }

    public function font(name:Either<String,AssetId<String>>):BitmapFont {

        var realName:String = cast name;
        if (realName.startsWith('font:')) realName = realName.substr(5);
        
        if (!assetsByKindAndName.exists('font')) return null;
        var asset:FontAsset = cast assetsByKindAndName.get('font').get(realName);
        if (asset == null) return null;

        return asset.font;

    }

    public function sound(name:Either<String,AssetId<String>>):Sound {

        var realName:String = cast name;
        if (realName.startsWith('sound:')) realName = realName.substr(6);
        
        if (!assetsByKindAndName.exists('sound')) return null;
        var asset:SoundAsset = cast assetsByKindAndName.get('sound').get(realName);
        if (asset == null) return null;

        return asset.sound;

    }

    public function text(name:Either<String,AssetId<String>>):String {

        var realName:String = cast name;
        if (realName.startsWith('text:')) realName = realName.substr(5);
        
        if (!assetsByKindAndName.exists('text')) return null;
        var asset:TextAsset = cast assetsByKindAndName.get('text').get(realName);
        if (asset == null) return null;

        return asset.text;

    }

    public function bytes(name:Either<String,AssetId<String>>):Bytes {

        var realName:String = cast name;
        if (realName.startsWith('binary:')) realName = realName.substr(7);
        
        if (!assetsByKindAndName.exists('binary')) return null;
        var asset:BinaryAsset = cast assetsByKindAndName.get('binary').get(realName);
        if (asset == null) return null;

        return asset.bytes;

    }

    public function shader(name:Either<String,AssetId<String>>):Shader {

        var realName:String = cast name;
        if (realName.startsWith('shader:')) realName = realName.substr(7);
        
        if (!assetsByKindAndName.exists('shader')) return null;
        var asset:ShaderAsset = cast assetsByKindAndName.get('shader').get(realName);
        if (asset == null) return null;

        return asset.shader;

    }

    public function database(name:Either<String,AssetId<String>>):Array<DynamicAccess<String>> {

        var realName:String = cast name;
        if (realName.startsWith('database:')) realName = realName.substr(9);
        
        if (!assetsByKindAndName.exists('database')) return null;
        var asset:DatabaseAsset = cast assetsByKindAndName.get('database').get(realName);
        if (asset == null) return null;

        return asset.database;

    }

    public function fragments(name:Either<String,AssetId<String>>):DynamicAccess<FragmentData> {

        var realName:String = cast name;
        if (realName.startsWith('fragments:')) realName = realName.substr(10);
        
        if (!assetsByKindAndName.exists('fragments')) return null;
        var asset:FragmentsAsset = cast assetsByKindAndName.get('fragments').get(realName);
        if (asset == null) return null;

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
     * Watch the given asset directory. Any change will fire `assetFilesChange` event.
     * If `hotReload` is set to `true` (its default), related assets will be hot reloaded
     * when their file changes on disk.
     * Behavior may differ depending on the platfom.
     * When using web target via electron, be sure to add `ceramic_use_electron` define.
     * @param path
     *     The assets path to watch. You could use `ceramic.macros.DefinesMacro.getDefine('assets_path')`
     *     to watch default asset path in project. It's the path that will be used if none is provided
     * @param hotReload 
     *     `true` by default. Will enable hot reload of assets when related file changes on disk
     * @return WatchDirectory instance used internally
     */
    public function watchDirectory(?path:String, hotReload:Bool = true):WatchDirectory {
        
        if (runtimeAssets != null) {
            throw 'There is already an instance of RuntimeAssets assigned. Cannot watch a directory, which also need its own instance';
        }

        if (path == null) {
            #if (web && !ceramic_use_electron)
            throw 'Cannot watch directory when using web target! (unless using electron runner and `ceramic_use_electron` define)';
            #else
            path = ceramic.macros.DefinesMacro.getDefine('assets_path');
            
            // Pre-multiply images alpha on the fly because we are reading from source assets
            if (defaultImageOptions == null) {
                defaultImageOptions = {};
            }
            defaultImageOptions.premultiplyAlpha = true;
            #end
        }

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
                    if (value > lastModifiedByRealAssetPath.get(realPathKey)) {
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
     * Used internally to make sure sub-instances of `Assets` take owner live reload settings and related
     * @param assets 
     */
    @:noCompletion public function inheritRuntimeAssetsFromAssets(assets:Assets):Void {

        runtimeAssets = assets.runtimeAssets;
        defaultImageOptions = assets.defaultImageOptions;

    }

/// Static helpers

    public static function decodePath(path:String):AssetPathInfo {

        return new AssetPathInfo(path);

    }

    public static function addAssetKind(kind:String, add:Assets->String->?AssetOptions->Void, extensions:Array<String>, dir:Bool, types:Array<String>):Void {

        customAssetKinds.set(kind, {
            kind: kind,
            add: add,
            extensions: extensions,
            dir: dir,
            types: types
        });

    }

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


/// Reloaded count

    static function incrementReloadCount(realAssetPath:String) {

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

        if (Assets.reloadCountByRealAssetPath == null || !Assets.reloadCountByRealAssetPath.exists(realAssetPath))
            return 0;

        return Assets.reloadCountByRealAssetPath.get(realAssetPath);

    }

}
