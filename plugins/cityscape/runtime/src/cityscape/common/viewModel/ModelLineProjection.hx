// Ported from vscode src/vs/editor/common/viewModel/modelLineProjection.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.viewModel;

import cityscape.common.Model.EndOfLinePreference;
import cityscape.common.Model.InjectedTextOptions;
import cityscape.common.Model.PositionAffinity;
import cityscape.common.ModelLineProjectionData;
import cityscape.common.TextModelEvents.LineInjectedText;
import cityscape.common.ViewModel.SingleLineInlineDecoration;
import cityscape.common.ViewModel.ViewLineData;
import cityscape.common.core.Position;
import cityscape.common.core.Range.IRange;
import cityscape.common.tokens.LineTokens;
import haxe.ds.Vector;

interface IModelLineProjection {
    function isVisible():Bool;

    /**
     * This invalidates the current instance (potentially reuses and returns it again).
     */
    function setVisible(isVisible:Bool):IModelLineProjection;

    function getProjectionData():Null<ModelLineProjectionData>;
    function getViewLineCount():Int;
    function getViewLineContent(model:ISimpleModel, modelLineNumber:Int, outputLineIndex:Int):String;
    function getViewLineLength(model:ISimpleModel, modelLineNumber:Int, outputLineIndex:Int):Int;
    function getViewLineMinColumn(model:ISimpleModel, modelLineNumber:Int, outputLineIndex:Int):Int;
    function getViewLineMaxColumn(model:ISimpleModel, modelLineNumber:Int, outputLineIndex:Int):Int;
    function getViewLineData(model:ISimpleModel, modelLineNumber:Int, outputLineIndex:Int):ViewLineData;
    function getViewLinesData(model:ISimpleModel, modelLineNumber:Int, outputLineIdx:Int, lineCount:Int, globalStartIndex:Int, needed:Array<Bool>, result:Array<Null<ViewLineData>>):Void;

    function getModelColumnOfViewPosition(outputLineIndex:Int, outputColumn:Int):Int;
    function getViewPositionOfModelPosition(deltaLineNumber:Int, inputColumn:Int, ?affinity:PositionAffinity):Position;
    function getViewLineNumberOfModelPosition(deltaLineNumber:Int, inputColumn:Int):Int;
    function normalizePosition(outputLineIndex:Int, outputPosition:Position, affinity:PositionAffinity):Position;

    function getInjectedTextAt(outputLineIndex:Int, column:Int):Null<InjectedText>;
}

/**
 * What a projection reads from a model: an `ITextModel` (through
 * `TextModelSimpleModel`) or a test double.
 */
interface ISimpleModel {
    function getLineTokens(lineNumber:Int):LineTokens;
    function getLineContent(lineNumber:Int):String;
    function getLineLength(lineNumber:Int):Int;
    function getLineMinColumn(lineNumber:Int):Int;
    function getLineMaxColumn(lineNumber:Int):Int;
    function getValueInRange(range:IRange, ?eol:EndOfLinePreference):String;
}

/**
 * Monaco passes the `ITextModel` itself as an `ISimpleModel`
 * (`model.tokenization.getLineTokens`); this adapter does the same.
 */
class TextModelSimpleModel implements ISimpleModel {

    final model:cityscape.common.Model.ITextModel;

    public function new(model:cityscape.common.Model.ITextModel) {
        this.model = model;
    }

    public inline function getLineTokens(lineNumber:Int):LineTokens {
        return model.tokenization.getLineTokens(lineNumber);
    }

    public inline function getLineContent(lineNumber:Int):String {
        return model.getLineContent(lineNumber);
    }

    public inline function getLineLength(lineNumber:Int):Int {
        return model.getLineLength(lineNumber);
    }

    public inline function getLineMinColumn(lineNumber:Int):Int {
        return model.getLineMinColumn(lineNumber);
    }

    public inline function getLineMaxColumn(lineNumber:Int):Int {
        return model.getLineMaxColumn(lineNumber);
    }

