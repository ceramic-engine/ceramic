package ceramic;

import ceramic.Shortcuts.*;

#if plugin_arcade

/**
 * Component that adds Arcade physics functionality to a Visual.
 * 
 * This class bridges Ceramic's visual system with the Arcade physics engine,
 * allowing any Visual to have physics properties like velocity, gravity, and
 * collision detection. It's automatically created when accessing a visual's
 * `arcade` property.
 * 
 * The component manages:
 * - Physics body creation and synchronization
 * - Collision and overlap event dispatching  
 * - World bounds detection
 * - Automatic cleanup on destruction
 * 
 * Usage example:
 * ```haxe
 * // Enable physics on a visual
 * var player = new Quad();
 * player.arcade.initBody(0, 0, 32, 32, 0);
 * player.arcade.body.velocity.y = -300; // Jump!
 * 
 * // Listen for collisions
 * player.arcade.onCollide(this, (v1, v2) -> {
 *     trace("Collision detected!");
 * });
 * ```
 * 
 * @see Visual.arcade for accessing this component
 * @see arcade.Body for physics properties
 */
@:dox(show)
class VisualArcadePhysics extends Entity {

    /**
     * Dispatched when this visual's body collides with another body.
     * 
     * This event fires for any collision, regardless of whether the other
     * body belongs to a Visual or is a standalone physics body.
     * 
     * @param visual The Visual that owns this physics component
     * @param body The other body involved in the collision
     */
    @event function collideBody(visual:Visual, body:arcade.Body);

    /**
     * Dispatched when this visual's body overlaps with another body.
     * 
     * Overlaps occur when bodies intersect but don't push each other apart.
     * Useful for triggers, collectibles, and detection zones.
     * 
     * @param visual The Visual that owns this physics component
     * @param body The other body involved in the overlap
     */
    @event function overlapBody(visual:Visual, body:arcade.Body);

    /**
     * Dispatched when this visual collides with another visual.
     * 
     * This is a convenience event that only fires when both bodies belong
     * to Visual objects, making it easier to work with visual-to-visual collisions.
     * 
     * @param visual1 This visual
     * @param visual2 The other visual involved in the collision
     */
    @event function collide(visual1:Visual, visual2:Visual);

    /**
     * Dispatched when this visual overlaps with another visual.
     * 
     * This is a convenience event that only fires when both bodies belong
     * to Visual objects, making it easier to work with visual-to-visual overlaps.
     * 
     * @param visual1 This visual
     * @param visual2 The other visual involved in the overlap
     */
    @event function overlap(visual1:Visual, visual2:Visual);

    /**
     * Dispatched when this visual's body collides with the world boundaries.
     * 
     * World bounds define the edges of the physics simulation area.
     * Bodies can be configured to collide with these bounds using
     * body.collideWorldBounds = true.
     * 
     * @param visual The Visual that hit the world bounds
     * @param up True if hit the top boundary
     * @param down True if hit the bottom boundary
     * @param left True if hit the left boundary
     * @param right True if hit the right boundary
     */
    @event function worldBounds(visual:Visual, up:Bool, down:Bool, left:Bool, right:Bool);

    /**
     * The Visual that owns this physics component.
     * Set automatically when the component is created.
     */
    public var visual:Visual = null;

    /**
     * The Arcade physics body attached to the visual.
     * 
     * This provides access to all physics properties:
     * - velocity, acceleration, drag
     * - immovable, mass, bounce
     * - collision flags (checkCollisionUp/Down/Left/Right)
     * 
     * Created by calling initBody().
     */
    public var body(default, null):arcade.Body = null;

    /**
     * The physics world this body belongs to.
     * 
     * If not set explicitly, uses the default world from ArcadeSystem.
     * Different worlds can have different gravity, bounds, and collision groups.
     */
    public var world:ArcadeWorld = null;

    /**
     * Horizontal offset of the physics body from the visual's position.
     * Useful when the collision box should be smaller or shifted from the visual.
     */
    public var offsetX:Float = 0;

    /**
     * Vertical offset of the physics body from the visual's position.
     * Useful when the collision box should be smaller or shifted from the visual.
     */
    public var offsetY:Float = 0;

