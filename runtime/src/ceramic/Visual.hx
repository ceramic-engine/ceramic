package ceramic;

#if ceramic_luxe_legacy
import backend.VisualItem;
#end

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

import ceramic.Point;

using ceramic.Extensions;

/**
 * Base class for all visual elements in Ceramic.
 *
 * Visuals are the building blocks to display things on screen. While a raw Visual
 * doesn't render anything by itself, it serves as a container for other visuals
 * and provides core functionality like transformation, hierarchy, and event handling.
 *
 * Specialized visual classes like Quad, Mesh, Text, etc. extend this class to
 * provide actual rendering capabilities.
 *
 * Key features:
 * - Hierarchical parent-child relationships
 * - Transform properties (position, scale, rotation, skew)
 * - Event handling (pointer events, focus)
 * - Depth sorting and rendering order
 * - Hit testing and touch input
 * - Shader and blend mode support
 *
 * Example usage:
 * ```haxe
 * var visual = new Visual();
 * visual.pos(100, 100);
 * visual.size(200, 150);
 * visual.onPointerDown(this, info -> {
 *     trace('Visual clicked at ${info.x}, ${info.y}');
 * });
 * ```
 */
@:allow(ceramic.App)
@:allow(ceramic.Screen)
@:allow(ceramic.MeshPool)
#if lua
@dynamicEvents
@:dce
#end
class Visual extends #if ceramic_visual_base VisualBase #else Entity #end #if plugin_arcade implements arcade.Collidable #end {

    /**
     * A factor applied to every computed depth. This factor is used to avoid having
     * all computed depth values being too small and risking to create precision issues.
     * It is expected to work best with use of `depthRange = 1` on visuals (default)
     */
    #if ceramic_depth_factor
    @:noCompletion inline static final DEPTH_FACTOR:Float = ceramic.macros.DefinesMacro.getFloatDefine('ceramic_depth_factor');
    #else
    @:noCompletion inline static final DEPTH_FACTOR:Float = 1000;
    #end

    /**
     * A garanteed margin between max inner computed depth and container depth range,
     * and min inner depth and container's computed depth.
     */
    @:noCompletion inline static final DEPTH_MARGIN:Float = 0.01;

/// Events

    /**
     * Fired when a pointer (touch or mouse) is down on the visual
     * @param info The info related to this pointer event
     */
    @event function pointerDown(info:TouchInfo);

    /**
     * Fired when a pointer (touch or mouse) was down on the visual and is not anymore
     * @param info The info related to this pointer event
     */
    @event function pointerUp(info:TouchInfo);

    /**
     * Fired when a pointer (touch or mouse) is over the visual
     * @param info The info related to this pointer event
     */
    @event function pointerOver(info:TouchInfo);

    /**
     * Fired when a pointer (touch or mouse) was over the visual and is not anymore
     * @param info The info related to this pointer event
     */
    @event function pointerOut(info:TouchInfo);

    /**
     * Fired when this visual gains focus (after handling a pointer event)
     */
    @event function focus();

    /**
     * Fired when this visual loses focus
     */
    @event function blur();

    inline function willListenPointerOver()
        @:privateAccess ceramic.App.app.screen.visualsListenPointerOver = true;

#if plugin_arcade

