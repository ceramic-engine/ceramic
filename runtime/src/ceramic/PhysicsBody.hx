package ceramic;

class PhysicsBody extends Entity {

    public var visual:Visual = null;

    public function new() {

        if (ceramic.App.app.physics._freezeBodies) {
            ceramic.App.app.physics._createdBodies.push(this);
        }
        else {
            ceramic.App.app.physics.bodies.push(cast this);
        }

    } //new

    override function destroy() {

        super.destroy();

        if (visual != null) {
            if (visual.body == this) {
                visual.body = null;
            } 
            visual = null;
        }

        if (ceramic.App.app.physics._freezeBodies) {
            ceramic.App.app.physics._destroyedBodies.push(this);
        }
        else {
            ceramic.App.app.physics.bodies.remove(cast this);
        }

    } //destroy

} //PhysicsBody
