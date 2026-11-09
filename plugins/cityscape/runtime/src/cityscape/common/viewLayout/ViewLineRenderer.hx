// Ported from vscode src/vs/editor/common/viewLayout/viewLineRenderer.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.viewLayout;

import cityscape.base.common.CharCode;
import cityscape.base.common.Strings;
import cityscape.common.ViewModel.InlineDecorationType;
import cityscape.common.core.StringBuilder;
import cityscape.common.tokens.LineTokens.IViewLineTokens;
import cityscape.common.viewLayout.LineDecorations;
import cityscape.common.viewLayout.LinePart;

enum abstract RenderWhitespace(Int) from Int to Int {
    var None = 0;
    var Boundary = 1;
    var Selection = 2;
    var Trailing = 3;
    var All = 4;
}

class LineRange {

    /**
     * Zero-based offset on which the range starts, inclusive.
     */
    public final startOffset:Int;

    /**
     * Zero-based offset on which the range ends, inclusive.
     */
    public final endOffset:Int;

    public function new(startIndex:Int, endIndex:Int) {
        this.startOffset = startIndex;
        this.endOffset = endIndex;
    }

    public function equals(otherLineRange:LineRange):Bool {
        return this.startOffset == otherLineRange.startOffset
            && this.endOffset == otherLineRange.endOffset;
    }

}

class RenderLineInput {

    public final useMonospaceOptimizations:Bool;
    public final canUseHalfwidthRightwardsArrow:Bool;
    public final lineContent:String;
    public final continuesWithWrappedLine:Bool;
    public final isBasicASCII:Bool;
    public final containsRTL:Bool;
    public final fauxIndentLength:Int;
    public final lineTokens:IViewLineTokens;
    public final lineDecorations:Array<LineDecoration>;
    public final tabSize:Int;
    public final startVisibleColumn:Int;
    public final spaceWidth:Float;
    public final renderSpaceWidth:Float;
    public final renderSpaceCharCode:Int;
    public final stopRenderingLineAfter:Int;
    public final renderWhitespace:RenderWhitespace;
    public final renderControlCharacters:Bool;
    public final fontLigatures:Bool;

    /**
     * Defined only when renderWhitespace is 'selection'. Selections are non-overlapping,
     * and ordered by position within the line.
     */
    public final selectionsOnLine:Null<Array<LineRange>>;

    /**
     * @param renderWhitespace `'none'`, `'boundary'`, `'selection'`, `'trailing'` or `'all'`
     */
    public function new(useMonospaceOptimizations:Bool, canUseHalfwidthRightwardsArrow:Bool, lineContent:String, continuesWithWrappedLine:Bool, isBasicASCII:Bool, containsRTL:Bool, fauxIndentLength:Int, lineTokens:IViewLineTokens, lineDecorations:Array<LineDecoration>, tabSize:Int, startVisibleColumn:Int, spaceWidth:Float, middotWidth:Float, wsmiddotWidth:Float, stopRenderingLineAfter:Int, renderWhitespace:String, renderControlCharacters:Bool, fontLigatures:Bool, selectionsOnLine:Null<Array<LineRange>>) {
        this.useMonospaceOptimizations = useMonospaceOptimizations;
        this.canUseHalfwidthRightwardsArrow = canUseHalfwidthRightwardsArrow;
        this.lineContent = lineContent;
        this.continuesWithWrappedLine = continuesWithWrappedLine;
        this.isBasicASCII = isBasicASCII;
        this.containsRTL = containsRTL;
        this.fauxIndentLength = fauxIndentLength;
        this.lineTokens = lineTokens;
        haxe.ds.ArraySort.sort(lineDecorations, LineDecoration.compare);
        this.lineDecorations = lineDecorations;
        this.tabSize = tabSize;
        this.startVisibleColumn = startVisibleColumn;
        this.spaceWidth = spaceWidth;
        this.stopRenderingLineAfter = stopRenderingLineAfter;
        this.renderWhitespace = (
            renderWhitespace == 'all'
                ? RenderWhitespace.All
                : renderWhitespace == 'boundary'
                    ? RenderWhitespace.Boundary
                    : renderWhitespace == 'selection'
                        ? RenderWhitespace.Selection
                        : renderWhitespace == 'trailing'
                            ? RenderWhitespace.Trailing
                            : RenderWhitespace.None
        );
        this.renderControlCharacters = renderControlCharacters;
        this.fontLigatures = fontLigatures;
        if (selectionsOnLine != null) {
            haxe.ds.ArraySort.sort(selectionsOnLine, (a, b) -> a.startOffset < b.startOffset ? -1 : 1);
        }
        this.selectionsOnLine = selectionsOnLine;

        final wsmiddotDiff = Math.abs(wsmiddotWidth - spaceWidth);
        final middotDiff = Math.abs(middotWidth - spaceWidth);
        if (wsmiddotDiff < middotDiff) {
            this.renderSpaceWidth = wsmiddotWidth;
            this.renderSpaceCharCode = 0x2E31; // U+2E31 - WORD SEPARATOR MIDDLE DOT
        } else {
            this.renderSpaceWidth = middotWidth;
            this.renderSpaceCharCode = 0xB7; // U+00B7 - MIDDLE DOT
        }
    }

    function sameSelection(otherSelections:Null<Array<LineRange>>):Bool {
        if (this.selectionsOnLine == null) {
            return otherSelections == null;
        }

        if (otherSelections == null) {
            return false;
        }

        if (otherSelections.length != this.selectionsOnLine.length) {
            return false;
        }

        for (i in 0...this.selectionsOnLine.length) {
            if (!this.selectionsOnLine[i].equals(otherSelections[i])) {
                return false;
            }
        }

        return true;
    }

