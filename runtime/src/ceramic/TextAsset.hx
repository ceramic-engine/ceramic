package ceramic;

import ceramic.Shortcuts.*;

class TextAsset extends Asset {

    public var text:String = null;

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

        log.info('Load text $path');
        app.backend.texts.load(Assets.realAssetPath(path, runtimeAssets), function(text) {

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

    override function destroy():Void {

        super.destroy();

        text = null;

    }

}
