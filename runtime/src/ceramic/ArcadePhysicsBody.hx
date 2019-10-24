package ceramic;

class ArcadePhysicsBody extends Entity {

    public var visual:Visual = null;

    public function new() {

        super();

        if (ceramic.App.app.arcadePhysics._freezeBodies) {
            ceramic.App.app.arcadePhysics._createdBodies.push(this);
        }
        else {
            ceramic.App.app.arcadePhysics.bodies.push(cast this);
        }

    } //new

    override function destroy() {

        super.destroy();

        if (visual != null) {
            if (visual.arcadeBody == this) {
                visual.arcadeBody = null;
            } 
            visual = null;
        }

        if (ceramic.App.app.arcadePhysics._freezeBodies) {
            ceramic.App.app.arcadePhysics._destroyedBodies.push(this);
        }
        else {
            ceramic.App.app.arcadePhysics.bodies.remove(cast this);
        }

    } //destroy

} //ArcadePhysicsBody
