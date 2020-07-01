package ceramic;

import haxe.DynamicAccess;

typedef TimelineTrackData = {

    /**
     * Whether this track should loop or not
     */
    var loop:Bool;

    /**
     * Entity id this track targets
     */
    var entity:String;

    /**
     * Entity field name this track targets
     */
    var field:String;

    /**
     * Track options
     */
    @:optional var options:Dynamic<Dynamic>;

    /**
     * Track keyframes. They should be sorted by frame index in ascending order
     */
    var keyframes:Array<TimelineKeyframeData>;

}
