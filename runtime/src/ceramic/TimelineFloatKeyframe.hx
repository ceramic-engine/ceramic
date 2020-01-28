package ceramic;

@:structInit
class TimelineFloatKeyframe extends TimelineKeyframe {

    public var value:Float;

    public function new(value:Float, time:Float, easing:Easing) {

        super(time, easing);
        
        this.value = value;

    }

}
