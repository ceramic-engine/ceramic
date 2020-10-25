package ceramic;

@:structInit
class TimelineFloatKeyframe extends TimelineKeyframe {

    public var value:Float;

    public function new(value:Float, index:Int, easing:Easing) {

        super(index, easing);
        
        this.value = value;

    }

}
