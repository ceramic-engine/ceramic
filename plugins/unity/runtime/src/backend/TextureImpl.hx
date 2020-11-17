package backend;

import unityengine.Texture2D;

class TextureImpl {

    static var _nextIndex:Int = 1;

    @:noCompletion
    public var index:Int = _nextIndex++;

    public var unityTexture:Texture2D;

    public var unityRenderTexture:Dynamic;

    public var path:String;

    public var textureId:TextureId;

    public var width(default,null):Int;

    public var height(default,null):Int;

    public function new(path:String, unityTexture:Texture2D, unityRenderTexture:Dynamic) {

        this.path = path;
        this.unityTexture = unityTexture;
        this.unityRenderTexture = unityRenderTexture;

        if (unityTexture != null) {
            this.width = unityTexture.width;
            this.height = unityTexture.height;
            this.textureId = unityTexture.GetInstanceID();
        }
        else if (unityRenderTexture != null) {
            this.width = untyped __cs__('(int)((UnityEngine.RenderTexture){0}).width', unityRenderTexture);
            this.height = untyped __cs__('(int)((UnityEngine.RenderTexture){0}).height', unityRenderTexture);
            this.textureId = untyped __cs__('(int)((UnityEngine.RenderTexture){0}).GetInstanceID()', unityRenderTexture);
        }

    }

}
