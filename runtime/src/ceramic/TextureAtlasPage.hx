package ceramic;

import tracker.Observable;

class TextureAtlasPage implements Observable {

    @observe public var name:String;

    @observe public var width:Float = 0;

    @observe public var height:Float = 0;

    @observe public var filter(default, set):TextureFilter = LINEAR;
    function set_filter(filter:TextureFilter):TextureFilter {
        if (this.filter != filter) {
            this.filter = filter;
            if (texture != null) {
                texture.filter = filter;
            }
        }
        return filter;
    }

    @observe public var texture(default, set):Texture = null;

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

    public function new(name:String, width:Float = 0, height:Float = 0, filter:TextureFilter = LINEAR, texture:Texture = null) {

        this.name = name;
        this.width = width;
        this.height = height;
        this.filter = filter;
        this.texture = texture;

    }

}
