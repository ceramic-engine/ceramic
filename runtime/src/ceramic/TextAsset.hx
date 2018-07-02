package ceramic;

import ceramic.Shortcuts.*;

class TextAsset extends Asset {

    public var text:String = null;

    override public function new(name:String, ?options:AssetOptions) {

        super('text', name, options);

    } //name

    override public function load() {

        status = LOADING;

        if (path == null) {
            warning('Cannot load text asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        log('Load text $path');
        app.backend.texts.load(path, function(text) {

            if (text != null) {
                this.text = text;
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                error('Failed to load text at path: $path');
                emitComplete(false);
            }

        });

    } //load

    override function destroy():Void {

        text = null;

    } //destroy

} //TextAsset
