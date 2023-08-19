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
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.onDestroy(this, _ -> {
            destroy();
        });

#if editor
        app.onceImmediate(() -> {
            if (!destroyed && edited) {
                app.onUpdate(this, _ -> {
                    if (emitter != null && #if cs (cast emitter:ParticleEmitter) #else emitter #end.status != IDLE) {
                        editor.requestHighFps();
                    }
                });

                /*
                autorun(() -> {
                    var animating = editor.model.animationState.animating;
                    unobserve();
                    #if cs (cast emitter:ParticleEmitter) #else emitter #end.paused = emitterPaused || !animating;
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
                #if cs (cast emitter:ParticleEmitter) #else emitter #end.emitContinuously(emitterInterval);
            }
            else {
                #if cs (cast emitter:ParticleEmitter) #else emitter #end.stop();
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

        #if cs (cast emitter:ParticleEmitter) #else emitter #end.explode(autoExplodeQuantity);

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
        return #if cs (cast emitter:ParticleEmitter) #else emitter #end.paused = paused;// || (edited ? !editor.model.animationState.animating : false);
    }
    #else
    public var emitterPaused(get,set):Bool;
    inline function get_emitterPaused():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.paused;
    inline function set_emitterPaused(paused:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.paused = paused;
    #end

    /**
     * How often a particle is emitted, if currently emitting.
     * Can be modified at the middle of an emission safely;
     */
    @editable({ label: 'Interval', group: 'emitterInterval' })
    public var emitterInterval(get,set):Float;
    inline function get_emitterInterval():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.interval;
    inline function set_emitterInterval(interval:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.interval = interval;

    /**
     * How particles should be launched. If `CIRCLE` (default), particles will use `launchAngle` and `speed`.
     * Otherwise, particles will just use `velocityX` and `velocityY`.
     */
    @editable({ label: 'Launch Mode' })
    public var emitterLaunchMode(get,set):ParticlesLaunchMode;
    inline function get_emitterLaunchMode():ParticlesLaunchMode return #if cs (cast emitter:ParticleEmitter) #else emitter #end.launchMode;
    inline function set_emitterLaunchMode(launchMode:ParticlesLaunchMode):ParticlesLaunchMode return #if cs (cast emitter:ParticleEmitter) #else emitter #end.launchMode = launchMode;

    /**
     * Apply particle scale to underlying visual or not.
     */
    @editable({ label: 'Scale Active', group: 'emitterScale' })
    public var emitterVisualScaleActive(get,set):Bool;
    inline function get_emitterVisualScaleActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.visualScaleActive;
    inline function set_emitterVisualScaleActive(visualScaleActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.visualScaleActive = visualScaleActive;

    /**
     * Keep the scale ratio of the particle. Uses the `scaleX` value for reference.
     */
    @editable({ label: 'Keep Scale Ratio', group: 'emitterScale' })
    public var emitterKeepScaleRatio(get,set):Bool;
    inline function get_emitterKeepScaleRatio():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.keepScaleRatio;
    inline function set_emitterKeepScaleRatio(keepScaleRatio:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.keepScaleRatio = keepScaleRatio;

    /**
     * Apply particle color to underlying visual or not.
     */
    @editable({ label: 'Color Active', group: 'emitterColorAlphaActive' })
    public var emitterVisualColorActive(get,set):Bool;
    inline function get_emitterVisualColorActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.visualColorActive;
    inline function set_emitterVisualColorActive(visualColorActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.visualColorActive = visualColorActive;

    /**
     * Apply particle alpha to underlying visual or not.
     */
    @editable({ label: 'Alpha Active', group: 'emitterColorAlphaActive' })
    public var emitterVisualAlphaActive(get,set):Bool;
    inline function get_emitterVisualAlphaActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.visualAlphaActive;
    inline function set_emitterVisualAlphaActive(visualAlphaActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.visualAlphaActive = visualAlphaActive;

    /**
     * Apply particle position (x & y) to underlying visual or not.
     */
    @editable({ label: 'Position Active', group: 'emitterPosRotationActive' })
    public var emitterVisualPositionActive(get,set):Bool;
    inline function get_emitterVisualPositionActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.visualPositionActive;
    inline function set_emitterVisualPositionActive(visualPositionActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.visualPositionActive = visualPositionActive;

    /**
     * Apply particle angle to underlying visual rotation or not.
     */
    @editable({ label: 'Rotation Active', group: 'emitterPosRotationActive' })
    public var emitterVisualRotationActive(get,set):Bool;
    inline function get_emitterVisualRotationActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.visualRotationActive;
    inline function set_emitterVisualRotationActive(visualRotationActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.visualRotationActive = visualRotationActive;

    /**
     * The width of the emission area.
     * If not defined (`-1`), will use visual's width bound to this `ParticleEmitter` object, if any
     */
    @editable({ label: 'Emitter Width', group: 'emitterSize' })
    public var emitterWidth(get,set):Float;
    inline function get_emitterWidth():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.width;
    inline function set_emitterWidth(width:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.width = width;
    /**
     * The height of the emission area.
     * If not defined (`-1`), will use visual's height bound to this `ParticleEmitter` object, if any
     */
    @editable({ label: 'Emitter Height', group: 'emitterSize' })
    public var emitterHeight(get,set):Float;
    inline function get_emitterHeight():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.height;
    inline function set_emitterHeight(height:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.height = height;

    /**
     * The x position of the emission, relative to particles parent (if any)
     */
    @editable({ label: 'Emitter X', group: 'emitterPos' })
    public var emitterX(get,set):Float;
    inline function get_emitterX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.x;
    inline function set_emitterX(x:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.x = x;
    /**
     * The y position of the emission, relative to particles parent (if any)
     */
    @editable({ label: 'Emitter Y', group: 'emitterPos' })
    public var emitterY(get,set):Float;
    inline function get_emitterY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.y;
    inline function set_emitterY(y:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.y = y;

    /**
     * Enable or disable the velocity range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. Active' })
    public var emitterVelocityActive(get,set):Bool;
    inline function get_emitterVelocityActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityActive;
    inline function set_emitterVelocityActive(velocityActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityActive = velocityActive;

    /**
     * If you are using `acceleration`, you can use `maxVelocity` with it
     * to cap the speed automatically (very useful!).
     */
    @editable({ label: 'Max Vel. X', group: 'emitterMaxVelocity' })
    public var emitterMaxVelocityX(get,set):Float;
    inline function get_emitterMaxVelocityX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.maxVelocityX;
    inline function set_emitterMaxVelocityX(maxVelocityX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.maxVelocityX = maxVelocityX;
    /**
     * If you are using `acceleration`, you can use `maxVelocity` with it
     * to cap the speed automatically (very useful!).
     */
    @editable({ label: 'Max Vel. Y', group: 'emitterMaxVelocity' })
    public var emitterMaxVelocityY(get,set):Float;
    inline function get_emitterMaxVelocityY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.maxVelocityY;
    inline function set_emitterMaxVelocityY(maxVelocityY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.maxVelocityY = maxVelocityY;
    /**
     * Sets the velocity range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. Start Min X', group: 'emitterVelocityStartMin' })
    public var emitterVelocityStartMinX(get,set):Float;
    inline function get_emitterVelocityStartMinX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityStartMinX;
    inline function set_emitterVelocityStartMinX(velocityStartMinX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityStartMinX = velocityStartMinX;
    /**
     * Sets the velocity range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. Start Min Y', group: 'emitterVelocityStartMin' })
    public var emitterVelocityStartMinY(get,set):Float;
    inline function get_emitterVelocityStartMinY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityStartMinY;
    inline function set_emitterVelocityStartMinY(velocityStartMinY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityStartMinY = velocityStartMinY;
    /**
     * Sets the velocity range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. Start Max X', group: 'emitterVelocityStartMax' })
    public var emitterVelocityStartMaxX(get,set):Float;
    inline function get_emitterVelocityStartMaxX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityStartMaxX;
    inline function set_emitterVelocityStartMaxX(velocityStartMaxX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityStartMaxX = velocityStartMaxX;
    /**
     * Sets the velocity range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. Start Max Y', group: 'emitterVelocityStartMax' })
    public var emitterVelocityStartMaxY(get,set):Float;
    inline function get_emitterVelocityStartMaxY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityStartMaxY;
    inline function set_emitterVelocityStartMaxY(velocityStartMaxY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityStartMaxY = velocityStartMaxY;
    /**
     * Sets the velocity range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. End Min X', group: 'emitterVelocityEndMin' })
    public var emitterVelocityEndMinX(get,set):Float;
    inline function get_emitterVelocityEndMinX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityEndMinX;
    inline function set_emitterVelocityEndMinX(velocityEndMinX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityEndMinX = velocityEndMinX;
    /**
     * Sets the velocity range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. End Min Y', group: 'emitterVelocityEndMin' })
    public var emitterVelocityEndMinY(get,set):Float;
    inline function get_emitterVelocityEndMinY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityEndMinY;
    inline function set_emitterVelocityEndMinY(velocityEndMinY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityEndMinY = velocityEndMinY;
    /**
     * Sets the velocity range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. End Max X', group: 'emitterVelocityEndMax' })
    public var emitterVelocityEndMaxX(get,set):Float;
    inline function get_emitterVelocityEndMaxX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityEndMaxX;
    inline function set_emitterVelocityEndMaxX(velocityEndMaxX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityEndMaxX = velocityEndMaxX;
    /**
     * Sets the velocity range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `SQUARE`.
     */
    @editable({ label: 'Vel. End Max Y', group: 'emitterVelocityEndMax' })
    public var emitterVelocityEndMaxY(get,set):Float;
    inline function get_emitterVelocityEndMaxY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityEndMaxY;
    inline function set_emitterVelocityEndMaxY(velocityEndMaxY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityEndMaxY = velocityEndMaxY;

    /**
     * Set the speed range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `CIRCLE`.
     */
    @editable({ label: 'Speed Start Min', group: 'emitterSpeedStart' })
    public var emitterSpeedStartMin(get,set):Float;
    inline function get_emitterSpeedStartMin():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.speedStartMin;
    inline function set_emitterSpeedStartMin(speedStartMin:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.speedStartMin = speedStartMin;
    /**
     * Set the speed range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `CIRCLE`.
     */
    @editable({ label: 'Speed Start Max', group: 'emitterSpeedStart' })
    public var emitterSpeedStartMax(get,set):Float;
    inline function get_emitterSpeedStartMax():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.speedStartMax;
    inline function set_emitterSpeedStartMax(speedStartMax:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.speedStartMax = speedStartMax;

    /**
     * Set the speed range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `CIRCLE`.
     */
    @editable({ label: 'Speed End Min', group: 'emitterSpeedEnd' })
    public var emitterSpeedEndMin(get,set):Float;
    inline function get_emitterSpeedEndMin():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.speedEndMin;
    inline function set_emitterSpeedEndMin(speedEndMin:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.speedEndMin = speedEndMin;
    /**
     * Set the speed range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `CIRCLE`.
     */
    @editable({ label: 'Speed End Max', group: 'emitterSpeedEnd' })
    public var emitterSpeedEndMax(get,set):Float;
    inline function get_emitterSpeedEndMax():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.speedEndMax;
    inline function set_emitterSpeedEndMax(speedEndMax:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.speedEndMax = speedEndMax;

    /**
     * Use in conjunction with angularAcceleration for fluid spin speed control.
     */
    @editable({ label: 'Max Angular Vel.', group: 'emitterAngularVelocityAcceleration' })
    public var emitterMaxAngularVelocity(get,set):Float;
    inline function get_emitterMaxAngularVelocity():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.maxAngularVelocity;
    inline function set_emitterMaxAngularVelocity(maxAngularVelocity:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.maxAngularVelocity = maxAngularVelocity;
    /**
     * Enable or disable the angular acceleration range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Angular Accel. Active', group: 'emitterAngularVelocityAcceleration' })
    public var emitterAngularAccelerationActive(get,set):Bool;
    inline function get_emitterAngularAccelerationActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularAccelerationActive;
    inline function set_emitterAngularAccelerationActive(angularAccelerationActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularAccelerationActive = angularAccelerationActive;

    /**
     * Set the angular acceleration range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Angular Accel. Start Min', group: 'emitterAngularAccelerationStart' })
    public var emitterAngularAccelerationStartMin(get,set):Float;
    inline function get_emitterAngularAccelerationStartMin():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularAccelerationStartMin;
    inline function set_emitterAngularAccelerationStartMin(angularAccelerationStartMin:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularAccelerationStartMin = angularAccelerationStartMin;
    /**
     * Set the angular acceleration range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Angular Accel. Start Max', group: 'emitterAngularAccelerationStart' })
    public var emitterAngularAccelerationStartMax(get,set):Float;
    inline function get_emitterAngularAccelerationStartMax():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularAccelerationStartMax;
    inline function set_emitterAngularAccelerationStartMax(angularAccelerationStartMax:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularAccelerationStartMax = angularAccelerationStartMax;

    /**
     * Enable or disable the angular drag range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Angular Drag Active' })
    public var emitterAngularDragActive(get,set):Bool;
    inline function get_emitterAngularDragActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularDragActive;
    inline function set_emitterAngularDragActive(angularDragActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularDragActive = angularDragActive;

    /**
     * Set the angular drag range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Angular Drag Start Min', group: 'emitterAngularDragStart' })
    public var emitterAngularDragStartMin(get,set):Float;
    inline function get_emitterAngularDragStartMin():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularDragStartMin;
    inline function set_emitterAngularDragStartMin(angularDragStartMin:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularDragStartMin = angularDragStartMin;
    /**
     * Set the angular drag range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Angular Drag Start Max', group: 'emitterAngularDragStart' })
    public var emitterAngularDragStartMax(get,set):Float;
    inline function get_emitterAngularDragStartMax():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularDragStartMax;
    inline function set_emitterAngularDragStartMax(angularDragStartMax:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularDragStartMax = angularDragStartMax;

    /**
     * Enable or disable the angular velocity range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Angular Vel. Active' })
    public var emitterAngularVelocityActive(get,set):Bool;
    inline function get_emitterAngularVelocityActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularVelocityActive;
    inline function set_emitterAngularVelocityActive(angularVelocityActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularVelocityActive = angularVelocityActive;

    /**
     * The angular velocity range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Angular Vel. Start Min', group: 'emitterAngularVelocityStart' })
    public var emitterAngularVelocityStartMin(get,set):Float;
    inline function get_emitterAngularVelocityStartMin():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularVelocityStartMin;
    inline function set_emitterAngularVelocityStartMin(angularVelocityStartMin:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularVelocityStartMin = angularVelocityStartMin;
    /**
     * The angular velocity range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Angular Vel. Start Max', group: 'emitterAngularVelocityStart' })
    public var emitterAngularVelocityStartMax(get,set):Float;
    inline function get_emitterAngularVelocityStartMax():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularVelocityStartMax;
    inline function set_emitterAngularVelocityStartMax(angularVelocityStartMax:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularVelocityStartMax = angularVelocityStartMax;

    /**
     * The angular velocity range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Angular Vel. End Min', group: 'emitterAngularVelocityEnd' })
    public var emitterAngularVelocityEndMin(get,set):Float;
    inline function get_emitterAngularVelocityEndMin():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularVelocityEndMin;
    inline function set_emitterAngularVelocityEndMin(angularVelocityEndMin:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularVelocityEndMin = angularVelocityEndMin;
    /**
     * The angular velocity range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Angular Vel. End Max', group: 'emitterAngularVelocityEnd' })
    public var emitterAngularVelocityEndMax(get,set):Float;
    inline function get_emitterAngularVelocityEndMax():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularVelocityEndMax;
    inline function set_emitterAngularVelocityEndMax(angularVelocityEndMax:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularVelocityEndMax = angularVelocityEndMax;

    /**
     * Enable or disable the angle range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    @editable({ label: 'Angle Active' })
    public var emitterAngleActive(get,set):Bool;
    inline function get_emitterAngleActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angleActive;
    inline function set_emitterAngleActive(angleActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angleActive = angleActive;

    /**
     * The angle range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    @editable({ label: 'Angle Start Min', group: 'emitterAngleStart' })
    public var emitterAngleStartMin(get,set):Float;
    inline function get_emitterAngleStartMin():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angleStartMin;
    inline function set_emitterAngleStartMin(angleStartMin:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angleStartMin = angleStartMin;
    /**
     * The angle range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    @editable({ label: 'Angle Start Max', group: 'emitterAngleStart' })
    public var emitterAngleStartMax(get,set):Float;
    inline function get_emitterAngleStartMax():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angleStartMax;
    inline function set_emitterAngleStartMax(angleStartMax:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angleStartMax = angleStartMax;

    /**
     * The angle range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    @editable({ label: 'Angle End Min', group: 'emitterAngleEnd' })
    public var emitterAngleEndMin(get,set):Float;
    inline function get_emitterAngleEndMin():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angleEndMin;
    inline function set_emitterAngleEndMin(angleEndMin:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angleEndMin = angleEndMin;
    /**
     * The angle range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    @editable({ label: 'Angle End Max', group: 'emitterAngleEnd' })
    public var emitterAngleEndMax(get,set):Float;
    inline function get_emitterAngleEndMax():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angleEndMax;
    inline function set_emitterAngleEndMax(angleEndMax:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.angleEndMax = angleEndMax;

    /**
     * Set this if you want to specify the beginning and ending value of angle,
     * instead of using `angularVelocity` (or `angularAcceleration`).
     */
    @editable({ label: 'Ignore Angular Vel.' })
    public var emitterIgnoreAngularVelocity(get,set):Bool;
    inline function get_emitterIgnoreAngularVelocity():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.ignoreAngularVelocity;
    inline function set_emitterIgnoreAngularVelocity(ignoreAngularVelocity:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.ignoreAngularVelocity = ignoreAngularVelocity;

    /**
     * Enable or disable the angle range at which particles will be launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    @editable({ label: 'Launch Angle Active' })
    public var emitterLaunchAngleActive(get,set):Bool;
    inline function get_emitterLaunchAngleActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.launchAngleActive;
    inline function set_emitterLaunchAngleActive(launchAngleActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.launchAngleActive = launchAngleActive;

    /**
     * The angle range at which particles will be launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    @editable({ label: 'Launch Angle Min', group: 'emitterLaunchAngle' })
    public var emitterLaunchAngleMin(get,set):Float;
    inline function get_emitterLaunchAngleMin():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.launchAngleMin;
    inline function set_emitterLaunchAngleMin(launchAngleMin:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.launchAngleMin = launchAngleMin;
    /**
     * The angle range at which particles will be launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    @editable({ label: 'Launch Angle Max', group: 'emitterLaunchAngle' })
    public var emitterLaunchAngleMax(get,set):Float;
    inline function get_emitterLaunchAngleMax():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.launchAngleMax;
    inline function set_emitterLaunchAngleMax(launchAngleMax:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.launchAngleMax = launchAngleMax;

    /**
     * Enable or disable the life, or duration, range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Lifespan Active' })
    public var emitterLifespanActive(get,set):Bool;
    inline function get_emitterLifespanActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.lifespanActive;
    inline function set_emitterLifespanActive(lifespanActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.lifespanActive = lifespanActive;

    /**
     * The life, or duration, range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Lifespan Min', group: 'emitterLifespan' })
    public var emitterLifespanMin(get,set):Float;
    inline function get_emitterLifespanMin():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.lifespanMin;
    inline function set_emitterLifespanMin(lifespanMin:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.lifespanMin = lifespanMin;
    /**
     * The life, or duration, range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Lifespan Max', group: 'emitterLifespan' })
    public var emitterLifespanMax(get,set):Float;
    inline function get_emitterLifespanMax():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.lifespanMax;
    inline function set_emitterLifespanMax(lifespanMax:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.lifespanMax = lifespanMax;

    /**
     * Enable or disable `scale` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Scale Active' })
    public var emitterScaleActive(get,set):Bool;
    inline function get_emitterScaleActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleActive;
    inline function set_emitterScaleActive(scaleActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleActive = scaleActive;

    /**
     * Sets `scale` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Scale Start Min X', group: 'emitterScaleStartMin' })
    public var emitterScaleStartMinX(get,set):Float;
    inline function get_emitterScaleStartMinX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleStartMinX;
    inline function set_emitterScaleStartMinX(scaleStartMinX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleStartMinX = scaleStartMinX;
    /**
     * Sets `scale` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Scale Start Min Y', group: 'emitterScaleStartMin' })
    public var emitterScaleStartMinY(get,set):Float;
    inline function get_emitterScaleStartMinY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleStartMinY;
    inline function set_emitterScaleStartMinY(scaleStartMinY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleStartMinY = scaleStartMinY;
    /**
     * Sets `scale` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Scale Start Max X', group: 'emitterScaleStartMax' })
    public var emitterScaleStartMaxX(get,set):Float;
    inline function get_emitterScaleStartMaxX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleStartMaxX;
    inline function set_emitterScaleStartMaxX(scaleStartMaxX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleStartMaxX = scaleStartMaxX;
    /**
     * Sets `scale` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Scale Start Max Y', group: 'emitterScaleStartMax' })
    public var emitterScaleStartMaxY(get,set):Float;
    inline function get_emitterScaleStartMaxY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleStartMaxY;
    inline function set_emitterScaleStartMaxY(scaleStartMaxY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleStartMaxY = scaleStartMaxY;
    /**
     * Sets `scale` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Scale End Min X', group: 'emitterScaleEndMin' })
    public var emitterScaleEndMinX(get,set):Float;
    inline function get_emitterScaleEndMinX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleEndMinX;
    inline function set_emitterScaleEndMinX(scaleEndMinX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleEndMinX = scaleEndMinX;
    /**
     * Sets `scale` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Scale End Min Y', group: 'emitterScaleEndMin' })
    public var emitterScaleEndMinY(get,set):Float;
    inline function get_emitterScaleEndMinY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleEndMinY;
    inline function set_emitterScaleEndMinY(scaleEndMinY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleEndMinY = scaleEndMinY;
    /**
     * Sets `scale` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Scale End Max X', group: 'emitterScaleEndMax' })
    public var emitterScaleEndMaxX(get,set):Float;
    inline function get_emitterScaleEndMaxX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleEndMaxX;
    inline function set_emitterScaleEndMaxX(scaleEndMaxX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleEndMaxX = scaleEndMaxX;
    /**
     * Sets `scale` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Scale End Max Y', group: 'emitterScaleEndMax' })
    public var emitterScaleEndMaxY(get,set):Float;
    inline function get_emitterScaleEndMaxY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleEndMaxY;
    inline function set_emitterScaleEndMaxY(scaleEndMaxY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleEndMaxY = scaleEndMaxY;

    /**
     * Enable or disable `alpha` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Alpha Active' })
    public var emitterAlphaActive(get,set):Bool;
    inline function get_emitterAlphaActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.alphaActive;
    inline function set_emitterAlphaActive(alphaActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.alphaActive = alphaActive;

    /**
     * Sets `alpha` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Alpha Start Min', group: 'emitterAlphaStart' })
    public var emitterAlphaStartMin(get,set):Float;
    inline function get_emitterAlphaStartMin():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.alphaStartMin;
    inline function set_emitterAlphaStartMin(alphaStartMin:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.alphaStartMin = alphaStartMin;
    /**
     * Sets `alpha` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Alpha Start Max', group: 'emitterAlphaStart' })
    public var emitterAlphaStartMax(get,set):Float;
    inline function get_emitterAlphaStartMax():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.alphaStartMax;
    inline function set_emitterAlphaStartMax(alphaStartMax:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.alphaStartMax = alphaStartMax;

    /**
     * Sets `alpha` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Alpha End Min', group: 'emitterAlphaEnd' })
    public var emitterAlphaEndMin(get,set):Float;
    inline function get_emitterAlphaEndMin():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.alphaEndMin;
    inline function set_emitterAlphaEndMin(alphaEndMin:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.alphaEndMin = alphaEndMin;
    /**
     * Sets `alpha` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Alpha End Max', group: 'emitterAlphaEnd' })
    public var emitterAlphaEndMax(get,set):Float;
    inline function get_emitterAlphaEndMax():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.alphaEndMax;
    inline function set_emitterAlphaEndMax(alphaEndMax:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.alphaEndMax = alphaEndMax;

    /**
     * Enable or disable `color` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Color Active' })
    public var emitterColorActive(get,set):Bool;
    inline function get_emitterColorActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.colorActive;
    inline function set_emitterColorActive(colorActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.colorActive = colorActive;

    /**
     * Sets `color` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Color Start Min', group: 'emitterColorStart' })
    public var emitterColorStartMin(get,set):Color;
    inline function get_emitterColorStartMin():Color return #if cs (cast emitter:ParticleEmitter) #else emitter #end.colorStartMin;
    inline function set_emitterColorStartMin(colorStartMin:Color):Color return #if cs (cast emitter:ParticleEmitter) #else emitter #end.colorStartMin = colorStartMin;
    /**
     * Sets `color` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Color Start Max', group: 'emitterColorStart' })
    public var emitterColorStartMax(get,set):Color;
    inline function get_emitterColorStartMax():Color return #if cs (cast emitter:ParticleEmitter) #else emitter #end.colorStartMax;
    inline function set_emitterColorStartMax(colorStartMax:Color):Color return #if cs (cast emitter:ParticleEmitter) #else emitter #end.colorStartMax = colorStartMax;

    /**
     * Sets `color` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Color End Min', group: 'emitterColorEnd' })
    public var emitterColorEndMin(get,set):Color;
    inline function get_emitterColorEndMin():Color return #if cs (cast emitter:ParticleEmitter) #else emitter #end.colorEndMin;
    inline function set_emitterColorEndMin(colorEndMin:Color):Color return #if cs (cast emitter:ParticleEmitter) #else emitter #end.colorEndMin = colorEndMin;
    /**
     * Sets `color` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Color End Max', group: 'emitterColorEnd' })
    public var emitterColorEndMax(get,set):Color;
    inline function get_emitterColorEndMax():Color return #if cs (cast emitter:ParticleEmitter) #else emitter #end.colorEndMax;
    inline function set_emitterColorEndMax(colorEndMax:Color):Color return #if cs (cast emitter:ParticleEmitter) #else emitter #end.colorEndMax = colorEndMax;

    /**
     * Enable or disable X and Y drag component of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Drag Active' })
    public var emitterDragActive(get,set):Bool;
    inline function get_emitterDragActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragActive;
    inline function set_emitterDragActive(dragActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragActive = dragActive;

    /**
     * Sets X and Y drag component of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Drag Start Min X', group: 'emitterDragStartMin' })
    public var emitterDragStartMinX(get,set):Float;
    inline function get_emitterDragStartMinX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragStartMinX;
    inline function set_emitterDragStartMinX(dragStartMinX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragStartMinX = dragStartMinX;
    /**
     * Sets X and Y drag component of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Drag Start Min Y', group: 'emitterDragStartMin' })
    public var emitterDragStartMinY(get,set):Float;
    inline function get_emitterDragStartMinY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragStartMinY;
    inline function set_emitterDragStartMinY(dragStartMinY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragStartMinY = dragStartMinY;
    /**
     * Sets X and Y drag component of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Drag Start Max X', group: 'emitterDragStartMax' })
    public var emitterDragStartMaxX(get,set):Float;
    inline function get_emitterDragStartMaxX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragStartMaxX;
    inline function set_emitterDragStartMaxX(dragStartMaxX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragStartMaxX = dragStartMaxX;
    /**
     * Sets X and Y drag component of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Drag Start Max Y', group: 'emitterDragStartMax' })
    public var emitterDragStartMaxY(get,set):Float;
    inline function get_emitterDragStartMaxY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragStartMaxY;
    inline function set_emitterDragStartMaxY(dragStartMaxY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragStartMaxY = dragStartMaxY;
    /**
     * Sets X and Y drag component of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Drag End Min X', group: 'emitterDragEndMin' })
    public var emitterDragEndMinX(get,set):Float;
    inline function get_emitterDragEndMinX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragEndMinX;
    inline function set_emitterDragEndMinX(dragEndMinX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragEndMinX = dragEndMinX;
    /**
     * Sets X and Y drag component of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Drag End Min Y', group: 'emitterDragEndMin' })
    public var emitterDragEndMinY(get,set):Float;
    inline function get_emitterDragEndMinY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragEndMinY;
    inline function set_emitterDragEndMinY(dragEndMinY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragEndMinY = dragEndMinY;
    /**
     * Sets X and Y drag component of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Drag End Max X', group: 'emitterDragEndMax' })
    public var emitterDragEndMaxX(get,set):Float;
    inline function get_emitterDragEndMaxX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragEndMaxX;
    inline function set_emitterDragEndMaxX(dragEndMaxX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragEndMaxX = dragEndMaxX;
    /**
     * Sets X and Y drag component of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    @editable({ label: 'Drag End Max Y', group: 'emitterDragEndMax' })
    public var emitterDragEndMaxY(get,set):Float;
    inline function get_emitterDragEndMaxY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragEndMaxY;
    inline function set_emitterDragEndMaxY(dragEndMaxY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragEndMaxY = dragEndMaxY;

    /**
     * Enable or disable the `acceleration` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. Active' })
    public var emitterAccelerationActive(get,set):Bool;
    inline function get_emitterAccelerationActive():Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationActive;
    inline function set_emitterAccelerationActive(accelerationActive:Bool):Bool return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationActive = accelerationActive;

    /**
     * Sets the `acceleration` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. Start Min X', group: 'emitterAccelerationStartMin' })
    public var emitterAccelerationStartMinX(get,set):Float;
    inline function get_emitterAccelerationStartMinX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationStartMinX;
    inline function set_emitterAccelerationStartMinX(accelerationStartMinX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationStartMinX = accelerationStartMinX;
    /**
     * Sets the `acceleration` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. Start Min Y', group: 'emitterAccelerationStartMin' })
    public var emitterAccelerationStartMinY(get,set):Float;
    inline function get_emitterAccelerationStartMinY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationStartMinY;
    inline function set_emitterAccelerationStartMinY(accelerationStartMinY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationStartMinY = accelerationStartMinY;
    /**
     * Sets the `acceleration` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. Start Max X', group: 'emitterAccelerationStartMax' })
    public var emitterAccelerationStartMaxX(get,set):Float;
    inline function get_emitterAccelerationStartMaxX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationStartMaxX;
    inline function set_emitterAccelerationStartMaxX(accelerationStartMaxX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationStartMaxX = accelerationStartMaxX;
    /**
     * Sets the `acceleration` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. Start Max Y', group: 'emitterAccelerationStartMax' })
    public var emitterAccelerationStartMaxY(get,set):Float;
    inline function get_emitterAccelerationStartMaxY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationStartMaxY;
    inline function set_emitterAccelerationStartMaxY(accelerationStartMaxY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationStartMaxY = accelerationStartMaxY;
    /**
     * Sets the `acceleration` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. End Min X', group: 'emitterAccelerationEndMin' })
    public var emitterAccelerationEndMinX(get,set):Float;
    inline function get_emitterAccelerationEndMinX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationEndMinX;
    inline function set_emitterAccelerationEndMinX(accelerationEndMinX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationEndMinX = accelerationEndMinX;
    /**
     * Sets the `acceleration` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. End Min Y', group: 'emitterAccelerationEndMin' })
    public var emitterAccelerationEndMinY(get,set):Float;
    inline function get_emitterAccelerationEndMinY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationEndMinY;
    inline function set_emitterAccelerationEndMinY(accelerationEndMinY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationEndMinY = accelerationEndMinY;
    /**
     * Sets the `acceleration` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. End Max X', group: 'emitterAccelerationEndMax' })
    public var emitterAccelerationEndMaxX(get,set):Float;
    inline function get_emitterAccelerationEndMaxX():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationEndMaxX;
    inline function set_emitterAccelerationEndMaxX(accelerationEndMaxX:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationEndMaxX = accelerationEndMaxX;
    /**
     * Sets the `acceleration` range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * Set acceleration y-values to give particles gravity.
     */
    @editable({ label: 'Accel. End Max Y', group: 'emitterAccelerationEndMax' })
    public var emitterAccelerationEndMaxY(get,set):Float;
    inline function get_emitterAccelerationEndMaxY():Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationEndMaxY;
    inline function set_emitterAccelerationEndMaxY(accelerationEndMaxY:Float):Float return #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationEndMaxY = accelerationEndMaxY;

/// Configuration shorthands

    /**
     * The width and height of the emission area.
     * If not defined (`-1`), will use visual's width and height bound to this `ParticleEmitter` object, if any
     */
    inline public function emitterSize(width:Float, height:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.size(width, height);
    }

    /**
     * The x and y position of the emission, relative to particles parent (if any)
     */
    inline public function emitterPos(x:Float, y:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.pos(x, y);
    }

    /**
     * If you are using `acceleration`, you can use `maxVelocity` with it
     * to cap the speed automatically (very useful!).
     */
    inline public function emitterMaxVelocity(maxVelocityX:Float, maxVelocityY:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.maxVelocity(maxVelocityX, maxVelocityY);
    }

    /**
     * Sets the velocity starting range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `SQUARE`.
     */
    inline public function emitterVelocityStart(startMinX:Float, startMinY:Float, ?startMaxX:Float, ?startMaxY:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityStart(startMinX, startMinY, startMaxX, startMaxY);
    }

    /**
     * Sets the velocity ending range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `SQUARE`.
     */
    inline public function emitterVelocityEnd(endMinX:Float, endMinY:Float, ?endMaxX:Float, ?endMaxY:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.velocityEnd(endMinX, endMinY, endMaxX, endMaxY);
    }

    /**
     * Set the speed starting range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `CIRCLE`.
     */
    inline public function emitterSpeedStart(startMin:Float, ?startMax:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.speedStart(startMin, startMax);
    }

    /**
     * Set the speed ending range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end. Only used with `CIRCLE`.
     */
    inline public function emitterSpeedEnd(endMin:Float, ?endMax:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.speedEnd(endMin, endMax);
    }

    /**
     * Set the angular acceleration range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterAngularAcceleration(startMin:Float, startMax:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularAcceleration(startMin, startMax);
    }

    /**
     * Set the angular drag range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterAngularDrag(startMin:Float, startMax:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularDrag(startMin, startMax);
    }

    /**
     * The angular velocity starting range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterAngularVelocityStart(startMin:Float, ?startMax:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularVelocityStart(startMin, startMax);
    }

    /**
     * The angular velocity ending range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterAngularVelocityEnd(endMin:Float, ?endMax:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.angularVelocityEnd(endMin, endMax);
    }

    /**
     * The angle starting range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    inline public function emitterAngleStart(startMin:Float, ?startMax:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.angleStart(startMin, startMax);
    }

    /**
     * The angle ending range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    inline public function emitterAngleEnd(endMin:Float, ?endMax:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.angleEnd(endMin, endMax);
    }

    /**
     * The angle range at which particles will be launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    inline public function emitterLaunchAngle(min:Float, max:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.launchAngle(min, max);
    }

    /**
     * The life, or duration, range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterLifespan(min:Float, max:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.lifespan(min, max);
    }

    /**
     * Sets `scale` starting range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterScaleStart(startMinX:Float, startMinY:Float, ?startMaxX:Float, ?startMaxY:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleStart(startMinX, startMinY, startMaxX, startMaxY);
    }

    /**
     * Sets `scale` ending range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterScaleEnd(endMinX:Float, endMinY:Float, ?endMaxX:Float, ?endMaxY:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.scaleEnd(endMinX, endMinY, endMaxX, endMaxY);
    }

    /**
     * Sets `acceleration` starting range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterAccelerationStart(startMinX:Float, startMinY:Float, ?startMaxX:Float, ?startMaxY:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationStart(startMinX, startMinY, startMaxX, startMaxY);
    }

    /**
     * Sets `acceleration` ending range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterAccelerationEnd(endMinX:Float, endMinY:Float, ?endMaxX:Float, ?endMaxY:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.accelerationEnd(endMinX, endMinY, endMaxX, endMaxY);
    }

    /**
     * Sets `drag` starting range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterDragStart(startMinX:Float, startMinY:Float, ?startMaxX:Float, ?startMaxY:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragStart(startMinX, startMinY, startMaxX, startMaxY);
    }

    /**
     * Sets `drag` ending range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterdragEnd(endMinX:Float, endMinY:Float, ?endMaxX:Float, ?endMaxY:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.dragEnd(endMinX, endMinY, endMaxX, endMaxY);
    }

    /**
     * Sets `color` starting range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterColorStart(startMin:Color, ?startMax:Color):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.colorStart(startMin, startMax);
    }

    /**
     * Sets `color` ending range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterColorEnd(endMin:Color, ?endMax:Color):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.colorEnd(endMin, endMax);
    }

    /**
     * Sets `alpha` starting range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterAlphaStart(startMin:Float, ?startMax:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.alphaStart(startMin, startMax);
    }

    /**
     * Sets `alpha` ending range of particles launched from this #if cs (cast emitter:ParticleEmitter) #else emitter #end.
     */
    inline public function emitterAlphaEnd(endMin:Float, ?endMax:Float):Void {
        #if cs (cast emitter:ParticleEmitter) #else emitter #end.alphaEnd(endMin, endMax);
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