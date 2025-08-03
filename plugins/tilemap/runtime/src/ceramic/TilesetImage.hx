package ceramic;

import tracker.Model;

/**
 * Represents the image resource used by a tileset.
 * 
 * TilesetImage encapsulates the texture and metadata for a tileset's graphical data.
 * It manages the texture lifecycle, including asset retention and hot-reloading support.
 * The image dimensions can be specified explicitly or derived from the loaded texture.
 * 
 * ## Features
 * 
 * - **Texture Management**: Handles texture loading and lifecycle
 * - **Asset Retention**: Properly retains/releases texture assets
 * - **Hot-Reload Support**: Automatically updates when texture assets are replaced
 * - **Dimension Tracking**: Stores image dimensions for layout calculations
 * 
 * ## Usage Example
 * 
 * ```haxe
 * var image = new TilesetImage();
 * image.source = "tiles/terrain.png";
 * image.texture = assets.texture("tiles/terrain");
 * 
 * // Dimensions are automatically set from texture if not specified
 * trace('Image size: ${image.width}x${image.height}');
 * 
 * // Attach to a tileset
 * tileset.image = image;
 * ```
 * 
 * @see Tileset
 * @see Texture
 */
class TilesetImage extends Model {

    /**
     * The texture used for this image, if loaded and ready to display
     */
    public var texture(default,set):Texture = null;
    function set_texture(texture:Texture):Texture {
        if (this.texture == texture) return texture;
        var prevTexture = this.texture;
        if (prevTexture != null) {
            if (prevTexture.asset != null) {
                prevTexture.asset.offReplaceTexture(replaceTexture);
                prevTexture.asset.release();
            }
        }
        this.texture = texture;
        if (this.texture != null) {
            if (this.texture.asset != null) {
                this.texture.asset.onReplaceTexture(this, replaceTexture);
                this.texture.asset.retain();
            }
            if (width == -1)
                width = Std.int(this.texture.width);
            if (height == -1)
                height = Std.int(this.texture.height);
        }
        return texture;
    }

    /**
     * The image width in points
     */
    @serialize public var width:Int = -1;

    /**
     * The image height in points
     */
    @serialize public var height:Int = -1;

    /**
     * The reference to the tileset image file, if any
     */
    @serialize public var source:String = null;

    override function destroy() {

        super.destroy();

        // Will update texture asset retain count accordingly
        texture = null;

    }

/// Internal

    /**
     * Internal callback for texture hot-reloading.
     * Called when the texture asset is replaced at runtime.
     * @param newTexture The new texture instance
     * @param prevTexture The previous texture being replaced
     */
    function replaceTexture(newTexture:Texture, prevTexture:Texture) {

        this.texture = newTexture;

    }

}
