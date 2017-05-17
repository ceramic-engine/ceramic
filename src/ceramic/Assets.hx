package ceramic;

abstract AssetId(String) {

    inline public function new(string:String) {
        this = string;
    }

} //AssetId

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

class ImageAsset extends Asset {

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

        app.backend.texts.load(name, null, function(text) {

            //trace(text);

        });

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

class SoundAsset extends Asset {

    override public function new(name:String) {

        super(name);

    } //name

    override public function load() {

        app.backend.audio.load(name, null, function(audio) {

            if (audio != null) {
                //this.audio = new Sound(audio);
                emitComplete(true);
            }
            else {
                emitComplete(false);
            }

        });

    } //load

} //AudioAsset

#if !macro
@:build(ceramic.macros.AssetsMacro.buildNames('image'))
#end
class Images {}

#if !macro
@:build(ceramic.macros.AssetsMacro.buildNames('text'))
#end
class Texts {}

#if !macro
@:build(ceramic.macros.AssetsMacro.buildNames('sound'))
#end
class Sounds {}

#if !macro
@:build(ceramic.macros.AssetsMacro.buildNames('font'))
#end
@:allow(ceramic.Assets)
class Fonts {}

#if !macro
@:build(ceramic.macros.AssetsMacro.buildLists())
#end
class Assets extends Entity {

/// Events

    @event function complete(success:Bool);

/// Properties

    public var assetsByName:Map<String,Asset> = new Map<String,Asset>();

/// Lifecycle

    public function new() {

    } //new

/// Add assets to load

    public function add(id:AssetId):Void {

        var value:String = cast id;
        var colonIndex = value.indexOf(':');

        if (colonIndex == -1) {
            throw "Assets: invalid asset id: " + id;
        }

        var kind = value.substr(0, colonIndex);
        var name = value.substr(colonIndex + 1);

        switch (kind) {
            case 'image': addImage(name);
            case 'text': addText(name);
            case 'sound': addSound(name);
            case 'font': addFont(name);
            default: throw "Assets: invalid asset kind for id: " + id;
        }

    } //add

    public function addImage(name:String):Void {

        assetsByName.set(name, new ImageAsset(name));

    } //addTexture

    public function addFont(name:String):Void {

        assetsByName.set(name, new FontAsset(name));

    } //addFont

    public function addText(name:String):Void {

        assetsByName.set(name, new TextAsset(name));

    } //addText

    public function addSound(name:String):Void {

        assetsByName.set(name, new SoundAsset(name));

    } //addSound

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

        var asset:ImageAsset = cast assetsByName.get(name);
        if (asset == null) return null;
        return asset.texture;

    } //texture

} //Assets
