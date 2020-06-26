package ceramic;

import haxe.DynamicAccess;

typedef TimelineTrackData = {

    var loop:Bool;

    var entity:String;

    var field:String;

    var keyframes:Array<TimelineKeyframeData>;

}
