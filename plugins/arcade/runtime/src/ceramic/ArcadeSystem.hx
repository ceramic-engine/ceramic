package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

#if plugin_arcade

/**
 * Main system managing Arcade physics simulation in Ceramic.
 * 
 * This system integrates the Arcade physics engine with Ceramic's visual system,
 * automatically synchronizing physics bodies with their visual representations.
 * It manages physics worlds, groups, and handles the update cycle for all physics objects.
 * 
 * The system operates in two phases:
 * - Early update: Updates physics simulation and processes collisions
 * - Late update: Applies physics results back to visual positions
 * 
 * Usage example:
 * ```haxe
 * // Access the arcade system
 * var arcade = app.systems.arcade;
 * 
 * // Use the default world
 * arcade.world.gravity.y = 800;
 * 
 * // Create custom worlds
 * var customWorld = arcade.createWorld();
 * ```
 * 
 * @see ArcadeWorld for physics world configuration
 * @see VisualArcadePhysics for adding physics to visuals
 */
@:allow(ceramic.App)
class ArcadeSystem extends System {

    /**
     * Event fired after physics simulation but before results are applied.
     * This is the ideal time to check for collisions and overlaps between bodies.
     * @param delta Time elapsed since last frame in seconds
     */
    @event function update(delta:Float);

    /**
     * Internal queue for physics items pending destruction.
     * Items are queued during update and flushed after to avoid modifying arrays during iteration.
     */
    @:allow(ceramic.VisualArcadePhysics)
    var _destroyedItems:Array<VisualArcadePhysics> = [];
    
    /**
     * Internal queue for newly created physics items.
     * Items are queued during update and added after to avoid modifying arrays during iteration.
     */
    @:allow(ceramic.VisualArcadePhysics)
    var _createdItems:Array<VisualArcadePhysics> = [];
    
    /**
     * Internal flag to prevent item list modifications during update loops.
     */
    @:allow(ceramic.VisualArcadePhysics)
    var _freezeItems:Bool = false;

    /**
     * All active physics items in the system.
     * Each item represents a visual with attached physics body.
     */
    public var items(default, null):Array<VisualArcadePhysics> = [];

    /**
     * All physics worlds managed by this system.
     * Multiple worlds can be used to create separate physics simulations
     * (e.g., foreground and background layers with different gravity).
     */
    public var worlds(default, null):Array<ArcadeWorld> = [];

    /**
     * The default physics world used when creating physics bodies.
     * This world is automatically created and its bounds updated to match screen size
     * when `autoUpdateWorldBounds` is true.
     */
    public var world:ArcadeWorld = null;

    /**
     * Named collision groups for organizing physics bodies.
     * Groups allow efficient collision detection between specific sets of objects.
     * 
     * Example:
     * ```haxe
     * arcade.groups.set("enemies", new arcade.Group());
     * arcade.groups.set("bullets", new arcade.Group());
     * // Later: arcade.world.collide(groups.get("enemies"), groups.get("bullets"));
     * ```
     */
    public var groups:Map<String, arcade.Group> = new Map();

    /**
     * When true, the default world's bounds are automatically updated
     * to match the screen size on each frame. This ensures physics
     * boundaries adjust when the window is resized.
     * 
     * Set to false if you want to manually control world bounds.
     */
    public var autoUpdateWorldBounds:Bool = true;

    /**
     * Creates a new ArcadeSystem instance.
     * Automatically creates the default physics world with screen dimensions.
     */
    public function new() {

        super();

        earlyUpdateOrder = 2000;
        lateUpdateOrder = 2000;

        this.world = createWorld();

    }

    /**
     * Creates a new physics world with screen dimensions.
     * 
     * @param autoAdd If true, automatically adds the world to the system's world list
     * @return The newly created ArcadeWorld
     */
    public function createWorld(autoAdd:Bool = true):ArcadeWorld {

        var world = new ArcadeWorld(0, 0, screen.width, screen.height);

        if (autoAdd) {
            addWorld(world);
        }

        return world;

    }

    /**
     * Adds a physics world to the system.
     * The world will be updated each frame along with other active worlds.
     * 
     * @param world The ArcadeWorld to add
     */
    public function addWorld(world:ArcadeWorld):Void {

        if (worlds.indexOf(world) == -1) {
            worlds.push(world);
        }
        else {
            log.warning('World already added to ArcadeSystem');
        }

    }

