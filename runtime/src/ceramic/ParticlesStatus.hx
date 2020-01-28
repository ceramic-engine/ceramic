package ceramic;

/** Which status a `Particles` emitter object has. */
enum ParticlesStatus {

    /** Not emitting particles, and no particle is visible. */
    IDLE;

    /** Emitting particles. */
    EMITTING;

    /** Not emitting particles, but previously emitted particles are still spreading */
    SPREADING;

}
