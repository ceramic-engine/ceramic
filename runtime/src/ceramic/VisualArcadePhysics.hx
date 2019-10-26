package ceramic;

class VisualArcadePhysics extends Entity {

#if ceramic_arcade_physics

    public var visual:Visual = null;

    public var body:arcade.Body = null;

    public var world:arcade.World = null;

    public function new(x:Float, y:Float, width:Float, height:Float, rotation:Float) {

        super();

        body = new arcade.Body(x, y, width, height, rotation);

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

#end

} //VisualArcadePhysics
