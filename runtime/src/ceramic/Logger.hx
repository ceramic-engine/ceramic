package ceramic;

@:allow(ceramic.App)
class Logger extends Entity {

/// Events

    @event function _log(value:Dynamic, ?pos:haxe.PosInfos);

    @event function _debug(value:Dynamic, ?pos:haxe.PosInfos);

    @event function _success(value:Dynamic, ?pos:haxe.PosInfos);

    @event function _warning(value:Dynamic, ?pos:haxe.PosInfos);

    @event function _error(value:Dynamic, ?pos:haxe.PosInfos);

/// Internal

#if (web && luxe)
    private static var _hasElectronRunner:Bool = false;
#end

    function new() {

        super();
        
#if unity
        haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos):Void {
            untyped __cs__('UnityEngine.Debug.Log({0})', v);
        };
#end
    }

/// Public API

    public function log(value:Dynamic, ?pos:haxe.PosInfos):Void {
        
        emitLog(value, pos);

        haxe.Log.trace(prefixLines('[log] ', value), pos);

    } //log

    public function success(value:Dynamic, ?pos:haxe.PosInfos):Void {
        
        emitSuccess(value, pos);

        haxe.Log.trace(prefixLines('[success] ', value), pos);

    } //success

    public function warning(value:Dynamic, ?pos:haxe.PosInfos):Void {
        
        emitWarning(value, pos);

#if (web && luxe)
        if (_hasElectronRunner) {
            haxe.Log.trace(prefixLines('[warning] ', value), pos);
        } else {
            untyped console.warn(value);
        }
#elseif web
        untyped console.warn(value);
#else
        haxe.Log.trace(prefixLines('[warning] ', value), pos);
#end

    } //warning

    public function error(value:Dynamic, ?pos:haxe.PosInfos):Void {
        
        emitError(value, pos);

#if (web && luxe)
        if (_hasElectronRunner) {
            haxe.Log.trace(prefixLines('[error] ', value), pos);
        } else {
            untyped console.error(value);
        }
#elseif web
        untyped console.error(value);
#else
        haxe.Log.trace(prefixLines('[error] ', value), pos);
#end

    } //error

/// Internal

    function prefixLines(prefix:String, input:Dynamic):String {

        var result = [];
        for (line in Std.string(input).split("\n")) {
            result.push(prefix + line);
        }
        return result.join("\n");

    } //prefixLines

} //Log