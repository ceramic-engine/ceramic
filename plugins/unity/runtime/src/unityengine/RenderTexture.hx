package unityengine;

@:native('UnityEngine.RenderTexture')
extern class RenderTexture extends Texture {

    static var active:RenderTexture;

    var width:Int;

    var height:Int;

    var filterMode:FilterMode;

}
