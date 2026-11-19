package ceramic;

import ceramic.Shortcuts.*;

/**
 * A visual container that manages a particle emitter with convenient automatic emission modes.
 *
 * Particles extends Visual to provide a high-level wrapper around ParticleEmitter,
 * adding features like automatic continuous emission and timed burst intervals.
 * This makes it easier to create self-contained particle effects that can be
 * added to the scene and configured with minimal code.
 *
 * The class is generic, allowing use of custom ParticleEmitter subclasses for
 * specialized particle behaviors.
 *
 * Key features:
 * - Automatic continuous emission with `autoEmit`
 * - Automatic burst intervals with `autoExplodeInterval`
 * - Forwards all emitter properties with `emitter*` prefix
 * - Lifecycle management - destroying particles destroys the emitter
 *
 * ```haxe
 * // Create auto-emitting smoke
 * var smoke = new Particles();
 * smoke.autoEmit = true;
 * smoke.emitterInterval = 0.05;
 * smoke.emitterLifespan(0.5, 1.0);
 * smoke.emitterSpeedStart(50, 100);
 * smoke.emitterAlphaEnd(0);
 * scene.add(smoke);
 *
 * // Create periodic explosions
 * var explosions = new Particles();
 * explosions.autoExplodeInterval = 2.0; // Every 2 seconds
 * explosions.autoExplodeQuantity = 50;
 * explosions.emitterSpeedStart(100, 300);
 * scene.add(explosions);
 *
 * // Use custom emitter
 * var custom = new Particles(new MyCustomEmitter());
 * screen.add(custom);
 * ```
 *
 * @see ParticleEmitter The underlying emitter being managed
 * @see ParticleItem Individual particle data
 */
class Particles<T:ParticleEmitter> extends Visual {

    /**
     * The particle emitter managed by this visual.
     *
     * Can be accessed directly for advanced configuration or
     * to call methods like `explode()` and `emitParticle()`.
     * Most common properties are also exposed with `emitter*` prefix.
     */
    @component public var emitter:T;

    /**
     * Creates a new Particles visual with an optional custom emitter.
     *
     * @param emitter Optional custom ParticleEmitter instance or subclass.
     *                If not provided, creates a standard ParticleEmitter.
     */
    public function new(?emitter:T) {

        super();

        if (emitter != null) {
            this.emitter = emitter;
        }
        else {
            this.emitter = cast new ParticleEmitter();
        }

        init();

    }

    /**
     * Initializes the particles system.
     *
     * Sets up lifecycle binding so that destroying the emitter
     * also destroys this visual container.
     */
    function init() {

        // When the emitter is destroyed, visual gets destroyed as well
        emitter.onDestroy(this, _ -> {
            destroy();
        });

    }

    /**
     * Whether to automatically emit particles continuously.
     *
     * When set to true, starts continuous emission using `emitterInterval`.
     * When set to false, stops emission (existing particles continue).
     *
     * Default: false
     *
     * ```haxe
     * particles.emitterInterval = 0.1; // Configure interval first
     * particles.autoEmit = true; // Start emitting
     * ```
     */
    public var autoEmit(default,set):Bool = false;
    function set_autoEmit(autoEmit:Bool):Bool {
        if (this.autoEmit != autoEmit) {
            this.autoEmit = autoEmit;
            if (autoEmit) {
                emitter.emitContinuously(emitterInterval);
            }
            else {
                emitter.stop();
            }
        }
        return autoEmit;
    }

    /**
     * Timer cleanup function for auto-explode intervals.
     */
    var clearExplodeInterval:Void->Void = null;

    /**
     * Interval in seconds between automatic burst emissions.
     *
     * When set to a positive value, triggers burst emissions of
     * `autoExplodeQuantity` particles at regular intervals.
     * Set to -1 to disable automatic bursts.
     *
     * Default: -1 (disabled)
     *
     * ```haxe
     * // Burst 30 particles every 1.5 seconds
     * particles.autoExplodeQuantity = 30;
     * particles.autoExplodeInterval = 1.5;
     * ```
     */
    public var autoExplodeInterval(default,set):Float = -1;
    function set_autoExplodeInterval(autoExplodeInterval:Float):Float {
        if (this.autoExplodeInterval != autoExplodeInterval) {
            this.autoExplodeInterval = autoExplodeInterval;
            computeAutoExplode();
        }
        return autoExplodeInterval;
    }

    /**
     * Number of particles to emit in each automatic burst.
     *
     * Used with `autoExplodeInterval` to create periodic bursts.
     * Only takes effect when `autoExplodeInterval` is positive.
     *
     * Default: 64
     *
     * @see autoExplodeInterval
     */
    public var autoExplodeQuantity(default,set):Int = 64;
    function set_autoExplodeQuantity(autoExplodeQuantity:Int):Int {
        if (this.autoExplodeQuantity != autoExplodeQuantity) {
            this.autoExplodeQuantity = autoExplodeQuantity;
            computeAutoExplode();
        }
        return autoExplodeQuantity;
    }

