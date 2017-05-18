package ceramic;

using StringTools;

abstract AssetId(String) {

    inline public function new(string:String) {
        this = string;
    }

} //AssetId

class Asset implements Events implements Shortcuts {

/// Events

    @event function complete(success:Bool);

/// Properties

    public var kind:String;

    public var name:String;

    public var path:String;

/// Lifecycle

    public function new(kind:String, name:String) {

        this.kind = kind;
        this.name = name;

        computePath();

    } //name

    public function load():Void {

        warning('This asset as no load implementation.');
        emitComplete(false);

    } //load

    public function computePath():Void {

        var extensions = switch (kind) {
            case 'image': app.backend.info.imageExtensions();
            case 'text': app.backend.info.textExtensions();
            case 'sound': app.backend.info.soundExtensions();
            case 'font': ['fnt'];
            default: [];
        }

        path = null;
        var targetDensity = Assets.targetTextureDensity();

        if (extensions.length > 0 && Assets.allByName.exists(name)) {
            var list = Assets.allByName.get(name);
            for (ext in extensions) {

                var bestDensity = 1.0;
                var bestDensityDiff = 99999999999.0;

                for (item in list) {
                    var pathInfo = Assets.decodePath(item);

                    if (pathInfo.extension == ext) {
                        var diff = Math.abs(targetDensity - pathInfo.density);
                        if (diff < bestDensityDiff) {
                            bestDensityDiff = diff;
                            bestDensity = pathInfo.density;
                            path = pathInfo.path;
                        }
                    }
                }
                if (path != null) {
                    break;
                }
            }
        }

    } //computePath

} //Asset

class ImageAsset extends Asset {

/// Properties

    public var texture:Texture = null;

/// Lifecycle

    override public function new(name:String) {

        super('image', name);

    } //name

    override public function load() {

        app.backend.textures.load(path, null, function(texture) {

            if (texture != null) {
                this.texture = new Texture(texture);
                emitComplete(true);
            }
            else {
                error('Failed to load texture at path: $path');
                emitComplete(false);
            }

        });

    } //load

} //TextureAsset

class FontAsset extends Asset {

    override public function new(name:String) {

        super('font', name);

    } //name

    override public function load() {

        app.backend.texts.load(path, null, function(text) {

            if (text != null) {

                try {
                    var fontData = ceramic.internal.BitmapFontParser.parse(text);

                    trace('font data');
                    trace(fontData);

                } catch (e:Dynamic) {
                    error('Failed to decode font data at path: $path');
                    emitComplete(false);
                }

                emitComplete(true);
            }
            else {
                error('Failed to load font data at path: $path');
                emitComplete(false);
            }

        });

    } //load

} //FontAsset

class TextAsset extends Asset {

    override public function new(name:String) {

        super('text', name);

    } //name

    override public function load() {

        app.backend.texts.load(path, function(text) {

            if (text != null) {
                emitComplete(true);
            }
            else {
                error('Failed to load text at path: $path');
                emitComplete(false);
            }

        });

    } //load

} //TextAsset

class SoundAsset extends Asset {

    override public function new(name:String) {

        super('sound', name);

    } //name

    override public function load() {

        app.backend.audio.load(path, null, function(audio) {

            if (audio != null) {
                //this.audio = new Sound(audio);
                emitComplete(true);
            }
            else {
                error('Failed to load audio at path: $path');
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

class AssetPathInfo {

/// Properties

    public var density:Float;

    public var extension:String;

    public var name:String;

    public var path:String;

/// Constructor

    public function new(path:String) {

        this.path = path;

        var dotIndex = path.lastIndexOf('.');
        extension = path.substr(dotIndex + 1).toLowerCase();

        var truncatedName = path.substr(0, dotIndex);
        var baseAtIndex = truncatedName.lastIndexOf('@');

        density = 1;
        if (baseAtIndex == -1) {
            baseAtIndex = dotIndex;
        }
        else {
            var afterAt = truncatedName.substr(baseAtIndex + 1);
            if (afterAt.endsWith('x')) {
                var flt = Std.parseFloat(afterAt.substr(0, afterAt.length-1));
                if (!Math.isNaN(flt)) {
                    density = flt;
                }
            }
        }

        name = path.substr(0, cast Math.min(baseAtIndex, dotIndex));

    }

    function toString():String {

        return '' + {extension: extension, name: name, path: path, density: density};

    } //toString

} //AssetPathInfo

#if !macro
@:build(ceramic.macros.AssetsMacro.buildLists())
#end
class Assets extends Entity {

/// Events

    @event function complete(success:Bool);

/// Properties

    var addedAssets:Array<Asset> = [];

    var assetsByKindAndName:Map<String,Map<String,Asset>> = new Map();

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

        addAsset(new ImageAsset(name));

    } //addTexture

    public function addFont(name:String):Void {

        addAsset(new FontAsset(name));

    } //addFont

    public function addText(name:String):Void {

        addAsset(new TextAsset(name));

    } //addText

    public function addSound(name:String):Void {

        addAsset(new SoundAsset(name));

    } //addSound

    public function addAsset(asset:Asset):Void {

        if (!assetsByKindAndName.exists(asset.kind)) assetsByKindAndName.set(asset.kind, new Map());
        assetsByKindAndName.get(asset.kind).set(asset.name, asset);
        addedAssets.push(asset);

    } //addAsset

/// Load

    public function load():Void {

        var pending = 0;
        var allSuccess = true;

        // Prepare loading
        for (asset in addedAssets) {

            asset.onceComplete(this, function(success) {

                if (!success) {
                    allSuccess = false;
                    error('Failed to load asset ${asset.name} ($asset)');
                }

                pending--;
                if (pending == 0) {
                    emitComplete(allSuccess);
                }

            });
            pending++;

        }

        // Load
        for (asset in addedAssets) {

            asset.load();

        }

    } //load

/// Get

    public function texture(name:String):Texture {

        if (!assetsByKindAndName.exists('image')) return null;
        var asset:ImageAsset = cast assetsByKindAndName.get('image').get(name);
        if (asset == null) return null;
        return asset.texture;

    } //texture

/// Static helpers

    public static function decodePath(path:String):AssetPathInfo {

        return new AssetPathInfo(path);

    } //decodePath

    public static function targetTextureDensity():Float {

        return (settings.targetDensity > 0) ?
            settings.targetDensity
        :
            screen.density
        ;

    } //targetTextureDensity

} //Assets