/// Arcade physics

    /**
     * The arcade physics body bound to this visual.
     */
    @:plugin('arcade')
    public var arcade(default,set):VisualArcadePhysics = null;
    function set_arcade(arcade:VisualArcadePhysics):VisualArcadePhysics {
        if (this.arcade == arcade) return arcade;
        if (this.arcade != null && this.arcade.visual == this) {
            this.arcade.visual = null;
        }
        this.arcade = arcade;
        if (arcade != null) {
            arcade.visual = this;
        }
        return arcade;
    }

    /**
     * Init arcade physics (body) bound to this visual.
     * @param world
     *      (optional) A world instance where the body will be attached.
     *      If none is provided, default world (app.arcade.world) will be used.
     * @return A `VisualArcadePhysics` instance
     */
    @:plugin('arcade')
    public function initArcadePhysics(?world:ArcadeWorld):VisualArcadePhysics {

        if (arcade != null) {
            arcade.destroy();
            arcade = null;
        }

        var w = width * scaleX;
        var h = height * scaleY;

        arcade = new VisualArcadePhysics();
        arcade.initBody(
            x - w * anchorX,
            y - h * anchorY,
            w,
            h,
            rotation
        );

        if (world == null) {
            world = ceramic.App.app.arcade.world;
        }
        arcade.world = world;

        return arcade;

    }

    #if !ceramic_no_arcade_shortcuts

    /**
     * The arcade physics body linked to this visual
     */
    @:plugin('arcade')
    public var body(get,never):arcade.Body;
    inline function get_body():arcade.Body {
        return arcade != null ? arcade.body : null;
    }

    /**
     * Allow this visual to be rotated by arcade physics, via `angularVelocity`, etc...
     */
    @:plugin('arcade')
    public var allowRotation(get,set):Bool;
    inline function get_allowRotation():Bool {
        return arcade != null && arcade.body != null ? arcade.body.allowRotation : true;
    }
    inline function set_allowRotation(allowRotation:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.allowRotation = allowRotation;
        return allowRotation;
    }

    /**
     * An immovable visual will not receive any impacts from other visual bodies. **Two** immovable visuas can't separate or exchange momentum and will pass through each other.
     */
    @:plugin('arcade')
    public var immovable(get,set):Bool;
    inline function get_immovable():Bool {
        return arcade != null && arcade.body != null ? arcade.body.immovable : false;
    }
    inline function set_immovable(immovable:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.immovable = immovable;
        return immovable;
    }

    /**
     * If set to `true`, arcade world will always separate on the X axis before Y when this body is involved. Otherwise it will check gravity totals first.
     */
    @:plugin('arcade')
    public var forceX(get,set):Bool;
    inline function get_forceX():Bool {
        return arcade != null && arcade.body != null ? arcade.body.forceX : false;
    }
    inline function set_forceX(forceX:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.forceX = forceX;
        return forceX;
    }

    /**
     * The x velocity, or rate of change the visual position. Measured in points per second.
     */
    @:plugin('arcade')
    public var velocityX(get,set):Float;
    inline function get_velocityX():Float {
        return arcade != null && arcade.body != null ? arcade.body.velocityX : 0;
    }
    inline function set_velocityX(velocityX:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.velocityX = velocityX;
        return velocityX;
    }

    /**
     * The y velocity, or rate of change the visual position. Measured in points per second.
     */
    @:plugin('arcade')
    public var velocityY(get,set):Float;
    inline function get_velocityY():Float {
        return arcade != null && arcade.body != null ? arcade.body.velocityY : 0;
    }
    inline function set_velocityY(velocityY:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.velocityY = velocityY;
        return velocityY;
    }

    /**
     * Set velocity, or rate of change of the visual position. Measured in points per second.
     * @param velocityX The velocity on **x** axis
     * @param velocityY The velocity on **y** axis
     */
    @:plugin('arcade')
    inline public function velocity(velocityX:Float, velocityY:Float):Void {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) {
            arcade.body.velocityX = velocityX;
            arcade.body.velocityY = velocityY;
        }
    }

    /**
     * The maximum x velocity that the visual can reach.
     */
    @:plugin('arcade')
    public var maxVelocityX(get,set):Float;
    inline function get_maxVelocityX():Float {
        return arcade != null && arcade.body != null ? arcade.body.maxVelocityX : 10000;
    }
    inline function set_maxVelocityX(maxVelocityX:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.maxVelocityX = maxVelocityX;
        return maxVelocityX;
    }

    /**
     * The maximum y velocity that the visual can reach.
     */
    @:plugin('arcade')
    public var maxVelocityY(get,set):Float;
    inline function get_maxVelocityY():Float {
        return arcade != null && arcade.body != null ? arcade.body.maxVelocityY : 10000;
    }
    inline function set_maxVelocityY(maxVelocityY:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.maxVelocityY = maxVelocityY;
        return maxVelocityY;
    }

    /**
     * Set maximum velocity that the visual can reach.
     * @param maxVelocityX The max velocity on **x** axis
     * @param maxVelocityY The max velocity on **y** axis
     */
    @:plugin('arcade')
    inline public function maxVelocity(maxVelocityX:Float, maxVelocityY:Float):Void {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) {
            arcade.body.maxVelocityX = maxVelocityX;
            arcade.body.maxVelocityY = maxVelocityY;
        }
    }

    /**
     * The x acceleration is the rate of change of the x velocity. Measured in points per second squared.
     */
    @:plugin('arcade')
    public var accelerationX(get,set):Float;
    inline function get_accelerationX():Float {
        return arcade != null && arcade.body != null ? arcade.body.accelerationX : 0;
    }
    inline function set_accelerationX(accelerationX:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.accelerationX = accelerationX;
        return accelerationX;
    }

    /**
     * The y acceleration is the rate of change of the y velocity. Measured in points per second squared.
     */
    @:plugin('arcade')
    public var accelerationY(get,set):Float;
    inline function get_accelerationY():Float {
        return arcade != null && arcade.body != null ? arcade.body.accelerationY : 0;
    }
    inline function set_accelerationY(accelerationY:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.accelerationY = accelerationY;
        return accelerationY;
    }

    /**
     * Set acceleration, which is the rate of change of the velocity. Measured in points per second squared.
     * @param accelerationX The acceleration on **x** axis
     * @param accelerationY The acceleration on **y** axis
     */
    @:plugin('arcade')
    inline public function acceleration(accelerationX:Float, accelerationY:Float):Void {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) {
            arcade.body.accelerationX = accelerationX;
            arcade.body.accelerationY = accelerationY;
        }
    }

    /**
     * Allow this visual to be influenced by drag
     */
    @:plugin('arcade')
    public var allowDrag(get,set):Bool;
    inline function get_allowDrag():Bool {
        return arcade != null && arcade.body != null ? arcade.body.allowDrag : true;
    }
    inline function set_allowDrag(allowDrag:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.allowDrag = allowDrag;
        return allowDrag;
    }

    /**
     * The x drag is the rate of reduction of the x velocity, kind of deceleration. Measured in points per second squared.
     */
    @:plugin('arcade')
    public var dragX(get,set):Float;
    inline function get_dragX():Float {
        return arcade != null && arcade.body != null ? arcade.body.dragX : 0;
    }
    inline function set_dragX(dragX:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.dragX = dragX;
        return dragX;
    }

    /**
     * The y drag is the rate of reduction of the y velocity, kind of deceleration. Measured in points per second squared.
     */
    @:plugin('arcade')
    public var dragY(get,set):Float;
    inline function get_dragY():Float {
        return arcade != null && arcade.body != null ? arcade.body.dragY : 0;
    }
    inline function set_dragY(dragY:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.dragY = dragY;
        return dragY;
    }

    /**
     * Set drag, which is the rate of reduction of the velocity, kind of deceleration. Measured in points per second squared.
     * @param dragX The drag value on **x** axis
     * @param dragY The drag value on **y** axis
     */
    @:plugin('arcade')
    inline public function drag(dragX:Float, dragY:Float):Void {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) {
            arcade.body.dragX = dragX;
            arcade.body.dragY = dragY;
        }
    }

    /**
     * The x elasticity of the visual when colliding. `bounceX = 1` means full rebound, `bounceX = 0.5` means 50% rebound velocity.
     */
    @:plugin('arcade')
    public var bounceX(get,set):Float;
    inline function get_bounceX():Float {
        return arcade != null && arcade.body != null ? arcade.body.bounceX : 0;
    }
    inline function set_bounceX(bounceX:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.bounceX = bounceX;
        return bounceX;
    }

    /**
     * The y elasticity of the visual when colliding. `bounceY = 1` means full rebound, `bounceY = 0.5` means 50% rebound velocity.
     */
    @:plugin('arcade')
    public var bounceY(get,set):Float;
    inline function get_bounceY():Float {
        return arcade != null && arcade.body != null ? arcade.body.bounceY : 0;
    }
    inline function set_bounceY(bounceY:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.bounceY = bounceY;
        return bounceY;
    }

    /**
     * Set elasticity of the visual when colliding. `1` means full rebound, `0.5` means 50% rebound velocity.
     * @param bounceX The bounce value on **x** axis
     * @param bounceY The bounce value on **y** axis
     */
    @:plugin('arcade')
    inline public function bounce(bounceX:Float, bounceY:Float):Void {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) {
            arcade.body.bounceX = bounceX;
            arcade.body.bounceY = bounceY;
        }
    }

    /**
     * Enable or disable world bounds specific bounce value with `worldBounceX` and `worldBounceY`.
     * Disabled by default, meaning `bounceX` and `bounceY` are used by default.
     */
    @:plugin('arcade')
    public var useWorldBounce(get,set):Bool;
    inline function get_useWorldBounce():Bool {
        return arcade != null && arcade.body != null ? arcade.body.useWorldBounce : false;
    }
    inline function set_useWorldBounce(useWorldBounce:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.useWorldBounce = useWorldBounce;
        return useWorldBounce;
    }

    /**
     * The x elasticity of the visual when colliding with world bounds. Ignored if `useWorldBounce` is `false` (`bounceX` used instead).
     */
    @:plugin('arcade')
    public var worldBounceX(get,set):Float;
    inline function get_worldBounceX():Float {
        return arcade != null && arcade.body != null ? arcade.body.worldBounceX : 0;
    }
    inline function set_worldBounceX(worldBounceX:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.worldBounceX = worldBounceX;
        return worldBounceX;
    }

    /**
     * The y elasticity of the visual when colliding with world bounds. Ignored if `useWorldBounce` is `false` (`bounceY` used instead).
     */
    @:plugin('arcade')
    public var worldBounceY(get,set):Float;
    inline function get_worldBounceY():Float {
        return arcade != null && arcade.body != null ? arcade.body.worldBounceY : 0;
    }
    inline function set_worldBounceY(worldBounceY:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.worldBounceY = worldBounceY;
        return worldBounceY;
    }

    /**
     * The elasticity of the visual when colliding with world bounds. Ignored if `useWorldBounce` is `false` (`bounceY` used instead).
     * @param worldBounceX The elasticity value on **x** axis
     * @param worldBounceY The elasticity value on **y** axis
     */
    @:plugin('arcade')
    inline public function worldBounce(worldBounceX:Float, worldBounceY:Float):Void {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) {
            arcade.body.worldBounceX = worldBounceX;
            arcade.body.worldBounceY = worldBounceY;
        }
    }

    /**
     * The maximum x delta per frame. `0` (default) means no maximum delta.
     */
    @:plugin('arcade')
    public var maxDeltaX(get,set):Float;
    inline function get_maxDeltaX():Float {
        return arcade != null && arcade.body != null ? arcade.body.maxDeltaX : 0;
    }
    inline function set_maxDeltaX(maxDeltaX:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.maxDeltaX = maxDeltaX;
        return maxDeltaX;
    }

    /**
     * The maximum y delta per frame. `0` (default) means no maximum delta.
     */
    @:plugin('arcade')
    public var maxDeltaY(get,set):Float;
    inline function get_maxDeltaY():Float {
        return arcade != null && arcade.body != null ? arcade.body.maxDeltaY : 0;
    }
    inline function set_maxDeltaY(maxDeltaY:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.maxDeltaY = maxDeltaY;
        return maxDeltaY;
    }

    /**
     * The max delta, or rate of change the visual position. Measured in points per second.
     * @param maxDeltaX The max delta value on **x** axis
     * @param maxDeltaY The max delta value on **y** axis
     */
    @:plugin('arcade')
    inline public function maxDelta(maxDeltaX:Float, maxDeltaY:Float):Void {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) {
            arcade.body.maxDeltaX = maxDeltaX;
            arcade.body.maxDeltaY = maxDeltaY;
        }
    }

    /**
     * Allow this visual to be influenced by gravity, either world or local.
     */
    @:plugin('arcade')
    public var allowGravity(get,set):Bool;
    inline function get_allowGravity():Bool {
        return arcade != null && arcade.body != null ? arcade.body.allowGravity : false;
    }
    inline function set_allowGravity(allowGravity:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.allowGravity = allowGravity;
        return allowGravity;
    }

    /**
     * This visual's local y gravity, **added** to any world gravity, unless `allowGravity` is set to false.
     */
    @:plugin('arcade')
    public var gravityX(get,set):Float;
    inline function get_gravityX():Float {
        return arcade != null && arcade.body != null ? arcade.body.gravityX : 0;
    }
    inline function set_gravityX(gravityX:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.gravityX = gravityX;
        return gravityX;
    }

    /**
     * This visual's local x gravity, **added** to any world gravity, unless `allowGravity` is set to false.
     */
    @:plugin('arcade')
    public var gravityY(get,set):Float;
    inline function get_gravityY():Float {
        return arcade != null && arcade.body != null ? arcade.body.gravityY : 0;
    }
    inline function set_gravityY(gravityY:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.gravityY = gravityY;
        return gravityY;
    }

    /**
     * This visual's local gravity, **added** to any world gravity, unless `allowGravity` is set to false.
     * @param gravityX The gravity on **x** axis
     * @param gravityY The gravity on **y** axis
     */
    @:plugin('arcade')
    inline public function gravity(gravityX:Float, gravityY:Float):Void {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) {
            arcade.body.gravityX = gravityX;
            arcade.body.gravityY = gravityY;
        }
    }

    /**
     * If this visual is `immovable` and moving, and another visual body is 'riding' this one, this is the amount of motion the riding body receives on **x** axis.
     */
    @:plugin('arcade')
    public var frictionX(get,set):Float;
    inline function get_frictionX():Float {
        return arcade != null && arcade.body != null ? arcade.body.frictionX : 1;
    }
    inline function set_frictionX(frictionX:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.frictionX = frictionX;
        return frictionX;
    }

    /**
     * If this visual is `immovable` and moving, and another visual body is 'riding' this one, this is the amount of motion the riding body receives on **y** axis.
     */
    @:plugin('arcade')
    public var frictionY(get,set):Float;
    inline function get_frictionY():Float {
        return arcade != null && arcade.body != null ? arcade.body.frictionY : 0;
    }
    inline function set_frictionY(frictionY:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.frictionY = frictionY;
        return frictionY;
    }

    /**
     * If this visual is `immovable` and moving, and another visual body is 'riding' this one, this is the amount of motion the riding body receives on x & y axis.
     * @param frictionX The friction on **x** axis
     * @param frictionY The friction on **y** axis
     */
    @:plugin('arcade')
    inline public function friction(frictionX:Float, frictionY:Float):Void {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) {
            arcade.body.frictionX = frictionX;
            arcade.body.frictionY = frictionY;
        }
    }

    /**
     * The angular velocity is the rate of change of the visual's rotation. It is measured in degrees per second.
     */
    @:plugin('arcade')
    public var angularVelocity(get,set):Float;
    inline function get_angularVelocity():Float {
        return arcade != null && arcade.body != null ? arcade.body.angularVelocity : 0;
    }
    inline function set_angularVelocity(angularVelocity:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.angularVelocity = angularVelocity;
        return angularVelocity;
    }

    /**
     * The maximum angular velocity in degrees per second that the visual can reach.
     */
    @:plugin('arcade')
    public var maxAngularVelocity(get,set):Float;
    inline function get_maxAngularVelocity():Float {
        return arcade != null && arcade.body != null ? arcade.body.maxAngularVelocity : 1000;
    }
    inline function set_maxAngularVelocity(maxAngularVelocity:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.maxAngularVelocity = maxAngularVelocity;
        return maxAngularVelocity;
    }

    /**
     * The angular acceleration is the rate of change of the angular velocity. Measured in degrees per second squared.
     */
    @:plugin('arcade')
    public var angularAcceleration(get,set):Float;
    inline function get_angularAcceleration():Float {
        return arcade != null && arcade.body != null ? arcade.body.angularAcceleration : 0;
    }
    inline function set_angularAcceleration(angularAcceleration:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.angularAcceleration = angularAcceleration;
        return angularAcceleration;
    }

    /**
     * The angular drag is the rate of reduction of the angular velocity. Measured in degrees per second squared.
     */
    @:plugin('arcade')
    public var angularDrag(get,set):Float;
    inline function get_angularDrag():Float {
        return arcade != null && arcade.body != null ? arcade.body.angularDrag : 0;
    }
    inline function set_angularDrag(angularDrag:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.angularDrag = angularDrag;
        return angularDrag;
    }

    /**
     * The mass of the visual's body. When two bodies collide their mass is used in the calculation to determine the exchange of velocity.
     */
    @:plugin('arcade')
    public var mass(get,set):Float;
    inline function get_mass():Float {
        return arcade != null && arcade.body != null ? arcade.body.mass : 1;
    }
    inline function set_mass(mass:Float):Float {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.mass = mass;
        return mass;
    }

    /**
     * The speed of the visual's body (read only). Equal to the magnitude of the velocity.
     */
    @:plugin('arcade')
    public var speed(get,never):Float;
    inline function get_speed():Float {
        return arcade != null && arcade.body != null ? arcade.body.speed : 0;
    }

    /**
     * Whether the physics system should update the visual's position and rotation based on its velocity, acceleration, drag, and gravity.
     */
    @:plugin('arcade')
    public var moves(get,set):Bool;
    inline function get_moves():Bool {
        return arcade != null && arcade.body != null ? arcade.body.moves : false;
    }
    inline function set_moves(moves:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.moves = moves;
        return moves;
    }

    /**
     * When this visual's body collides with another, the amount of overlap (x axis) is stored here.
     */
    @:plugin('arcade')
    public var overlapX(get,never):Float;
    inline function get_overlapX():Float {
        return arcade != null && arcade.body != null ? arcade.body.overlapX : 1;
    }

    /**
     * When this visual's body collides with another, the amount of overlap (y axis) is stored here.
     */
    @:plugin('arcade')
    public var overlapY(get,never):Float;
    inline function get_overlapY():Float {
        return arcade != null && arcade.body != null ? arcade.body.overlapY : 0;
    }

    /**
     * If a visual's body is overlapping with another body, but neither of them are moving (maybe they spawned on-top of each other?) this is set to `true`.
     */
    @:plugin('arcade')
    public var embedded(get,never):Bool;
    inline function get_embedded():Bool {
        return arcade != null && arcade.body != null ? arcade.body.embedded : false;
    }

    /**
     * A visual body can be set to collide against the world bounds automatically and rebound back into the world if this is set to true. Otherwise it will leave the world.
     */
    @:plugin('arcade')
    public var collideWorldBounds(get,never):Bool;
    inline function get_collideWorldBounds():Bool {
        return arcade != null && arcade.body != null ? arcade.body.collideWorldBounds : false;
    }
    inline function set_collideWorldBounds(collideWorldBounds:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        if (arcade.body != null) arcade.body.collideWorldBounds = collideWorldBounds;
        return collideWorldBounds;
    }

    #if (documentation || completion)

    /**
     * Dispatched when this visual body collides with another visual's body.
     * @param visual1 This visual
     * @param visual2 The other colliding visual
     */
    @event function collide(visual1:Visual, visual2:Visual);

    /**
     * Dispatched when this visual body overlaps with another visual's body.
     * @param visual1 This visual
     * @param visual2 The other overlapping visual
     */
    @event function overlap(visual1:Visual, visual2:Visual);

    /**
     * Dispatched when this visual body collides with another body.
     * @param visual This visual
     * @param body The other colliding body
     */
    @event function collideBody(visual:Visual, body:arcade.Body);

    /**
     * Dispatched when this visual body overlaps with another body.
     * @param visual The visual
     * @param body The other overlapping body
     */
    @event function overlapBody(visual:Visual, body:arcade.Body);

    /**
     * Dispatched when this visual body collides with the world bounds.
     * @param visual This visual
     * @param up `true` if visual collides up with bounds
     * @param down `true` if visual collides down with bounds
     * @param left `true` if visual collides left with bounds
     * @param right `true` if visual collides right with bounds
     */
    @event function worldBounds(visual:Visual, up:Bool, down:Bool, left:Bool, right:Bool);

    #else

    @:plugin('arcade')
    inline public function onCollide(owner:Entity, handleVisual1Visual2:(visual1:Visual,visual2:Visual)->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onCollide(owner, handleVisual1Visual2);
    }

    @:plugin('arcade')
    inline public function onceCollide(owner:Entity, handleVisual1Visual2:(visual1:Visual,visual2:Visual)->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onceCollide(owner, handleVisual1Visual2);
    }

    @:plugin('arcade')
    inline public function offCollide(?handleVisual1Visual2:(visual1:Visual,visual2:Visual)->Void):Void {
        if (arcade != null) {
            arcade.offCollide(handleVisual1Visual2);
        }
    }

    @:plugin('arcade')
    inline public function listensCollide():Bool {
        return arcade != null ? arcade.listensCollide() : false;
    }

    @:plugin('arcade')
    inline public function onCollideBody(owner:Entity, handleVisualBody:(visual:Visual,body:arcade.Body)->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onCollideBody(owner, handleVisualBody);
    }

    @:plugin('arcade')
    inline public function onceCollideBody(owner:Entity, handleVisualBody:(visual:Visual,body:arcade.Body)->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onceCollideBody(owner, handleVisualBody);
    }

    @:plugin('arcade')
    inline public function offCollideBody(?handleVisualBody:(visual:Visual,body:arcade.Body)->Void):Void {
        if (arcade != null) {
            arcade.offCollideBody(handleVisualBody);
        }
    }

    @:plugin('arcade')
    inline public function listensCollideBody():Bool {
        return arcade != null ? arcade.listensCollideBody() : false;
    }

    @:plugin('arcade')
    inline public function onOverlap(owner:Entity, handleVisual1Visual2:(visual1:Visual,visual2:Visual)->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onOverlap(owner, handleVisual1Visual2);
    }

    @:plugin('arcade')
    inline public function onceOverlap(owner:Entity, handleVisual1Visual2:(visual1:Visual,visual2:Visual)->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onceOverlap(owner, handleVisual1Visual2);
    }

    @:plugin('arcade')
    inline public function offOverlap(?handleVisual1Visual2:(visual1:Visual,visual2:Visual)->Void):Void {
        if (arcade != null) {
            arcade.offOverlap(handleVisual1Visual2);
        }
    }

    @:plugin('arcade')
    inline public function listensOverlap():Bool {
        return arcade != null ? arcade.listensOverlap() : false;
    }

    @:plugin('arcade')
    inline public function onOverlapBody(owner:Entity, handleVisualBody:(visual:Visual,body:arcade.Body)->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onOverlapBody(owner, handleVisualBody);
    }

    @:plugin('arcade')
    inline public function onceOverlapBody(owner:Entity, handleVisualBody:(visual:Visual,body:arcade.Body)->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onceOverlapBody(owner, handleVisualBody);
    }

    @:plugin('arcade')
    inline public function offOverlapBody(?handleVisualBody:(visual:Visual,body:arcade.Body)->Void):Void {
        if (arcade != null) {
            arcade.offOverlapBody(handleVisualBody);
        }
    }

    @:plugin('arcade')
    inline public function listensOverlapBody():Bool {
        return arcade != null ? arcade.listensOverlapBody() : false;
    }

    @:plugin('arcade')
    inline public function onWorldBounds(owner:Entity, handleVisualUpDownLeftRight:(visual:Visual,up:Bool,down:Bool,left:Bool,right:Bool)->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onWorldBounds(owner, handleVisualUpDownLeftRight);
    }

    @:plugin('arcade')
    inline public function onceWorldBounds(owner:Entity, handleVisualUpDownLeftRight:(visual:Visual,up:Bool,down:Bool,left:Bool,right:Bool)->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onceWorldBounds(owner, handleVisualUpDownLeftRight);
    }

    @:plugin('arcade')
    inline public function offWorldBounds(?handleVisualUpDownLeftRight:(visual:Visual,up:Bool,down:Bool,left:Bool,right:Bool)->Void):Void {
        if (arcade != null) {
            arcade.offWorldBounds(handleVisualUpDownLeftRight);
        }
    }

    @:plugin('arcade')
    inline public function listensWorldBounds():Bool {
        return arcade != null ? arcade.listensWorldBounds() : false;
    }

    #end

    #end

