package ceramic;

import ceramic.internal.BitmapFontParser;
import ceramic.BitmapFont;

using StringTools;

typedef AssetOptions = Dynamic;

enum AssetStatus {
    NONE;
    LOADING;
    READY;
    BROKEN;
}

abstract AssetId(String) {

    inline public function new(string:String) {
        this = string;
    }

} //AssetId

class Asset extends Entity {

/// Events

    @event function complete(success:Bool);

/// Properties

    public var kind:String;

    public var path(default,set):String;

    public var density:Float = 1.0;

    public var owner:Assets;

    public var options:AssetOptions;

    @observable public var status:AssetStatus = NONE;

    var handleTexturesDensityChange(default,set):Bool = false;

/// Lifecycle

    public function new(kind:String, name:String, ?options:AssetOptions) {

        this.kind = kind;
        this.name = name;
        this.options = options != null ? options : {};

        computePath();

    } //name

    public function load():Void {

        status = BROKEN;
        error('This asset as no load implementation.');
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

        var targetDensity = screen.texturesDensity;
        var path = null;
        var bestPathInfo = null;

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
                            bestPathInfo = pathInfo;
                        }
                    }
                }
                if (path != null) {
                    break;
                }
            }
        }

        this.path = path; // sets density

        // Set additional options
        if (bestPathInfo != null && bestPathInfo.flags != null) {
            for (flag in bestPathInfo.flags.keys()) {
                if (!Reflect.hasField(options, flag)) {
                    Reflect.setField(options, flag, bestPathInfo.flags.get(flag));
                }
            }
        }

    } //computePath

    function set_path(path:String):String {

        if (this.path == path) return path;
        this.path = path;

        if (path == null) {
            density = 1.0;
        } else {
            density = Assets.decodePath(path).density;
        }

        return path;

    } //set_path

    function set_handleTexturesDensityChange(value:Bool):Bool {

        if (handleTexturesDensityChange == value) return value;
        handleTexturesDensityChange = value;

        if (value) {
            screen.onTexturesDensityChange(this, texturesDensityDidChange);
        }
        else {
            screen.offTexturesDensityChange(texturesDensityDidChange);
        }

        return value;

    } //set_handleTexturesDensityChange

    function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        // Override

    } //texturesDensityDidChange

} //Asset

class ImageAsset extends Asset {

/// Properties

    public var texture:Texture = null;

/// Lifecycle

    override public function new(name:String, ?options:AssetOptions) {

        super('image', name, options);
        handleTexturesDensityChange = true;

    } //name

    override public function load() {

        status = LOADING;
        log('Load $path');
        app.backend.textures.load(path, null, function(texture) {

            if (texture != null) {

                var prevTexture = this.texture;
                this.texture = new Texture(texture, density);
                this.texture.name = path;

                // Link the texture to this asset so that
                // destroying one will destroy the other
                this.texture.asset = this;

                if (prevTexture != null) {
                    // Texture was reloaded. Update related visuals
                    for (visual in app.visuals) {
                        if (Std.is(visual, Quad)) {
                            var quad:Quad = cast visual;
                            if (quad.texture == prevTexture) {

                                // Update texture but keep same frame
                                //
                                var frameX = quad.frameX;
                                var frameY = quad.frameY;
                                var frameWidth = quad.frameWidth;
                                var frameHeight = quad.frameHeight;

                                quad.texture = this.texture;

                                // Frame was reset by texture assign.
                                // Put it back to what it was.
                                quad.frameX = frameX;
                                quad.frameY = frameY;
                                quad.frameWidth = frameWidth;
                                quad.frameHeight = frameHeight;
                            }
                        }
                        else if (Std.is(visual, Mesh)) {
                            var mesh:Mesh = cast visual;
                            if (mesh.texture == prevTexture) {
                                mesh.texture = this.texture;
                            }
                        }
                    }

                    // Set asset to null because we don't want it
                    // to be destroyed when destroying the texture.
                    prevTexture.asset = null;
                    // Destroy texture
                    prevTexture.destroy();
                }

                status = READY;
                emitComplete(true);
                if (handleTexturesDensityChange) {
                    checkTexturesDensity();
                }
            }
            else {
                status = BROKEN;
                error('Failed to load texture at path: $path');
                emitComplete(false);
            }

        });

    } //load

    override function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        if (status == READY) {
            // Only check if the asset is already loaded.
            // If it is currently loading, it will check
            // at load end anyway.
            checkTexturesDensity();
        }

    } //texturesDensityDidChange

    function checkTexturesDensity():Void {

        var prevPath = path;
        computePath();

        if (prevPath != path) {
            log('Reload texture ($prevPath -> $path)');
            load();
        }

    } //checkTexturesDensity

    function destroy():Void {

        if (texture != null) {
            texture.destroy();
            texture = null;
        }

    } //destroy

} //TextureAsset

class FontAsset extends Asset {

/// Properties

    public var fontData:BitmapFontData = null;

    public var pages:Map<String,Texture> = null;

