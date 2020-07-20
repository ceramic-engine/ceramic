package ceramic;

@:allow(ceramic.App)
class Logger extends Entity {

/// Events

    @event function _info(value:Dynamic, ?pos:haxe.PosInfos);

    @event function _debug(value:Dynamic, ?pos:haxe.PosInfos);

    @event function _success(value:Dynamic, ?pos:haxe.PosInfos);

    @event function _warning(value:Dynamic, ?pos:haxe.PosInfos);

    @event function _error(value:Dynamic, ?pos:haxe.PosInfos);

/// Internal

#if (web && luxe)
    private static var _hasElectronRunner:Bool = false;
#end

    var indentPrefix:String = '';

    static var didInitOnce:Bool = false;

    public function new() {

        super();
        
        if (!didInitOnce) {
            didInitOnce = true;
#if unity
            haxe.Log.trace = function(v:Dynamic, ?pos:haxe.PosInfos):Void {
                untyped __cs__('UnityEngine.Debug.Log({0})', v);
            };
#end
        }
    }

/// Public API

    public function debug(value:Dynamic, ?pos:haxe.PosInfos):Void {
        
        emitDebug(value, pos);

        haxe.Log.trace(prefixLines('[debug] ', value), pos);

    }

    public function info(value:Dynamic, ?pos:haxe.PosInfos):Void {
        
        emitInfo(value, pos);

        haxe.Log.trace(prefixLines('[info] ', value), pos);

    }

    public function success(value:Dynamic, ?pos:haxe.PosInfos):Void {
        
        emitSuccess(value, pos);

        haxe.Log.trace(prefixLines('[success] ', value), pos);

    }

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

    }

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

    }

    inline public function pushIndent() {

        indentPrefix += '    ';

    }

    inline public function popIndent() {

        indentPrefix = indentPrefix.substring(0, indentPrefix.length - 4);

    }

/// Internal

    function prefixLines(prefix:String, input:Dynamic):String {

        var result = [];
        for (line in Std.string(input).split("\n")) {
            result.push(prefix + indentPrefix + line);
        }
        return result.join("\n");

    }

} //Log