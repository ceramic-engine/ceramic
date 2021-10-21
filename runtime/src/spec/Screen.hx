package spec;

import backend.Texture;
import haxe.io.Bytes;

interface Screen {

    function getWidth():Int;

    function getHeight():Int;

    function getDensity():Float;

    function setBackground(background:Int):Void;

    function setWindowTitle(title:String):Void;

    function setWindowFullscreen(fullscreen:Bool):Void;

    function screenshotToTexture(done:(texture:Texture)->Void):Void;

    function screenshotToPng(?path:String, done:(?data:Bytes)->Void):Void;

    function screenshotToPixels(done:(pixels:ceramic.UInt8Array, width:Int, height:Int)->Void):Void;

}
