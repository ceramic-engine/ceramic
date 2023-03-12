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
     * The sprite sheet created from the aseprite file
     */
    public var sheet(default, null):SpriteSheet;

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
     * The texture atlas packer used to store frame regions as texture
     */
    public var atlasPacker(default, null):TextureAtlasPacker;

    /**
     * The texture atlas (if any)
     */
    public var atlas(get, never):TextureAtlas;
    inline function get_atlas():TextureAtlas {
        return atlasPacker != null ? atlasPacker.atlas : null;
    }

    /**
     * The asset related to this sprite aseprite data (if any)
     */
    public var asset:SpriteAsset = null;

    override function destroy() {

        if (atlasPacker != null && prefix != null) {
            atlasPacker.removeRegionsWithPrefix(prefix);
        }

        if (asset != null) {
            var _asset = asset;
            asset = null;
            _asset.destroy();
        }

        super.destroy();

    }

}
