package unityengine;

import haxe.io.BytesData;

@:native('UnityEngine.ImageConversionModule.ImageConversion')
extern class ImageConversion {

    static function EncodeToPNG(tex:Texture2D):BytesData;

    static function EncodeToJPG(tex:Texture2D, quality:Int):BytesData;

}
