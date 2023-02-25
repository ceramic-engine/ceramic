package unityengine;

import haxe.io.BytesData;

@:native('UnityEngine.ImageConversion')
extern class ImageConversion {

    static function EncodeToPNG(tex:Texture2D):BytesData;

    static function EncodeToJPG(tex:Texture2D, quality:Int):BytesData;

    static function LoadImage(tex:Texture2D, data:BytesData, markNonReadable:Bool):Bool;

}
