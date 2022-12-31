package ceramic;

import ceramic.Shortcuts.*;
import tracker.Observable;

using ceramic.Extensions;

// Ported to ceramic from HaxeFlixel FlxEmitter, FlxParticle & FlxVelocity:
// https://github.com/HaxeFlixel/flixel/blob/02e2d18158761d0d508a06126daef2487aa7373c/flixel/effects/particles/FlxEmitter.hx

/**
 * A particle emitter.
 */
class ParticleEmitter extends Entity implements Component implements Observable {

/// Entity/Visual

    var entity:Visual;

    public var visual(get, set):Visual;
    inline function get_visual():Visual return entity;
    inline function set_visual(visual:Visual):Visual return entity = visual;

/// Events

    @event function _emitParticle(particle:ParticleItem);

/// Configuration shorthands

    /**
     * The width and height of the emission area.
     * If not defined (`-1`), will use visual's width and height bound to this `ParticleEmitter` object, if any
     */
    inline public function size(width:Float, height:Float):Void {
        this.width = width;
        this.height = height;
    }

    /**
     * The x and y position of the emission, relative to particles parent (if any)
     */
    inline public function pos(x:Float, y:Float):Void {
        this.x = x;
        this.y = y;
    }

    /**
     * If you are using `acceleration`, you can use `maxVelocity` with it
     * to cap the speed automatically (very useful!).
     */
    inline public function maxVelocity(maxVelocityX:Float, maxVelocityY:Float):Void {
        this.maxVelocityX = maxVelocityX;
        this.maxVelocityY = maxVelocityY;
    }

    /**
     * Sets the velocity starting range of particles launched from this emitter. Only used with `SQUARE`.
     */
    inline public function velocityStart(startMinX:Float, startMinY:Float, ?startMaxX:Float, ?startMaxY:Float):Void {
        this.velocityStartMinX = startMinX;
        this.velocityStartMinY = startMinY;
        if (startMaxX == null) {
            this.velocityStartMaxX = startMinX;
        }
        else {
            this.velocityStartMaxX = startMaxX;
        }
        if (startMaxY == null) {
            this.velocityStartMaxY = startMinY;
        }
        else {
            this.velocityStartMaxY = startMaxY;
        }
    }

    /**
     * Sets the velocity ending range of particles launched from this emitter. Only used with `SQUARE`.
     */
    inline public function velocityEnd(endMinX:Float, endMinY:Float, ?endMaxX:Float, ?endMaxY:Float):Void {
        this.velocityEndMinX = endMinX;
        this.velocityEndMinY = endMinY;
        if (endMaxX == null) {
            this.velocityEndMaxX = endMinX;
        }
        else {
            this.velocityEndMaxX = endMaxX;
        }
        if (endMaxY == null) {
            this.velocityEndMaxY = endMinY;
        }
        else {
            this.velocityEndMaxY = endMaxY;
        }
    }

    /**
     * Set the speed starting range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    inline public function speedStart(startMin:Float, ?startMax:Float):Void {
        speedStartMin = startMin;
        speedStartMax = startMax != null ? startMax : startMin;
    }

    /**
     * Set the speed ending range of particles launched from this emitter. Only used with `CIRCLE`.
     */
    inline public function speedEnd(endMin:Float, ?endMax:Float):Void {
        speedEndMin = endMin;
        speedEndMax = endMax != null ? endMax : endMin;
    }

    /**
     * Set the angular acceleration range of particles launched from this emitter.
     */
    inline public function angularAcceleration(startMin:Float, startMax:Float):Void {
        angularAccelerationStartMin = startMin;
        angularAccelerationStartMax = startMax;
    }

    /**
     * Set the angular drag range of particles launched from this emitter.
     */
    inline public function angularDrag(startMin:Float, startMax:Float):Void {
        angularDragStartMin = startMin;
        angularDragStartMax = startMax;
    }

    /**
     * The angular velocity starting range of particles launched from this emitter.
     */
    inline public function angularVelocityStart(startMin:Float, ?startMax:Float):Void {
        angularVelocityStartMin = startMin;
        angularVelocityStartMax = startMax != null ? startMax : startMin;
    }