    public var font:BitmapFont = null;

/// Lifecycle

    override public function new(name:String, ?options:AssetOptions) {

        super('font', name, options);
        handleTexturesDensityChange = true;

    } //name

    override public function load() {

        // Load font data
        status = LOADING;
        log('Load $path');
        var tmpAssets0 = new Assets();
        var asset = new TextAsset(name);
        asset.handleTexturesDensityChange = false;
        asset.path = path;
        tmpAssets0.addAsset(asset);
        tmpAssets0.onceComplete(function(success) {

            var text = asset.text;

            if (text != null) {

                // Change font data asset owner
                tmpAssets0.removeAsset(asset);
                if (owner != null) {
                    owner.addAsset(asset);
                }

                try {
                    fontData = BitmapFontParser.parse(text);

                    // Load pages
                    var pages = new Map();
                    var tmpAssets1 = new Assets();
                    var assetList:Array<ImageAsset> = [];

                    for (page in fontData.pages) {

                        var pathInfo = Assets.decodePath(page.file);
                        var asset = new ImageAsset(pathInfo.name);

                        // Because it is handled at font level
                        asset.handleTexturesDensityChange = false;

                        asset.path = pathInfo.path;
                        tmpAssets1.addAsset(asset);
                        assetList.push(asset);
                        
                    }

                    tmpAssets1.onceComplete(function(success) {

                        if (success) {
                            // Change texture assets owner
                            for (asset in assetList) {
                                tmpAssets1.removeAsset(asset);
                                if (owner != null) {
                                    owner.addAsset(asset);
                                }

                                // Fill pages mapping
                                pages.set(asset.path, asset.texture);
                            }

                            // Create bitmap font
                            var prevFont = this.font;
                            this.font = new BitmapFont(fontData, pages);
                            this.font.name = path;

                            // Link the font to this asset so that
                            // destroying one will destroy the other
                            this.font.asset = this;

                            if (prevFont != null) {
                                // Font was reloaded. Update related visuals
                                for (visual in app.visuals) {
                                    if (Std.is(visual, Text)) {
                                        var text:Text = cast visual;
                                        if (text.font == prevFont) {
                                            text.font = this.font;
                                        }
                                    }
                                }

                                // Set asset to null because we don't want it
                                // to be destroyed when destroying the font.
                                prevFont.asset = null;
                                // Destroy texture
                                prevFont.destroy();
                            }

                            status = READY;
                            emitComplete(true);

                        }
                        else {
                            status = BROKEN;
                            error('Failed to load textures for font at path: $path');
                            emitComplete(false);
                        }

                        // Destroy temporary assets
                        tmpAssets1.destroy();

                    });

                    tmpAssets1.load();

                } catch (e:Dynamic) {
                    status = BROKEN;
                    error('Failed to decode font data at path: $path');
                    emitComplete(false);
                }
            }
            else {
                status = BROKEN;
                error('Failed to load font data at path: $path');
                emitComplete(false);
            }

            // Destroy temporary assets
            tmpAssets0.destroy();
        });

        tmpAssets0.load();

    } //load

    override function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        if (status == READY) {
            // Only check if the asset is already loaded.
            // If it is currently loading, it will check
            // at load end anyway.
            checkTexturesDensity();
        }

    } //texturesDensityDidChange

    function checkTexturesDensity():Void {

        var prevPath = path;
        computePath();

        if (prevPath != path) {
            log('Reload font ($prevPath -> $path)');
            load();
        }

    } //checkTexturesDensity

    function destroy():Void {

        if (font != null) {
            font.destroy();
            font = null;
        }

    } //destroy

} //FontAsset

class TextAsset extends Asset {

    public var text:String = null;

    override public function new(name:String, ?options:AssetOptions) {

        super('text', name, options);

    } //name

    override public function load() {

        status = LOADING;
        log('Load $path');
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

    function destroy():Void {

        text = null;

    } //destroy

} //TextAsset

class SoundAsset extends Asset {

    public var stream:Bool = false;

    public var sound:Sound = null;

    override public function new(name:String, ?options:AssetOptions) {

        super('sound', name, options);

    } //name

    override public function load() {

        status = LOADING;
        log('Load $path');
        app.backend.audio.load(path, { stream: options.stream }, function(audio) {

            if (audio != null) {
                this.sound = new Sound(audio);
                this.sound.asset = this;
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                error('Failed to load audio at path: $path');
                emitComplete(false);
            }

        });

    } //load

    function destroy():Void {

        if (sound != null) {
            sound.destroy();
            sound = null;
        }

    } //destroy


} //SoundAsset

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

