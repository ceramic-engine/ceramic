package ceramic;

import ceramic.Shortcuts.*;

class SoundAsset extends Asset {

    /// Events
    
    @event function replaceSound(newSound:Sound, prevSound:Sound);

    public var stream:Bool = false;

    @observe public var sound:Sound = null;

    override public function new(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('sound', name, options #if ceramic_debug_entity_allocs , pos #end);

    }

    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load sound asset if path is undefined.');
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

        log.info('Load sound $backendPath');
        app.backend.audio.load(realPath, { stream: options.stream }, function(audio) {

            if (audio != null) {
                this.sound = new Sound(audio);
                this.sound.asset = this;
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                log.error('Failed to load audio at path: $path');
                emitComplete(false);
            }

        });

    }

    override function assetFilesDidChange(newFiles:ImmutableMap<String, Float>, previousFiles:ImmutableMap<String, Float>):Void {

        if (!app.backend.audio.supportsHotReloadPath())
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
            log.info('Reload sound (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        if (sound != null) {
            sound.destroy();
            sound = null;
        }

    }

}
