package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;
import haxe.io.Bytes;

using StringTools;
using ceramic.Extensions;

/**
 * A texture is an image ready to be drawn.
 */
class Texture extends Entity {

/// Internal

    static var _nextIndex:Int = 1;

    @:noCompletion
    public var index:Int = _nextIndex++;

    public var isRenderTexture(default,null):Bool = false;

    public var asRenderTexture(default,null):RenderTexture = null;

/// Properties

    /**
     * The texture ID used by the underlying backend (OpenGL etc...)
     */
    public var textureId(get,never):backend.TextureId;
    inline function get_textureId():backend.TextureId {
        return app.backend.textures.getTextureId(backendItem);
    }

    /**
     * The native width of the texture, not depending on texture density
     */
    public var nativeWidth(get,never):Int;
    inline function get_nativeWidth():Int {
        return app.backend.textures.getTextureWidth(backendItem);
    }

    /**
     * The native height of the texture, not depending on texture density
     */
    public var nativeHeight(get,never):Int;
    inline function get_nativeHeight():Int {
        return app.backend.textures.getTextureHeight(backendItem);
    }

    /**
     * The native actual width of the texture.
     * Same as native width unless underlying backend needs pot (power of two) sizes.
     */
    public var nativeWidthActual(get,never):Int;
    inline function get_nativeWidthActual():Int {
        return app.backend.textures.getTextureWidthActual(backendItem);
    }

    /**
     * The native actual height of the texture.
     * Same as native height unless underlying backend needs pot (power of two) sizes.
     */
    public var nativeHeightActual(get,never):Int;
    inline function get_nativeHeightActual():Int {
        return app.backend.textures.getTextureHeightActual(backendItem);
    }

    public var width(default,null):Float;

    public var height(default,null):Float;

    public var density(default,set):Float;
    function set_density(density:Float):Float {
        if (this.density == density) return density;
        this.density = density;
        width = app.backend.textures.getTextureWidth(backendItem) / density;
        height = app.backend.textures.getTextureHeight(backendItem) / density;
        return density;
    }

    public var filter(default,set):TextureFilter = LINEAR;
    function set_filter(filter:TextureFilter):TextureFilter {
        if (this.filter == filter) return filter;
        this.filter = filter;
        app.backend.textures.setTextureFilter(backendItem, filter);
        return filter;
    }

    public var backendItem:backend.Texture;

    public var asset:ImageAsset;

/// Lifecycle

    /**
     * Create a new texture from the given pixels buffer
     * @param width Width of the texture
     * @param height Height of the texture
     * @param pixels A pixel buffer in integer RGBA format
     * @param density (optional) density of the texture
     * @return Texture
     */
    public static function fromPixels(width:Float, height:Float, pixels:ceramic.UInt8Array, density:Float = 1):Texture {

        var backendItem = app.backend.textures.createTexture(Math.round(width * density), Math.round(height * density), pixels);
        return new Texture(backendItem, density);

    }

    public function new(backendItem:backend.Texture, density:Float = -1 #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        if (density == -1) density = screen.texturesDensity;

        this.backendItem = backendItem;
        this.density = density; // sets widht/height as well

    }

    override function destroy() {

        super.destroy();

        if (asset != null) asset.destroy();

        app.backend.textures.destroyTexture(backendItem);
        backendItem = null;

    }

/// Pixels

    public function fetchPixels(?result:ceramic.UInt8Array):ceramic.UInt8Array {

        return app.backend.textures.fetchTexturePixels(backendItem, result);

    }

    public function submitPixels(pixels:ceramic.UInt8Array):Void {

        app.backend.textures.submitTexturePixels(backendItem, pixels);

    }

/// PNG

    /**
     * Export texture as PNG data and save it to the given file path
     * @param path The png file path where to save the image (`'/path/to/image.png'`)
     * @param done Called when the png has been exported
     */
    inline extern overload public function toPng(path:String, reversePremultiplyAlpha:Bool = true, done:()->Void):Void {
        _toPng(path, reversePremultiplyAlpha, (?data) -> {
            done();
        });
    }

    /**
     * Export texture to PNG data/bytes
     * @param done Called when the png has been exported, with `data` containing PNG bytes
     */
    inline extern overload public function toPng(reversePremultiplyAlpha:Bool = true, done:(data:Bytes)->Void):Void {
        _toPng(null, reversePremultiplyAlpha, (?data) -> {
            done(data);
        });
    }

    function _toPng(?path:String, reversePremultiplyAlpha:Bool = true, done:(?data:Bytes)->Void):Void {

        app.backend.textures.textureToPng(backendItem, reversePremultiplyAlpha, path, done);

    }

/// Print

    override function toString():String {

        if (id != null) {
            var name = id;
            if (name.startsWith('texture:')) name = name.substr(8);
            return 'Texture($name $width $height $density #$index)';
        } else {
            return 'Texture($width $height $density #$index)';
        }

    }

}
