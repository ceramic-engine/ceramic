package npm;

@:jsRequire('stream-splitter')
extern class StreamSplitter {

    inline static function splitter(delimiter:String):StreamSplitter {
        return js.Node.require('stream-splitter')(delimiter);
    }

    var encoding:String;

    function on(event:String, callback:Dynamic):Void;

} //StreamSplitter