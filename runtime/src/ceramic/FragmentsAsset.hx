package ceramic;

import ceramic.Shortcuts.*;

import haxe.Json;
import haxe.DynamicAccess;

class FragmentsAsset extends Asset {

    @observe public var fragments:DynamicAccess<FragmentData> = null;

    override public function new(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('fragments', name, options #if ceramic_debug_entity_allocs , pos #end);

    }

    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load fragments asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        // Add reload count if any
        var backendPath = path;
        var realPath = Assets.realAssetPath(backendPath, runtimeAssets);
        var assetReloadedCount = Assets.getReloadCount(realPath);
        if (app.backend.texts.supportsHotReloadPath() && assetReloadedCount > 0) {
            realPath += '?hot=' + assetReloadedCount;
            backendPath += '?hot=' + assetReloadedCount;
        }

        log.info('Load fragments $backendPath');
        app.backend.texts.load(realPath, function(text) {

            if (text != null) {
                try {
                    this.fragments = Json.parse(text);
                } catch (e:Dynamic) {
                    status = BROKEN;
                    log.error('Failed to parse fragments at path: $path');
                    emitComplete(false);
                    return;
                }
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                log.error('Failed to load fragments at path: $path');
                emitComplete(false);
            }

        });

    }

    override function assetFilesDidChange(newFiles:ImmutableMap<String, Float>, previousFiles:ImmutableMap<String, Float>):Void {

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

        if (newTime > previousTime) {
            log.info('Reload fragments (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        fragments = null;

    }

}
