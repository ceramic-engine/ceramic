package ceramic;

import ceramic.Shortcuts.*;

/**
 * A component that displays the visible bounds of a visual entity.
 * 
 * VisibleBounds is a debugging utility that overlays a visual representation
 * of an entity's bounding box. This is useful for:
 * - Debugging layout and positioning issues
 * - Visualizing collision boundaries
 * - Understanding the actual size of transformed visuals
 * - Checking alignment and spacing
 * 
 * The component automatically updates the bounds visual to match the
 * entity's current dimensions, making it ideal for dynamic content.
 * 
 * @example
 * ```haxe
 * // Add a red border to show bounds
 * var border = new Quad();
 * border.color = Color.RED;
 * border.borderWidth = 2;
 * border.transparent = true;
 * 
 * var boundsComponent = new VisibleBounds(border);
 * myVisual.component('bounds', boundsComponent);
 * 
 * // Remove bounds display
 * myVisual.removeComponent('bounds');
 * ```
 * 
 * @see Visual The visual entities this component can be attached to
 * @see Component The component interface this class implements
 */
class VisibleBounds extends Entity implements Component {

    /**
     * The visual entity this component is attached to.
     * Set automatically when the component is bound.
     */
    var entity:Visual;

    /**
     * The visual used to display the bounds.
     * This visual is added as a child to the entity and
     * resized to match the entity's dimensions.
     */
    var bounds:Visual = null;

    /// Lifecycle

    /**
     * Creates a new VisibleBounds component.
     * 
     * @param bounds The visual to use for displaying bounds.
     *               Common choices:
     *               - Quad with borderWidth for outlines
     *               - Quad with alpha < 1 for semi-transparent overlay
     *               - Mesh for custom bounds visualization
     * 
     * @example
     * ```haxe
     * // Create bounds with dashed line (using a texture)
     * var dashedQuad = new Quad();
     * dashedQuad.texture = dashedLineTexture;
     * var bounds = new VisibleBounds(dashedQuad);
     * ```
     */
    public function new(bounds:Visual) {

        super();

        this.bounds = bounds;

    }

    /**
     * Called when this component is attached to an entity.
     * 
     * Sets up the bounds visual as a child of the entity and
     * starts listening for update events to sync the bounds size.
     * The bounds are immediately updated to match the entity.
     */
    function bindAsComponent():Void {

        entity.add(bounds);
        app.onUpdate(this, updateBounds);
        updateBounds(0);

    }

    /**
     * Updates the bounds visual to match the entity's dimensions.
     * 
     * Called every frame to ensure the bounds accurately reflect
     * the entity's current size. The bounds visual is positioned
     * at (0,0) relative to the entity and sized to match exactly.
     * 
     * @param delta Time elapsed since last frame (unused but required by update callback)
     */
    function updateBounds(delta:Float) {

        bounds.pos(0, 0);
        bounds.size(entity.width, entity.height);

    }

}
