package ceramic;

import tracker.Model;

using ceramic.Extensions;

/**
 * Represents a named animation sequence within a sprite sheet.
 * Contains an ordered list of frames with timing information.
 * 
 * Animations are typically created by:
 * - Parsing from Aseprite JSON frame tags
 * - Using SpriteSheet.addGridAnimation() for grid-based sheets
 * - Manual construction for custom animations
 * 
 * The total duration is computed automatically from all frame durations.
 */
class SpriteSheetAnimation extends Model {

    /**
     * The unique name identifier for this animation.
     * Used to reference the animation when playing sprites.
     */
    @serialize public var name:String = null;

    /**
     * Ordered array of frames that make up this animation.
     * Each frame contains a texture region and duration.
     */
    @serialize public var frames:ReadOnlyArray<SpriteSheetFrame> = null;

    /**
     * Compute the total duration of this animation in seconds.
     * This is the sum of all individual frame durations.
     * @return Total animation duration
     */
    @compute public function duration():Float {

        var result:Float = 0.0;

        var frames = this.frames;
        if (frames != null) {
            for (i in 0...frames.length) {
                result += frames.unsafeGet(i).duration;
            }
        }

        return result;

    }

}
