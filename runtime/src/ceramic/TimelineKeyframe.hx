package ceramic;

@:structInit
class TimelineKeyframe {

    public var time:Float;

    public var easing:Easing = NONE;

    public function new(time:Float, easing:Easing) {
        
        this.time = time;
        this.easing = easing;

    } //new

} //TimelineKeyframe
