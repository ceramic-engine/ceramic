package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;

using ceramic.Extensions;
using StringTools;

/** A texture is an image ready to be drawn. */
class Texture extends Entity {

/// Internal

    static var _nextIndex:Int = 1;

    @:noCompletion
    public var index:Int = _nextIndex++;

    public var isRenderTexture(default,null):Bool = false;

/// Properties

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

    public function new(backendItem:backend.Texture, density:Float = -1 #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        if (density == -1) density = screen.texturesDensity;

        this.backendItem = backendItem;
        this.density = density; // sets widht/height as well

    } //new

    override function destroy() {

        super.destroy();

        if (asset != null) asset.destroy();

        app.backend.textures.destroyTexture(backendItem);
        backendItem = null;

    } //destroy

/// Print

    override function toString():String {

        if (id != null) {
            var name = id;
            if (name.startsWith('texture:')) name = name.substr(8);
            return 'Texture($name $width $height $density)';
        } else {
            return 'Texture($width $height $density)';
        }

    } //toString

} //Texture
