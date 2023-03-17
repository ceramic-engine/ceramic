package ceramic;

import haxe.io.Bytes;

@:structInit
class AsepriteFrame {
    public var aseFrame(default, null):ase.Frame;
    public var index(default, null):Int;
    public var duration(default, null):Float;
    public var tags(default, null):Array<String> = [];
    public var pixels:UInt8Array = null;
    public var hash:Bytes = null;
    public var hashIndex:Int = -1;
    public var duplicateOfIndex:Int = -1;
    public var duplicateSameOffset:Bool = false;
    public var offsetX:Int = 0;
    public var offsetY:Int = 0;
    public var packedWidth:Int = 0;
    public var packedHeight:Int = 0;

}
