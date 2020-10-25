package ceramic;

@:structInit
class TimelineColorKeyframe extends TimelineKeyframe {

    public var value:Color;

    public function new(value:Color, index:Int, easing:Easing) {

        super(index, easing);
        
        this.value = value;

    }

}
