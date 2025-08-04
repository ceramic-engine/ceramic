package ceramic;

import ase.Ase;
import ase.chunks.LayerChunk;
import ase.chunks.SliceChunk;

/**
 * Data structure containing parsed Aseprite file information.
 * 
 * This class holds all the data extracted from an Aseprite (.ase/.aseprite) file,
 * including frames, layers, tags, slices, and palette information. It manages
 * the texture atlas used to pack frame images and optionally creates sprite sheets
 * for animation playback.
 * 
 * The data is typically created by AsepriteParser and can be used to:
 * - Access individual frames and their pixel data
 * - Create animated sprites using tags
 * - Extract slice information for UI elements
 * - Access layer data for compositing
 * 
 * @see AsepriteParser for loading Aseprite files
 * @see AsepriteFrame for frame data structure
 * @see Sprite for animation playback (when sprite plugin is enabled)
 */
@:structInit
class AsepriteData extends Entity {

    /**
     * The raw Aseprite format file data.
     * Contains low-level file structure information from the ase library.
     */
    public var ase(default, null):Ase;

    /**
     * The color palette extracted from the Aseprite file.
     * For indexed color mode sprites, this defines the available colors.
     * For RGB mode sprites, this may be null or unused.
     */
    public var palette(default, null):AsepritePalette;

    /**
     * Animation tags defined in the Aseprite file.
     * Tags mark frame ranges that can be played as animations.
     * Keys are tag names, values contain frame range and loop information.
     */
    public var tags(default, null):Map<String, AsepriteTag>;

    /**
     * Slices defined in the Aseprite file.
     * Slices mark rectangular regions that can be used for 9-slice scaling
     * or to define UI element boundaries.
     * Keys are slice names, values contain bounds and pivot data.
     */
    public var slices(default, null):Map<String,SliceChunk>;

    /**
     * Layer information from the Aseprite file.
     * Layers are composited together to create the final frames.
     * Array is ordered from bottom to top layer.
     */
    public var layers(default, null):Array<LayerChunk>;

    /**
     * Total duration of the complete animation in seconds.
     * This is the sum of all frame durations in the sprite.
     */
    public var duration(default, null):Float;

    /**
     * Prefix used for naming texture regions in the atlas.
     * Frame regions are named as "prefix#frameNumber".
     * This allows multiple Aseprite files to share the same atlas.
     */
    public var prefix(default, null):String;

    /**
     * All frames extracted from the Aseprite file.
     * Each frame contains the composited image data and timing information.
     * Frames are ordered by frame number (0-based).
     */
    public var frames(default, null):Array<AsepriteFrame>;

    /**
     * The texture atlas packer used to pack frame images.
     * This optimally arranges all frames into texture pages to minimize
     * texture switches during rendering.
     * May be null if frames are not packed into an atlas.
     */
    public var atlasPacker(default, null):TextureAtlasPacker = null;

    /**
     * The texture atlas containing all packed frames.
     * This is a convenience accessor for atlasPacker.atlas.
     * Returns null if frames are not packed into an atlas.
     */
    public var atlas(get, never):TextureAtlas;
    inline function get_atlas():TextureAtlas {
        return atlasPacker != null ? atlasPacker.atlas : null;
    }

    /**
     * The image asset that loaded this Aseprite data.
     * Kept for reference counting and automatic cleanup.
     * May be null if data was created programmatically.
     */
    public var imageAsset:ImageAsset = null;

    #if plugin_sprite

    /**
     * The sprite sheet created from the Aseprite frames.
     * This provides animation playback functionality when the sprite plugin is enabled.
     * Automatically destroyed when the AsepriteData is destroyed.
     */
    @:plugin('sprite')
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
     * The sprite asset that loaded this Aseprite data.
     * Used when the Aseprite file is loaded as a sprite asset.
     * Kept for reference counting and automatic cleanup.
     */
    @:plugin('sprite')
    public var spriteAsset:SpriteAsset = null;

    /**
     * Destroys the sprite sheet if it exists.
     * Ensures the atlas reference is cleared before destruction
     * to prevent double-freeing of texture resources.
     */
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

    /**
     * Destroys this AsepriteData and all associated resources.
     * This includes:
     * - The sprite sheet (if sprite plugin is enabled)
     * - Texture regions in the atlas
     * - Associated sprite and image assets
     */
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
