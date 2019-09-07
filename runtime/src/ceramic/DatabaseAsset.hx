package ceramic;

import ceramic.Shortcuts.*;

import haxe.DynamicAccess;

class DatabaseAsset extends Asset {

    public var database:Array<DynamicAccess<String>> = null;

    override public function new(name:String, ?options:AssetOptions) {

        super('database', name, options);

    } //new

    override public function load() {

        status = LOADING;

        if (path == null) {
            warning('Cannot load database asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        log('Load database $path');
        app.backend.texts.load(path, function(text) {

            if (text != null) {
                try {
                    this.database = Csv.parse(text);
                } catch (e:Dynamic) {
                    status = BROKEN;
                    error('Failed to parse database at path: $path');
                    emitComplete(false);
                    return;
                }
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                error('Failed to load database at path: $path');
                emitComplete(false);
            }

        });

    } //load

    override function destroy():Void {

        super.destroy();

        database = null;

    } //destroy

} //DatabaseAsset
