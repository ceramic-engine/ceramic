package ceramic;

@:structInit
class TimelineBoolKeyframe extends TimelineKeyframe {

    public var value:Bool;

    public function new(value:Bool, index:Int, easing:Easing) {

        super(index, easing);
        
        this.value = value;

    }

}