    /**
     * Creates a new VisualArcadePhysics component.
     * 
     * Automatically registers with the ArcadeSystem for updates.
     * Usually created automatically when accessing visual.arcade.
     */
    public function new() {

        super();

        if (ceramic.App.app.arcade._freezeItems) {
            ceramic.App.app.arcade._createdItems.push(this);
        }
        else {
            ceramic.App.app.arcade.items.push(this);
        }

    }

    /**
     * Initializes the physics body with the specified dimensions.
     * 
     * Must be called before the body can be used in physics simulation.
     * The body's position will be synchronized with the visual each frame.
     * 
     * @param x Initial X position of the body
     * @param y Initial Y position of the body
     * @param width Width of the collision box
     * @param height Height of the collision box
     * @param rotation Initial rotation in degrees
     */
    public function initBody(x:Float, y:Float, width:Float, height:Float, rotation:Float) {

        body = new arcade.Body(x, y, width, height, rotation);
        body.data = this;

    }

    /**
     * Destroys this physics component and its body.
     * 
     * Automatically called when the visual is destroyed.
     * Removes the component from the physics system and cleans up references.
     */
    override function destroy() {

        super.destroy();

        if (visual != null) {
            if (visual.arcade == this) {
                visual.arcade = null;
            }
            visual = null;
        }

        if (body != null) {
            body.destroy();
            body = null;
        }

        if (ceramic.App.app.arcade._freezeItems) {
            ceramic.App.app.arcade._destroyedItems.push(this);
        }
        else {
            ceramic.App.app.arcade.items.remove(this);
        }

    }

    /// Event handling
    
    /**
     * Internal: Sets up collision event handler when listeners are added.
     */

    inline function willListenCollideBody()
        if (body != null) body.onCollide = handleCollide;

    inline function willListenCollide()
        if (body != null) body.onCollide = handleCollide;

    inline function willListenOverlapBody()
        if (body != null) body.onOverlap = handleOverlap;

    inline function willListenOverlap()
        if (body != null) body.onOverlap = handleOverlap;

    inline function willListenWorldBounds()
        if (body != null) body.onWorldBounds = handleWorldBounds;

    /**
     * Internal collision event handler that dispatches appropriate events.
     */
    function handleCollide(body1:arcade.Body, body2:arcade.Body):Void {

        var arcade1 = fromBody(body1);
        var arcade2 = fromBody(body2);
        var visual1 = arcade1 != null ? arcade1.visual : null;
        var visual2 = arcade2 != null ? arcade2.visual : null;

        if (visual1 != null) {
            emitCollideBody(visual1, body2);
            if (visual2 != null) {
                emitCollide(visual1, visual2);
            }
        }
        else {
            log.warning('Invalid body collide event: failed to retrieve visual from body.');
        }

    }

    /**
     * Internal overlap event handler that dispatches appropriate events.
     */
    function handleOverlap(body1:arcade.Body, body2:arcade.Body):Void {

        var arcade1 = fromBody(body1);
        var arcade2 = fromBody(body2);
        var visual1 = arcade1 != null ? arcade1.visual : null;
        var visual2 = arcade2 != null ? arcade2.visual : null;

        if (visual1 != null) {
            emitOverlapBody(visual1, body2);
            if (visual2 != null) {
                emitOverlap(visual1, visual2);
            }
        }
        else {
            log.warning('Invalid body overlap event: failed to retrieve visual from body.');
        }

    }

    /**
     * Internal world bounds collision handler that dispatches the worldBounds event.
     */
    function handleWorldBounds(body1:arcade.Body, up:Bool, down:Bool, left:Bool, right:Bool):Void {

        var arcade1 = fromBody(body1);
        var visual1 = arcade1 != null ? arcade1.visual : null;

        if (visual1 != null) {
            emitWorldBounds(visual1, up, down, left, right);
        }
        else {
            log.warning('Invalid body worldBounds event: failed to retrieve visual from body.');
        }

    }

/// Static helpers

    /**
     * Retrieves the VisualArcadePhysics component associated with a physics body.
     * 
     * Useful when you have a body reference from a collision callback and need
     * to access the visual or arcade component.
     * 
     * @param body The physics body to look up
     * @return The VisualArcadePhysics component, or null if the body doesn't belong to a visual
     */
    public static function fromBody(body:arcade.Body):VisualArcadePhysics {

        var data = body.data;
        if (Std.isOfType(data, VisualArcadePhysics)) {
            return cast data;
        }
        return null;

    }

}

#end
