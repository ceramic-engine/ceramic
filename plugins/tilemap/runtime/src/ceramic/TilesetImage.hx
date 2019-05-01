package ceramic;

class TilesetImage extends Entity {

    /** The texture used for this image, if loaded and ready to display */
    public var texture(default,set):Texture = null;
    function set_texture(texture:Texture):Texture {
        if (this.texture == texture) return texture;
        var prevTexture = this.texture;
        if (prevTexture != null) {
            if (prevTexture.asset != null) {
                prevTexture.asset.offReplaceTexture(replaceTexture);
            }
        }
        this.texture = texture;
        if (this.texture != null) {
            if (this.texture.asset != null) {
                this.texture.asset.onReplaceTexture(this, replaceTexture);
            }
        }
        return texture;
    }

    /** The image width in points */
    public var width:Int = -1;

    /** The image height in points */
    public var height:Int = -1;

    /** The reference to the tileset image file, if any */
    public var source:String = null;

    public function new() {

    } //new

/// Internal

    function replaceTexture(newTexture:Texture, prevTexture:Texture) {

        this.texture = newTexture;

    } //replaceTexture

} //TilesetImage