    public function equals(other:RenderLineInput):Bool {
        return (
            this.useMonospaceOptimizations == other.useMonospaceOptimizations
            && this.canUseHalfwidthRightwardsArrow == other.canUseHalfwidthRightwardsArrow
            && this.lineContent == other.lineContent
            && this.continuesWithWrappedLine == other.continuesWithWrappedLine
            && this.isBasicASCII == other.isBasicASCII
            && this.containsRTL == other.containsRTL
            && this.fauxIndentLength == other.fauxIndentLength
            && this.tabSize == other.tabSize
            && this.startVisibleColumn == other.startVisibleColumn
            && this.spaceWidth == other.spaceWidth
            && this.renderSpaceWidth == other.renderSpaceWidth
            && this.renderSpaceCharCode == other.renderSpaceCharCode
            && this.stopRenderingLineAfter == other.stopRenderingLineAfter
            && this.renderWhitespace == other.renderWhitespace
            && this.renderControlCharacters == other.renderControlCharacters
            && this.fontLigatures == other.fontLigatures
            && LineDecoration.equalsArr(this.lineDecorations, other.lineDecorations)
            && this.lineTokens.equals(other.lineTokens)
            && this.sameSelection(other.selectionsOnLine)
        );
    }

}

/**
 * Monaco packs the part index and the char index in one Uint32 (16 bits
 * each); two arrays here.
 */
class DomPosition {

    public final partIndex:Int;
    public final charIndex:Int;

    public function new(partIndex:Int, charIndex:Int) {
        this.partIndex = partIndex;
        this.charIndex = charIndex;
    }

}

/**
 * Provides a both direction mapping between a line's character and its rendered position.
 */
class CharacterMapping {

    @:allow(cityscape)
    static inline function getPartIndex(partData:Int):Int {
        return (partData >>> 16) & 0xFFFF;
    }

    @:allow(cityscape)
    static inline function getCharIndex(partData:Int):Int {
        return partData & 0xFFFF;
    }

    public final length:Int;
    final _data:Array<Int>;
    final _horizontalOffset:Array<Int>;

    public function new(length:Int, partCount:Int) {
        this.length = length;
        this._data = [for (_ in 0...length) 0];
        this._horizontalOffset = [for (_ in 0...length) 0];
    }

    public function setColumnInfo(column:Int, partIndex:Int, charIndex:Int, horizontalOffset:Int):Void {
        final partData = (((partIndex & 0xFFFF) << 16) | (charIndex & 0xFFFF));
        this._data[column - 1] = partData;
        this._horizontalOffset[column - 1] = horizontalOffset;
    }

    public function getHorizontalOffset(column:Int):Int {
        if (this._horizontalOffset.length == 0) {
            // No characters on this line
            return 0;
        }
        return this._horizontalOffset[column - 1];
    }

    function charOffsetToPartData(charOffset:Int):Int {
        if (this.length == 0) {
            return 0;
        }
        if (charOffset < 0) {
            return this._data[0];
        }
        if (charOffset >= this.length) {
            return this._data[this.length - 1];
        }
        return this._data[charOffset];
    }

    public function getDomPosition(column:Int):DomPosition {
        final partData = this.charOffsetToPartData(column - 1);
        final partIndex = CharacterMapping.getPartIndex(partData);
        final charIndex = CharacterMapping.getCharIndex(partData);
        return new DomPosition(partIndex, charIndex);
    }

    /**
     * Cityscape: `getDomPosition` packed in an Int (read with `getPartIndex`
     * and `getCharIndex`), without allocating.
     */
    public function getDomPartData(column:Int):Int {
        return this.charOffsetToPartData(column - 1);
    }

    public function getColumn(domPosition:DomPosition, partLength:Int):Int {
        final charOffset = this.partDataToCharOffset(domPosition.partIndex, partLength, domPosition.charIndex);
        return charOffset + 1;
    }

    /**
     * Compares packed entries as unsigned 32 bit numbers, like Monaco's
     * Uint32Array.
     */
    static inline function unsignedCompare(a:Int, b:Int):Int {
        final ua = a + (a < 0 ? 4294967296.0 : 0.0);
        final ub = b + (b < 0 ? 4294967296.0 : 0.0);
        return ua < ub ? -1 : (ua > ub ? 1 : 0);
    }

    function partDataToCharOffset(partIndex:Int, partLength:Int, charIndex:Int):Int {
        if (this.length == 0) {
            return 0;
        }

        final searchEntry = (((partIndex & 0xFFFF) << 16) | (charIndex & 0xFFFF));

        var min = 0;
        var max = this.length - 1;
        while (min + 1 < max) {
            final mid = ((min + max) >>> 1);
            final midEntry = this._data[mid];
            if (midEntry == searchEntry) {
                return mid;
            } else if (unsignedCompare(midEntry, searchEntry) > 0) {
                max = mid;
            } else {
                min = mid;
            }
        }

        if (min == max) {
            return min;
        }

        final minEntry = this._data[min];
        final maxEntry = this._data[max];

        if (minEntry == searchEntry) {
            return min;
        }
        if (maxEntry == searchEntry) {
            return max;
        }

        final minPartIndex = CharacterMapping.getPartIndex(minEntry);
        final minCharIndex = CharacterMapping.getCharIndex(minEntry);

        final maxPartIndex = CharacterMapping.getPartIndex(maxEntry);
        var maxCharIndex:Int;

        if (minPartIndex != maxPartIndex) {
            // sitting between parts
            maxCharIndex = partLength;
        } else {
            maxCharIndex = CharacterMapping.getCharIndex(maxEntry);
        }

        final minEntryDistance = charIndex - minCharIndex;
        final maxEntryDistance = maxCharIndex - charIndex;

        if (minEntryDistance <= maxEntryDistance) {
            return min;
        }
        return max;
    }

    public function inflate():Array<Array<Int>> {
        final result:Array<Array<Int>> = [];
        for (i in 0...this.length) {
            final partData = this._data[i];
            final partIndex = CharacterMapping.getPartIndex(partData);
            final charIndex = CharacterMapping.getCharIndex(partData);
            final visibleColumn = this._horizontalOffset[i];
            result.push([partIndex, charIndex, visibleColumn]);
        }
        return result;
    }

}

enum abstract ForeignElementType(Int) from Int to Int {
    var None = 0;
    var Before = 1;
    var After = 2;
}

class RenderLineOutput {

    public final characterMapping:CharacterMapping;
    public final containsRTL:Bool;
    public final containsForeignElements:ForeignElementType;