    /**
     * Removes a physics world from the system.
     * The world will no longer be updated by the system.
     * 
     * @param world The ArcadeWorld to remove
     */
    public function removeWorld(world:ArcadeWorld):Void {

        if (!worlds.remove(world)) {
            log.warning('World not removed from ArcadeSystem because it was not added at the first place');
        }
        
    }

    /**
     * Updates all physics worlds with the given time delta.
     * @param delta Time elapsed since last frame in seconds
     */
    inline function updateWorlds(delta:Float):Void {

        for (i in 0...worlds.length) {
            var world = worlds.unsafeGet(i);
            updateWorld(world, delta);
        }

    }

    /**
     * Updates a single physics world.
     * @param world The world to update
     * @param delta Time elapsed since last frame in seconds
     */
    inline function updateWorld(world:ArcadeWorld, delta:Float):Void {

        world.elapsed = delta;

    }

    /**
     * Early update phase: synchronizes visual properties to physics bodies
     * and runs physics simulation.
     * @param delta Time elapsed since last frame in seconds
     */
    override function earlyUpdate(delta:Float):Void {

        if (delta <= 0) return;

        // Auto update default world bounds?
        if (autoUpdateWorldBounds) {
            world.setBounds(0, 0, screen.width, screen.height);
        }

        updateWorlds(delta);

        _freezeItems = true;

        // Run preUpdate()
        for (i in 0...items.length) {
            var item = items.unsafeGet(i);
            if (!item.destroyed) {
                var visual = item.visual;
                if (visual == null) {
                    log.warning('Pre updating arcade body with no visual, destroy item!');
                    item.destroy();
                }
                else if (visual.destroyed) {
                    log.warning('Pre updating arcade body with destroyed visual, destroy item!');
                    item.destroy();
                }
                else {
                    // TODO ensure position is accurate when rotation/scale with non-centered anchor?
                    var scaleX = visual.scaleX;
                    var scaleY = visual.scaleY;
                    var anchorX = visual.anchorX;
                    var anchorY = visual.anchorY;
                    if (scaleX < 0) {
                        scaleX = -scaleX;
                        anchorX = 1.0 - anchorX;
                    }
                    if (scaleY < 0) {
                        scaleY = -scaleY;
                        anchorY = 1.0 - anchorY;
                    }
                    var w = visual.width * scaleX;
                    var h = visual.height * scaleY;
                    var body = item.body;
                    if (body != null) {
                        body.preUpdate(
                            item.world,
                            item.offsetX + visual.x - w * anchorX,
                            item.offsetY + visual.y - h * anchorY,
                            w,
                            h,
                            visual.rotation
                        );
                    }
                }
            }
        }

        _freezeItems = false;

        flushDestroyedItems();
        flushCreatedItems();

        emitUpdate(delta);

    }

    /**
     * Late update phase: applies physics simulation results back to visuals.
     * This includes position updates and rotation if enabled.
     * @param delta Time elapsed since last frame in seconds
     */
    override function lateUpdate(delta:Float):Void {

        if (delta <= 0) return;

        _freezeItems = true;

        // Run postUpdate()
        for (i in 0...items.length) {
            var item = items.unsafeGet(i);
            if (!item.destroyed) {
                var visual = item.visual;
                if (visual == null) {
                    log.warning('Post updating arcade body with no visual, destroy item!');
                    item.destroy();
                }
                else if (visual.destroyed) {
                    log.warning('Post updating arcade body with destroyed visual, destroy item!');
                    item.destroy();
                }
                else {
                    var body = item.body;
                    if (body != null) {
                        body.postUpdate(world);
                        visual.x += body.dx;
                        visual.y += body.dy;
                        if (body.allowRotation) {
                            visual.rotation += body.deltaZ();
                        }
                    }
                }
            }
        }

        _freezeItems = false;

        flushDestroyedItems();
        flushCreatedItems();

    }

    /**
     * Removes all items queued for destruction from the active items list.
     */
    inline function flushDestroyedItems():Void {

        while (_destroyedItems.length > 0) {
            var item = _destroyedItems.pop();
            items.remove(item);
        }
        
    }

    /**
     * Adds all newly created items to the active items list.
     */
    inline function flushCreatedItems():Void {

        while (_createdItems.length > 0) {
            var item = _createdItems.pop();
            items.push(item);
        }
        
    }

}

#end