    /**
     * The angular velocity ending range of particles launched from this emitter.
     */
    inline public function angularVelocityEnd(endMin:Float, ?endMax:Float):Void {
        angularVelocityEndMin = endMin;
        angularVelocityEndMax = endMax != null ? endMax : endMin;
    }

    /**
     * The angle starting range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    inline public function angleStart(startMin:Float, ?startMax:Float):Void {
        angleStartMin = startMin;
        angleStartMax = startMax != null ? startMax : startMin;
    }

    /**
     * The angle ending range of particles launched from this emitter.
     * `angleEndMin` and `angleEndMax` are ignored unless `ignoreAngularVelocity` is set to `true`.
     */
    inline public function angleEnd(endMin:Float, ?endMax:Float):Void {
        angleEndMin = endMin;
        angleEndMax = endMax != null ? endMax : endMax;
    }

    /**
     * The angle range at which particles will be launched from this emitter.
     * Ignored unless `launchMode` is set to `CIRCLE`.
     */
    inline public function launchAngle(min:Float, max:Float):Void {
        launchAngleMin = min;
        launchAngleMax = max;
    }

    /**
     * The life, or duration, range of particles launched from this emitter.
     */
    inline public function lifespan(min:Float, max:Float):Void {
        lifespanMin = min;
        lifespanMax = max;
    }

    /**
     * Sets `scale` starting range of particles launched from this emitter.
     */
    inline public function scaleStart(startMinX:Float, startMinY:Float, ?startMaxX:Float, ?startMaxY:Float):Void {
        this.scaleStartMinX = startMinX;
        this.scaleStartMinY = startMinY;
        if (startMaxX == null) {
            this.scaleStartMaxX = startMinX;
        }
        else {
            this.scaleStartMaxX = startMaxX;
        }
        if (startMaxY == null) {
            this.scaleStartMaxY = startMinY;
        }
        else {
            this.scaleStartMaxY = startMaxY;
        }
    }

    /**
     * Sets `scale` ending range of particles launched from this emitter.
     */
    inline public function scaleEnd(endMinX:Float, endMinY:Float, ?endMaxX:Float, ?endMaxY:Float):Void {
        this.scaleEndMinX = endMinX;
        this.scaleEndMinY = endMinY;
        if (endMaxX == null) {
            this.scaleEndMaxX = endMinX;
        }
        else {
            this.scaleEndMaxX = endMaxX;
        }
        if (endMaxY == null) {
            this.scaleEndMaxY = endMinY;
        }
        else {
            this.scaleEndMaxY = endMaxY;
        }
    }

    /**
     * Sets `acceleration` starting range of particles launched from this emitter.
     */
    inline public function accelerationStart(startMinX:Float, startMinY:Float, ?startMaxX:Float, ?startMaxY:Float):Void {
        this.accelerationStartMinX = startMinX;
        this.accelerationStartMinY = startMinY;
        if (startMaxX == null) {
            this.accelerationStartMaxX = startMinX;
        }
        else {
            this.accelerationStartMaxX = startMaxX;
        }
        if (startMaxY == null) {
            this.accelerationStartMaxY = startMinY;
        }
        else {
            this.accelerationStartMaxY = startMaxY;
        }
    }

    /**
     * Sets `acceleration` ending range of particles launched from this emitter.
     */
    inline public function accelerationEnd(endMinX:Float, endMinY:Float, ?endMaxX:Float, ?endMaxY:Float):Void {
        this.accelerationEndMinX = endMinX;
        this.accelerationEndMinY = endMinY;
        if (endMaxX == null) {
            this.accelerationEndMaxX = endMinX;
        }
        else {
            this.accelerationEndMaxX = endMaxX;
        }
        if (endMaxY == null) {
            this.accelerationEndMaxY = endMinY;
        }
        else {
            this.accelerationEndMaxY = endMaxY;
        }
    }

    /**
     * Sets `drag` starting range of particles launched from this emitter.
     */
    inline public function dragStart(startMinX:Float, startMinY:Float, ?startMaxX:Float, ?startMaxY:Float):Void {
        this.dragStartMinX = startMinX;
        this.dragStartMinY = startMinY;
        if (startMaxX == null) {
            this.dragStartMaxX = startMinX;
        }
        else {
            this.dragStartMaxX = startMaxX;
        }
        if (startMaxY == null) {
            this.dragStartMaxY = startMinY;
        }
        else {
            this.dragStartMaxY = startMaxY;
        }
    }