    public function new(characterMapping:CharacterMapping, containsRTL:Bool, containsForeignElements:ForeignElementType) {
        this.characterMapping = characterMapping;
        this.containsRTL = containsRTL;
        this.containsForeignElements = containsForeignElements;
    }

}

class RenderLineOutput2 {

    public final characterMapping:CharacterMapping;
    public final html:String;
    public final containsRTL:Bool;
    public final containsForeignElements:ForeignElementType;

    public function new(characterMapping:CharacterMapping, html:String, containsRTL:Bool, containsForeignElements:ForeignElementType) {
        this.characterMapping = characterMapping;
        this.html = html;
        this.containsRTL = containsRTL;
        this.containsForeignElements = containsForeignElements;
    }

}

class ResolvedRenderLineInput {

    public final fontIsMonospace:Bool;
    public final canUseHalfwidthRightwardsArrow:Bool;
    public final lineContent:String;
    public final len:Int;
    public final isOverflowing:Bool;
    public final overflowingCharCount:Int;
    public final parts:Array<LinePart>;
    public final containsForeignElements:ForeignElementType;
    public final fauxIndentLength:Int;
    public final tabSize:Int;
    public final startVisibleColumn:Int;
    public final containsRTL:Bool;
    public final spaceWidth:Float;
    public final renderSpaceCharCode:Int;
    public final renderWhitespace:RenderWhitespace;
    public final renderControlCharacters:Bool;

    public function new(fontIsMonospace:Bool, canUseHalfwidthRightwardsArrow:Bool, lineContent:String, len:Int, isOverflowing:Bool, overflowingCharCount:Int, parts:Array<LinePart>, containsForeignElements:ForeignElementType, fauxIndentLength:Int, tabSize:Int, startVisibleColumn:Int, containsRTL:Bool, spaceWidth:Float, renderSpaceCharCode:Int, renderWhitespace:RenderWhitespace, renderControlCharacters:Bool) {
        this.fontIsMonospace = fontIsMonospace;
        this.canUseHalfwidthRightwardsArrow = canUseHalfwidthRightwardsArrow;
        this.lineContent = lineContent;
        this.len = len;
        this.isOverflowing = isOverflowing;
        this.overflowingCharCount = overflowingCharCount;
        this.parts = parts;
        this.containsForeignElements = containsForeignElements;
        this.fauxIndentLength = fauxIndentLength;
        this.tabSize = tabSize;
        this.startVisibleColumn = startVisibleColumn;
        this.containsRTL = containsRTL;
        this.spaceWidth = spaceWidth;
        this.renderSpaceCharCode = renderSpaceCharCode;
        this.renderWhitespace = renderWhitespace;
        this.renderControlCharacters = renderControlCharacters;
    }

}

/**
 * Where `_renderLine` writes a line (Cityscape): Monaco writes HTML spans;
 * the Glaze view writes runs of text (`cityscape.view.ViewLineRuns`). The
 * characters and their order are the same in both.
 */
interface IRenderLineSink {
    function beginLine(containsRTL:Bool):Void;
    /**
     * @param className The class names of the part, `mtkz` for whitespace rendered with a width
     * @param whitespaceWidth The width of a whitespace part rendered with a width, or -1
     */
    function beginPart(partIndex:Int, part:LinePart, className:String, partContainsRTL:Bool, whitespaceWidth:Float):Void;
    function appendCharCode(charCode:Int):Void;
    /**
     * A character that HTML escapes (`<`, `>`, `&`).
     */
    function appendEscapedCharCode(charCode:Int, html:String):Void;
    /**
     * The NUL character without `renderControlCharacters` (`&#00;` in HTML).
     */
    function appendNul():Void;
    /**
     * A control character shown as `[U+XXXX]`.
     */
    function appendString(text:String):Void;
    function endPart():Void;
    function appendOverflow(text:String):Void;
    function endLine():Void;
}

/**
 * The HTML output of Monaco (`StringBuilder`).
 */
class HtmlRenderLineSink implements IRenderLineSink {

    final sb:StringBuilder;

    public function new(sb:StringBuilder) {
        this.sb = sb;
    }

    public function beginLine(containsRTL:Bool):Void {
        if (containsRTL) {
            sb.appendString('<span dir="ltr">');
        } else {
            sb.appendString('<span>');
        }
    }

    public function beginPart(partIndex:Int, part:LinePart, className:String, partContainsRTL:Bool, whitespaceWidth:Float):Void {
        sb.appendString('<span ');
        if (partContainsRTL) {
            sb.appendString('style="unicode-bidi:isolate" ');
        }
        sb.appendString('class="');
        sb.appendString(className);
        sb.appendASCIICharCode(CharCode.DoubleQuote);
        if (whitespaceWidth >= 0) {
            sb.appendString(' style="width:');
            sb.appendString(ViewLineRenderer.jsNumberToString(whitespaceWidth));
            sb.appendString('px"');
        }
        sb.appendASCIICharCode(CharCode.GreaterThan);
    }

    public function appendCharCode(charCode:Int):Void {
        sb.appendCharCode(charCode);
    }

    public function appendEscapedCharCode(charCode:Int, html:String):Void {
        sb.appendString(html);
    }

    public function appendNul():Void {
        sb.appendString('&#00;');
    }

    public function appendString(text:String):Void {
        sb.appendString(text);
    }

    public function endPart():Void {
        sb.appendString('</span>');
    }

    public function appendOverflow(text:String):Void {
        sb.appendString('<span class="mtkoverflow">');
        sb.appendString(text);
        sb.appendString('</span>');
    }

    public function endLine():Void {
        sb.appendString('</span>');
    }

}

class ViewLineRenderer {

    /**
     * JavaScript's `String(n)` for the numbers of the renderer (integers and
     * simple decimals).
     */
    public static function jsNumberToString(n:Float):String {
        if (n == Math.ffloor(n) && Math.abs(n) < 1e15) {
            return Std.string(Std.int(n));
        }
        return Std.string(n);
    }

