package ceramic;

/**
 * A keyframe that stores a color value for timeline animations.
 * 
 * Used by TimelineColorTrack to animate color properties over time.
 * Colors are interpolated between keyframes based on the easing function,
 * creating smooth color transitions.
 * 
 * The color interpolation is performed in RGB color space, with each
 * channel (red, green, blue) interpolated independently.
 * 
 * Example usage in a timeline:
 * ```haxe
 * var track = new TimelineColorTrack();
 * track.add(new TimelineColorKeyframe(Color.RED, 0, LINEAR));
 * track.add(new TimelineColorKeyframe(Color.YELLOW, 30, EASE_IN_OUT));
 * track.add(new TimelineColorKeyframe(Color.BLUE, 60, BOUNCE_EASE_OUT));
 * ```
 * 
 * @see TimelineColorTrack
 * @see TimelineKeyframe
 * @see Timeline
 * @see Color
 */
@:structInit
class TimelineColorKeyframe extends TimelineKeyframe {

    /**
     * The color value stored in this keyframe.
     * This color is used as a target for interpolation when animating.
     */
    public var value:Color;

    /**
     * Create a new color keyframe.
     * 
     * @param value The color value for this keyframe
     * @param index The frame index (time position) for this keyframe
     * @param easing The easing function for interpolation to the next keyframe
     */
    public function new(value:Color, index:Int, easing:Easing) {

        super(index, easing);
        
        this.value = value;

    }

}