    /**
     * Updates the automatic explosion timer based on current settings.
     *
     * Clears any existing timer and creates a new one if both
     * interval and quantity are positive.
     */
    function computeAutoExplode() {

        if (clearExplodeInterval != null) {
            clearExplodeInterval();
            clearExplodeInterval = null;
        }

        if (autoExplodeInterval > 0 && autoExplodeQuantity > 0) {
            clearExplodeInterval = Timer.interval(this, autoExplodeInterval, doAutoExplode);
        }

    }

    /**
     * Executes an automatic burst emission.
     *
     * Called by the interval timer to emit the configured
     * quantity of particles.
     */
    function doAutoExplode() {

        emitter.explode(autoExplodeQuantity);

    }

/// Helpers forwarding to emitter

    // The following properties forward to the underlying emitter for convenience.
    // This allows configuring the emitter through the Particles instance without
    // directly accessing the emitter property.

    /**
     * Determines whether the emitter is currently paused. It is totally safe to directly toggle this.
     */
    public var emitterPaused(get,set):Bool;
    inline function get_emitterPaused():Bool return emitter.paused;
    inline function set_emitterPaused(paused:Bool):Bool return emitter.paused = paused;

    /**
     * How often a particle is emitted, if currently emitting.
     * Can be modified at the middle of an emission safely;
     */
    public var emitterInterval(get,set):Float;
    inline function get_emitterInterval():Float return emitter.interval;
    inline function set_emitterInterval(interval:Float):Float return emitter.interval = interval;

    /**
     * How particles should be launched. If `CIRCLE` (default), particles will use `launchAngle` and `speed`.
     * Otherwise, particles will just use `velocityX` and `velocityY`.
     */
    public var emitterLaunchMode(get,set):ParticlesLaunchMode;
    inline function get_emitterLaunchMode():ParticlesLaunchMode return emitter.launchMode;
    inline function set_emitterLaunchMode(launchMode:ParticlesLaunchMode):ParticlesLaunchMode return emitter.launchMode = launchMode;

    /**
     * Keep the scale ratio of the particle. Uses the `scaleX` value for reference.
     */
    public var emitterKeepScaleRatio(get,set):Bool;
    inline function get_emitterKeepScaleRatio():Bool return emitter.keepScaleRatio;
    inline function set_emitterKeepScaleRatio(keepScaleRatio:Bool):Bool return emitter.keepScaleRatio = keepScaleRatio;

    /**
     * Apply particle scale to underlying visual or not.
     */
    public var emitterVisualScaleActive(get,set):Bool;
    inline function get_emitterVisualScaleActive():Bool return emitter.visualScaleActive;
    inline function set_emitterVisualScaleActive(visualScaleActive:Bool):Bool return emitter.visualScaleActive = visualScaleActive;

    /**
     * Apply particle color to underlying visual or not.
     */
    public var emitterVisualColorActive(get,set):Bool;
    inline function get_emitterVisualColorActive():Bool return emitter.visualColorActive;
    inline function set_emitterVisualColorActive(visualColorActive:Bool):Bool return emitter.visualColorActive = visualColorActive;

    /**
     * Apply particle alpha to underlying visual or not.
     */
    public var emitterVisualAlphaActive(get,set):Bool;
    inline function get_emitterVisualAlphaActive():Bool return emitter.visualAlphaActive;
    inline function set_emitterVisualAlphaActive(visualAlphaActive:Bool):Bool return emitter.visualAlphaActive = visualAlphaActive;

    /**
     * Apply particle position (x & y) to underlying visual or not.
     */
    public var emitterVisualPositionActive(get,set):Bool;
    inline function get_emitterVisualPositionActive():Bool return emitter.visualPositionActive;
    inline function set_emitterVisualPositionActive(visualPositionActive:Bool):Bool return emitter.visualPositionActive = visualPositionActive;

    /**
     * Apply particle angle to underlying visual rotation or not.
     */
    public var emitterVisualRotationActive(get,set):Bool;
    inline function get_emitterVisualRotationActive():Bool return emitter.visualRotationActive;
    inline function set_emitterVisualRotationActive(visualRotationActive:Bool):Bool return emitter.visualRotationActive = visualRotationActive;

    /**
     * The width of the emission area.
     * If not defined (`-1`), will use visual's width bound to this `ParticleEmitter` object, if any
     */
    public var emitterWidth(get,set):Float;
    inline function get_emitterWidth():Float return emitter.width;
    inline function set_emitterWidth(width:Float):Float return emitter.width = width;
    /**
     * The height of the emission area.
     * If not defined (`-1`), will use visual's height bound to this `ParticleEmitter` object, if any
     */
    public var emitterHeight(get,set):Float;
    inline function get_emitterHeight():Float return emitter.height;
    inline function set_emitterHeight(height:Float):Float return emitter.height = height;

    /**
     * The x position of the emission, relative to particles parent (if any)
     */
    public var emitterX(get,set):Float;
    inline function get_emitterX():Float return emitter.x;
    inline function set_emitterX(x:Float):Float return emitter.x = x;
    /**
     * The y position of the emission, relative to particles parent (if any)
     */
    public var emitterY(get,set):Float;
    inline function get_emitterY():Float return emitter.y;
    inline function set_emitterY(y:Float):Float return emitter.y = y;

