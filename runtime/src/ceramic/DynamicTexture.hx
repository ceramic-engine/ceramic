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

        // Update visuals
        app.updateVisuals(app.visuals);

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

        // Call backend
        app.backend.draw.stamp(flatVisuals, this, clear, clipX, clipY, clipWidth, clipHeight);

    } //stamp

} //DynamicTexture