    /**
     * Sets `drag` ending range of particles launched from this emitter.
     */
    inline public function dragEnd(endMinX:Float, endMinY:Float, ?endMaxX:Float, ?endMaxY:Float):Void {
        this.dragEndMinX = endMinX;
        this.dragEndMinY = endMinY;
        if (endMaxX == null) {
            this.dragEndMaxX = endMinX;
        }
        else {
            this.dragEndMaxX = endMaxX;
        }
        if (endMaxY == null) {
            this.dragEndMaxY = endMinY;
        }
        else {
            this.dragEndMaxY = endMaxY;
        }
    }

    /**
     * Sets `color` starting range of particles launched from this emitter.
     */
    inline public function colorStart(startMin:Color, ?startMax:Color):Void {
        colorStartMin = startMin;
        colorStartMax = startMax != null ? startMax : startMin;
    }

    /**
     * Sets `color` ending range of particles launched from this emitter.
     */
    inline public function colorEnd(endMin:Color, ?endMax:Color):Void {
        colorEndMin = endMin;
        colorEndMax = endMax != null ? endMax : endMin;
    }

    /**
     * Sets `alpha` starting range of particles launched from this emitter.
     */
    inline public function alphaStart(startMin:Float, ?startMax:Float):Void {
        alphaStartMin = startMin;
        alphaStartMax = startMax != null ? startMax : startMin;
    }

    /**
     * Sets `alpha` ending range of particles launched from this emitter.
     */
    inline public function alphaEnd(endMin:Float, ?endMax:Float):Void {
        alphaEndMin = endMin;
        alphaEndMax = endMax != null ? endMax : endMin;
    }

/// Properties

    /**
     * Determines whether the emitter is currently emitting particles or not
     */
    @observe public var status(default,null):ParticlesStatus = IDLE;

    /**
     * Determines whether the emitter is currently paused. It is totally safe to directly toggle this.
     */
    public var paused:Bool = false;

    /**
     * How often a particle is emitted, if currently emitting.
     * Can be modified at the middle of an emission safely;
     */
    public var interval:Float = 0.1;

    /**
     * How particles should be launched. If `CIRCLE` (default), particles will use `launchAngle` and `speed`.
     * Otherwise, particles will just use `velocityX` and `velocityY`.
     */
    public var launchMode:ParticlesLaunchMode = CIRCLE;

    /**
     * Keep the scale ratio of the particle. Uses the `scaleX` value for reference.
     */
    public var keepScaleRatio:Bool = false;

    /**
     * Apply particle scale to underlying visual or not.
     */
    public var visualScaleActive:Bool = true;

    /**
     * Apply particle color to underlying visual or not.
     */
    public var visualColorActive:Bool = true;

    /**
     * Apply particle position (x & y) to underlying visual or not.
     */
    public var visualPositionActive:Bool = true;

    /**
     * Apply particle angle to underlying visual rotation or not.
     */
    public var visualRotationActive:Bool = true;

    /**
     * Apply particle alpha to underlying visual or not.
     */
    public var visualAlphaActive:Bool = true;

    /**
     * The width of the emission area.
     * If not defined (`-1`), will use visual's width bound to this `ParticleEmitter` object, if any
     */
    public var width:Float = -1;
    /**
     * The height of the emission area.
     * If not defined (`-1`), will use visual's height bound to this `ParticleEmitter` object, if any
     */
    public var height:Float = -1;

    /**
     * The x position of the emission, relative to particles parent (if any)
     */
    public var x:Float = 0;
    /**
     * The y position of the emission, relative to particles parent (if any)
     */
    public var y:Float = 0;

    /**
     * If you are using `acceleration`, you can use `maxVelocity` with it
     * to cap the speed automatically (very useful!).
     */
    public var maxVelocityX:Float = 10000;
    /**
     * If you are using `acceleration`, you can use `maxVelocity` with it
     * to cap the speed automatically (very useful!).
     */
    public var maxVelocityY:Float = 10000;