    /**
     * Enable or disable the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var emitterVelocityActive(get,set):Bool;
    inline function get_emitterVelocityActive():Bool return emitter.velocityActive;
    inline function set_emitterVelocityActive(velocityActive:Bool):Bool return emitter.velocityActive = velocityActive;

    /**
     * If you are using `acceleration`, you can use `maxVelocity` with it
     * to cap the speed automatically (very useful!).
     */
    public var emitterMaxVelocityX(get,set):Float;
    inline function get_emitterMaxVelocityX():Float return emitter.maxVelocityX;
    inline function set_emitterMaxVelocityX(maxVelocityX:Float):Float return emitter.maxVelocityX = maxVelocityX;
    /**
     * If you are using `acceleration`, you can use `maxVelocity` with it
     * to cap the speed automatically (very useful!).
     */
    public var emitterMaxVelocityY(get,set):Float;
    inline function get_emitterMaxVelocityY():Float return emitter.maxVelocityY;
    inline function set_emitterMaxVelocityY(maxVelocityY:Float):Float return emitter.maxVelocityY = maxVelocityY;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var emitterVelocityStartMinX(get,set):Float;
    inline function get_emitterVelocityStartMinX():Float return emitter.velocityStartMinX;
    inline function set_emitterVelocityStartMinX(velocityStartMinX:Float):Float return emitter.velocityStartMinX = velocityStartMinX;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var emitterVelocityStartMinY(get,set):Float;
    inline function get_emitterVelocityStartMinY():Float return emitter.velocityStartMinY;
    inline function set_emitterVelocityStartMinY(velocityStartMinY:Float):Float return emitter.velocityStartMinY = velocityStartMinY;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var emitterVelocityStartMaxX(get,set):Float;
    inline function get_emitterVelocityStartMaxX():Float return emitter.velocityStartMaxX;
    inline function set_emitterVelocityStartMaxX(velocityStartMaxX:Float):Float return emitter.velocityStartMaxX = velocityStartMaxX;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var emitterVelocityStartMaxY(get,set):Float;
    inline function get_emitterVelocityStartMaxY():Float return emitter.velocityStartMaxY;
    inline function set_emitterVelocityStartMaxY(velocityStartMaxY:Float):Float return emitter.velocityStartMaxY = velocityStartMaxY;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var emitterVelocityEndMinX(get,set):Float;
    inline function get_emitterVelocityEndMinX():Float return emitter.velocityEndMinX;
    inline function set_emitterVelocityEndMinX(velocityEndMinX:Float):Float return emitter.velocityEndMinX = velocityEndMinX;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var emitterVelocityEndMinY(get,set):Float;
    inline function get_emitterVelocityEndMinY():Float return emitter.velocityEndMinY;
    inline function set_emitterVelocityEndMinY(velocityEndMinY:Float):Float return emitter.velocityEndMinY = velocityEndMinY;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var emitterVelocityEndMaxX(get,set):Float;
    inline function get_emitterVelocityEndMaxX():Float return emitter.velocityEndMaxX;
    inline function set_emitterVelocityEndMaxX(velocityEndMaxX:Float):Float return emitter.velocityEndMaxX = velocityEndMaxX;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var emitterVelocityEndMaxY(get,set):Float;
    inline function get_emitterVelocityEndMaxY():Float return emitter.velocityEndMaxY;
    inline function set_emitterVelocityEndMaxY(velocityEndMaxY:Float):Float return emitter.velocityEndMaxY = velocityEndMaxY;

    /**
     * Set the speed range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    public var emitterSpeedStartMin(get,set):Float;
    inline function get_emitterSpeedStartMin():Float return emitter.speedStartMin;
    inline function set_emitterSpeedStartMin(speedStartMin:Float):Float return emitter.speedStartMin = speedStartMin;
    /**
     * Set the speed range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    public var emitterSpeedStartMax(get,set):Float;
    inline function get_emitterSpeedStartMax():Float return emitter.speedStartMax;
    inline function set_emitterSpeedStartMax(speedStartMax:Float):Float return emitter.speedStartMax = speedStartMax;

    /**
     * Set the speed range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    public var emitterSpeedEndMin(get,set):Float;
    inline function get_emitterSpeedEndMin():Float return emitter.speedEndMin;
    inline function set_emitterSpeedEndMin(speedEndMin:Float):Float return emitter.speedEndMin = speedEndMin;
    /**
     * Set the speed range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    public var emitterSpeedEndMax(get,set):Float;
    inline function get_emitterSpeedEndMax():Float return emitter.speedEndMax;
    inline function set_emitterSpeedEndMax(speedEndMax:Float):Float return emitter.speedEndMax = speedEndMax;

    /**
     * Use in conjunction with angularAcceleration for fluid spin speed control.
     */
    public var emitterMaxAngularVelocity(get,set):Float;
    inline function get_emitterMaxAngularVelocity():Float return emitter.maxAngularVelocity;
    inline function set_emitterMaxAngularVelocity(maxAngularVelocity:Float):Float return emitter.maxAngularVelocity = maxAngularVelocity;
    /**
     * Enable or disable the angular acceleration range of particles launched from this emitter.
     */
    public var emitterAngularAccelerationActive(get,set):Bool;
    inline function get_emitterAngularAccelerationActive():Bool return emitter.angularAccelerationActive;
    inline function set_emitterAngularAccelerationActive(angularAccelerationActive:Bool):Bool return emitter.angularAccelerationActive = angularAccelerationActive;

