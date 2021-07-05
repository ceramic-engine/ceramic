package ceramic;

import haxe.DynamicAccess;

typedef FragmentData = {

    /**
     * Identifier of the fragment.
     */
    public var id:String;

    /**
     * Arbitrary data hold by this fragment.
     */
    public var data:Dynamic<Dynamic>;

    /**
     * Fragment width
     */
    public var width:Float;

    /**
     * Fragment height
     */
    public var height:Float;

    /**
     * Fragment-level components
     */
    public var components:DynamicAccess<String>;

    /**
     * Timeline tracks
     */
    @:optional public var tracks:Array<TimelineTrackData>;

    /**
     * Timeline labels
     */
    @:optional public var labels:DynamicAccess<Int>;

    /**
     * Frames per second (used in timeline, default is 30).
     * Note that this is only affecting how long a frame in the timeline lasts.
     * Using 30FPS doesn't mean the screen will be rendered at 30FPS.
     * Frame values are interpolated to match screen frame rate.
     */
    @:optional public var fps:Int;

    /**
     * Fragment color (if not transparent, default `BLACK`)
     */
    @:optional public var color:Color;

    /**
     * Fragment being transparent or not (default `true`)
     */
    @:optional public var transparent:Bool;

    /**
     * Whether fragment background overflows (no effect on fragment itself, depends on player implementation)
     */
    @:optional public var overflow:Bool;

    /**
     * Fragment items (visuals or other entities)
     */
    @:optional public var items:Array<FragmentItem>;

}
