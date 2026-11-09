// New code for Cityscape (not a port): the regular expression engines given to the TextMate registry.
package cityscape.textmate;

import textmate.OnigLib;

/**
 * Chooses the Oniguruma engine of the TextMate tokenizer: vscode-oniguruma's
 * onig.wasm on the web when the build loaded it (Glaze's `glaze_onig_wasm`
 * define and `glaze.kit.highlighter.OnigWasm`, like the kit's highlighter),
 * else the pure Haxe `oniguruma` library (every target).
 */
class OnigLibs {

    /**
     * The engine to use now: onig.wasm when it is loaded, else the pure Haxe one.
     */
    public static function create():IOnigLib {
        #if (js && glaze_onig_wasm)
        final module = glaze.kit.highlighter.OnigWasm.onigModule;
        if (module != null) {
            return new textmate.onig.WasmOnigLib(module);
        }
        #end
        return new PureOnigLib();
    }

    /**
     * True when `create()` returns the onig.wasm engine.
     */
    public static function isWasm():Bool {
        #if (js && glaze_onig_wasm)
        return glaze.kit.highlighter.OnigWasm.onigModule != null;
        #else
        return false;
        #end
    }

}

/**
 * The `IOnigLib` of the pure Haxe `oniguruma` library (port of Oniguruma
 * 6.9.8 with the vscode-oniguruma API).
 */
class PureOnigLib implements IOnigLib {

    public function new() {}

    public function createOnigScanner(sources:Array<String>):OnigScanner {
        return new PureOnigScanner(new oniguruma.OnigScanner(sources));
    }

    public function createOnigString(str:String):OnigString {
        return new PureOnigString(new oniguruma.OnigString(str));
    }

}

private class PureOnigScanner implements OnigScanner {

    final scanner:oniguruma.OnigScanner;

    public function new(scanner:oniguruma.OnigScanner) {
        this.scanner = scanner;
    }

    public function findNextMatchSync(string:OnigString, startPosition:Int, options:Int):Null<IOnigMatch> {
        final s = (cast string : PureOnigString).onigString;
        final opts:Array<oniguruma.FindOption> = options == 0 ? null : findOptions(options);
        #if js
        // Same fields on plain JavaScript objects
        return cast scanner.findNextMatchSync(s, startPosition, opts);
        #else
        // The captures read from the scanner, without its OnigMatch
        final index = scanner.findNextMatchIndex(s, startPosition, opts);
        if (index < 0) {
            return null;
        }
        final count = scanner.captureCount;
        final captures = new Array<IOnigCaptureIndex>();
        captures.resize(count);
        for (i in 0...count) {
            final start = scanner.captureStart(i);
            final end = scanner.captureEnd(i);
            captures[i] = new IOnigCaptureIndex(start, end, end - start);
        }
        return new IOnigMatch(index, captures);
        #end
    }

    static function findOptions(options:Int):Array<oniguruma.FindOption> {
        final opts:Array<oniguruma.FindOption> = [];
        if (options & FindOption.NotBeginString != 0)
            opts.push(oniguruma.FindOption.NotBeginString);
        if (options & FindOption.NotEndString != 0)
            opts.push(oniguruma.FindOption.NotEndString);
        if (options & FindOption.NotBeginPosition != 0)
            opts.push(oniguruma.FindOption.NotBeginPosition);
        if (options & FindOption.DebugCall != 0)
            opts.push(oniguruma.FindOption.DebugCall);
        return opts;
    }

    public function dispose():Void {
        scanner.dispose();
    }

}

private class PureOnigString implements OnigString {

    public final onigString:oniguruma.OnigString;

    public var content(get, never):String;

    inline function get_content():String {
        return onigString.content;
    }

    public function new(onigString:oniguruma.OnigString) {
        this.onigString = onigString;
    }

    public function dispose():Void {
        onigString.dispose();
    }

}
