package ceramic;

import ceramic.Shortcuts.*;

// Ported to ceramic from HaxeFlixel FlxEmitter & FlxParticle:
// https://github.com/HaxeFlixel/flixel/blob/02e2d18158761d0d508a06126daef2487aa7373c/flixel/effects/particles/FlxEmitter.hx

/** A visual that act as a particle emitter. */
class Particles extends Visual {

/// Events

    @event function _start();

    @event function _finish();

    @event function _emitParticle(particle:ParticleItem);

/// Properties

    /**
     * Determines whether the emitter is currently emitting particles. It is totally safe to directly toggle this.
     */
    public var emitting:Bool = false;

    /**
     * How often a particle is emitted (if emitter is started with `explode=false`).
     */
    public var frequency:Float = 0.1;

    /**
     * How particles should be launched. If `CIRCLE`, particles will use `launchAngle` and `speed`.
     * Otherwise, particles will just use `velocityX` and `velocityY`.
     */
    public var launchMode:ParticlesMode = ParticlesMode.CIRCLE;

    /**
     * Keep the scale ratio of the particle. Uses the `scaleX` value for reference.
     */
    public var keepScaleRatio:Bool = false;

	/**
	 * Enable or disable the velocity range of particles launched from this emitter. Only used with `ParticlesMode.SQUARE`.
	 */
    public var velocityActive:Bool = true;
	/**
	 * Sets the velocity range of particles launched from this emitter. Only used with `ParticlesMode.SQUARE`.
	 */
    public var velocityStartMinX:Float = -100;
	/**
	 * Sets the velocity range of particles launched from this emitter. Only used with `ParticlesMode.SQUARE`.
	 */
    public var velocityStartMinY:Float = -100;
	/**
	 * Sets the velocity range of particles launched from this emitter. Only used with `ParticlesMode.SQUARE`.
	 */
    public var velocityStartMaxX:Float = 100;
	/**
	 * Sets the velocity range of particles launched from this emitter. Only used with `ParticlesMode.SQUARE`.
	 */
    public var velocityStartMaxY:Float = 100;
	/**
	 * Sets the velocity range of particles launched from this emitter. Only used with `ParticlesMode.SQUARE`.
	 */
    public var velocityEndMinX:Float = -100;
	/**
	 * Sets the velocity range of particles launched from this emitter. Only used with `ParticlesMode.SQUARE`.
	 */
    public var velocityEndMinY:Float = -100;
	/**
	 * Sets the velocity range of particles launched from this emitter. Only used with `ParticlesMode.SQUARE`.
	 */
    public var velocityEndMaxX:Float = 100;
	/**
	 * Sets the velocity range of particles launched from this emitter. Only used with `ParticlesMode.SQUARE`.
	 */
    public var velocityEndMaxY:Float = 100;

    /**
     * Set the speed range of particles launched from this emitter. Only used with `ParticlesMode.CIRCLE`.
     */
    public var speedStartMin:Float = 0;
    /**
     * Set the speed range of particles launched from this emitter. Only used with `ParticlesMode.CIRCLE`.
     */
    public var speedStartMax:Float = 100;
    /**
     * Set the speed range of particles launched from this emitter. Only used with `ParticlesMode.CIRCLE`.
     */
    public var speedEndMin:Float = 0;
    /**
     * Set the speed range of particles launched from this emitter. Only used with `ParticlesMode.CIRCLE`.
     */
    public var speedEndMax:Float = 100;

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
	 * Enable or disable the angular deceleration range of particles launched from this emitter.
	 */
    public var angularDecelerationActive:Bool = true;
    /**
     * Set the angular deceleration range of particles launched from this emitter.
     */
    public var angularDecelerationStartMin:Float = 0;
    /**
     * Set the angular deceleration range of particles launched from this emitter.
     */
    public var angularDecelerationStartMax:Float = 0;

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
     * Ignored unless `launchMode` is set to `ParticlesMode.CIRCLE`.
     */
    public var launchAngleActive:Bool = true;
    /**
     * The angle range at which particles will be launched from this emitter.
     * Ignored unless `launchMode` is set to `ParticlesMode.CIRCLE`.
     */
    public var launchAngleMin:Float = -180;
    /**
     * The angle range at which particles will be launched from this emitter.
     * Ignored unless `launchMode` is set to `ParticlesMode.CIRCLE`.
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
     * Enable or disable X and Y deceleration component of particles launched from this emitter.
     */
    public var decelerationActive:Bool = true;
	/**
	 * Sets X and Y deceleration component of particles launched from this emitter.
	 */
    public var decelerationStartMinX:Float = 0;
	/**
	 * Sets X and Y deceleration component of particles launched from this emitter.
	 */
    public var decelerationStartMinY:Float = 0;
	/**
	 * Sets X and Y deceleration component of particles launched from this emitter.
	 */
    public var decelerationStartMaxX:Float = 0;
	/**
	 * Sets X and Y deceleration component of particles launched from this emitter.
	 */
    public var decelerationStartMaxY:Float = 0;
	/**
	 * Sets X and Y deceleration component of particles launched from this emitter.
	 */
    public var decelerationEndMinX:Float = 0;
	/**
	 * Sets X and Y deceleration component of particles launched from this emitter.
	 */
    public var decelerationEndMinY:Float = 0;
	/**
	 * Sets X and Y deceleration component of particles launched from this emitter.
	 */
    public var decelerationEndMaxX:Float = 0;
	/**
	 * Sets X and Y deceleration component of particles launched from this emitter.
	 */
    public var decelerationEndMaxY:Float = 0;

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
     * Enable or disable the `elasticity`, or bounce, range of particles launched from this emitter.
     */
    public var elasticityActive:Bool = true;
    /**
     * Sets the `elasticity`, or bounce, range of particles launched from this emitter.
     */
    public var elasticityStartMin:Float = 0;
    /**
     * Sets the `elasticity`, or bounce, range of particles launched from this emitter.
     */
    public var elasticityStartMax:Float = 0;
    /**
     * Sets the `elasticity`, or bounce, range of particles launched from this emitter.
     */
    public var elasticityEndMin:Float = 0;
    /**
     * Sets the `elasticity`, or bounce, range of particles launched from this emitter.
     */
    public var elasticityEndMax:Float = 0;