    public inline function getValueInRange(range:IRange, ?eol:EndOfLinePreference):String {
        return model.getValueInRange(range, eol);
    }

}

class ModelLineProjections {

    public static function createModelLineProjection(lineBreakData:Null<ModelLineProjectionData>, isVisible:Bool):IModelLineProjection {
        if (lineBreakData == null) {
            // No mapping needed
            if (isVisible) {
                return IdentityModelLineProjection.INSTANCE;
            }
            return HiddenModelLineProjection.INSTANCE;
        } else {
            return new ModelLineProjection(lineBreakData, isVisible);
        }
    }

    static final _spaces:Array<String> = [''];

    public static function spaces(count:Int):String {
        if (count >= _spaces.length) {
            for (i in 1...count + 1) {
                _spaces[i] = _makeSpaces(i);
            }
        }
        return _spaces[count];
    }

    static function _makeSpaces(count:Int):String {
        return StringTools.lpad('', ' ', count);
    }

    /**
     * Cityscape: whether one of the injections replaces model text (hidden
     * ranges).
     */
    public static function hasReplacement(injectionOptions:Array<InjectedTextOptions>):Bool {
        for (o in injectionOptions) {
            if (ModelLineProjectionData.replacedLengthOf(o) > 0) {
                return true;
            }
        }
        return false;
    }

    /**
     * The tokens of a model line with its injections applied: Monaco's
     * `LineTokens.withInserted` when nothing is replaced, otherwise the
     * replaced ranges are cut out of the tokens first (Cityscape).
     */
    public static function tokensWithInjections(lineTokens:LineTokens, injectionOffsets:Array<Int>, injectionOptions:Array<InjectedTextOptions>):LineTokens {
        if (!hasReplacement(injectionOptions)) {
            return lineTokens.withInserted([for (idx in 0...injectionOffsets.length) {
                offset: injectionOffsets[idx],
                text: injectionOptions[idx].content,
                tokenMetadata: LineTokens.defaultTokenMetadata
            }]);
        }

        final text = lineTokens.getLineContent();
        final result = new StringBuf();
        var resultLength = 0;
        final newTokens:Array<Int> = [];
        final count = lineTokens.getCount();
        var tokenIndex = 0;
        var offset = 0;

        // Copies text [offset, end) with its token metadata
        inline function copyUntil(end:Int):Void {
            while (offset < end && tokenIndex < count) {
                final tokenEnd = lineTokens.getEndOffset(tokenIndex);
                if (tokenEnd <= offset) {
                    tokenIndex++;
                    continue;
                }
                final pieceEnd = (tokenEnd < end ? tokenEnd : end);
                result.add(text.substring(offset, pieceEnd));
                resultLength += pieceEnd - offset;
                newTokens.push(resultLength);
                newTokens.push(lineTokens.getMetadata(tokenIndex));
                offset = pieceEnd;
            }
        }

        for (idx in 0...injectionOffsets.length) {
            final injectionOffset = injectionOffsets[idx];
            final options = injectionOptions[idx];
            copyUntil(injectionOffset);
            if (options.content.length > 0) {
                result.add(options.content);
                resultLength += options.content.length;
                newTokens.push(resultLength);
                newTokens.push(LineTokens.defaultTokenMetadata);
            }
            final replaced = ModelLineProjectionData.replacedLengthOf(options);
            if (replaced > 0) {
                // skip the replaced text
                offset = injectionOffset + replaced;
                while (tokenIndex < count && lineTokens.getEndOffset(tokenIndex) <= offset) {
                    tokenIndex++;
                }
            }
        }
        copyUntil(text.length);

        if (newTokens.length == 0) {
            newTokens.push(0);
            newTokens.push(LineTokens.defaultTokenMetadata);
        }

        return new LineTokens(haxe.io.UInt32Array.fromArray(newTokens), result.toString(), lineTokens.languageIdCodec);
    }

}

/**
 * This projection is used to
 * * wrap model lines
 * * inject text
 */
class ModelLineProjection implements IModelLineProjection {

    final _projectionData:ModelLineProjectionData;
    var _isVisible:Bool;

