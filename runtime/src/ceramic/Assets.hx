package ceramic;

import ceramic.internal.BitmapFontParser;
import ceramic.BitmapFont;
import ceramic.Either;
import ceramic.Shortcuts.*;

import haxe.io.Path;

using StringTools;

typedef AssetOptions = Dynamic;

enum AssetStatus {
    NONE;
    LOADING;
    READY;
    BROKEN;
}

@:forward
abstract AssetId<T:String>(T) from T to T {

    inline public function new(value:T) {
        this = value;
    }

} //AssetId

@:allow(ceramic.Assets)
class Asset extends Entity {

/// Events

    @event function complete(success:Bool);

/// Properties

    /** Asset kind */
    public var kind(default,null):String;

    /** Asset name */
    public var name(default,set):String;

    /** Asset path */
    public var path(default,set):String;

    /** Asset target density. Some assets depend on current screen density,
        like bitmap fonts, textures. Default is 1.0 */
    public var density(default,null):Float = 1.0;

    /** Asset owner. The owner is a group of assets (Assets instance). When the owner gets
        destroyed, every asset it owns get destroyed as well. */
    public var owner(default,null):Assets;

    /** Optional runtime assets, used to compute path. */
    public var runtimeAssets(default,set):RuntimeAssets;

    /** Asset options. Depends on asset kind and even backend in some cases. */
    public var options(default,null):AssetOptions;

    /** Sub assets-list. Defaults to null but some kind of assets (like bitmap fonts) instanciate it to load sub-assets it depends on. */
    public var assets(default,null):Assets = null;

    @observable public var status:AssetStatus = NONE;

    var handleTexturesDensityChange(default,set):Bool = false;

/// Lifecycle

    public function new(kind:String, name:String, ?options:AssetOptions) {

        this.kind = kind;
        this.options = options != null ? options : {};
        this.name = name;

        computePath();

    } //name

    public function load():Void {

        status = BROKEN;
        error('This asset as no load implementation.');
        emitComplete(false);

    } //load

    public function destroy():Void {

        if (owner != null) {
            owner.removeAsset(this);
            owner = null;
        }

        if (assets != null) {
            assets.destroy();
            assets = null;
        }

    } //destroy

