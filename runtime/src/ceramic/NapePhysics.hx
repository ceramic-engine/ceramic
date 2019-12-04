package ceramic;

import ceramic.Shortcuts.*;
using ceramic.Extensions;

@:allow(ceramic.App)
class NapePhysics extends Entity {

#if ceramic_nape_physics

    static var _matrix:Transform = new Transform();

    @:allow(ceramic.VisualNapePhysics)
    var _destroyedItems:Array<VisualNapePhysics> = [];
    @:allow(ceramic.VisualNapePhysics)
    var _createdItems:Array<VisualNapePhysics> = [];
    @:allow(ceramic.VisualNapePhysics)
    var _freezeItems:Bool = false;

    /** Triggered right before updating/stepping nape spaces */
    @event function updateSpaces(delta:Float);

    /** Triggered right before applying nape bodies to visuals */
    @event function beginUpdateVisuals();

    /** Triggered right after applying nape bodies to visuals */
    @event function endUpdateVisuals();

    public var items(default, null):Array<ceramic.VisualNapePhysics> = [];

    /** All spaces used with nape physics */
    public var spaces(default, null):Array<nape.space.Space> = [];

    /** Default space for nape physics */
    public var space(default, null):nape.space.Space = null;

    public function new() {

        super();

        this.space = createSpace();

    } //new

    public function createSpace(autoAdd:Bool = true):nape.space.Space {

        var space = new nape.space.Space(new nape.geom.Vec2(0, 0));

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
            log.warning('Space already added to NapePhysics');
        }

    } //addSpace

    public function removeSpace(space:nape.space.Space):Void {

        if (!spaces.remove(space)) {
            log.warning('Space not removed from NapePhysics because it was not added at the first place');
        }
        
    } //removeSpace

    inline function updateSpaces(delta:Float):Void {

        emitUpdateSpaces(delta);

        for (i in 0...spaces.length) {
            var space = spaces.unsafeGet(i);
            updateSpace(space, delta);
        }

    } //updateSpaces

    inline function updateSpace(space:nape.space.Space, delta:Float):Void {

        space.step(delta);

    } //updateSpace

    inline function update(delta:Float):Void {

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

    } //preUpdate

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

    } //updateVisuals

    inline function flushDestroyedItems():Void {

        while (_destroyedItems.length > 0) {
            var body = _destroyedItems.pop();
            items.remove(cast body);
        }
        
    } //flushDestroyedItems

    inline function flushCreatedItems():Void {

        while (_createdItems.length > 0) {
            var body = _createdItems.pop();
            items.push(cast body);
        }
        
    } //flushCreatedItems

#end

} //NapePhysics