    public function new(lineBreakData:ModelLineProjectionData, isVisible:Bool) {
        this._projectionData = lineBreakData;
        this._isVisible = isVisible;
    }

    public function isVisible():Bool {
        return this._isVisible;
    }

    public function setVisible(isVisible:Bool):IModelLineProjection {
        this._isVisible = isVisible;
        return this;
    }

    public function getProjectionData():Null<ModelLineProjectionData> {
        return this._projectionData;
    }

    public function getViewLineCount():Int {
        if (!this._isVisible) {
            return 0;
        }
        return this._projectionData.getOutputLineCount();
    }

    public function getViewLineContent(model:ISimpleModel, modelLineNumber:Int, outputLineIndex:Int):String {
        this._assertVisible();

        final startOffsetInInputWithInjections = outputLineIndex > 0 ? this._projectionData.breakOffsets[outputLineIndex - 1] : 0;
        final endOffsetInInputWithInjections = this._projectionData.breakOffsets[outputLineIndex];

        var r:String;
        final injectionOffsets = this._projectionData.injectionOffsets;
        if (injectionOffsets != null) {
            final injectedTexts = [for (idx in 0...injectionOffsets.length) new LineInjectedText(
                0,
                0,
                injectionOffsets[idx] + 1,
                this._projectionData.injectionOptions[idx],
                0
            )];
            final lineWithInjections = LineInjectedText.applyInjectedText(
                model.getLineContent(modelLineNumber),
                injectedTexts
            );
            r = lineWithInjections.substring(startOffsetInInputWithInjections, endOffsetInInputWithInjections);
        } else {
            r = model.getValueInRange({
                startLineNumber: modelLineNumber,
                startColumn: startOffsetInInputWithInjections + 1,
                endLineNumber: modelLineNumber,
                endColumn: endOffsetInInputWithInjections + 1
            });
        }

        if (outputLineIndex > 0) {
            r = ModelLineProjections.spaces(this._projectionData.wrappedTextIndentLength) + r;
        }

        return r;
    }

    public function getViewLineLength(model:ISimpleModel, modelLineNumber:Int, outputLineIndex:Int):Int {
        this._assertVisible();
        return this._projectionData.getLineLength(outputLineIndex);
    }

    public function getViewLineMinColumn(_model:ISimpleModel, _modelLineNumber:Int, outputLineIndex:Int):Int {
        this._assertVisible();
        return this._projectionData.getMinOutputOffset(outputLineIndex) + 1;
    }

    public function getViewLineMaxColumn(model:ISimpleModel, modelLineNumber:Int, outputLineIndex:Int):Int {
        this._assertVisible();
        return this._projectionData.getMaxOutputOffset(outputLineIndex) + 1;
    }

    /**
     * Try using {@link getViewLinesData} instead.
     */
    public function getViewLineData(model:ISimpleModel, modelLineNumber:Int, outputLineIndex:Int):ViewLineData {
        final arr = new Array<Null<ViewLineData>>();
        this.getViewLinesData(model, modelLineNumber, outputLineIndex, 1, 0, [true], arr);
        return arr[0];
    }

