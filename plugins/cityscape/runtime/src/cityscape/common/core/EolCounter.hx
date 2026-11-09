// Ported from vscode src/vs/editor/common/core/eolCounter.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.base.common.CharCode;

enum abstract StringEOL(Int) from Int to Int {
    var Unknown = 0;
    var Invalid = 3;
    var LF = 1;
    var CRLF = 2;
}

/**
 * The result of `countEOL` (Monaco returns a tuple
 * `[eolCount, firstLineLength, lastLineLength, eol]`).
 */
class EolCount {

    public var eolCount:Int;

    public var firstLineLength:Int;

    public var lastLineLength:Int;

    public var eol:StringEOL;

    public function new() {
        this.eolCount = 0;
        this.firstLineLength = 0;
        this.lastLineLength = 0;
        this.eol = StringEOL.Unknown;
    }

}

class EolCounter {

    /**
     * Counts the line breaks of `text`. Pass `result` to reuse an object
     * (no allocation).
     */
    public static function countEOL(text:String, ?result:EolCount):EolCount {
        if (result == null) {
            result = new EolCount();
        }
        var eolCount = 0;
        var firstLineLength = 0;
        var lastLineStart = 0;
        var eol:Int = StringEOL.Unknown;
        var i = 0;
        final len = text.length;
        while (i < len) {
            final chr = StringTools.fastCodeAt(text, i);

            if (chr == CharCode.CarriageReturn) {
                if (eolCount == 0) {
                    firstLineLength = i;
                }
                eolCount++;
                if (i + 1 < len && StringTools.fastCodeAt(text, i + 1) == CharCode.LineFeed) {
                    // \r\n... case
                    eol |= StringEOL.CRLF;
                    i++; // skip \n
                }
                else {
                    // \r... case
                    eol |= StringEOL.Invalid;
                }
                lastLineStart = i + 1;
            }
            else if (chr == CharCode.LineFeed) {
                // \n... case
                eol |= StringEOL.LF;
                if (eolCount == 0) {
                    firstLineLength = i;
                }
                eolCount++;
                lastLineStart = i + 1;
            }
            i++;
        }
        if (eolCount == 0) {
            firstLineLength = text.length;
        }
        result.eolCount = eolCount;
        result.firstLineLength = firstLineLength;
        result.lastLineLength = text.length - lastLineStart;
        result.eol = eol;
        return result;
    }

}