#end

#if plugin_nape

/// Nape physics

    /**
     * The nape physics (body) of this visual.
     */
    @:plugin('nape')
    public var nape(default,set):VisualNapePhysics = null;
    function set_nape(nape:VisualNapePhysics):VisualNapePhysics {
        if (this.nape == nape) return nape;
        if (this.nape != null && this.nape.visual == this) {
            this.nape.visual = null;
        }
        this.nape = nape;
        if (nape != null) {
            nape.visual = this;
        }
        return nape;
    }

    /**
     * Init nape physics body bound to this visual.
     * @param type Physics body type (`STATIC`, `KINEMATIC` or `DYNAMIC`)
     * @param space (optional) Related nape spaces. Will use default space if not provided.
     * @param shape (optional) Shape used for this body. Default is a box matching visual bounds.
     * @param shapes (optional) Array of shapes used for this body.
     * @param material (optional) A custom material to use with this body.
     * @return A `VisualNapePhysics` instance
     */
    @:plugin('nape')
    public function initNapePhysics(
        type:ceramic.NapePhysicsBodyType,
        ?space:nape.space.Space,
        ?shape:nape.shape.Shape,
        ?shapes:Array<nape.shape.Shape>,
        ?material:nape.phys.Material
    ):VisualNapePhysics {

        if (nape != null) {
            nape.destroy();
            nape = null;
        }

        if (contentDirty) {
            computeContent();
        }

        var w = width * scaleX;
        var h = height * scaleY;

        nape = new VisualNapePhysics(
            type,
            shape,
            shapes,
            material,
            x - w * (anchorX - 0.5),
            y - h * (anchorY - 0.5),
            w,
            h,
            rotation
        );

        if (space == null) {
            space = ceramic.App.app.nape.space;
        }
        nape.body.space = space;

        return nape;

    }

#end

/// Access as specific types

    /**
     * Get this visual typed as `Quad` or null if it isn't a `Quad`
     */
    public var asQuad:Quad = null;

    /**
     * Get this visual typed as `Mesh` or null if it isn't a `Mesh`
     */
    public var asMesh:Mesh = null;

/// Properties

    /**
     * When enabled, this visual will receive as many up/down/click/over/out events as
     * there are fingers or mouse pointer interacting with it.
     * Default is `false`, ensuring there is never multiple up/down/click/over/out that
     * overlap each other. In that case, it triggers `pointer down` when the first finger/pointer hits
     * the visual and trigger `pointer up` when the last finger/pointer stops touching it. Behavior is
     * similar for `pointer over` and `pointer out` events.
     */
    public var multiTouch:Bool = false;

    /**
     * Whether this visual is between a `pointer down` and an `pointer up` event or not.
     */
    public var isPointerDown(get,null):Bool;
    var _numPointerDown:Int = 0;
    inline function get_isPointerDown():Bool { return _numPointerDown > 0; }

    /**
     * Whether this visual is between a `pointer over` and an `pointer out` event or not.
     */
    public var isPointerOver(get,null):Bool;
    var _numPointerOver:Int = 0;
    inline function get_isPointerOver():Bool { return _numPointerOver > 0; }

    /**
     * Use the given visual's bounds as clipping area for itself and **every children**.
     * Clipping areas cannot be combined. That means if `clip` is not null and current
     * visual instance is already clipped by a parent visual, its children's won't be clipped
     * by it anymore as they are instead clipped by this `clip` property instead.
     */
    public var clip(default,set):Visual = null;
    inline function set_clip(clip:Visual):Visual {
        if (this.clip == clip) return clip;
        this.clip = clip;
        clipDirty = true;
        return clip;
    }

    /**
     * Whether this visual should inherit its parent alpha value or not.
     * If it inherits, parent alpha value will be multiplied with current visual's own `alpha` property.
     */
    public var inheritAlpha(default,set):Bool = false;
    inline function set_inheritAlpha(inheritAlpha:Bool):Bool {
        if (this.inheritAlpha == inheritAlpha) return inheritAlpha;
        this.inheritAlpha = inheritAlpha;
        visibilityDirty = true;
        return inheritAlpha;
    }

    /**
     * Stop this visual, whatever that means (override in subclasses).
     * When arcade physics are enabled, visual's body is stopped from this call.
     */
    public function stop():Void {
#if plugin_arcade
        if (arcade != null) arcade.body.stop();
#end
    }

#if ceramic_wireframe

    public var wireframe(get,set):Bool;
    inline function get_wireframe():Bool {
        // Equivalent to internalFlag(7)
        return flags & FLAG_RENDER_WIREFRAME == FLAG_RENDER_WIREFRAME;
    }
    inline function set_wireframe(wireframe:Bool):Bool {
        // Equivalent to internalFlag(7, isHitVisual)
        flags = wireframe ? flags | FLAG_RENDER_WIREFRAME : flags & ~FLAG_RENDER_WIREFRAME;
        return wireframe;
    }

#end

#if ceramic_luxe_legacy

    /**
     * Allows the backend to keep data associated with this visual.
     */
    public var backendItem:VisualItem;

