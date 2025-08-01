package ceramic;

/**
 * Represents a single particle in a particle system.
 * 
 * ParticleItem holds all the data for an individual particle including
 * its physical properties, visual appearance, and animation state.
 * Particles are managed by ParticleEmitter and should not be instantiated
 * directly by user code.
 * 
 * The particle's properties can change over its lifetime through:
 * - Linear interpolation between start and end values
 * - Physics simulation (velocity, acceleration, drag)
 * - Direct property manipulation
 * 
 * Visual synchronization:
 * When visual*Active flags are true, the particle automatically
 * updates the corresponding properties on its visual. This allows
 * the particle system to control the visual appearance efficiently.
 * 
 * @see ParticleEmitter The system that manages particle lifecycles
 * @see Visual The visual representation of the particle
 */
@:allow(ceramic.ParticleEmitter)
class ParticleItem {

    /**
     * The visual representation of this particle.
     * Can be any Visual subclass (Quad, Mesh, etc.).
     * Managed by the ParticleEmitter's pooling system.
     */
    public var visual:Visual = null;

    /**
     * Whether particle scale should be applied to the visual.
     * When true, changes to scaleX/scaleY update visual.scaleX/scaleY.
     */
    public var visualScaleActive:Bool = true;
    
    /**
     * Whether particle color should be applied to the visual.
     * When true, changes to color update visual's color (for Quad/Mesh).
     */
    public var visualColorActive:Bool = true;
    
    /**
     * Whether particle position should be applied to the visual.
     * When true, changes to x/y update visual.x/y.
     */
    public var visualPositionActive:Bool = true;
    
    /**
     * Whether particle angle should be applied to the visual.
     * When true, changes to angle update visual.rotation.
     */
    public var visualRotationActive:Bool = true;
    
    /**
     * Whether particle alpha should be applied to the visual.
     * When true, changes to alpha update visual.alpha.
     */
    public var visualAlphaActive:Bool = true;

    /**
     * Whether this particle is currently active in the simulation.
     * Inactive particles are in the recycling pool.
     */
    public var active:Bool = false;

    /**
     * Total lifetime of the particle in seconds.
     * When age >= lifespan, the particle is recycled.
     * Set to 0 for infinite lifetime.
     */
    public var lifespan:Float = 0;
    
    /**
     * Current age of the particle in seconds.
     * Increases each update by delta time.
     * Used to calculate interpolation progress.
     */
    public var age:Float = 0;

    /**
     * The timestamp when this particle was emitted.
     * Uses Timer.now for absolute time reference.
     * Useful for time-based effects or debugging.
     */
    public var time:Float = 0;

    /**
     * A random value between 0 and 1 unique to this particle.
     * Generated when emitted, remains constant during lifetime.
     * Useful for randomizing behavior without additional RNG calls.
     */
    public var random:Float = 0;

    /**
     * Custom status field for user-defined particle states.
     * Can be used to track special conditions, animation states,
     * or any integer-based status specific to your implementation.
     */
    public var status:Int = 0;

    /**
     * Whether color interpolation over lifetime is active.
     * When true, color interpolates from colorRangeStart to colorRangeEnd.
     */
    public var colorRangeActive:Bool = true;
    
    /**
     * Starting color for interpolation.
     * The particle begins with this color at age 0.
     */
    public var colorRangeStart:Color = Color.WHITE;
    
    /**
     * Ending color for interpolation.
     * The particle reaches this color at the end of its lifespan.
     */
    public var colorRangeEnd:Color = Color.WHITE;
    
    /**
     * Current color of the particle.
     * When visualColorActive is true, automatically syncs with visual's color.
     * Supports Quad and Mesh visuals.
     */
    @:isVar public var color(get,set):Color;
    inline function get_color():Color {
        var color:Color = Color.WHITE;
        if (visualColorActive && visual != null) {
            if (visual.asQuad != null) {
                color = visual.asQuad.color;
            }
            else if (visual.asMesh != null) {
                color = visual.asMesh.color;
            }
        }
        else {
            color = this.color;
        }
        return color;
    }
    inline function set_color(color:Color):Color {
        if (visualColorActive && visual != null) {
            if (visual.asQuad != null) {
                visual.asQuad.color = color;
            }
            else if (visual.asMesh != null) {
                visual.asMesh.color = color;
            }
        }
        return this.color = color;
    }

    /**
     * Whether acceleration interpolation over lifetime is active.
     */
    public var accelerationRangeActive:Bool = true;
    
    /**
     * Starting X acceleration for interpolation.
     */
    public var accelerationRangeStartX:Float = 0;
    
    /**
     * Starting Y acceleration for interpolation.
     */
    public var accelerationRangeStartY:Float = 0;
    
    /**
     * Ending X acceleration for interpolation.
     */
    public var accelerationRangeEndX:Float = 0;
    
    /**
     * Ending Y acceleration for interpolation.
     */
    public var accelerationRangeEndY:Float = 0;
    
