package ceramic;

typedef AsepriteJson = {

    var frames:Array<AsepriteJsonFrame>;

    var meta:AsepriteJsonMeta;

}

enum abstract AsepriteJsonFrameTagDirection(String) {

    var FORWARD = "forward";

    var REVERSE = "reverse";

    var PINGPONG = "pingpong";

}

typedef AsepriteJsonMeta = {

    var app:String;

    var version:String;

    var image:String;

    var format:String;

    var size:AsepriteJsonSize;

    var scale:String;

    var frameTags:Array<AsepriteJsonFrameTag>;

    var layers:Array<AsepriteJsonLayer>;

    var slices:Array<AsepriteJsonSlice>;

}

typedef AsepriteJsonFrameTag = {

    var name:String;

    var from:Int;

    var to:Int;

    var direction:AsepriteJsonFrameTagDirection;

}

typedef AsepriteJsonLayer = {

    var name:String;

    var opacity:Int;

    var blendMode:String;

}

typedef AsepriteJsonSlice = {

}

typedef AsepriteJsonFrame = {

    var filename:String;

    var frame:AsepriteJsonRect;

    var rotated:Bool;

    var trimmed:Bool;

    var spriteSourceSize:AsepriteJsonRect;

    var sourceSize:AsepriteJsonSize;

    var duration:Float;

}

typedef AsepriteJsonRect = {

    var x:Float;

    var y:Float;

    var w:Float;

    var h:Float;

}

typedef AsepriteJsonSize = {

    var w:Float;

    var h:Float;

}
