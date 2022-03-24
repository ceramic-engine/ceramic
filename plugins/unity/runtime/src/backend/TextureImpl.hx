package backend;

import unityengine.RenderTexture;
import unityengine.Texture2D;

class TextureImpl {

    static var _nextIndex:Int = 1;

    @:noCompletion
    public var index:Int = _nextIndex++;

    @:noCompletion
    public var usedAsRenderTarget:Bool = false;

    public var unityTexture:Texture2D;

    public var unityRenderTexture:RenderTexture;

    public var path:String;

    public var textureId:TextureId;

    public var width(default,null):Int;

    public var height(default,null):Int;

    public function new(path:String, unityTexture:Texture2D, unityRenderTexture:RenderTexture) {

        this.path = path;
        this.unityTexture = unityTexture;
        this.unityRenderTexture = unityRenderTexture;

        if (unityTexture != null) {
            this.width = unityTexture.width;
            this.height = unityTexture.height;
            this.textureId = unityTexture.GetInstanceID();
        }
        else if (unityRenderTexture != null) {
            this.width = unityRenderTexture.width;
            this.height = unityRenderTexture.height;
            this.textureId = unityRenderTexture.GetInstanceID();
        }

    }

}