    /**
     * Current X acceleration in pixels per second squared.
     * Positive values accelerate right, negative left.
     */
    public var accelerationX:Float = 0;
    
    /**
     * Current Y acceleration in pixels per second squared.
     * Positive values accelerate down, negative up.
     * Common use: positive value for gravity effect.
     */
    public var accelerationY:Float = 0;

    /**
     * Whether drag interpolation over lifetime is active.
     */
    public var dragRangeActive:Bool = true;
    
    /**
     * Starting X drag coefficient for interpolation.
     */
    public var dragRangeStartX:Float = 0;
    
    /**
     * Starting Y drag coefficient for interpolation.
     */
    public var dragRangeStartY:Float = 0;
    
    /**
     * Ending X drag coefficient for interpolation.
     */
    public var dragRangeEndX:Float = 0;
    
    /**
     * Ending Y drag coefficient for interpolation.
     */
    public var dragRangeEndY:Float = 0;
    
    /**
     * Current X drag coefficient.
     * Reduces velocity over time, simulating air resistance.
     * Higher values = more resistance.
     */
    public var dragX:Float = 0;
    
    /**
     * Current Y drag coefficient.
     * Reduces velocity over time, simulating air resistance.
     * Higher values = more resistance.
     */
    public var dragY:Float = 0;

    /**
     * Whether velocity interpolation over lifetime is active.
     */
    public var velocityRangeActive:Bool = true;
    
    /**
     * Starting X velocity for interpolation.
     */
    public var velocityRangeStartX:Float = 0;
    
    /**
     * Starting Y velocity for interpolation.
     */
    public var velocityRangeStartY:Float = 0;
    
    /**
     * Ending X velocity for interpolation.
     */
    public var velocityRangeEndX:Float = 0;
    
    /**
     * Ending Y velocity for interpolation.
     */
    public var velocityRangeEndY:Float = 0;
    
    /**
     * Current X velocity in pixels per second.
     * Positive = right, negative = left.
     */
    public var velocityX:Float = 0;
    
    /**
     * Current Y velocity in pixels per second.
     * Positive = down, negative = up.
     */
    public var velocityY:Float = 0;

    /**
     * Whether angular velocity interpolation over lifetime is active.
     */
    public var angularVelocityRangeActive:Bool = true;
    
    /**
     * Starting angular velocity for interpolation.
     */
    public var angularVelocityRangeStart:Float = 0;
    
    /**
     * Ending angular velocity for interpolation.
     */
    public var angularVelocityRangeEnd:Float = 0;
    
    /**
     * Current angular velocity in degrees per second.
     * Positive = clockwise, negative = counter-clockwise.
     */
    public var angularVelocity:Float = 0;

    /**
     * Whether angular acceleration is active.
     * Note: Currently doesn't support interpolation.
     */
    public var angularAccelerationRangeActive:Bool = true;
    
    /**
     * Starting angular acceleration (unused currently).
     */
    public var angularAccelerationRangeStart:Float = 0;
    
    /**
     * Ending angular acceleration (unused currently).
     */
    public var angularAccelerationRangeEnd:Float = 0;
    
    /**
     * Angular acceleration in degrees per second squared.
     * Changes angular velocity over time.
     */
    public var angularAcceleration:Float = 0;

    /**
     * Angular drag coefficient.
     * Reduces angular velocity over time.
     * Higher values = more rotational resistance.
     */
    public var angularDrag:Float = 0;

    /**
     * Whether scale interpolation over lifetime is active.
     */
    public var scaleRangeActive:Bool = true;
    
    /**
     * Starting X scale for interpolation.
     */
    public var scaleRangeStartX:Float = 1;
    
    /**
     * Starting Y scale for interpolation.
     */
    public var scaleRangeStartY:Float = 1;
    
    /**
     * Ending X scale for interpolation.
     */
    public var scaleRangeEndX:Float = 1;
    
    /**
     * Ending Y scale for interpolation.
     */
    public var scaleRangeEndY:Float = 1;
    
    /**
     * Current X scale factor.
     * When visualScaleActive is true, automatically syncs with visual.scaleX.
     * 1.0 = normal size, 2.0 = double width, 0.5 = half width.
     */
    @:isVar public var scaleX(get,set):Float;
    inline function get_scaleX():Float {
        return visualScaleActive && visual != null ? visual.scaleX : this.scaleX;
    }
    inline function set_scaleX(scaleX:Float):Float {
        if (visualScaleActive && visual != null) {
            visual.scaleX = scaleX;
        }
        return this.scaleX = scaleX;
    }
    
    /**
     * Current Y scale factor.
     * When visualScaleActive is true, automatically syncs with visual.scaleY.
     * 1.0 = normal size, 2.0 = double height, 0.5 = half height.
     */
    @:isVar public var scaleY(get,set):Float;
    inline function get_scaleY():Float {
        return visualScaleActive && visual != null ? visual.scaleY : this.scaleY;
    }
    inline function set_scaleY(scaleY:Float):Float {
        if (visualScaleActive && visual != null) {
            visual.scaleY = scaleY;
        }
        return this.scaleY = scaleY;
    }
    
