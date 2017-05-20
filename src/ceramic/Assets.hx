package ceramic;

import ceramic.internal.BitmapFontParser;
import ceramic.BitmapFont;

using StringTools;

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

    public var name:String;

    public var path(default,set):String;

    public var density:Float = 1.0;

    public var owner:Assets;

    @observable public var status:AssetStatus = NONE;

    var handleTexturesDensityChange(default,set):Bool = false;

/// Lifecycle

    public function new(kind:String, name:String) {

        this.kind = kind;
        this.name = name;

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

        path = null;
        var targetDensity = screen.texturesDensity;
        var path = null;

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

        this.path = path; // sets density

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

    override public function new(name:String) {

        super('image', name);
        handleTexturesDensityChange = true;

    } //name

    override public function load() {

        status = LOADING;
        log('Load $path');
        app.backend.textures.load(path, null, function(texture) {

            if (texture != null) {

                var prevTexture = this.texture;
                this.texture = new Texture(texture, path, density);

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

    override public function new(name:String) {

        super('font', name);
        handleTexturesDensityChange = true;

    } //name

    override public function load() {

        // Load font data
        status = LOADING;
        log('Load $path');
        app.backend.texts.load(path, null, function(text) {

            if (text != null) {

                try {
                    fontData = BitmapFontParser.parse(text);

                    // Load pages
                    var pages = new Map();
                    var tmpAssets = new Assets();
                    var assetList:Array<ImageAsset> = [];

                    for (page in fontData.pages) {

                        var pathInfo = Assets.decodePath(page.file);
                        var asset = new ImageAsset(pathInfo.name);

                        // Because it is handled at font level
                        asset.handleTexturesDensityChange = false;

                        asset.path = pathInfo.path;
                        tmpAssets.addAsset(asset);
                        assetList.push(asset);
                        
                    }

                    tmpAssets.onComplete(function(success) {

                        if (success) {
                            // Change texture assets owner
                            for (asset in assetList) {
                                tmpAssets.removeAsset(asset);
                                if (owner != null) {
                                    owner.addAsset(asset);
                                }

                                // Fill pages mapping
                                pages.set(asset.path, asset.texture);
                            }

                            // Create bitmap font
                            var prevFont = this.font;
                            font = new BitmapFont(fontData, pages);

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
                        tmpAssets.destroy();

                    });

                    tmpAssets.load();

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

    override public function new(name:String) {

        super('text', name);

    } //name

    override public function load() {

        status = LOADING;
        log('Load $path');
        app.backend.texts.load(path, function(text) {

            if (text != null) {
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

} //TextAsset

class SoundAsset extends Asset {

    override public function new(name:String) {

        super('sound', name);

    } //name

    override public function load() {

        status = LOADING;
        log('Load $path');
        app.backend.audio.load(path, null, function(audio) {

            if (audio != null) {
                //this.audio = new Sound(audio);
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

    public function destroy() {

        for (asset in addedAssets) {
            asset.destroy();
        }
        addedAssets = null;
        assetsByKindAndName = null;

    } //destroy

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

/// Static helpers

    public static function decodePath(path:String):AssetPathInfo {

        return new AssetPathInfo(path);

    } //decodePath

} //Assets
