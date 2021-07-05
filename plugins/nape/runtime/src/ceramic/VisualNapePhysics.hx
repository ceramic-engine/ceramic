package ceramic;

class VisualNapePhysics extends Entity {

#if plugin_nape

    public var visual:Visual = null;

    public var body:nape.phys.Body = null;

    public function new(
        bodyType:NapePhysicsBodyType, ?shape:nape.shape.Polygon, ?material:nape.phys.Material,
        x:Float, y:Float, width:Float, height:Float, rotation:Float
        ) {

        super();

        var napeBodyType = switch (bodyType) {
            case DYNAMIC: nape.phys.BodyType.DYNAMIC;
            case KINEMATIC: nape.phys.BodyType.KINEMATIC;
            case STATIC: nape.phys.BodyType.STATIC;
        }

        body = new nape.phys.Body(
            napeBodyType,
            nape.geom.Vec2.weak(x, y)
        );
        if (shape == null) {
            shape = new nape.shape.Polygon(
                nape.shape.Polygon.box(width, height)
            );
        }

        body.rotation = Utils.degToRad(rotation);

        body.shapes.add(shape);
        if (material != null) body.setShapeMaterials(material);

        if (ceramic.App.app.nape._freezeItems) {
            ceramic.App.app.nape._createdItems.push(this);
        }
        else {
            ceramic.App.app.nape.items.push(cast this);
        }

    }

    override function destroy() {

        super.destroy();

        if (visual != null) {
            if (visual.nape == this) {
                visual.nape = null;
            } 
            visual = null;
        }

        if (ceramic.App.app.nape._freezeItems) {
            ceramic.App.app.nape._destroyedItems.push(this);
        }
        else {
            ceramic.App.app.nape.items.remove(cast this);
        }

    }

#end

}
