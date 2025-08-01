package ceramic;

/**
 * Data structure representing a keyframe in serialized form.
 * 
 * This typedef is used for storing and loading keyframe data,
 * typically from fragment files or other data sources. It contains
 * the raw data that gets converted into typed TimelineKeyframe
 * instances at runtime.
 * 
 * The actual keyframe type created depends on the track type and
 * the value's data type:
 * - Bool values -> TimelineBoolKeyframe
 * - Float/Int values -> TimelineFloatKeyframe
 * - Color values -> TimelineColorKeyframe
 * - Arrays -> TimelineFloatArrayKeyframe
 * 
 * Example in fragment data:
 * ```json
 * {
 *   "index": 30,
 *   "easing": "EASE_IN_OUT",
 *   "value": 100.5
 * }
 * ```
 * 
 * @see TimelineTrackData
 * @see TimelineKeyframe
 * @see Fragment
 */
typedef TimelineKeyframeData = {

    /**
     * The frame index (time position) for this keyframe.
     * Represents when this keyframe's value should be reached.
     */
    var index:Int;

    /**
     * The easing function name as a string.
     * Must match one of the Easing enum values (e.g., "LINEAR", "EASE_IN_OUT").
     * Converted to an Easing enum value at runtime.
     */
    var easing:String;

    /**
     * The keyframe value in its raw form.
     * The type depends on what property is being animated:
     * - Bool for boolean tracks
     * - Float/Int for numeric tracks
     * - Color/String for color tracks
     * - Array<Float> for array tracks
     */
    var value:Dynamic;

}