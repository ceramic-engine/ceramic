package ceramic;

import ceramic.Shortcuts.*;
import haxe.io.Bytes;

class BinaryAsset extends Asset {

    @observe public var bytes:Bytes = null;

    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('binary', name, variant, options #if ceramic_debug_entity_allocs , pos #end);

    }

    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load binary asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        var loadOptions:AssetOptions = {};
        if (owner != null) {
            loadOptions.immediate = owner.immediate;
            loadOptions.loadMethod = owner.loadMethod;
        }
        if (options != null) {
            for (key in Reflect.fields(options)) {
                Reflect.setField(loadOptions, key, Reflect.field(options, key));
            }
        }

        // Add reload count if any
        var backendPath = path;
        var realPath = Assets.realAssetPath(backendPath, runtimeAssets);
        var assetReloadedCount = Assets.getReloadCount(realPath);
        if (app.backend.binaries.supportsHotReloadPath() && assetReloadedCount > 0) {
            realPath += '?hot=' + assetReloadedCount;
            backendPath += '?hot=' + assetReloadedCount;
        }

        log.info('Load binary $backendPath');
        app.backend.binaries.load(realPath, loadOptions, function(bytes) {

            if (bytes != null) {
                this.bytes = bytes;
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                log.error('Failed to load binary at path: $path');
                emitComplete(false);
            }

        });

    }

    override function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        if (!app.backend.binaries.supportsHotReloadPath())
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
            log.info('Reload binary (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        bytes = null;

    }

}
