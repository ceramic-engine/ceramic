// Ported from vscode src/vs/editor/common/modelLineProjectionData.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.common.Model.InjectedTextCursorStops;
import cityscape.common.Model.InjectedTextOptions;
import cityscape.common.Model.PositionAffinity;
import cityscape.common.TextModelEvents.LineInjectedText;
import cityscape.common.config.EditorOptions.WrappingIndent;
import cityscape.common.config.FontInfo;
import cityscape.common.core.Position;

/**
 * *input*:
 * ```
 * xxxxxxxxxxxxxxxxxxxxxxxxxxx
 * ```
 *
 * -> Applying injections `[i...i]`, *inputWithInjections*:
 * ```
 * xxxxxx[iiiiiiiiii]xxxxxxxxxxxxxxxxx[ii]xxxx
 * ```
 *
 * -> breaking at offsets `|` in `xxxxxx[iiiiiii|iii]xxxxxxxxxxx|xxxxxx[ii]xxxx|`:
 * ```
 * xxxxxx[iiiiiii
 * iii]xxxxxxxxxxx
 * xxxxxx[ii]xxxx
 * ```
 *
 * -> applying wrappedTextIndentLength, *output*:
 * ```
 * xxxxxx[iiiiiii
 *    iii]xxxxxxxxxxx
 *    xxxxxx[ii]xxxx
 * ```
 *
 * Cityscape: an injection can also replace input text
 * (`InjectedTextOptions.replacedLength`, used for hidden ranges). Such an
 * injection removes `replacedLength` units of the input at its offset and
 * puts its content there; with `replacedLength = 0` (Monaco's only case)
 * every computation below is exactly Monaco's.
 */
class ModelLineProjectionData {

    public var injectionOffsets:Null<Array<Int>>;
    /**
     * `injectionOptions.length` must equal `injectionOffsets.length`
     */
    public var injectionOptions:Null<Array<InjectedTextOptions>>;
    /**
     * Refers to offsets after applying injections to the source.
     * The last break offset indicates the length of the source after applying injections.
     */
    public var breakOffsets:Array<Int>;
    /**
     * Refers to offsets after applying injections (visible columns can be
     * fractional: a full width character counts `typicalFullwidthCharacterWidth
     * / typicalHalfwidthCharacterWidth` columns)
     */
    public var breakOffsetsVisibleColumn:Array<Float>;
    public var wrappedTextIndentLength:Int;

    public function new(injectionOffsets:Null<Array<Int>>, injectionOptions:Null<Array<InjectedTextOptions>>, breakOffsets:Array<Int>, breakOffsetsVisibleColumn:Array<Float>, wrappedTextIndentLength:Int) {
        this.injectionOffsets = injectionOffsets;
        this.injectionOptions = injectionOptions;
        this.breakOffsets = breakOffsets;
        this.breakOffsetsVisibleColumn = breakOffsetsVisibleColumn;
        this.wrappedTextIndentLength = wrappedTextIndentLength;
    }

    /**
     * The number of input units replaced by an injection (Cityscape).
     */
    public static inline function replacedLengthOf(options:InjectedTextOptions):Int {
        final r:Null<Int> = options.replacedLength;
        return r == null ? 0 : r;
    }

    public function getOutputLineCount():Int {
        return this.breakOffsets.length;
    }

    public function getMinOutputOffset(outputLineIndex:Int):Int {
        if (outputLineIndex > 0) {
            return this.wrappedTextIndentLength;
        }
        return 0;
    }

    public function getLineLength(outputLineIndex:Int):Int {
        // These offsets refer to model text with injected text.
        final startOffset = outputLineIndex > 0 ? this.breakOffsets[outputLineIndex - 1] : 0;
        final endOffset = this.breakOffsets[outputLineIndex];

        var lineLength = endOffset - startOffset;
        if (outputLineIndex > 0) {
            lineLength += this.wrappedTextIndentLength;
        }
        return lineLength;
    }

    public function getMaxOutputOffset(outputLineIndex:Int):Int {
        return this.getLineLength(outputLineIndex);
    }

