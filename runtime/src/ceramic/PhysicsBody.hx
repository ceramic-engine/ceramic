package ceramic;

class PhysicsBody extends Entity {

    public var visual:Visual = null;

    public function new() {

        if (ceramic.App.app._freezePhysicsBodies) {
            ceramic.App.app._createPhysicsBodies.push(this);
        }
        else {
            ceramic.App.app.physicsBodies.push(cast this);
        }

    } //new

    override function destroy() {

        if (visual != null) {
            if (visual.body == this) {
                visual.body = null;
            } 
            visual = null;
        }

        if (ceramic.App.app._freezePhysicsBodies) {
            ceramic.App.app._destroyedPhysicsBodies.push(this);
        }
        else {
            ceramic.App.app.physicsBodies.remove(cast this);
        }

    } //destroy

} //PhysicsBody