    /**
     * Set the angular acceleration range of particles launched from this emitter.
     */
    public var emitterAngularAccelerationStartMin(get,set):Float;
    inline function get_emitterAngularAccelerationStartMin():Float return emitter.angularAccelerationStartMin;
    inline function set_emitterAngularAccelerationStartMin(angularAccelerationStartMin:Float):Float return emitter.angularAccelerationStartMin = angularAccelerationStartMin;
    /**
     * Set the angular acceleration range of particles launched from this emitter.
     */
    public var emitterAngularAccelerationStartMax(get,set):Float;
    inline function get_emitterAngularAccelerationStartMax():Float return emitter.angularAccelerationStartMax;
    inline function set_emitterAngularAccelerationStartMax(angularAccelerationStartMax:Float):Float return emitter.angularAccelerationStartMax = angularAccelerationStartMax;

    /**
     * Enable or disable the angular drag range of particles launched from this emitter.
     */
    public var emitterAngularDragActive(get,set):Bool;
    inline function get_emitterAngularDragActive():Bool return emitter.angularDragActive;
    inline function set_emitterAngularDragActive(angularDragActive:Bool):Bool return emitter.angularDragActive = angularDragActive;

    /**
     * Set the angular drag range of particles launched from this emitter.
     */
    public var emitterAngularDragStartMin(get,set):Float;
    inline function get_emitterAngularDragStartMin():Float return emitter.angularDragStartMin;
    inline function set_emitterAngularDragStartMin(angularDragStartMin:Float):Float return emitter.angularDragStartMin = angularDragStartMin;
    /**
     * Set the angular drag range of particles launched from this emitter.
     */
    public var emitterAngularDragStartMax(get,set):Float;
    inline function get_emitterAngularDragStartMax():Float return emitter.angularDragStartMax;
    inline function set_emitterAngularDragStartMax(angularDragStartMax:Float):Float return emitter.angularDragStartMax = angularDragStartMax;

    /**
     * Enable or disable the angular velocity range of particles launched from this emitter.
     */
    public var emitterAngularVelocityActive(get,set):Bool;
    inline function get_emitterAngularVelocityActive():Bool return emitter.angularVelocityActive;
    inline function set_emitterAngularVelocityActive(angularVelocityActive:Bool):Bool return emitter.angularVelocityActive = angularVelocityActive;

    /**
     * The angular velocity range of particles launched from this emitter.
     */
    public var emitterAngularVelocityStartMin(get,set):Float;
    inline function get_emitterAngularVelocityStartMin():Float return emitter.angularVelocityStartMin;
    inline function set_emitterAngularVelocityStartMin(angularVelocityStartMin:Float):Float return emitter.angularVelocityStartMin = angularVelocityStartMin;
    /**
     * The angular velocity range of particles launched from this emitter.
     */
    public var emitterAngularVelocityStartMax(get,set):Float;
    inline function get_emitterAngularVelocityStartMax():Float return emitter.angularVelocityStartMax;
    inline function set_emitterAngularVelocityStartMax(angularVelocityStartMax:Float):Float return emitter.angularVelocityStartMax = angularVelocityStartMax;

    /**
     * The angular velocity range of particles launched from this emitter.
     */
    public var emitterAngularVelocityEndMin(get,set):Float;
    inline function get_emitterAngularVelocityEndMin():Float return emitter.angularVelocityEndMin;
    inline function set_emitterAngularVelocityEndMin(angularVelocityEndMin:Float):Float return emitter.angularVelocityEndMin = angularVelocityEndMin;
    /**
     * The angular velocity range of particles launched from this emitter.
     */
    public var emitterAngularVelocityEndMax(get,set):Float;
    inline function get_emitterAngularVelocityEndMax():Float return emitter.angularVelocityEndMax;
    inline function set_emitterAngularVelocityEndMax(angularVelocityEndMax:Float):Float return emitter.angularVelocityEndMax = angularVelocityEndMax;

    /**
     * Enable or disable the angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    public var emitterAngleActive(get,set):Bool;
    inline function get_emitterAngleActive():Bool return emitter.angleActive;
    inline function set_emitterAngleActive(angleActive:Bool):Bool return emitter.angleActive = angleActive;

    /**
     * The angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    public var emitterAngleStartMin(get,set):Float;
    inline function get_emitterAngleStartMin():Float return emitter.angleStartMin;
    inline function set_emitterAngleStartMin(angleStartMin:Float):Float return emitter.angleStartMin = angleStartMin;
    /**
     * The angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    public var emitterAngleStartMax(get,set):Float;
    inline function get_emitterAngleStartMax():Float return emitter.angleStartMax;
    inline function set_emitterAngleStartMax(angleStartMax:Float):Float return emitter.angleStartMax = angleStartMax;

    /**
     * The angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    public var emitterAngleEndMin(get,set):Float;
    inline function get_emitterAngleEndMin():Float return emitter.angleEndMin;
    inline function set_emitterAngleEndMin(angleEndMin:Float):Float return emitter.angleEndMin = angleEndMin;
    /**
     * The angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    public var emitterAngleEndMax(get,set):Float;
    inline function get_emitterAngleEndMax():Float return emitter.angleEndMax;
    inline function set_emitterAngleEndMax(angleEndMax:Float):Float return emitter.angleEndMax = angleEndMax;

    /**
     * Set this if you want to specify the beginning and ending value of angle,
     * instead of using `angularVelocity` (or `angularAcceleration`).
     */
    public var emitterIgnoreAngularVelocity(get,set):Bool;
    inline function get_emitterIgnoreAngularVelocity():Bool return emitter.ignoreAngularVelocity;
    inline function set_emitterIgnoreAngularVelocity(ignoreAngularVelocity:Bool):Bool return emitter.ignoreAngularVelocity = ignoreAngularVelocity;

