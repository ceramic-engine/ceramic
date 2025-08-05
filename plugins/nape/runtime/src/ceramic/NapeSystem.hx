package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

#if plugin_nape

/**
 * Central system managing Nape physics simulation in Ceramic.
 * 
 * Handles:
 * - Multiple physics spaces (worlds)
 * - Automatic synchronization between Nape bodies and Ceramic visuals
 * - Physics stepping and timing
 * - Body lifecycle management
 * 
 * The system automatically updates visual positions and rotations based on
 * their associated physics bodies after each physics step.
 * 
 * ```haxe
 * // Access the default physics space
 * var space = app.nape.space;
 * space.gravity.setxy(0, 600); // Set gravity
 * 
 * // Create additional spaces
 * var customSpace = app.nape.createSpace();
 * customSpace.gravity.setxy(0, 300);
 * 
 * // Pause all physics
 * app.nape.paused = true;
 * ```
 */
@:allow(ceramic.App)
class NapeSystem extends System {

    /** Reusable transform matrix for position calculations */
    static var _matrix:Transform = new Transform();

    /** Queue of physics bodies pending destruction */
    @:allow(ceramic.VisualNapePhysics)
    var _destroyedItems:Array<VisualNapePhysics> = [];
    
    /** Queue of physics bodies pending creation */
    @:allow(ceramic.VisualNapePhysics)
    var _createdItems:Array<VisualNapePhysics> = [];
    
    /** Flag to defer item list modifications during updates */
    @:allow(ceramic.VisualNapePhysics)
    var _freezeItems:Bool = false;

    /**
     * Triggered right before updating/stepping nape spaces.
     * Use this to apply forces or modify physics state before simulation.
     * @param delta Time step in seconds
     */
    @event function updateSpaces(delta:Float);

    /**
     * Triggered right before applying nape bodies to visuals.
     * Visual positions are about to be updated from physics.
     */
    @event function beginUpdateVisuals();

    /**
     * Triggered right after applying nape bodies to visuals.
     * Visual positions have been synchronized with physics.
     */
    @event function endUpdateVisuals();

    /**
     * All active physics body items being managed.
     * Each item links a Nape body to a Ceramic visual.
     */
    public var items(default, null):Array<ceramic.VisualNapePhysics> = [];

    /**
     * All physics spaces (worlds) used with Nape physics.
     * Multiple spaces allow for separate physics simulations.
     */
    public var spaces(default, null):Array<nape.space.Space> = [];

    /**
     * Default space for Nape physics.
     * Bodies are added to this space unless specified otherwise.
     * Has zero gravity by default.
     */
    public var space(default, null):nape.space.Space = null;

    /**
     * If set to `true`, physics simulation is paused.
     * Bodies maintain their state but don't move or collide.
     */
    public var paused:Bool = false;

    /**
     * Creates the Nape physics system.
     * Initializes the default space with zero gravity.
     */
    public function new() {

        super();

        earlyUpdateOrder = 3000;

        this.space = createSpace();

    }

    /**
     * Creates a new physics space (world).
     * 
     * Each space is an independent physics simulation with its own
     * gravity, bodies, and constraints.
     * 
     * @param autoAdd If true, automatically adds the space to be updated
     * @return New physics space with zero gravity
     */
    public function createSpace(autoAdd:Bool = true):nape.space.Space {

        var space = new nape.space.Space(new nape.geom.Vec2(0, 0));

        if (autoAdd) {
            addSpace(space);
        }

        return space;

    }

    /**
     * Adds a physics space to be updated by the system.
     * 
     * @param space Space to add for automatic stepping
     */
    public function addSpace(space:nape.space.Space):Void {

        if (spaces.indexOf(space) == -1) {
            spaces.push(space);
        }
        else {
            log.warning('Space already added to NapeSystem');
        }

    }

    /**
     * Removes a physics space from automatic updates.
     * 
     * The space itself is not destroyed, just removed from the update list.
     * 
     * @param space Space to stop updating
     */
    public function removeSpace(space:nape.space.Space):Void {

        if (!spaces.remove(space)) {
            log.warning('Space not removed from NapeSystem because it was not added at the first place');
        }

    }

