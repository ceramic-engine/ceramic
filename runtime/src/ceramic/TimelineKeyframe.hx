package ceramic;

@:structInit
class TimelineKeyframe {

    public var index:Int;

    public var easing:Easing = NONE;

    public function new(index:Int, easing:Easing) {
        
        this.index = index;
        this.easing = easing;

    }

}
