package ceramic;

import ceramic.Shortcuts.*;
using ceramic.Extensions;

@:allow(ceramic.App)
class NapePhysics extends Entity {

#if ceramic_nape_physics

    @:allow(ceramic.NapePhysicsBody)
    var _destroyedBodies:Array<NapePhysicsBody> = [];
    @:allow(ceramic.NapePhysicsBody)
    var _createdBodies:Array<NapePhysicsBody> = [];
    @:allow(ceramic.NapePhysicsBody)
    var _freezeBodies:Bool = false;

    public var bodies:Array<ceramic.NapePhysicsBody> = [];

    public var space:nape.space.Space = null;

    public function new() {

        space = initSpace();

    } //new

    public function initSpace(gravityX:Float, gravityY:Float):Void {

        return new Space(new nape.geom.Vec2(gravityX, gravityY));

    } //initSpace

    inline function updateSpace(delta:Float):Void {

        // TODO

    } //updateSpace

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

} //NapePhysics