    /**
     * Sets both X and Y scale factors at once.
     * 
     * @param scaleX Horizontal scale factor
     * @param scaleY Vertical scale factor
     */
    inline public function scale(scaleX:Float, scaleY:Float):Void {
        this.scaleX = scaleX;
        this.scaleY = scaleY;
    }

    /**
     * Current X position in pixels.
     * When visualPositionActive is true, automatically syncs with visual.x.
     * Relative to the particle's parent visual.
     */
    @:isVar public var x(get,set):Float;
    inline function get_x():Float {
        return visualPositionActive && visual != null ? visual.x : this.x;
    }
    inline function set_x(x:Float):Float {
        if (visualPositionActive && visual != null) {
            visual.x = x;
        }
        return this.x = x;
    }
    
    /**
     * Current Y position in pixels.
     * When visualPositionActive is true, automatically syncs with visual.y.
     * Relative to the particle's parent visual.
     */
    @:isVar public var y(get,set):Float;
    inline function get_y():Float {
        return visualPositionActive && visual != null ? visual.y : this.y;
    }
    inline function set_y(y:Float):Float {
        if (visualPositionActive && visual != null) {
            visual.y = y;
        }
        return this.y = y;
    }
    
    /**
     * Sets both X and Y position at once.
     * 
     * @param x Horizontal position in pixels
     * @param y Vertical position in pixels
     */
    inline public function pos(x:Float, y:Float):Void {
        this.x = x;
        this.y = y;
    }

    /**
     * Current rotation angle in degrees.
     * When visualRotationActive is true, automatically syncs with visual.rotation.
     * 0 = no rotation, 90 = quarter turn clockwise.
     */
    @:isVar public var angle(get,set):Float = 0;
    inline function get_angle():Float {
        return visualRotationActive && visual != null ? visual.rotation : this.angle;
    }
    inline function set_angle(angle:Float):Float {
        if (visualRotationActive && visual != null) {
            visual.rotation = angle;
        }
        return this.angle = angle;
    }

    /**
     * Whether alpha interpolation over lifetime is active.
     */
    public var alphaRangeActive:Bool = true;
    
    /**
     * Starting alpha for interpolation.
     * 1.0 = fully opaque.
     */
    public var alphaRangeStart:Float = 1;
    
    /**
     * Ending alpha for interpolation.
     * 0.0 = fully transparent.
     */
    public var alphaRangeEnd:Float = 1;
    
    /**
     * Current alpha transparency.
     * When visualAlphaActive is true, automatically syncs with visual.alpha.
     * Range: 0.0 (invisible) to 1.0 (opaque).
     */
    @:isVar public var alpha(get,set):Float;
    inline function get_alpha():Float {
        return visualAlphaActive && visual != null ? visual.alpha : this.alpha;
    }
    inline function set_alpha(alpha:Float):Float {
        if (visualAlphaActive && visual != null) {
            visual.alpha = alpha;
        }
        return this.alpha = alpha;
    }

    /**
     * Private constructor - ParticleItems are created and managed by ParticleEmitter.
     * User code should not instantiate particles directly.
     */
    private function new() {}

    /**
     * Resets all particle properties to default values.
     * 
     * Called by ParticleEmitter when recycling a particle.
     * Ensures clean state for reused particles.
     */
    inline public function reset():Void {

        age = 0;
        lifespan = 0;
        status = 0;
        time = Timer.now;

        colorRangeActive = true;
        colorRangeStart = Color.WHITE;
        colorRangeEnd = Color.WHITE;
        color = Color.WHITE;

        accelerationRangeActive = true;
        accelerationRangeStartX = 0;
        accelerationRangeStartY = 0;
        accelerationRangeEndX = 0;
        accelerationRangeEndY = 0;
        accelerationX = 0;
        accelerationY = 0;

        dragRangeActive = true;
        dragRangeStartX = 0;
        dragRangeStartY = 0;
        dragRangeEndX = 0;
        dragRangeEndY = 0;
        dragX = 0;
        dragY = 0;

        velocityRangeActive = true;
        velocityRangeStartX = 0;
        velocityRangeStartY = 0;
        velocityRangeEndX = 0;
        velocityRangeEndY = 0;
        velocityX = 0;
        velocityY = 0;

        angularVelocityRangeActive = true;
        angularVelocityRangeStart = 0;
        angularVelocityRangeEnd = 0;
        angularVelocity = 0;

        angularAccelerationRangeActive = true;
        angularAccelerationRangeStart = 0;
        angularAccelerationRangeEnd = 0;
        angularAcceleration = 0;

        angularDrag = 0;

        scaleRangeActive = true;
        scaleRangeStartX = 1;
        scaleRangeStartY = 1;
        scaleRangeEndX = 1;
        scaleRangeEndY = 1;

        pos(0, 0);
        scale(1, 1);
        alpha = 1;
        angle = 0;

    }

}