#end

    /**
     * Computed flag that tells whether this visual is only translated,
     * thus not rotated, skewed nor scaled.
     * When this is `true`, matrix computation may be a bit faster as it
     * will skip some unneeded matrix computation.
     */
    public var translatesOnly:Bool = true;

    /**
     * Whether we should re-check if this visual is only translating or having a more complex transform
     */
    public var translatesOnlyDirty:Bool = false;

    /**
     * Setting this to true will force the visual to recompute its displayed content
     */
    public var contentDirty(default, set):Bool = true;
    inline function set_contentDirty(contentDirty:Bool):Bool {
        this.contentDirty = contentDirty;
        if (contentDirty) {
            ceramic.App.app.visualsContentDirty = true;
        }
        return contentDirty;
    }

    /**
     * Setting this to true will force the visual's matrix to be re-computed
     */
    public var matrixDirty(default,set):Bool = true;
    inline function set_matrixDirty(matrixDirty:Bool):Bool {
        this.matrixDirty = matrixDirty;
        if (matrixDirty) {
            if (children != null) {
                for (i in 0...children.length) {
                    var child = children.unsafeGet(i);
                    child.matrixDirty = true;
                }
            }
        }
        return matrixDirty;
    }

    /**
     * Setting this to true will force the visual's computed render target to be re-computed
     */
    public var renderTargetDirty(default,set):Bool = true;
    inline function set_renderTargetDirty(renderTargetDirty:Bool):Bool {
        this.renderTargetDirty = renderTargetDirty;
        if (renderTargetDirty) {
            clipDirty = true;
            if (children != null) {
                for (i in 0...children.length) {
                    var child = children.unsafeGet(i);
                    child.renderTargetDirty = true;
                }
            }
        }
        return renderTargetDirty;
    }

    /**
     * Setting this to true will force the visual to compute it's visility in hierarchy
     */
    public var visibilityDirty(default,set):Bool = true;
    inline function set_visibilityDirty(visibilityDirty:Bool):Bool {
        this.visibilityDirty = visibilityDirty;
        if (visibilityDirty) {
            if (children != null) {
                for (i in 0...children.length) {
                    var child = children.unsafeGet(i);
                    child.visibilityDirty = true;
                }
            }
        }
        return visibilityDirty;
    }

    /**
     * Setting this to true will force the visual to compute it's touchability in hierarchy
     */
    public var touchableDirty(default,set):Bool = true;
    inline function set_touchableDirty(touchableDirty:Bool):Bool {
        this.touchableDirty = touchableDirty;
        if (touchableDirty) {
            if (children != null) {
                for (i in 0...children.length) {
                    var child = children.unsafeGet(i);
                    child.touchableDirty = true;
                }
            }
        }
        return touchableDirty;
    }

    /**
     * Setting this to true will force the visual to compute it's clipping state in hierarchy
     */
    public var clipDirty(default,set):Bool = true;
    inline function set_clipDirty(clipDirty:Bool):Bool {
        this.clipDirty = clipDirty;
        if (clipDirty) {
            if (children != null) {
                for (i in 0...children.length) {
                    var child = children.unsafeGet(i);
                    child.clipDirty = true;
                }
            }
        }
        return clipDirty;
    }
    /**
     * If set, the visual will be rendered into this target RenderTexture instance
     * instead of being drawn onto screen directly.
     */
    public var renderTarget(default,set):RenderTexture = null;
    function set_renderTarget(renderTarget:RenderTexture):RenderTexture {
        if (this.renderTarget == renderTarget) return renderTarget;
        this.renderTarget = renderTarget;
        matrixDirty = true;
        renderTargetDirty = true;
        return renderTarget;
    }

    public var blending(default,set):Blending = Blending.AUTO;
    function set_blending(blending:Blending):Blending {
        return this.blending = blending;
    }

    /**
     * Set to `false` to make this visual (and all of its children) invisible and not rendered.
     */
    public var visible(default,set):Bool = true;
    function set_visible(visible:Bool):Bool {
        if (this.visible == visible) return visible;
        this.visible = visible;
        visibilityDirty = true;
        return visible;
    }

    /**
     * Set to `false` to make this visual (and all of its children) not touchable
     */
    public var touchable(default,set):Bool = true;
    function set_touchable(touchable:Bool):Bool {
        if (this.touchable == touchable) return touchable;
        this.touchable = touchable;
        touchableDirty = true;
        return touchable;
    }

    /**
     * Set this visual's depth.
     * Visuals are rendered from back to front of the screen.
     * Given two visuals, a visual with higher depth will be rendered **above** a visual with lower depth.
     * In practice, it is advised to use integer values like `1`, `2`, `3`... to order your visuals,
     * like you would do with z-index on CSS elements.
     */
    public var depth(default,set):Float = 0;
    function set_depth(depth:Float):Float {
        if (this.depth == depth) return depth;
        this.depth = depth;
        ceramic.App.app.hierarchyDirty = true;
        return depth;
    }

    /**
     * If set to `1` (default), children will be sort by depth and their computed depth
     * will be within range [parent.depth, parent.depth + depthRange].
     * You'll usually won't need to change this value,
     * unless you want to do advanced drawing where different
     * hierarchies of visuals are blending with each other.
     *
     * ```haxe
     * // Children computed depths will be relative to their parent visual depth.
     * // This is the default value and recommended approach in most situations as
     * // its behaviour is similar to display trees, z-index etc...
     * visual.depthRange = 1;
     *
     * // More advanced, two visuals: visual2 above visual1 because of higher depth, but
     * // visual1's depth range is `8`, so its children computed depths will be distributed
     * // between `1` and `1 + 8` (9 excluded). That means some of visual1's children
     * // can be above visual2's children. Can be useful on some specific edge cases,
     * // but not recommended in general.
     * visual1.depthRange = 8;
     * visual1.depth = 1;
     * visual2.depth = 2;
     *
     * // Another case: two visuals with the same depth and depthRange.
     * // There children will share the same computed depth space, so a child of visual1 at `depth = 6`
     * // will be above a child of visual2 at `depth = 4`.
     * // Resulting computed depths will be between `1` and `1 + 16` (17 excluded).
     * visual1.depthRange = 16
     * visual2.depthRange = 16
     * visual1.depth = 1;
     * visual2.depth = 1;
     *
     * // Children computed depths won't be relative to their parent visual depth.
     * // Instead, it will be relative to the higher parent (of the parent) in hierarchy that has a positive `depthRange` value,
     * visual.depthRange = -1;
     * ```
     */
        #if ceramic_no_depth_range
    public var depthRange(default,set):Float = -1;
    #else
    public var depthRange(default,set):Float = 1;
    #end
    function set_depthRange(depthRange:Float):Float {
        if (this.depthRange == depthRange) return depthRange;
        this.depthRange = depthRange;
        ceramic.App.app.hierarchyDirty = true;
        return depthRange;
    }

    /**
     * The **x** position of this visual.
     * Relative to its parent, or screen if this visual has no parent.
     */
    public var x(default,set):Float = 0;
    function set_x(x:Float):Float {
        if (this.x == x) return x;
        this.x = x;
        matrixDirty = true;
        return x;
    }

    /**
     * The **y** position of this visual.
     * Relative to its parent, or screen if this visual has no parent.
     */
    public var y(default,set):Float = 0;
    function set_y(y:Float):Float {
        if (this.y == y) return y;
        this.y = y;
        matrixDirty = true;
        return y;
    }

    /**
     * The **scaleX** value of this visual.
     */
    public var scaleX(default,set):Float = 1;
    function set_scaleX(scaleX:Float):Float {
        if (this.scaleX == scaleX) return scaleX;
        this.scaleX = scaleX;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return scaleX;
    }

    /**
     * The **scaleY** value of this visual.
     */
    public var scaleY(default,set):Float = 1;
    function set_scaleY(scaleY:Float):Float {
        if (this.scaleY == scaleY) return scaleY;
        this.scaleY = scaleY;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return scaleY;
    }

    /**
     * The **skewX** value of this visual.
     */
    public var skewX(default,set):Float = 0;
    function set_skewX(skewX:Float):Float {
        if (this.skewX == skewX) return skewX;
        this.skewX = skewX;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return skewX;
    }

    /**
     * The **skewY** value of this visual.
     */
    public var skewY(default,set):Float = 0;
    function set_skewY(skewY:Float):Float {
        if (this.skewY == skewY) return skewY;
        this.skewY = skewY;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return skewY;
    }

    /**
     * The **anchorX** value of this visual.
     * Affects how position, scale, rotation and skew of the visual are rendered.
     * Default is `0`, which means: anchor relative to the **left** of the visual.
     * Use `1` to make it relative to the **right** of the visual, or `0.5` to make it
     * relative to the **horizontal center** of the visual.
     */
    public var anchorX(default,set):Float = 0;
    function set_anchorX(anchorX:Float):Float {
        if (this.anchorX == anchorX) return anchorX;
        this.anchorX = anchorX;
        matrixDirty = true;
        return anchorX;
    }

    /**
     * The **anchorY** value of this visual.
     * Affects how position, scale, rotation and skew of the visual are rendered.
     * Default is `0`, which means: anchor relative to the **top** of the visual.
     * Use `1` to make it relative to the **bottom** of the visual, or `0.5` to make it
     * relative to the **vertical center** of the visual.
     */
    public var anchorY(default,set):Float = 0;
    function set_anchorY(anchorY:Float):Float {
        if (this.anchorY == anchorY) return anchorY;
        this.anchorY = anchorY;
        matrixDirty = true;
        return anchorY;
    }

    /**
     * The **width** of the visual.
     * Default is `0`. Can be set to an explicit value.
     * Some subclasses of `Visual` are computing it automatically
     * like `Text` from its textual content or `Quad` when a texture is assigned to it.
     */
    public var width(get,set):Float;
    var _width:Float = 0;
    function get_width():Float {
        return _width;
    }
    function set_width(width:Float):Float {
        if (_width == width) return width;
        _width = width;
        if (anchorX != 0) matrixDirty = true;
        return width;
    }

    /**
     * The **height** of the visual.
     * Default is `0`. Can be set to an explicit value.
     * Some subclasses of `Visual` are computing it automatically
     * like `Text` from its textual content or `Quad` when a texture is assigned to it.
     */
    public var height(get,set):Float;
    var _height:Float = 0;
    function get_height():Float {
        return _height;
    }
    function set_height(height:Float):Float {
        if (_height == height) return height;
        _height = height;
        if (anchorY != 0) matrixDirty = true;
        return height;
    }

    /**
     * If set to a value above zero, matrix translation (tx & ty) will be rounded.
     *
     * ```haxe
     * roundTranslation = 0; // No rounding (default)
     * roundTranslation = 1; // Pixel perfect rounding
     * roundTranslation = 2; // Half-pixel rounding
     * ```
     *
     * May be useful to render pixel perfect scenes onto `ceramic.Filter`.
     */
    public var roundTranslation(default,set):Int = -1;
    function set_roundTranslation(roundTranslation:Int):Int {
        if (this.roundTranslation == roundTranslation) return roundTranslation;
        this.roundTranslation = roundTranslation;
        matrixDirty = true;
        return roundTranslation;
    }

    /**
     * Rotation of the visual in degrees.
     * The center of the rotation depends on `anchorX` and `anchorY`.
     */
    public var rotation(default,set):Float = 0;
    function set_rotation(rotation:Float):Float {
        if (this.rotation == rotation) return rotation;
        this.rotation = rotation;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return rotation;
    }

    /**
     * Alpha of the visual. Must be a value between `0` (transparent) and `1` (fully opaque)
     */
    public var alpha(default,set):Float = 1;
    function set_alpha(alpha:Float):Float {
        if (this.alpha == alpha) return alpha;
        this.alpha = alpha;
        visibilityDirty = true;
        return alpha;
    }

    /**
     * Visual X translation.
     * This is a shorthand equivalent to assigning a `Transform` object to
     * the visual with a `tx` value of `translateX`.
     * Only recommended for advanced usage as `x` property should be used in general instead.
     */
    public var translateX(get, set):Float;
    inline function get_translateX():Float {
        return transform != null ? transform.tx : 0;
    }
    inline function set_translateX(translateX:Float):Float {
        if (translateX == 0) {
            if (transform != null && transform.tx != 0) {
                transform.tx = 0;
                transform.changedDirty = true;
            }
        }
        else {
            if (transform == null) {
                transform = new Transform();
            }
            if (transform.tx != translateX) {
                transform.tx = translateX;
                transform.changedDirty = true;
            }
        }
        return translateX;
    }

    /**
     * Visual Y translation.
     * This is a shorthand equivalent to assigning a `Transform` object to
     * the visual with a `ty` value of `translateY`.
     * Only recommended for advanced usage as `y` property should be used in general instead.
     */
    public var translateY(get, set):Float;
    inline function get_translateY():Float {
        return transform != null ? transform.ty : 0;
    }
    inline function set_translateY(translateY:Float):Float {
        if (translateY == 0) {
            if (transform != null && transform.ty != 0) {
                transform.ty = 0;
                transform.changedDirty = true;
            }
        }
        else {
            if (transform == null) {
                transform = new Transform();
            }
            if (transform.ty != translateY) {
                transform.ty = translateY;
                transform.changedDirty = true;
            }
        }
        return translateY;
    }

    /**
     * Set additional matrix-based transform to this visual. Default is `null`.
     * A `Transform` object will affect of the visual is rendered.
     * The transform is applied after visual's properties (position, rotation, scale, skew).
     */
    public var transform(default,set):Transform = null;
    function set_transform(transform:Transform):Transform {
        if (this.transform == transform) return transform;

        if (this.transform != null) {
            this.transform.offChange(transformDidChange);
        }

        this.transform = transform;

        if (this.transform != null) {
            this.transform.onChange(this, transformDidChange);
        }

        matrixDirty = true;

        return transform;
    }

    /**
     * Assign a shader to this visual.
     * When none is assigned, default shader will be used.
     */
    public var shader(default, set):Shader = null;
    function set_shader(shader:Shader):Shader {
        return this.shader = shader;
    }

