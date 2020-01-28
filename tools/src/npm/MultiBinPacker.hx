package npm;

@:jsRequire('multi-bin-packer')
extern class MultiBinPacker<T> {

    function new(maxWidth:Int, maxHeight:Int, ?padding:Int);

    function add(width:Int, height:Int, data:T):Void;

    function addArray(array:Array<{width:Int, height:Int, data:T}>):Void;

    var bins:Array<MultiBinPackerBin<T>>;

}

extern class MultiBinPackerBin<T> {

    var width:Int;

    var height:Int;

    var rects:Array<MultiBinPackerBinRect<T>>;

}

extern class MultiBinPackerBinRect<T> {

    var x:Int;

    var y:Int;

    var width:Int;

    var height:Int;

    var data:T;

}