    public static function renderViewLine(input:RenderLineInput, sb:StringBuilder):RenderLineOutput {
        return renderViewLineTo(input, new HtmlRenderLineSink(sb));
    }

    /**
     * `renderViewLine` writing to any sink (Cityscape).
     */
    public static function renderViewLineTo(input:RenderLineInput, sink:IRenderLineSink):RenderLineOutput {
        if (input.lineContent.length == 0) {

            if (input.lineDecorations.length > 0) {
                // This line is empty, but it contains inline decorations
                sink.beginLine(false);

                var beforeCount = 0;
                var afterCount = 0;
                var containsForeignElements = ForeignElementType.None;
                for (lineDecoration in input.lineDecorations) {
                    if (lineDecoration.type == InlineDecorationType.Before || lineDecoration.type == InlineDecorationType.After) {
                        final part = new LinePart(0, lineDecoration.className, lineDecoration.type == InlineDecorationType.Before ? LinePartMetadata.PSEUDO_BEFORE : LinePartMetadata.PSEUDO_AFTER, false);
                        if (Std.isOfType(sink, HtmlRenderLineSink)) {
                            // Monaco: `<span class="..."></span>`
                            sink.appendString('<span class="' + lineDecoration.className + '"></span>');
                        } else {
                            sink.beginPart(beforeCount + afterCount, part, lineDecoration.className, false, -1);
                            sink.endPart();
                        }

                        if (lineDecoration.type == InlineDecorationType.Before) {
                            containsForeignElements |= ForeignElementType.Before;
                            beforeCount++;
                        }
                        if (lineDecoration.type == InlineDecorationType.After) {
                            containsForeignElements |= ForeignElementType.After;
                            afterCount++;
                        }
                    }
                }

                sink.endLine();

                final characterMapping = new CharacterMapping(1, beforeCount + afterCount);
                characterMapping.setColumnInfo(1, beforeCount, 0, 0);

                return new RenderLineOutput(
                    characterMapping,
                    false,
                    containsForeignElements
                );
            }

            // completely empty line
            if (Std.isOfType(sink, HtmlRenderLineSink)) {
                sink.appendString('<span><span></span></span>');
            } else {
                sink.beginLine(false);
                sink.endLine();
            }
            return new RenderLineOutput(
                new CharacterMapping(0, 0),
                false,
                ForeignElementType.None
            );
        }

        return _renderLine(resolveRenderLineInput(input), sink);
    }

    public static function renderViewLine2(input:RenderLineInput):RenderLineOutput2 {
        final sb = new StringBuilder(10000);
        final out = renderViewLine(input, sb);
        return new RenderLineOutput2(out.characterMapping, sb.build(), out.containsRTL, out.containsForeignElements);
    }

    public static function resolveRenderLineInput(input:RenderLineInput):ResolvedRenderLineInput {
        final lineContent = input.lineContent;

        var isOverflowing:Bool;
        var overflowingCharCount:Int;
        var len:Int;

        if (input.stopRenderingLineAfter != -1 && input.stopRenderingLineAfter < lineContent.length) {
            isOverflowing = true;
            overflowingCharCount = lineContent.length - input.stopRenderingLineAfter;
            len = input.stopRenderingLineAfter;
        } else {
            isOverflowing = false;
            overflowingCharCount = 0;
            len = lineContent.length;
        }

        var tokens = transformAndRemoveOverflowing(lineContent, input.containsRTL, input.lineTokens, input.fauxIndentLength, len);
        if (input.renderControlCharacters && !input.isBasicASCII) {
            // Calling `extractControlCharacters` before adding (possibly empty) line parts
            // for inline decorations. `extractControlCharacters` removes empty line parts.
            tokens = extractControlCharacters(lineContent, tokens);
        }
        if (input.renderWhitespace == RenderWhitespace.All ||
            input.renderWhitespace == RenderWhitespace.Boundary ||
            (input.renderWhitespace == RenderWhitespace.Selection && input.selectionsOnLine != null) ||
            (input.renderWhitespace == RenderWhitespace.Trailing && !input.continuesWithWrappedLine)
        ) {
            tokens = _applyRenderWhitespace(input, lineContent, len, tokens);
        }
        var containsForeignElements = ForeignElementType.None;
        if (input.lineDecorations.length > 0) {
            for (i in 0...input.lineDecorations.length) {
                final lineDecoration = input.lineDecorations[i];
                if (lineDecoration.type == InlineDecorationType.RegularAffectingLetterSpacing) {
                    // Pretend there are foreign elements... although not 100% accurate.
                    containsForeignElements |= ForeignElementType.Before;
                } else if (lineDecoration.type == InlineDecorationType.Before) {
                    containsForeignElements |= ForeignElementType.Before;
                } else if (lineDecoration.type == InlineDecorationType.After) {
                    containsForeignElements |= ForeignElementType.After;
                }
            }
            tokens = _applyInlineDecorations(lineContent, len, tokens, input.lineDecorations);
        }
        if (!input.containsRTL) {
            // We can never split RTL text, as it ruins the rendering
            tokens = splitLargeTokens(lineContent, tokens, !input.isBasicASCII || input.fontLigatures);
        }

        return new ResolvedRenderLineInput(
            input.useMonospaceOptimizations,
            input.canUseHalfwidthRightwardsArrow,
            lineContent,
            len,
            isOverflowing,
            overflowingCharCount,
            tokens,
            containsForeignElements,
            input.fauxIndentLength,
            input.tabSize,
            input.startVisibleColumn,
            input.containsRTL,
            input.spaceWidth,
            input.renderSpaceCharCode,
            input.renderWhitespace,
            input.renderControlCharacters
        );
    }

