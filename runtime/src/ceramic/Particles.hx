package ceramic;

import ceramic.Shortcuts.*;

#if editor
import editor.Editor.editor;
import tracker.Autorun.unobserve;
#end

@editable
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

        init();

    }

    function init() {

        // When the emitter is destroyed, visual gets destroyed as well
        emitter.onDestroy(this, _ -> {
            destroy();
        });

#if editor
        app.onceImmediate(() -> {
            if (!destroyed && edited) {
                app.onUpdate(this, _ -> {
                    if (emitter != null && emitter.status != IDLE) {
                        editor.requestHighFps();
                    }
                });

                /*
                autorun(() -> {
                    var animating = editor.model.animationState.animating;
                    unobserve();
                    emitter.paused = emitterPaused || !animating;
                });
                */
            }
        });
#end

    }

    @editable({ group: 'emitterInterval' })
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

    var clearExplodeInterval:Void->Void = null;

    @editable({ label: 'Explode Interval', group: 'autoExplode' })
    public var autoExplodeInterval(default,set):Float = -1;
    function set_autoExplodeInterval(autoExplodeInterval:Float):Float {
        if (this.autoExplodeInterval != autoExplodeInterval) {
            this.autoExplodeInterval = autoExplodeInterval;
            computeAutoExplode();
        }
        return autoExplodeInterval;
    }

    @editable({ label: 'Explode Quantity', group: 'autoExplode' })
    public var autoExplodeQuantity(default,set):Int = 64;
    function set_autoExplodeQuantity(autoExplodeQuantity:Int):Int {
        if (this.autoExplodeQuantity != autoExplodeQuantity) {
            this.autoExplodeQuantity = autoExplodeQuantity;
            computeAutoExplode();
        }
        return autoExplodeQuantity;
    }

    function computeAutoExplode() {

        if (clearExplodeInterval != null) {
            clearExplodeInterval();
            clearExplodeInterval = null;
        }

        if (autoExplodeInterval > 0 && autoExplodeQuantity > 0) {
            clearExplodeInterval = Timer.interval(this, autoExplodeInterval, doAutoExplode);
        }

    }

    function doAutoExplode() {

        emitter.explode(autoExplodeQuantity);

    }

