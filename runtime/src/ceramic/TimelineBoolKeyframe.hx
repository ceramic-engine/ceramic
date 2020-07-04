package ceramic;

@:structInit
class TimelineBoolKeyframe extends TimelineKeyframe {

    public var value:Bool;

    public function new(value:Bool, time:Float, easing:Easing) {

        super(time, easing);
        
        this.value = value;

    }

}
