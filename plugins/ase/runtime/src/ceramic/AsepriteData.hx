package ceramic;

import ase.Ase;
import ase.chunks.LayerChunk;
import ase.chunks.SliceChunk;

@:structInit
class AsepriteData extends Entity {

    /**
     * The raw ase format file data
     */
    public var ase(default, null):Ase;

    /**
     * The palette used (on RGB frames, this might not be relevant though)
     */
    public var palette(default, null):AsepritePalette;

    /**
     * Tags extracted from the aseprite file
     */
    public var tags(default, null):Map<String, AsepriteTag>;

    /**
     * Slice extracted from the aseprite file
     */
    public var slices(default, null):Map<String,SliceChunk>;

    /**
     * Layers extracted from the aseprite file
     */
    public var layers(default, null):Array<LayerChunk>;

    /**
     * Total duration of the sprite when combining every frame animation
     */
    public var duration(default, null):Float;

    /**
     * The prefix used to name regions in atlas
     */
    public var prefix(default, null):String;

    /**
     * All frames extracted from the aseprite file
     */
    public var frames(default, null):Array<AsepriteFrame>;

    /**
     * The texture atlas packer used to store frame regions as texture (if any)
     */
    public var atlasPacker(default, null):TextureAtlasPacker = null;

    /**
     * The texture atlas (if any)
     */
    public var atlas(get, never):TextureAtlas;
    inline function get_atlas():TextureAtlas {
        return atlasPacker != null ? atlasPacker.atlas : null;
    }

    /**
     * The image asset related to this aseprite data (if any)
     */
    public var imageAsset:ImageAsset = null;

    #if plugin_sprite

    /**
     * The sprite sheet created from the aseprite file
     */
    public var sheet(default, set):SpriteSheet = null;
    function set_sheet(sheet:SpriteSheet):SpriteSheet {
        if (this.sheet != sheet) {
            if (this.sheet != null) {
                var _sheet = this.sheet;
                sheet = null;
                if (atlasPacker != null && _sheet.atlas == atlasPacker.atlas) {
                    _sheet.atlas = null;
                }
                _sheet.destroy();
            }
        }
        return sheet;
    }

    /**
     * The sprite asset related to this sprite aseprite data (if any)
     */
    public var spriteAsset:SpriteAsset = null;

    function destroySheet() {

        if (sheet != null) {
            var _sheet = sheet;
            sheet = null;
            if (atlasPacker != null && _sheet.atlas == atlasPacker.atlas) {
                _sheet.atlas = null;
            }
            _sheet.destroy();
        }

    }

    #end

    override function destroy() {

        #if plugin_sprite
        destroySheet();
        #end

        if (atlasPacker != null && prefix != null) {
            atlasPacker.removeRegionsWithPrefix(prefix + '#');
        }

        #if plugin_sprite
        if (spriteAsset != null) {
            var _spriteAsset = spriteAsset;
            spriteAsset = null;
            _spriteAsset.destroy();
        }
        #end

        if (imageAsset != null) {
            var _imageAsset = imageAsset;
            imageAsset = null;
            _imageAsset.destroy();
        }

        super.destroy();

    }

}
