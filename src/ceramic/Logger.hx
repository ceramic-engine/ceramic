package ceramic;

@:allow(ceramic.App)
class Logger {

/// Internal

    function new() {}

/// Public API

    public function log(value:Dynamic, ?pos:haxe.PosInfos):Void {

        haxe.Log.trace('[log] ' + value, pos);

    } //log

    public function success(value:Dynamic, ?pos:haxe.PosInfos):Void {

        haxe.Log.trace('[success] ' + value, pos);

    } //success

    public function warning(value:Dynamic, ?pos:haxe.PosInfos):Void {

        haxe.Log.trace('[warning] ' + value, pos);

    } //warning

    public function error(value:Dynamic, ?pos:haxe.PosInfos):Void {

        haxe.Log.trace('[error] ' + value, pos);

    } //error

} //Log