    public function getViewLinesData(model:ISimpleModel, modelLineNumber:Int, outputLineIdx:Int, lineCount:Int, globalStartIndex:Int, needed:Array<Bool>, result:Array<Null<ViewLineData>>):Void {
        this._assertVisible();

        final lineBreakData = this._projectionData;

        final injectionOffsets = lineBreakData.injectionOffsets;
        final injectionOptions = lineBreakData.injectionOptions;

        var inlineDecorationsPerOutputLine:Null<Array<Array<SingleLineInlineDecoration>>> = null;

        if (injectionOffsets != null) {
            inlineDecorationsPerOutputLine = [];
            var totalInjectedTextLengthBefore = 0;
            var currentInjectedOffset = 0;

            for (outputLineIndex in 0...lineBreakData.getOutputLineCount()) {
                final inlineDecorations = new Array<SingleLineInlineDecoration>();
                inlineDecorationsPerOutputLine[outputLineIndex] = inlineDecorations;

                final lineStartOffsetInInputWithInjections = outputLineIndex > 0 ? lineBreakData.breakOffsets[outputLineIndex - 1] : 0;
                final lineEndOffsetInInputWithInjections = lineBreakData.breakOffsets[outputLineIndex];

                while (currentInjectedOffset < injectionOffsets.length) {
                    final length = injectionOptions[currentInjectedOffset].content.length;
                    final injectedTextStartOffsetInInputWithInjections = injectionOffsets[currentInjectedOffset] + totalInjectedTextLengthBefore;
                    final injectedTextEndOffsetInInputWithInjections = injectedTextStartOffsetInInputWithInjections + length;

                    if (injectedTextStartOffsetInInputWithInjections > lineEndOffsetInInputWithInjections) {
                        // Injected text only starts in later wrapped lines.
                        break;
                    }

                    if (lineStartOffsetInInputWithInjections < injectedTextEndOffsetInInputWithInjections) {
                        // Injected text ends after or in this line (but also starts in or before this line).
                        final options = injectionOptions[currentInjectedOffset];
                        // Cityscape: injected text with a typed style is decorated too
                        if ((options.inlineClassName != null && options.inlineClassName != '') || options.inlineStyle != null) {
                            final offset = (outputLineIndex > 0 ? lineBreakData.wrappedTextIndentLength : 0);
                            final s = injectedTextStartOffsetInInputWithInjections - lineStartOffsetInInputWithInjections;
                            final start = offset + (s > 0 ? s : 0);
                            final e1 = injectedTextEndOffsetInInputWithInjections - lineStartOffsetInInputWithInjections;
                            final e2 = lineEndOffsetInInputWithInjections - lineStartOffsetInInputWithInjections;
                            final end = offset + (e1 < e2 ? e1 : e2);
                            if (start != end) {
                                inlineDecorations.push(new SingleLineInlineDecoration(start, end, options.inlineClassName != null ? options.inlineClassName : '', options.inlineClassNameAffectsLetterSpacing == true, options.inlineStyle));
                            }
                        }
                    }

                    if (injectedTextEndOffsetInInputWithInjections <= lineEndOffsetInInputWithInjections) {
                        totalInjectedTextLengthBefore += length - ModelLineProjectionData.replacedLengthOf(injectionOptions[currentInjectedOffset]);
                        currentInjectedOffset++;
                    } else {
                        // injected text breaks into next line, process it again
                        break;
                    }
                }
            }
        }

        var lineWithInjections:LineTokens;
        if (injectionOffsets != null) {
            lineWithInjections = ModelLineProjections.tokensWithInjections(model.getLineTokens(modelLineNumber), injectionOffsets, injectionOptions);
        } else {
            lineWithInjections = model.getLineTokens(modelLineNumber);
        }

        for (outputLineIndex in outputLineIdx...outputLineIdx + lineCount) {
            final globalIndex = globalStartIndex + outputLineIndex - outputLineIdx;
            if (!needed[globalIndex]) {
                result[globalIndex] = null;
                continue;
            }
            result[globalIndex] = this._getViewLineData(lineWithInjections, inlineDecorationsPerOutputLine != null ? inlineDecorationsPerOutputLine[outputLineIndex] : null, outputLineIndex);
        }
    }