/// Flags

    /**
     * Read and write arbitrary boolean flags on this visual.
     * Index should be between 0 (included) and 16 (excluded) or result is undefined.
     * @param index The index of the flag to change, between 0 (included) and 16 (excluded)
     * @param value (optional) The boolean value to set, or no value to simply read current value
     * @return The existing value if just reading, or the new value if writing
     */
    inline public function flag(index:Int, ?value:Bool):Bool {

        var i = index + 16;
        return value != null ? flags.setBool(i, value) : flags.bool(i);

    }

    private inline static final FLAG_NOT_ACTIVE:Int = 1; // 1 << 0
    private inline static final FLAG_VISIBLE_WHEN_ACTIVE:Int = 2; // 1 << 1
    private inline static final FLAG_TOUCHABLE_WHEN_ACTIVE:Int = 4; // 1 << 2
    private inline static final FLAG_IS_HIT_VISUAL:Int = 8; // 1 << 3

    #if plugin_arcade
    private inline static final FLAG_ARCADE_BODY_ENABLE:Int = 64; // 1 << 6
    #end

    #if ceramic_wireframe
    private inline static final FLAG_RENDER_WIREFRAME:Int = 128; // 1 << 7
    #end

    /**
     * Read and write arbitrary boolean flags on this visual.
     * Index should be between 0 (included) and 16 (excluded) or result is undefined.
     * /!\ Reserved for internal use
     */
    inline private function internalFlag(index:Int, ?value:Bool):Bool {

        return value != null ? flags.setBool(index, value) : flags.bool(index);

    }

    /**
     * Just a way to store some flags.
     * 32 boolean values stored inside an `Int`.
     */
    var flags:Flags = new Flags();

    /**
     * Whether this visual is `active`. Default is **true**. When setting it to **false**,
     * the visual won't be `visible` nor `touchable` anymore (these get set to **false**).
     * When restoring `active` to **true**, `visible` and `touchable` will also get back
     * their previous state.
     * If you want to keep a visual around without it being displayed or interactive, simply
     * set its `active` property to `false`. It will be almost like it doesn't exist and its
     * impact on rendering will be minimal.
     */
    public var active(get,set):Bool;
    inline function get_active():Bool {
        return flags & FLAG_NOT_ACTIVE != FLAG_NOT_ACTIVE;
    }
    function set_active(active:Bool):Bool {
        if (active == (flags & FLAG_NOT_ACTIVE != FLAG_NOT_ACTIVE)) return active;
        flags = active ? flags & ~FLAG_NOT_ACTIVE : flags | FLAG_NOT_ACTIVE;
        if (active) {
            visible = flags & FLAG_VISIBLE_WHEN_ACTIVE == FLAG_VISIBLE_WHEN_ACTIVE;
            touchable = flags & FLAG_TOUCHABLE_WHEN_ACTIVE == FLAG_TOUCHABLE_WHEN_ACTIVE;
#if plugin_arcade
            var body = this.body;
            if (body != null) {
                body.enable = flags & FLAG_ARCADE_BODY_ENABLE == FLAG_ARCADE_BODY_ENABLE;
            }
#end
        }
        else {
            flags = visible ? flags | FLAG_VISIBLE_WHEN_ACTIVE : flags & ~FLAG_VISIBLE_WHEN_ACTIVE;
            flags = touchable ? flags | FLAG_TOUCHABLE_WHEN_ACTIVE : flags & ~FLAG_TOUCHABLE_WHEN_ACTIVE;
            visible = false;
            touchable = false;
#if plugin_arcade
            var body = this.body;
            if (body != null) {
                flags = body.enable ? flags | FLAG_ARCADE_BODY_ENABLE : flags & ~FLAG_ARCADE_BODY_ENABLE;
            }
            else {
                flags = flags & ~FLAG_ARCADE_BODY_ENABLE;
            }
#end
        }
        return active;
    }

/// Properties (Matrix)

    @:noCompletion public var matA:Float = 1;

    @:noCompletion public var matB:Float = 0;

    @:noCompletion public var matC:Float = 0;

    @:noCompletion public var matD:Float = 1;

    @:noCompletion public var matTX:Float = 0;

    @:noCompletion public var matTY:Float = 0;

/// Properties (Computed)

    /**
     * Computed visible value. This is `true` if this visual is `visible` and all
     * of its parents are `visible`. If you want to know if a visual is visible on screen,
     * you should check with this property and not `visible` property, which doesn't account
     * for parent visibility.
     */
    public var computedVisible(default, null):Bool = true;

    /**
     * Computed alpha value. This is the combination of this visual's alpha and its parent alpha
     * if `inheritAlpha` is `true`
     */
    public var computedAlpha(default, null):Float = 1;

    /**
     * Computed depth value. This is the final depth used by rendering, computed from this visual's `depth`
     * and `depthRange` properties and its hierarchy of parent visuals.
     */
    public var computedDepth(default, null):Float = 0;

    /**
     * Computed render target. When a visual has a `renderTarget` assigned, its `computedRenderTarget` will
     * be assigned with the same instance, and its children's `computedRenderTarget` property as well.
     */
    public var computedRenderTarget(default, null):RenderTexture = null;

    /**
     * Computed touchable value. This is `true` if this visual is `touchable` and all
     * of its parents are `touchable`.
     */
    public var computedTouchable(default, null):Bool = true;

    /**
     * If any parent of this visual has a `clip` visual assigned, this will be the computed/resolved visual.
     */
    public var computedClip(default, null):Visual = null;

/// Properties (Children)

    /**
     * A visual can have **children**.
     * Children positions and transformations are relative to their parent.
     * This property is read only. Use `add()` to add children to this visual
     * and `remove()` to remove them.
     * The order on the visuals in `children` should not be used to predict the order in which visuals are rendered.
     * If you want to control the order of rendering of visuals, use `depth` property on the children instead.
     */
    public var children(default,null):ReadOnlyArray<Visual> = null;

    /**
     * The **parent visual** if there is any, or `null` if this visual doesn't have any parent.
     */
    public var parent(default,null):Visual = null;

/// Internal

    inline static var _degToRad:Float = 0.017453292519943295;

    static var _matrix:Transform = new Transform();

    static var _point:Point = new Point();

/// Helpers

    /**
     * Shorthand to set `width` and `height` in a single call.
     * @param width The width to set to the visual
     * @param height The height to set to the visual
     */
    inline public function size(width:Float, height:Float):Void {

        this.width = width;
        this.height = height;

    }

    /**
     * Shorthand to set `anchorX` and `anchorY` in a single call.
     * @param anchorX The anchor to set to the visual on **x** axis
     * @param anchorY The anchor to set to the visual on **y** axis
     */
    inline public function anchor(anchorX:Float, anchorY:Float):Void {

        this.anchorX = anchorX;
        this.anchorY = anchorY;

    }

    /**
     * Shorthand to set `x` and `y` in a single call.
     * @param x The x position to set to the visual
     * @param y The y position to set to the visual
     */
    inline public function pos(x:Float, y:Float):Void {

        this.x = x;
        this.y = y;

    }

    /**
     * Shorthand to set `scaleX` and `scaleY` in a single call.
     * @param scaleX The scale to set to the visual on **x** axis
     * @param scaleY (optional) The scale to set to the visual on **y** axis. If not provided, will use scaleX value.
     */
    inline public extern overload function scale(scaleX:Float):Void {

        _scale(scaleX, scaleX);

    }

    /**
     * Shorthand to set `scaleX` and `scaleY` in a single call.
     * @param scaleX The scale to set to the visual on **x** axis
     * @param scaleY (optional) The scale to set to the visual on **y** axis. If not provided, will use scaleX value.
     */
    inline public extern overload function scale(scaleX:Float, scaleY:Float):Void {

        _scale(scaleX, scaleY);

    }

    inline function _scale(scaleX:Float, scaleY:Float):Void {

        this.scaleX = scaleX;
        this.scaleY = scaleY;

    }

    /**
     * Shorthand to set `skewX` and `skewY` in a single call.
     * @param skewX The skew to set to the visual on **x** axis
     * @param skewY The skew to set to the visual on **y** axis
     */
    inline public function skew(skewX:Float, skewY:Float):Void {

        this.skewX = skewX;
        this.skewY = skewY;

    }

    /**
     * Shorthand to set `translateX` and `translateY` in a single call.
     * @param translateX The translation to set to the visual on **x** axis
     * @param translateY The translation to set to the visual on **y** axis
     */
    inline public function translate(translateX:Float, translateY:Float):Void {

        this.translateX = translateX;
        this.translateY = translateY;

    }

/// Advanced helpers

    /**
     * Change the visual's anchor but ensure the visual keeps its current position.
     * This is similar to `anchor(anchorX, anchorY)` but visual with have its `x` and `y` properties
     * updated to ensure it stays at the same position as before changing anchor.
     * @param anchorX The anchor to set to the visual on **x** axis
     * @param anchorY The anchor to set to the visual on **y** axis
     */
    public function anchorKeepPosition(anchorX:Float, anchorY:Float):Void {

        if (this.anchorX == anchorX && this.anchorY == anchorY) return;

        // Get initial pos
        visualToScreen(0, 0, _point, false);
        if (parent != null) {
            parent.screenToVisual(_point.x, _point.y, _point, false);
        }

        var prevX = _point.x;
        var prevY = _point.y;
        this.anchorX = anchorX;
        this.anchorY = anchorY;

        // Get new pos
        this.visualToScreen(0, 0, _point, false);
        if (parent != null) {
            parent.screenToVisual(_point.x, _point.y, _point, false);
        }

        // Move visual accordingly
        this.x += prevX - _point.x;
        this.y += prevY - _point.y;

    }

    /**
     * Returns the first child matching the requested `id` or `null` otherwise.
     * @param id The requested id
     * @param recursive (optional) Recursive search in children
     * @return A matching visual or `null`
     */
    public function childWithId(id:String, recursive:Bool = true):Visual {

        if (children != null) {
            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                if (child.id == id) return child;
            }
            if (recursive) {
                for (i in 0...children.length) {
                    var child = children.unsafeGet(i);
                    var childResult = child.childWithId(id, true);
                    if (childResult != null) return childResult;
                }
            }
        }

        return null;

    }

    /**
     * Returns the first child matching the requested type or `null` otherwise.
     * @param type The requested type
     * @param recursive (optional) Recursive search in children
     * @return A matching visual or `null`
     */
    public function childWithType<T:Visual>(type:Class<T>, recursive:Bool = true):T {

        if (children != null) {
            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                if (Std.isOfType(child, type)) return cast child;
            }
            if (recursive) {
                for (i in 0...children.length) {
                    var child = children.unsafeGet(i);
                    var childResult = child.childWithType(type, true);
                    if (childResult != null) return cast childResult;
                }
            }
        }

        return null;

    }

