// Ported from vscode src/vs/editor/common/languages/supports/richEditBrackets.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages.supports;

import cityscape.base.common.RegExp;
import cityscape.base.common.Strings;
import cityscape.common.core.Range;
import cityscape.common.languages.LanguageConfiguration.CharacterPair;

private typedef InternalBracket = {
    final open:Array<String>;
    final close:Array<String>;
}

/**
 * Represents a grouping of colliding bracket pairs.
 *
 * Most of the times this contains a single bracket pair,
 * but sometimes this contains multiple bracket pairs in cases
 * where the same string appears as a closing bracket for multiple
 * bracket pairs, or the same string appears an opening bracket for
 * multiple bracket pairs.
 *
 * e.g. of a group containing a single pair:
 *   open: ['{'], close: ['}']
 *
 * e.g. of a group containing multiple pairs:
 *   open: ['if', 'for'], close: ['end', 'end']
 */
class RichEditBracket {

    public final languageId:String;
    /**
     * A 0-based consecutive unique identifier for this bracket pair.
     * If a language has 5 bracket pairs, out of which 2 are grouped together,
     * it is expected that the `index` goes from 0 to 4.
     */
    public final index:Int;
    /**
     * The open sequence for each bracket pair contained in this group.
     *
     * The open sequence at a specific index corresponds to the
     * closing sequence at the same index.
     *
     * [ open[i], closed[i] ] represent a bracket pair.
     */
    public final open:Array<String>;
    /**
     * The close sequence for each bracket pair contained in this group.
     *
     * The close sequence at a specific index corresponds to the
     * opening sequence at the same index.
     *
     * [ open[i], closed[i] ] represent a bracket pair.
     */
    public final close:Array<String>;
    /**
     * A regular expression that is useful to search for this bracket pair group in a string.
     *
     * This regular expression is built in a way that it is aware of the other bracket
     * pairs defined for the language, so it might match brackets from other groups.
     *
     * See the fine details in `getRegexForBracketPair`.
     */
    public final forwardRegex:RegExp;
    /**
     * A regular expression that is useful to search for this bracket pair group in a string backwards.
     *
     * This regular expression is built in a way that it is aware of the other bracket
     * pairs defined for the language, so it might match brackets from other groups.
     *
     * See the fine defails in `getReversedRegexForBracketPair`.
     */
    public final reversedRegex:RegExp;
    final _openSet:Map<String, Bool>;
    final _closeSet:Map<String, Bool>;

    public function new(languageId:String, index:Int, open:Array<String>, close:Array<String>, forwardRegex:RegExp, reversedRegex:RegExp) {
        this.languageId = languageId;
        this.index = index;
        this.open = open;
        this.close = close;
        this.forwardRegex = forwardRegex;
        this.reversedRegex = reversedRegex;
        _openSet = RichEditBracket._toSet(this.open);
        _closeSet = RichEditBracket._toSet(this.close);
    }

    /**
     * Check if the provided `text` is an open bracket in this group.
     */
    public function isOpen(text:String):Bool {
        return _openSet.exists(text);
    }

    /**
     * Check if the provided `text` is a close bracket in this group.
     */
    public function isClose(text:String):Bool {
        return _closeSet.exists(text);
    }

    static function _toSet(arr:Array<String>):Map<String, Bool> {
        final result = new Map<String, Bool>();
        for (element in arr) {
            result.set(element, true);
        }
        return result;
    }

}

class RichEditBrackets {

    /**
     * All groups of brackets defined for this language.
     */
    public final brackets:Array<RichEditBracket>;
    /**
     * A regular expression that is useful to search for all bracket pairs in a string.
     *
     * See the fine details in `getRegexForBrackets`.
     */
    public final forwardRegex:RegExp;
    /**
     * A regular expression that is useful to search for all bracket pairs in a string backwards.
     *
     * See the fine details in `getReversedRegexForBrackets`.
     */
    public final reversedRegex:RegExp;
    /**
     * The length (i.e. str.length) for the longest bracket pair.
     */
    public final maxBracketLength:Int;
    /**
     * A map useful for decoding a regex match and finding which bracket group was matched.
     */
    public final textIsBracket:Map<String, RichEditBracket>;
    /**
     * A set useful for decoding if a regex match is the open bracket of a bracket pair.
     */
    public final textIsOpenBracket:Map<String, Bool>;