    /**
     * Enable or disable the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var velocityActive:Bool = true;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var velocityStartMinX:Float = -100;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var velocityStartMinY:Float = -100;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var velocityStartMaxX:Float = 100;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var velocityStartMaxY:Float = 100;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var velocityEndMinX:Float = -100;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var velocityEndMinY:Float = -100;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var velocityEndMaxX:Float = 100;
    /**
     * Sets the velocity range of particles launched from this emitter. Only used with `SQUARE`.
     */
    public var velocityEndMaxY:Float = 100;

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

    /**
     * A random seed used to generated particles.
     * Provide a custom seed to reproduce same chain of particles.
     */
    public var seed(get,set):Float;
    inline function get_seed():Float {
        return _seedRandom.seed;
    }
    function set_seed(seed:Float):Float {
        _seedRandom.reset(seed);
        return seed;
    }

    /**
     * Custom particle visual creation. Use this to emit custom visuals as particle. Another option
     * is to create a subclass of `ParticleEmitter` and override `getParticleVisual()` method.
     */
    public var getCustomParticleVisual:(existingVisual:Visual)->Visual;

    /**
     * The internal quantity we want to emit (when emitting continuously)
     */
    var _quantityToEmit:Int = 0;

    /**
     * Timer used when emitting continuously
     */
    var _continuousTimer:Float = 0;

    /**
     * Internal list of active particle items
     */
    var _activeParticles:Array<ParticleItem> = [];

    /**
     * Internal list of recycled particle items
     */
    var _recycledParticles:Array<ParticleItem> = [];

    /**
     * Internal list of particle items when they are being iterated on to be updated
     */
    var _updatingParticles:Array<ParticleItem> = [];

    /**
     * The seeded random used internally
     */
    var _seedRandom:SeedRandom = new SeedRandom(Math.random() * 999999999);

    /**
     * Internal point object, handy for reusing for memory management purposes.
     */
    static var _point:Point = new Point(0, 0);

/// Lifecycle

    /**
     * Creates a new `ParticleEmitter` object.
     */
    public function new()
    {
        super();

        app.onUpdate(this, update);
    }

    override function destroy() {

        // When particle visuals are not associated to another visual,
        // destroy them if emitter is destroyed
        if (visual == null && _activeParticles != null && _activeParticles.length > 0) {
            var len = _activeParticles.length;
            for (i in 0...len) {
                var particle = _activeParticles.unsafeGet(i);
                if (particle.visual != null && particle.visual.parent == null) {
                    particle.visual.destroy();
                    particle.visual = null;
                }
            }
        }

        super.destroy();

    }

    function bindAsComponent() {

    }

    /**
     * Called automatically by the game loop
     */
    function update(delta:Float):Void
    {
        // Paused, nothing to do
        if (paused) return;

        // No visual, nothing to do
        if (visual == null) return;

        // Not paused, and EMITTING status, do emit a particle if needed
        if (status == EMITTING)
        {
            emitContinuousParticlesIfNeeded(delta);
        }

        // Update visible particles anyway
        if (_activeParticles.length > 0) {

            // Iterate over particles to update them.
            // We use a dedicated array for iteration to allow
            // active particles array to be updated while iterating
            var len = _activeParticles.length;
            for (i in 0...len) {
                var particle = _activeParticles.unsafeGet(i);
                _updatingParticles[i] = particle;
            }
            for (i in 0...len) {
                var particle = _updatingParticles.unsafeGet(i);
                _updatingParticles.unsafeSet(i, null);
                updateParticle(particle, delta);
            }
        }

        // Update status if needed, if there are still particles visibles or not
        if (status != EMITTING) {
            status = _activeParticles.length > 0 ? SPREADING : IDLE;
        }

    }

    /**
     * Emit one or more particles if continuous emission is active and enough time has passed
     */
    inline function emitContinuousParticlesIfNeeded(delta:Float):Void {

        _continuousTimer += delta;

        // Somehow interval was set to 0 or below.
        // Stop in that case
        if (interval <= 0) {
            interval = 0;
            stop();
            return;
        }

        while (_continuousTimer >= interval) {

            // Check quantity is zero.
            // If so, stop emitting
            if (_quantityToEmit == 0) {
                stop();
                break;
            }

            // Decrement quantity
            if (_quantityToEmit > 0) {
                _quantityToEmit--;
            }

            _continuousTimer -= interval;
            emitParticle();
        }

    }

