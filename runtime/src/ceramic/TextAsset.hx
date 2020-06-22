package ceramic;

import ceramic.Shortcuts.*;

class TextAsset extends Asset {

    @observe public var text:String = null;

    override public function new(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('text', name, options #if ceramic_debug_entity_allocs , pos #end);

    }

    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load text asset if path is undefined.');
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

        log.info('Load text $backendPath');
        app.backend.texts.load(realPath, function(text) {

            if (text != null) {
                this.text = text;
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                log.error('Failed to load text at path: $path');
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

        if (newTime > previousTime) {
            log.info('Reload text (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        text = null;

    }

}