/// Lifecycle

    /**
     * Create a new `Visual`
     */
    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        ceramic.App.app.addVisual(this);

#if ceramic_luxe_legacy
        backendItem = ceramic.App.app.backend.draw.getItem(this);
#end

    }

    /**
     * Destroy the visual.
     * When a visual is destroyed, `clear()` is called,
     * which means all children are removed and destroyed.
     * Events owned by this visual and events on this visual are
     * unbound so they don't need to be unbound explicitly.
     * As soon as `destroy()` is called, the `destroyed` property
     * becomes `true`.
     */
    override public function destroy() {

        super.destroy();

        if (@:privateAccess ceramic.App.app.screen.unobservedFocusedVisual == this) {
            ceramic.App.app.screen.focusedVisual = null;
        }

        ceramic.App.app.removeVisual(this);

        if (parent != null) parent.remove(this);
        if (transform != null) transform = null;

#if plugin_arcade
        if (arcade != null) {
            arcade.destroy();
            arcade = null;
        }
#end

#if plugin_nape
        if (nape != null) {
            nape.destroy();
            nape = null;
        }
#end

        clear();

        // Ensure this visual won't be rendered anymore
        visibilityDirty = false;
        computedVisible = false;

    }

    /**
     * Remove and destroy all children.
     */
    public function clear() {

        if (children != null && children.length > 0) {
            var len = children.length;
            var pool = ArrayPool.pool(len);
            var tmp = pool.get();
            for (i in 0...len) {
                tmp.set(i, children.unsafeGet(i));
            }
            for (i in 0...len) {
                var child:Visual = tmp.get(i);
                child.destroy();
            }
            children = null;
            pool.release(tmp);
        }

    }

/// Matrix

    /**
     * Called when this visual's transform has changed
     */
    function transformDidChange() {

        matrixDirty = true;

    }

    /**
     * Called when this visual's matrix needs to be recomputed
     */
    function computeMatrix() {

        if (parent != null && parent.matrixDirty) {
            parent.computeMatrix();
        }

        _matrix.identity();

        doComputeMatrix();

    }

    inline function computeTranslatesOnly() {

        translatesOnly = (rotation == 0 && scaleX == 1 && scaleY == 1 && skewX == 0 && skewY == 0);
        translatesOnlyDirty = false;

    }

    inline function doComputeMatrix() {

        if (translatesOnlyDirty) {
            computeTranslatesOnly();
        }

        var w = width;
        var h = height;

        // Apply local properties (pos, scale, rotation, skew)
        //

        if (translatesOnly) {
            _matrix.tx += x - anchorX * w;
            _matrix.ty += y - anchorY * h;
        }
        else {
            #if ceramic_visual_legacy_matrix

            // This will be removed eventually

            _matrix.translate(-anchorX * w, -anchorY * h);

            if (skewX != 0 || skewY != 0) {
                _matrix.skew(skewX * _degToRad, skewY * _degToRad);
            }

            if (rotation != 0) _matrix.rotate(rotation * _degToRad);
            _matrix.translate(anchorX * w, anchorY * h);
            if (scaleX != 1.0 || scaleY != 1.0) _matrix.scale(scaleX, scaleY);
            _matrix.translate(
                x - (anchorX * w * scaleX),
                y - (anchorY * h * scaleY)
            );

            #else

            // Newer way of applying transformations
            // Simpler and with a better order of transformations
            // (order matches better existing editors and standards so far)

            _matrix.translate(-anchorX * w, -anchorY * h);

            if (scaleX != 1.0 || scaleY != 1.0)
                _matrix.scale(scaleX, scaleY);

            if (skewX != 0 || skewY != 0)
                _matrix.skew(skewX * _degToRad, skewY * _degToRad);

            if (rotation != 0)
                _matrix.rotate(rotation * _degToRad);

            _matrix.translate(x, y);

            #end
        }

        if (transform != null) {

            // Concat matrix with transform
            //
            var a1 = _matrix.a * transform.a + _matrix.b * transform.c;
            _matrix.b = _matrix.a * transform.b + _matrix.b * transform.d;
            _matrix.a = a1;

            var c1 = _matrix.c * transform.a + _matrix.d * transform.c;
            _matrix.d = _matrix.c * transform.b + _matrix.d * transform.d;

            _matrix.c = c1;

            var tx1 = _matrix.tx * transform.a + _matrix.ty * transform.c + transform.tx;
            _matrix.ty = _matrix.tx * transform.b + _matrix.ty * transform.d + transform.ty;
            _matrix.tx = tx1;

        }

        if (parent != null && renderTarget == null) {

            // Concat matrix with parent's computed matrix data
            //
            if (parent.matA == 1 && parent.matB == 0 && parent.matC == 0 && parent.matD == 1) {

                _matrix.tx += parent.matTX;
                _matrix.ty += parent.matTY;

            }
            else if (translatesOnly && transform == null) {

                _matrix.a = parent.matA;
                _matrix.b = parent.matB;
                _matrix.c = parent.matC;
                _matrix.d = parent.matD;

                var tx1 = _matrix.tx * parent.matA + _matrix.ty * parent.matC + parent.matTX;
                _matrix.ty = _matrix.tx * parent.matB + _matrix.ty * parent.matD + parent.matTY;
                _matrix.tx = tx1;

            }
            else {

                var a1 = _matrix.a * parent.matA + _matrix.b * parent.matC;
                _matrix.b = _matrix.a * parent.matB + _matrix.b * parent.matD;
                _matrix.a = a1;

                var c1 = _matrix.c * parent.matA + _matrix.d * parent.matC;
                _matrix.d = _matrix.c * parent.matB + _matrix.d * parent.matD;

                _matrix.c = c1;

                var tx1 = _matrix.tx * parent.matA + _matrix.ty * parent.matC + parent.matTX;
                _matrix.ty = _matrix.tx * parent.matB + _matrix.ty * parent.matD + parent.matTY;
                _matrix.tx = tx1;
            }

        }

        // Assign final matrix values to visual
        //
        matA = _matrix.a;
        matB = _matrix.b;
        matC = _matrix.c;
        matD = _matrix.d;
        matTX = _matrix.tx;
        matTY = _matrix.ty;

        if (roundTranslation > 0) {
            if (roundTranslation == 1) {
                matTX = Math.round(matTX);
                matTY = Math.round(matTY);
            }
            else {
                matTX = Math.round(matTX * roundTranslation) / roundTranslation;
                matTY = Math.round(matTY * roundTranslation) / roundTranslation;
            }
        }

        // Matrix is up to date
        matrixDirty = false;

    }

/// Hit test

    /**
     * Returns true if screen (x, y) screen coordinates hit/intersect this visual visible bounds
     * @param x Screen **x** coordinate
     * @param y Screen **y** coordinate
     * @return `true` if it hits
     */
    public inline extern overload function hits(x:Float, y:Float):Bool {
        return _hits(x, y, false);
    }

    /**
     * Returns true if screen (x, y) screen coordinates hit/intersect this visual visible bounds
     * @param x Screen **x** coordinate
     * @param y Screen **y** coordinate
     * @param ignoreRenderTarget
     *      If `true`, hit test will be performed like the visual
     *      doesn't have a render target even if it has in reality
     * @return `true` if it hits
     */
    public inline extern overload function hits(x:Float, y:Float, ignoreRenderTarget:Bool):Bool {
        return _hits(x, y, ignoreRenderTarget);
    }

    function _hits(x:Float, y:Float, ignoreRenderTarget:Bool):Bool {

        if (!ignoreRenderTarget) {
            // A visuals that renders to texture never hits by default
            // unless the render texture is managed by a `Filter` instance, re-routing touch
            if (renderTargetDirty) computeRenderTarget();
            if (computedRenderTarget != null) {
                var parent = this.parent;
                if (parent != null) {
                    do {
                        if (parent.asQuad != null && Std.isOfType(parent, Filter)) {
                            var filter:Filter = cast parent;
                            if (filter.renderTexture == computedRenderTarget) {
                                if (Screen.matchedHitVisual == null || filter.hitVisual == Screen.matchedHitVisual) {
                                    return filter.visualInContentHits(this, x, y);
                                }
                            }
                        }
                        parent = parent.parent;
                    }
                    while (parent != null);
                }
                return false;
            }
            else if (Screen.matchedHitVisual != null && Screen.matchedHitVisual != this) {
                return false;
            }
        }

        if (matrixDirty) {
            computeMatrix();
        }

        _matrix.setTo(matA, matB, matC, matD, matTX, matTY);
        _matrix.invert();

        return hitTest(x, y, _matrix);

    }

    /**
     * The actual hit test performed on the visual.
     * If needed to change how hit test is performed
     * on a visual subclass, this is the method to override.
     * @param x Screen **x** coordinate
     * @param y Screen **y** coordinate
     * @param matrix The matrix being applied to visual, relative to screen space
     * @return `true` if it hits
     */
    @:dox(show)
    function hitTest(x:Float, y:Float, matrix:Transform):Bool {

        var testX = matrix.transformX(x, y);
        var testY = matrix.transformY(x, y);

        return testX >= 0
            && testX < width
            && testY >= 0
            && testY < height;

    }

    private var isHitVisual(get,set):Bool;
    inline function get_isHitVisual():Bool {
        // Equivalent to internalFlag(3)
        return flags & FLAG_IS_HIT_VISUAL == FLAG_IS_HIT_VISUAL;
    }
    inline function set_isHitVisual(isHitVisual:Bool):Bool {
        // Equivalent to internalFlag(3, isHitVisual)
        flags = isHitVisual ? flags | FLAG_IS_HIT_VISUAL : flags & ~FLAG_IS_HIT_VISUAL;
        return isHitVisual;
    }

    /**
     * Override this method in subclasses to intercept hitting pointer down events on this visual's children (any level in sub-hierarchy).
     * Return `true` to stop an event from being triggered on the hitting child, `false` (default) otherwise.
     * @param hittingVisual The hitting visual, meaning the visual on which the event applies
     * @param x The **x** coordinate of the event
     * @param y The **y** coordinate of the event
     * @param touchIndex The **touch index** of the event (or `-1` if it is not a touch event)
     * @param buttonId The **button id** of the event (or `-1` if it is not a mouse event)
     * @return `true` if the event is intercepted
     */
    @:dox(show)
    function interceptPointerDown(hittingVisual:Visual, x:Float, y:Float, touchIndex:Int, buttonId:Int):Bool {

        return false;

    }

    /**
     * Override this method in subclasses to intercept hitting pointer over events on this visual's children (any level in sub-hierarchy).
     * Return `true` to stop an event from being triggered on the hitting child, `false` (default) otherwise.
     * @param hittingVisual The hitting visual, meaning the visual on which the event applies
     * @param x The **x** coordinate of the event
     * @param y The **y** coordinate of the event
     * @return `true` if the event is intercepted
     */
    @:dox(show)
    function interceptPointerOver(hittingVisual:Visual, x:Float, y:Float):Bool {

        return false;

    }

