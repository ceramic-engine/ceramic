// Ported from vscode src/vs/editor/browser/view/domLineBreaksComputer.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view;

import cityscape.base.common.CharCode;
import cityscape.base.common.Strings;
import cityscape.common.Model.InjectedTextOptions;
import cityscape.common.ModelLineProjectionData;
import cityscape.common.TextModelEvents.LineInjectedText;
import cityscape.common.config.EditorOptions.WrappingIndent;
import cityscape.common.config.FontInfo;

/**
 * Measures text for `MeasuredLineBreaksComputerFactory`: the x position of
 * every UTF-16 offset of `text` (`text.length + 1` values, the first one 0).
 */
interface ILineMeasurer {
    function measure(text:String, fontInfo:FontInfo):Array<Float>;
}

/**
 * The line breaks of the `advanced` wrapping strategy, measured by Glaze's
 * text system instead of the DOM (Monaco renders the lines in a hidden
 * `div` and reads where the browser broke them).
 *
 * Same inputs and outputs as Monaco: the indent of continuation lines, the
 * `[loreline]` patch (`wrappingIndentColumns`), break offsets in the text
 * with injections, visible columns. The break opportunities approximate the
 * browser's (`overflow-wrap: break-word`): after a run of spaces, around
 * CJK ideographs and kana (unless `wordBreak` is `keepAll`), after a hyphen,
 * and anywhere (between graphemes) when a word does not fit; trailing spaces
 * hang past the width, like CSS (docs/DEVIATIONS.md, "Measured line breaks").
 */
class MeasuredLineBreaksComputerFactory implements ILineBreaksComputerFactory {

    final measurer:ILineMeasurer;

    public function new(measurer:ILineMeasurer) {
        this.measurer = measurer;
    }

    public function createLineBreaksComputer(fontInfo:FontInfo, tabSize:Int, wrappingColumn:Int, wrappingIndent:WrappingIndent, wordBreak:String, wrappingIndentColumns:Int):ILineBreaksComputer {
        return new MeasuredLineBreaksComputer(measurer, fontInfo, tabSize, wrappingColumn, wrappingIndent, wordBreak, wrappingIndentColumns);
    }

}

private class MeasuredLineBreaksComputer implements ILineBreaksComputer {

    final measurer:ILineMeasurer;
    final fontInfo:FontInfo;
    final tabSize:Int;
    final wrappingColumn:Int;
    final wrappingIndent:WrappingIndent;
    final wordBreak:String;
    final wrappingIndentColumns:Int;

    final requests:Array<String> = [];
    final injectedTexts:Array<Null<Array<LineInjectedText>>> = [];

    public function new(measurer:ILineMeasurer, fontInfo:FontInfo, tabSize:Int, wrappingColumn:Int, wrappingIndent:WrappingIndent, wordBreak:String, wrappingIndentColumns:Int) {
        this.measurer = measurer;
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
    }

    public function finalize():Array<Null<ModelLineProjectionData>> {
        return createLineBreaks(requests, fontInfo, tabSize, wrappingColumn, wrappingIndent, wordBreak, injectedTexts);
    }

    function createEmptyLineBreakWithPossiblyInjectedText(requestIdx:Int):Null<ModelLineProjectionData> {
        final injectedTexts = injectedTexts[requestIdx];
        if (injectedTexts != null) {
            final lineText = LineInjectedText.applyInjectedText(requests[requestIdx], injectedTexts);

            final injectionOptions = [for (t in injectedTexts) t.options];
            final injectionOffsets = [for (text in injectedTexts) text.column - 1];

            // creating a `LineBreakData` with an invalid `breakOffsetsVisibleColumn` is OK
            // because `breakOffsetsVisibleColumn` will never be used because it contains injected text
            return new ModelLineProjectionData(injectionOffsets, injectionOptions, [lineText.length], [], 0);
        } else {
            return null;
        }
    }

