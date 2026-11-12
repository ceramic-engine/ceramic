// Ported from vscode src/vs/editor/common/viewModel/monospaceLineBreaksComputer.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.viewModel;

import cityscape.base.common.CharCode;
import cityscape.base.common.Strings;
import cityscape.common.Model.InjectedTextOptions;
import cityscape.common.ModelLineProjectionData;
import cityscape.common.TextModelEvents.LineInjectedText;
import cityscape.common.config.EditorOptions.WrappingIndent;
import cityscape.common.config.FontInfo;
import cityscape.common.core.CharacterClassifier;

/**
 * Line breaks computed from character columns (the `simple` wrapping
 * strategy).
 *
 * Includes loreline-monaco's `[loreline]` patch as the
 * `wrappingIndentColumns` argument (`globalThis.__lorelineWrapExtraColumns`
 * there): when 0 or more, the extra indent of continuation lines is that
 * many columns per level instead of a tab stop.
 *
 * Monaco keeps two module level arrays reused between calls; they are
 * fields of the factory here (no state in statics).
 */
class MonospaceLineBreaksComputerFactory implements ILineBreaksComputerFactory {

    public static function create(breakBeforeChars:String, breakAfterChars:String):MonospaceLineBreaksComputerFactory {
        return new MonospaceLineBreaksComputerFactory(breakBeforeChars, breakAfterChars);
    }

    final classifier:WrappingCharacterClassifier;

    @:allow(cityscape.common.viewModel.MonospaceLineBreaksComputer)
    var arrPool1:Array<Int> = [];
    @:allow(cityscape.common.viewModel.MonospaceLineBreaksComputer)
    var arrPool2:Array<Float> = [];

    public function new(breakBeforeChars:String, breakAfterChars:String) {
        this.classifier = new WrappingCharacterClassifier(breakBeforeChars, breakAfterChars);
    }

    public function createLineBreaksComputer(fontInfo:FontInfo, tabSize:Int, wrappingColumn:Int, wrappingIndent:WrappingIndent, wordBreak:String, wrappingIndentColumns:Int):ILineBreaksComputer {
        return new MonospaceLineBreaksComputer(this, classifier, fontInfo, tabSize, wrappingColumn, wrappingIndent, wordBreak, wrappingIndentColumns);
    }

}

@:allow(cityscape.common.viewModel.MonospaceLineBreaksComputerFactory)
class MonospaceLineBreaksComputer implements ILineBreaksComputer {

    final factory:MonospaceLineBreaksComputerFactory;
    final classifier:WrappingCharacterClassifier;
    final fontInfo:FontInfo;
    final tabSize:Int;
    final wrappingColumn:Int;
    final wrappingIndent:WrappingIndent;
    final wordBreak:String;
    final wrappingIndentColumns:Int;

    final requests:Array<String> = [];
    final injectedTexts:Array<Null<Array<LineInjectedText>>> = [];
    final previousBreakingData:Array<Null<ModelLineProjectionData>> = [];

    function new(factory:MonospaceLineBreaksComputerFactory, classifier:WrappingCharacterClassifier, fontInfo:FontInfo, tabSize:Int, wrappingColumn:Int, wrappingIndent:WrappingIndent, wordBreak:String, wrappingIndentColumns:Int) {
        this.factory = factory;
        this.classifier = classifier;
        this.fontInfo = fontInfo;
        this.tabSize = tabSize;
        this.wrappingColumn = wrappingColumn;
        this.wrappingIndent = wrappingIndent;
        this.wordBreak = wordBreak;
        this.wrappingIndentColumns = wrappingIndentColumns;
    }

    public function addRequest(lineText:String, injectedText:Null<Array<LineInjectedText>>, previousLineBreakData:Null<ModelLineProjectionData>):Void {
        requests.push(lineText);
        injectedTexts.push(injectedText);
        previousBreakingData.push(previousLineBreakData);
    }

