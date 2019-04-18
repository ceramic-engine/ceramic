package ceramic;

import ceramic.RenderTexture;
import ceramic.Quad;
import ceramic.Visual;

/** A visuals that displays its children through a filter. A filter draws its children into a `RenderTexture`
    allowing to process the result through a shader, apply blending or alpha on the final result... */
class Filter extends Quad {

/// Public properties

    /** If `enabled` is set to `false`, no render texture will be used.
        The children will be displayed on screen directly.
        Useful to toggle a filter without touching visuals hierarchy. */
    public var enabled(default,set):Bool = true;
    function set_enabled(enabled:Bool):Bool {
        if (this.enabled == enabled) return enabled;
        this.enabled = enabled;
        contentDirty = true;
        return enabled;
    }

/// Internal

    var renderTexture:RenderTexture = null;

    function filterSize(filterWidth:Int, filterHeight:Int):Void {

        if (enabled) {
            if (renderTexture == null || renderTexture.width != filterWidth || renderTexture.height != filterHeight) {
                if (renderTexture != null) {
                    texture = null;
                    renderTexture.destroy();
                    renderTexture = null;
                }
                if (filterWidth > 0 && filterHeight > 0) {
                    renderTexture = new RenderTexture(filterWidth, filterHeight);
                    texture = renderTexture;
                }
            }
        }
        else {
            if (renderTexture != null) {
                texture = null;
                renderTexture.destroy();
                renderTexture = null;
            }
        }

        if (children != null) {
            for (i in 0...children.length) {
                var child = children.unsafeGet(i);
                child.renderTarget = renderTexture;
            }
        }

    } //filterSize

/// Overrides

    override function set_width(width:Float):Float {
        if (this.width == width) return width;
        contentDirty = true;
        return super.set_width(width);
    }

    override function set_height(height:Float):Float {
        if (this.height == height) return height;
        contentDirty = true;
        return super.set_height(height);
    }

    override function computeContent() {
        filterSize(Math.ceil(width), Math.ceil(height));
    }

    override function add(visual:Visual):Void {
        super.add(visual);
        visual.renderTarget = renderTexture;
    }

    override function remove(visual:Visual):Void {
        super.remove(visual);
        visual.renderTarget = null;
    }

    override function destroy() {
        texture = null;
        if (renderTexture != null) {
            renderTexture.destroy();
            renderTexture = null;
        }
    }

} //Filter