    public function translateToInputOffset(outputLineIndex:Int, outputOffset:Int):Int {
        if (outputLineIndex > 0) {
            outputOffset = outputOffset - this.wrappedTextIndentLength;
            if (outputOffset < 0) {
                outputOffset = 0;
            }
        }

        final offsetInInputWithInjection = outputLineIndex == 0 ? outputOffset : this.breakOffsets[outputLineIndex - 1] + outputOffset;
        var offsetInInput = offsetInInputWithInjection;

        final injectionOffsets = this.injectionOffsets;
        if (injectionOffsets != null) {
            final injectionOptions = this.injectionOptions;
            for (i in 0...injectionOffsets.length) {
                if (offsetInInput > injectionOffsets[i]) {
                    if (offsetInInput < injectionOffsets[i] + injectionOptions[i].content.length) {
                        // `inputOffset` is within injected text
                        offsetInInput = injectionOffsets[i];
                    } else {
                        offsetInInput -= injectionOptions[i].content.length - replacedLengthOf(injectionOptions[i]);
                    }
                } else {
                    break;
                }
            }
        }

        return offsetInInput;
    }

    public function translateToOutputPosition(inputOffset:Int, affinity:PositionAffinity = PositionAffinity.None):OutputPosition {
        var inputOffsetInInputWithInjection = inputOffset;
        final injectionOffsets = this.injectionOffsets;
        if (injectionOffsets != null) {
            final injectionOptions = this.injectionOptions;
            for (i in 0...injectionOffsets.length) {
                if (inputOffset < injectionOffsets[i]) {
                    break;
                }

                if (affinity != PositionAffinity.Right && inputOffset == injectionOffsets[i]) {
                    break;
                }

                final replaced = replacedLengthOf(injectionOptions[i]);
                if (replaced > 0 && inputOffset < injectionOffsets[i] + replaced) {
                    // Cityscape: inside replaced (hidden) text, the position goes to
                    // the end of the injection with a right affinity, else to its start
                    final injectionStart = inputOffsetInInputWithInjection - (inputOffset - injectionOffsets[i]);
                    inputOffsetInInputWithInjection = (affinity == PositionAffinity.Right ? injectionStart + injectionOptions[i].content.length : injectionStart);
                    return this.offsetInInputWithInjectionsToOutputPosition(inputOffsetInInputWithInjection, affinity);
                }

                inputOffsetInInputWithInjection += injectionOptions[i].content.length - replaced;
            }
        }

        return this.offsetInInputWithInjectionsToOutputPosition(inputOffsetInInputWithInjection, affinity);
    }

    function offsetInInputWithInjectionsToOutputPosition(offsetInInputWithInjections:Int, affinity:PositionAffinity = PositionAffinity.None):OutputPosition {
        var low = 0;
        var high = this.breakOffsets.length - 1;
        var mid = 0;
        var midStart = 0;

        while (low <= high) {
            mid = low + ((high - low) >> 1);

            final midStop = this.breakOffsets[mid];
            midStart = mid > 0 ? this.breakOffsets[mid - 1] : 0;

            if (affinity == PositionAffinity.Left) {
                if (offsetInInputWithInjections <= midStart) {
                    high = mid - 1;
                } else if (offsetInInputWithInjections > midStop) {
                    low = mid + 1;
                } else {
                    break;
                }
            } else {
                if (offsetInInputWithInjections < midStart) {
                    high = mid - 1;
                } else if (offsetInInputWithInjections >= midStop) {
                    low = mid + 1;
                } else {
                    break;
                }
            }
        }

        var outputOffset = offsetInInputWithInjections - midStart;
        if (mid > 0) {
            outputOffset += this.wrappedTextIndentLength;
        }

        return new OutputPosition(mid, outputOffset);
    }