    /**
     * Update a particle (and its visual) from its parameter and elapsed time
     */
    function updateParticle(particle:ParticleItem, delta:Float):Void {

        if (particle.age < particle.lifespan) {
            particle.age += delta;
        }

        if (particle.age >= particle.lifespan && particle.lifespan != 0)
        {
            recycleParticle(particle);
        }
        else
        {
            if (particle.lifespan > 0) {

                var lifespanDelta:Float = delta / particle.lifespan;
                var lifespanPercent:Float = particle.age / particle.lifespan;

                if (particle.velocityRangeActive)
                {
                    particle.velocityX += (particle.velocityRangeEndX - particle.velocityRangeStartX) * lifespanDelta;
                    particle.velocityY += (particle.velocityRangeEndY - particle.velocityRangeStartY) * lifespanDelta;
                }

                if (particle.angularVelocityRangeActive)
                {
                    particle.angularVelocity += (particle.angularVelocityRangeEnd - particle.angularVelocityRangeStart) * lifespanDelta;
                }

                if (particle.scaleRangeActive)
                {
                    particle.scaleX += (particle.scaleRangeEndX - particle.scaleRangeStartX) * lifespanDelta;
                    particle.scaleY += (particle.scaleRangeEndY - particle.scaleRangeStartY) * lifespanDelta;
                }

                if (particle.alphaRangeActive)
                {
                    particle.alpha += (particle.alphaRangeEnd - particle.alphaRangeStart) * lifespanDelta;
                }

                if (particle.colorRangeActive)
                {
                    particle.color = interpolateColor(particle.colorRangeStart, particle.colorRangeEnd, lifespanPercent);
                }

                if (particle.dragRangeActive)
                {
                    particle.dragX += (particle.dragRangeEndX - particle.dragRangeStartX) * lifespanDelta;
                    particle.dragY += (particle.dragRangeEndY - particle.dragRangeStartY) * lifespanDelta;
                }

                if (particle.accelerationRangeActive)
                {
                    particle.accelerationX += (particle.accelerationRangeEndX - particle.accelerationRangeStartX) * lifespanDelta;
                    particle.accelerationY += (particle.accelerationRangeEndY - particle.accelerationRangeStartY) * lifespanDelta;
                }
            }

            // Update motion
            //

            var velocityDelta = computeVelocity(particle.angularVelocity, particle.angularAcceleration, particle.angularDrag, maxAngularVelocity, delta) - particle.angularVelocity;
            particle.angularVelocity += velocityDelta;
            if (particle.angularVelocity != 0) {
                particle.angle += particle.angularVelocity * delta;
            }

            velocityDelta = computeVelocity(particle.velocityX, particle.accelerationX, particle.dragX, maxVelocityX, delta) - particle.velocityX;
            particle.velocityX += velocityDelta;
            if (particle.velocityX != 0) {
                particle.x += particle.velocityX * delta;
            }

            velocityDelta = computeVelocity(particle.velocityY, particle.accelerationY, particle.dragY, maxVelocityY, delta) - particle.velocityY;
            particle.velocityY += velocityDelta;
            if (particle.velocityY != 0) {
                particle.y += particle.velocityY * delta;
            }
        }

    }

/// Managing particles and visuals

    /**
     * Instanciate and return a new ParticleItem object.
     * Override this method if you want to instanciate a custom ParticleItem subclass
     * @return ParticleItem
     */
    function createParticleItem():ParticleItem {

        return new ParticleItem();

    }

    function getParticle():ParticleItem {

        var particle:ParticleItem;

        if (_recycledParticles.length > 0) {
            particle = _recycledParticles.pop();
        }
        else {
            particle = createParticleItem();
        }

        particle.visual = getParticleVisual(particle.visual);

        if (visual != null && particle.visual.parent != visual) {
            visual.add(particle.visual);
        }

        _activeParticles.push(particle);
        particle.active = true;

        return particle;

    }