    public function computePath(?extensions:Array<String>, ?dir:Bool, ?runtimeAssets:RuntimeAssets):Void {

        // Runtime assets
        if (runtimeAssets == null && this.runtimeAssets != null) {
            runtimeAssets = this.runtimeAssets;
        }

        // Compute extensions list and dir flag
        //
        if (extensions == null) {
            extensions = switch (kind) {
                case 'image': app.backend.info.imageExtensions();
                case 'text': app.backend.info.textExtensions();
                case 'sound': app.backend.info.soundExtensions();
                case 'shader': app.backend.info.shaderExtensions();
                case 'font': ['fnt'];
                default: null;
            }
        }
        if (extensions == null || dir == null) {
            if (Assets.customAssetKinds != null && Assets.customAssetKinds.exists(kind)) {
                var kindInfo = Assets.customAssetKinds.get(kind);
                if (extensions == null) extensions = kindInfo.extensions;
                if (dir == null) dir = kindInfo.dir;
            }
        }
        if (extensions == null) extensions = [];
        if (dir == null) dir = false;

        // Compute path
        //
        var targetDensity = screen.texturesDensity;
        var path = null;
        var bestPathInfo = null;

        var byName:Map<String,Array<String>> = dir ?
            runtimeAssets != null ?
                runtimeAssets.getLists().allDirsByName
            :
                Assets.allDirsByName
        :
            runtimeAssets != null ?
                runtimeAssets.getLists().allByName
            :
                Assets.allByName
        ;

        var name = this.name;

        if (extensions.length > 0) {

            // Remove extension in name, if any
            for (ext in extensions) {
                if (name.endsWith('.' + ext)) {
                    name = name.substr(0, name.length - ext.length - 1);
                    break;
                }
            }

            if (byName.exists(name)) {

                var list = byName.get(name);

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

        // Loaded data doesn't match path anymore
        if (status == READY) status = NONE;

        this.path = path;

        if (path == null) {
            density = 1.0;
        } else {
            density = Assets.decodePath(path).density;
        }

        return path;

    } //set_path

    function set_name(name:String):String {

        if (this.name == name) return name;

        this.name = name;
        id = 'asset:$kind:$name';

        return name;

    } //set_name

    function set_runtimeAssets(runtimeAssets:RuntimeAssets):RuntimeAssets {

        if (this.runtimeAssets == runtimeAssets) return runtimeAssets;

        this.runtimeAssets = runtimeAssets;
        computePath();

        return runtimeAssets;

    } //set_runtimeAssets

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

/// Print

    function toString():String {

        var className = className();

        if (path != null && path.trim() != '') {
            return '$className($name $path)';
        } else {
            return '$className($name)';
        }

    } //toString

/// Complete event hook

    inline function willEmitComplete(success:Bool) {

        trace(this + ' willEmitComplete ' + success);

        if (success && owner != null) {
            owner.emitUpdate(this);
        }

    } //willEmitComplete

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

        if (path == null) {
            warning('Cannot load image asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        log('Load image $path');
        app.backend.textures.load(path, {
            premultiplyAlpha: options.premultiplyAlpha ? true : false
        }, function(texture) {

            if (texture != null) {

                var prevTexture = this.texture;
                this.texture = new Texture(texture, density);
                this.texture.id = 'texture:' + path;
                
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

        assets = new Assets();

    } //name

    override public function load() {

        // Create array of assets to destroy after load
        var toDestroy:Array<Asset> = [];
        for (asset in assets) {
            toDestroy.push(asset);
        }

        // Load font data
        status = LOADING;

        if (path == null) {
            warning('Cannot load font asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        log('Load font $path');
        var asset = new TextAsset(name);
        asset.handleTexturesDensityChange = false;
        asset.path = path;
        assets.addAsset(asset);
        assets.onceComplete(this, function(success) {

            var text = asset.text;

            if (text != null) {

                try {
                    fontData = BitmapFontParser.parse(text);

                    // Load pages
                    var pages = new Map();
                    var assetList:Array<ImageAsset> = [];

                    for (page in fontData.pages) {

                        var pathInfo = Assets.decodePath(page.file);
                        var asset = new ImageAsset(pathInfo.name);

                        // Because it is handled at font level
                        asset.handleTexturesDensityChange = false;

                        asset.path = pathInfo.path;
                        assets.addAsset(asset);
                        assetList.push(asset);
                        
                    }

                    assets.onceComplete(this, function(success) {

                        if (success) {
                            // Fill pages mapping
                            for (asset in assetList) {
                                pages.set(asset.path, asset.texture);
                            }

                            // Create bitmap font
                            var prevFont = this.font;
                            this.font = new BitmapFont(fontData, pages);
                            this.font.id = 'font:' + path;

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

                            // Destroy unused assets
                            for (asset in toDestroy) {
                                if (Std.is(asset, ImageAsset)) {
                                    // When it's an image, ensure we don't use it for the updated font, still.
                                    var imageAsset:ImageAsset = cast asset;
                                    if (assetList.indexOf(imageAsset) == -1) {
                                        asset.destroy();
                                    }
                                } else {
                                    asset.destroy();
                                }
                            }

                            status = READY;
                            emitComplete(true);
                            if (handleTexturesDensityChange) {
                                checkTexturesDensity();
                            }

                        }
                        else {
                            status = BROKEN;
                            error('Failed to load textures for font at path: $path');
                            emitComplete(false);
                        }

                    });

                    assets.load();

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

        assets.load();

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

        if (pages != null) {
            for (key in pages.keys()) {
                var texture = pages.get(key);
                texture.destroy();
            }
            pages = null;
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

        if (path == null) {
            warning('Cannot load sound asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        log('Load sound $path');
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

class ShaderAsset extends Asset {

    public var shader:Shader = null;

    override public function new(name:String, ?options:AssetOptions) {

        super('shader', name, options);

    } //name

    override public function load() {

        status = LOADING;

        if (path == null) {
            warning('Cannot load shader asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }
        
        // Compute vertex and fragment shader paths
        if (path != null && (path.toLowerCase().endsWith('.frag') || path.toLowerCase().endsWith('.vert'))) {
            var paths = Assets.allByName.get(name);
            if (options.fragId == null) {
                for (path in paths) {
                    if (path.toLowerCase().endsWith('.frag')) {
                        options.fragId = path;
                        break;
                    }
                }
            }
            if (options.vertId == null) {
                for (path in paths) {
                    if (path.toLowerCase().endsWith('.vert')) {
                        options.vertId = path;
                        break;
                    }
                }
            }

            if (options.fragId != null || options.vertId != null) {
                path = Path.directory(path);
            }

            log('Load shader' + (options.vertId != null ? ' ' + options.vertId : '') + (options.fragId != null ? ' ' + options.fragId : ''));
        }
        else {
            log('Load shader $path');
        }

        app.backend.shaders.load(path, {
            fragId: options.fragId,
            vertId: options.vertId,
            noDefaultUniforms: options.noDefaultUniforms
        }, function(shader) {

            if (shader != null) {
                this.shader = new Shader(shader);
                this.shader.asset = this;
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                error('Failed to load shader at path: $path');
                emitComplete(false);
            }

        });

    } //load

    function destroy():Void {

        if (shader != null) {
            shader.destroy();
            shader = null;
        }

    } //destroy

/// Print

    function toString():String {

        var className = 'ShaderAsset';

        if (options.vertId != null || options.fragId != null) {
            var vertId = options.vertId != null ? options.vertId : 'default';
            var fragId = options.fragId != null ? options.fragId : 'default';
            return '$className($name $vertId $fragId)';
        }
        else if (path != null && path.trim() != '') {
            return '$className($name $path)';
        } else {
            return '$className($name)';
        }

    } //toString

} //ShaderAsset

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
class Fonts {}

#if !macro
@:build(ceramic.macros.AssetsMacro.buildNames('shader'))
#end
class Shaders {}

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

@:structInit
class CustomAssetKind {

    public var kind:String;

    public var add:Assets->String->?AssetOptions->Void;

    public var extensions:Array<String>;

    public var dir:Bool;

} //CustomAssetKind

#if !macro
@:build(ceramic.macros.AssetsMacro.buildLists())
#end
@:allow(ceramic.Asset)
class Assets extends Entity {

/// Events

    @event function complete(success:Bool);

    @event function update(asset:Asset);

/// Properties

    var addedAssets:Array<Asset> = [];

    var assetsByKindAndName:Map<String,Map<String,Asset>> = new Map();

/// Internal

    static var customAssetKinds:Map<String,CustomAssetKind>;

/// Lifecycle

    public function new() {

    } //new

    public function destroy() {

        for (asset in [].concat(addedAssets)) {
            asset.destroy();
        }
        addedAssets = null;
        assetsByKindAndName = null;

    } //destroy

/// Add assets to load

    public function add(id:AssetId<Dynamic>, ?options:AssetOptions):Void {

        var value:String = Std.is(id, String) ? cast id : cast Reflect.field(id, '_id');
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
            case 'shader': addShader(name, options);
            default:
                if (customAssetKinds != null && customAssetKinds.exists(kind)) {
                    customAssetKinds.get(kind).add(this, name, options);
                } else {
                    throw "Assets: invalid asset kind for id: " + id;
                }
        }

    } //add

    public function addImage(name:String, ?options:AssetOptions):Void {

        if (name.startsWith('image:')) name = name.substr(6);
        addAsset(new ImageAsset(name, options));

    } //addTexture

    public function addFont(name:String, ?options:AssetOptions):Void {
        
        if (name.startsWith('font:')) name = name.substr(5);
        addAsset(new FontAsset(name, options));

    } //addFont

    public function addText(name:String, ?options:AssetOptions):Void {
        
        if (name.startsWith('text:')) name = name.substr(5);
        addAsset(new TextAsset(name, options));

    } //addText

    public function addSound(name:String, ?options:AssetOptions):Void {
        
        if (name.startsWith('sound:')) name = name.substr(6);
        addAsset(new SoundAsset(name, options));

    } //addSound

    public function addShader(name:String, ?options:AssetOptions):Void {
        
        if (name.startsWith('shader:')) name = name.substr(7);
        addAsset(new ShaderAsset(name, options));

    } //addShader

    /** Add the given asset. If a previous asset was replaced, return it. */
    public function addAsset(asset:Asset):Asset {

        if (!assetsByKindAndName.exists(asset.kind)) assetsByKindAndName.set(asset.kind, new Map());
        var byName = assetsByKindAndName.get(asset.kind);

        var previousAsset = byName.get(asset.name);
        if (previousAsset != null) {
            if (previousAsset != asset) {
                log('Replace $previousAsset with $asset');
                removeAsset(previousAsset);
            } else {
                warning('Cannot add asset $asset because it is already added for name: ${asset.name}.');
                return previousAsset;
            }
        }

        byName.set(asset.name, asset);
        if (asset.owner != null && asset.owner != this) {
            asset.owner.removeAsset(asset);
        }
        addedAssets.push(asset);
        asset.owner = this;

        return previousAsset;

    } //addAsset
    
    public function asset(idOrName:Either<AssetId<Dynamic>, String>, ?kind:String):Asset {

        var value:String = Std.is(idOrName, String) ? cast idOrName : cast Reflect.field(idOrName, '_id');
        var colonIndex = value.indexOf(':');

        var name:String = value;

        if (colonIndex != -1) {
            name = value.substring(0, colonIndex);
            kind = value.substring(colonIndex + 1);
        }

        if (kind == null) return null;
        var byName = assetsByKindAndName.get(kind);
        if (byName == null) return null;
        return byName.get(name);

    } //asset

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

    public function texture(name:Either<String,AssetId<String>>):Texture {

        var realName:String = cast name;
        if (realName.startsWith('image:')) realName = realName.substr(6);

        if (!assetsByKindAndName.exists('image')) return null;
        var asset:ImageAsset = cast assetsByKindAndName.get('image').get(realName);
        if (asset == null) return null;

        return asset.texture;

    } //texture

    public function font(name:Either<String,AssetId<String>>):BitmapFont {

        var realName:String = cast name;
        if (realName.startsWith('font:')) realName = realName.substr(5);
        
        if (!assetsByKindAndName.exists('font')) return null;
        var asset:FontAsset = cast assetsByKindAndName.get('font').get(realName);
        if (asset == null) return null;

        return asset.font;

    } //font

    public function sound(name:Either<String,AssetId<String>>):Sound {

        var realName:String = cast name;
        if (realName.startsWith('sound:')) realName = realName.substr(6);
        
        if (!assetsByKindAndName.exists('sound')) return null;
        var asset:SoundAsset = cast assetsByKindAndName.get('sound').get(realName);
        if (asset == null) return null;

        return asset.sound;

    } //font

    public function text(name:Either<String,AssetId<String>>):String {

        var realName:String = cast name;
        if (realName.startsWith('text:')) realName = realName.substr(5);
        
        if (!assetsByKindAndName.exists('text')) return null;
        var asset:TextAsset = cast assetsByKindAndName.get('text').get(realName);
        if (asset == null) return null;

        return asset.text;

    } //text

    public function shader(name:Either<String,AssetId<String>>):Shader {

        var realName:String = cast name;
        if (realName.startsWith('shader:')) realName = realName.substr(7);
        
        if (!assetsByKindAndName.exists('shader')) return null;
        var asset:ShaderAsset = cast assetsByKindAndName.get('shader').get(realName);
        if (asset == null) return null;

        return asset.shader;

    } //shader

/// Iterator

    public function iterator():Iterator<Asset> {

        var list:Array<Asset> = [];

        for (byName in assetsByKindAndName) {
            for (asset in byName) {
                list.push(asset);
            }
        }

        return list.iterator();

    } //iterator

/// Static helpers

    public static function decodePath(path:String):AssetPathInfo {

        return new AssetPathInfo(path);

    } //decodePath

    public static function addAssetKind(kind:String, add:Assets->String->?AssetOptions->Void, extensions:Array<String>, dir:Bool = false):Void {

        if (customAssetKinds == null) {
            customAssetKinds = new Map();
        }
        customAssetKinds.set(kind, {
            kind: kind,
            add: add,
            extensions: extensions,
            dir: dir
        });

    } //addAssetKind

} //Assets
