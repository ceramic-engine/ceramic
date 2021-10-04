package ceramic;

#if plugin_nape

@:dox(show)
class VisualNapePhysics extends Entity {

    public var visual:Visual = null;

    public var body:nape.phys.Body = null;

    public function new(
        bodyType:NapePhysicsBodyType,
        ?shape:nape.shape.Shape,
        ?shapes:Array<nape.shape.Shape>,
        ?material:nape.phys.Material,
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
        if (shape == null && (shapes == null || shapes.length == 0)) {
            shape = new nape.shape.Polygon(
                nape.shape.Polygon.box(width, height)
            );
        }

        body.rotation = Utils.degToRad(rotation);

        if (shape != null) {
            body.shapes.add(shape);
        }
        if (shapes != null) {
            for (i in 0...shapes.length) {
                body.shapes.add(shapes[i]);
            }
        }
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

        body.space = null;

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

}

#end