    /**
     * Get a visual for a particle that will be emitted right after.
     * If a visual is being recycled, provide it as argument.
     */
    function getParticleVisual(existingVisual:Visual):Visual {

        // Default implementation returns a 5x5 quad
        // This method can be overrided in a subclass to use a different visual as particle

        // particleVisualGetter property can be used as well, but its dynamic nature could make it a less ideal option
        // on some targets if performance, low pressure on GC is a priority

        if (getCustomParticleVisual != null) {
            return getCustomParticleVisual(existingVisual);
        }

        if (existingVisual != null) {
            existingVisual.active = true;
            return existingVisual;
        }

        var quad = new Quad();
        quad.size(5, 5);
        quad.anchor(0.5, 0.5);
        quad.color = Color.WHITE;
        return quad;

    }

    function recycleParticle(particle:ParticleItem):Void {

        _activeParticles.remove(particle);
        particle.active = false;

        recycleParticleVisual(particle.visual);

        if (particle.visual.destroyed) {
            particle.visual = null;
        }

        _recycledParticles.push(particle);

    }

    /**
     * Recycle a particle's visual to reuse it later.
     */
    function recycleParticleVisual(visualToRecycle:Visual):Void {

        // Just make the visual inactive
        visualToRecycle.active = false;

    }


/// Public API

    /**
     * Start emitting particles continuously.
     *
     * @param   interval   How often to emit a particle.
     *                      `0` = never emit, `0.1` = 1 particle every 0.1 seconds, `5` = 1 particle every 5 seconds.
     * @param   quantity    How many particles to launch before stopping. `-1` (default) = never stop
     */
    public function emitContinuously(interval:Float = 0.1, quantity:Int = -1):Void
    {
        if (interval <= 0 || quantity == 0) {
            this.interval = 0;
            stop();
            return;
        }

        // Configure continuous emitting
        this.interval = interval;
        this.status = EMITTING;
        _quantityToEmit = quantity;

    }

    /**
     * Burst a given quantity number of particles at once
     *
     * @param   quantity    How many particles to launch. Does nothing if lower than `1`
     */
    public function explode(quantity:Int):Void {

        if (quantity < 1) {
            return;
        }

        // Emit all particles at once
        for (i in 0...quantity) {
            emitParticle();
        }

    }

    /**
     * Stop emitting (if it was emitting)
     */
    public function stop():Void {

        status = _activeParticles.length > 0 ? SPREADING : IDLE;
        _quantityToEmit = 0;
        _continuousTimer = 0;

    }

