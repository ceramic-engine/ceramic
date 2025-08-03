package ceramic;

import tracker.Model;

/**
 * Represents a single frame within a sprite animation.
 * Contains the texture region to display and how long to display it.
 * 
 * Frames are the building blocks of animations, each pointing to
 * a specific area of the texture atlas with timing information.
 */
class SpriteSheetFrame extends Model {

    /**
     * Duration to display this frame in seconds.
     * Used during animation playback to determine frame timing.
     */
    @serialize public var duration:Float = 0;

    /**
     * The texture region (sub-rectangle) to display for this frame.
     * Points to a specific area within the texture atlas.
     */
    @serialize public var region:TextureAtlasRegion;

    /**
     * Create a new sprite sheet frame.
     * @param atlas The texture atlas containing the frame
     * @param name Unique name for the texture region
     * @param page Atlas page index (default: 0)
     * @param region Optional pre-existing region to use
     */
    public function new(atlas:TextureAtlas, name:String, page:Int = 0, ?region:TextureAtlasRegion) {
        super();

        if (region != null)
            this.region = region;
        else
            this.region = new TextureAtlasRegion(name, atlas, page);
    }

}
