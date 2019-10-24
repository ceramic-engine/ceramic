package ceramic;

class NapePhysicsBody extends Entity {

    public var visual:Visual = null;

    public function new() {

        super();

        if (ceramic.App.app.napePhysics._freezeBodies) {
            ceramic.App.app.napePhysics._createdBodies.push(this);
        }
        else {
            ceramic.App.app.napePhysics.bodies.push(cast this);
        }

    } //new

    override function destroy() {

        super.destroy();

        if (visual != null) {
            if (visual.napeBody == this) {
                visual.napeBody = null;
            } 
            visual = null;
        }

        if (ceramic.App.app.napePhysics._freezeBodies) {
            ceramic.App.app.napePhysics._destroyedBodies.push(this);
        }
        else {
            ceramic.App.app.napePhysics.bodies.remove(cast this);
        }

    } //destroy

} //NapePhysicsBody