    /**
     * In the rendering phase, characters are always looped until token.endIndex.
     * Ensure that all tokens end before `len` and the last one ends precisely at `len`.
     */
    static function transformAndRemoveOverflowing(lineContent:String, lineContainsRTL:Bool, tokens:IViewLineTokens, fauxIndentLength:Int, len:Int):Array<LinePart> {
        final result:Array<LinePart> = [];

        // The faux indent part of the line should have no token type
        if (fauxIndentLength > 0) {
            result.push(new LinePart(fauxIndentLength, '', 0, false));
        }
        var startOffset = fauxIndentLength;
        for (tokenIndex in 0...tokens.getCount()) {
            final endIndex = tokens.getEndOffset(tokenIndex);
            if (endIndex <= fauxIndentLength) {
                // The faux indent part of the line should have no token type
                continue;
            }
            final type = tokens.getClassName(tokenIndex);
            if (endIndex >= len) {
                final tokenContainsRTL = (lineContainsRTL ? Strings.containsRTL(lineContent.substring(startOffset, len)) : false);
                result.push(new LinePart(len, type, 0, tokenContainsRTL));
                break;
            }
            final tokenContainsRTL = (lineContainsRTL ? Strings.containsRTL(lineContent.substring(startOffset, endIndex)) : false);
            result.push(new LinePart(endIndex, type, 0, tokenContainsRTL));
            startOffset = endIndex;
        }

        return result;
    }

    static inline final LongToken = 50;

    /**
     * See https://github.com/microsoft/vscode/issues/6885.
     * It appears that having very large spans causes very slow reading of character positions.
     * So here we try to avoid that.
     */
    static function splitLargeTokens(lineContent:String, tokens:Array<LinePart>, onlyAtSpaces:Bool):Array<LinePart> {
        var lastTokenEndIndex = 0;
        final result:Array<LinePart> = [];

        if (onlyAtSpaces) {
            // Split only at spaces => we need to walk each character
            for (i in 0...tokens.length) {
                final token = tokens[i];
                final tokenEndIndex = token.endIndex;
                if (lastTokenEndIndex + LongToken < tokenEndIndex) {
                    final tokenType = token.type;
                    final tokenMetadata = token.metadata;
                    final tokenContainsRTL = token.containsRTL;

                    var lastSpaceOffset = -1;
                    var currTokenStart = lastTokenEndIndex;
                    for (j in lastTokenEndIndex...tokenEndIndex) {
                        if (StringTools.fastCodeAt(lineContent, j) == CharCode.Space) {
                            lastSpaceOffset = j;
                        }
                        if (lastSpaceOffset != -1 && j - currTokenStart >= LongToken) {
                            // Split at `lastSpaceOffset` + 1
                            result.push(new LinePart(lastSpaceOffset + 1, tokenType, tokenMetadata, tokenContainsRTL));
                            currTokenStart = lastSpaceOffset + 1;
                            lastSpaceOffset = -1;
                        }
                    }
                    if (currTokenStart != tokenEndIndex) {
                        result.push(new LinePart(tokenEndIndex, tokenType, tokenMetadata, tokenContainsRTL));
                    }
                } else {
                    result.push(token);
                }

                lastTokenEndIndex = tokenEndIndex;
            }
        } else {
            // Split anywhere => we don't need to walk each character
            for (i in 0...tokens.length) {
                final token = tokens[i];
                final tokenEndIndex = token.endIndex;
                final diff = (tokenEndIndex - lastTokenEndIndex);
                if (diff > LongToken) {
                    final tokenType = token.type;
                    final tokenMetadata = token.metadata;
                    final tokenContainsRTL = token.containsRTL;
                    final piecesCount = Math.ceil(diff / LongToken);
                    for (j in 1...piecesCount) {
                        final pieceEndIndex = lastTokenEndIndex + (j * LongToken);
                        result.push(new LinePart(pieceEndIndex, tokenType, tokenMetadata, tokenContainsRTL));
                    }
                    result.push(new LinePart(tokenEndIndex, tokenType, tokenMetadata, tokenContainsRTL));
                } else {
                    result.push(token);
                }
                lastTokenEndIndex = tokenEndIndex;
            }
        }

        return result;
    }

    public static function isControlCharacter(charCode:Int):Bool {
        if (charCode < 32) {
            return (charCode != CharCode.Tab);
        }
        if (charCode == 127) {
            // DEL
            return true;
        }

        if (
            (charCode >= 0x202A && charCode <= 0x202E)
            || (charCode >= 0x2066 && charCode <= 0x2069)
            || (charCode >= 0x200E && charCode <= 0x200F)
            || charCode == 0x061C
        ) {
            // Unicode Directional Formatting Characters
            return true;
        }

        return false;
    }

    static function extractControlCharacters(lineContent:String, tokens:Array<LinePart>):Array<LinePart> {
        final result:Array<LinePart> = [];
        var lastLinePart = new LinePart(0, '', 0, false);
        var charOffset = 0;
        for (token in tokens) {
            final tokenEndIndex = token.endIndex;
            while (charOffset < tokenEndIndex) {
                final charCode = StringTools.fastCodeAt(lineContent, charOffset);
                if (isControlCharacter(charCode)) {
                    if (charOffset > lastLinePart.endIndex) {
                        // emit previous part if it has text
                        lastLinePart = new LinePart(charOffset, token.type, token.metadata, token.containsRTL);
                        result.push(lastLinePart);
                    }
                    lastLinePart = new LinePart(charOffset + 1, 'mtkcontrol', token.metadata, false);
                    result.push(lastLinePart);
                }
                charOffset++;
            }
            if (charOffset > lastLinePart.endIndex) {
                // emit previous part if it has text
                lastLinePart = new LinePart(tokenEndIndex, token.type, token.metadata, token.containsRTL);
                result.push(lastLinePart);
            }
        }
        return result;
    }

