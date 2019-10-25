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

    public var bodies(default, null):Array<ceramic.NapePhysicsBody> = [];

    public var spaces(default, null):Array<nape.space.Space> = [];

    public function new() {

        super();

    } //new

    public function createSpace(gravityX:Float, gravityY:Float, autoAdd:Bool = true):nape.space.Space {

        var space = new nape.space.Space(new nape.geom.Vec2(gravityX, gravityY));

        if (autoAdd) {
            addSpace(space);
        }

        return space;

    } //createSpace

    public function addSpace(space:nape.space.Space):Void {

        if (spaces.indexOf(space) == -1) {
            spaces.push(space);
        }
        else {
            warning('Space already added to NapePhysics');
        }

    } //createSpace

    public function removeSpace(space:nape.space.Space):Void {

        if (!spaces.remove(space)) {
            warning('Space not removed from NapePhysics because it was not added at the first place');
        }
        
    } //removeSpace

    inline function updateSpaces(delta:Float):Void {

        for (i in 0...spaces.length) {
            var space = spaces.unsafeGet(i);
            updateSpace(space, delta);
        }

    } //updateSpaces

    inline function updateSpace(space:nape.space.Space, delta:Float):Void {

        space.step(delta);

    } //updateSpace

    inline function preUpdate(delta:Float):Void {

        if (delta <= 0) return;

        _freezeBodies = true;

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
            }
        }

        _freezeBodies = false;

        flushDestroyedBodies();
        flushCreatedBodies();

        updateSpaces(delta);

    } //preUpdate

    inline function postUpdate(delta:Float):Void {

        _freezeBodies = true;

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
                    visual.pos(
                        body.position.x - visual.width * visual.anchorX,
                        body.position.y - visual.height * visual.anchorY
                    );
                    if (body.allowRotation) {
                        body.rotation = radToDeg(body.rotation);
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

    inline static function radToDeg(rad:Float):Float {
        return rad * 57.29577951308232;
    }

#end

} //NapePhysics
