package ceramic;

import ceramic.Path;
import ceramic.Shortcuts.*;
import tracker.Observable;

using StringTools;

@:allow(ceramic.Assets)
class Asset extends Entity implements Observable {

/// Events

    @event function complete(success:Bool);

/// Properties

    /**
     * Asset kind
     */
    public var kind(default,null):String;

    /**
     * Asset name
     */
    public var name(default,set):String;

    /**
     * Asset variant
     */
    public var variant(default,set):String;

    /**
     * Asset full name (including variant, if provided)
     */
    public var fullName(default,null):String;

    /**
     * Asset path
     */
    public var path(default,set):String;

    /**
     * All paths related to this asset
     */
    public var allPaths(default,null):Array<String>;

    /**
     * Asset target density. Some assets depend on current screen density,
     * like bitmap fonts, textures. Default is 1.0
     */
    public var density(default,null):Float = 1.0;

    /**
     * Asset owner. The owner is a group of assets (Assets instance). When the owner gets
     * destroyed, every asset it owns get destroyed as well.
     */
    public var owner(default,null):Assets;

    /**
     * Optional runtime assets, used to compute path.
     */
    public var runtimeAssets(default,set):RuntimeAssets;

    /**
     * Asset options. Depends on asset kind and even backend in some cases.
     */
    public var options(default,null):AssetOptions;

    /**
     * Sub assets-list. Defaults to null but some kind of assets (like bitmap fonts) instanciate it to load sub-assets it depends on.
     */
    public var assets(default,null):Assets = null;

    /**
     * Manage asset retain count. Increase it by calling `retain()` and decrease it by calling `release()`.
     * This can be used when mutliple objects are using the same assets
     * without knowing in advance when they will be needed.
     */
    public var refCount(default,null):Int = 0;

    @observe public var status:AssetStatus = NONE;

    var handleTexturesDensityChange(default,set):Bool = false;

    var hotReload(default,set):Bool = false;

    var customExtensions(default,null):Array<String> = null;

/// Lifecycle

    public function new(kind:String, name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        this.kind = kind;
        this.options = options != null ? options : {};
        this.name = name;
        this.variant = variant;

        computePath();

    }

    public function load():Void {

        status = BROKEN;
        log.error('This asset as no load implementation.');
        emitComplete(false);

    }

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
                case 'font': ['fnt'];
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

    function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        // Override

    }

/// Print

    override function toString():String {

        var className = className();

        if (path != null && path.trim() != '') {
            return '$className($name $path)';
        } else {
            return '$className($name)';
        }

    }

/// Complete event hook

    inline function willEmitComplete(success:Bool) {

        if (success && owner != null) {
            owner.emitUpdate(this);
        }

    }

/// Reference counting

    public function retain():Void {

        #if ceramic_debug_refcount
        ceramic.Utils.printStackTrace();
        log.success('RETAIN ' + this + ' $refCount + 1');
        #end
        refCount++;

    }

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
