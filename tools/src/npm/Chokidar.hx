package npm;

@:jsRequire("chokidar")
extern class Chokidar {

    static function watch(paths:Dynamic, options:Dynamic):ChokidarWatcher;

} //Chokidar

extern class ChokidarWatcher {

    function on(event:String, callback:Dynamic):ChokidarWatcher;

    function add(paths:Dynamic):Void;

    function unwatch(paths:Dynamic):Void;

    function close():Void;

    function getWatched():Dynamic;

} //ChokidarWatcher
