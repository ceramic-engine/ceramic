// Original code (not a port), written for Glaze.
// MIT License, see Ceramic's LICENSE file.
package glaze.kit.highlighter;

import textmate.OnigLib;

/**
 * The `IOnigLib` of the pure Haxe `oniguruma` library (the port of
 * Oniguruma 6.9.8 with the vscode-oniguruma API), for the `textmate`
 * registry. It is the regex engine of the highlighter on every target,
 * unless the web build opts in to onig.wasm (`glaze_onig_wasm` define, see `OnigWasm`).
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
        final m = if (options == 0) {
            scanner.findNextMatchSync(s, startPosition);
        }
        else {
            final opts:Array<oniguruma.FindOption> = [];
            if (options & FindOption.NotBeginString != 0)
                opts.push(oniguruma.FindOption.NotBeginString);
            if (options & FindOption.NotEndString != 0)
                opts.push(oniguruma.FindOption.NotEndString);
            if (options & FindOption.NotBeginPosition != 0)
                opts.push(oniguruma.FindOption.NotBeginPosition);
            if (options & FindOption.DebugCall != 0)
                opts.push(oniguruma.FindOption.DebugCall);
            scanner.findNextMatchSync(s, startPosition, opts);
        }
        if (m == null) {
            return null;
        }
        #if js
        // Same fields on plain JavaScript objects
        return cast m;
        #else
        final src = m.captureIndices;
        final captures = new Array<IOnigCaptureIndex>();
        captures.resize(src.length);
        for (i in 0...src.length) {
            final c = src[i];
            captures[i] = new IOnigCaptureIndex(c.start, c.end, c.length);
        }
        return new IOnigMatch(m.index, captures);
        #end
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
