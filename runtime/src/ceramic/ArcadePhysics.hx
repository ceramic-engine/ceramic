package ceramic;

import ceramic.Shortcuts.*;
using ceramic.Extensions;

@:allow(ceramic.App)
class ArcadePhysics extends Entity {

#if ceramic_arcade_physics

    @:allow(ceramic.VisualArcadePhysics)
    var _destroyedItems:Array<VisualArcadePhysics> = [];
    @:allow(ceramic.VisualArcadePhysics)
    var _createdItems:Array<VisualArcadePhysics> = [];
    @:allow(ceramic.VisualArcadePhysics)
    var _freezeItems:Bool = false;

    public var items(default, null):Array<VisualArcadePhysics> = [];

    /** All worlds used with arcade physics */
    public var worlds(default, null):Array<arcade.World> = [];

    /** Default world used for arcade physics */
    public var world:arcade.World = null;

    /** If `true`, default world (`world`) bounds will be
        updated automatically to match screen size. */
    public var autoUpdateWorldBounds:Bool = true;

    public function new() {

        super();

        this.world = createWorld();

    } //new


    public function createWorld(autoAdd:Bool = true):arcade.World {

        var world = new arcade.World(0, 0, screen.width, screen.height);

        if (autoAdd) {
            addWorld(world);
        }

        return world;

    } //createWorld

    public function addWorld(world:arcade.World):Void {

        if (worlds.indexOf(world) == -1) {
            worlds.push(world);
        }
        else {
            log.warning('World already added to ArcadePhysics');
        }

    } //addWorld

    public function removeWorld(world:arcade.World):Void {

        if (!worlds.remove(world)) {
            log.warning('World not removed from ArcadePhysics because it was not added at the first place');
        }
        
    } //removeWorld

    inline function updateWorlds(delta:Float):Void {

        for (i in 0...worlds.length) {
            var world = worlds.unsafeGet(i);
            updateWorld(world, delta);
        }

    } //updateWorlds

    inline function updateWorld(world:arcade.World, delta:Float):Void {

        world.elapsed = delta;

    } //updateWorld

    inline function preUpdate(delta:Float):Void {

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
                    var w = visual.width * visual.scaleX;
                    var h = visual.height * visual.scaleY;
                    item.body.preUpdate(
                        item.world,
                        visual.x - w * visual.anchorX,
                        visual.y - h * visual.anchorY,
                        w,
                        h,
                        visual.rotation
                    );
                }
            }
        }

        _freezeItems = false;

        flushDestroyedItems();
        flushCreatedItems();

    } //preUpdate

    inline function postUpdate(delta:Float):Void {

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
                    body.postUpdate(world);
                    visual.x += body.dx;
                    visual.y += body.dy;
                    if (body.allowRotation) {
                        visual.rotation += body.deltaZ();
                    }
                }
            }
        }

        _freezeItems = false;

        flushDestroyedItems();
        flushCreatedItems();

    } //postUpdate

    inline function flushDestroyedItems():Void {

        while (_destroyedItems.length > 0) {
            var item = _destroyedItems.pop();
            items.remove(item);
        }
        
    } //flushDestroyedItems

    inline function flushCreatedItems():Void {

        while (_createdItems.length > 0) {
            var item = _createdItems.pop();
            items.push(item);
        }
        
    } //flushCreatedItems

#end

} //ArcadePhysics
