package ceramic;

#if plugin_nape

/**
 * Component that links a Ceramic Visual to a Nape physics body.
 * 
 * This class manages the relationship between the visual representation
 * and the physics simulation. The physics body drives the visual's
 * position and rotation after each physics update.
 * 
 * ```haxe
 * // Create a dynamic physics box
 * var visual = new Quad();
 * visual.size(100, 100);
 * visual.anchor(0.5, 0.5);
 * visual.pos(400, 300);
 * 
 * visual.nape = new VisualNapePhysics(
 *     DYNAMIC,        // Body type
 *     null,           // Default box shape
 *     null,           // No additional shapes
 *     null,           // Default material
 *     visual.x,       // X position
 *     visual.y,       // Y position  
 *     visual.width,   // Width
 *     visual.height,  // Height
 *     visual.rotation // Rotation
 * );
 * 
 * // Add to physics space
 * visual.nape.body.space = app.nape.space;
 * ```
 */
@:dox(show)
class VisualNapePhysics extends Entity {

    /**
     * The visual that this physics component is attached to.
     * Set automatically when assigned to a visual's `nape` property.
     */
    public var visual:Visual = null;

    /**
     * The Nape physics body that controls the visual's transform.
     * Can be added to a Space to enable physics simulation.
     */
    public var body:nape.phys.Body = null;

    /**
     * Creates a new physics body linked to a visual.
     * 
     * If no shape is provided, creates a box shape matching the dimensions.
     * The body is not automatically added to any physics space.
     * 
     * @param bodyType Type of physics body (STATIC, KINEMATIC, or DYNAMIC)
     * @param shape Optional single shape for the body
     * @param shapes Optional array of shapes for compound bodies
     * @param material Physics material defining friction, elasticity, etc.
     * @param x Initial X position (center)
     * @param y Initial Y position (center)
     * @param width Width for default box shape
     * @param height Height for default box shape
     * @param rotation Initial rotation in degrees
     */
    public function new(
        bodyType:NapePhysicsBodyType,
        ?shape:nape.shape.Shape,
        ?shapes:Array<nape.shape.Shape>,
        ?material:nape.phys.Material,
        x:Float, y:Float, width:Float, height:Float, rotation:Float
        ) {

        super();

        // Convert Ceramic body type to Nape body type
        var napeBodyType = switch (bodyType) {
            case DYNAMIC: nape.phys.BodyType.DYNAMIC;
            case KINEMATIC: nape.phys.BodyType.KINEMATIC;
            case STATIC: nape.phys.BodyType.STATIC;
        }

        // Create physics body at specified position
        body = new nape.phys.Body(
            napeBodyType,
            nape.geom.Vec2.weak(x, y)
        );
        
        // Create default box shape if none provided
        if (shape == null && (shapes == null || shapes.length == 0)) {
            shape = new nape.shape.Polygon(
                nape.shape.Polygon.box(width, height)
            );
        }

        // Set initial rotation
        body.rotation = Utils.degToRad(rotation);

        // Add shapes to body
        if (shape != null) {
            body.shapes.add(shape);
        }
        if (shapes != null) {
            for (i in 0...shapes.length) {
                body.shapes.add(shapes[i]);
            }
        }
        
        // Apply material to all shapes
        if (material != null) body.setShapeMaterials(material);

        // Register with physics system
        if (ceramic.App.app.nape._freezeItems) {
            ceramic.App.app.nape._createdItems.push(this);
        }
        else {
            ceramic.App.app.nape.items.push(cast this);
        }

    }

    /**
     * Destroys the physics component and removes the body from simulation.
     * 
     * - Removes body from its physics space
     * - Clears the visual's nape reference
     * - Unregisters from the physics system
     */
    override function destroy() {

        super.destroy();

        // Remove body from physics space
        body.space = null;

        // Clear visual reference
        if (visual != null) {
            if (visual.nape == this) {
                visual.nape = null;
            }
            visual = null;
        }

        // Unregister from physics system
        if (ceramic.App.app.nape._freezeItems) {
            ceramic.App.app.nape._destroyedItems.push(this);
        }
        else {
            ceramic.App.app.nape.items.remove(cast this);
        }

    }

}

#end
