// New code for Cityscape (not a port): JavaScript's `Intl.Collator` with
// the default locale and options, used where Monaco sorts with
// `new Intl.Collator().compare` (sortLinesCommand.ts).
package cityscape.base.common;

/**
 * Compares strings like JavaScript's `new Intl.Collator().compare`.
 *
 * On JavaScript it is the native `Intl.Collator`. Other targets have no
 * `Intl` (see DEVIATIONS.md, "Sorting without Intl"): the comparison follows
 * the three levels of the Unicode collation algorithm with a small table
 * instead of ICU's: first the base characters (whitespace, then punctuation
 * and symbols, then digits, then letters, letters compared without case and
 * accents, Latin-1 and Latin Extended-A letters folded to their base letter),
 * then the accents (a letter without accent first), then the case (lower
 * case first).
 */
class Collator {

    #if js
    final _collator:Dynamic;
    #end

    public function new() {
        #if js
        _collator = js.Syntax.code('new Intl.Collator()');
        #end
    }

    public function compare(a:String, b:String):Int {
        #if js
        return _collator.compare(a, b);
        #else
        return compareWithoutIntl(a, b);
        #end
    }

    /**
     * The base letters of U+00C0 to U+017F (`.` for the two symbols).
     */
    static inline final LATIN_BASE = 'aaaaaaaceeeeiiiidnooooo.ouuuuytsaaaaaaaceeeeiiiidnooooo.ouuuuytyaaaaaaccccccccddddeeeeeeeeeegggggggghhhhiiiiiiiiiiiijjkkkllllllllllnnnnnnnnnoooooooorrrrrrssssssssttttttuuuuuuuuuuuuwwyyyzzzzzzs';

    static inline final RANK_WHITESPACE = 0x1000000;
    static inline final RANK_PUNCTUATION = 0x2000000;
    static inline final RANK_DIGIT = 0x3000000;
    static inline final RANK_LETTER = 0x4000000;

    static function isWhitespace(c:Int):Bool {
        return (c >= 9 && c <= 13) || c == 32 || c == 0xA0 || c == 0x1680 || (c >= 0x2000 && c <= 0x200A) || c == 0x2028 || c == 0x2029 || c == 0x202F || c == 0x205F || c == 0x3000 || c == 0xFEFF;
    }

    static function lowerCode(c:Int):Int {
        if (c >= 'A'.code && c <= 'Z'.code) {
            return c + 32;
        }
        if (c < 128) {
            return c;
        }
        final lower = String.fromCharCode(c).toLowerCase();
        return lower.length == 1 ? StringTools.fastCodeAt(lower, 0) : c;
    }

    static function upperCode(c:Int):Int {
        if (c >= 'a'.code && c <= 'z'.code) {
            return c - 32;
        }
        if (c < 128) {
            return c;
        }
        final upper = String.fromCharCode(c).toUpperCase();
        return upper.length == 1 ? StringTools.fastCodeAt(upper, 0) : c;
    }

    /**
     * The primary weight of a character.
     */
    static function primary(c:Int):Int {
        if (isWhitespace(c)) {
            return RANK_WHITESPACE + c;
        }
        if (c >= '0'.code && c <= '9'.code) {
            return RANK_DIGIT + c;
        }
        if ((c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code)) {
            return RANK_LETTER + lowerCode(c);
        }
        if (c >= 0xC0 && c <= 0x17F) {
            final base = StringTools.fastCodeAt(LATIN_BASE, c - 0xC0);
            if (base != '.'.code) {
                return RANK_LETTER + base;
            }
            return RANK_PUNCTUATION + c;
        }
        if (c < 0xC0) {
            return RANK_PUNCTUATION + c;
        }
        // Other scripts: a letter when it has a case or is above the Latin blocks
        return RANK_LETTER + lowerCode(c);
    }

    /**
     * The secondary weight (accents) of a character: 0 without accent.
     */
    static function secondary(c:Int):Int {
        if (c >= 0xC0 && c <= 0x17F) {
            final base = StringTools.fastCodeAt(LATIN_BASE, c - 0xC0);
            if (base != '.'.code) {
                return lowerCode(c);
            }
        }
        return 0;
    }

    /**
     * The tertiary weight (case) of a character: 1 for an upper case letter.
     */
    static function tertiary(c:Int):Int {
        return (lowerCode(c) != c && upperCode(c) == c) ? 1 : 0;
    }

    static function compareLevel(a:String, b:String, weight:(c:Int) -> Int):Int {
        final lenA = a.length;
        final lenB = b.length;
        var i = 0;
        while (i < lenA && i < lenB) {
            final wa = weight(StringTools.fastCodeAt(a, i));
            final wb = weight(StringTools.fastCodeAt(b, i));
            if (wa != wb) {
                return wa < wb ? -1 : 1;
            }
            i++;
        }
        return lenA == lenB ? 0 : (lenA < lenB ? -1 : 1);
    }

    static function compareWithoutIntl(a:String, b:String):Int {
        var r = compareLevel(a, b, primary);
        if (r != 0) {
            return r;
        }
        r = compareLevel(a, b, secondary);
        if (r != 0) {
            return r;
        }
        return compareLevel(a, b, tertiary);
    }

}
