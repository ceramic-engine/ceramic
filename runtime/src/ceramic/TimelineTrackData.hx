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
     * Track keyframes. They are expected to be sorted by frame index ascending
     */
    var keyframes:Array<TimelineKeyframeData>;

}
