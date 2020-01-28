package ceramic;

class Audio extends Entity {

    @:allow(ceramic.Sound)
    var mixers:IntMap<AudioMixer>;

    @:allow(ceramic.App)
    private function new() {

        super();

        mixers = new IntMap();
        initMixerIfNeeded(0);

    }

    @:allow(ceramic.Sound)
    inline function initMixerIfNeeded(index:Int):Void {

        if (!mixers.exists(index)) {
            mixers.set(index, new AudioMixer(index));
        }

    }

    public function mixer(index:Int):AudioMixer {

        return mixers.getInline(index);

    }

}