    public function new(languageId:String, _brackets:Array<CharacterPair>) {
        final brackets = groupFuzzyBrackets(_brackets);

        this.brackets = [for (index in 0...brackets.length) {
            final b = brackets[index];
            new RichEditBracket(
                languageId,
                index,
                b.open,
                b.close,
                getRegexForBracketPair(b.open, b.close, brackets, index),
                getReversedRegexForBracketPair(b.open, b.close, brackets, index)
            );
        }];

        forwardRegex = getRegexForBrackets(this.brackets);
        reversedRegex = getReversedRegexForBrackets(this.brackets);

        textIsBracket = new Map();
        textIsOpenBracket = new Map();

        var maxBracketLength = 0;
        for (bracket in this.brackets) {
            for (open in bracket.open) {
                textIsBracket.set(open, bracket);
                textIsOpenBracket.set(open, true);
                maxBracketLength = Std.int(Math.max(maxBracketLength, open.length));
            }
            for (close in bracket.close) {
                textIsBracket.set(close, bracket);
                textIsOpenBracket.set(close, false);
                maxBracketLength = Std.int(Math.max(maxBracketLength, close.length));
            }
        }
        this.maxBracketLength = maxBracketLength;
    }

    /**
     * Groups together brackets that have equal open or close sequences.
     *
     * For example, if the following brackets are defined:
     *   ['IF','END']
     *   ['for','end']
     *   ['{','}']
     *
     * Then the grouped brackets would be:
     *   { open: ['if', 'for'], close: ['end', 'end'] }
     *   { open: ['{'], close: ['}'] }
     */
    static function groupFuzzyBrackets(brackets:Array<CharacterPair>):Array<InternalBracket> {
        final N = brackets.length;

        brackets = [for (b in brackets) [b[0].toLowerCase(), b[1].toLowerCase()]];

        final group:Array<Int> = [];
        for (i in 0...N) {
            group[i] = i;
        }

        final areOverlapping = (a:CharacterPair, b:CharacterPair) -> {
            final aOpen = a[0];
            final aClose = a[1];
            final bOpen = b[0];
            final bClose = b[1];
            return (aOpen == bOpen || aOpen == bClose || aClose == bOpen || aClose == bClose);
        };

        final mergeGroups = (g1:Int, g2:Int) -> {
            final newG = g1 < g2 ? g1 : g2;
            final oldG = g1 < g2 ? g2 : g1;
            for (i in 0...N) {
                if (group[i] == oldG) {
                    group[i] = newG;
                }
            }
        };

        // group together brackets that have the same open or the same close sequence
        for (i in 0...N) {
            final a = brackets[i];
            for (j in i + 1...N) {
                final b = brackets[j];
                if (areOverlapping(a, b)) {
                    mergeGroups(group[i], group[j]);
                }
            }
        }

        final result:Array<InternalBracket> = [];
        for (g in 0...N) {
            final currentOpen:Array<String> = [];
            final currentClose:Array<String> = [];
            for (i in 0...N) {
                if (group[i] == g) {
                    currentOpen.push(brackets[i][0]);
                    currentClose.push(brackets[i][1]);
                }
            }
            if (currentOpen.length > 0) {
                result.push({
                    open: currentOpen,
                    close: currentClose
                });
            }
        }
        return result;
    }

    static function collectSuperstrings(str:String, brackets:Array<InternalBracket>, currentIndex:Int, dest:Array<String>):Void {
        for (i in 0...brackets.length) {
            if (i == currentIndex) {
                continue;
            }
            final bracket = brackets[i];
            for (open in bracket.open) {
                if (open.indexOf(str) >= 0) {
                    dest.push(open);
                }
            }
            for (close in bracket.close) {
                if (close.indexOf(str) >= 0) {
                    dest.push(close);
                }
            }
        }
    }

    static function lengthcmp(a:String, b:String):Int {
        return a.length - b.length;
    }

    static function unique(arr:Array<String>):Array<String> {
        if (arr.length <= 1) {
            return arr;
        }
        final result:Array<String> = [];
        final seen = new Map<String, Bool>();
        for (element in arr) {
            if (seen.exists(element)) {
                continue;
            }
            result.push(element);
            seen.set(element, true);
        }
        return result;
    }