/// Helpers forwarding to emitter

    /**
     * Determines whether the emitter is currently paused. It is totally safe to directly toggle this.
     */
    @editable({ label: 'Paused' })
    #if editor
    public var emitterPaused(default,set):Bool;
    function set_emitterPaused(paused:Bool):Bool {
        this.emitterPaused = paused;
        return emitter.paused = paused;// || (edited ? !editor.model.animationState.animating : false);
    }
    #else
    public var emitterPaused(get,set):Bool;
    inline function get_emitterPaused():Bool return emitter.paused;
    inline function set_emitterPaused(paused:Bool):Bool return emitter.paused = paused;
    #end

    /**
     * How often a particle is emitted, if currently emitting.
     * Can be modified at the middle of an emission safely;
     */
    @editable({ label: 'Interval', group: 'emitterInterval' })
    public var emitterInterval(get,set):Float;
    inline function get_emitterInterval():Float return emitter.interval;
    inline function set_emitterInterval(interval:Float):Float return emitter.interval = interval;

    /**
     * How particles should be launched. If `CIRCLE` (default), particles will use `launchAngle` and `speed`.
     * Otherwise, particles will just use `velocityX` and `velocityY`.
     */
    @editable({ label: 'Launch Mode' })
    public var emitterLaunchMode(get,set):ParticlesLaunchMode;
    inline function get_emitterLaunchMode():ParticlesLaunchMode return emitter.launchMode;
    inline function set_emitterLaunchMode(launchMode:ParticlesLaunchMode):ParticlesLaunchMode return emitter.launchMode = launchMode;

    /**
     * Apply particle scale to underlying visual or not.
     */
    @editable({ label: 'Scale Active', group: 'emitterScale' })
    public var emitterVisualScaleActive(get,set):Bool;
    inline function get_emitterVisualScaleActive():Bool return emitter.visualScaleActive;
    inline function set_emitterVisualScaleActive(visualScaleActive:Bool):Bool return emitter.visualScaleActive = visualScaleActive;

    /**
     * Keep the scale ratio of the particle. Uses the `scaleX` value for reference.
     */
    @editable({ label: 'Keep Scale Ratio', group: 'emitterScale' })
    public var emitterKeepScaleRatio(get,set):Bool;
    inline function get_emitterKeepScaleRatio():Bool return emitter.keepScaleRatio;
    inline function set_emitterKeepScaleRatio(keepScaleRatio:Bool):Bool return emitter.keepScaleRatio = keepScaleRatio;

    /**
     * Apply particle color to underlying visual or not.
     */
    @editable({ label: 'Color Active', group: 'emitterColorAlphaActive' })
    public var emitterVisualColorActive(get,set):Bool;
    inline function get_emitterVisualColorActive():Bool return emitter.visualColorActive;
    inline function set_emitterVisualColorActive(visualColorActive:Bool):Bool return emitter.visualColorActive = visualColorActive;

    /**
     * Apply particle alpha to underlying visual or not.
     */
    @editable({ label: 'Alpha Active', group: 'emitterColorAlphaActive' })
    public var emitterVisualAlphaActive(get,set):Bool;
    inline function get_emitterVisualAlphaActive():Bool return emitter.visualAlphaActive;
    inline function set_emitterVisualAlphaActive(visualAlphaActive:Bool):Bool return emitter.visualAlphaActive = visualAlphaActive;

    /**
     * Apply particle position (x & y) to underlying visual or not.
     */
    @editable({ label: 'Position Active', group: 'emitterPosRotationActive' })
    public var emitterVisualPositionActive(get,set):Bool;
    inline function get_emitterVisualPositionActive():Bool return emitter.visualPositionActive;
    inline function set_emitterVisualPositionActive(visualPositionActive:Bool):Bool return emitter.visualPositionActive = visualPositionActive;

    /**
     * Apply particle angle to underlying visual rotation or not.
     */
    @editable({ label: 'Rotation Active', group: 'emitterPosRotationActive' })
    public var emitterVisualRotationActive(get,set):Bool;
    inline function get_emitterVisualRotationActive():Bool return emitter.visualRotationActive;
    inline function set_emitterVisualRotationActive(visualRotationActive:Bool):Bool return emitter.visualRotationActive = visualRotationActive;

    /**
     * The width of the emission area.
     * If not defined (`-1`), will use visual's width bound to this `ParticleEmitter` object, if any
     */
    @editable({ label: 'Emitter Width', group: 'emitterSize' })
    public var emitterWidth(get,set):Float;
    inline function get_emitterWidth():Float return emitter.width;
    inline function set_emitterWidth(width:Float):Float return emitter.width = width;
    /**
     * The height of the emission area.
     * If not defined (`-1`), will use visual's height bound to this `ParticleEmitter` object, if any
     */
    @editable({ label: 'Emitter Height', group: 'emitterSize' })
    public var emitterHeight(get,set):Float;
    inline function get_emitterHeight():Float return emitter.height;
    inline function set_emitterHeight(height:Float):Float return emitter.height = height;

    /**
     * The x position of the emission, relative to particles parent (if any)
     */
    @editable({ label: 'Emitter X', group: 'emitterPos' })
    public var emitterX(get,set):Float;
    inline function get_emitterX():Float return emitter.x;
    inline function set_emitterX(x:Float):Float return emitter.x = x;
    /**
     * The y position of the emission, relative to particles parent (if any)
     */
    @editable({ label: 'Emitter Y', group: 'emitterPos' })
    public var emitterY(get,set):Float;
    inline function get_emitterY():Float return emitter.y;
    inline function set_emitterY(y:Float):Float return emitter.y = y;

    /**
     * Enable or disable the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. Active' })
    public var emitterVelocityActive(get,set):Bool;
    inline function get_emitterVelocityActive():Bool return emitter.velocityActive;
    inline function set_emitterVelocityActive(velocityActive:Bool):Bool return emitter.velocityActive = velocityActive;

    /**
     * If you are using `acceleration`, you can use `maxVelocity` with it
     * to cap the speed automatically (very useful!).
     */
    @editable({ label: 'Max Vel. X', group: 'emitterMaxVelocity' })
    public var emitterMaxVelocityX(get,set):Float;
    inline function get_emitterMaxVelocityX():Float return emitter.maxVelocityX;
    inline function set_emitterMaxVelocityX(maxVelocityX:Float):Float return emitter.maxVelocityX = maxVelocityX;
    /**
     * If you are using `acceleration`, you can use `maxVelocity` with it
     * to cap the speed automatically (very useful!).
     */
    @editable({ label: 'Max Vel. Y', group: 'emitterMaxVelocity' })
    public var emitterMaxVelocityY(get,set):Float;
    inline function get_emitterMaxVelocityY():Float return emitter.maxVelocityY;
    inline function set_emitterMaxVelocityY(maxVelocityY:Float):Float return emitter.maxVelocityY = maxVelocityY;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. Start Min X', group: 'emitterVelocityStartMin' })
    public var emitterVelocityStartMinX(get,set):Float;
    inline function get_emitterVelocityStartMinX():Float return emitter.velocityStartMinX;
    inline function set_emitterVelocityStartMinX(velocityStartMinX:Float):Float return emitter.velocityStartMinX = velocityStartMinX;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. Start Min Y', group: 'emitterVelocityStartMin' })
    public var emitterVelocityStartMinY(get,set):Float;
    inline function get_emitterVelocityStartMinY():Float return emitter.velocityStartMinY;
    inline function set_emitterVelocityStartMinY(velocityStartMinY:Float):Float return emitter.velocityStartMinY = velocityStartMinY;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. Start Max X', group: 'emitterVelocityStartMax' })
    public var emitterVelocityStartMaxX(get,set):Float;
    inline function get_emitterVelocityStartMaxX():Float return emitter.velocityStartMaxX;
    inline function set_emitterVelocityStartMaxX(velocityStartMaxX:Float):Float return emitter.velocityStartMaxX = velocityStartMaxX;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. Start Max Y', group: 'emitterVelocityStartMax' })
    public var emitterVelocityStartMaxY(get,set):Float;
    inline function get_emitterVelocityStartMaxY():Float return emitter.velocityStartMaxY;
    inline function set_emitterVelocityStartMaxY(velocityStartMaxY:Float):Float return emitter.velocityStartMaxY = velocityStartMaxY;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. End Min X', group: 'emitterVelocityEndMin' })
    public var emitterVelocityEndMinX(get,set):Float;
    inline function get_emitterVelocityEndMinX():Float return emitter.velocityEndMinX;
    inline function set_emitterVelocityEndMinX(velocityEndMinX:Float):Float return emitter.velocityEndMinX = velocityEndMinX;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. End Min Y', group: 'emitterVelocityEndMin' })
    public var emitterVelocityEndMinY(get,set):Float;
    inline function get_emitterVelocityEndMinY():Float return emitter.velocityEndMinY;
    inline function set_emitterVelocityEndMinY(velocityEndMinY:Float):Float return emitter.velocityEndMinY = velocityEndMinY;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. End Max X', group: 'emitterVelocityEndMax' })
    public var emitterVelocityEndMaxX(get,set):Float;
    inline function get_emitterVelocityEndMaxX():Float return emitter.velocityEndMaxX;
    inline function set_emitterVelocityEndMaxX(velocityEndMaxX:Float):Float return emitter.velocityEndMaxX = velocityEndMaxX;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. End Max Y', group: 'emitterVelocityEndMax' })
    public var emitterVelocityEndMaxY(get,set):Float;
    inline function get_emitterVelocityEndMaxY():Float return emitter.velocityEndMaxY;
    inline function set_emitterVelocityEndMaxY(velocityEndMaxY:Float):Float return emitter.velocityEndMaxY = velocityEndMaxY;

    /**
     * Set the speed range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    @editable({ label: 'Speed Start Min', group: 'emitterSpeedStart' })
    public var emitterSpeedStartMin(get,set):Float;
    inline function get_emitterSpeedStartMin():Float return emitter.speedStartMin;
    inline function set_emitterSpeedStartMin(speedStartMin:Float):Float return emitter.speedStartMin = speedStartMin;
    /**
     * Set the speed range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    @editable({ label: 'Speed Start Max', group: 'emitterSpeedStart' })
    public var emitterSpeedStartMax(get,set):Float;
    inline function get_emitterSpeedStartMax():Float return emitter.speedStartMax;
    inline function set_emitterSpeedStartMax(speedStartMax:Float):Float return emitter.speedStartMax = speedStartMax;

    /**
     * Set the speed range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    @editable({ label: 'Speed End Min', group: 'emitterSpeedEnd' })
    public var emitterSpeedEndMin(get,set):Float;
    inline function get_emitterSpeedEndMin():Float return emitter.speedEndMin;
    inline function set_emitterSpeedEndMin(speedEndMin:Float):Float return emitter.speedEndMin = speedEndMin;
    /**
     * Set the speed range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    @editable({ label: 'Speed End Max', group: 'emitterSpeedEnd' })
    public var emitterSpeedEndMax(get,set):Float;
    inline function get_emitterSpeedEndMax():Float return emitter.speedEndMax;
    inline function set_emitterSpeedEndMax(speedEndMax:Float):Float return emitter.speedEndMax = speedEndMax;

    /**
     * Use in conjunction with angularAcceleration for fluid spin speed control.
     */
    @editable({ label: 'Max Angular Vel.', group: 'emitterAngularVelocityAcceleration' })
    public var emitterMaxAngularVelocity(get,set):Float;
    inline function get_emitterMaxAngularVelocity():Float return emitter.maxAngularVelocity;
    inline function set_emitterMaxAngularVelocity(maxAngularVelocity:Float):Float return emitter.maxAngularVelocity = maxAngularVelocity;
    /**
     * Enable or disable the angular acceleration range of particles launched from this emitter.
     */
    @editable({ label: 'Angular Accel. Active', group: 'emitterAngularVelocityAcceleration' })
    public var emitterAngularAccelerationActive(get,set):Bool;
    inline function get_emitterAngularAccelerationActive():Bool return emitter.angularAccelerationActive;
    inline function set_emitterAngularAccelerationActive(angularAccelerationActive:Bool):Bool return emitter.angularAccelerationActive = angularAccelerationActive;

    /**
     * Set the angular acceleration range of particles launched from this emitter.
     */
    @editable({ label: 'Angular Accel. Start Min', group: 'emitterAngularAccelerationStart' })
    public var emitterAngularAccelerationStartMin(get,set):Float;
    inline function get_emitterAngularAccelerationStartMin():Float return emitter.angularAccelerationStartMin;
    inline function set_emitterAngularAccelerationStartMin(angularAccelerationStartMin:Float):Float return emitter.angularAccelerationStartMin = angularAccelerationStartMin;
    /**
     * Set the angular acceleration range of particles launched from this emitter.
     */
    @editable({ label: 'Angular Accel. Start Max', group: 'emitterAngularAccelerationStart' })
    public var emitterAngularAccelerationStartMax(get,set):Float;
    inline function get_emitterAngularAccelerationStartMax():Float return emitter.angularAccelerationStartMax;
    inline function set_emitterAngularAccelerationStartMax(angularAccelerationStartMax:Float):Float return emitter.angularAccelerationStartMax = angularAccelerationStartMax;

    /**
     * Enable or disable the angular drag range of particles launched from this emitter.
     */
    @editable({ label: 'Angular Drag Active' })
    public var emitterAngularDragActive(get,set):Bool;
    inline function get_emitterAngularDragActive():Bool return emitter.angularDragActive;
    inline function set_emitterAngularDragActive(angularDragActive:Bool):Bool return emitter.angularDragActive = angularDragActive;

    /**
     * Set the angular drag range of particles launched from this emitter.
     */
    @editable({ label: 'Angular Drag Start Min', group: 'emitterAngularDragStart' })
    public var emitterAngularDragStartMin(get,set):Float;
    inline function get_emitterAngularDragStartMin():Float return emitter.angularDragStartMin;
    inline function set_emitterAngularDragStartMin(angularDragStartMin:Float):Float return emitter.angularDragStartMin = angularDragStartMin;
    /**
     * Set the angular drag range of particles launched from this emitter.
     */
    @editable({ label: 'Angular Drag Start Max', group: 'emitterAngularDragStart' })
    public var emitterAngularDragStartMax(get,set):Float;
    inline function get_emitterAngularDragStartMax():Float return emitter.angularDragStartMax;
    inline function set_emitterAngularDragStartMax(angularDragStartMax:Float):Float return emitter.angularDragStartMax = angularDragStartMax;

    /**
     * Enable or disable the angular velocity range of particles launched from this emitter.
     */
    @editable({ label: 'Angular Vel. Active' })
    public var emitterAngularVelocityActive(get,set):Bool;
    inline function get_emitterAngularVelocityActive():Bool return emitter.angularVelocityActive;
    inline function set_emitterAngularVelocityActive(angularVelocityActive:Bool):Bool return emitter.angularVelocityActive = angularVelocityActive;

    /**
     * The angular velocity range of particles launched from this emitter.
     */
    @editable({ label: 'Angular Vel. Start Min', group: 'emitterAngularVelocityStart' })
    public var emitterAngularVelocityStartMin(get,set):Float;
    inline function get_emitterAngularVelocityStartMin():Float return emitter.angularVelocityStartMin;
    inline function set_emitterAngularVelocityStartMin(angularVelocityStartMin:Float):Float return emitter.angularVelocityStartMin = angularVelocityStartMin;
    /**
     * The angular velocity range of particles launched from this emitter.
     */
    @editable({ label: 'Angular Vel. Start Max', group: 'emitterAngularVelocityStart' })
    public var emitterAngularVelocityStartMax(get,set):Float;
    inline function get_emitterAngularVelocityStartMax():Float return emitter.angularVelocityStartMax;
    inline function set_emitterAngularVelocityStartMax(angularVelocityStartMax:Float):Float return emitter.angularVelocityStartMax = angularVelocityStartMax;

    /**
     * The angular velocity range of particles launched from this emitter.
     */
    @editable({ label: 'Angular Vel. End Min', group: 'emitterAngularVelocityEnd' })
    public var emitterAngularVelocityEndMin(get,set):Float;
    inline function get_emitterAngularVelocityEndMin():Float return emitter.angularVelocityEndMin;
    inline function set_emitterAngularVelocityEndMin(angularVelocityEndMin:Float):Float return emitter.angularVelocityEndMin = angularVelocityEndMin;
    /**
     * The angular velocity range of particles launched from this emitter.
     */
    @editable({ label: 'Angular Vel. End Max', group: 'emitterAngularVelocityEnd' })
    public var emitterAngularVelocityEndMax(get,set):Float;
    inline function get_emitterAngularVelocityEndMax():Float return emitter.angularVelocityEndMax;
    inline function set_emitterAngularVelocityEndMax(angularVelocityEndMax:Float):Float return emitter.angularVelocityEndMax = angularVelocityEndMax;

    /**
     * Enable or disable the angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    @editable({ label: 'Angle Active' })
    public var emitterAngleActive(get,set):Bool;
    inline function get_emitterAngleActive():Bool return emitter.angleActive;
    inline function set_emitterAngleActive(angleActive:Bool):Bool return emitter.angleActive = angleActive;

    /**
     * The angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    @editable({ label: 'Angle Start Min', group: 'emitterAngleStart' })
    public var emitterAngleStartMin(get,set):Float;
    inline function get_emitterAngleStartMin():Float return emitter.angleStartMin;
    inline function set_emitterAngleStartMin(angleStartMin:Float):Float return emitter.angleStartMin = angleStartMin;
    /**
     * The angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    @editable({ label: 'Angle Start Max', group: 'emitterAngleStart' })
    public var emitterAngleStartMax(get,set):Float;
    inline function get_emitterAngleStartMax():Float return emitter.angleStartMax;
    inline function set_emitterAngleStartMax(angleStartMax:Float):Float return emitter.angleStartMax = angleStartMax;

    /**
     * The angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    @editable({ label: 'Angle End Min', group: 'emitterAngleEnd' })
    public var emitterAngleEndMin(get,set):Float;
    inline function get_emitterAngleEndMin():Float return emitter.angleEndMin;
    inline function set_emitterAngleEndMin(angleEndMin:Float):Float return emitter.angleEndMin = angleEndMin;
    /**
     * The angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    @editable({ label: 'Angle End Max', group: 'emitterAngleEnd' })
    public var emitterAngleEndMax(get,set):Float;
    inline function get_emitterAngleEndMax():Float return emitter.angleEndMax;
    inline function set_emitterAngleEndMax(angleEndMax:Float):Float return emitter.angleEndMax = angleEndMax;

    /**
     * Set this if you want to specify the beginning and ending value of angle,
     * instead of using `angularVelocity` (or `angularAcceleration`).
     */
    @editable({ label: 'Ignore Angular Vel.' })
    public var emitterIgnoreAngularVelocity(get,set):Bool;
    inline function get_emitterIgnoreAngularVelocity():Bool return emitter.ignoreAngularVelocity;
    inline function set_emitterIgnoreAngularVelocity(ignoreAngularVelocity:Bool):Bool return emitter.ignoreAngularVelocity = ignoreAngularVelocity;

    /**
     * Enable or disable the angle range at which particles will be launched from this emitter.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    @editable({ label: 'Launch Angle Active' })
    public var emitterLaunchAngleActive(get,set):Bool;
    inline function get_emitterLaunchAngleActive():Bool return emitter.launchAngleActive;
    inline function set_emitterLaunchAngleActive(launchAngleActive:Bool):Bool return emitter.launchAngleActive = launchAngleActive;

    /**
     * The angle range at which particles will be launched from this emitter.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    @editable({ label: 'Launch Angle Min', group: 'emitterLaunchAngle' })
    public var emitterLaunchAngleMin(get,set):Float;
    inline function get_emitterLaunchAngleMin():Float return emitter.launchAngleMin;
    inline function set_emitterLaunchAngleMin(launchAngleMin:Float):Float return emitter.launchAngleMin = launchAngleMin;
    /**
     * The angle range at which particles will be launched from this emitter.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    @editable({ label: 'Launch Angle Max', group: 'emitterLaunchAngle' })
    public var emitterLaunchAngleMax(get,set):Float;
    inline function get_emitterLaunchAngleMax():Float return emitter.launchAngleMax;
    inline function set_emitterLaunchAngleMax(launchAngleMax:Float):Float return emitter.launchAngleMax = launchAngleMax;

    /**
     * Enable or disable the life, or duration, range of particles launched from this emitter.
     */
    @editable({ label: 'Lifespan Active' })
    public var emitterLifespanActive(get,set):Bool;
    inline function get_emitterLifespanActive():Bool return emitter.lifespanActive;
    inline function set_emitterLifespanActive(lifespanActive:Bool):Bool return emitter.lifespanActive = lifespanActive;

    /**
     * The life, or duration, range of particles launched from this emitter.
     */
    @editable({ label: 'Lifespan Min', group: 'emitterLifespan' })
    public var emitterLifespanMin(get,set):Float;
    inline function get_emitterLifespanMin():Float return emitter.lifespanMin;
    inline function set_emitterLifespanMin(lifespanMin:Float):Float return emitter.lifespanMin = lifespanMin;
    /**
     * The life, or duration, range of particles launched from this emitter.
     */
    @editable({ label: 'Lifespan Max', group: 'emitterLifespan' })
    public var emitterLifespanMax(get,set):Float;
    inline function get_emitterLifespanMax():Float return emitter.lifespanMax;
    inline function set_emitterLifespanMax(lifespanMax:Float):Float return emitter.lifespanMax = lifespanMax;

    /**
     * Enable or disable `scale` range of particles launched from this emitter.
     */
    @editable({ label: 'Scale Active' })
    public var emitterScaleActive(get,set):Bool;
    inline function get_emitterScaleActive():Bool return emitter.scaleActive;
    inline function set_emitterScaleActive(scaleActive:Bool):Bool return emitter.scaleActive = scaleActive;

    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    @editable({ label: 'Scale Start Min X', group: 'emitterScaleStartMin' })
    public var emitterScaleStartMinX(get,set):Float;
    inline function get_emitterScaleStartMinX():Float return emitter.scaleStartMinX;
    inline function set_emitterScaleStartMinX(scaleStartMinX:Float):Float return emitter.scaleStartMinX = scaleStartMinX;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    @editable({ label: 'Scale Start Min Y', group: 'emitterScaleStartMin' })
    public var emitterScaleStartMinY(get,set):Float;
    inline function get_emitterScaleStartMinY():Float return emitter.scaleStartMinY;
    inline function set_emitterScaleStartMinY(scaleStartMinY:Float):Float return emitter.scaleStartMinY = scaleStartMinY;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    @editable({ label: 'Scale Start Max X', group: 'emitterScaleStartMax' })
    public var emitterScaleStartMaxX(get,set):Float;
    inline function get_emitterScaleStartMaxX():Float return emitter.scaleStartMaxX;
    inline function set_emitterScaleStartMaxX(scaleStartMaxX:Float):Float return emitter.scaleStartMaxX = scaleStartMaxX;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    @editable({ label: 'Scale Start Max Y', group: 'emitterScaleStartMax' })
    public var emitterScaleStartMaxY(get,set):Float;
    inline function get_emitterScaleStartMaxY():Float return emitter.scaleStartMaxY;
    inline function set_emitterScaleStartMaxY(scaleStartMaxY:Float):Float return emitter.scaleStartMaxY = scaleStartMaxY;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    @editable({ label: 'Scale End Min X', group: 'emitterScaleEndMin' })
    public var emitterScaleEndMinX(get,set):Float;
    inline function get_emitterScaleEndMinX():Float return emitter.scaleEndMinX;
    inline function set_emitterScaleEndMinX(scaleEndMinX:Float):Float return emitter.scaleEndMinX = scaleEndMinX;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    @editable({ label: 'Scale End Min Y', group: 'emitterScaleEndMin' })
    public var emitterScaleEndMinY(get,set):Float;
    inline function get_emitterScaleEndMinY():Float return emitter.scaleEndMinY;
    inline function set_emitterScaleEndMinY(scaleEndMinY:Float):Float return emitter.scaleEndMinY = scaleEndMinY;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    @editable({ label: 'Scale End Max X', group: 'emitterScaleEndMax' })
    public var emitterScaleEndMaxX(get,set):Float;
    inline function get_emitterScaleEndMaxX():Float return emitter.scaleEndMaxX;
    inline function set_emitterScaleEndMaxX(scaleEndMaxX:Float):Float return emitter.scaleEndMaxX = scaleEndMaxX;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    @editable({ label: 'Scale End Max Y', group: 'emitterScaleEndMax' })
    public var emitterScaleEndMaxY(get,set):Float;
    inline function get_emitterScaleEndMaxY():Float return emitter.scaleEndMaxY;
    inline function set_emitterScaleEndMaxY(scaleEndMaxY:Float):Float return emitter.scaleEndMaxY = scaleEndMaxY;

    /**
     * Enable or disable `alpha` range of particles launched from this emitter.
     */
    @editable({ label: 'Alpha Active' })
    public var emitterAlphaActive(get,set):Bool;
    inline function get_emitterAlphaActive():Bool return emitter.alphaActive;
    inline function set_emitterAlphaActive(alphaActive:Bool):Bool return emitter.alphaActive = alphaActive;

    /**
     * Sets `alpha` range of particles launched from this emitter.
     */
    @editable({ label: 'Alpha Start Min', group: 'emitterAlphaStart' })
    public var emitterAlphaStartMin(get,set):Float;
    inline function get_emitterAlphaStartMin():Float return emitter.alphaStartMin;
    inline function set_emitterAlphaStartMin(alphaStartMin:Float):Float return emitter.alphaStartMin = alphaStartMin;
    /**
     * Sets `alpha` range of particles launched from this emitter.
     */
    @editable({ label: 'Alpha Start Max', group: 'emitterAlphaStart' })
    public var emitterAlphaStartMax(get,set):Float;
    inline function get_emitterAlphaStartMax():Float return emitter.alphaStartMax;
    inline function set_emitterAlphaStartMax(alphaStartMax:Float):Float return emitter.alphaStartMax = alphaStartMax;

    /**
     * Sets `alpha` range of particles launched from this emitter.
     */
    @editable({ label: 'Alpha End Min', group: 'emitterAlphaEnd' })
    public var emitterAlphaEndMin(get,set):Float;
    inline function get_emitterAlphaEndMin():Float return emitter.alphaEndMin;
    inline function set_emitterAlphaEndMin(alphaEndMin:Float):Float return emitter.alphaEndMin = alphaEndMin;
    /**
     * Sets `alpha` range of particles launched from this emitter.
     */
    @editable({ label: 'Alpha End Max', group: 'emitterAlphaEnd' })
    public var emitterAlphaEndMax(get,set):Float;
    inline function get_emitterAlphaEndMax():Float return emitter.alphaEndMax;
    inline function set_emitterAlphaEndMax(alphaEndMax:Float):Float return emitter.alphaEndMax = alphaEndMax;

    /**
     * Enable or disable `color` range of particles launched from this emitter.
     */
    @editable({ label: 'Color Active' })
    public var emitterColorActive(get,set):Bool;
    inline function get_emitterColorActive():Bool return emitter.colorActive;
    inline function set_emitterColorActive(colorActive:Bool):Bool return emitter.colorActive = colorActive;

    /**
     * Sets `color` range of particles launched from this emitter.
     */
    @editable({ label: 'Color Start Min', group: 'emitterColorStart' })
    public var emitterColorStartMin(get,set):Color;
    inline function get_emitterColorStartMin():Color return emitter.colorStartMin;
    inline function set_emitterColorStartMin(colorStartMin:Color):Color return emitter.colorStartMin = colorStartMin;
    /**
     * Sets `color` range of particles launched from this emitter.
     */
    @editable({ label: 'Color Start Max', group: 'emitterColorStart' })
    public var emitterColorStartMax(get,set):Color;
    inline function get_emitterColorStartMax():Color return emitter.colorStartMax;
    inline function set_emitterColorStartMax(colorStartMax:Color):Color return emitter.colorStartMax = colorStartMax;

    /**
     * Sets `color` range of particles launched from this emitter.
     */
    @editable({ label: 'Color End Min', group: 'emitterColorEnd' })
    public var emitterColorEndMin(get,set):Color;
    inline function get_emitterColorEndMin():Color return emitter.colorEndMin;
    inline function set_emitterColorEndMin(colorEndMin:Color):Color return emitter.colorEndMin = colorEndMin;
    /**
     * Sets `color` range of particles launched from this emitter.
     */
    @editable({ label: 'Color End Max', group: 'emitterColorEnd' })
    public var emitterColorEndMax(get,set):Color;
    inline function get_emitterColorEndMax():Color return emitter.colorEndMax;
    inline function set_emitterColorEndMax(colorEndMax:Color):Color return emitter.colorEndMax = colorEndMax;

    /**
     * Enable or disable X and Y drag component of particles launched from this emitter.
     */
    @editable({ label: 'Drag Active' })
    public var emitterDragActive(get,set):Bool;
    inline function get_emitterDragActive():Bool return emitter.dragActive;
    inline function set_emitterDragActive(dragActive:Bool):Bool return emitter.dragActive = dragActive;

    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    @editable({ label: 'Drag Start Min X', group: 'emitterDragStartMin' })
    public var emitterDragStartMinX(get,set):Float;
    inline function get_emitterDragStartMinX():Float return emitter.dragStartMinX;
    inline function set_emitterDragStartMinX(dragStartMinX:Float):Float return emitter.dragStartMinX = dragStartMinX;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    @editable({ label: 'Drag Start Min Y', group: 'emitterDragStartMin' })
    public var emitterDragStartMinY(get,set):Float;
    inline function get_emitterDragStartMinY():Float return emitter.dragStartMinY;
    inline function set_emitterDragStartMinY(dragStartMinY:Float):Float return emitter.dragStartMinY = dragStartMinY;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    @editable({ label: 'Drag Start Max X', group: 'emitterDragStartMax' })
    public var emitterDragStartMaxX(get,set):Float;
    inline function get_emitterDragStartMaxX():Float return emitter.dragStartMaxX;
    inline function set_emitterDragStartMaxX(dragStartMaxX:Float):Float return emitter.dragStartMaxX = dragStartMaxX;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    @editable({ label: 'Drag Start Max Y', group: 'emitterDragStartMax' })
    public var emitterDragStartMaxY(get,set):Float;
    inline function get_emitterDragStartMaxY():Float return emitter.dragStartMaxY;
    inline function set_emitterDragStartMaxY(dragStartMaxY:Float):Float return emitter.dragStartMaxY = dragStartMaxY;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    @editable({ label: 'Drag End Min X', group: 'emitterDragEndMin' })
    public var emitterDragEndMinX(get,set):Float;
    inline function get_emitterDragEndMinX():Float return emitter.dragEndMinX;
    inline function set_emitterDragEndMinX(dragEndMinX:Float):Float return emitter.dragEndMinX = dragEndMinX;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    @editable({ label: 'Drag End Min Y', group: 'emitterDragEndMin' })
    public var emitterDragEndMinY(get,set):Float;
    inline function get_emitterDragEndMinY():Float return emitter.dragEndMinY;
    inline function set_emitterDragEndMinY(dragEndMinY:Float):Float return emitter.dragEndMinY = dragEndMinY;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    @editable({ label: 'Drag End Max X', group: 'emitterDragEndMax' })
    public var emitterDragEndMaxX(get,set):Float;
    inline function get_emitterDragEndMaxX():Float return emitter.dragEndMaxX;
    inline function set_emitterDragEndMaxX(dragEndMaxX:Float):Float return emitter.dragEndMaxX = dragEndMaxX;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    @editable({ label: 'Drag End Max Y', group: 'emitterDragEndMax' })
    public var emitterDragEndMaxY(get,set):Float;
    inline function get_emitterDragEndMaxY():Float return emitter.dragEndMaxY;
    inline function set_emitterDragEndMaxY(dragEndMaxY:Float):Float return emitter.dragEndMaxY = dragEndMaxY;

    /**
     * Enable or disable the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. Active' })
    public var emitterAccelerationActive(get,set):Bool;
    inline function get_emitterAccelerationActive():Bool return emitter.accelerationActive;
    inline function set_emitterAccelerationActive(accelerationActive:Bool):Bool return emitter.accelerationActive = accelerationActive;

    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. Start Min X', group: 'emitterAccelerationStartMin' })
    public var emitterAccelerationStartMinX(get,set):Float;
    inline function get_emitterAccelerationStartMinX():Float return emitter.accelerationStartMinX;
    inline function set_emitterAccelerationStartMinX(accelerationStartMinX:Float):Float return emitter.accelerationStartMinX = accelerationStartMinX;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. Start Min Y', group: 'emitterAccelerationStartMin' })
    public var emitterAccelerationStartMinY(get,set):Float;
    inline function get_emitterAccelerationStartMinY():Float return emitter.accelerationStartMinY;
    inline function set_emitterAccelerationStartMinY(accelerationStartMinY:Float):Float return emitter.accelerationStartMinY = accelerationStartMinY;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. Start Max X', group: 'emitterAccelerationStartMax' })
    public var emitterAccelerationStartMaxX(get,set):Float;
    inline function get_emitterAccelerationStartMaxX():Float return emitter.accelerationStartMaxX;
    inline function set_emitterAccelerationStartMaxX(accelerationStartMaxX:Float):Float return emitter.accelerationStartMaxX = accelerationStartMaxX;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. Start Max Y', group: 'emitterAccelerationStartMax' })
    public var emitterAccelerationStartMaxY(get,set):Float;
    inline function get_emitterAccelerationStartMaxY():Float return emitter.accelerationStartMaxY;
    inline function set_emitterAccelerationStartMaxY(accelerationStartMaxY:Float):Float return emitter.accelerationStartMaxY = accelerationStartMaxY;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. End Min X', group: 'emitterAccelerationEndMin' })
    public var emitterAccelerationEndMinX(get,set):Float;
    inline function get_emitterAccelerationEndMinX():Float return emitter.accelerationEndMinX;
    inline function set_emitterAccelerationEndMinX(accelerationEndMinX:Float):Float return emitter.accelerationEndMinX = accelerationEndMinX;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. End Min Y', group: 'emitterAccelerationEndMin' })
    public var emitterAccelerationEndMinY(get,set):Float;
    inline function get_emitterAccelerationEndMinY():Float return emitter.accelerationEndMinY;
    inline function set_emitterAccelerationEndMinY(accelerationEndMinY:Float):Float return emitter.accelerationEndMinY = accelerationEndMinY;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. End Max X', group: 'emitterAccelerationEndMax' })
    public var emitterAccelerationEndMaxX(get,set):Float;
    inline function get_emitterAccelerationEndMaxX():Float return emitter.accelerationEndMaxX;
    inline function set_emitterAccelerationEndMaxX(accelerationEndMaxX:Float):Float return emitter.accelerationEndMaxX = accelerationEndMaxX;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. End Max Y', group: 'emitterAccelerationEndMax' })
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

    #if editor

/// Editor

    public static function editorSetupEntity(entityData:editor.model.EditorEntityData) {

        entityData.props.set('width', 100);
        entityData.props.set('height', 100);
        entityData.props.set('autoEmit', true);

    }

    #end

}