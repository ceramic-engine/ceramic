package ceramic;

/**
 * How particles should be launched. If `CIRCLE`, particles will use `launchAngle` and `speed`.
 * Otherwise, particles will just use `velocityX` and `velocityY`.
 */
enum ParticlesLaunchMode {

    /**
     * Particles will use `launchAngle` and `speed` to be launched
     */
    CIRCLE;

    /**
     * Particles will use `velocityX` and `velocityY` to be launched
     */
    SQUARE;

}