    public function normalizeOutputPosition(outputLineIndex:Int, outputOffset:Int, affinity:PositionAffinity):OutputPosition {
        if (this.injectionOffsets != null) {
            final offsetInInputWithInjections = this.outputPositionToOffsetInInputWithInjections(outputLineIndex, outputOffset);
            final normalizedOffsetInUnwrappedLine = this.normalizeOffsetInInputWithInjectionsAroundInjections(offsetInInputWithInjections, affinity);
            if (normalizedOffsetInUnwrappedLine != offsetInInputWithInjections) {
                // injected text caused a change
                return this.offsetInInputWithInjectionsToOutputPosition(normalizedOffsetInUnwrappedLine, affinity);
            }
        }

        if (affinity == PositionAffinity.Left) {
            if (outputLineIndex > 0 && outputOffset == this.getMinOutputOffset(outputLineIndex)) {
                return new OutputPosition(outputLineIndex - 1, this.getMaxOutputOffset(outputLineIndex - 1));
            }
        }
        else if (affinity == PositionAffinity.Right) {
            final maxOutputLineIndex = this.getOutputLineCount() - 1;
            if (outputLineIndex < maxOutputLineIndex && outputOffset == this.getMaxOutputOffset(outputLineIndex)) {
                return new OutputPosition(outputLineIndex + 1, this.getMinOutputOffset(outputLineIndex + 1));
            }
        }

        return new OutputPosition(outputLineIndex, outputOffset);
    }

    function outputPositionToOffsetInInputWithInjections(outputLineIndex:Int, outputOffset:Int):Int {
        if (outputLineIndex > 0) {
            outputOffset = outputOffset - this.wrappedTextIndentLength;
            if (outputOffset < 0) {
                outputOffset = 0;
            }
        }
        final result = (outputLineIndex > 0 ? this.breakOffsets[outputLineIndex - 1] : 0) + outputOffset;
        return result;
    }

    function normalizeOffsetInInputWithInjectionsAroundInjections(offsetInInputWithInjections:Int, affinity:PositionAffinity):Int {
        final injectedText = this.getInjectedTextAtOffset(offsetInInputWithInjections);
        if (injectedText == null) {
            return offsetInInputWithInjections;
        }
        final injectionOffsets = this.injectionOffsets;
        final injectionOptions = this.injectionOptions;

        if (affinity == PositionAffinity.None) {
            if (offsetInInputWithInjections == injectedText.offsetInInputWithInjections + injectedText.length
                && hasRightCursorStop(injectionOptions[injectedText.injectedTextIndex].cursorStops)) {
                return injectedText.offsetInInputWithInjections + injectedText.length;
            } else {
                var result = injectedText.offsetInInputWithInjections;
                if (hasLeftCursorStop(injectionOptions[injectedText.injectedTextIndex].cursorStops)) {
                    return result;
                }

                var index = injectedText.injectedTextIndex - 1;
                while (index >= 0 && injectionOffsets[index] == injectionOffsets[injectedText.injectedTextIndex]) {
                    if (hasRightCursorStop(injectionOptions[index].cursorStops)) {
                        break;
                    }
                    result -= injectionOptions[index].content.length;
                    if (hasLeftCursorStop(injectionOptions[index].cursorStops)) {
                        break;
                    }
                    index--;
                }

                return result;
            }
        } else if (affinity == PositionAffinity.Right || affinity == PositionAffinity.RightOfInjectedText) {
            var result = injectedText.offsetInInputWithInjections + injectedText.length;
            var index = injectedText.injectedTextIndex;
            // traverse all injected text that touch each other
            while (index + 1 < injectionOffsets.length && injectionOffsets[index + 1] == injectionOffsets[index]) {
                result += injectionOptions[index + 1].content.length;
                index++;
            }
            return result;
        } else {
            // affinity is left
            var result = injectedText.offsetInInputWithInjections;
            var index = injectedText.injectedTextIndex;
            // traverse all injected text that touch each other
            while (index - 1 >= 0 && injectionOffsets[index - 1] == injectionOffsets[index]) {
                result -= injectionOptions[index - 1].content.length;
                index--;
            }
            return result;
        }
    }

