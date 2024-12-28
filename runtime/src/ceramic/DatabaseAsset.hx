package ceramic;

import ceramic.Shortcuts.*;
import haxe.DynamicAccess;

class DatabaseAsset extends Asset {

    @observe public var database:Array<DynamicAccess<String>> = null;

    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('database', name, variant, options #if ceramic_debug_entity_allocs , pos #end);

    }

    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load database asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        var loadOptions:AssetOptions = {};
        if (owner != null) {
            loadOptions.immediate = owner.immediate;
            loadOptions.loadMethod = owner.loadMethod;
        }

        // Add reload count if any
        var backendPath = path;
        var realPath = Assets.realAssetPath(backendPath, runtimeAssets);
        var assetReloadedCount = Assets.getReloadCount(realPath);
        if (app.backend.texts.supportsHotReloadPath() && assetReloadedCount > 0) {
            realPath += '?hot=' + assetReloadedCount;
            backendPath += '?hot=' + assetReloadedCount;
        }

        log.info('Load database $backendPath');
        app.backend.texts.load(realPath, loadOptions, function(text) {

            if (text != null) {
                try {
                    this.database = Csv.parse(text);
                } catch (e:Dynamic) {
                    status = BROKEN;
                    log.error('Failed to parse database at path: $path');
                    emitComplete(false);
                    return;
                }
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                log.error('Failed to load database at path: $path');
                emitComplete(false);
            }

        });

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

        if (newTime != previousTime) {
            log.info('Reload database (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        database = null;

    }

}
