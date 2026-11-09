// Ported from vscode src/vs/editor/common/core/wordHelper.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.core;

import cityscape.base.common.Lifecycle;
import cityscape.base.common.RegExp;

/**
 * Word information.
 */
typedef IWordAtPosition = {
    /**
     * The word.
     */
    final word:String;
    /**
     * The column where the word starts.
     */
    final startColumn:Int;
    /**
     * The column where the word ends.
     */
    final endColumn:Int;
}

typedef IGetWordAtTextConfig = {
    var maxLen:Int;
    var windowSize:Int;
    var timeBudget:Float;
}

/**
 * Module values and functions of wordHelper.ts.
 */
class WordHelper {

    public static inline final USUAL_WORD_SEPARATORS = "`~!@#$%^&*()-=+[{]}\\|;:'\",.<>/?";

    /**
     * Create a word definition regular expression based on default word separators.
     * Optionally provide allowed separators that should be included in words.
     *
     * The default would look like this:
     * /(-?\d*\.\d\w*)|([^\`\~\!\@\#\$\%\^\&\*\(\)\-\=\+\[\{\]\}\\\|\;\:\'\"\,\.\<\>\/\?\s]+)/g
     */
    static function createWordRegExp(allowInWords:String = ''):RegExp {
        var source = '(-?\\d*\\.\\d\\w*)|([^';
        for (i in 0...USUAL_WORD_SEPARATORS.length) {
            final sep = USUAL_WORD_SEPARATORS.charAt(i);
            if (allowInWords.indexOf(sep) >= 0) {
                continue;
            }
            source += '\\' + sep;
        }
        source += '\\s]+)';
        return new RegExp(source, 'g');
    }

    /**
     * catches numbers (including floating numbers) in the first group, and alphanum in the second.
     *
     * Like Monaco, a single shared object: `getWordAtText` uses its
     * `lastIndex` during a call and resets it to 0, so it must be used from
     * one thread at a time (the main thread).
     */
    public static final DEFAULT_WORD_REGEXP:RegExp = createWordRegExp();

    public static function ensureValidWordDefinition(?wordDefinition:RegExp):RegExp {
        var result:RegExp = DEFAULT_WORD_REGEXP;

        if (wordDefinition != null) {
            if (!wordDefinition.global) {
                var flags = 'g';
                if (wordDefinition.ignoreCase) {
                    flags += 'i';
                }
                if (wordDefinition.multiline) {
                    flags += 'm';
                }
                if (wordDefinition.unicode) {
                    flags += 'u';
                }
                result = new RegExp(wordDefinition.source, flags);
            }
            else {
                result = wordDefinition;
            }
        }

        result.lastIndex = 0;

        return result;
    }

    static final _defaultConfig:Array<IGetWordAtTextConfig> = [{
        maxLen: 1000,
        windowSize: 15,
        timeBudget: 150
    }];

    /**
     * Sets the configuration of `getWordAtText` used when none is given
     * (an application wide setting, like Monaco's); disposing the result
     * restores the previous one.
     */
    public static function setDefaultGetWordAtTextConfig(value:IGetWordAtTextConfig):IDisposable {
        _defaultConfig.unshift(value);
        return Lifecycle.toDisposable(() -> _defaultConfig.remove(value));
    }

    public static function getWordAtText(column:Int, wordDefinition:RegExp, text:String, textOffset:Int, ?config:IGetWordAtTextConfig):Null<IWordAtPosition> {
        // Ensure the regex has the 'g' flag, otherwise this will loop forever
        wordDefinition = ensureValidWordDefinition(wordDefinition);

        if (config == null) {
            config = _defaultConfig[0];
        }

        if (text.length > config.maxLen) {
            // don't throw strings that long at the regexp
            // but use a sub-string in which a word must occur
            var start = column - config.maxLen / 2;
            if (start < 0) {
                start = 0;
            }
            else {
                textOffset += Std.int(start);
            }
            text = jsSubstring(text, start, column + config.maxLen / 2);
            return getWordAtText(column, wordDefinition, text, textOffset, config);
        }

        final t1 = haxe.Timer.stamp() * 1000;
        final pos = column - 1 - textOffset;

        var prevRegexIndex = -1;
        var match:Null<RegExpExecArray> = null;

        var i = 1;
        while (true) {
            // check time budget
            if (haxe.Timer.stamp() * 1000 - t1 >= config.timeBudget) {
                break;
            }

            // reset the index at which the regexp should start matching, also know where it
            // should stop so that subsequent search don't repeat previous searches
            final regexIndex = pos - config.windowSize * i;
            wordDefinition.lastIndex = Std.int(Math.max(0, regexIndex));
            final thisMatch = _findRegexMatchEnclosingPosition(wordDefinition, text, pos, prevRegexIndex);

            if (thisMatch == null && match != null) {
                // stop: we have something
                break;
            }

            match = thisMatch;

            // stop: searched at start
            if (regexIndex <= 0) {
                break;
            }
            prevRegexIndex = regexIndex;
            i++;
        }

        if (match != null) {
            final result:IWordAtPosition = {
                word: match[0],
                startColumn: textOffset + 1 + match.index,
                endColumn: textOffset + 1 + match.index + match[0].length
            };
            wordDefinition.lastIndex = 0;
            return result;
        }

        return null;
    }

    /**
     * JavaScript's `substring` with number arguments (floored, clamped,
     * swapped when reversed).
     */
    static function jsSubstring(text:String, start:Float, end:Float):String {
        var s = Std.int(Math.max(0, Math.min(text.length, Math.isNaN(start) ? 0 : start)));
        var e = Std.int(Math.max(0, Math.min(text.length, Math.isNaN(end) ? 0 : end)));
        if (s > e) {
            final t = s;
            s = e;
            e = t;
        }
        return text.substring(s, e);
    }

    static function _findRegexMatchEnclosingPosition(wordDefinition:RegExp, text:String, pos:Int, stopPos:Int):Null<RegExpExecArray> {
        var match:Null<RegExpExecArray>;
        while ((match = wordDefinition.exec(text)) != null) {
            final matchIndex = match.index;
            if (matchIndex <= pos && wordDefinition.lastIndex >= pos) {
                return match;
            }
            else if (stopPos > 0 && matchIndex > stopPos) {
                return null;
            }
        }
        return null;
    }

}
