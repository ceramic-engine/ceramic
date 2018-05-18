package spec;

import backend.UInt8Array;
import backend.Image;
import backend.LoadImageOptions;

interface Images {

    function load(path:String, ?options:LoadImageOptions, done:Image->Void):Void;

/// Images

    function createImage(width:Int, height:Int):Image;
    
    function destroyImage(image:Image):Void;

    function getImageWidth(image:Image):Int;

    function getImageHeight(image:Image):Int;

    function getImagePixels(image:Image):UInt8Array;

    function setTextureFilter(texture:Image, filter:ceramic.TextureFilter):Void;

    function createRenderTarget(width:Int, height:Int):Image;

} //Image