    public function finalizeResult():Array<Null<ModelLineProjectionData>> {
        final columnsForFullWidthChar = fontInfo.typicalFullwidthCharacterWidth / fontInfo.typicalHalfwidthCharacterWidth;
        final result:Array<Null<ModelLineProjectionData>> = [];
        for (i in 0...requests.length) {
            final injectedText = injectedTexts[i];
            final previousLineBreakData = previousBreakingData[i];
            if (previousLineBreakData != null && previousLineBreakData.injectionOptions == null && injectedText == null) {
                result[i] = createLineBreaksFromPreviousLineBreaks(factory, classifier, previousLineBreakData, requests[i], tabSize, wrappingColumn, columnsForFullWidthChar, wrappingIndent, wordBreak, wrappingIndentColumns);
            } else {
                result[i] = createLineBreaks(classifier, requests[i], injectedText, tabSize, wrappingColumn, columnsForFullWidthChar, wrappingIndent, wordBreak, wrappingIndentColumns);
            }
        }
        factory.arrPool1.resize(0);
        factory.arrPool2.resize(0);
        return result;
    }

    static function createLineBreaksFromPreviousLineBreaks(factory:MonospaceLineBreaksComputerFactory, classifier:WrappingCharacterClassifier, previousBreakingData:ModelLineProjectionData, lineText:String, tabSize:Int, firstLineBreakColumn:Int, columnsForFullWidthChar:Float, wrappingIndent:WrappingIndent, wordBreak:String, wrappingIndentColumns:Int):Null<ModelLineProjectionData> {
        if (firstLineBreakColumn == -1) {
            return null;
        }

        final len = lineText.length;
        if (len <= 1) {
            return null;
        }

        final isKeepAll = (wordBreak == 'keepAll');

        final prevBreakingOffsets = previousBreakingData.breakOffsets;
        final prevBreakingOffsetsVisibleColumn = previousBreakingData.breakOffsetsVisibleColumn;

        final wrappedTextIndentLength = computeWrappedTextIndentLength(lineText, tabSize, firstLineBreakColumn, columnsForFullWidthChar, wrappingIndent, wrappingIndentColumns);
        final wrappedLineBreakColumn = firstLineBreakColumn - wrappedTextIndentLength;

        final breakingOffsets:Array<Int> = factory.arrPool1;
        final breakingOffsetsVisibleColumn:Array<Float> = factory.arrPool2;
        var breakingOffsetsCount = 0;
        var lastBreakingOffset = 0;
        var lastBreakingOffsetVisibleColumn:Float = 0;

        var breakingColumn:Float = firstLineBreakColumn;
        final prevLen = prevBreakingOffsets.length;
        var prevIndex = 0;

        if (prevIndex >= 0) {
            var bestDistance = Math.abs(prevBreakingOffsetsVisibleColumn[prevIndex] - breakingColumn);
            while (prevIndex + 1 < prevLen) {
                final distance = Math.abs(prevBreakingOffsetsVisibleColumn[prevIndex + 1] - breakingColumn);
                if (distance >= bestDistance) {
                    break;
                }
                bestDistance = distance;
                prevIndex++;
            }
        }

        while (prevIndex < prevLen) {
            // Allow for prevIndex to be -1 (for the case where we hit a tab when walking backwards from the first break)
            var prevBreakOffset = prevIndex < 0 ? 0 : prevBreakingOffsets[prevIndex];
            var prevBreakOffsetVisibleColumn:Float = prevIndex < 0 ? 0 : prevBreakingOffsetsVisibleColumn[prevIndex];
            if (lastBreakingOffset > prevBreakOffset) {
                prevBreakOffset = lastBreakingOffset;
                prevBreakOffsetVisibleColumn = lastBreakingOffsetVisibleColumn;
            }

            var breakOffset = 0;
            var breakOffsetVisibleColumn:Float = 0;

            var forcedBreakOffset = 0;
            var forcedBreakOffsetVisibleColumn:Float = 0;

            // initially, we search as much as possible to the right (if it fits)
            if (prevBreakOffsetVisibleColumn <= breakingColumn) {
                var visibleColumn = prevBreakOffsetVisibleColumn;
                var prevCharCode = prevBreakOffset == 0 ? CharCode.Null : StringTools.fastCodeAt(lineText, prevBreakOffset - 1);
                var prevCharCodeClass = prevBreakOffset == 0 ? CharacterClass.NONE : classifier.get(prevCharCode);
                var entireLineFits = true;
                var i = prevBreakOffset;
                while (i < len) {
                    final charStartOffset = i;
                    final charCode = StringTools.fastCodeAt(lineText, i);
                    var charCodeClass:Int;
                    var charWidth:Float;

                    if (Strings.isHighSurrogate(charCode)) {
                        // A surrogate pair must always be considered as a single unit, so it is never to be broken
                        i++;
                        charCodeClass = CharacterClass.NONE;
                        charWidth = 2;
                    } else {
                        charCodeClass = classifier.get(charCode);
                        charWidth = computeCharWidth(charCode, visibleColumn, tabSize, columnsForFullWidthChar);
                    }

                    if (charStartOffset > lastBreakingOffset && canBreak(prevCharCode, prevCharCodeClass, charCode, charCodeClass, isKeepAll)) {
                        breakOffset = charStartOffset;
                        breakOffsetVisibleColumn = visibleColumn;
                    }

                    visibleColumn += charWidth;

                    // check if adding character at `i` will go over the breaking column
                    if (visibleColumn > breakingColumn) {
                        // We need to break at least before character at `i`:
                        if (charStartOffset > lastBreakingOffset) {
                            forcedBreakOffset = charStartOffset;
                            forcedBreakOffsetVisibleColumn = visibleColumn - charWidth;
                        } else {
                            // we need to advance at least by one character
                            forcedBreakOffset = i + 1;
                            forcedBreakOffsetVisibleColumn = visibleColumn;
                        }

                        if (visibleColumn - breakOffsetVisibleColumn > wrappedLineBreakColumn) {
                            // Cannot break at `breakOffset` => reset it if it was set
                            breakOffset = 0;
                        }

                        entireLineFits = false;
                        break;
                    }

                    prevCharCode = charCode;
                    prevCharCodeClass = charCodeClass;
                    i++;
                }

                if (entireLineFits) {
                    // there is no more need to break => stop the outer loop!
                    if (breakingOffsetsCount > 0) {
                        // Add last segment, no need to assign to `lastBreakingOffset` and `lastBreakingOffsetVisibleColumn`
                        breakingOffsets[breakingOffsetsCount] = prevBreakingOffsets[prevBreakingOffsets.length - 1];
                        breakingOffsetsVisibleColumn[breakingOffsetsCount] = prevBreakingOffsetsVisibleColumn[prevBreakingOffsets.length - 1];
                        breakingOffsetsCount++;
                    }
                    break;
                }
            }

            if (breakOffset == 0) {
                // must search left
                var visibleColumn = prevBreakOffsetVisibleColumn;
                var charCode = charCodeAtOrNaN(lineText, prevBreakOffset);
                var charCodeClass = classifier.get(charCode);
                var hitATabCharacter = false;
                var i = prevBreakOffset - 1;
                while (i >= lastBreakingOffset) {
                    final charStartOffset = i + 1;
                    final prevCharCode = StringTools.fastCodeAt(lineText, i);

                    if (prevCharCode == CharCode.Tab) {
                        // cannot determine the width of a tab when going backwards, so we must go forwards
                        hitATabCharacter = true;
                        break;
                    }

                    var prevCharCodeClass:Int;
                    var prevCharWidth:Float;

                    if (Strings.isLowSurrogate(prevCharCode)) {
                        // A surrogate pair must always be considered as a single unit, so it is never to be broken
                        i--;
                        prevCharCodeClass = CharacterClass.NONE;
                        prevCharWidth = 2;
                    } else {
                        prevCharCodeClass = classifier.get(prevCharCode);
                        prevCharWidth = (Strings.isFullWidthCharacter(prevCharCode) ? columnsForFullWidthChar : 1);
                    }

                    if (visibleColumn <= breakingColumn) {
                        if (forcedBreakOffset == 0) {
                            forcedBreakOffset = charStartOffset;
                            forcedBreakOffsetVisibleColumn = visibleColumn;
                        }

                        if (visibleColumn <= breakingColumn - wrappedLineBreakColumn) {
                            // went too far!
                            break;
                        }

                        if (canBreak(prevCharCode, prevCharCodeClass, charCode, charCodeClass, isKeepAll)) {
                            breakOffset = charStartOffset;
                            breakOffsetVisibleColumn = visibleColumn;
                            break;
                        }
                    }

                    visibleColumn -= prevCharWidth;
                    charCode = prevCharCode;
                    charCodeClass = prevCharCodeClass;
                    i--;
                }

                if (breakOffset != 0) {
                    final remainingWidthOfNextLine = wrappedLineBreakColumn - (forcedBreakOffsetVisibleColumn - breakOffsetVisibleColumn);
                    if (remainingWidthOfNextLine <= tabSize) {
                        final charCodeAtForcedBreakOffset = charCodeAtOrNaN(lineText, forcedBreakOffset);
                        var charWidth:Float;
                        if (Strings.isHighSurrogate(charCodeAtForcedBreakOffset)) {
                            // A surrogate pair must always be considered as a single unit, so it is never to be broken
                            charWidth = 2;
                        } else {
                            charWidth = computeCharWidth(charCodeAtForcedBreakOffset, forcedBreakOffsetVisibleColumn, tabSize, columnsForFullWidthChar);
                        }
                        if (remainingWidthOfNextLine - charWidth < 0) {
                            // it is not worth it to break at breakOffset, it just introduces an extra needless line!
                            breakOffset = 0;
                        }
                    }
                }

                if (hitATabCharacter) {
                    // cannot determine the width of a tab when going backwards, so we must go forwards from the previous break
                    prevIndex--;
                    continue;
                }
            }

            if (breakOffset == 0) {
                // Could not find a good breaking point
                breakOffset = forcedBreakOffset;
                breakOffsetVisibleColumn = forcedBreakOffsetVisibleColumn;
            }

            if (breakOffset <= lastBreakingOffset) {
                // Make sure that we are advancing (at least one character)
                final charCode = charCodeAtOrNaN(lineText, lastBreakingOffset);
                if (Strings.isHighSurrogate(charCode)) {
                    // A surrogate pair must always be considered as a single unit, so it is never to be broken
                    breakOffset = lastBreakingOffset + 2;
                    breakOffsetVisibleColumn = lastBreakingOffsetVisibleColumn + 2;
                } else {
                    breakOffset = lastBreakingOffset + 1;
                    breakOffsetVisibleColumn = lastBreakingOffsetVisibleColumn + computeCharWidth(charCode, lastBreakingOffsetVisibleColumn, tabSize, columnsForFullWidthChar);
                }
            }

            lastBreakingOffset = breakOffset;
            breakingOffsets[breakingOffsetsCount] = breakOffset;
            lastBreakingOffsetVisibleColumn = breakOffsetVisibleColumn;
            breakingOffsetsVisibleColumn[breakingOffsetsCount] = breakOffsetVisibleColumn;
            breakingOffsetsCount++;
            breakingColumn = breakOffsetVisibleColumn + wrappedLineBreakColumn;

            while (prevIndex < 0 || (prevIndex < prevLen && prevBreakingOffsetsVisibleColumn[prevIndex] < breakOffsetVisibleColumn)) {
                prevIndex++;
            }

            // `prevBreakingOffsetsVisibleColumn[prevLen]` is `undefined` in Monaco: NaN distances end the search
            var bestDistance = prevIndex < prevLen ? Math.abs(prevBreakingOffsetsVisibleColumn[prevIndex] - breakingColumn) : Math.NaN;
            while (prevIndex + 1 < prevLen) {
                final distance = Math.abs(prevBreakingOffsetsVisibleColumn[prevIndex + 1] - breakingColumn);
                if (distance >= bestDistance) {
                    break;
                }
                bestDistance = distance;
                prevIndex++;
            }
        }

        if (breakingOffsetsCount == 0) {
            return null;
        }

        // Doing here some object reuse which ends up helping a huge deal with GC pauses!
        breakingOffsets.resize(breakingOffsetsCount);
        breakingOffsetsVisibleColumn.resize(breakingOffsetsCount);
        factory.arrPool1 = previousBreakingData.breakOffsets;
        factory.arrPool2 = previousBreakingData.breakOffsetsVisibleColumn;
        previousBreakingData.breakOffsets = breakingOffsets;
        previousBreakingData.breakOffsetsVisibleColumn = breakingOffsetsVisibleColumn;
        previousBreakingData.wrappedTextIndentLength = wrappedTextIndentLength;
        return previousBreakingData;
    }