    /**
     * This function can be used both internally and externally to emit the next particle.
     */
    public function emitParticle():Void
    {
        var particle:ParticleItem = getParticle();

        particle.visualScaleActive = visualScaleActive;
        particle.visualColorActive = visualColorActive;
        particle.visualPositionActive = visualPositionActive;
        particle.visualRotationActive = visualRotationActive;
        particle.visualAlphaActive = visualAlphaActive;

        particle.reset();
        particle.random = _seedRandom.random();

        // Particle lifespan settings
        if (lifespanActive)
        {
            particle.lifespan = randomBetweenFloats(lifespanMin, lifespanMax);
        }

        if (velocityActive)
        {
            // Particle velocity/launch angle settings
            particle.velocityRangeActive = particle.lifespan > 0 && (particle.velocityRangeStartX != particle.velocityRangeEndX || particle.velocityRangeStartY != particle.velocityRangeEndY);

            if (launchMode == CIRCLE)
            {
                var particleAngle:Float = 0;
                if (launchAngleActive)
                    particleAngle = randomBetweenFloats(launchAngleMin, launchAngleMax);

                // Calculate launch velocity
                velocityFromAngle(particleAngle, randomBetweenFloats(speedStartMin, speedStartMax), _point);
                particle.velocityX = _point.x;
                particle.velocityY = _point.y;
                particle.velocityRangeStartX = _point.x;
                particle.velocityRangeStartY = _point.y;

                // Calculate final velocity
                velocityFromAngle(particleAngle, randomBetweenFloats(speedEndMin, speedEndMax), _point);
                particle.velocityRangeEndX = _point.x;
                particle.velocityRangeEndY = _point.y;
            }
            else
            {
                particle.velocityRangeStartX = randomBetweenFloats(velocityStartMinX, velocityStartMaxX);
                particle.velocityRangeStartY = randomBetweenFloats(velocityStartMinY, velocityStartMaxY);
                particle.velocityRangeEndX = randomBetweenFloats(velocityEndMinX, velocityEndMaxX);
                particle.velocityRangeEndY = randomBetweenFloats(velocityEndMinY, velocityEndMaxY);
                particle.velocityX = particle.velocityRangeStartX;
                particle.velocityY = particle.velocityRangeStartY;
            }
        }
        else
            particle.velocityRangeActive = false;

        // Particle angular velocity settings
        particle.angularVelocityRangeActive = particle.lifespan > 0 && (angularVelocityStartMin != angularVelocityEndMin || angularVelocityStartMax != angularVelocityEndMax);

        if (!ignoreAngularVelocity)
        {
            if (angularAccelerationActive)
                particle.angularAcceleration = randomBetweenFloats(angularAccelerationStartMin, angularAccelerationStartMax);

            if (angularVelocityActive)
            {
                particle.angularVelocityRangeStart = randomBetweenFloats(angularVelocityStartMin, angularVelocityStartMax);
                particle.angularVelocityRangeEnd = randomBetweenFloats(angularVelocityEndMin, angularVelocityEndMax);
                particle.angularVelocity = particle.angularVelocityRangeStart;
            }

            if (angularDragActive)
                particle.angularDrag = randomBetweenFloats(angularDragStartMin, angularDragStartMax);
        }
        else if (angularVelocityActive)
        {
            particle.angularVelocity = (randomBetweenFloats(angleEndMin,
                angleEndMax) - randomBetweenFloats(angleStartMin, angleStartMax)) / randomBetweenFloats(lifespanMin, lifespanMax);
            particle.angularVelocityRangeActive = false;
        }

        // Particle angle settings
        if (angleActive)
            particle.angle = randomBetweenFloats(angleStartMin, angleStartMax);

        // Particle scale settings
        if (scaleActive)
        {
            particle.scaleRangeStartX = randomBetweenFloats(scaleStartMinX, scaleStartMaxX);
            particle.scaleRangeStartY = keepScaleRatio ? particle.scaleRangeStartX : randomBetweenFloats(scaleStartMinY, scaleStartMaxY);
            particle.scaleRangeEndX = randomBetweenFloats(scaleEndMinX, scaleEndMaxX);
            particle.scaleRangeEndY = keepScaleRatio ? particle.scaleRangeEndX : randomBetweenFloats(scaleEndMinY, scaleEndMaxY);
            particle.scaleRangeActive = particle.lifespan > 0 && (particle.scaleRangeStartX != particle.scaleRangeEndX || particle.scaleRangeStartY != particle.scaleRangeEndY);
            particle.scale(particle.scaleRangeStartX, particle.scaleRangeStartY);
        }
        else
            particle.scaleRangeActive = false;

        // Particle alpha settings
        if (alphaActive)
        {
            particle.alphaRangeStart = randomBetweenFloats(alphaStartMin, alphaStartMax);
            particle.alphaRangeEnd = randomBetweenFloats(alphaEndMin, alphaEndMax);
            particle.alphaRangeActive = particle.lifespan > 0 && particle.alphaRangeStart != particle.alphaRangeEnd;
            particle.alpha = particle.alphaRangeStart;
        }
        else
            particle.alphaRangeActive = false;

        // Particle color settings
        if (colorActive)
        {
            particle.colorRangeStart = randomBetweenColors(colorStartMin, colorStartMax);
            particle.colorRangeEnd = randomBetweenColors(colorEndMin, colorEndMax);
            particle.colorRangeActive = particle.lifespan > 0 && particle.colorRangeStart != particle.colorRangeEnd;
            particle.color = particle.colorRangeStart;
        }
        else
            particle.colorRangeActive = false;

        // Particle drag settings
        if (dragActive)
        {
            particle.dragRangeStartX = randomBetweenFloats(dragStartMinX, dragStartMaxX);
            particle.dragRangeStartY = randomBetweenFloats(dragStartMinY, dragStartMaxY);
            particle.dragRangeEndX = randomBetweenFloats(dragEndMinX, dragEndMaxX);
            particle.dragRangeEndY = randomBetweenFloats(dragEndMinY, dragEndMaxY);
            particle.dragRangeActive = particle.lifespan > 0 && (particle.dragRangeStartX != particle.dragRangeEndX || particle.dragRangeStartY != particle.dragRangeEndY);
            particle.dragX = particle.dragRangeStartX;
            particle.dragY = particle.dragRangeStartY;
        }
        else
            particle.dragRangeActive = false;

        // Particle acceleration settings
        if (accelerationActive)
        {
            particle.accelerationRangeStartX = randomBetweenFloats(accelerationStartMinX, accelerationStartMaxX);
            particle.accelerationRangeStartY = randomBetweenFloats(accelerationStartMinY, accelerationStartMaxY);
            particle.accelerationRangeEndX = randomBetweenFloats(accelerationEndMinX, accelerationEndMaxX);
            particle.accelerationRangeEndY = randomBetweenFloats(accelerationEndMinY, accelerationEndMaxY);
            particle.accelerationRangeActive = particle.lifespan > 0
                && (particle.accelerationRangeStartX != particle.accelerationRangeEndX || particle.accelerationRangeStartY != particle.accelerationRangeEndY);
            particle.accelerationX = particle.accelerationRangeStartX;
            particle.accelerationY = particle.accelerationRangeStartY;
        }
        else
            particle.accelerationRangeActive = false;

        // Set position
        var areaWidth = this.width;
        if (areaWidth < 0) {
            if (visual != null)
                areaWidth = visual.width;
            else
                areaWidth = 0;
        }
        var areaHeight = this.height;
        if (areaHeight < 0) {
            if (visual != null)
                areaHeight = visual.height;
            else
                areaHeight = 0;
        }
        particle.pos(
            x + randomBetweenFloats(0, areaWidth),
            y + randomBetweenFloats(0, areaHeight)
        );

        emitEmitParticle(particle);

    }

/// Static internal helpers