    function _getViewLineData(lineWithInjections:LineTokens, inlineDecorations:Null<Array<SingleLineInlineDecoration>>, outputLineIndex:Int):ViewLineData {
        this._assertVisible();
        final lineBreakData = this._projectionData;
        final deltaStartIndex = (outputLineIndex > 0 ? lineBreakData.wrappedTextIndentLength : 0);

        final lineStartOffsetInInputWithInjections = outputLineIndex > 0 ? lineBreakData.breakOffsets[outputLineIndex - 1] : 0;
        final lineEndOffsetInInputWithInjections = lineBreakData.breakOffsets[outputLineIndex];
        final tokens = lineWithInjections.sliceAndInflate(lineStartOffsetInInputWithInjections, lineEndOffsetInInputWithInjections, deltaStartIndex);

        var lineContent = tokens.getLineContent();
        if (outputLineIndex > 0) {
            lineContent = ModelLineProjections.spaces(lineBreakData.wrappedTextIndentLength) + lineContent;
        }

        final minColumn = this._projectionData.getMinOutputOffset(outputLineIndex) + 1;
        final maxColumn = lineContent.length + 1;
        final continuesWithWrappedLine = (outputLineIndex + 1 < this.getViewLineCount());
        // Visible columns can be fractional (full width characters): Std.int (see ModelLineProjectionData)
        final startVisibleColumn = (outputLineIndex == 0 ? 0 : Std.int(lineBreakData.breakOffsetsVisibleColumn[outputLineIndex - 1]));

        return new ViewLineData(
            lineContent,
            continuesWithWrappedLine,
            minColumn,
            maxColumn,
            startVisibleColumn,
            tokens,
            inlineDecorations
        );
    }

    public function getModelColumnOfViewPosition(outputLineIndex:Int, outputColumn:Int):Int {
        this._assertVisible();
        return this._projectionData.translateToInputOffset(outputLineIndex, outputColumn - 1) + 1;
    }

    public function getViewPositionOfModelPosition(deltaLineNumber:Int, inputColumn:Int, ?affinity:PositionAffinity):Position {
        this._assertVisible();
        final r = this._projectionData.translateToOutputPosition(inputColumn - 1, affinity == null ? PositionAffinity.None : affinity);
        return r.toPosition(deltaLineNumber);
    }

    public function getViewLineNumberOfModelPosition(deltaLineNumber:Int, inputColumn:Int):Int {
        this._assertVisible();
        final r = this._projectionData.translateToOutputPosition(inputColumn - 1);
        return deltaLineNumber + r.outputLineIndex;
    }

    public function normalizePosition(outputLineIndex:Int, outputPosition:Position, affinity:PositionAffinity):Position {
        final baseViewLineNumber = outputPosition.lineNumber - outputLineIndex;
        final normalizedOutputPosition = this._projectionData.normalizeOutputPosition(outputLineIndex, outputPosition.column - 1, affinity);
        final result = normalizedOutputPosition.toPosition(baseViewLineNumber);
        return result;
    }

    public function getInjectedTextAt(outputLineIndex:Int, outputColumn:Int):Null<InjectedText> {
        return this._projectionData.getInjectedText(outputLineIndex, outputColumn - 1);
    }

    function _assertVisible():Void {
        if (!this._isVisible) {
            throw 'Not supported';
        }
    }

}

/**
 * This projection does not change the model line.
 */
class IdentityModelLineProjection implements IModelLineProjection {

    public static final INSTANCE = new IdentityModelLineProjection();

    function new() {}

    public function isVisible():Bool {
        return true;
    }

    public function setVisible(isVisible:Bool):IModelLineProjection {
        if (isVisible) {
            return this;
        }
        return HiddenModelLineProjection.INSTANCE;
    }

    public function getProjectionData():Null<ModelLineProjectionData> {
        return null;
    }

    public function getViewLineCount():Int {
        return 1;
    }

    public function getViewLineContent(model:ISimpleModel, modelLineNumber:Int, _outputLineIndex:Int):String {
        return model.getLineContent(modelLineNumber);
    }

    public function getViewLineLength(model:ISimpleModel, modelLineNumber:Int, _outputLineIndex:Int):Int {
        return model.getLineLength(modelLineNumber);
    }

    public function getViewLineMinColumn(model:ISimpleModel, modelLineNumber:Int, _outputLineIndex:Int):Int {
        return model.getLineMinColumn(modelLineNumber);
    }

    public function getViewLineMaxColumn(model:ISimpleModel, modelLineNumber:Int, _outputLineIndex:Int):Int {
        return model.getLineMaxColumn(modelLineNumber);
    }