    public function getInjectedText(outputLineIndex:Int, outputOffset:Int):Null<InjectedText> {
        final offset = this.outputPositionToOffsetInInputWithInjections(outputLineIndex, outputOffset);
        final injectedText = this.getInjectedTextAtOffset(offset);
        if (injectedText == null) {
            return null;
        }
        return new InjectedText(this.injectionOptions[injectedText.injectedTextIndex]);
    }

    function getInjectedTextAtOffset(offsetInInputWithInjections:Int):Null<{injectedTextIndex:Int, offsetInInputWithInjections:Int, length:Int}> {
        final injectionOffsets = this.injectionOffsets;
        final injectionOptions = this.injectionOptions;

        if (injectionOffsets != null) {
            var totalInjectedTextLengthBefore = 0;
            for (i in 0...injectionOffsets.length) {
                final length = injectionOptions[i].content.length;
                final injectedTextStartOffsetInInputWithInjections = injectionOffsets[i] + totalInjectedTextLengthBefore;
                final injectedTextEndOffsetInInputWithInjections = injectionOffsets[i] + totalInjectedTextLengthBefore + length;

                if (injectedTextStartOffsetInInputWithInjections > offsetInInputWithInjections) {
                    // Injected text starts later.
                    break; // All later injected texts have an even larger offset.
                }

                // Cityscape: an empty replacement (hidden text) is no injected text
                if (offsetInInputWithInjections <= injectedTextEndOffsetInInputWithInjections && length > 0) {
                    // Injected text ends after or with the given position (but also starts with or before it).
                    return {
                        injectedTextIndex: i,
                        offsetInInputWithInjections: injectedTextStartOffsetInInputWithInjections,
                        length: length
                    };
                }

                totalInjectedTextLengthBefore += length - replacedLengthOf(injectionOptions[i]);
            }
        }

        return null;
    }

    static function hasRightCursorStop(cursorStop:Null<InjectedTextCursorStops>):Bool {
        if (cursorStop == null) {
            return true;
        }
        return cursorStop == InjectedTextCursorStops.Right || cursorStop == InjectedTextCursorStops.Both;
    }

    static function hasLeftCursorStop(cursorStop:Null<InjectedTextCursorStops>):Bool {
        if (cursorStop == null) {
            return true;
        }
        return cursorStop == InjectedTextCursorStops.Left || cursorStop == InjectedTextCursorStops.Both;
    }

}

class InjectedText {

    public final options:InjectedTextOptions;

    public function new(options:InjectedTextOptions) {
        this.options = options;
    }

}

class OutputPosition {

    public var outputLineIndex:Int;
    public var outputOffset:Int;

    public function new(outputLineIndex:Int, outputOffset:Int) {
        this.outputLineIndex = outputLineIndex;
        this.outputOffset = outputOffset;
    }

    public function toString():String {
        return '${this.outputLineIndex}:${this.outputOffset}';
    }

    public function toPosition(baseLineNumber:Int):Position {
        return new Position(baseLineNumber + this.outputLineIndex, this.outputOffset + 1);
    }

}

interface ILineBreaksComputerFactory {
    /**
     * `wrappingIndentColumns` is Cityscape's option of loreline-monaco's
     * `[loreline]` patch: when 0 or more, the extra indent of wrapped lines
     * (`wrappingIndent` `indent` or `deepIndent`) is that many columns per
     * level instead of a tab stop. -1 keeps Monaco's behaviour.
     */
    function createLineBreaksComputer(fontInfo:FontInfo, tabSize:Int, wrappingColumn:Int, wrappingIndent:WrappingIndent, wordBreak:String, wrappingIndentColumns:Int):ILineBreaksComputer;
}

interface ILineBreaksComputer {
    /**
     * Pass in `previousLineBreakData` if the only difference is in breaking columns!!!
     */
    function addRequest(lineText:String, injectedText:Null<Array<LineInjectedText>>, previousLineBreakData:Null<ModelLineProjectionData>):Void;
    function finalize():Array<Null<ModelLineProjectionData>>;
}
