package npm;

import js.node.Buffer;

typedef SharpMetadata = {

    var format:String;

    var width:Float;

    var height:Float;

    var space:String;

    var channels:Int;

    var density:Float;

    var hasProfile:Bool;

    var hasAlpha:Bool;

    var orientation:Float;

    var exif:Buffer;

    var icc:Buffer;

}

@:jsRequire('sharp')
extern class Sharp {

    inline static function sharp(?input:Dynamic, ?options:Dynamic):Sharp {
        return options != null
        ? js.Node.require('sharp')(input, options)
        : js.Node.require('sharp')(input);
    }

    function resize(width:Float, ?height:Float, ?options:Dynamic):Sharp;

    function extend(options:Dynamic):Sharp;

    function extract(options:Dynamic):Sharp;

    function toFile(output:String, callback:Dynamic->Dynamic->Void):Sharp;

    function raw():Sharp;

    function png():Sharp;

    function toBuffer(callback:Dynamic->Dynamic->Dynamic->Void):Sharp;

    function metadata(callback:Dynamic->SharpMetadata->Void):Sharp;

}