    /**
     * Internal helper for deciding how many particles to launch.
     */
    var _quantity:Int = 0;

    /**
     * Internal helper for the style of particle emission (all at once, or one at a time).
     */
    var _explode:Bool = true;

    /**
     * Internal helper for deciding when to launch particles or destroy them.
     */
    var _timer:Float = 0;

    /**
     * Internal counter for figuring out how many particles to launch.
     */
    var _counter:Int = 0;

    /**
     * Internal helper for automatically calling the `destroy()` method
     */
    var _waitForDestroy:Bool = false;

    /**
     * Internal list of active particle items
     */
    var _activeParticles:Array<ParticleItem> = [];

    /**
     * Internal list of recycled particle items
     */
    var _recycledParticles:Array<ParticleItem> = [];

    /**
     * Internal point object, handy for reusing for memory management purposes.
     */
    static var _point:Point = new Point(0, 0);

/// Lifecycle

    /**
     * Creates a new `Particles` object.
     * Does NOT automatically generate or attach particles!
     */
    public function new()
    {
        super();

        app.onUpdate(this, update);
    }

    /**
     * Called automatically by the game loop, decides when to launch particles and when to "die".
     */
    function update(elapsed:Float):Void
    {
        if (emitting)
        {
            if (_explode)
                explode();
            else
                emitContinuously(elapsed);
        }
        else if (_waitForDestroy)
        {
            _timer += elapsed;

            if ((lifespanMax > 0) && (_timer > lifespanMax))
            {
                destroy();
                return;
            }
        }

    } //update

    function explode():Void
    {
        // TODO port to ceramic

        /*
        var amount:Int = _quantity;
        if (amount <= 0 || amount > length)
            amount = length;

        for (i in 0...amount)
            emitParticle();
            */

        emitFinish();
    }

    function emitContinuously(elapsed:Float):Void
    {
        // Spawn one particle per frame
        if (frequency <= 0)
        {
            emitParticleContinuously();
        }
        else
        {
            _timer += elapsed;

            while (_timer > frequency)
            {
                _timer -= frequency;
                emitParticleContinuously();
            }
        }
    }

    function emitParticleContinuously():Void
    {
        emitParticle();
        _counter++;

        if (_quantity > 0 && _counter >= _quantity)
            emitFinish();
    }

    function didEmitFinish():Void
    {
        emitting = false;
        _waitForDestroy = true;
        _quantity = 0;
    }

    /**
     * Call this function to turn off all the particles and the emitter.
     */
    override public function destroy():Void
    {
        emitting = false;
        _waitForDestroy = false;
    }

/// Managing particles and visuals

    function getParticle():ParticleItem {

        var particle:ParticleItem;

        if (_recycledParticles.length > 0) {
            particle = _recycledParticles.pop();
        }
        else {
            particle = new ParticleItem();
        }

        if (particle.visual == null) {
            particle.visual = getParticleVisual();
        }

        return particle;

    } //getParticle