    public function getViewLineData(model:ISimpleModel, modelLineNumber:Int, _outputLineIndex:Int):ViewLineData {
        final lineTokens = model.getLineTokens(modelLineNumber);
        final lineContent = lineTokens.getLineContent();
        return new ViewLineData(
            lineContent,
            false,
            1,
            lineContent.length + 1,
            0,
            lineTokens.inflate(),
            null
        );
    }

    public function getViewLinesData(model:ISimpleModel, modelLineNumber:Int, _fromOuputLineIndex:Int, _toOutputLineIndex:Int, globalStartIndex:Int, needed:Array<Bool>, result:Array<Null<ViewLineData>>):Void {
        if (!needed[globalStartIndex]) {
            result[globalStartIndex] = null;
            return;
        }
        result[globalStartIndex] = this.getViewLineData(model, modelLineNumber, 0);
    }

    public function getModelColumnOfViewPosition(_outputLineIndex:Int, outputColumn:Int):Int {
        return outputColumn;
    }

    public function getViewPositionOfModelPosition(deltaLineNumber:Int, inputColumn:Int, ?affinity:PositionAffinity):Position {
        return new Position(deltaLineNumber, inputColumn);
    }

    public function getViewLineNumberOfModelPosition(deltaLineNumber:Int, _inputColumn:Int):Int {
        return deltaLineNumber;
    }

    public function normalizePosition(outputLineIndex:Int, outputPosition:Position, affinity:PositionAffinity):Position {
        return outputPosition;
    }

    public function getInjectedTextAt(_outputLineIndex:Int, _outputColumn:Int):Null<InjectedText> {
        return null;
    }

}

/**
 * This projection hides the model line.
 */
class HiddenModelLineProjection implements IModelLineProjection {

    public static final INSTANCE = new HiddenModelLineProjection();

    function new() {}

    public function isVisible():Bool {
        return false;
    }

    public function setVisible(isVisible:Bool):IModelLineProjection {
        if (!isVisible) {
            return this;
        }
        return IdentityModelLineProjection.INSTANCE;
    }

    public function getProjectionData():Null<ModelLineProjectionData> {
        return null;
    }

    public function getViewLineCount():Int {
        return 0;
    }

    public function getViewLineContent(_model:ISimpleModel, _modelLineNumber:Int, _outputLineIndex:Int):String {
        throw 'Not supported';
    }

    public function getViewLineLength(_model:ISimpleModel, _modelLineNumber:Int, _outputLineIndex:Int):Int {
        throw 'Not supported';
    }

    public function getViewLineMinColumn(_model:ISimpleModel, _modelLineNumber:Int, _outputLineIndex:Int):Int {
        throw 'Not supported';
    }

    public function getViewLineMaxColumn(_model:ISimpleModel, _modelLineNumber:Int, _outputLineIndex:Int):Int {
        throw 'Not supported';
    }

    public function getViewLineData(_model:ISimpleModel, _modelLineNumber:Int, _outputLineIndex:Int):ViewLineData {
        throw 'Not supported';
    }

    public function getViewLinesData(_model:ISimpleModel, _modelLineNumber:Int, _fromOuputLineIndex:Int, _toOutputLineIndex:Int, _globalStartIndex:Int, _needed:Array<Bool>, _result:Array<Null<ViewLineData>>):Void {
        throw 'Not supported';
    }

    public function getModelColumnOfViewPosition(_outputLineIndex:Int, _outputColumn:Int):Int {
        throw 'Not supported';
    }

    public function getViewPositionOfModelPosition(_deltaLineNumber:Int, _inputColumn:Int, ?affinity:PositionAffinity):Position {
        throw 'Not supported';
    }

    public function getViewLineNumberOfModelPosition(_deltaLineNumber:Int, _inputColumn:Int):Int {
        throw 'Not supported';
    }

    public function normalizePosition(outputLineIndex:Int, outputPosition:Position, affinity:PositionAffinity):Position {
        throw 'Not supported';
    }

    public function getInjectedTextAt(_outputLineIndex:Int, _outputColumn:Int):Null<InjectedText> {
        throw 'Not supported';
    }

}
