package ceramic;

import ceramic.Shortcuts.*;

class VisualArcadePhysics extends Entity {

#if plugin_arcade

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

    public var world:ArcadeWorld = null;

    public var offsetX:Float = 0;

    public var offsetY:Float = 0;

    public function new() {

        super();

        if (ceramic.App.app.arcade._freezeItems) {
            ceramic.App.app.arcade._createdItems.push(this);
        }
        else {
            ceramic.App.app.arcade.items.push(this);
        }

    }

    public function initBody(x:Float, y:Float, width:Float, height:Float, rotation:Float) {

        body = new arcade.Body(x, y, width, height, rotation);
        body.data = this;

    }

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

    }

    /// Event handling

    inline function willListenCollideBody()
        if (body != null) body.onCollide = handleCollide;

    inline function willListenCollide()
        if (body != null) body.onCollide = handleCollide;

    inline function willListenOverlapBody()
        if (body != null) body.onOverlap = handleOverlap;

    inline function willListenOverlap()
        if (body != null) body.onOverlap = handleOverlap;

    inline function willListenWorldBounds()
        if (body != null) body.onWorldBounds = handleWorldBounds;

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
            log.warning('Invalid body collide event: failed to retrieve visual from body.');
        }

    }

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
            log.warning('Invalid body overlap event: failed to retrieve visual from body.');
        }

    }

    function handleWorldBounds(body1:arcade.Body, up:Bool, down:Bool, left:Bool, right:Bool):Void {

        var arcade1 = fromBody(body1);
        var visual1 = arcade1 != null ? arcade1.visual : null;

        if (visual1 != null) {
            emitWorldBounds(visual1, up, down, left, right);
        }
        else {
            log.warning('Invalid body worldBounds event: failed to retrieve visual from body.');
        }

    }

/// Static helpers

    public static function fromBody(body:arcade.Body):VisualArcadePhysics {

        var data = body.data;
        if (Std.isOfType(data, VisualArcadePhysics)) {
            return cast data;
        }
        return null;

    }

#end

}