    /**
     * Whitespace is rendered by "replacing" tokens with a special-purpose `mtkw` type that is later recognized in the rendering phase.
     * Moreover, a token is created for every visual indent because on some fonts the glyphs used for rendering whitespace (&rarr; or &middot;) do not have the same width as &nbsp;.
     * The rendering phase will generate `style="width:..."` for these tokens.
     */
    static function _applyRenderWhitespace(input:RenderLineInput, lineContent:String, len:Int, tokens:Array<LinePart>):Array<LinePart> {

        final continuesWithWrappedLine = input.continuesWithWrappedLine;
        final fauxIndentLength = input.fauxIndentLength;
        final tabSize = input.tabSize;
        final startVisibleColumn = input.startVisibleColumn;
        final useMonospaceOptimizations = input.useMonospaceOptimizations;
        final selections = input.selectionsOnLine;
        final onlyBoundary = (input.renderWhitespace == RenderWhitespace.Boundary);
        final onlyTrailing = (input.renderWhitespace == RenderWhitespace.Trailing);
        final generateLinePartForEachWhitespace = (input.renderSpaceWidth != input.spaceWidth);

        final result:Array<LinePart> = [];
        var tokenIndex = 0;
        var tokenType = tokens[tokenIndex].type;
        var tokenContainsRTL = tokens[tokenIndex].containsRTL;
        var tokenEndIndex = tokens[tokenIndex].endIndex;
        final tokensLength = tokens.length;

        var lineIsEmptyOrWhitespace = false;
        var firstNonWhitespaceIndex = Strings.firstNonWhitespaceIndex(lineContent);
        var lastNonWhitespaceIndex:Int;
        if (firstNonWhitespaceIndex == -1) {
            lineIsEmptyOrWhitespace = true;
            firstNonWhitespaceIndex = len;
            lastNonWhitespaceIndex = len;
        } else {
            lastNonWhitespaceIndex = Strings.lastNonWhitespaceIndex(lineContent);
        }

        var wasInWhitespace = false;
        var currentSelectionIndex = 0;
        var currentSelection:Null<LineRange> = selections != null && selections.length > 0 ? selections[currentSelectionIndex] : null;
        var tmpIndent = startVisibleColumn % tabSize;
        for (charIndex in fauxIndentLength...len) {
            final chCode = StringTools.fastCodeAt(lineContent, charIndex);

            if (currentSelection != null && charIndex >= currentSelection.endOffset) {
                currentSelectionIndex++;
                currentSelection = selections != null && currentSelectionIndex < selections.length ? selections[currentSelectionIndex] : null;
            }

            var isInWhitespace:Bool;
            if (charIndex < firstNonWhitespaceIndex || charIndex > lastNonWhitespaceIndex) {
                // in leading or trailing whitespace
                isInWhitespace = true;
            } else if (chCode == CharCode.Tab) {
                // a tab character is rendered both in all and boundary cases
                isInWhitespace = true;
            } else if (chCode == CharCode.Space) {
                // hit a space character
                if (onlyBoundary) {
                    // rendering only boundary whitespace
                    if (wasInWhitespace) {
                        isInWhitespace = true;
                    } else {
                        final nextChCode = (charIndex + 1 < len ? StringTools.fastCodeAt(lineContent, charIndex + 1) : CharCode.Null);
                        isInWhitespace = (nextChCode == CharCode.Space || nextChCode == CharCode.Tab);
                    }
                } else {
                    isInWhitespace = true;
                }
            } else {
                isInWhitespace = false;
            }

            // If rendering whitespace on selection, check that the charIndex falls within a selection
            if (isInWhitespace && selections != null) {
                isInWhitespace = currentSelection != null && currentSelection.startOffset <= charIndex && currentSelection.endOffset > charIndex;
            }

            // If rendering only trailing whitespace, check that the charIndex points to trailing whitespace.
            if (isInWhitespace && onlyTrailing) {
                isInWhitespace = lineIsEmptyOrWhitespace || charIndex > lastNonWhitespaceIndex;
            }

            if (isInWhitespace && tokenContainsRTL) {
                // If the token contains RTL text, breaking it up into multiple line parts
                // to render whitespace might affect the browser's bidi layout.
                //
                // We render whitespace in such tokens only if the whitespace
                // is the leading or the trailing whitespace of the line,
                // which doesn't affect the browser's bidi layout.
                if (charIndex >= firstNonWhitespaceIndex && charIndex <= lastNonWhitespaceIndex) {
                    isInWhitespace = false;
                }
            }

            if (wasInWhitespace) {
                // was in whitespace token
                if (!isInWhitespace || (!useMonospaceOptimizations && tmpIndent >= tabSize)) {
                    // leaving whitespace token or entering a new indent
                    if (generateLinePartForEachWhitespace) {
                        final lastEndIndex = (result.length > 0 ? result[result.length - 1].endIndex : fauxIndentLength);
                        for (i in lastEndIndex + 1...charIndex + 1) {
                            result.push(new LinePart(i, 'mtkw', LinePartMetadata.IS_WHITESPACE, false));
                        }
                    } else {
                        result.push(new LinePart(charIndex, 'mtkw', LinePartMetadata.IS_WHITESPACE, false));
                    }
                    tmpIndent = tmpIndent % tabSize;
                }
            } else {
                // was in regular token
                if (charIndex == tokenEndIndex || (isInWhitespace && charIndex > fauxIndentLength)) {
                    result.push(new LinePart(charIndex, tokenType, 0, tokenContainsRTL));
                    tmpIndent = tmpIndent % tabSize;
                }
            }

            if (chCode == CharCode.Tab) {
                tmpIndent = tabSize;
            } else if (Strings.isFullWidthCharacter(chCode)) {
                tmpIndent += 2;
            } else {
                tmpIndent++;
            }

            wasInWhitespace = isInWhitespace;

            while (charIndex == tokenEndIndex) {
                tokenIndex++;
                if (tokenIndex < tokensLength) {
                    tokenType = tokens[tokenIndex].type;
                    tokenContainsRTL = tokens[tokenIndex].containsRTL;
                    tokenEndIndex = tokens[tokenIndex].endIndex;
                } else {
                    break;
                }
            }
        }

        var generateWhitespace = false;
        if (wasInWhitespace) {
            // was in whitespace token
            if (continuesWithWrappedLine && onlyBoundary) {
                final lastCharCode = (len > 0 ? StringTools.fastCodeAt(lineContent, len - 1) : CharCode.Null);
                final prevCharCode = (len > 1 ? StringTools.fastCodeAt(lineContent, len - 2) : CharCode.Null);
                final isSingleTrailingSpace = (lastCharCode == CharCode.Space && (prevCharCode != CharCode.Space && prevCharCode != CharCode.Tab));
                if (!isSingleTrailingSpace) {
                    generateWhitespace = true;
                }
            } else {
                generateWhitespace = true;
            }
        }

        if (generateWhitespace) {
            if (generateLinePartForEachWhitespace) {
                final lastEndIndex = (result.length > 0 ? result[result.length - 1].endIndex : fauxIndentLength);
                for (i in lastEndIndex + 1...len + 1) {
                    result.push(new LinePart(i, 'mtkw', LinePartMetadata.IS_WHITESPACE, false));
                }
            } else {
                result.push(new LinePart(len, 'mtkw', LinePartMetadata.IS_WHITESPACE, false));
            }
        } else {
            result.push(new LinePart(len, tokenType, 0, tokenContainsRTL));
        }

        return result;
    }