    function createLineBreaks(requests:Array<String>, fontInfo:FontInfo, tabSize:Int, firstLineBreakColumn:Int, wrappingIndent:WrappingIndent, wordBreak:String, injectedTextsPerLine:Array<Null<Array<LineInjectedText>>>):Array<Null<ModelLineProjectionData>> {
        if (firstLineBreakColumn == -1) {
            return [for (i in 0...requests.length) createEmptyLineBreakWithPossiblyInjectedText(i)];
        }

        final overallWidth = Math.round(firstLineBreakColumn * fontInfo.typicalHalfwidthCharacterWidth);
        final additionalIndent = (wrappingIndent == WrappingIndent.DeepIndent ? 2 : wrappingIndent == WrappingIndent.Indent ? 1 : 0);
        // [loreline] See monospaceLineBreaksComputer, and keep both computers in sync
        final additionalIndentSize = (wrappingIndentColumns >= 0)
            ? Math.round(wrappingIndentColumns * additionalIndent)
            : Math.round(tabSize * additionalIndent);
        final additionalIndentLength = Math.ceil(fontInfo.spaceWidth * additionalIndentSize);

        final result:Array<Null<ModelLineProjectionData>> = [];
        for (i in 0...requests.length) {
            final lineContent = LineInjectedText.applyInjectedText(requests[i], injectedTextsPerLine[i]);

            var firstNonWhitespaceIndex = 0;
            var wrappedTextIndentLength = 0;
            var width:Float = overallWidth;

            if (wrappingIndent != WrappingIndent.None) {
                firstNonWhitespaceIndex = Strings.firstNonWhitespaceIndex(lineContent);
                if (firstNonWhitespaceIndex == -1) {
                    // all whitespace line
                    firstNonWhitespaceIndex = 0;

                } else {
                    // Track existing indent

                    for (j in 0...firstNonWhitespaceIndex) {
                        final charWidth = (
                            StringTools.fastCodeAt(lineContent, j) == CharCode.Tab
                                ? (tabSize - (wrappedTextIndentLength % tabSize))
                                : 1
                        );
                        wrappedTextIndentLength += charWidth;
                    }

                    final indentWidth = Math.ceil(fontInfo.spaceWidth * wrappedTextIndentLength);

                    // Force sticking to beginning of line if no character would fit except for the indentation
                    if (indentWidth + fontInfo.typicalFullwidthCharacterWidth > overallWidth) {
                        firstNonWhitespaceIndex = 0;
                        wrappedTextIndentLength = 0;
                    } else {
                        width = overallWidth - indentWidth;
                    }
                }
            }

            final renderLineContent = lineContent.substr(firstNonWhitespaceIndex);
            final breakOffsets = readLineBreaks(renderLineContent, wrappedTextIndentLength, tabSize, width, additionalIndentLength, wordBreak == 'keepAll');
            if (breakOffsets == null) {
                result[i] = createEmptyLineBreakWithPossiblyInjectedText(i);
                continue;
            }

            final visibleColumns = computeVisibleColumns(renderLineContent, wrappedTextIndentLength, tabSize);
            final breakOffsetsVisibleColumn:Array<Float> = [for (offset in breakOffsets) visibleColumns[offset]];

            if (firstNonWhitespaceIndex != 0) {
                // All break offsets are relative to the renderLineContent, make them absolute again
                for (j in 0...breakOffsets.length) {
                    breakOffsets[j] += firstNonWhitespaceIndex;
                }
            }

            var injectionOptions:Null<Array<InjectedTextOptions>>;
            var injectionOffsets:Null<Array<Int>>;
            final curInjectedTexts = injectedTextsPerLine[i];
            if (curInjectedTexts != null) {
                injectionOptions = [for (t in curInjectedTexts) t.options];
                injectionOffsets = [for (text in curInjectedTexts) text.column - 1];
            } else {
                injectionOptions = null;
                injectionOffsets = null;
            }

            result[i] = new ModelLineProjectionData(injectionOffsets, injectionOptions, breakOffsets, breakOffsetsVisibleColumn, wrappedTextIndentLength + additionalIndentSize);
        }
        return result;
    }

    /**
     * The visible columns of Monaco's `renderLine` (domLineBreaksComputer.ts).
     */
    static function computeVisibleColumns(lineContent:String, initialVisibleColumn:Int, tabSize:Int):Array<Int> {
        final len = lineContent.length;
        var visibleColumn = initialVisibleColumn;
        final visibleColumns:Array<Int> = [];
        for (charIndex in 0...len) {
            visibleColumns[charIndex] = visibleColumn;
            final charCode = StringTools.fastCodeAt(lineContent, charIndex);
            var charWidth = 1;
            if (charCode == CharCode.Tab) {
                charWidth = (tabSize - (visibleColumn % tabSize));
            } else if (Strings.isFullWidthCharacter(charCode)) {
                charWidth++;
            }
            visibleColumn += charWidth;
        }
        visibleColumns[len] = visibleColumn;
        return visibleColumns;
    }