    /**
     * Enable or disable the angle range at which particles will be launched from this emitter.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    public var emitterLaunchAngleActive(get,set):Bool;
    inline function get_emitterLaunchAngleActive():Bool return emitter.launchAngleActive;
    inline function set_emitterLaunchAngleActive(launchAngleActive:Bool):Bool return emitter.launchAngleActive = launchAngleActive;

    /**
     * The angle range at which particles will be launched from this emitter.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    public var emitterLaunchAngleMin(get,set):Float;
    inline function get_emitterLaunchAngleMin():Float return emitter.launchAngleMin;
    inline function set_emitterLaunchAngleMin(launchAngleMin:Float):Float return emitter.launchAngleMin = launchAngleMin;
    /**
     * The angle range at which particles will be launched from this emitter.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    public var emitterLaunchAngleMax(get,set):Float;
    inline function get_emitterLaunchAngleMax():Float return emitter.launchAngleMax;
    inline function set_emitterLaunchAngleMax(launchAngleMax:Float):Float return emitter.launchAngleMax = launchAngleMax;

    /**
     * Enable or disable the life, or duration, range of particles launched from this emitter.
     */
    public var emitterLifespanActive(get,set):Bool;
    inline function get_emitterLifespanActive():Bool return emitter.lifespanActive;
    inline function set_emitterLifespanActive(lifespanActive:Bool):Bool return emitter.lifespanActive = lifespanActive;

    /**
     * The life, or duration, range of particles launched from this emitter.
     */
    public var emitterLifespanMin(get,set):Float;
    inline function get_emitterLifespanMin():Float return emitter.lifespanMin;
    inline function set_emitterLifespanMin(lifespanMin:Float):Float return emitter.lifespanMin = lifespanMin;
    /**
     * The life, or duration, range of particles launched from this emitter.
     */
    public var emitterLifespanMax(get,set):Float;
    inline function get_emitterLifespanMax():Float return emitter.lifespanMax;
    inline function set_emitterLifespanMax(lifespanMax:Float):Float return emitter.lifespanMax = lifespanMax;

    /**
     * Enable or disable `scale` range of particles launched from this emitter.
     */
    public var emitterScaleActive(get,set):Bool;
    inline function get_emitterScaleActive():Bool return emitter.scaleActive;
    inline function set_emitterScaleActive(scaleActive:Bool):Bool return emitter.scaleActive = scaleActive;

    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var emitterScaleStartMinX(get,set):Float;
    inline function get_emitterScaleStartMinX():Float return emitter.scaleStartMinX;
    inline function set_emitterScaleStartMinX(scaleStartMinX:Float):Float return emitter.scaleStartMinX = scaleStartMinX;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var emitterScaleStartMinY(get,set):Float;
    inline function get_emitterScaleStartMinY():Float return emitter.scaleStartMinY;
    inline function set_emitterScaleStartMinY(scaleStartMinY:Float):Float return emitter.scaleStartMinY = scaleStartMinY;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var emitterScaleStartMaxX(get,set):Float;
    inline function get_emitterScaleStartMaxX():Float return emitter.scaleStartMaxX;
    inline function set_emitterScaleStartMaxX(scaleStartMaxX:Float):Float return emitter.scaleStartMaxX = scaleStartMaxX;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var emitterScaleStartMaxY(get,set):Float;
    inline function get_emitterScaleStartMaxY():Float return emitter.scaleStartMaxY;
    inline function set_emitterScaleStartMaxY(scaleStartMaxY:Float):Float return emitter.scaleStartMaxY = scaleStartMaxY;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var emitterScaleEndMinX(get,set):Float;
    inline function get_emitterScaleEndMinX():Float return emitter.scaleEndMinX;
    inline function set_emitterScaleEndMinX(scaleEndMinX:Float):Float return emitter.scaleEndMinX = scaleEndMinX;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var emitterScaleEndMinY(get,set):Float;
    inline function get_emitterScaleEndMinY():Float return emitter.scaleEndMinY;
    inline function set_emitterScaleEndMinY(scaleEndMinY:Float):Float return emitter.scaleEndMinY = scaleEndMinY;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var emitterScaleEndMaxX(get,set):Float;
    inline function get_emitterScaleEndMaxX():Float return emitter.scaleEndMaxX;
    inline function set_emitterScaleEndMaxX(scaleEndMaxX:Float):Float return emitter.scaleEndMaxX = scaleEndMaxX;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var emitterScaleEndMaxY(get,set):Float;
    inline function get_emitterScaleEndMaxY():Float return emitter.scaleEndMaxY;
    inline function set_emitterScaleEndMaxY(scaleEndMaxY:Float):Float return emitter.scaleEndMaxY = scaleEndMaxY;