    /**
     * Inline decorations are "merged" on top of tokens.
     * Special care must be taken when multiple inline decorations are at play and they overlap.
     */
    static function _applyInlineDecorations(lineContent:String, len:Int, tokens:Array<LinePart>, _lineDecorations:Array<LineDecoration>):Array<LinePart> {
        haxe.ds.ArraySort.sort(_lineDecorations, LineDecoration.compare);
        final lineDecorations = LineDecorationsNormalizer.normalize(lineContent, _lineDecorations);
        final lineDecorationsLen = lineDecorations.length;

        var lineDecorationIndex = 0;
        final result:Array<LinePart> = [];
        var lastResultEndIndex = 0;
        for (tokenIndex in 0...tokens.length) {
            final token = tokens[tokenIndex];
            final tokenEndIndex = token.endIndex;
            final tokenType = token.type;
            final tokenMetadata = token.metadata;
            final tokenContainsRTL = token.containsRTL;

            while (lineDecorationIndex < lineDecorationsLen && lineDecorations[lineDecorationIndex].startOffset < tokenEndIndex) {
                final lineDecoration = lineDecorations[lineDecorationIndex];

                if (lineDecoration.startOffset > lastResultEndIndex) {
                    lastResultEndIndex = lineDecoration.startOffset;
                    result.push(new LinePart(lastResultEndIndex, tokenType, tokenMetadata, tokenContainsRTL));
                }

                if (lineDecoration.endOffset + 1 <= tokenEndIndex) {
                    // This line decoration ends before this token ends
                    lastResultEndIndex = lineDecoration.endOffset + 1;
                    result.push(new LinePart(lastResultEndIndex, tokenType + ' ' + lineDecoration.className, tokenMetadata | lineDecoration.metadata, tokenContainsRTL));
                    lineDecorationIndex++;
                } else {
                    // This line decoration continues on to the next token
                    lastResultEndIndex = tokenEndIndex;
                    result.push(new LinePart(lastResultEndIndex, tokenType + ' ' + lineDecoration.className, tokenMetadata | lineDecoration.metadata, tokenContainsRTL));
                    break;
                }
            }

            if (tokenEndIndex > lastResultEndIndex) {
                lastResultEndIndex = tokenEndIndex;
                result.push(new LinePart(lastResultEndIndex, tokenType, tokenMetadata, tokenContainsRTL));
            }
        }

        final lastTokenEndIndex = tokens[tokens.length - 1].endIndex;
        if (lineDecorationIndex < lineDecorationsLen && lineDecorations[lineDecorationIndex].startOffset == lastTokenEndIndex) {
            while (lineDecorationIndex < lineDecorationsLen && lineDecorations[lineDecorationIndex].startOffset == lastTokenEndIndex) {
                final lineDecoration = lineDecorations[lineDecorationIndex];
                result.push(new LinePart(lastResultEndIndex, lineDecoration.className, lineDecoration.metadata, false));
                lineDecorationIndex++;
            }
        }

        return result;
    }

