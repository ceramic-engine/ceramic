// Ported from vscode src/vs/editor/common/diff/defaultLinesDiffComputer/utils.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.diff.defaultLinesDiffComputer;

import cityscape.base.common.CharCode;
import cityscape.base.common.Strings;
import cityscape.common.core.LineRange;
import cityscape.common.diff.RangeMapping.DetailedLineRangeMapping;

class Array2D<T> {

    final array:Array<T>;
    public final width:Int;
    public final height:Int;

    /**
     * `initialValue` fills the array (Monaco's cells start `undefined` and
     * are always written before they are read).
     */
    public function new(width:Int, height:Int, initialValue:T) {
        this.width = width;
        this.height = height;
        this.array = [for (_ in 0...width * height) initialValue];
    }

    public inline function get(x:Int, y:Int):T {
        return this.array[x + y * this.width];
    }

    public inline function set(x:Int, y:Int, value:T):Void {
        this.array[x + y * this.width] = value;
    }

}

/**
 * Module functions of utils.ts.
 */
class Utils {

    public static inline function isSpace(charCode:Int):Bool {
        return charCode == CharCode.Space || charCode == CharCode.Tab;
    }

    /**
     * The string of the UTF-16 code units `codes[start...end]` (Monaco's
     * `codes.map(e => String.fromCharCode(e)).join('')`): surrogate pairs
     * are joined into their code point.
     */
    public static function fromCharCodes(codes:Array<Int>, start:Int, end:Int):String {
        #if js
        final buf = new StringBuf();
        for (i in start...end) {
            buf.add(js.Syntax.code('String.fromCharCode({0})', codes[i]));
        }
        return buf.toString();
        #else
        final buf = new StringBuf();
        var i = start;
        while (i < end) {
            final c = codes[i];
            if (Strings.isHighSurrogate(c) && i + 1 < end && Strings.isLowSurrogate(codes[i + 1])) {
                buf.addChar(Strings.computeCodePoint(c, codes[i + 1]));
                i += 2;
                continue;
            }
            buf.addChar(c);
            i++;
        }
        return buf.toString();
        #end
    }

    /**
     * JavaScript's `str.trim()` (whitespace and line terminators).
     */
    public static function jsTrim(str:String):String {
        var start = 0;
        var end = str.length;
        while (start < end && Strings.isJsWhitespace(StringTools.fastCodeAt(str, start))) {
            start++;
        }
        while (end > start && Strings.isJsWhitespace(StringTools.fastCodeAt(str, end - 1))) {
            end--;
        }
        return (start == 0 && end == str.length) ? str : str.substring(start, end);
    }

    /**
     * JavaScript's `str.trimStart()`.
     */
    public static function jsTrimStart(str:String):String {
        var start = 0;
        final end = str.length;
        while (start < end && Strings.isJsWhitespace(StringTools.fastCodeAt(str, start))) {
            start++;
        }
        return start == 0 ? str : str.substring(start);
    }

    /**
     * JavaScript's `str.trimEnd()`.
     */
    public static function jsTrimEnd(str:String):String {
        var end = str.length;
        while (end > 0 && Strings.isJsWhitespace(StringTools.fastCodeAt(str, end - 1))) {
            end--;
        }
        return end == str.length ? str : str.substring(0, end);
    }

}

/**
 * The keys given to characters by `LineRangeFragment` (Monaco's static
 * `chrKeys` map and its size).
 */
class CharKeys {

    public final map:Map<Int, Int> = new Map();
    public var size:Int = 0;

    public function new() {}

}

/**
 * The characters of a line range, as a histogram, to compare fragments.
 *
 * Monaco keeps the key of each character in a static map shared by all
 * computations; the keys only need to be consistent between the fragments
 * compared, so each computation gives its own map (`chrKeys`), keyed by
 * UTF-16 code unit like Monaco's `line[j]`.
 */
class LineRangeFragment {

    static function getKey(chrKeys:CharKeys, chr:Int):Int {
        var key = chrKeys.map.get(chr);
        if (key == null) {
            key = chrKeys.size;
            chrKeys.map.set(chr, key);
            chrKeys.size++;
        }
        return key;
    }

    final totalCount:Int;
    final histogram:Array<Int> = [];

    public final range:LineRange;
    public final lines:Array<String>;
    public final source:DetailedLineRangeMapping;

    public function new(range:LineRange, lines:Array<String>, source:DetailedLineRangeMapping, chrKeys:CharKeys) {
        this.range = range;
        this.lines = lines;
        this.source = source;
        var counter = 0;
        for (i in range.startLineNumber - 1...range.endLineNumberExclusive - 1) {
            final line = lines[i];
            for (j in 0...line.length) {
                counter++;
                final chr = StringTools.fastCodeAt(line, j);
                final key = getKey(chrKeys, chr);
                increment(key);
            }
            counter++;
            final key = getKey(chrKeys, '\n'.code);
            increment(key);
        }

        this.totalCount = counter;
    }

    inline function increment(key:Int):Void {
        while (this.histogram.length <= key) {
            this.histogram.push(0);
        }
        this.histogram[key] = this.histogram[key] + 1;
    }

    public function computeSimilarity(other:LineRangeFragment):Float {
        var sumDifferences = 0;
        final maxLength = Std.int(Math.max(this.histogram.length, other.histogram.length));
        for (i in 0...maxLength) {
            final a = i < this.histogram.length ? this.histogram[i] : 0;
            final b = i < other.histogram.length ? other.histogram[i] : 0;
            sumDifferences += Std.int(Math.abs(a - b));
        }
        return 1 - (sumDifferences / (this.totalCount + other.totalCount));
    }

}