    inline static function degToRad(deg:Float):Float {

        return deg * 0.017453292519943295;

    }

    inline function randomBetweenFloats(a:Float, b:Float):Float {

        return a + (b - a) * _seedRandom.random();

    }

    inline function randomBetweenColors(a:Color, b:Color):Color {

        var rnd:Float = _seedRandom.random();
        return Color.fromRGBFloat(
            a.redFloat + (b.redFloat - a.redFloat) * rnd,
            a.greenFloat + (b.greenFloat - a.greenFloat) * rnd,
            a.blueFloat + (b.blueFloat - a.blueFloat) * rnd
        );

    }

    inline static function interpolateColor(a:Color, b:Color, percent:Float):Color {

        return Color.fromRGBFloat(
            a.redFloat + (b.redFloat - a.redFloat) * percent,
            a.greenFloat + (b.greenFloat - a.greenFloat) * percent,
            a.blueFloat + (b.blueFloat - a.blueFloat) * percent
        );

    }

    inline static function velocityFromAngle(angle:Float, speed:Float, result:Point):Void {

        var a:Float = degToRad(angle - 90);
        result.x = Math.cos(a) * speed;
        result.y = Math.sin(a) * speed;

    }

    /**
     * A tween-like function that takes a starting velocity and some other factors and returns an altered velocity.
     *
     * @param	velocity		Any component of velocity (e.g. 20).
     * @param	acceleration	Rate at which the velocity is changing.
     * @param	drag	This is how much the velocity changes if acceleration is not set.
     * @param	max				An absolute value cap for the velocity (0 for no cap).
     * @param	elapsed			The amount of time passed in to the latest update cycle
     * @return	The altered velocity value.
     */
    inline static function computeVelocity(velocity:Float, acceleration:Float, drag:Float, max:Float, elapsed:Float):Float
    {
        if (acceleration != 0)
        {
            velocity += acceleration * elapsed;
        }
        if (drag != 0)
        {
            var drag:Float = drag * elapsed;
            if (velocity - drag > 0)
            {
                velocity -= drag;
            }
            else if (velocity + drag < 0)
            {
                velocity += drag;
            }
            else
            {
                velocity = 0;
            }
        }
        if (velocity != 0 && max != 0)
        {
            if (velocity > max)
            {
                velocity = max;
            }
            else if (velocity < -max)
            {
                velocity = -max;
            }
        }

        return velocity;

    }

}