    /**
     * `str.charCodeAt(i)`, -1 (standing for JavaScript's NaN, which no
     * comparison matches) past the end.
     */
    static inline function charCodeAtOrNaN(str:String, i:Int):Int {
        return i < str.length ? StringTools.fastCodeAt(str, i) : -1;
    }

    static function createLineBreaks(classifier:WrappingCharacterClassifier, _lineText:String, injectedTexts:Null<Array<LineInjectedText>>, tabSize:Int, firstLineBreakColumn:Int, columnsForFullWidthChar:Float, wrappingIndent:WrappingIndent, wordBreak:String, wrappingIndentColumns:Int):Null<ModelLineProjectionData> {
        final lineText = LineInjectedText.applyInjectedText(_lineText, injectedTexts);

        var injectionOptions:Null<Array<InjectedTextOptions>>;
        var injectionOffsets:Null<Array<Int>>;
        if (injectedTexts != null && injectedTexts.length > 0) {
            injectionOptions = [for (t in injectedTexts) t.options];
            injectionOffsets = [for (text in injectedTexts) text.column - 1];
        } else {
            injectionOptions = null;
            injectionOffsets = null;
        }

        if (firstLineBreakColumn == -1) {
            if (injectionOptions == null) {
                return null;
            }
            // creating a `LineBreakData` with an invalid `breakOffsetsVisibleColumn` is OK
            // because `breakOffsetsVisibleColumn` will never be used because it contains injected text
            return new ModelLineProjectionData(injectionOffsets, injectionOptions, [lineText.length], [], 0);
        }

        final len = lineText.length;
        if (len <= 1) {
            if (injectionOptions == null) {
                return null;
            }
            // creating a `LineBreakData` with an invalid `breakOffsetsVisibleColumn` is OK
            // because `breakOffsetsVisibleColumn` will never be used because it contains injected text
            return new ModelLineProjectionData(injectionOffsets, injectionOptions, [lineText.length], [], 0);
        }

        final isKeepAll = (wordBreak == 'keepAll');
        final wrappedTextIndentLength = computeWrappedTextIndentLength(lineText, tabSize, firstLineBreakColumn, columnsForFullWidthChar, wrappingIndent, wrappingIndentColumns);
        final wrappedLineBreakColumn = firstLineBreakColumn - wrappedTextIndentLength;

        final breakingOffsets:Array<Int> = [];
        final breakingOffsetsVisibleColumn:Array<Float> = [];
        var breakingOffsetsCount = 0;
        var breakOffset = 0;
        var breakOffsetVisibleColumn:Float = 0;

        var breakingColumn:Float = firstLineBreakColumn;
        var prevCharCode = StringTools.fastCodeAt(lineText, 0);
        var prevCharCodeClass = classifier.get(prevCharCode);
        var visibleColumn = computeCharWidth(prevCharCode, 0, tabSize, columnsForFullWidthChar);

        var startOffset = 1;
        if (Strings.isHighSurrogate(prevCharCode)) {
            // A surrogate pair must always be considered as a single unit, so it is never to be broken
            visibleColumn += 1;
            prevCharCode = StringTools.fastCodeAt(lineText, 1);
            prevCharCodeClass = classifier.get(prevCharCode);
            startOffset++;
        }

        var i = startOffset;
        while (i < len) {
            final charStartOffset = i;
            final charCode = StringTools.fastCodeAt(lineText, i);
            var charCodeClass:Int;
            var charWidth:Float;

            if (Strings.isHighSurrogate(charCode)) {
                // A surrogate pair must always be considered as a single unit, so it is never to be broken
                i++;
                charCodeClass = CharacterClass.NONE;
                charWidth = 2;
            } else {
                charCodeClass = classifier.get(charCode);
                charWidth = computeCharWidth(charCode, visibleColumn, tabSize, columnsForFullWidthChar);
            }

            if (canBreak(prevCharCode, prevCharCodeClass, charCode, charCodeClass, isKeepAll)) {
                breakOffset = charStartOffset;
                breakOffsetVisibleColumn = visibleColumn;
            }

            visibleColumn += charWidth;

            // check if adding character at `i` will go over the breaking column
            if (visibleColumn > breakingColumn) {
                // We need to break at least before character at `i`:

                if (breakOffset == 0 || visibleColumn - breakOffsetVisibleColumn > wrappedLineBreakColumn) {
                    // Cannot break at `breakOffset`, must break at `i`
                    breakOffset = charStartOffset;
                    breakOffsetVisibleColumn = visibleColumn - charWidth;
                }

                breakingOffsets[breakingOffsetsCount] = breakOffset;
                breakingOffsetsVisibleColumn[breakingOffsetsCount] = breakOffsetVisibleColumn;
                breakingOffsetsCount++;
                breakingColumn = breakOffsetVisibleColumn + wrappedLineBreakColumn;
                breakOffset = 0;
            }

            prevCharCode = charCode;
            prevCharCodeClass = charCodeClass;
            i++;
        }

        if (breakingOffsetsCount == 0 && (injectedTexts == null || injectedTexts.length == 0)) {
            return null;
        }

        // Add last segment
        breakingOffsets[breakingOffsetsCount] = len;
        breakingOffsetsVisibleColumn[breakingOffsetsCount] = visibleColumn;

        return new ModelLineProjectionData(injectionOffsets, injectionOptions, breakingOffsets, breakingOffsetsVisibleColumn, wrappedTextIndentLength);
    }

