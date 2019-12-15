package ceramic;

class AudioMixer extends Entity {

    public var volume:Float = 0.5;

    public var pan:Float = 0;

    public var pitch:Float = 1;

    public var mute:Bool = false;

    public var index:Int;

    @:allow(ceramic.Audio)
    private function new(index:Int) {

        super();

        this.index = index;

    } //new

} //AudioMixer
