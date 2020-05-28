package ceramic;

import tracker.Model;

class TilesetImage extends Model {

    /** The texture used for this image, if loaded and ready to display */
    public var texture(default,set):Texture = null;
    function set_texture(texture:Texture):Texture {
        if (this.texture == texture) return texture;
        var prevTexture = this.texture;
        if (prevTexture != null) {
            if (prevTexture.asset != null) {
                prevTexture.asset.offReplaceTexture(replaceTexture);
            }
            if (prevTexture.asset != null) prevTexture.asset.release();
        }
        this.texture = texture;
        if (this.texture != null) {
            if (this.texture.asset != null) {
                this.texture.asset.onReplaceTexture(this, replaceTexture);
            }
            if (this.texture.asset != null) this.texture.asset.retain();
        }
        return texture;
    }

    /** The image width in points */
    @serialize public var width:Int = -1;

    /** The image height in points */
    @serialize public var height:Int = -1;

    /** The reference to the tileset image file, if any */
    @serialize public var source:String = null;

    override function destroy() {

        super.destroy();

        // Will update texture asset retain count accordingly
        texture = null;

    }

/// Internal

    function replaceTexture(newTexture:Texture, prevTexture:Texture) {

        this.texture = newTexture;

    }

}
