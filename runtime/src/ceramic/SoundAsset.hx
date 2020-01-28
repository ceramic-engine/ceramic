package ceramic;

import ceramic.Shortcuts.*;

class SoundAsset extends Asset {

    public var stream:Bool = false;

    public var sound:Sound = null;

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

        log.info('Load sound $path');
        app.backend.audio.load(Assets.realAssetPath(path), { stream: options.stream }, function(audio) {

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

    override function destroy():Void {

        super.destroy();

        if (sound != null) {
            sound.destroy();
            sound = null;
        }

    }

}
