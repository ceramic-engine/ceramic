package ceramic;

import haxe.DynamicAccess;

/**
 * Data structure representing an animation track in serialized form.
 * 
 * This typedef is used for storing and loading timeline track data,
 * typically from fragment files. It defines which entity property to
 * animate and contains all the keyframes for that animation.
 * 
 * At runtime, this data is converted into typed TimelineTrack instances
 * based on the field type:
 * - Bool fields -> TimelineBoolTrack
 * - Float/numeric fields -> TimelineFloatTrack
 * - Color fields -> TimelineColorTrack
 * - Array fields -> TimelineFloatArrayTrack
 * 
 * Example in fragment data:
 * ```json
 * {
 *   "loop": false,
 *   "entity": "mySprite",
 *   "field": "x",
 *   "keyframes": [
 *     { "index": 0, "easing": "LINEAR", "value": 0 },
 *     { "index": 30, "easing": "EASE_OUT", "value": 100 },
 *     { "index": 60, "easing": "BOUNCE_EASE_OUT", "value": 200 }
 *   ]
 * }
 * ```
 * 
 * @see TimelineKeyframeData
 * @see Timeline
 * @see Fragment
 * @see FragmentData
 */
typedef TimelineTrackData = {

    /**
     * Whether this track should loop independently.
     * Note: Usually controlled by the parent timeline's loop setting.
     * Track-level looping is less common.
     */
    var loop:Bool;

    /**
     * The ID of the entity whose property will be animated.
     * Must match an entity ID within the same fragment.
     */
    var entity:String;

    /**
     * The name of the property/field to animate on the target entity.
     * Examples: "x", "y", "rotation", "alpha", "visible", "color"
     */
    var field:String;

    /**
     * Optional track-specific configuration.
     * Can contain custom parameters for specialized track types
     * or plugin-specific animation behaviors.
     */
    @:optional var options:Dynamic<Dynamic>;

    /**
     * Array of keyframes defining the animation.
     * 
     * IMPORTANT: Keyframes must be sorted by frame index in ascending order.
     * Each keyframe specifies a value at a specific time (frame index)
     * and how to interpolate to the next keyframe.
     */
    var keyframes:Array<TimelineKeyframeData>;

}