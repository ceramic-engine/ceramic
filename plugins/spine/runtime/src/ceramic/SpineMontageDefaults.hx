package ceramic;

@:structInit
class SpineMontageDefaults {

    /**
     * The default skin to use
     */
    public var skin:Null<String> = null;

    /**
     * Whether the animation is looping or not by default (default: `false`)
     */
    public var loop:Bool = false;

    /**
     * The default time scale of the animation.
     * (default: `1.0`, double speed: `2.0`, half speed: `0.5` etc...)
     */
    public var speed:Float = 1;

    /**
     * The default track index to apply the animation on.
     * Leaving it to `0` (default) is on most cases the right choice.
     */
    public var track:Int = 0;

}
