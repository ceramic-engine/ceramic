package ceramic;

#if ceramic_luxe_legacy
import backend.VisualItem;
#end

import ceramic.Point;

using ceramic.Extensions;

@:allow(ceramic.App)
@:allow(ceramic.Screen)
@:allow(ceramic.MeshPool)
@editable()
#if lua
@dynamicEvents
@:dce
#end
class Visual extends Entity #if ceramic_arcade_physics implements arcade.Collidable #end {
    
    /** A factor applied to every computed depth. This factor is used to avoid having
        all computed depth values being too small and risking to create precision issues.
        It is expected to work best with use of `depthRange = 1` on visuals (default) */
    inline static final DEPTH_FACTOR:Float = 2000000;
    
    /** A garanteed margin between max inner computed depth and container depth range,
        and min inner depth and container's computed depth. */
    inline static final DEPTH_MARGIN:Float = 0.01;

/// Events

    @event function pointerDown(info:TouchInfo);
    @event function pointerUp(info:TouchInfo);
    @event function pointerOver(info:TouchInfo);
    @event function pointerOut(info:TouchInfo);

    @event function focus();
    @event function blur();

#if ceramic_arcade_physics

/// Arcade physics

    /** The arcade physics body bound to this visual. */
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

    /** Init arcade physics (body) bound to this visual. */
    public function initArcadePhysics(?world:ArcadeWorld):VisualArcadePhysics {

        if (arcade != null) {
            arcade.destroy();
            arcade = null;
        }

        var w = width * scaleX;
        var h = height * scaleY;

        arcade = new VisualArcadePhysics(
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

    /** The arcade physics body linked to this visual */
    public var body(get,never):arcade.Body;
    inline function get_body():arcade.Body {
        return arcade != null ? arcade.body : null;
    }

    /** Allow this visual to be rotated by arcade physics, via `angularVelocity`, etc... */
    public var allowRotation(get,set):Bool;
    inline function get_allowRotation():Bool {
        return arcade != null ? arcade.body.allowRotation : true;
    }
    inline function set_allowRotation(allowRotation:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        arcade.body.allowRotation = allowRotation;
        return allowRotation;
    }

    /** An immovable visual will not receive any impacts from other visual bodies. **Two** immovable visuas can't separate or exchange momentum and will pass through each other. */
    public var immovable(get,set):Bool;
    inline function get_immovable():Bool {
        return arcade != null ? arcade.body.immovable : false;
    }
    inline function set_immovable(immovable:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        arcade.body.immovable = immovable;
        return immovable;
    }

    /** The x velocity, or rate of change the visual position. Measured in points per second. */
    public var velocityX(get,set):Float;
    inline function get_velocityX():Float {
        return arcade != null ? arcade.body.velocityX : 0;
    }
    inline function set_velocityX(velocityX:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.velocityX = velocityX;
        return velocityX;
    }

    /** The y velocity, or rate of change the visual position. Measured in points per second. */
    public var velocityY(get,set):Float;
    inline function get_velocityY():Float {
        return arcade != null ? arcade.body.velocityY : 0;
    }
    inline function set_velocityY(velocityY:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.velocityY = velocityY;
        return velocityY;
    }

    /** The velocity, or rate of change the visual position. Measured in points per second. */
    inline public function velocity(velocityX:Float, velocityY:Float):Void {
        if (arcade == null) initArcadePhysics();
        arcade.body.velocityX = velocityX;
        arcade.body.velocityY = velocityY;
    }

    /** The maximum x velocity that the visual can reach. */
    public var maxVelocityX(get,set):Float;
    inline function get_maxVelocityX():Float {
        return arcade != null ? arcade.body.maxVelocityX : 10000;
    }
    inline function set_maxVelocityX(maxVelocityX:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.maxVelocityX = maxVelocityX;
        return maxVelocityX;
    }

    /** The maximum y velocity that the visual can reach. */
    public var maxVelocityY(get,set):Float;
    inline function get_maxVelocityY():Float {
        return arcade != null ? arcade.body.maxVelocityY : 10000;
    }
    inline function set_maxVelocityY(maxVelocityY:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.maxVelocityY = maxVelocityY;
        return maxVelocityY;
    }

    /** The maximum velocity that the visual can reach. */
    inline public function maxVelocity(maxVelocityX:Float, maxVelocityY:Float):Void {
        if (arcade == null) initArcadePhysics();
        arcade.body.maxVelocityX = maxVelocityX;
        arcade.body.maxVelocityY = maxVelocityY;
    }

    /** The x acceleration is the rate of change of the x velocity. Measured in points per second squared. */
    public var accelerationX(get,set):Float;
    inline function get_accelerationX():Float {
        return arcade != null ? arcade.body.accelerationX : 0;
    }
    inline function set_accelerationX(accelerationX:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.accelerationX = accelerationX;
        return accelerationX;
    }

    /** The y acceleration is the rate of change of the y velocity. Measured in points per second squared. */
    public var accelerationY(get,set):Float;
    inline function get_accelerationY():Float {
        return arcade != null ? arcade.body.accelerationY : 0;
    }
    inline function set_accelerationY(accelerationY:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.accelerationY = accelerationY;
        return accelerationY;
    }

    /** The acceleration is the rate of change of the y velocity. Measured in points per second squared. */
    inline public function acceleration(accelerationX:Float, accelerationY:Float):Void {
        if (arcade == null) initArcadePhysics();
        arcade.body.accelerationX = accelerationX;
        arcade.body.accelerationY = accelerationY;
    }

    /** Allow this visual to be influenced by drag */
    public var allowDrag(get,set):Bool;
    inline function get_allowDrag():Bool {
        return arcade != null ? arcade.body.allowDrag : true;
    }
    inline function set_allowDrag(allowDrag:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        arcade.body.allowDrag = allowDrag;
        return allowDrag;
    }

    /** The x drag is the rate of reduction of the x velocity, kind of deceleration. Measured in points per second squared. */
    public var dragX(get,set):Float;
    inline function get_dragX():Float {
        return arcade != null ? arcade.body.dragX : 0;
    }
    inline function set_dragX(dragX:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.dragX = dragX;
        return dragX;
    }

    /** The y drag is the rate of reduction of the y velocity, kind of deceleration. Measured in points per second squared. */
    public var dragY(get,set):Float;
    inline function get_dragY():Float {
        return arcade != null ? arcade.body.dragY : 0;
    }
    inline function set_dragY(dragY:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.dragY = dragY;
        return dragY;
    }

    /** The drag is the rate of reduction of the velocity, kind of deceleration. Measured in points per second squared. */
    inline public function drag(dragX:Float, dragY:Float):Void {
        if (arcade == null) initArcadePhysics();
        arcade.body.dragX = dragX;
        arcade.body.dragY = dragY;
    }

    /** The x elasticity of the visual when colliding. `bounceX = 1` means full rebound, `bounceX = 0.5` means 50% rebound velocity. */
    public var bounceX(get,set):Float;
    inline function get_bounceX():Float {
        return arcade != null ? arcade.body.bounceX : 0;
    }
    inline function set_bounceX(bounceX:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.bounceX = bounceX;
        return bounceX;
    }

    /** The y elasticity of the visual when colliding. `bounceY = 1` means full rebound, `bounceY = 0.5` means 50% rebound velocity. */
    public var bounceY(get,set):Float;
    inline function get_bounceY():Float {
        return arcade != null ? arcade.body.bounceY : 0;
    }
    inline function set_bounceY(bounceY:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.bounceY = bounceY;
        return bounceY;
    }

    /** The elasticity of the visual when colliding. `1` means full rebound, `0.5` means 50% rebound velocity. */
    inline public function bounce(bounceX:Float, bounceY:Float):Void {
        if (arcade == null) initArcadePhysics();
        arcade.body.bounceX = bounceX;
        arcade.body.bounceY = bounceY;
    }

    /** Enable or disable world bounds specific bounce value with `worldBounceX` and `worldBounceY`.
        Disabled by default, meaning `bounceX` and `bounceY` are used by default. */
    public var useWorldBounce(get,set):Bool;
    inline function get_useWorldBounce():Bool {
        return arcade != null ? arcade.body.useWorldBounce : false;
    }
    inline function set_useWorldBounce(useWorldBounce:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        arcade.body.useWorldBounce = useWorldBounce;
        return useWorldBounce;
    }

    /** The x elasticity of the visual when colliding with world bounds. Ignored if `useWorldBounce` is `false` (`bounceX` used instead). */
    public var worldBounceX(get,set):Float;
    inline function get_worldBounceX():Float {
        return arcade != null ? arcade.body.worldBounceX : 0;
    }
    inline function set_worldBounceX(worldBounceX:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.worldBounceX = worldBounceX;
        return worldBounceX;
    }

    /** The y elasticity of the visual when colliding with world bounds. Ignored if `useWorldBounce` is `false` (`bounceY` used instead). */
    public var worldBounceY(get,set):Float;
    inline function get_worldBounceY():Float {
        return arcade != null ? arcade.body.worldBounceY : 0;
    }
    inline function set_worldBounceY(worldBounceY:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.worldBounceY = worldBounceY;
        return worldBounceY;
    }

    /** The elasticity of the visual when colliding with world bounds. Ignored if `useWorldBounce` is `false` (`bounceY` used instead). */
    inline public function worldBounce(worldBounceX:Float, worldBounceY:Float):Void {
        if (arcade == null) initArcadePhysics();
        arcade.body.worldBounceX = worldBounceX;
        arcade.body.worldBounceY = worldBounceY;
    }

    /** The maximum x delta per frame. `0` (default) means no maximum delta. */
    public var maxDeltaX(get,set):Float;
    inline function get_maxDeltaX():Float {
        return arcade != null ? arcade.body.maxDeltaX : 0;
    }
    inline function set_maxDeltaX(maxDeltaX:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.maxDeltaX = maxDeltaX;
        return maxDeltaX;
    }

    /** The maximum y delta per frame. `0` (default) means no maximum delta. */
    public var maxDeltaY(get,set):Float;
    inline function get_maxDeltaY():Float {
        return arcade != null ? arcade.body.maxDeltaY : 0;
    }
    inline function set_maxDeltaY(maxDeltaY:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.maxDeltaY = maxDeltaY;
        return maxDeltaY;
    }

    /** The maxDelta, or rate of change the visual position. Measured in points per second. */
    inline public function maxDelta(maxDeltaX:Float, maxDeltaY:Float):Void {
        if (arcade == null) initArcadePhysics();
        arcade.body.maxDeltaX = maxDeltaX;
        arcade.body.maxDeltaY = maxDeltaY;
    }

    /** Allow this visual to be influenced by gravity, either world or local. */
    public var allowGravity(get,set):Bool;
    inline function get_allowGravity():Bool {
        return arcade != null ? arcade.body.allowGravity : false;
    }
    inline function set_allowGravity(allowGravity:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        arcade.body.allowGravity = allowGravity;
        return allowGravity;
    }

    /** This visual's local y gravity, **added** to any world gravity, unless `allowGravity` is set to false. */
    public var gravityX(get,set):Float;
    inline function get_gravityX():Float {
        return arcade != null ? arcade.body.gravityX : 0;
    }
    inline function set_gravityX(gravityX:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.gravityX = gravityX;
        return gravityX;
    }

    /** This visual's local x gravity, **added** to any world gravity, unless `allowGravity` is set to false. */
    public var gravityY(get,set):Float;
    inline function get_gravityY():Float {
        return arcade != null ? arcade.body.gravityY : 0;
    }
    inline function set_gravityY(gravityY:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.gravityY = gravityY;
        return gravityY;
    }

    /** This visual's local gravity, **added** to any world gravity, unless `allowGravity` is set to false. */
    inline public function gravity(gravityX:Float, gravityY:Float):Void {
        if (arcade == null) initArcadePhysics();
        arcade.body.gravityX = gravityX;
        arcade.body.gravityY = gravityY;
    }

    /** If this visual is `immovable` and moving, and another visual body is 'riding' this one, this is the amount of motion the riding body receives on x axis. */
    public var frictionX(get,set):Float;
    inline function get_frictionX():Float {
        return arcade != null ? arcade.body.frictionX : 1;
    }
    inline function set_frictionX(frictionX:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.frictionX = frictionX;
        return frictionX;
    }

    /** If this visual is `immovable` and moving, and another visual body is 'riding' this one, this is the amount of motion the riding body receives on y axis. */
    public var frictionY(get,set):Float;
    inline function get_frictionY():Float {
        return arcade != null ? arcade.body.frictionY : 0;
    }
    inline function set_frictionY(frictionY:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.frictionY = frictionY;
        return frictionY;
    }

    /** If this visual is `immovable` and moving, and another visual body is 'riding' this one, this is the amount of motion the riding body receives on x & y axis. */
    inline public function friction(frictionX:Float, frictionY:Float):Void {
        if (arcade == null) initArcadePhysics();
        arcade.body.frictionX = frictionX;
        arcade.body.frictionY = frictionY;
    }

    /** The angular velocity is the rate of change of the visual's rotation. It is measured in degrees per second. */
    public var angularVelocity(get,set):Float;
    inline function get_angularVelocity():Float {
        return arcade != null ? arcade.body.angularVelocity : 0;
    }
    inline function set_angularVelocity(angularVelocity:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.angularVelocity = angularVelocity;
        return angularVelocity;
    }

    /** The maximum angular velocity in degrees per second that the visual can reach. */
    public var maxAngularVelocity(get,set):Float;
    inline function get_maxAngularVelocity():Float {
        return arcade != null ? arcade.body.maxAngularVelocity : 1000;
    }
    inline function set_maxAngularVelocity(maxAngularVelocity:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.maxAngularVelocity = maxAngularVelocity;
        return maxAngularVelocity;
    }

    /** The angular acceleration is the rate of change of the angular velocity. Measured in degrees per second squared. */
    public var angularAcceleration(get,set):Float;
    inline function get_angularAcceleration():Float {
        return arcade != null ? arcade.body.angularAcceleration : 0;
    }
    inline function set_angularAcceleration(angularAcceleration:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.angularAcceleration = angularAcceleration;
        return angularAcceleration;
    }

    /** The angular drag is the rate of reduction of the angular velocity. Measured in degrees per second squared. */
    public var angularDrag(get,set):Float;
    inline function get_angularDrag():Float {
        return arcade != null ? arcade.body.angularDrag : 0;
    }
    inline function set_angularDrag(angularDrag:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.angularDrag = angularDrag;
        return angularDrag;
    }

    /** The mass of the visual's body. When two bodies collide their mass is used in the calculation to determine the exchange of velocity. */
    public var mass(get,set):Float;
    inline function get_mass():Float {
        return arcade != null ? arcade.body.mass : 1;
    }
    inline function set_mass(mass:Float):Float {
        if (arcade == null) initArcadePhysics();
        arcade.body.mass = mass;
        return mass;
    }

    /** The speed of the visual's body (read only). Equal to the magnitude of the velocity. */
    public var speed(get,never):Float;
    inline function get_speed():Float {
        return arcade != null ? arcade.body.speed : 0;
    }

    /** Whether the physics system should update the visual's position and rotation based on its velocity, acceleration, drag, and gravity. */
    public var moves(get,set):Bool;
    inline function get_moves():Bool {
        return arcade != null ? arcade.body.moves : false;
    }
    inline function set_moves(moves:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        arcade.body.moves = moves;
        return moves;
    }

    /** When this visual's body collides with another, the amount of overlap (x axis) is stored here. */
    public var overlapX(get,never):Float;
    inline function get_overlapX():Float {
        return arcade != null ? arcade.body.overlapX : 1;
    }

    /** When this visual's body collides with another, the amount of overlap (y axis) is stored here. */
    public var overlapY(get,never):Float;
    inline function get_overlapY():Float {
        return arcade != null ? arcade.body.overlapY : 0;
    }
    
    /** If a visual's body is overlapping with another body, but neither of them are moving (maybe they spawned on-top of each other?) this is set to `true`. */
    public var embedded(get,never):Bool;
    inline function get_embedded():Bool {
        return arcade != null ? arcade.body.embedded : false;
    }
    
    /** A visual body can be set to collide against the world bounds automatically and rebound back into the world if this is set to true. Otherwise it will leave the world. */
    public var collideWorldBounds(get,never):Bool;
    inline function get_collideWorldBounds():Bool {
        return arcade != null ? arcade.body.collideWorldBounds : false;
    }
    inline function set_collideWorldBounds(collideWorldBounds:Bool):Bool {
        if (arcade == null) initArcadePhysics();
        arcade.body.collideWorldBounds = collideWorldBounds;
        return collideWorldBounds;
    }

    /** Dispatched when this visual body collides with another visual's body. */
    inline public function onCollide(owner:Entity, handleVisual1Visual2:Visual->Visual->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onCollide(owner, handleVisual1Visual2);
    }

    /** Dispatched when this visual body collides with another visual's body. */
    inline public function onceCollide(owner:Entity, handleVisual1Visual2:Visual->Visual->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onceCollide(owner, handleVisual1Visual2);
    }

    /** Dispatched when this visual body collides with another visual's body. */
    inline public function offCollide(?handleVisual1Visual2:Visual->Visual->Void):Void {
        if (arcade != null) {
            arcade.offCollide(handleVisual1Visual2);
        }
    }

    /** Dispatched when this visual body collides with another visual's body. */
    inline public function listensCollide():Bool {
        return arcade != null ? arcade.listensCollide() : false;
    }

    /** Dispatched when this visual body collides with another body. */
    inline public function onCollideBody(owner:Entity, handleVisualBody:Visual->arcade.Body->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onCollideBody(owner, handleVisualBody);
    }

    /** Dispatched when this visual body collides with another body. */
    inline public function onceCollideBody(owner:Entity, handleVisualBody:Visual->arcade.Body->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onceCollideBody(owner, handleVisualBody);
    }

    /** Dispatched when this visual body collides with another body. */
    inline public function offCollideBody(?handleVisualBody:Visual->arcade.Body->Void):Void {
        if (arcade != null) {
            arcade.offCollideBody(handleVisualBody);
        }
    }

    /** Dispatched when this visual body collides with another body. */
    inline public function listensCollideBody():Bool {
        return arcade != null ? arcade.listensCollideBody() : false;
    }

    /** Dispatched when this visual body overlaps with another visual's body. */
    inline public function onOverlap(owner:Entity, handleVisual1Visual2:Visual->Visual->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onOverlap(owner, handleVisual1Visual2);
    }

    /** Dispatched when this visual body overlaps with another visual's body. */
    inline public function onceOverlap(owner:Entity, handleVisual1Visual2:Visual->Visual->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onceOverlap(owner, handleVisual1Visual2);
    }

    /** Dispatched when this visual body overlaps with another visual's body. */
    inline public function offOverlap(?handleVisual1Visual2:Visual->Visual->Void):Void {
        if (arcade != null) {
            arcade.offOverlap(handleVisual1Visual2);
        }
    }

    /** Dispatched when this visual body overlaps with another visual's body. */
    inline public function listensOverlap():Bool {
        return arcade != null ? arcade.listensOverlap() : false;
    }

    /** Dispatched when this visual body overlaps with another body. */
    inline public function onOverlapBody(owner:Entity, handleVisualBody:Visual->arcade.Body->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onOverlapBody(owner, handleVisualBody);
    }

    /** Dispatched when this visual body overlaps with another body. */
    inline public function onceOverlapBody(owner:Entity, handleVisualBody:Visual->arcade.Body->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onceOverlapBody(owner, handleVisualBody);
    }

    /** Dispatched when this visual body overlaps with another body. */
    inline public function offOverlapBody(?handleVisualBody:Visual->arcade.Body->Void):Void {
        if (arcade != null) {
            arcade.offOverlapBody(handleVisualBody);
        }
    }

    /** Dispatched when this visual body overlaps with another body. */
    inline public function listensOverlapBody():Bool {
        return arcade != null ? arcade.listensOverlapBody() : false;
    }

    /** Dispatched when this visual body collides with the world bounds. */
    inline public function onWorldBounds(owner:Entity, handleVisualUpDownLeftRight:Visual->Bool->Bool->Bool->Bool->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onWorldBounds(owner, handleVisualUpDownLeftRight);
    }

    /** Dispatched when this visual body collides with the world bounds. */
    inline public function onceWorldBounds(owner:Entity, handleVisualUpDownLeftRight:Visual->Bool->Bool->Bool->Bool->Void):Void {
        if (arcade == null) initArcadePhysics();
        arcade.onceWorldBounds(owner, handleVisualUpDownLeftRight);
    }

    /** Dispatched when this visual body collides with the world bounds. */
    inline public function offWorldBounds(?handleVisualUpDownLeftRight:Visual->Bool->Bool->Bool->Bool->Void):Void {
        if (arcade != null) {
            arcade.offWorldBounds(handleVisualUpDownLeftRight);
        }
    }

    /** Dispatched when this visual body collides with the world bounds. */
    inline public function listensWorldBounds():Bool {
        return arcade != null ? arcade.listensWorldBounds() : false;
    }

    #end

#end

#if ceramic_nape_physics

/// Arcade physics

    /** The nape physics (body) of this visual. */
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

    /** Init nape physics body bound to this visual. */
    public function initNapePhysics(
        type:ceramic.NapePhysicsBodyType,
        ?space:nape.space.Space,
        ?shape:nape.shape.Polygon,
        ?material:nape.phys.Material
    ):VisualNapePhysics {

        if (nape != null) {
            nape.destroy();
            nape = null;
        }

        var w = width * scaleX;
        var h = height * scaleY;

        nape = new VisualNapePhysics(
            type,
            shape,
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

    /** Get this visual typed as `Quad` or null if it isn't a `Quad` */
    public var asQuad:Quad = null;

    /** Get this visual typed as `Mesh` or null if it isn't a `Mesh` */
    public var asMesh:Mesh = null;

/// Properties

    /** When enabled, this visual will receive as many up/down/click/over/out events as
        there are fingers or mouse pointer interacting with it.
        Default is `false`, ensuring there is never multiple up/down/click/over/out that
        overlap each other. In that case, it triggers `pointer down` when the first finger/pointer hits
        the visual and trigger `pointer up` when the last finger/pointer stops touching it. Behavior is
        similar for `pointer over` and `pointer out` events. */
    public var multiTouch:Bool = false;

    /** Whether this visual is between a `pointer down` and an `pointer up` event or not. */
    public var isPointerDown(get,null):Bool;
    var _numPointerDown:Int = 0;
    inline function get_isPointerDown():Bool { return _numPointerDown > 0; }

    /** Whether this visual is between a `pointer over` and an `pointer out` event or not. */
    public var isPointerOver(get,null):Bool;
    var _numPointerOver:Int = 0;
    inline function get_isPointerOver():Bool { return _numPointerOver > 0; }

    /** Use the given visual's bounds as clipping area. */
    public var clip(default,set):Visual = null;
    inline function set_clip(clip:Visual):Visual {
        if (this.clip == clip) return clip;
        this.clip = clip;
        clipDirty = true;
        return clip;
    }

    /** Whether this visual should inherit its parent alpha state or not. **/
    public var inheritAlpha(default,set):Bool = false;
    inline function set_inheritAlpha(inheritAlpha:Bool):Bool {
        if (this.inheritAlpha == inheritAlpha) return inheritAlpha;
        this.inheritAlpha = inheritAlpha;
        visibilityDirty = true;
        return inheritAlpha;
    }

    /**
     * Stop this visual, whatever that means (override in subclasses).
     * When arcade physics are enabled, they are also stopped from this call.
     */
    public function stop():Void {
#if ceramic_arcade_physics
        if (arcade != null) arcade.body.stop;
#end
    }

#if ceramic_debug_rendering_option

    public var debugRendering:DebugRendering = DebugRendering.DEFAULT;

#end

#if ceramic_luxe_legacy

    /** Allows the backend to keep data associated with this visual. */
    public var backendItem:VisualItem;

#end

    /** Computed flag that tells whether this visual is only translated,
        thus not rotated, skewed nor scaled.
        When this is `true`, matrix computation may be a bit faster as it
        will skip some unneeded matrix computation. */
    public var translatesOnly:Bool = true;

    /** Whether we should re-check if this visual is only translating or having a more complex transform */
    public var translatesOnlyDirty:Bool = false;

    /** Setting this to true will force the visual to recompute its displayed content */
    public var contentDirty(default, set):Bool = true;
    inline function set_contentDirty(contentDirty:Bool):Bool {
        this.contentDirty = contentDirty;
        if (contentDirty) {
            ceramic.App.app.visualsContentDirty = true;
        }
        return contentDirty;
    }

    /** Setting this to true will force the visual's matrix to be re-computed */
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

    /** Setting this to true will force the visual's computed render target to be re-computed */
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

    /** Setting this to true will force the visual to compute it's visility in hierarchy */
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

    /** Setting this to true will force the visual to compute it's touchability in hierarchy */
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

    /** Setting this to true will force the visual to compute it's clipping state in hierarchy */
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
    /** If set, the visual will be rendered into this target RenderTexture instance
        instead of being drawn onto screen directly. */
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

    @editable({ group: 'active' })
    public var visible(default,set):Bool = true;
    function set_visible(visible:Bool):Bool {
        if (this.visible == visible) return visible;
        this.visible = visible;
        visibilityDirty = true;
        return visible;
    }

    @editable({ group: 'active' })
    public var touchable(default,set):Bool = true;
    function set_touchable(touchable:Bool):Bool {
        if (this.touchable == touchable) return touchable;
        this.touchable = touchable;
        touchableDirty = true;
        return touchable;
    }

    @editable({ group: 'depth' })
    public var depth(default,set):Float = 0;
    function set_depth(depth:Float):Float {
        if (this.depth == depth) return depth;
        this.depth = depth;
        ceramic.App.app.hierarchyDirty = true;
        return depth;
    }


    /** If set, children will be sort by depth and their computed depth
        will be within range [parent.depth, parent.depth + depthRange] */
    @editable({ group: 'depth', label: 'Range' })
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

    @editable({ group: 'position' })
    public var x(default,set):Float = 0;
    function set_x(x:Float):Float {
        if (this.x == x) return x;
        this.x = x;
        matrixDirty = true;
        return x;
    }

    @editable({ group: 'position' })
    public var y(default,set):Float = 0;
    function set_y(y:Float):Float {
        if (this.y == y) return y;
        this.y = y;
        matrixDirty = true;
        return y;
    }

    @editable({ group: 'scale' })
    public var scaleX(default,set):Float = 1;
    function set_scaleX(scaleX:Float):Float {
        if (this.scaleX == scaleX) return scaleX;
        this.scaleX = scaleX;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return scaleX;
    }

    @editable({ group: 'scale' })
    public var scaleY(default,set):Float = 1;
    function set_scaleY(scaleY:Float):Float {
        if (this.scaleY == scaleY) return scaleY;
        this.scaleY = scaleY;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return scaleY;
    }

    @editable({ group: 'skew' })
    public var skewX(default,set):Float = 0;
    function set_skewX(skewX:Float):Float {
        if (this.skewX == skewX) return skewX;
        this.skewX = skewX;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return skewX;
    }

    @editable({ group: 'skew' })
    public var skewY(default,set):Float = 0;
    function set_skewY(skewY:Float):Float {
        if (this.skewY == skewY) return skewY;
        this.skewY = skewY;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return skewY;
    }

    @editable({ group: 'anchor' })
    public var anchorX(default,set):Float = 0;
    function set_anchorX(anchorX:Float):Float {
        if (this.anchorX == anchorX) return anchorX;
        this.anchorX = anchorX;
        matrixDirty = true;
        return anchorX;
    }

    @editable({ group: 'anchor' })
    public var anchorY(default,set):Float = 0;
    function set_anchorY(anchorY:Float):Float {
        if (this.anchorY == anchorY) return anchorY;
        this.anchorY = anchorY;
        matrixDirty = true;
        return anchorY;
    }

    @editable({ min: 0, group: 'size' })
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

    @editable({ min: 0, group: 'size' })
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

    @editable({ slider: [0, 360], degrees: true })
    public var rotation(default,set):Float = 0;
    function set_rotation(rotation:Float):Float {
        if (this.rotation == rotation) return rotation;
        this.rotation = rotation;
        matrixDirty = true;
        translatesOnlyDirty = true;
        return rotation;
    }

    @editable({ slider: [0, 1] })
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
     * the visual with a `tx` value of `translateX`
     */
    @editable({ group: 'translate' })
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
     * the visual with a `ty` value of `translateY`
     */
    @editable({ group: 'translate' })
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

    /** Set additional matrix-based transform to this visual. Default is null. */
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

    /** Assign a shader to this visual. */
    @editable
    public var shader:Shader = null;

/// Flags

    /** Read and write arbitrary boolean flags on this visual.
        Index should be between 0 (included) and 16 (excluded) or result is undefined. */
    inline public function flag(index:Int, ?value:Bool):Bool {

        var i = index + 16;
        return value != null ? flags.setBool(i, value) : flags.bool(i);

    }

    /** Read and write arbitrary boolean flags on this visual.
        Index should be between 0 (included) and 16 (excluded) or result is undefined.
        /!\ Reserved for internal use */
    inline private function internalFlag(index:Int, ?value:Bool):Bool {

        return value != null ? flags.setBool(index, value) : flags.bool(index);

    }

    /** Just a way to store some flags. **/
    var flags:Flags = new Flags();

    /** Whether this visual is `active`. Default is **true**. When setting it to **false**,
        the visual won't be `visible` nor `touchable` anymore (these get set to **false**).
        When restoring `active` to **true**, `visible` and `touchable` will also get back
        their previous state. **/
    public var active(get,set):Bool;
    inline function get_active():Bool {
        return !flags.bool(0);
    }
    function set_active(active:Bool):Bool {
        if (active == !flags.bool(0)) return active;
        flags.setBool(0, !active);
        if (active) {
            visible = flags.bool(1);
            touchable = flags.bool(2);
#if ceramic_arcade_physics
            var body = this.body;
            if (body != null) {
                body.enable = flags.bool(3);
            }
#end
        }
        else {
            flags.setBool(1, visible);
            flags.setBool(2, touchable);
            visible = false;
            touchable = false;
#if ceramic_arcade_physics
            var body = this.body;
            if (body != null) {
                flags.setBool(3, body.enable);
            }
            else {
                flags.setBool(3, false);
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

    public var computedVisible:Bool = true;

    public var computedAlpha:Float = 1;

    public var computedDepth:Float = 0;

    public var computedRenderTarget:RenderTexture = null;

    public var computedTouchable:Bool = true;

    public var computedClip:Bool = false;

/// Properties (Children)

    public var children(default,null):ReadOnlyArray<Visual> = null;

    //@editable
    public var parent(default,null):Visual = null;

/// Internal

    inline static var _degToRad:Float = 0.017453292519943295;

    static var _matrix:Transform = new Transform();

    static var _point:Point = new Point();

/// Helpers

    inline public function size(width:Float, height:Float):Void {

        this.width = width;
        this.height = height;

    }

    inline public function anchor(anchorX:Float, anchorY:Float):Void {

        this.anchorX = anchorX;
        this.anchorY = anchorY;

    }

    inline public function pos(x:Float, y:Float):Void {

        this.x = x;
        this.y = y;

    }

    inline public function scale(scaleX:Float, scaleY:Float = -1):Void {

        this.scaleX = scaleX;
        this.scaleY = scaleY != -1 ? scaleY : scaleX;

    }

    inline public function skew(skewX:Float, skewY:Float):Void {

        this.skewX = skewX;
        this.skewY = skewY;

    }

    inline public function translate(translateX:Float, translateY:Float):Void {

        this.translateX = translateX;
        this.translateY = translateY;

    }

/// Advanced helpers

    /** Change the visual's anchor but update its x and y values to make
        it keep its current position. */
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

    /** Returns the first child matching the requested `id` or `null` otherwise. */
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

/// Lifecycle

    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        super(#if ceramic_debug_entity_allocs pos #end);

        ceramic.App.app.visuals.push(this);
        ceramic.App.app.hierarchyDirty = true;

#if ceramic_luxe_legacy
        backendItem = ceramic.App.app.backend.draw.getItem(this);
#end

    }

    override public function destroy() {

        super.destroy();

        if (ceramic.App.app.screen.focusedVisual == this) {
            ceramic.App.app.screen.focusedVisual = null;
        }
        
        ceramic.App.app.visuals.remove(this);
        ceramic.App.app.hierarchyDirty = true;

        if (parent != null) parent.remove(this);
        if (transform != null) transform = null;

#if ceramic_arcade_physics
        if (arcade != null) {
            arcade.destroy();
            arcade = null;
        }
#end

#if ceramic_nape_physics
        if (nape != null) {
            nape.destroy();
            nape = null;
        }
#end

        clear();

    }

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

    function transformDidChange() {

        matrixDirty = true;

    }

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
            if (translatesOnly && transform == null) {

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

        // Matrix is up to date
        matrixDirty = false;

    }

/// Hit test

    /** Returns true if screen (x, y) screen coordinates hit/intersect this visual visible bounds */
    public function hits(x:Float, y:Float):Bool {

        // A visuals that renders to texture never hits by default
        // unless the render texture is managed by a `Filter` instance, re-routing touch
        if (renderTargetDirty) computeRenderTarget();
        if (computedRenderTarget != null) {
            var parent = this.parent;
            if (parent != null) {
                do {
                    if (parent.asQuad != null && Std.is(parent, Filter)) {
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

        if (matrixDirty) {
            computeMatrix();
        }

        _matrix.setTo(matA, matB, matC, matD, matTX, matTY);
        _matrix.invert();

        return hitTest(x, y, _matrix);

    }

    /** The actual hit test performed on the visual.
        If needed to change how hit test is performed
        on a visual subclass, this is the method to override. */
    function hitTest(x:Float, y:Float, matrix:Transform):Bool {

        var testX = _matrix.transformX(x, y);
        var testY = _matrix.transformY(x, y);

        return testX >= 0
            && testX < width
            && testY >= 0
            && testY < height;

    }

    /** Override this method in subclasses to intercept hitting pointer down events on this visual's children (any level in sub-hierarchy).
        Return `true` to stop an event from being triggered on the hitting child, `false` (default) otherwise. */
    function interceptPointerDown(hittingVisual:Visual, x:Float, y:Float, touchIndex:Int, buttonId:Int):Bool {

        return false;

    }

    /** Override this method in subclasses to intercept hitting pointer over events on this visual's children (any level in sub-hierarchy).
        Return `true` to stop an event from being triggered on the hitting child, `false` (default) otherwise. */
    function interceptPointerOver(hittingVisual:Visual, x:Float, y:Float):Bool {

        return false;

    }

/// Screen to visual positions and vice versa

    /** Assign X and Y to given point after converting them from screen coordinates to current visual coordinates. */
    public function screenToVisual(x:Float, y:Float, point:Point, handleFilters:Bool = true):Void {

        if (matrixDirty) {
            computeMatrix();
        }

        _matrix.setTo(matA, matB, matC, matD, matTX, matTY);
        _matrix.invert();

        point.x = _matrix.transformX(x, y);
        point.y = _matrix.transformY(x, y);

        if (handleFilters) {
            // A visuals that renders to texture never hits by default
            // unless the render texture is managed by a `Filter` instance, re-routing touch
            if (renderTargetDirty) computeRenderTarget();
            if (computedRenderTarget != null) {
                var parent = this.parent;
                if (parent != null) {
                    do {
                        if (parent.asQuad != null && Std.is(parent, Filter)) {
                            var filter:Filter = cast parent;
                            if (filter.renderTexture == computedRenderTarget) {
                                filter.screenToVisual(point.x, point.y, point);
                                break;
                            }
                        }
                        parent = parent.parent;
                    }
                    while (parent != null);
                }
            }
        }

    }

    /** Assign X and Y to given point after converting them from current visual coordinates to screen coordinates. */
    public function visualToScreen(x:Float, y:Float, point:Point, handleFilters:Bool = true):Void {

        if (matrixDirty) {
            computeMatrix();
        }

        _matrix.setTo(matA, matB, matC, matD, matTX, matTY);

        point.x = _matrix.transformX(x, y);
        point.y = _matrix.transformY(x, y);

        if (handleFilters) {
            // A visuals that renders to texture never hits by default
            // unless the render texture is managed by a `Filter` instance, re-routing touch
            if (renderTargetDirty) computeRenderTarget();
            if (computedRenderTarget != null) {
                var parent = this.parent;
                if (parent != null) {
                    do {
                        if (parent.asQuad != null && Std.is(parent, Filter)) {
                            var filter:Filter = cast parent;
                            if (filter.renderTexture == computedRenderTarget) {
                                filter.visualToScreen(point.x, point.y, point);
                                break;
                            }
                        }
                        parent = parent.parent;
                    }
                    while (parent != null);
                }
            }
        }

    }

/// Transform from visual

    /** Assign X and Y to given point after converting them from current visual coordinates to screen coordinates. */
    public function visualToTransform(transform:Transform):Void {

        if (matrixDirty) {
            computeMatrix();
        }

        transform.setTo(matA, matB, matC, matD, matTX, matTY);

    }

/// Visibility / Alpha

    function computeVisibility() {

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

        computedClip = false;
        if (parent != null) {
            if (parent.computedClip || parent.clip != null) {
                if (computedRenderTarget == parent.computedRenderTarget) {
                    computedClip = true;
                }
            }
        }

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

    public function computeContent() {
        
        contentDirty = false;

    }

/// Children

    static var _minDepth:Float = 0;

    static var _maxDepth:Float = 0;

    /**
     * Will walk on every children and set their depths starting from 
     * `start` and incrementing depth by `step`.
     * @param start the depth starting value (default 1). First child will have this depth, next child `depthStart + depthStep` etc...
     * @param step the depth step to use when increment depth for each child
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

    /** Compute children depth. The result depends on whether
        a parent defines a custom `depthRange` value or not. */
    function computeChildrenDepth():Void {

        if (children != null) {

            // Compute deepest in hierarchy first
            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                child.computedDepth = child.depth * DEPTH_FACTOR;
                child.computeChildrenDepth();
            }

            // Apply depth range if any
            if (depthRange != -1) {

                _minDepth = 9999999999;
                _maxDepth = -9999999999;

                // Compute min/max depth
                for (i in 0...children.length) {
                    var child = children.unsafeGet(i);
                    child.computeMinMaxDepths();
                }

                // Multiply depth
                for (i in 0...children.length) {
                    var child = children.unsafeGet(i);
                    child.multiplyDepths(computedDepth + Math.min(DEPTH_MARGIN, depthRange * DEPTH_FACTOR), Math.max(0, depthRange * DEPTH_FACTOR - DEPTH_MARGIN));
                }
            }
        }

    }

    function computeMinMaxDepths():Void {

        if (_minDepth > computedDepth) _minDepth = computedDepth;
        if (_maxDepth < computedDepth + 1) _maxDepth = computedDepth + 1;

        if (children != null) {

            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                child.computeMinMaxDepths();
            }
        }

    }

    function multiplyDepths(startDepth:Float, targetRange:Float):Void {

        if (_maxDepth == _minDepth) {
            computedDepth = startDepth + 0.5 * targetRange;
        } else {
            computedDepth = startDepth + ((computedDepth - _minDepth) / (_maxDepth - _minDepth)) * targetRange;
        }

        // Multiply recursively
        if (children != null) {

            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                child.multiplyDepths(startDepth, targetRange);
            }
        }

    }

    public function hasIndirectParent(targetParent:Visual):Bool {

        var parent = this.parent;
        while (parent != null) {
            if (parent == targetParent) return true;
            parent = parent.parent;
        }

        return false;

    }

    public function firstParentWithClass<T>(clazz:Class<T>):T {

        var parent = this.parent;
        while (parent != null) {
            if (Std.is(parent, clazz)) return cast parent;
            parent = parent.parent;
        }

        return null;

    }

    public function add(visual:Visual):Void {

        if (visual == this) {
            throw 'A visual cannot add itself as child!';
        }

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

    /** Returns `true` if the current visual contains this child.
        When `recursive` option is `true`, will return `true` if
        the current visual contains this child or one of
        its direct or indirect children does. */
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

    /** Compute bounds from children this visual contains.
        This overwrites width, height, anchorX and anchorY properties accordingly.
        Warning: this may be an expensive operation. */
    function computeBounds():Void {

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

#if editor

/// Editor

    public static function editorSetupEntity(entityData:editor.model.EditorEntityData) {

        entityData.props.set('width', 100);
        entityData.props.set('height', 100);

    }

#end

}
