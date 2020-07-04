package ceramic;

@:structInit
class TimelineFloatArrayKeyframe extends TimelineKeyframe {

    public var value:Array<Float>;

    public function new(value:Array<Float>, time:Float, easing:Easing) {

        super(time, easing);
        
        this.value = value;

    }

}