    /**
     * Updates all physics spaces by stepping their simulations.
     * 
     * @param delta Time step in seconds
     */
    inline function updateSpaces(delta:Float):Void {

        if (paused)
            return;

        emitUpdateSpaces(delta);

        for (i in 0...spaces.length) {
            var space = spaces.unsafeGet(i);
            updateSpace(space, delta);
        }

    }

    /**
     * Steps a single physics space forward in time.
     * 
     * @param space Space to update
     * @param delta Time step in seconds
     */
    inline function updateSpace(space:nape.space.Space, delta:Float):Void {

        space.step(delta);

    }

    /**
     * Main update cycle for physics simulation.
     * 
     * Order of operations:
     * 1. Validate all physics items (remove orphaned bodies)
     * 2. Process creation/destruction queues
     * 3. Step physics simulation
     * 4. Synchronize visual positions with physics
     * 
     * @param delta Time elapsed since last update
     */
    override function earlyUpdate(delta:Float):Void {

        if (delta <= 0) return;

        _freezeItems = true;

        for (i in 0...items.length) {
            var item = items.unsafeGet(i);
            if (!item.destroyed) {
                var visual = item.visual;
                if (visual == null) {
                    log.warning('Pre updating nape body with no visual, destroy item!');
                    item.destroy();
                }
                else if (visual.destroyed) {
                    log.warning('Pre updating nape body with destroyed visual, destroy item!');
                    item.destroy();
                }
            }
        }

        _freezeItems = false;

        flushDestroyedItems();
        flushCreatedItems();

        updateSpaces(delta);

        updateVisuals(delta);

    }

    /**
     * Synchronizes visual positions with physics body positions.
     * 
     * Takes into account:
     * - Visual anchor points
     * - Scale transformations
     * - Rotation (if allowed by body)
     * 
     * Physics bodies are positioned at their center, while visuals
     * can have arbitrary anchor points, requiring transformation.
     * 
     * @param delta Time step (unused but passed for consistency)
     */
    inline function updateVisuals(delta:Float):Void {

        emitBeginUpdateVisuals();

        _freezeItems = true;

        for (i in 0...items.length) {
            var item = items.unsafeGet(i);
            if (!item.destroyed) {
                var visual = item.visual;
                if (visual == null) {
                    log.warning('Post updating nape body with no visual, destroy item!');
                    item.destroy();
                }
                else if (visual.destroyed) {
                    log.warning('Post updating nape body with destroyed visual, destroy item!');
                    item.destroy();
                }
                else {
                    var body = item.body;

                    var w = visual.width * visual.scaleX;
                    var h = visual.height * visual.scaleY;
                    var allowRotation = body.allowRotation;

                    // TODO handle nested visuals position?
                    _matrix.identity();
                    _matrix.translate(
                        w * (0.5 - visual.anchorX),
                        h * (0.5 - visual.anchorY)
                    );
                    if (allowRotation) {
                        _matrix.rotate(body.rotation);
                    }

                    visual.pos(
                        body.position.x - _matrix.tx,
                        body.position.y - _matrix.ty
                    );
                    if (allowRotation) {
                        visual.rotation = Utils.radToDeg(body.rotation);
                    }
                }
            }
        }

        _freezeItems = false;

        flushDestroyedItems();
        flushCreatedItems();

        emitEndUpdateVisuals();

    }

    /**
     * Processes the queue of destroyed physics items.
     * Removes them from the active items list.
     */
    inline function flushDestroyedItems():Void {

        while (_destroyedItems.length > 0) {
            var body = _destroyedItems.pop();
            items.remove(cast body);
        }

    }

    /**
     * Processes the queue of newly created physics items.
     * Adds them to the active items list.
     */
    inline function flushCreatedItems():Void {

        while (_createdItems.length > 0) {
            var body = _createdItems.pop();
            items.push(cast body);
        }

    }

}

#end
