package ceramic;

@:structInit
class TimelineColorKeyframe extends TimelineKeyframe {

    public var value:Color;

    public function new(value:Color, time:Float, easing:Easing) {

        super(time, easing);
        
        this.value = value;

    }

}
