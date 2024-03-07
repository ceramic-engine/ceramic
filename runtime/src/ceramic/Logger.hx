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

#if web
    private static var _hasElectronRunner:Bool = false;
#end

    var indentPrefix:String = '';

    static var didInitOnce:Bool = false;

    public function new() {

        super();

        if (!didInitOnce) {
            didInitOnce = true;
#if ceramic_mute_logs
            haxe.Log.trace = function(v:Dynamic, ?pos:haxe.PosInfos):Void {
                // Logs disabled
            };
#else
#if unity
            haxe.Log.trace = function(v:Dynamic, ?pos:haxe.PosInfos):Void {
                #if !ceramic_unity_no_log
                untyped __cs__('UnityEngine.Debug.Log({0}+{1}+{2}+":"+{3})', v, '\n', pos.fileName, pos.lineNumber);
                #end
            };
#end
#end
        }
    }

/// Public API

#if (!completion && ceramic_no_log)
    inline public function debug(value:Dynamic, ?pos:haxe.PosInfos):Void {}
    inline public function info(value:Dynamic, ?pos:haxe.PosInfos):Void {}
    inline public function success(value:Dynamic, ?pos:haxe.PosInfos):Void {}
    inline public function warning(value:Dynamic, ?pos:haxe.PosInfos):Void {}
    inline public function error(value:Dynamic, ?pos:haxe.PosInfos):Void {}
#else
    public function debug(value:Dynamic, ?pos:haxe.PosInfos):Void {

        if (!Runner.currentIsMainThread()) {
            if (listensDebug()) {
                Runner.runInMain(function() {
                    emitDebug(value, pos);
                });
            }
        }
        else {
            emitDebug(value, pos);
        }

#if !ceramic_mute_logs
#if unity
#if !ceramic_unity_no_log
        untyped __cs__('UnityEngine.Debug.Log("<color=magenta>"+{0}+"</color>"+{1}+{2}+":"+{3})', value, '\n', pos.fileName, pos.lineNumber);
#end
#else
        haxe.Log.trace(prefixLines('[debug] ', value), pos);
#end
#end

    }

    public function info(value:Dynamic, ?pos:haxe.PosInfos):Void {

        if (!Runner.currentIsMainThread()) {
            if (listensInfo()) {
                Runner.runInMain(function() {
                    emitInfo(value, pos);
                });
            }
        }
        else {
            emitInfo(value, pos);
        }

#if !ceramic_mute_logs
#if unity
#if !ceramic_unity_no_log
        untyped __cs__('UnityEngine.Debug.Log("<color=cyan>"+{0}+"</color>"+{1}+{2}+":"+{3})', value, '\n', pos.fileName, pos.lineNumber);
#end
#else
        haxe.Log.trace(prefixLines('[info] ', value), pos);
#end
#end

    }

    public function success(value:Dynamic, ?pos:haxe.PosInfos):Void {

        if (!Runner.currentIsMainThread()) {
            if (listensSuccess()) {
                Runner.runInMain(function() {
                    emitSuccess(value, pos);
                });
            }
        }
        else {
            emitSuccess(value, pos);
        }

#if !ceramic_mute_logs
#if unity
#if !ceramic_unity_no_log
        untyped __cs__('UnityEngine.Debug.Log("<color=lime>"+{0}+"</color>"+{1}+{2}+":"+{3})', value, '\n', pos.fileName, pos.lineNumber);
#end
#else
        haxe.Log.trace(prefixLines('[success] ', value), pos);
#end
#end

    }

    public function warning(value:Dynamic, ?pos:haxe.PosInfos):Void {

        if (!Runner.currentIsMainThread()) {
            if (listensWarning()) {
                Runner.runInMain(function() {
                    emitWarning(value, pos);
                });
            }
        }
        else {
            emitWarning(value, pos);
        }

#if !ceramic_mute_logs
#if unity
#if !ceramic_unity_no_log
        untyped __cs__('UnityEngine.Debug.LogWarning("<color=yellow>"+{0}+"</color>"+{1}+{2}+":"+{3})', value, '\n', pos.fileName, pos.lineNumber);
#end
#elseif web
        if (_hasElectronRunner) {
            haxe.Log.trace(prefixLines('[warning] ', value), pos);
        } else {
            untyped console.warn(value);
        }
#else
        haxe.Log.trace(prefixLines('[warning] ', value), pos);
#end
#end

    }

    public function error(value:Dynamic, ?pos:haxe.PosInfos):Void {

        if (!Runner.currentIsMainThread()) {
            if (listensError()) {
                Runner.runInMain(function() {
                    emitError(value, pos);
                });
            }
        }
        else {
            emitError(value, pos);
        }

#if !ceramic_mute_logs
#if unity
#if !ceramic_unity_no_log
        untyped __cs__('UnityEngine.Debug.LogError("<color=red>"+{0}+"</color>"+{1}+{2}+":"+{3})', value, '\n', pos.fileName, pos.lineNumber);
#end
#elseif web
        if (_hasElectronRunner) {
            haxe.Log.trace(prefixLines('[error] ', value), pos);
        } else {
            untyped console.error(value);
        }
#else
        haxe.Log.trace(prefixLines('[error] ', value), pos);
#end
#end

    }
#end

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

}