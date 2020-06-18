package ceramic;

class Particles<T:ParticleEmitter> extends Visual {

    @component public var emitter:T;

    public function new(?emitter:T) {

        super();

        if (emitter != null) {
            this.emitter = emitter;
        }
        else {
            this.emitter = cast new ParticleEmitter();
        }

        // When the emitter is destroyed, visual gets destroyed as well
        emitter.onDestroy(this, _ -> {
            destroy();
        });

    }

}