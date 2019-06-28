package ceramic;

import ceramic.Shortcuts.*;
using ceramic.Extensions;

@:allow(ceramic.App)
class ArcadePhysics extends Entity {

#if ceramic_arcade_physics

    @:allow(ceramic.PhysicsBody)
    var _destroyedBodies:Array<PhysicsBody> = [];
    @:allow(ceramic.PhysicsBody)
    var _createdBodies:Array<PhysicsBody> = [];
    @:allow(ceramic.PhysicsBody)
    var _freezeBodies:Bool = false;

    public var bodies:Array<arcade.Body> = [];

    public var world:arcade.World = null;

    public var autoUpdateWorldBounds:Bool = true;

    public function new() {

        initWorld();

    } //new

    inline function initWorld():Void {

        world = new arcade.World(0, 0, screen.width, screen.height);

    } //initWorld

    inline function updateWorld(delta:Float):Void {

        if (autoUpdateWorldBounds) {
            world.setBounds(0, 0, screen.width, screen.height);
        }

        world.elapsed = delta;

    } //updateWorld

    inline function preUpdate(delta:Float):Void {

        if (delta <= 0) return;

        updateWorld(delta);

        _freezeBodies = true;

        // Run preUpdate()
        for (i in 0...bodies.length) {
            var body:arcade.Body = bodies.unsafeGet(i);
            if (!body.destroyed) {
                var visual = body.visual;
                var w = visual.width * visual.scaleX;
                var h = visual.height * visual.scaleY;
                @:privateAccess body.preUpdate(
                    world,
                    visual.x - w * visual.anchorX,
                    visual.y - h * visual.anchorY,
                    w,
                    h,
                    visual.rotation
                );
            }
        }

        _freezeBodies = false;

        flushDestroyedBodies();
        flushCreatedBodies();

    } //preUpdate

    inline function postUpdate(delta:Float):Void {

        _freezeBodies = true;

        // Run postUpdate()
        for (i in 0...bodies.length) {
            var body:arcade.Body = bodies.unsafeGet(i);
            if (!body.destroyed) {
                @:privateAccess body.postUpdate(world);
            }
        }

        _freezeBodies = false;

        flushDestroyedBodies();
        flushCreatedBodies();

    } //postUpdate

    inline function flushDestroyedBodies():Void {

        while (_destroyedBodies.length > 0) {
            var body = _destroyedBodies.pop();
            bodies.remove(cast body);
        }
        
    } //flushDestroyedBodies

    inline function flushCreatedBodies():Void {

        while (_createdBodies.length > 0) {
            var body = _createdBodies.pop();
            bodies.push(cast body);
        }
        
    } //flushCreatedBodies

#end

} //ArcadePhysics
