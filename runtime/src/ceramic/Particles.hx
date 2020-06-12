package ceramic;

class Particles extends Visual {

    @component public var emitter:ParticleEmitter;

    public function new(?emitter:ParticleEmitter) {

        super();

        if (emitter != null) {
            this.emitter = emitter;
        }
        else {
            this.emitter = new ParticleEmitter();
        }

        // When the emitter is destroyed, visual gets destroyed as well
        emitter.onDestroy(this, _ -> {
            destroy();
        });

    }

}