    public var flags:Map<String,Dynamic>;

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
            var afterAtParts = truncatedName.substr(baseAtIndex + 1);
            for (afterAt in afterAtParts.split('+')) {
                var isFlag = true;
                if (afterAt.endsWith('x')) {
                    var flt = Std.parseFloat(afterAt.substr(0, afterAt.length-1));
                    if (!Math.isNaN(flt)) {
                        density = flt;
                        isFlag = false;
                    }
                }
                if (isFlag) {
                    if (flags == null) flags = new Map();
                    var equalIndex = afterAt.indexOf('=');
                    if (equalIndex == -1) {
                        flags.set(afterAt, true);
                    } else {
                        var key = afterAt.substr(0, equalIndex);
                        var val = afterAt.substr(equalIndex + 1);
                        flags.set(key, val);
                    }
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

    public function destroy() {

        for (asset in addedAssets) {
            asset.destroy();
        }
        addedAssets = null;
        assetsByKindAndName = null;

    } //destroy

/// Add assets to load

    public function add(id:AssetId, ?options:AssetOptions):Void {

        var value:String = cast id;
        var colonIndex = value.indexOf(':');

        if (colonIndex == -1) {
            throw "Assets: invalid asset id: " + id;
        }

        var kind = value.substr(0, colonIndex);
        var name = value.substr(colonIndex + 1);

        switch (kind) {
            case 'image': addImage(name, options);
            case 'text': addText(name, options);
            case 'sound': addSound(name, options);
            case 'font': addFont(name, options);
            default: throw "Assets: invalid asset kind for id: " + id;
        }

    } //add

    public function addImage(name:String, ?options:AssetOptions):Void {
        
        addAsset(new ImageAsset(name, options));

    } //addTexture

    public function addFont(name:String, ?options:AssetOptions):Void {

        addAsset(new FontAsset(name, options));

    } //addFont

    public function addText(name:String, ?options:AssetOptions):Void {

        addAsset(new TextAsset(name, options));

    } //addText

    public function addSound(name:String, ?options:AssetOptions):Void {

        addAsset(new SoundAsset(name, options));

    } //addSound

    public function addAsset(asset:Asset):Void {

        if (!assetsByKindAndName.exists(asset.kind)) assetsByKindAndName.set(asset.kind, new Map());
        var byName = assetsByKindAndName.get(asset.kind);

        var previousAsset = byName.get(asset.kind);
        if (previousAsset != null) {
            if (previousAsset == asset) {
                warning('Cannot add asset $asset because an asset is already added for its name: ${asset.name} ($previousAsset).');
            } else {
                warning('Cannot add asset $asset because it is already added for name: ${asset.name}.');
            }
            return;
        }

        byName.set(asset.name, asset);
        if (asset.owner != null && asset.owner != this) {
            asset.owner.removeAsset(asset);
        }
        addedAssets.push(asset);
        asset.owner = this;

    } //addAsset

    public function removeAsset(asset:Asset):Void {

        var byName = assetsByKindAndName.get(asset.kind);
        var toRemove = byName.get(asset.name);

        if (asset != toRemove) {
            throw 'Cannot remove asset $asset if it was not added at the first place.';
        }

        addedAssets.remove(asset);
        byName.remove(asset.name);
        asset.owner = null;

    } //removeAsset

/// Load

    public function load():Void {

        var pending = 0;
        var allSuccess = true;

        // Prepare loading
        for (asset in addedAssets) {

            if (asset.status == NONE) {

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

        }

        // Load
        if (pending > 0) {

            for (asset in addedAssets) {

                if (asset.status == NONE) {
                    asset.load();
                }

            }

        } else {

            warning('There was no asset to load.');
            emitComplete(true);

        }

    } //load

/// Get

    public function texture(name:Either<String,AssetId>):Texture {

        var realName:String = cast name;
        if (realName.startsWith('image:')) realName = realName.substr(6);

        if (!assetsByKindAndName.exists('image')) return null;
        var asset:ImageAsset = cast assetsByKindAndName.get('image').get(realName);
        if (asset == null) return null;

        return asset.texture;

    } //texture

    public function font(name:Either<String,AssetId>):BitmapFont {

        var realName:String = cast name;
        if (realName.startsWith('font:')) realName = realName.substr(5);
        
        if (!assetsByKindAndName.exists('font')) return null;
        var asset:FontAsset = cast assetsByKindAndName.get('font').get(realName);
        if (asset == null) return null;

        return asset.font;

    } //font

    public function sound(name:Either<String,AssetId>):Sound {

        var realName:String = cast name;
        if (realName.startsWith('sound:')) realName = realName.substr(6);
        
        if (!assetsByKindAndName.exists('sound')) return null;
        var asset:SoundAsset = cast assetsByKindAndName.get('sound').get(realName);
        if (asset == null) return null;

        return asset.sound;

    } //font

    public function text(name:Either<String,AssetId>):String {

        var realName:String = cast name;
        if (realName.startsWith('text:')) realName = realName.substr(5);
        
        if (!assetsByKindAndName.exists('text')) return null;
        var asset:TextAsset = cast assetsByKindAndName.get('text').get(realName);
        if (asset == null) return null;

        return asset.text;

    } //text

/// Static helpers

    public static function decodePath(path:String):AssetPathInfo {

        return new AssetPathInfo(path);

    } //decodePath

} //Assets
