package ceramic;

import ceramic.Shortcuts.*;
using ceramic.Extensions;

@:allow(ceramic.App)
class ArcadePhysics extends Entity {

#if ceramic_arcade_physics

    @:allow(ceramic.ArcadePhysicsBody)
    var _destroyedBodies:Array<ArcadePhysicsBody> = [];
    @:allow(ceramic.ArcadePhysicsBody)
    var _createdBodies:Array<ArcadePhysicsBody> = [];
    @:allow(ceramic.ArcadePhysicsBody)
    var _freezeBodies:Bool = false;

    public var bodies(default, null):Array<arcade.Body> = [];

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
                if (visual == null) {
                    warning('Pre updating arcade body with no visual, destroy body!');
                    body.destroy();
                }
                else if (visual.destroyed) {
                    warning('Pre updating arcade body with destroyed visual, destroy body!');
                    body.destroy();
                }
                else {
                    var w = visual.width * visual.scaleX;
                    var h = visual.height * visual.scaleY;
                    body.preUpdate(
                        world,
                        visual.x - w * visual.anchorX,
                        visual.y - h * visual.anchorY,
                        w,
                        h,
                        visual.rotation
                    );
                }
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
                var visual = body.visual;
                if (visual == null) {
                    warning('Post updating arcade body with no visual, destroy body!');
                    body.destroy();
                }
                else if (visual.destroyed) {
                    warning('Post updating arcade body with destroyed visual, destroy body!');
                    body.destroy();
                }
                else {
                    body.postUpdate(world);
                    visual.x += body.dx;
                    visual.y += body.dy;
                    if (body.allowRotation) {
                        visual.rotation += visual.deltaZ();
                    }
                }
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