    static function computeCharWidth(charCode:Int, visibleColumn:Float, tabSize:Int, columnsForFullWidthChar:Float):Float {
        if (charCode == CharCode.Tab) {
            return (tabSize - jsMod(visibleColumn, tabSize));
        }
        if (Strings.isFullWidthCharacter(charCode)) {
            return columnsForFullWidthChar;
        }
        if (charCode < 32) {
            // when using `editor.renderControlCharacters`, the substitutions are often wide
            return columnsForFullWidthChar;
        }
        return 1;
    }

    /**
     * JavaScript's `%` on numbers.
     */
    static inline function jsMod(a:Float, b:Float):Float {
        return a % b;
    }

    static function tabCharacterWidth(visibleColumn:Float, tabSize:Int):Float {
        return (tabSize - jsMod(visibleColumn, tabSize));
    }

    /**
     * Kinsoku Shori : Don't break after a leading character, like an open bracket
     * Kinsoku Shori : Don't break before a trailing character, like a period
     */
    static function canBreak(prevCharCode:Int, prevCharCodeClass:Int, charCode:Int, charCodeClass:Int, isKeepAll:Bool):Bool {
        return (
            charCode != CharCode.Space
            && (
                (prevCharCodeClass == CharacterClass.BREAK_AFTER && charCodeClass != CharacterClass.BREAK_AFTER) // break at the end of multiple BREAK_AFTER
                || (prevCharCodeClass != CharacterClass.BREAK_BEFORE && charCodeClass == CharacterClass.BREAK_BEFORE) // break at the start of multiple BREAK_BEFORE
                || (!isKeepAll && prevCharCodeClass == CharacterClass.BREAK_IDEOGRAPHIC && charCodeClass != CharacterClass.BREAK_AFTER)
                || (!isKeepAll && charCodeClass == CharacterClass.BREAK_IDEOGRAPHIC && prevCharCodeClass != CharacterClass.BREAK_BEFORE)
            )
        );
    }