    /**
     * Enable or disable `alpha` range of particles launched from this emitter.
     */
    public var emitterAlphaActive(get,set):Bool;
    inline function get_emitterAlphaActive():Bool return emitter.alphaActive;
    inline function set_emitterAlphaActive(alphaActive:Bool):Bool return emitter.alphaActive = alphaActive;

    /**
     * Sets `alpha` range of particles launched from this emitter.
     */
    public var emitterAlphaStartMin(get,set):Float;
    inline function get_emitterAlphaStartMin():Float return emitter.alphaStartMin;
    inline function set_emitterAlphaStartMin(alphaStartMin:Float):Float return emitter.alphaStartMin = alphaStartMin;
    /**
     * Sets `alpha` range of particles launched from this emitter.
     */
    public var emitterAlphaStartMax(get,set):Float;
    inline function get_emitterAlphaStartMax():Float return emitter.alphaStartMax;
    inline function set_emitterAlphaStartMax(alphaStartMax:Float):Float return emitter.alphaStartMax = alphaStartMax;

    /**
     * Sets `alpha` range of particles launched from this emitter.
     */
    public var emitterAlphaEndMin(get,set):Float;
    inline function get_emitterAlphaEndMin():Float return emitter.alphaEndMin;
    inline function set_emitterAlphaEndMin(alphaEndMin:Float):Float return emitter.alphaEndMin = alphaEndMin;
    /**
     * Sets `alpha` range of particles launched from this emitter.
     */
    public var emitterAlphaEndMax(get,set):Float;
    inline function get_emitterAlphaEndMax():Float return emitter.alphaEndMax;
    inline function set_emitterAlphaEndMax(alphaEndMax:Float):Float return emitter.alphaEndMax = alphaEndMax;

    /**
     * Enable or disable `color` range of particles launched from this emitter.
     */
    public var emitterColorActive(get,set):Bool;
    inline function get_emitterColorActive():Bool return emitter.colorActive;
    inline function set_emitterColorActive(colorActive:Bool):Bool return emitter.colorActive = colorActive;

    /**
     * Sets `color` range of particles launched from this emitter.
     */
    public var emitterColorStartMin(get,set):Color;
    inline function get_emitterColorStartMin():Color return emitter.colorStartMin;
    inline function set_emitterColorStartMin(colorStartMin:Color):Color return emitter.colorStartMin = colorStartMin;
    /**
     * Sets `color` range of particles launched from this emitter.
     */
    public var emitterColorStartMax(get,set):Color;
    inline function get_emitterColorStartMax():Color return emitter.colorStartMax;
    inline function set_emitterColorStartMax(colorStartMax:Color):Color return emitter.colorStartMax = colorStartMax;

    /**
     * Sets `color` range of particles launched from this emitter.
     */
    public var emitterColorEndMin(get,set):Color;
    inline function get_emitterColorEndMin():Color return emitter.colorEndMin;
    inline function set_emitterColorEndMin(colorEndMin:Color):Color return emitter.colorEndMin = colorEndMin;
    /**
     * Sets `color` range of particles launched from this emitter.
     */
    public var emitterColorEndMax(get,set):Color;
    inline function get_emitterColorEndMax():Color return emitter.colorEndMax;
    inline function set_emitterColorEndMax(colorEndMax:Color):Color return emitter.colorEndMax = colorEndMax;

    /**
     * Enable or disable X and Y drag component of particles launched from this emitter.
     */
    public var emitterDragActive(get,set):Bool;
    inline function get_emitterDragActive():Bool return emitter.dragActive;
    inline function set_emitterDragActive(dragActive:Bool):Bool return emitter.dragActive = dragActive;

    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var emitterDragStartMinX(get,set):Float;
    inline function get_emitterDragStartMinX():Float return emitter.dragStartMinX;
    inline function set_emitterDragStartMinX(dragStartMinX:Float):Float return emitter.dragStartMinX = dragStartMinX;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var emitterDragStartMinY(get,set):Float;
    inline function get_emitterDragStartMinY():Float return emitter.dragStartMinY;
    inline function set_emitterDragStartMinY(dragStartMinY:Float):Float return emitter.dragStartMinY = dragStartMinY;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var emitterDragStartMaxX(get,set):Float;
    inline function get_emitterDragStartMaxX():Float return emitter.dragStartMaxX;
    inline function set_emitterDragStartMaxX(dragStartMaxX:Float):Float return emitter.dragStartMaxX = dragStartMaxX;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var emitterDragStartMaxY(get,set):Float;
    inline function get_emitterDragStartMaxY():Float return emitter.dragStartMaxY;
    inline function set_emitterDragStartMaxY(dragStartMaxY:Float):Float return emitter.dragStartMaxY = dragStartMaxY;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var emitterDragEndMinX(get,set):Float;
    inline function get_emitterDragEndMinX():Float return emitter.dragEndMinX;
    inline function set_emitterDragEndMinX(dragEndMinX:Float):Float return emitter.dragEndMinX = dragEndMinX;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var emitterDragEndMinY(get,set):Float;
    inline function get_emitterDragEndMinY():Float return emitter.dragEndMinY;
    inline function set_emitterDragEndMinY(dragEndMinY:Float):Float return emitter.dragEndMinY = dragEndMinY;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var emitterDragEndMaxX(get,set):Float;
    inline function get_emitterDragEndMaxX():Float return emitter.dragEndMaxX;
    inline function set_emitterDragEndMaxX(dragEndMaxX:Float):Float return emitter.dragEndMaxX = dragEndMaxX;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var emitterDragEndMaxY(get,set):Float;
    inline function get_emitterDragEndMaxY():Float return emitter.dragEndMaxY;
    inline function set_emitterDragEndMaxY(dragEndMaxY:Float):Float return emitter.dragEndMaxY = dragEndMaxY;