/// Screen to visual positions and vice versa

    /**
     * Assign **x** and **y** to given point after converting them from screen coordinates to current visual coordinates.
     * @param x The **x** coordinate
     * @param y The **y** coordinate
     * @param point The point in which resulting x and y coordinate are stored
     * @param handleFilters (optional) Make it `false` if you want to skip nested filter transformations
     */
    public function screenToVisual(x:Float, y:Float, point:Point, handleFilters:Bool = true):Void {

        if (matrixDirty) {
            computeMatrix();
        }

        if (handleFilters) {
            // A visuals that renders to texture never hits by default
            // unless the render texture is managed by a `Filter` instance, re-routing touch
            if (renderTargetDirty) computeRenderTarget();
            if (computedRenderTarget != null) {
                var parent = this.parent;
                if (parent != null) {
                    do {
                        if (parent.asQuad != null && Std.isOfType(parent, Filter)) {
                            var filter:Filter = cast parent;
                            if (filter.renderTexture == computedRenderTarget) {
                                filter.screenToVisual(x, y, point);

                                _matrix.setTo(matA, matB, matC, matD, matTX, matTY);
                                _matrix.invert();
                                var _x = point.x;
                                var _y = point.y;
                                point.x = _matrix.transformX(_x, _y);
                                point.y = _matrix.transformY(_x, _y);

                                return;
                            }
                        }
                        parent = parent.parent;
                    }
                    while (parent != null);
                }
            }
        }

        _matrix.setTo(matA, matB, matC, matD, matTX, matTY);
        _matrix.invert();
        point.x = _matrix.transformX(x, y);
        point.y = _matrix.transformY(x, y);

    }

    /**
     * Assign **x** and **y** to given point after converting them from current visual coordinates to screen coordinates.
     * @param x The **x** coordinate
     * @param y The **y** coordinate
     * @param point The point in which resulting x and y coordinate are stored
     * @param handleFilters (optional) Make it `false` if you want to skip nested filter transformations
     */
    public function visualToScreen(x:Float, y:Float, point:Point, handleFilters:Bool = true):Void {

        if (matrixDirty) {
            computeMatrix();
        }

        if (handleFilters) {
            // A visuals that renders to texture never hits by default
            // unless the render texture is managed by a `Filter` instance, re-routing touch
            if (renderTargetDirty) computeRenderTarget();
            if (computedRenderTarget != null) {
                var parent = this.parent;
                if (parent != null) {
                    do {
                        if (parent.asQuad != null && Std.isOfType(parent, Filter)) {
                            var filter:Filter = cast parent;
                            if (filter.renderTexture == computedRenderTarget) {

                                _matrix.setTo(matA, matB, matC, matD, matTX, matTY);
                                point.x = _matrix.transformX(x, y);
                                point.y = _matrix.transformY(x, y);

                                filter.visualToScreen(point.x, point.y, point);

                                return;
                            }
                        }
                        parent = parent.parent;
                    }
                    while (parent != null);
                }
            }
        }

        _matrix.setTo(matA, matB, matC, matD, matTX, matTY);
        point.x = _matrix.transformX(x, y);
        point.y = _matrix.transformY(x, y);

    }

/// Transform from visual

    /**
     * Extract current visual transformation and write it into the given `transform`
     * @param transform The transform object to write data into
     */
    public function visualToTransform(transform:Transform):Void {

        if (matrixDirty) {
            computeMatrix();
        }

        transform.setTo(matA, matB, matC, matD, matTX, matTY);

    }

/// Visibility / Alpha

    function computeVisibility() {

        if (destroyed) {

            computedVisible = false;

        }
        else {

            if (parent != null && parent.visibilityDirty) {
                parent.computeVisibility();
            }

            computedVisible = visible;
            computedAlpha = alpha;

            if (computedVisible) {

                if (parent != null) {
                    if (!parent.computedVisible && (parent.inheritAlpha || !parent.visible || (parent.parent != null && !parent.parent.computedVisible))) {
                        computedVisible = false;
                    }
                    if (inheritAlpha) computedAlpha *= parent.computedAlpha;
                }

                if (computedAlpha == 0 && blending != Blending.SET) {
                    computedVisible = false;
                }

            }
        }

        visibilityDirty = false;

    }

/// Clipping

    function computeClip() {

        if (renderTargetDirty) {
            computeRenderTarget();
        }

        if (parent != null && parent.clipDirty) {
            parent.computeClip();
        }

        #if ceramic_clip_children_only
        computedClip = null;
        if (parent != null) {
            if (parent.computedClip != null || parent.clip != null) {
                if (computedRenderTarget == parent.computedRenderTarget) {
                    computedClip = parent.computedClip != null ? parent.computedClip : parent.clip;
                }
            }
        }
        #else
        computedClip = clip;
        if (computedClip == null && parent != null) {
            if (parent.computedClip != null) {
                if (computedRenderTarget == parent.computedRenderTarget) {
                    computedClip = parent.computedClip;
                }
            }
        }
        #end

        clipDirty = false;

    }

/// Touchable

    function computeTouchable() {

        if (parent != null && parent.touchableDirty) {
            parent.computeTouchable();
        }

        computedTouchable = touchable;

        if (computedTouchable) {

            if (parent != null) {
                if (!parent.computedTouchable) {
                    computedTouchable = false;
                }
            }

        }

        touchableDirty = false;

    }

/// RenderTarget (computed)

    function computeRenderTarget() {

        if (parent != null && parent.renderTargetDirty) {
            parent.computeRenderTarget();
        }

        var prevComputedRenderTarget = computedRenderTarget;

        computedRenderTarget = renderTarget;
        if (computedRenderTarget == null && parent != null && parent.computedRenderTarget != null) {
            computedRenderTarget = parent.computedRenderTarget;
        }

        /*
        if (prevComputedRenderTarget != computedRenderTarget) {
            // Release dependant render target texture
            if (prevComputedRenderTarget != null) {
                if (asQuad != null) {
                    if (asQuad.texture != null && asQuad.texture.isRenderTexture) {
                        prevComputedRenderTarget.decrementDependingTextureCount(asQuad.texture);
                    }
                }
                else if (asMesh != null) {
                    if (asMesh.texture != null && asMesh.texture.isRenderTexture) {
                        prevComputedRenderTarget.decrementDependingTextureCount(asMesh.texture);
                    }
                }
            }
            // Add dependent render target texture
            if (computedRenderTarget != null) {
                if (asQuad != null) {
                    if (asQuad.texture != null && asQuad.texture.isRenderTexture) {
                        computedRenderTarget.incrementDependingTextureCount(asQuad.texture);
                    }
                }
                else if (asMesh != null) {
                    if (asMesh.texture != null && asMesh.texture.isRenderTexture) {
                        computedRenderTarget.incrementDependingTextureCount(asMesh.texture);
                    }
                }
            }
        }*/

        renderTargetDirty = false;

    }

/// Display

    /**
     * Compute content on this visual.
     * This method is expected to be overrided in `Visual` subclasses
     * to compute actual content (raw `Visual` class doesn't do anything).
     */
    public function computeContent() {

        contentDirty = false;

    }