    /**
     * The text laid out for measurement, like Monaco's `renderLine`: tabs as
     * spaces to the next tab stop, control characters as control pictures.
     * `textOffsets[i]` is where `lineContent` offset `i` starts in it.
     */
    static function renderText(lineContent:String, initialVisibleColumn:Int, tabSize:Int, textOffsets:Array<Int>):String {
        final sb = new StringBuf();
        var visibleColumn = initialVisibleColumn;
        var offset = 0;
        for (charIndex in 0...lineContent.length) {
            textOffsets[charIndex] = offset;
            final charCode = StringTools.fastCodeAt(lineContent, charIndex);
            switch (charCode) {
                case CharCode.Tab:
                    final produced = (tabSize - (visibleColumn % tabSize));
                    for (_ in 0...produced) {
                        sb.addChar(' '.code);
                    }
                    offset += produced;
                    visibleColumn += produced;
                case CharCode.Null | CharCode.UTF8_BOM | CharCode.LINE_SEPARATOR | CharCode.PARAGRAPH_SEPARATOR | CharCode.NEXT_LINE:
                    sb.addChar(0xFFFD);
                    offset++;
                    visibleColumn++;
                default:
                    if (charCode < 32) {
                        sb.addChar(9216 + charCode);
                    } else if (Strings.isHighSurrogate(charCode) && charIndex + 1 < lineContent.length) {
                        // the pair is added with its low surrogate
                        sb.addChar(Strings.getNextCodePoint(lineContent, lineContent.length, charIndex));
                        offset++;
                        visibleColumn++;
                        continue;
                    } else if (Strings.isLowSurrogate(charCode) && charIndex > 0 && Strings.isHighSurrogate(StringTools.fastCodeAt(lineContent, charIndex - 1))) {
                        // second unit of a pair, already added
                    } else {
                        sb.addChar(charCode);
                    }
                    offset++;
                    visibleColumn += Strings.isFullWidthCharacter(charCode) ? 2 : 1;
            }
        }
        textOffsets[lineContent.length] = offset;
        return sb.toString();
    }

    static inline function isIdeographic(c:Int):Bool {
        return (c >= 0x3040 && c <= 0x30FF) || (c >= 0x3400 && c <= 0x4DBF) || (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0xF900 && c <= 0xFAFF) || (c >= 0xAC00 && c <= 0xD7AF);
    }

    /**
     * Whether a line may break before `lineContent[i]` (0 < i < length).
     */
    static function canBreakBefore(lineContent:String, i:Int, keepAll:Bool):Bool {
        final c = StringTools.fastCodeAt(lineContent, i);
        final prev = StringTools.fastCodeAt(lineContent, i - 1);
        if (Strings.isLowSurrogate(c)) {
            return false;
        }
        if (c == CharCode.Space || c == CharCode.Tab) {
            return false;
        }
        if (prev == CharCode.Space || prev == CharCode.Tab) {
            return true;
        }
        if (prev == CharCode.Dash && !(c >= '0'.code && c <= '9'.code)) {
            return true;
        }
        if (!keepAll && (isIdeographic(c) || isIdeographic(prev))) {
            return true;
        }
        return false;
    }

    function readLineBreaks(lineContent:String, initialVisibleColumn:Int, tabSize:Int, width:Float, wrappingIndentLength:Float, keepAll:Bool):Null<Array<Int>> {
        if (lineContent.length <= 1) {
            return null;
        }
        final textOffsets:Array<Int> = [];
        final text = renderText(lineContent, initialVisibleColumn, tabSize, textOffsets);
        final xs = measurer.measure(text, fontInfo);
        inline function xAt(i:Int):Float {
            final o = textOffsets[i];
            return o < xs.length ? xs[o] : xs[xs.length - 1];
        }

        final len = lineContent.length;
        final breakOffsets:Array<Int> = [];
        var lineStart = 0;
        var available = width;
        while (lineStart < len) {
            final startX = xAt(lineStart);
            var lastOpportunity = -1;
            var breakAt = -1;
            var i = lineStart + 1;
            while (i <= len) {
                if (i < len && canBreakBefore(lineContent, i, keepAll)) {
                    lastOpportunity = i;
                }
                // the character before `i` ends at xAt(i); spaces hang
                final prevChar = StringTools.fastCodeAt(lineContent, i - 1);
                final hangs = (prevChar == CharCode.Space || prevChar == CharCode.Tab);
                if (!hangs && xAt(i) - startX > available + 0.01) {
                    // the character ending at `i` does not fit
                    if (lastOpportunity > lineStart) {
                        breakAt = lastOpportunity;
                    } else {
                        // break-word: the last grapheme that fits (at least one)
                        breakAt = i - 1;
                        if (breakAt > lineStart && Strings.isLowSurrogate(StringTools.fastCodeAt(lineContent, breakAt))) {
                            breakAt--;
                        }
                        if (breakAt <= lineStart) {
                            breakAt = i;
                            if (breakAt < len && Strings.isLowSurrogate(StringTools.fastCodeAt(lineContent, breakAt))) {
                                breakAt++;
                            }
                        }
                    }
                    break;
                }
                i++;
            }
            if (breakAt == -1 || breakAt >= len) {
                break;
            }
            breakOffsets.push(breakAt);
            lineStart = breakAt;
            available = width - wrappingIndentLength;
        }

        if (breakOffsets.length == 0) {
            return null;
        }

        breakOffsets.push(lineContent.length);
        return breakOffsets;
    }

}
