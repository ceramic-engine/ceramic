package ceramic;

@:structInit
class TextureAtlasPage {

    public var name:String;

    public var width:Float = 0;

    public var height:Float = 0;

    public var filter:TextureFilter = LINEAR;

    public var texture(default, set):Texture = null;

    function set_texture(texture:Texture):Texture {
        if (this.texture != texture) {
            this.texture = texture;
            if (texture != null) {
                if (width <= 0)
                    width = texture.nativeWidth;
                if (height <= 0)
                    height = texture.nativeHeight;
            }
        }
        return texture;
    }

}
