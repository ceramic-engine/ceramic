package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;

using StringTools;

class RenderTexture extends Texture {

/// Lifecycle

    public function new(width:Int, height:Int, density:Float = 1) {

        var backendItem = app.backend.textures.createRenderTexture(
            Math.round(width * density),
            Math.round(height * density)
        );

        super(backendItem, density);

    } //new

} //RenderTexture