    /**
     * Enable or disable the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var emitterAccelerationActive(get,set):Bool;
    inline function get_emitterAccelerationActive():Bool return emitter.accelerationActive;
    inline function set_emitterAccelerationActive(accelerationActive:Bool):Bool return emitter.accelerationActive = accelerationActive;

    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var emitterAccelerationStartMinX(get,set):Float;
    inline function get_emitterAccelerationStartMinX():Float return emitter.accelerationStartMinX;
    inline function set_emitterAccelerationStartMinX(accelerationStartMinX:Float):Float return emitter.accelerationStartMinX = accelerationStartMinX;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var emitterAccelerationStartMinY(get,set):Float;
    inline function get_emitterAccelerationStartMinY():Float return emitter.accelerationStartMinY;
    inline function set_emitterAccelerationStartMinY(accelerationStartMinY:Float):Float return emitter.accelerationStartMinY = accelerationStartMinY;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var emitterAccelerationStartMaxX(get,set):Float;
    inline function get_emitterAccelerationStartMaxX():Float return emitter.accelerationStartMaxX;
    inline function set_emitterAccelerationStartMaxX(accelerationStartMaxX:Float):Float return emitter.accelerationStartMaxX = accelerationStartMaxX;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var emitterAccelerationStartMaxY(get,set):Float;
    inline function get_emitterAccelerationStartMaxY():Float return emitter.accelerationStartMaxY;
    inline function set_emitterAccelerationStartMaxY(accelerationStartMaxY:Float):Float return emitter.accelerationStartMaxY = accelerationStartMaxY;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var emitterAccelerationEndMinX(get,set):Float;
    inline function get_emitterAccelerationEndMinX():Float return emitter.accelerationEndMinX;
    inline function set_emitterAccelerationEndMinX(accelerationEndMinX:Float):Float return emitter.accelerationEndMinX = accelerationEndMinX;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var emitterAccelerationEndMinY(get,set):Float;
    inline function get_emitterAccelerationEndMinY():Float return emitter.accelerationEndMinY;
    inline function set_emitterAccelerationEndMinY(accelerationEndMinY:Float):Float return emitter.accelerationEndMinY = accelerationEndMinY;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var emitterAccelerationEndMaxX(get,set):Float;
    inline function get_emitterAccelerationEndMaxX():Float return emitter.accelerationEndMaxX;
    inline function set_emitterAccelerationEndMaxX(accelerationEndMaxX:Float):Float return emitter.accelerationEndMaxX = accelerationEndMaxX;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var emitterAccelerationEndMaxY(get,set):Float;
    inline function get_emitterAccelerationEndMaxY():Float return emitter.accelerationEndMaxY;
    inline function set_emitterAccelerationEndMaxY(accelerationEndMaxY:Float):Float return emitter.accelerationEndMaxY = accelerationEndMaxY;

/// Configuration shorthands

    /**
     * The width and height of the emission area.
     * If not defined (`-1`), will use visual's width and height bound to this `ParticleEmitter` object, if any
     */
    inline public function emitterSize(width:Float, height:Float):Void {
        emitter.size(width, height);
    }

    /**
     * The x and y position of the emission, relative to particles parent (if any)
     */
    inline public function emitterPos(x:Float, y:Float):Void {
        emitter.pos(x, y);
    }

    /**
     * If you are using `acceleration`, you can use `maxVelocity` with it
     * to cap the speed automatically (very useful!).
     */
    inline public function emitterMaxVelocity(maxVelocityX:Float, maxVelocityY:Float):Void {
        emitter.maxVelocity(maxVelocityX, maxVelocityY);
    }

    /**
     * Sets the velocity starting range of particles launched from this emitter. Only used with `SQUARE`.
     */
    inline public function emitterVelocityStart(startMinX:Float, startMinY:Float, ?startMaxX:Float, ?startMaxY:Float):Void {
        emitter.velocityStart(startMinX, startMinY, startMaxX, startMaxY);
    }

    /**
     * Sets the velocity ending range of particles launched from this emitter. Only used with `SQUARE`.
     */
    inline public function emitterVelocityEnd(endMinX:Float, endMinY:Float, ?endMaxX:Float, ?endMaxY:Float):Void {
        emitter.velocityEnd(endMinX, endMinY, endMaxX, endMaxY);
    }

