package ceramic;

import ceramic.Shortcuts.*;

class VisualArcadePhysics extends Entity {

#if ceramic_arcade_physics

    /** Dispatched when this visual body collides with another body. */
    @event function collideBody(visual:Visual, body:arcade.Body);

    /** Dispatched when this visual body overlaps with another body. */
    @event function overlapBody(visual:Visual, body:arcade.Body);

    /** Dispatched when this visual body collides with another visual's body. */
    @event function collide(visual1:Visual, visual2:Visual);

    /** Dispatched when this visual body overlaps with another visual's body. */
    @event function overlap(visual1:Visual, visual2:Visual);

    /** Dispatched when this visual body collides with the world bounds. */
    @event function worldBounds(visual:Visual, up:Bool, down:Bool, left:Bool, right:Bool);

    public var visual:Visual = null;

    public var body(default, null):arcade.Body = null;

    public var world:arcade.World = null;

    public function new(x:Float, y:Float, width:Float, height:Float, rotation:Float) {

        super();

        body = new arcade.Body(x, y, width, height, rotation);
        body.data = this;

        if (ceramic.App.app.arcade._freezeItems) {
            ceramic.App.app.arcade._createdItems.push(this);
        }
        else {
            ceramic.App.app.arcade.items.push(this);
        }

    } //new

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

    } //destroy

    /// Event handling

    inline function willListenCollideBody()
        body.onCollide = handleCollide;

    inline function willListenCollide()
        body.onCollide = handleCollide;

    inline function willListenOverlapBody()
        body.onOverlap = handleOverlap;

    inline function willListenOverlap()
        body.onOverlap = handleOverlap;

    inline function willListenWorldBounds()
        body.onWorldBounds = handleWorldBounds;

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
            warning('Invalid body collide event: failed to retrieve visual from body.');
        }

    } //handleCollide

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
            warning('Invalid body overlap event: failed to retrieve visual from body.');
        }

    } //handleOverlap

    function handleWorldBounds(body1:arcade.Body, up:Bool, down:Bool, left:Bool, right:Bool):Void {

        var arcade1 = fromBody(body1);
        var visual1 = arcade1 != null ? arcade1.visual : null;

        if (visual1 != null) {
            emitWorldBounds(visual1, up, down, left, right);
        }
        else {
            warning('Invalid body worldBounds event: failed to retrieve visual from body.');
        }

    } //handleWorldBounds

    /// Static helpers

    public static function fromBody(body:arcade.Body):VisualArcadePhysics {

        var data = body.data;
        if (Std.is(data, VisualArcadePhysics)) {
            return cast data;
        }
        return null;

    } //fromBody

#end

} //VisualArcadePhysics
