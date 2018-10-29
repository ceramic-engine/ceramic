package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;

using StringTools;

/** A texture generated at runtime by stamping visuals on it. */
class DynamicTexture extends RenderTexture {

    static var _clearQuad:Quad = null;

/// Lifecycle

    public function new(width:Int, height:Int, density:Float = -1) {

        super(width, height, density);

        autoRender = false;
        clearOnRender = false;

    } //new

/// Public API

    public function clear(color:Color = 0xFFFFFF, alpha:Float = 0, clipX:Float = -1, clipY:Float = -1, clipWidth:Float = -1, clipHeight:Float = -1) {

        if (_clearQuad == null) {
            _clearQuad = new Quad();
            _clearQuad.active = false;
            _clearQuad.blending = SET;
            _clearQuad.anchor(0, 0);
        }

        _clearQuad.color = color;
        _clearQuad.alpha = alpha;

        if (clipX != -1 && clipY != -1 && clipWidth != -1 && clipHeight != -1) {
            _clearQuad.size(clipWidth, clipHeight);
            _clearQuad.pos(clipX, clipY);
        }
        else {
            _clearQuad.size(width, height);
            _clearQuad.pos(0, 0);
        }

        stamp(_clearQuad);

    } //clear

    /** Draws the given visual onto the render texture */
    public function stamp(visual:Visual) {

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

        // Update & sort visuals
        //app.computeHierarchy();
        app.updateVisuals(flatVisuals);
        app.sortVisuals(flatVisuals);

        // Mark render texture as dirty
        renderDirty = true;

        // Call backend and do actual draw
        app.backend.draw.stamp(flatVisuals);

        // Restore visual state
        visual.visible = visualVisible;
        visual.renderTarget = visualRenderTarget;
        if (visualParent != null) visualParent.add(visual);

    } //stamp

} //DynamicTexture