    /**
     * This function is on purpose not split up into multiple functions to allow runtime type inference (i.e. performance reasons).
     * Notice how all the needed data is fully resolved and passed in (i.e. no other calls).
     */
    public static function _renderLine(input:ResolvedRenderLineInput, sink:IRenderLineSink):RenderLineOutput {
        final fontIsMonospace = input.fontIsMonospace;
        final canUseHalfwidthRightwardsArrow = input.canUseHalfwidthRightwardsArrow;
        final containsForeignElements = input.containsForeignElements;
        final lineContent = input.lineContent;
        final len = input.len;
        final isOverflowing = input.isOverflowing;
        final overflowingCharCount = input.overflowingCharCount;
        final parts = input.parts;
        final fauxIndentLength = input.fauxIndentLength;
        final tabSize = input.tabSize;
        final startVisibleColumn = input.startVisibleColumn;
        final containsRTL = input.containsRTL;
        final spaceWidth = input.spaceWidth;
        final renderSpaceCharCode = input.renderSpaceCharCode;
        final renderWhitespace = input.renderWhitespace;
        final renderControlCharacters = input.renderControlCharacters;

        final characterMapping = new CharacterMapping(len + 1, parts.length);
        var lastCharacterMappingDefined = false;

        var charIndex = 0;
        var visibleColumn = startVisibleColumn;
        var charOffsetInPart = 0; // the character offset in the current part
        var charHorizontalOffset = 0; // the character horizontal position in terms of chars relative to line start

        var partDisplacement = 0;

        sink.beginLine(containsRTL);

        for (partIndex in 0...parts.length) {

            final part = parts[partIndex];
            final partEndIndex = part.endIndex;
            final partType = part.type;
            final partContainsRTL = part.containsRTL;
            final partRendersWhitespace = (renderWhitespace != RenderWhitespace.None && part.isWhitespace());
            final partRendersWhitespaceWithWidth = partRendersWhitespace && !fontIsMonospace && (partType == 'mtkw'/*only whitespace*/ || containsForeignElements == ForeignElementType.None);
            final partIsEmptyAndHasPseudoAfter = (charIndex == partEndIndex && part.isPseudoAfter());
            charOffsetInPart = 0;

            if (partRendersWhitespace) {

                var partWidth = 0;
                {
                    var _charIndex = charIndex;
                    var _visibleColumn = visibleColumn;

                    while (_charIndex < partEndIndex) {
                        final charCode = StringTools.fastCodeAt(lineContent, _charIndex);
                        final charWidth = (charCode == CharCode.Tab ? (tabSize - (_visibleColumn % tabSize)) : 1);
                        partWidth += charWidth;
                        if (_charIndex >= fauxIndentLength) {
                            _visibleColumn += charWidth;
                        }
                        _charIndex++;
                    }
                }

                sink.beginPart(partIndex, part, partRendersWhitespaceWithWidth ? 'mtkz' : partType, partContainsRTL, partRendersWhitespaceWithWidth ? spaceWidth * partWidth : -1);

                while (charIndex < partEndIndex) {
                    characterMapping.setColumnInfo(charIndex + 1, partIndex - partDisplacement, charOffsetInPart, charHorizontalOffset);
                    partDisplacement = 0;
                    final charCode = StringTools.fastCodeAt(lineContent, charIndex);

                    var producedCharacters:Int;
                    var charWidth:Int;

                    if (charCode == CharCode.Tab) {
                        producedCharacters = (tabSize - (visibleColumn % tabSize));
                        charWidth = producedCharacters;

                        if (!canUseHalfwidthRightwardsArrow || charWidth > 1) {
                            sink.appendCharCode(0x2192); // RIGHTWARDS ARROW
                        } else {
                            sink.appendCharCode(0xFFEB); // HALFWIDTH RIGHTWARDS ARROW
                        }
                        for (space in 2...charWidth + 1) {
                            sink.appendCharCode(0xA0); // &nbsp;
                        }

                    } else { // must be CharCode.Space
                        producedCharacters = 2;
                        charWidth = 1;

                        sink.appendCharCode(renderSpaceCharCode); // &middot; or word separator middle dot
                        sink.appendCharCode(0x200C); // ZERO WIDTH NON-JOINER
                    }

                    charOffsetInPart += producedCharacters;
                    charHorizontalOffset += charWidth;
                    if (charIndex >= fauxIndentLength) {
                        visibleColumn += charWidth;
                    }
                    charIndex++;
                }

            } else {

                sink.beginPart(partIndex, part, partType, partContainsRTL, -1);

                while (charIndex < partEndIndex) {
                    characterMapping.setColumnInfo(charIndex + 1, partIndex - partDisplacement, charOffsetInPart, charHorizontalOffset);
                    partDisplacement = 0;
                    final charCode = StringTools.fastCodeAt(lineContent, charIndex);

                    var producedCharacters = 1;
                    var charWidth = 1;

                    switch (charCode) {
                        case CharCode.Tab:
                            producedCharacters = (tabSize - (visibleColumn % tabSize));
                            charWidth = producedCharacters;
                            for (space in 1...producedCharacters + 1) {
                                sink.appendCharCode(0xA0); // &nbsp;
                            }

                        case CharCode.Space:
                            sink.appendCharCode(0xA0); // &nbsp;

                        case CharCode.LessThan:
                            sink.appendEscapedCharCode(charCode, '&lt;');

                        case CharCode.GreaterThan:
                            sink.appendEscapedCharCode(charCode, '&gt;');

                        case CharCode.Ampersand:
                            sink.appendEscapedCharCode(charCode, '&amp;');

                        case CharCode.Null:
                            if (renderControlCharacters) {
                                // See https://unicode-table.com/en/blocks/control-pictures/
                                sink.appendCharCode(9216);
                            } else {
                                sink.appendNul();
                            }

                        case CharCode.UTF8_BOM | CharCode.LINE_SEPARATOR | CharCode.PARAGRAPH_SEPARATOR | CharCode.NEXT_LINE:
                            sink.appendCharCode(0xFFFD);

                        default:
                            if (Strings.isFullWidthCharacter(charCode)) {
                                charWidth++;
                            }
                            // See https://unicode-table.com/en/blocks/control-pictures/
                            if (renderControlCharacters && charCode < 32) {
                                sink.appendCharCode(9216 + charCode);
                            } else if (renderControlCharacters && charCode == 127) {
                                // DEL
                                sink.appendCharCode(9249);
                            } else if (renderControlCharacters && isControlCharacter(charCode)) {
                                sink.appendString('[U+');
                                sink.appendString(to4CharHex(charCode));
                                sink.appendString(']');
                                producedCharacters = 8;
                                charWidth = producedCharacters;
                            } else {
                                sink.appendCharCode(charCode);
                            }
                    }

                    charOffsetInPart += producedCharacters;
                    charHorizontalOffset += charWidth;
                    if (charIndex >= fauxIndentLength) {
                        visibleColumn += charWidth;
                    }
                    charIndex++;
                }
            }

            if (partIsEmptyAndHasPseudoAfter) {
                partDisplacement++;
            } else {
                partDisplacement = 0;
            }

            if (charIndex >= len && !lastCharacterMappingDefined && part.isPseudoAfter()) {
                lastCharacterMappingDefined = true;
                characterMapping.setColumnInfo(charIndex + 1, partIndex, charOffsetInPart, charHorizontalOffset);
            }

            sink.endPart();

        }

        if (!lastCharacterMappingDefined) {
            // When getting client rects for the last character, we will position the
            // text range at the end of the span, insteaf of at the beginning of next span
            characterMapping.setColumnInfo(len + 1, parts.length - 1, charOffsetInPart, charHorizontalOffset);
        }

        if (isOverflowing) {
            sink.appendOverflow('Show more (' + renderOverflowingCharCount(overflowingCharCount) + ')');
        }

        sink.endLine();

        return new RenderLineOutput(characterMapping, containsRTL, containsForeignElements);
    }

    static function to4CharHex(n:Int):String {
        return StringTools.hex(n, 4).toUpperCase();
    }

    static function renderOverflowingCharCount(n:Int):String {
        if (n < 1024) {
            return '$n chars';
        }
        if (n < 1024 * 1024) {
            return toFixed1(n / 1024) + ' KB';
        }
        return toFixed1(n / 1024 / 1024) + ' MB';
    }

    static function toFixed1(x:Float):String {
        final r = Math.round(x * 10);
        final whole = Std.int(r / 10);
        return '$whole.' + (r - whole * 10);
    }

}
