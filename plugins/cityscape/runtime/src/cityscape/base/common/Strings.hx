// Ported from vscode src/vs/base/common/strings.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * Module functions of strings.ts. Only what the ported code needs so far;
 * add functions here as modules need them, keeping Monaco's names.
 *
 * Strings are Haxe `String`s indexed in UTF-16 code units, like JavaScript.
 * The regular expressions of strings.ts that only test character ranges are
 * written as loops over the code units, which give the same answers on every
 * target.
 */
class Strings {

    /**
     * Whether `charCode` is a UTF-16 high (leading) surrogate.
     */
    public static inline function isHighSurrogate(charCode:Int):Bool {
        return (0xD800 <= charCode && charCode <= 0xDBFF);
    }

    /**
     * Whether `charCode` is a UTF-16 low (trailing) surrogate.
     */
    public static inline function isLowSurrogate(charCode:Int):Bool {
        return (0xDC00 <= charCode && charCode <= 0xDFFF);
    }

    /**
     * The code point of a surrogate pair.
     */
    public static inline function computeCodePoint(highSurrogate:Int, lowSurrogate:Int):Int {
        return ((highSurrogate - 0xD800) << 10) + (lowSurrogate - 0xDC00) + 0x10000;
    }

    /**
     * Returns true if `str` contains only basic ASCII characters in the range
     * 32 - 126 (including 32 and 126) or \n, \r, \t
     * (`/^[\t\n\r\x20-\x7E]*$/`).
     */
    public static function isBasicASCII(str:String):Bool {
        for (i in 0...str.length) {
            final c = StringTools.fastCodeAt(str, i);
            if (!(c == CharCode.Tab || c == CharCode.LineFeed || c == CharCode.CarriageReturn || (c >= 0x20 && c <= 0x7E))) {
                return false;
            }
        }
        return true;
    }

    /**
     * Returns true if `str` contains any Unicode character that is classified
     * as "R" or "AL" (the code unit ranges of Monaco's generated `CONTAINS_RTL`
     * regular expression).
     */
    public static function containsRTL(str:String):Bool {
        final len = str.length;
        var i = 0;
        while (i < len) {
            final c = StringTools.fastCodeAt(str, i);
            if (isRTLBmp(c)) {
                return true;
            }
            if (i + 1 < len && (c == 0xD802 || c == 0xD803 || c == 0xD83A || c == 0xD83B)) {
                final d = StringTools.fastCodeAt(str, i + 1);
                if (isRTLAstral(c, d)) {
                    return true;
                }
            }
            i++;
        }
        return false;
    }

    static function isRTLBmp(c:Int):Bool {
        if (c < 0x05BE)
            return false;
        return c == 0x05BE || c == 0x05C0 || c == 0x05C3 || c == 0x05C6 || (c >= 0x05D0 && c <= 0x05F4) || c == 0x0608
            || c == 0x060B || c == 0x060D || (c >= 0x061B && c <= 0x064A) || (c >= 0x066D && c <= 0x066F) || (c >= 0x0671 && c <= 0x06D5)
            || c == 0x06E5 || c == 0x06E6 || c == 0x06EE || c == 0x06EF || (c >= 0x06FA && c <= 0x0710) || (c >= 0x0712 && c <= 0x072F)
            || (c >= 0x074D && c <= 0x07A5) || (c >= 0x07B1 && c <= 0x07EA) || c == 0x07F4 || c == 0x07F5 || (c >= 0x07FA && c <= 0x0815)
            || c == 0x081A || c == 0x0824 || c == 0x0828 || (c >= 0x0830 && c <= 0x0858) || (c >= 0x085E && c <= 0x088E)
            || (c >= 0x08A0 && c <= 0x08C9) || c == 0x200F || c == 0xFB1D || (c >= 0xFB1F && c <= 0xFB28) || (c >= 0xFB2A && c <= 0xFD3D)
            || (c >= 0xFD50 && c <= 0xFDC7) || (c >= 0xFDF0 && c <= 0xFDFC) || (c >= 0xFE70 && c <= 0xFEFC);
    }

    static function isRTLAstral(high:Int, d:Int):Bool {
        return switch high {
            case 0xD802:
                (d >= 0xDC00 && d <= 0xDD1B) || (d >= 0xDD20 && d <= 0xDE00) || (d >= 0xDE10 && d <= 0xDE35) || (d >= 0xDE40 && d <= 0xDEE4)
                    || (d >= 0xDEEB && d <= 0xDF35) || (d >= 0xDF40 && d <= 0xDFFF);
            case 0xD803:
                (d >= 0xDC00 && d <= 0xDD23) || (d >= 0xDE80 && d <= 0xDEA9) || (d >= 0xDEAD && d <= 0xDF45) || (d >= 0xDF51 && d <= 0xDF81)
                    || (d >= 0xDF86 && d <= 0xDFF6);
            case 0xD83A:
                (d >= 0xDC00 && d <= 0xDCCF) || (d >= 0xDD00 && d <= 0xDD43) || (d >= 0xDD4B && d <= 0xDFFF);
            case 0xD83B:
                (d >= 0xDC00 && d <= 0xDEBB);
            case _:
                false;
        }
    }

    /**
     * Returns true if `str` contains unusual line terminators, like LS or PS
     * (`/[  ]/`).
     */
    public static function containsUnusualLineTerminators(str:String):Bool {
        for (i in 0...str.length) {
            final c = StringTools.fastCodeAt(str, i);
            if (c == 0x2028 || c == 0x2029) {
                return true;
            }
        }
        return false;
    }

}
