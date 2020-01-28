package backend;

import unityengine.Texture2D;

class ImageImpl {

    public var unityTexture:Texture2D;

    public var path:String;

    public var width(get,never):Int;
    inline function get_width():Int {
        return unityTexture.width;
    }

    public var height(get,never):Int;
    inline function get_height():Int {
        return unityTexture.height;
    }

    public function new(path:String, unityTexture:Texture2D) {

        this.path = path;
        this.unityTexture = unityTexture;

    }

}
