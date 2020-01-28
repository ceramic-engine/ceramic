package ceramic;

import ceramic.Shortcuts.*;

import haxe.DynamicAccess;

class DatabaseAsset extends Asset {

    public var database:Array<DynamicAccess<String>> = null;

    override public function new(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('database', name, options #if ceramic_debug_entity_allocs , pos #end);

    }

    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load database asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        log.info('Load database $path');
        app.backend.texts.load(Assets.realAssetPath(path), function(text) {

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

    override function destroy():Void {

        super.destroy();

        database = null;

    }

}