    /**
     * Set the speed starting range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    inline public function emitterSpeedStart(startMin:Float, ?startMax:Float):Void {
        emitter.speedStart(startMin, startMax);
    }

    /**
     * Set the speed ending range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    inline public function emitterSpeedEnd(endMin:Float, ?endMax:Float):Void {
        emitter.speedEnd(endMin, endMax);
    }

    /**
     * Set the angular acceleration range of particles launched from this emitter.
     */
    inline public function emitterAngularAcceleration(startMin:Float, startMax:Float):Void {
        emitter.angularAcceleration(startMin, startMax);
    }

    /**
     * Set the angular drag range of particles launched from this emitter.
     */
    inline public function emitterAngularDrag(startMin:Float, startMax:Float):Void {
        emitter.angularDrag(startMin, startMax);
    }

    /**
     * The angular velocity starting range of particles launched from this emitter.
     */
    inline public function emitterAngularVelocityStart(startMin:Float, ?startMax:Float):Void {
        emitter.angularVelocityStart(startMin, startMax);
    }

    /**
     * The angular velocity ending range of particles launched from this emitter.
     */
    inline public function emitterAngularVelocityEnd(endMin:Float, ?endMax:Float):Void {
        emitter.angularVelocityEnd(endMin, endMax);
    }

    /**
     * The angle starting range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    inline public function emitterAngleStart(startMin:Float, ?startMax:Float):Void {
        emitter.angleStart(startMin, startMax);
    }

    /**
     * The angle ending range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    inline public function emitterAngleEnd(endMin:Float, ?endMax:Float):Void {
        emitter.angleEnd(endMin, endMax);
    }

    /**
     * The angle range at which particles will be launched from this emitter.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    inline public function emitterLaunchAngle(min:Float, max:Float):Void {
        emitter.launchAngle(min, max);
    }

    /**
     * The life, or duration, range of particles launched from this emitter.
     */
    inline public function emitterLifespan(min:Float, max:Float):Void {
        emitter.lifespan(min, max);
    }

    /**
     * Sets `scale` starting range of particles launched from this emitter.
     */
    inline public function emitterScaleStart(startMinX:Float, startMinY:Float, ?startMaxX:Float, ?startMaxY:Float):Void {
        emitter.scaleStart(startMinX, startMinY, startMaxX, startMaxY);
    }

    /**
     * Sets `scale` ending range of particles launched from this emitter.
     */
    inline public function emitterScaleEnd(endMinX:Float, endMinY:Float, ?endMaxX:Float, ?endMaxY:Float):Void {
        emitter.scaleEnd(endMinX, endMinY, endMaxX, endMaxY);
    }

    /**
     * Sets `acceleration` starting range of particles launched from this emitter.
     */
    inline public function emitterAccelerationStart(startMinX:Float, startMinY:Float, ?startMaxX:Float, ?startMaxY:Float):Void {
        emitter.accelerationStart(startMinX, startMinY, startMaxX, startMaxY);
    }

    /**
     * Sets `acceleration` ending range of particles launched from this emitter.
     */
    inline public function emitterAccelerationEnd(endMinX:Float, endMinY:Float, ?endMaxX:Float, ?endMaxY:Float):Void {
        emitter.accelerationEnd(endMinX, endMinY, endMaxX, endMaxY);
    }

    /**
     * Sets `drag` starting range of particles launched from this emitter.
     */
    inline public function emitterDragStart(startMinX:Float, startMinY:Float, ?startMaxX:Float, ?startMaxY:Float):Void {
        emitter.dragStart(startMinX, startMinY, startMaxX, startMaxY);
    }

    /**
     * Sets `drag` ending range of particles launched from this emitter.
     */
    inline public function emitterdragEnd(endMinX:Float, endMinY:Float, ?endMaxX:Float, ?endMaxY:Float):Void {
        emitter.dragEnd(endMinX, endMinY, endMaxX, endMaxY);
    }

    /**
     * Sets `color` starting range of particles launched from this emitter.
     */
    inline public function emitterColorStart(startMin:Color, ?startMax:Color):Void {
        emitter.colorStart(startMin, startMax);
    }

    /**
     * Sets `color` ending range of particles launched from this emitter.
     */
    inline public function emitterColorEnd(endMin:Color, ?endMax:Color):Void {
        emitter.colorEnd(endMin, endMax);
    }

    /**
     * Sets `alpha` starting range of particles launched from this emitter.
     */
    inline public function emitterAlphaStart(startMin:Float, ?startMax:Float):Void {
        emitter.alphaStart(startMin, startMax);
    }

    /**
     * Sets `alpha` ending range of particles launched from this emitter.
     */
    inline public function emitterAlphaEnd(endMin:Float, ?endMax:Float):Void {
        emitter.alphaEnd(endMin, endMax);
    }

    // Note: The emitter* properties and methods above provide convenient access to
    // the underlying ParticleEmitter configuration. They forward directly to the
    // emitter instance, allowing you to configure particles without accessing
    // the emitter property directly. For properties not exposed here, access
    // the emitter directly: particles.emitter.someProperty

}