    /**
     * Create a regular expression that can be used to search forward in a piece of text
     * for a group of bracket pairs. But this regex must be built in a way in which
     * it is aware of the other bracket pairs defined for the language.
     *
     * For example, if a language contains the following bracket pairs:
     *   ['begin', 'end']
     *   ['if', 'end if']
     * The two bracket pairs do not collide because no open or close brackets are equal.
     * So the function getRegexForBracketPair is called twice, once with
     * the ['begin'], ['end'] group consisting of one bracket pair, and once with
     * the ['if'], ['end if'] group consiting of the other bracket pair.
     *
     * But there could be a situation where an occurrence of 'end if' is mistaken
     * for an occurrence of 'end'.
     *
     * Therefore, for the bracket pair ['begin', 'end'], the regex will also
     * target 'end if'. The regex will be something like:
     *   /(\bend if\b)|(\bend\b)|(\bif\b)/
     *
     * The regex also searches for "superstrings" (other brackets that might be mistaken with the current bracket).
     */
    static function getRegexForBracketPair(open:Array<String>, close:Array<String>, brackets:Array<InternalBracket>, currentIndex:Int):RegExp {
        return createBracketOrRegExp(getBracketPairPieces(open, close, brackets, currentIndex));
    }

    /**
     * The pieces of `getRegexForBracketPair` and `getReversedRegexForBracketPair`.
     */
    static function getBracketPairPieces(open:Array<String>, close:Array<String>, brackets:Array<InternalBracket>, currentIndex:Int):Array<String> {
        // search in all brackets for other brackets that are a superstring of these brackets
        var pieces:Array<String> = [];
        pieces = pieces.concat(open);
        pieces = pieces.concat(close);
        final len = pieces.length;
        for (i in 0...len) {
            collectSuperstrings(pieces[i], brackets, currentIndex, pieces);
        }
        pieces = unique(pieces);
        haxe.ds.ArraySort.sort(pieces, lengthcmp);
        pieces.reverse();
        return pieces;
    }

    /**
     * Matching a regular expression in JS can only be done "forwards". So JS offers natively only
     * methods to find the first match of a regex in a string. But sometimes, it is useful to
     * find the last match of a regex in a string. For such a situation, a nice solution is to
     * simply reverse the string and then search for a reversed regex.
     *
     * This function also has the fine details of `getRegexForBracketPair`. For the same example
     * given above, the regex produced here would look like:
     *   /(\bfi dne\b)|(\bdne\b)|(\bfi\b)/
     */
    static function getReversedRegexForBracketPair(open:Array<String>, close:Array<String>, brackets:Array<InternalBracket>, currentIndex:Int):RegExp {
        final pieces = getBracketPairPieces(open, close, brackets, currentIndex);
        return createBracketOrRegExp([for (p in pieces) BracketsUtils.toReversedString(p)]);
    }

    /**
     * Creates a regular expression that targets all bracket pairs.
     *
     * e.g. for the bracket pairs:
     *  ['{','}']
     *  ['begin,'end']
     *  ['for','end']
     * the regex would look like:
     *  /(\{)|(\})|(\bbegin\b)|(\bend\b)|(\bfor\b)/
     */
    static function getRegexForBrackets(brackets:Array<RichEditBracket>):RegExp {
        return createBracketOrRegExp(getBracketsPieces(brackets));
    }

    static function getBracketsPieces(brackets:Array<RichEditBracket>):Array<String> {
        final pieces:Array<String> = [];
        for (bracket in brackets) {
            for (open in bracket.open) {
                pieces.push(open);
            }
            for (close in bracket.close) {
                pieces.push(close);
            }
        }
        return unique(pieces);
    }

    /**
     * Matching a regular expression in JS can only be done "forwards". So JS offers natively only
     * methods to find the first match of a regex in a string. But sometimes, it is useful to
     * find the last match of a regex in a string. For such a situation, a nice solution is to
     * simply reverse the string and then search for a reversed regex.
     *
     * e.g. for the bracket pairs:
     *  ['{','}']
     *  ['begin,'end']
     *  ['for','end']
     * the regex would look like:
     *  /(\{)|(\})|(\bnigeb\b)|(\bdne\b)|(\brof\b)/
     */
    static function getReversedRegexForBrackets(brackets:Array<RichEditBracket>):RegExp {
        final pieces = getBracketsPieces(brackets);
        return createBracketOrRegExp([for (p in pieces) BracketsUtils.toReversedString(p)]);
    }