    function getParticleVisual():Visual {

        // Default implementation return a random-colored 2x2 quad
        // This method can be overrided in a subclass to use a different visual as particle

        var quad = new Quad();
        quad.size(2, 2);
        quad.anchor(0.5, 0.5);
        quad.color = Color.random();
        return quad;

    } //getParticleVisual

/// Public API

    /**
     * Call this function to start emitting particles.
     *
     * @param   explode     Whether the particles should all burst out at once.
     * @param   frequency   Ignored if `explode` is set to `true`. `frequency` is how often to emit a particle.
     *                      `0` = never emit, `0.1` = 1 particle every 0.1 seconds, `5` = 1 particle every 5 seconds.
     * @param   quantity    How many particles to launch. `0` = "all of the particles".
     */
    public function start(explode:Bool = true, frequency:Float = 0.1, quantity:Int = 0):Void
    {
        emitting = true;

        _explode = explode;
        this.frequency = frequency;
        _quantity += quantity;

        _counter = 0;
        _timer = 0;

        _waitForDestroy = false;

        emitStart();

    } //start

    /**
     * This function can be used both internally and externally to emit the next particle.
     */
    public function emitParticle():Void
    {
        var particle:ParticleItem = getParticle();

        particle.reset();

        // Particle lifespan settings
        if (lifespanActive)
        {
            particle.lifespan = randomBetweenFloats(lifespanMin, lifespanMax);
        }

        if (velocityActive)
        {
            // Particle velocity/launch angle settings
            particle.velocityRangeActive = particle.lifespan > 0 && (particle.velocityRangeStartX != particle.velocityRangeEndX || particle.velocityRangeStartY != particle.velocityRangeEndY);

            if (launchMode == ParticlesMode.CIRCLE)
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

            if (angularDecelerationActive)
                particle.angularDeceleration = randomBetweenFloats(angularDecelerationStartMin, angularDecelerationStartMax);
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

        // Particle deceleration settings
        if (decelerationActive)
        {
            particle.decelerationRangeStartX = randomBetweenFloats(decelerationStartMinX, decelerationStartMaxX);
            particle.decelerationRangeStartY = randomBetweenFloats(decelerationStartMinY, decelerationStartMaxY);
            particle.decelerationRangeEndX = randomBetweenFloats(decelerationEndMinX, decelerationEndMaxX);
            particle.decelerationRangeEndY = randomBetweenFloats(decelerationEndMinY, decelerationEndMaxY);
            particle.decelerationRangeActive = particle.lifespan > 0 && (particle.decelerationRangeStartX != particle.decelerationRangeEndX || particle.decelerationRangeStartY != particle.decelerationRangeEndY);
            particle.decelerationX = particle.decelerationRangeStartX;
            particle.decelerationY = particle.decelerationRangeStartY;
        }
        else
            particle.decelerationRangeActive = false;

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

        // Particle elasticity settings
        if (elasticityActive)
        {
            particle.elasticityRangeStart = randomBetweenFloats(elasticityStartMin, elasticityStartMax);
            particle.elasticityRangeEnd = randomBetweenFloats(elasticityEndMin, elasticityEndMax);
            particle.elasticityRangeActive = particle.lifespan > 0 && particle.elasticityRangeStart != particle.elasticityRangeEnd;
            particle.elasticity = particle.elasticityRangeStart;
        }
        else
            particle.elasticityRangeActive = false;

        // Set position
        particle.pos(randomBetweenFloats(0, width), randomBetweenFloats(0, height));

        emitEmitParticle(particle);

    } //emitParticle

/// Static internal helpers

    inline static function degToRad(deg:Float):Float {

        return deg * 0.017453292519943295;

    } //degToRad

    inline static function randomBetweenFloats(a:Float, b:Float):Float {

        return a + (b - a) * Math.random();

    } //randomBetweenFloats

    inline static function randomBetweenColors(a:Color, b:Color):Color {

        var rnd:Float = Math.random();
        return Color.fromRGBFloat(
            a.redFloat + (b.redFloat - a.redFloat) * rnd,
            a.greenFloat + (b.greenFloat - a.greenFloat) * rnd,
            a.blueFloat + (b.blueFloat - a.blueFloat) * rnd
        );

    } //randomBetweenColors

    inline static function velocityFromAngle(angle:Float, speed:Float, result:Point):Void {

        var a:Float = degToRad(angle);
        result.x = Math.cos(a) * speed;
        result.y = Math.sin(a) * speed;

    } //velocityFromAngle

} //Particles

enum ParticlesMode {

