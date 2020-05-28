package ceramic;

@:structInit
class SpineMontageAnimation<T> {

    /** The animation to play */
    public var anim:String;

    /** The skin to use */
    public var skin:Null<String> = null;

    /** Whether the animation is looping or not */
    public var loop:Null<Bool> = null;

    /** Start the animation on this given track position relative to track duration
    (`0`: beginning of track, `1`: end of track) */
    public var time:Float = 0;

    /** The time scale of this animation.
    (default: `1.0`, double speed: `2.0`, half speed: `0.5` etc...) */
    public var speed:Float = -1;

    /** The track index to apply the animation on. */
    public var track:Int = -1;

    /** Auto-play an animation after this one has finished. */
    public var next:T = null;

}