    static function prepareBracketForRegExp(str:String):String {
        // This bracket pair uses letters like e.g. "begin" - "end"
        final insertWordBoundaries = isWordOrSpaces(str);
        str = Strings.escapeRegExpCharacters(str);
        return (insertWordBoundaries ? '\\b' + str + '\\b' : str);
    }

    /**
     * `/^[\w ]+$/.test(str)`.
     */
    static function isWordOrSpaces(str:String):Bool {
        if (str.length == 0) {
            return false;
        }
        for (i in 0...str.length) {
            final c = StringTools.fastCodeAt(str, i);
            if (c != ' '.code && !RegExp.isAsciiWordChar(c)) {
                return false;
            }
        }
        return true;
    }

    /**
     * `createBracketOrRegExp` of richEditBrackets.ts.
     */
    public static function createBracketOrRegExp(pieces:Array<String>, ?options:RegExpOptions):RegExp {
        final regexStr = '(' + [for (p in pieces) prepareBracketForRegExp(p)].join(')|(') + ')';
        return Strings.createRegExp(regexStr, true, options);
    }

}

class BracketsUtils {

    /**
     * `toReversedString` of richEditBrackets.ts: the UTF-16 code units of
     * `str` in reverse order. Monaco caches the last result in a module
     * variable; Cityscape keeps no state in statics and reverses every time.
     */
    public static function toReversedString(str:String):String {
        final buf = new StringBuf();
        var i = str.length - 1;
        while (i >= 0) {
            buf.addChar(StringTools.fastCodeAt(str, i));
            i--;
        }
        return buf.toString();
    }

    /**
     * `text.match(regex)`: the offset (0 when the regular expression is
     * global, like Monaco's `m.index || 0`) and the text of the first match,
     * or null.
     */
    static function _match(regex:RegExp, text:String):Null<{index:Int, text:String}> {
        if (regex.global) {
            regex.lastIndex = 0;
            final m = regex.exec(text);
            regex.lastIndex = 0;
            if (m == null) {
                return null;
            }
            return {index: 0, text: m[0]};
        }
        final m = regex.exec(text);
        if (m == null) {
            return null;
        }
        return {index: m.index, text: m[0]};
    }

    static function _findPrevBracketInText(reversedBracketRegex:RegExp, lineNumber:Int, reversedText:String, offset:Int):Null<Range> {
        final m = _match(reversedBracketRegex, reversedText);

        if (m == null) {
            return null;
        }

        final matchOffset = reversedText.length - m.index;
        final matchLength = m.text.length;
        final absoluteMatchOffset = offset + matchOffset;

        return new Range(lineNumber, absoluteMatchOffset - matchLength + 1, lineNumber, absoluteMatchOffset + 1);
    }

    public static function findPrevBracketInRange(reversedBracketRegex:RegExp, lineNumber:Int, lineText:String, startOffset:Int, endOffset:Int):Null<Range> {
        // Because JS does not support backwards regex search, we search forwards in a reversed string with a reversed regex ;)
        final reversedLineText = toReversedString(lineText);
        final reversedSubstr = reversedLineText.substring(lineText.length - endOffset, lineText.length - startOffset);
        return _findPrevBracketInText(reversedBracketRegex, lineNumber, reversedSubstr, startOffset);
    }

    public static function findNextBracketInText(bracketRegex:RegExp, lineNumber:Int, text:String, offset:Int):Null<Range> {
        final m = _match(bracketRegex, text);

        if (m == null) {
            return null;
        }

        final matchOffset = m.index;
        final matchLength = m.text.length;
        if (matchLength == 0) {
            return null;
        }
        final absoluteMatchOffset = offset + matchOffset;

        return new Range(lineNumber, absoluteMatchOffset + 1, lineNumber, absoluteMatchOffset + 1 + matchLength);
    }

    public static function findNextBracketInRange(bracketRegex:RegExp, lineNumber:Int, lineText:String, startOffset:Int, endOffset:Int):Null<Range> {
        final substr = lineText.substring(startOffset, endOffset);
        return findNextBracketInText(bracketRegex, lineNumber, substr, startOffset);
    }

}