    /**
     * Monaco's `computeWrappedTextIndentLength`, with the `[loreline]` patch
     * (`wrappingIndentColumns`). The result is an Int when `tabSize` and
     * the columns are; a fractional `columnsForFullWidthChar` only takes part
     * in the comparison.
     */
    public static function computeWrappedTextIndentLength(lineText:String, tabSize:Int, firstLineBreakColumn:Int, columnsForFullWidthChar:Float, wrappingIndent:WrappingIndent, wrappingIndentColumns:Int = -1):Int {
        var wrappedTextIndentLength = 0;
        if (wrappingIndent != WrappingIndent.None) {
            final firstNonWhitespaceIndex = Strings.firstNonWhitespaceIndex(lineText);
            if (firstNonWhitespaceIndex != -1) {
                // Track existing indent

                for (i in 0...firstNonWhitespaceIndex) {
                    final charWidth = (StringTools.fastCodeAt(lineText, i) == CharCode.Tab ? Std.int(tabCharacterWidth(wrappedTextIndentLength, tabSize)) : 1);
                    wrappedTextIndentLength += charWidth;
                }

                // Increase indent of continuation lines, if desired
                final numberOfAdditionalTabs = (wrappingIndent == WrappingIndent.DeepIndent ? 2 : wrappingIndent == WrappingIndent.Indent ? 1 : 0);
                if (wrappingIndentColumns >= 0) {
                    // [loreline] the extra indent is that many columns per level
                    // instead of being snapped to the next tab stop
                    wrappedTextIndentLength += numberOfAdditionalTabs * wrappingIndentColumns;
                } else {
                    for (i in 0...numberOfAdditionalTabs) {
                        final charWidth = Std.int(tabCharacterWidth(wrappedTextIndentLength, tabSize));
                        wrappedTextIndentLength += charWidth;
                    }
                }

                // Force sticking to beginning of line if no character would fit except for the indentation
                if (wrappedTextIndentLength + columnsForFullWidthChar > firstLineBreakColumn) {
                    wrappedTextIndentLength = 0;
                }
            }
        }
        return wrappedTextIndentLength;
    }

}

