package ceramic;

class Asset implements Events implements Shortcuts {

/// Events

    @event function complete(success:Bool);

/// Properties

    public var name:String;

/// Lifecycle

    public function new(name:String) {

        this.name = name;

    } //name

    public function load():Void {

        emitComplete(false);

    } //load

} //Asset

class TextureAsset extends Asset {

/// Properties

    public var texture:Texture = null;

/// Lifecycle

    override public function new(name:String) {

        super(name);

    } //name

    override public function load() {

        app.backend.textures.load(name, null, function(texture) {

            if (texture != null) {
                this.texture = new Texture(texture);
                emitComplete(true);
            }
            else {
                emitComplete(false);
            }

        });

    } //load

} //TextureAsset

class FontAsset extends Asset {

    override public function new(name:String) {

        super(name);

    } //name

    override public function load() {

        // TODO use text and textures (bitmap font)
        emitComplete(false);
        /*
        app.backend.fonts.load(name, null, function(font) {

            if (font != null) {
                //this.font = new Font(font);
                emitComplete(true);
            }
            else {
                emitComplete(false);
            }

        });
        */

    } //load

} //FontAsset

class TextAsset extends Asset {

    override public function new(name:String) {

        super(name);

    } //name

    override public function load() {

        app.backend.texts.load(name, function(text) {

            if (text != null) {
                //this.text = text;
                emitComplete(true);
            }
            else {
                emitComplete(false);
            }

        });

    } //load

} //TextAsset

class AudioAsset extends Asset {

    override public function new(name:String) {

        super(name);

    } //name

    override public function load() {

        app.backend.audio.load(name, null, function(audio) {

            if (audio != null) {
                //this.audio = new Audio(audio);
                emitComplete(true);
            }
            else {
                emitComplete(false);
            }

        });

    } //load

} //AudioAsset

class Assets extends Entity {

/// Events

    @event function complete(success:Bool);

/// Properties

    public var assetsByName:Map<String,Asset> = new Map<String,Asset>();

/// Lifecycle

    public function new() {

    } //new

/// Add assets to load

    public function addTexture(name:String):Void {

        assetsByName.set(name, new TextureAsset(name));

    } //addTexture

    public function addFont(name:String):Void {

        assetsByName.set(name, new FontAsset(name));

    } //addFont

    public function addText(name:String):Void {

        assetsByName.set(name, new TextAsset(name));

    } //addText

    public function addAudio(name:String):Void {

        assetsByName.set(name, new AudioAsset(name));

    } //addAudio

/// Load

    public function load():Void {

        var pending = 0;
        var allSuccess = true;

        // Prepare loading
        for (name in assetsByName.keys()) {

            var asset = assetsByName.get(name);
            asset.onceComplete(this, function(success) {

                if (!success) {
                    allSuccess = false;
                    trace('Error when loading asset $name ($asset)');
                }

                pending--;
                if (pending == 0) {
                    emitComplete(allSuccess);
                }

            });
            pending++;

        }

        // Load
        for (name in assetsByName.keys()) {

            var asset = assetsByName.get(name);
            asset.load();

        }

    } //load

/// Get

    public function texture(name:String):Texture {

        var asset:TextureAsset = cast assetsByName.get(name);
        if (asset == null) return null;
        return asset.texture;

    } //texture

} //Assets
