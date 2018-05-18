package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;

using StringTools;

class RenderTexture extends Texture {

    public var autoRender:Bool = true;

    public var renderDirty:Bool = false;

/// Lifecycle

    public function new(width:Int, height:Int, density:Float = 1) {

        var backendItem = app.backend.images.createRenderTarget(
            Math.round(width * density),
            Math.round(height * density)
        );

        super(backendItem, density);

        isRenderTexture = true;

        app.renderTextures.push(this);

    } //new

    function destroy() {

        app.renderTextures.remove(this);

    } //destroy

} //RenderTexture