enum abstract CharacterClass(Int) from Int to Int {
    var NONE = 0;
    var BREAK_BEFORE = 1;
    var BREAK_AFTER = 2;
    var BREAK_IDEOGRAPHIC = 3; // for Han and Kana.
}

class WrappingCharacterClassifier extends CharacterClassifier {

    public function new(BREAK_BEFORE:String, BREAK_AFTER:String) {
        super(CharacterClass.NONE);

        for (i in 0...BREAK_BEFORE.length) {
            this.set(StringTools.fastCodeAt(BREAK_BEFORE, i), CharacterClass.BREAK_BEFORE);
        }

        for (i in 0...BREAK_AFTER.length) {
            this.set(StringTools.fastCodeAt(BREAK_AFTER, i), CharacterClass.BREAK_AFTER);
        }
    }

    override public function get(charCode:Int):Int {
        if (charCode >= 0 && charCode < 256) {
            return this._asciiMap.get(charCode);
        } else {
            // Initialize CharacterClass.BREAK_IDEOGRAPHIC for these Unicode ranges:
            // 1. CJK Unified Ideographs (0x4E00 -- 0x9FFF)
            // 2. CJK Unified Ideographs Extension A (0x3400 -- 0x4DBF)
            // 3. Hiragana and Katakana (0x3040 -- 0x30FF)
            if (
                (charCode >= 0x3040 && charCode <= 0x30FF)
                || (charCode >= 0x3400 && charCode <= 0x4DBF)
                || (charCode >= 0x4E00 && charCode <= 0x9FFF)
            ) {
                return CharacterClass.BREAK_IDEOGRAPHIC;
            }

            final v = this._map.get(charCode);
            return (v == null || v == 0) ? this._defaultValue : v;
        }
    }

}