    SQUARE;

    CIRCLE;

} //ParticlesMode

class ParticleItem {

    public var visual:Visual = null;

    public var lifespan:Float = 0;

    public var colorRangeActive:Bool = true;
    public var colorRangeStart:Color = Color.WHITE;
    public var colorRangeEnd:Color = Color.WHITE;
    public var color(get,set):Color;
    inline function get_color():Color {
        var color:Color = Color.WHITE;
        if (visual.quad != null) {
            color = visual.quad.color;
        }
        else if (visual.mesh != null) {
            color = visual.mesh.color;
        }
        return color;
    }
    inline function set_color(color:Color):Color {
        if (visual.quad != null) {
            visual.quad.color = color;
        }
        else if (visual.mesh != null) {
            visual.mesh.color = color;
        }
        return color;
    }

    public var accelerationRangeActive:Bool = true;
    public var accelerationRangeStartX:Float = 0;
    public var accelerationRangeStartY:Float = 0;
    public var accelerationRangeEndX:Float = 0;
    public var accelerationRangeEndY:Float = 0;
    public var accelerationX:Float = 0;
    public var accelerationY:Float = 0;

    public var decelerationRangeActive:Bool = true;
    public var decelerationRangeStartX:Float = 0;
    public var decelerationRangeStartY:Float = 0;
    public var decelerationRangeEndX:Float = 0;
    public var decelerationRangeEndY:Float = 0;
    public var decelerationX:Float = 0;
    public var decelerationY:Float = 0;

    public var velocityRangeActive:Bool = true;
    public var velocityRangeStartX:Float = 0;
    public var velocityRangeStartY:Float = 0;
    public var velocityRangeEndX:Float = 0;
    public var velocityRangeEndY:Float = 0;
    public var velocityX:Float = 0;
    public var velocityY:Float = 0;

    public var elasticityRangeActive:Bool = true;
    public var elasticityRangeStart:Float = 0;
    public var elasticityRangeEnd:Float = 0;
    public var elasticity:Float = 0;

    public var angularVelocityRangeActive:Bool = true;
    public var angularVelocityRangeStart:Float = 0;
    public var angularVelocityRangeEnd:Float = 0;
    public var angularVelocity:Float = 0;

    public var angularAccelerationRangeActive:Bool = true;
    public var angularAccelerationRangeStart:Float = 0;
    public var angularAccelerationRangeEnd:Float = 0;
    public var angularAcceleration:Float = 0;

    public var angularDeceleration:Float = 0;

    public var scaleRangeActive:Bool = true;
    public var scaleRangeStartX:Float = 1;
    public var scaleRangeStartY:Float = 1;
    public var scaleRangeEndX:Float = 1;
    public var scaleRangeEndY:Float = 1;
    public var scaleX(get,set):Float;
    inline function get_scaleX():Float {
        return visual.scaleX;
    }
    inline function set_scaleX(scaleX:Float):Float {
        visual.scaleX = scaleX;
        return scaleX;
    }
    public var scaleY:Float;
    inline function get_scaleY():Float {
        return visual.scaleY;
    }
    inline function set_scaleY(scaleY:Float):Float {
        visual.scaleY = scaleY;
        return scaleY;
    }
    inline public function scale(scaleX:Float, scaleY:Float):Void {
        visual.scale(scaleX, scaleY);
    }

    public var x(get,set):Float;
    inline function get_x():Float {
        return visual.x;
    }
    inline function set_x(x:Float):Float {
        visual.x = x;
        return x;
    }
    public var y:Float;
    inline function get_y():Float {
        return visual.y;
    }
    inline function set_y(y:Float):Float {
        visual.y = y;
        return y;
    }
    inline public function pos(x:Float, y:Float):Void {
        visual.pos(x, y);
    }

    public var angle(get,set):Float;
    inline function get_angle():Float {
        return visual.rotation;
    }
    inline function set_angle(angle:Float):Float {
        visual.rotation = angle;
        return angle;
    }

    public var alphaRangeActive:Bool = true;
    public var alphaRangeStart:Float = 1;
    public var alphaRangeEnd:Float = 1;
    public var alpha(get,set):Float;
    inline function get_alpha():Float {
        return visual.alpha;
    }
    inline function set_alpha(alpha:Float):Float {
        visual.alpha = alpha;
        return alpha;
    }

    public function new() {}

    public function reset():Void {

        angle = 0;

    } //reset

} //ParticleItem
