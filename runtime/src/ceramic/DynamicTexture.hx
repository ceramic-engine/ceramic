package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;

using StringTools;

/** A texture generated at runtime by stamping visuals on it. */
class DynamicTexture extends RenderTexture {

/// Lifecycle

    public function new(width:Int, height:Int, density:Float = -1) {

        super(width, height, density);

        autoRender = false;
        clearOnRender = true;

    } //new

/// Public API

    /** Draws the given visual onto the render texture */
    public function stamp(visual:Visual, clipX:Float = -1, clipY:Float = -1, clipWidth:Float = -1, clipHeight:Float = -1) {

        // Keep original values as needed
        var visualParent = visual.parent;
        var visualRenderTarget = visual.renderTarget;
        var visualVisible = visual.visible;

        // Set new values
        if (visualParent != null) visualParent.remove(visual);
        visual.renderTarget = this;
        visual.visible = true;

        // Create flat array of visuals to draw
        var flatVisuals:Array<Visual> = [visual];
        function addChildren(visual:Visual, visuals:Array<Visual>) {
            if (visual.children != null) {
                for (child in visual.children) {
                    visuals.push(child);
                    addChildren(child, visuals);
                }
            }
        }
        addChildren(visual, flatVisuals);

        // Update visuals
        app.updateVisuals(flatVisuals);

        // Call backend and do actual draw
        app.backend.draw.stamp(flatVisuals, clipX, clipY, clipWidth, clipHeight);

        // Restore visual state
        visual.visible = visualVisible;
        visual.renderTarget = visualRenderTarget;
        if (visualParent != null) visualParent.add(visual);

    } //stamp

} //DynamicTexture