/// Children

    static var _minDepth:Float = 0;

    static var _maxDepth:Float = 0;

    /**
     * Will walk on every children and set their depths starting from
     * `start` and incrementing depth by `step`.
     * @param start The depth starting value (default 1). First child will have this depth, next child `depthStart + depthStep` etc...
     * @param step The depth step to use when increment depth for each child
     */
    public function autoChildrenDepth(start:Float = 1, step:Float = 1):Void {

        var depth = start;

        if (children != null) {
            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                child.depth = depth;
                depth += step;
            }
        }

    }

    /**
     * Sort children by depth in ascending order.
     * This will simply reorder children in `children` array.
     * No depth value will be changed on any child.
     */
    public function sortChildrenByDepth():Void {

        if (children != null && children.length > 0) {

            SortVisualsByDepth.sort(children.original);

        }

    }

    /**
     * This is the equivalent of calling `sortChildrenByDepth()` followed with `autoChildrenDepth()`
     * @param start The depth starting value (default 1). First child will have this depth, next child `depthStart + depthStep` etc...
     * @param step The depth step to use when increment depth for each child
     */
    public function normalizeChildrenDepth(start:Float = 1, step:Float = 1):Void {

        if (children != null && children.length > 0) {

            sortChildrenByDepth();
            autoChildrenDepth();

        }

    }

    /**
     * Compute children depth. The result depends on whether
     * a parent defines a custom `depthRange` value or not.
     */
    #if ceramic_soft_inline inline #end static function computeChildrenDepth(visual:Visual):Void {

        _computeChildrenDepth0(visual #if !ceramic_soft_inline , 0 #end);

    }

    #if !ceramic_soft_inline inline #end static function _computeChildrenDepth0(visual:Visual #if !ceramic_soft_inline , step:Int #end):Void {

        var children = visual.children.original;
        if (children != null) {

            // Compute deepest in hierarchy first
            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                child.computedDepth = child.depth * DEPTH_FACTOR;
                #if !ceramic_soft_inline
                if (step == 0) {
                    _computeChildrenDepth0(child, 1);
                }
                else {
                    _computeChildrenDepth1(child, 0);
                #else
                    computeChildrenDepth(child);
                #end
                #if !ceramic_soft_inline
                }
                #end
            }

            _computeChildrenDepthApplyDepthRange(visual, children);
        }

    }

    #if !ceramic_soft_inline inline #end static function _computeChildrenDepth1(visual:Visual #if !ceramic_soft_inline , step:Int #end):Void {

        var children = visual.children.original;
        if (children != null) {

            // Compute deepest in hierarchy first
            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                child.computedDepth = child.depth * DEPTH_FACTOR;
                #if !ceramic_soft_inline
                if (step == 0) {
                    _computeChildrenDepth1(child, 1);
                }
                else {
                #end
                    computeChildrenDepth(child);
                #if !ceramic_soft_inline
                }
                #end
            }

            _computeChildrenDepthApplyDepthRange(visual, children);
        }

    }

    inline static function _computeChildrenDepthApplyDepthRange(visual:Visual, children:Array<Visual>) {

        // Apply depth range if any
        var depthRange = visual.depthRange;
        if (depthRange != -1) {

            _minDepth = 9999999999;
            _maxDepth = -9999999999;

            // Compute min/max depth
            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                inline computeMinMaxDepths(child);
            }

            // Multiply depth
            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                inline multiplyDepths(child, visual.computedDepth + Math.min(DEPTH_MARGIN, depthRange * DEPTH_FACTOR), Math.max(0, depthRange * DEPTH_FACTOR - DEPTH_MARGIN));
            }
        }

    }

    #if ceramic_soft_inline inline #end static function computeMinMaxDepths(visual:Visual):Void {

        _computeMinMaxDepths0(visual #if !ceramic_soft_inline , 0 #end);

    }

    #if !ceramic_soft_inline inline #end static function _computeMinMaxDepths0(visual:Visual #if !ceramic_soft_inline , step:Int #end):Void {

        var computedDepth = visual.computedDepth;
        if (_minDepth > computedDepth) _minDepth = computedDepth;
        if (_maxDepth < computedDepth + 1) _maxDepth = computedDepth + 1;

        var children = visual.children.original;
        if (children != null) {

            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                #if !ceramic_soft_inline
                if (step == 0) {
                    _computeMinMaxDepths0(child, 1);
                }
                else {
                    _computeMinMaxDepths1(child, 0);
                #else
                    computeMinMaxDepths(child);
                #end
                #if !ceramic_soft_inline
                }
                #end
            }
        }

    }

    #if !ceramic_soft_inline inline #end static function _computeMinMaxDepths1(visual:Visual #if !ceramic_soft_inline , step:Int #end):Void {

        var computedDepth = visual.computedDepth;
        if (_minDepth > computedDepth) _minDepth = computedDepth;
        if (_maxDepth < computedDepth + 1) _maxDepth = computedDepth + 1;

        var children = visual.children.original;
        if (children != null) {

            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                #if !ceramic_soft_inline
                if (step == 0) {
                    _computeMinMaxDepths1(child, 1);
                }
                else {
                #end
                    computeMinMaxDepths(child);
                #if !ceramic_soft_inline
                }
                #end
            }
        }

    }

    #if ceramic_soft_inline inline #end static function multiplyDepths(visual:Visual, startDepth:Float, targetRange:Float):Void {

        _multiplyDepths0(visual, startDepth, targetRange #if !ceramic_soft_inline , 0 #end);

    }

    #if !ceramic_soft_inline inline #end static function _multiplyDepths0(visual:Visual, startDepth:Float, targetRange:Float #if !ceramic_soft_inline , step:Int #end):Void {

        if (_maxDepth == _minDepth) {
            visual.computedDepth = startDepth + 0.5 * targetRange;
        } else {
            visual.computedDepth = startDepth + ((visual.computedDepth - _minDepth) / (_maxDepth - _minDepth)) * targetRange;
        }

        // Multiply recursively
        var children = visual.children.original;
        if (children != null) {

            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                #if !ceramic_soft_inline
                if (step == 0) {
                    _multiplyDepths0(child, startDepth, targetRange, 1);
                }
                else {
                    _multiplyDepths1(child, startDepth, targetRange, 0);
                #else
                    multiplyDepths(child, startDepth, targetRange);
                #end
                #if !ceramic_soft_inline
                }
                #end
            }
        }

    }

    #if !ceramic_soft_inline inline #end static function _multiplyDepths1(visual:Visual, startDepth:Float, targetRange:Float #if !ceramic_soft_inline , step:Int #end):Void {

        if (_maxDepth == _minDepth) {
            visual.computedDepth = startDepth + 0.5 * targetRange;
        } else {
            visual.computedDepth = startDepth + ((visual.computedDepth - _minDepth) / (_maxDepth - _minDepth)) * targetRange;
        }

        // Multiply recursively
        var children = visual.children.original;
        if (children != null) {

            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                #if !ceramic_soft_inline
                if (step == 0) {
                    _multiplyDepths1(child, startDepth, targetRange, 1);
                }
                else {
                #end
                    multiplyDepths(child, startDepth, targetRange);
                #if !ceramic_soft_inline
                }
                #end
            }
        }

    }

    /**
     * Check if current visual has `targetParent` as parent visual. The parent can possibly
     * be indirect, meaning it can be the parent of the parent of the visual etc...
     * @param targetParent The target parent to check
     * @return `true` if the visual has the given target parent as indirect parent
     */
    public function hasIndirectParent(targetParent:Visual):Bool {

        var parent = this.parent;
        while (parent != null) {
            if (parent == targetParent) return true;
            parent = parent.parent;
        }

        return false;

    }

    /**
     * Returns the first parent (can be indirect) of this visual that matches
     * the given class or `null` if none is matching
     * @param clazz The requested class
     * @return A matching parent or `null`
     */
    public function firstParentWithClass<T>(clazz:Class<T>):T {

        var parent = this.parent;
        while (parent != null) {
            if (Std.isOfType(parent, clazz)) return cast parent;
            parent = parent.parent;
        }

        return null;

    }

    /**
     * Add the given visual as a child.
     * When a visual is added as a child, it's `parent` property is updated
     * and it will follow parent transformation in addition to its own.
     * @param visual The visual to add
     */
    public function add(visual:Visual):Void {

        if (visual == this) {
            throw 'A visual cannot add itself as child!';
        }

        if (visual == null) {
            throw 'A visual cannot add a null child!';
        }

        if (visual.destroyed) {
            throw 'A visual cannot add an already destroyed child!';
        }

        if (visual.parent != this) {

            App.app.hierarchyDirty = true;

            if (visual.parent != null) {
                visual.parent.remove(visual);
            }

            visual.parent = this;
            visual.visibilityDirty = true;
            visual.matrixDirty = true;
            visual.renderTargetDirty = true;
            if (children == null) {
                children = [];
            }
            @:privateAccess children.original.push(visual);
            clipDirty = true;
        }

    }

    /**
     * Remove the child from current visual.
     * @param visual The child to remove
     */
    public function remove(visual:Visual):Void {

        App.app.hierarchyDirty = true;

        if (children == null) return;

        var index = children.indexOf(visual);
        if (index != -1) {
            @:privateAccess children.original.splice(children.indexOf(visual), 1);
        }
        else {
            ceramic.Shortcuts.log.warning('Cannot remove visual $visual, index is -1');
        }
        visual.parent = null;
        visual.visibilityDirty = true;
        visual.matrixDirty = true;
        visual.renderTargetDirty = true;
        visual.clipDirty = true;

    }

    /**
     * Returns `true` if the current visual contains this child.
     * When `recursive` option is `true`, will return `true` if
     * the current visual contains this child or one of
     * its direct or indirect children does.
     * @param child The child to check in hierarchy
     * @param recursive (optional) Set to `true` to search recursively on indirect children
     * @return `true` if the current visual contains this child
     */
    public function contains(child:Visual, recursive:Bool = false):Bool {

        var parent = child.parent;

        while (parent != null) {

            if (parent == this) return true;
            parent = parent.parent;

            if (!recursive) break;
        }

        return false;

    }

/// Size helpers

    /**
     * Compute bounds from children this visual contains.
     * This overwrites width, height, anchorX and anchorY properties accordingly.
     * Warning: this may be an expensive operation.
     */
    public function computeBounds():Void {

        if (children == null) {
            _width = 0;
            _height = 0;
        }
        else {
            var minX = 999999999.0;
            var minY = 999999999.0;
            var maxX = -999999999.9;
            var maxY = -999999999.9;
            var point = new Point();
            for (i in 0...children.length) {
                var child = children.unsafeGet(i);

                if (child.visible) {

                    // Mesh is a specific case.
                    // For now we handle it in Visual class directly.
                    // We might move this into Mesh class later.
                    if (child.asMesh != null) {
                        var mesh:Mesh = child.asMesh;
                        var vertices = mesh.vertices;
                        var i = 0;
                        var len = vertices.length;
                        var x = 0.0;
                        var y = 0.0;

                        while (i < len) {
                            x = vertices[i];
                            y = vertices[i + 1];

                            child.visualToScreen(x, y, point, false);
                            if (point.x > maxX) maxX = point.x;
                            if (point.y > maxY) maxY = point.y;
                            if (point.x < minX) minX = point.x;
                            if (point.y < minY) minY = point.y;

                            i += 2;
                        }

                    }
                    else {
                        child.visualToScreen(0, 0, point, false);
                        if (point.x > maxX) maxX = point.x;
                        if (point.y > maxY) maxY = point.y;
                        if (point.x < minX) minX = point.x;
                        if (point.y < minY) minY = point.y;

                        child.visualToScreen(child.width, 0, point, false);
                        if (point.x > maxX) maxX = point.x;
                        if (point.y > maxY) maxY = point.y;
                        if (point.x < minX) minX = point.x;
                        if (point.y < minY) minY = point.y;

                        child.visualToScreen(0, child.height, point, false);
                        if (point.x > maxX) maxX = point.x;
                        if (point.y > maxY) maxY = point.y;
                        if (point.x < minX) minX = point.x;
                        if (point.y < minY) minY = point.y;

                        child.visualToScreen(child.width, child.height, point, false);
                        if (point.x > maxX) maxX = point.x;
                        if (point.y > maxY) maxY = point.y;
                        if (point.x < minX) minX = point.x;
                        if (point.y < minY) minY = point.y;
                    }
                }
            }

            // Keep absolute position to restore it after we update anchor
            visualToScreen(0, 0, point, false);
            var origX = point.x;
            var origY = point.y;

            screenToVisual(minX, minY, point, false);
            minX = point.x;
            minY = point.y;

            screenToVisual(maxX, maxY, point, false);
            maxX = point.x;
            maxY = point.y;

            // max and min could be inverted if the visual has a custom render target
            if (maxX < minX) {
                var prevMinX = minX;
                minX = maxX;
                maxX = prevMinX;
            }
            if (maxY < minY) {
                var prevMinY = minY;
                minY = maxY;
                maxY = prevMinY;
            }

            _width = maxX - minX;
            _height = maxY - minY;

            anchorX = _width != 0 ? -minX / _width : 0;
            anchorY = _height != 0 ? -minY / _height : 0;

            // Restore position
            screenToVisual(origX, origY, point, false);
            this.x = point.x - _width * anchorX;
            this.y = point.y - _height * anchorY;

            matrixDirty = true;
        }

    }

/// Screen size helpers

    /**
     * Will set this visual size to native screen size.
     * This is different than `bindToScreenSize()` because it will ignore
     * logical screen scaling. Use that if you want to provide visuals
     * that should keep the same pixel size when the window changes size and scales its content.
     * If needed, a `Transform` instance will be created and assigned to `transform` property.
     */
    public function bindToNativeScreenSize():Void {

        // Bind to screen transform
        ceramic.App.app.screen.reverseMatrix.onChange(this, _bindToNativeScreenSizeCallback);
        ceramic.App.app.onPreUpdate(this, _ -> {
            if (this.width != ceramic.App.app.screen.nativeWidth || this.height != ceramic.App.app.screen.nativeHeight) {
                size(ceramic.App.app.screen.nativeWidth, ceramic.App.app.screen.nativeHeight);
            }
        });
        _bindToNativeScreenSizeCallback();

    }

    private function _bindToNativeScreenSizeCallback():Void {

        if (transform == null)
            transform = new Transform();

        transform.identity();
        transform.scale(ceramic.App.app.screen.nativeDensity, ceramic.App.app.screen.nativeDensity);
        transform.concat(ceramic.App.app.screen.reverseMatrix);
        transform.tx = transform.tx;
        transform.ty = transform.ty;
        transform.changedDirty = true;

        size(ceramic.App.app.screen.nativeWidth, ceramic.App.app.screen.nativeHeight);

    }

    /**
     * Will set this visual size to screen size
     */
    public function bindToScreenSize(factor:Float = 1.0):Void {

        // Bind to screen size
        ceramic.App.app.screen.onResize(this, () -> _bindToScreenSizeCallback(factor));
        _bindToScreenSizeCallback(factor);

    }

    private function _bindToScreenSizeCallback(factor:Float):Void {

        size(ceramic.App.app.screen.width * factor, ceramic.App.app.screen.height * factor);

    }

    /**
     * Will set this visual size to target size (`settings.targetWidth` and `settings.targetHeight`)
     */
    public function bindToTargetSize():Void {

        // Bind to target size
        ceramic.App.app.screen.onResize(this, _bindToTargetSizeCallback);
        _bindToTargetSizeCallback();

    }

    private function _bindToTargetSizeCallback():Void {

        size(ceramic.App.app.screen.width, ceramic.App.app.screen.height);

    }

}
