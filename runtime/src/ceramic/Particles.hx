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

    #if nope
    /**
     * Set the speed range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    public var speedStartMin:Float = 0;
    /**
     * Set the speed range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    public var speedStartMax:Float = 100;
    /**
     * Set the speed range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    public var speedEndMin:Float = 0;
    /**
     * Set the speed range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    public var speedEndMax:Float = 100;
    
    /**
	 * Use in conjunction with angularAcceleration for fluid spin speed control.
	 */
	public var maxAngularVelocity:Float = 10000;

    /**
     * Enable or disable the angular acceleration range of particles launched from this emitter.
     */
    public var angularAccelerationActive:Bool = true;
    /**
     * Set the angular acceleration range of particles launched from this emitter.
     */
    public var angularAccelerationStartMin:Float = 0;
    /**
     * Set the angular acceleration range of particles launched from this emitter.
     */
    public var angularAccelerationStartMax:Float = 0;

    /**
     * Enable or disable the angular drag range of particles launched from this emitter.
     */
    public var angularDragActive:Bool = true;
    /**
     * Set the angular drag range of particles launched from this emitter.
     */
    public var angularDragStartMin:Float = 0;
    /**
     * Set the angular drag range of particles launched from this emitter.
     */
    public var angularDragStartMax:Float = 0;

    /**
     * Enable or disable the angular velocity range of particles launched from this emitter.
     */
    public var angularVelocityActive:Bool = true;
    /**
     * The angular velocity range of particles launched from this emitter.
     */
    public var angularVelocityStartMin:Float = 0;
    /**
     * The angular velocity range of particles launched from this emitter.
     */
    public var angularVelocityStartMax:Float = 0;
    /**
     * The angular velocity range of particles launched from this emitter.
     */
    public var angularVelocityEndMin:Float = 0;
    /**
     * The angular velocity range of particles launched from this emitter.
     */
    public var angularVelocityEndMax:Float = 0;

    /**
     * Enable or disable the angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    public var angleActive:Bool = true;
    /**
     * The angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    public var angleStartMin:Float = 0;
    /**
     * The angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    public var angleStartMax:Float = 0;
    /**
     * The angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    public var angleEndMin:Float = 0;
    /**
     * The angle range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    public var angleEndMax:Float = 0;

    /**
     * Set this if you want to specify the beginning and ending value of angle,
     * instead of using `angularVelocity` (or `angularAcceleration`).
     */
    public var ignoreAngularVelocity:Bool = false;

    /**
     * Enable or disable the angle range at which particles will be launched from this emitter.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    public var launchAngleActive:Bool = true;
    /**
     * The angle range at which particles will be launched from this emitter.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    public var launchAngleMin:Float = -180;
    /**
     * The angle range at which particles will be launched from this emitter.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    public var launchAngleMax:Float = 180;

    /**
     * Enable or disable the life, or duration, range of particles launched from this emitter.
     */
    public var lifespanActive:Bool = true;
    /**
     * The life, or duration, range of particles launched from this emitter.
     */
    public var lifespanMin:Float = 3;
    /**
     * The life, or duration, range of particles launched from this emitter.
     */
    public var lifespanMax:Float = 3;

    /**
     * Enable or disable `scale` range of particles launched from this emitter.
     */
    public var scaleActive:Bool = true;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var scaleStartMinX:Float = 1;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var scaleStartMinY:Float = 1;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var scaleStartMaxX:Float = 1;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var scaleStartMaxY:Float = 1;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var scaleEndMinX:Float = 1;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var scaleEndMinY:Float = 1;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var scaleEndMaxX:Float = 1;
    /**
     * Sets `scale` range of particles launched from this emitter.
     */
    public var scaleEndMaxY:Float = 1;

    /**
     * Enable or disable `alpha` range of particles launched from this emitter.
     */
    public var alphaActive:Bool = true;
    /**
     * Sets `alpha` range of particles launched from this emitter.
     */
    public var alphaStartMin:Float = 1;
    /**
     * Sets `alpha` range of particles launched from this emitter.
     */
    public var alphaStartMax:Float = 1;
    /**
     * Sets `alpha` range of particles launched from this emitter.
     */
    public var alphaEndMin:Float = 1;
    /**
     * Sets `alpha` range of particles launched from this emitter.
     */
    public var alphaEndMax:Float = 1;

    /**
     * Enable or disable `color` range of particles launched from this emitter.
     */
    public var colorActive:Bool = true;
    /**
     * Sets `color` range of particles launched from this emitter.
     */
    public var colorStartMin:Color = Color.WHITE;
    /**
     * Sets `color` range of particles launched from this emitter.
     */
    public var colorStartMax:Color = Color.WHITE;
    /**
     * Sets `color` range of particles launched from this emitter.
     */
    public var colorEndMin:Color = Color.WHITE;
    /**
     * Sets `color` range of particles launched from this emitter.
     */
    public var colorEndMax:Color = Color.WHITE;

    /**
     * Enable or disable X and Y drag component of particles launched from this emitter.
     */
    public var dragActive:Bool = true;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var dragStartMinX:Float = 0;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var dragStartMinY:Float = 0;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var dragStartMaxX:Float = 0;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var dragStartMaxY:Float = 0;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var dragEndMinX:Float = 0;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var dragEndMinY:Float = 0;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var dragEndMaxX:Float = 0;
    /**
     * Sets X and Y drag component of particles launched from this emitter.
     */
    public var dragEndMaxY:Float = 0;

    /**
     * Enable or disable the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var accelerationActive:Bool = true;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var accelerationStartMinX:Float = 0;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var accelerationStartMinY:Float = 0;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var accelerationStartMaxX:Float = 0;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var accelerationStartMaxY:Float = 0;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var accelerationEndMinX:Float = 0;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var accelerationEndMinY:Float = 0;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var accelerationEndMaxX:Float = 0;
    /**
     * Sets the `acceleration` range of particles launched from this emitter.
     * Set acceleration y-values to give particles gravity.
     */
    public var accelerationEndMaxY:Float = 0;
    #end

    #if editor
    
/// Editor

    public static function editorSetupEntity(entityData:editor.model.EditorEntityData) {

        entityData.props.set('width', 100);
        entityData.props.set('height', 100);
        entityData.props.set('autoEmit', true);

    }
    
    #end

}