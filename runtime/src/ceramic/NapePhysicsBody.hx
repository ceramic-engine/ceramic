package ceramic;

class VisualNapePhysics extends Entity {

    public var visual:Visual = null;

    public var body:nape.phys.Body = null;

    public function new() {

        super();

        if (ceramic.App.app.nape._freezeBodies) {
            ceramic.App.app.nape._createdBodies.push(this);
        }
        else {
            ceramic.App.app.nape.bodies.push(cast this);
        }

    } //new

    public function destroy() {

        super.destroy();

        if (visual != null) {
            if (visual.nape == this) {
                visual.nape = null;
            } 
            visual = null;
        }

        if (ceramic.App.app.nape._freezeBodies) {
            ceramic.App.app.nape._destroyedBodies.push(this);
        }
        else {
            ceramic.App.app.nape.bodies.remove(cast this);
        }

    } //destroy

} //NapePhysicsBody
