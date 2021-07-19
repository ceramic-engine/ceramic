package ceramic;

import ceramic.Shortcuts.*;

using ceramic.Extensions;

@:allow(ceramic.App)
class ArcadeSystem extends System {

#if plugin_arcade

    /**
     * When this event is fired, it's the right time to make your bodies collide/overlap
     * @param delta 
     */
    @event function update(delta:Float);

    @:allow(ceramic.VisualArcadePhysics)
    var _destroyedItems:Array<VisualArcadePhysics> = [];
    @:allow(ceramic.VisualArcadePhysics)
    var _createdItems:Array<VisualArcadePhysics> = [];
    @:allow(ceramic.VisualArcadePhysics)
    var _freezeItems:Bool = false;

    public var items(default, null):Array<VisualArcadePhysics> = [];

    /**
     * All worlds used with arcade physics
     */
    public var worlds(default, null):Array<ArcadeWorld> = [];

    /**
     * Default world used for arcade physics
     */
    public var world:ArcadeWorld = null;

    /**
     * Groups by id
     */
    public var groups:Map<String, arcade.Group> = new Map();

    /**
     * If `true`, default world (`world`) bounds will be
     * updated automatically to match screen size.
     */
    public var autoUpdateWorldBounds:Bool = true;

    public function new() {

        super();

        earlyUpdateOrder = 2000;
        lateUpdateOrder = 2000;

        this.world = createWorld();

    }

    public function createWorld(autoAdd:Bool = true):ArcadeWorld {

        var world = new ArcadeWorld(0, 0, screen.width, screen.height);

        if (autoAdd) {
            addWorld(world);
        }

        return world;

    }

    public function addWorld(world:ArcadeWorld):Void {

        if (worlds.indexOf(world) == -1) {
            worlds.push(world);
        }
        else {
            log.warning('World already added to ArcadeSystem');
        }

    }

    public function removeWorld(world:ArcadeWorld):Void {

        if (!worlds.remove(world)) {
            log.warning('World not removed from ArcadeSystem because it was not added at the first place');
        }
        
    }

    inline function updateWorlds(delta:Float):Void {

        for (i in 0...worlds.length) {
            var world = worlds.unsafeGet(i);
            updateWorld(world, delta);
        }

    }

    inline function updateWorld(world:ArcadeWorld, delta:Float):Void {

        world.elapsed = delta;

    }

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

    inline function flushDestroyedItems():Void {

        while (_destroyedItems.length > 0) {
            var item = _destroyedItems.pop();
            items.remove(item);
        }
        
    }

    inline function flushCreatedItems():Void {

        while (_createdItems.length > 0) {
            var item = _createdItems.pop();
            items.push(item);
        }
        
    }

#end

}
