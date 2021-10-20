package unityengine;

@:native('UnityEngine.ScreenCapture')
extern class ScreenCapture {

    static function CaptureScreenshot(filename:String, superSize:Int):Void;

    static function CaptureScreenshotAsTexture(superSize:Int):Texture2D;

    static function CaptureScreenshotIntoRenderTexture(renderTexture:RenderTexture):Void;

}
