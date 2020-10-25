package ceramic;

@:structInit
class TimelineFloatArrayKeyframe extends TimelineKeyframe {

    public var value:Array<Float>;

    public function new(value:Array<Float>, index:Int, easing:Easing) {

        super(index, easing);
        
        this.value = value;

    }

}
