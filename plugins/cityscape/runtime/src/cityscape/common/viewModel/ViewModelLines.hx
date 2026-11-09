// Ported from vscode src/vs/editor/common/viewModel/viewModelLines.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.viewModel;

import cityscape.common.Model.IModelDecoration;
import cityscape.common.Model.IModelDeltaDecoration;
import cityscape.common.Model.ITextModel;
import cityscape.common.Model.PositionAffinity;
import cityscape.common.ModelLineProjectionData;
import cityscape.common.TextModelEvents.LineInjectedText;
import cityscape.common.TextModelGuides;
import cityscape.common.ViewEvents;
import cityscape.common.ViewModel.ICoordinatesConverter;
import cityscape.common.ViewModel.ViewLineData;
import cityscape.common.config.EditorOptions.WrappingIndent;
import cityscape.common.config.FontInfo;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.PrefixSumComputer;
import cityscape.common.viewModel.ModelLineProjection;

/**
 * The result of `onModelLineChanged`: Monaco's tuple
 * `[lineMappingChanged, changed, inserted, deleted]`.
 */
typedef ModelLineChangedResult = {
    final lineMappingChanged:Bool;
    final linesChangedEvent:Null<ViewLinesChangedEvent>;
    final linesInsertedEvent:Null<ViewLinesInsertedEvent>;
    final linesDeletedEvent:Null<ViewLinesDeletedEvent>;
}

interface IViewModelLines {
    function dispose():Void;

    function createCoordinatesConverter():ICoordinatesConverter;

    function setWrappingSettings(fontInfo:FontInfo, wrappingStrategy:String, wrappingColumn:Int, wrappingIndent:WrappingIndent, wordBreak:String, ?wrappingIndentColumns:Int):Bool;
    function setTabSize(newTabSize:Int):Bool;
    function getHiddenAreas():Array<Range>;
    function setHiddenAreas(_ranges:Array<Range>):Bool;

    function createLineBreaksComputer():ILineBreaksComputer;
    function onModelFlushed():Void;
    function onModelLinesDeleted(versionId:Null<Int>, fromLineNumber:Int, toLineNumber:Int):Null<ViewLinesDeletedEvent>;
    function onModelLinesInserted(versionId:Null<Int>, fromLineNumber:Int, toLineNumber:Int, lineBreaks:Array<Null<ModelLineProjectionData>>):Null<ViewLinesInsertedEvent>;
    function onModelLineChanged(versionId:Null<Int>, lineNumber:Int, lineBreakData:Null<ModelLineProjectionData>):ModelLineChangedResult;
    function acceptVersionId(versionId:Int):Void;

    function getViewLineCount():Int;
    function getActiveIndentGuide(viewLineNumber:Int, minLineNumber:Int, maxLineNumber:Int):IActiveIndentGuideInfo;
    function getViewLinesIndentGuides(viewStartLineNumber:Int, viewEndLineNumber:Int):Array<Int>;
    function getViewLinesBracketGuides(startLineNumber:Int, endLineNumber:Int, activePosition:Null<IPosition>, options:BracketGuideOptions):Array<Array<IndentGuide>>;
    function getViewLineContent(viewLineNumber:Int):String;
    function getViewLineLength(viewLineNumber:Int):Int;
    function getViewLineMinColumn(viewLineNumber:Int):Int;
    function getViewLineMaxColumn(viewLineNumber:Int):Int;
    function getViewLineData(viewLineNumber:Int):ViewLineData;
    function getViewLinesData(viewStartLineNumber:Int, viewEndLineNumber:Int, needed:Array<Bool>):Array<Null<ViewLineData>>;

    function getDecorationsInRange(range:Range, ownerId:Int, filterOutValidation:Bool, onlyMinimapDecorations:Bool, onlyMarginDecorations:Bool):Array<IModelDecoration>;

    function getInjectedTextAt(viewPosition:Position):Null<InjectedText>;

    function normalizePosition(position:Position, affinity:PositionAffinity):Position;
    /**
     * Gets the column at which indentation stops at a given line.
     * @internal
     */
    function getLineIndentColumn(lineNumber:Int):Int;
}

/**
 * Monaco's `ArrayQueue.takeWhile` on the injected texts of a model, sorted
 * by line number.
 */
private class InjectedTextQueue {

    final items:Array<LineInjectedText>;
    var index:Int = 0;

    public function new(items:Array<LineInjectedText>) {
        this.items = items;
    }

    public function takeWhileLine(lineNumber:Int):Null<Array<LineInjectedText>> {
        var result:Null<Array<LineInjectedText>> = null;
        while (index < items.length && items[index].lineNumber == lineNumber) {
            if (result == null) {
                result = [];
            }
            result.push(items[index]);
            index++;
        }
        return result;
    }

}

/**
 * Cityscape: the view's own injections of a model line (hidden ranges of
 * decorations, `IModelDecorationOptions.hidden` / `replacement`), merged
 * with the model's injected text. Set by the view model.
 */
typedef ViewInjectedTextProvider = (modelLineNumber:Int) -> Null<Array<LineInjectedText>>;

class ViewModelLinesFromProjectedModel implements IViewModelLines {

    final _editorId:Int;
    final model:ITextModel;
    final simpleModel:ISimpleModel;
    var _validModelVersionId:Int;

    final _domLineBreaksComputerFactory:ILineBreaksComputerFactory;
    final _monospaceLineBreaksComputerFactory:ILineBreaksComputerFactory;

    var fontInfo:FontInfo;
    var tabSize:Int;
    var wrappingColumn:Int;
    var wrappingIndent:WrappingIndent;
    var wordBreak:String;
    var wrappingStrategy:String;
    var wrappingIndentColumns:Int;

    var modelLineProjections:Array<IModelLineProjection>;

    /**
     * Reflects the sum of the line counts of all projected model lines.
     */
    var projectedModelLineLineCounts:ConstantTimePrefixSumComputer;

    var hiddenAreasDecorationIds:Array<String> = [];

    /**
     * Cityscape: the view's own injections (hidden ranges), or null.
     */
    public var viewInjectedTextProvider:Null<ViewInjectedTextProvider> = null;

    public function new(editorId:Int, model:ITextModel, domLineBreaksComputerFactory:ILineBreaksComputerFactory, monospaceLineBreaksComputerFactory:ILineBreaksComputerFactory, fontInfo:FontInfo, tabSize:Int, wrappingStrategy:String, wrappingColumn:Int, wrappingIndent:WrappingIndent, wordBreak:String, wrappingIndentColumns:Int = -1, ?viewInjectedTextProvider:ViewInjectedTextProvider) {
        this._editorId = editorId;
        this.model = model;
        this.simpleModel = new TextModelSimpleModel(model);
        this._validModelVersionId = -1;
        this._domLineBreaksComputerFactory = domLineBreaksComputerFactory;
        this._monospaceLineBreaksComputerFactory = monospaceLineBreaksComputerFactory;
        this.fontInfo = fontInfo;
        this.tabSize = tabSize;
        this.wrappingStrategy = wrappingStrategy;
        this.wrappingColumn = wrappingColumn;
        this.wrappingIndent = wrappingIndent;
        this.wordBreak = wordBreak;
        this.wrappingIndentColumns = wrappingIndentColumns;
        this.viewInjectedTextProvider = viewInjectedTextProvider;

        this._constructLines(/*resetHiddenAreas*/true, null);
    }

    public function dispose():Void {
        this.hiddenAreasDecorationIds = this.model.deltaDecorations(this.hiddenAreasDecorationIds, []);
    }

    public function createCoordinatesConverter():ICoordinatesConverter {
        return new CoordinatesConverter(this);
    }

    /**
     * Cityscape: merges the view's own injections of a model line with the
     * model's (sorted by column, then by order).
     */
    public function mergeViewInjectedText(lineNumber:Int, modelInjectedText:Null<Array<LineInjectedText>>):Null<Array<LineInjectedText>> {
        final provider = viewInjectedTextProvider;
        if (provider == null) {
            return modelInjectedText;
        }
        final own = provider(lineNumber);
        if (own == null || own.length == 0) {
            return modelInjectedText;
        }
        if (modelInjectedText == null || modelInjectedText.length == 0) {
            return own;
        }
        final result = modelInjectedText.concat(own);
        haxe.ds.ArraySort.sort(result, (a, b) -> {
            if (a.column == b.column) {
                return a.order - b.order;
            }
            return a.column - b.column;
        });
        return result;
    }

    function _constructLines(resetHiddenAreas:Bool, previousLineBreaks:Null<Array<Null<ModelLineProjectionData>>>):Void {
        this.modelLineProjections = [];

        if (resetHiddenAreas) {
            this.hiddenAreasDecorationIds = this.model.deltaDecorations(this.hiddenAreasDecorationIds, []);
        }

        final linesContent = this.model.getLinesContent();
        final injectedTextDecorations = this.model.getInjectedTextDecorations(this._editorId);
        final lineCount = linesContent.length;
        final lineBreaksComputer = this.createLineBreaksComputer();

        final injectedTextQueue = new InjectedTextQueue(LineInjectedText.fromDecorations(injectedTextDecorations));
        for (i in 0...lineCount) {
            final lineInjectedText = mergeViewInjectedText(i + 1, injectedTextQueue.takeWhileLine(i + 1));
            lineBreaksComputer.addRequest(linesContent[i], lineInjectedText, previousLineBreaks != null ? previousLineBreaks[i] : null);
        }
        final linesBreaks = lineBreaksComputer.finalize();

        final values:Array<Int> = [];

        final hiddenAreas = [for (areaId in this.hiddenAreasDecorationIds) this.model.getDecorationRange(areaId)];
        hiddenAreas.sort(Range.compareRangesUsingStarts);
        var hiddenAreaStart = 1, hiddenAreaEnd = 0;
        var hiddenAreaIdx = -1;
        var nextLineNumberToUpdateHiddenArea = (hiddenAreaIdx + 1 < hiddenAreas.length) ? hiddenAreaEnd + 1 : lineCount + 2;

        for (i in 0...lineCount) {
            final lineNumber = i + 1;

            if (lineNumber == nextLineNumberToUpdateHiddenArea) {
                hiddenAreaIdx++;
                hiddenAreaStart = hiddenAreas[hiddenAreaIdx].startLineNumber;
                hiddenAreaEnd = hiddenAreas[hiddenAreaIdx].endLineNumber;
                nextLineNumberToUpdateHiddenArea = (hiddenAreaIdx + 1 < hiddenAreas.length) ? hiddenAreaEnd + 1 : lineCount + 2;
            }

            final isInHiddenArea = (lineNumber >= hiddenAreaStart && lineNumber <= hiddenAreaEnd);
            final line = ModelLineProjections.createModelLineProjection(linesBreaks[i], !isInHiddenArea);
            values[i] = line.getViewLineCount();
            this.modelLineProjections[i] = line;
        }

        this._validModelVersionId = this.model.getVersionId();

        this.projectedModelLineLineCounts = new ConstantTimePrefixSumComputer(values);
    }

    public function getHiddenAreas():Array<Range> {
        return [for (decId in this.hiddenAreasDecorationIds) this.model.getDecorationRange(decId)];
    }

    public function setHiddenAreas(_ranges:Array<Range>):Bool {
        final validatedRanges = [for (r in _ranges) this.model.validateRange(r)];
        final newRanges = normalizeLineRanges(validatedRanges);

        // This checks if there really was a change
        final oldRanges = [for (areaId in this.hiddenAreasDecorationIds) this.model.getDecorationRange(areaId)];
        oldRanges.sort(Range.compareRangesUsingStarts);
        if (newRanges.length == oldRanges.length) {
            var hasDifference = false;
            for (i in 0...newRanges.length) {
                if (!newRanges[i].equalsRange(oldRanges[i])) {
                    hasDifference = true;
                    break;
                }
            }
            if (!hasDifference) {
                return false;
            }
        }

        final newDecorations:Array<IModelDeltaDecoration> = [for (r in newRanges) {
            range: r,
            options: {description: 'empty'},
        }];

        this.hiddenAreasDecorationIds = this.model.deltaDecorations(this.hiddenAreasDecorationIds, newDecorations);

        final hiddenAreas = newRanges;
        var hiddenAreaStart = 1, hiddenAreaEnd = 0;
        var hiddenAreaIdx = -1;
        var nextLineNumberToUpdateHiddenArea = (hiddenAreaIdx + 1 < hiddenAreas.length) ? hiddenAreaEnd + 1 : this.modelLineProjections.length + 2;

        var hasVisibleLine = false;
        for (i in 0...this.modelLineProjections.length) {
            final lineNumber = i + 1;

            if (lineNumber == nextLineNumberToUpdateHiddenArea) {
                hiddenAreaIdx++;
                hiddenAreaStart = hiddenAreas[hiddenAreaIdx].startLineNumber;
                hiddenAreaEnd = hiddenAreas[hiddenAreaIdx].endLineNumber;
                nextLineNumberToUpdateHiddenArea = (hiddenAreaIdx + 1 < hiddenAreas.length) ? hiddenAreaEnd + 1 : this.modelLineProjections.length + 2;
            }

            var lineChanged = false;
            if (lineNumber >= hiddenAreaStart && lineNumber <= hiddenAreaEnd) {
                // Line should be hidden
                if (this.modelLineProjections[i].isVisible()) {
                    this.modelLineProjections[i] = this.modelLineProjections[i].setVisible(false);
                    lineChanged = true;
                }
            } else {
                hasVisibleLine = true;
                // Line should be visible
                if (!this.modelLineProjections[i].isVisible()) {
                    this.modelLineProjections[i] = this.modelLineProjections[i].setVisible(true);
                    lineChanged = true;
                }
            }
            if (lineChanged) {
                final newOutputLineCount = this.modelLineProjections[i].getViewLineCount();
                this.projectedModelLineLineCounts.setValue(i, newOutputLineCount);
            }
        }

        if (!hasVisibleLine) {
            // Cannot have everything be hidden => reveal everything!
            this.setHiddenAreas([]);
        }

        return true;
    }

    public function modelPositionIsVisible(modelLineNumber:Int, _modelColumn:Int):Bool {
        if (modelLineNumber < 1 || modelLineNumber > this.modelLineProjections.length) {
            // invalid arguments
            return false;
        }
        return this.modelLineProjections[modelLineNumber - 1].isVisible();
    }

    public function getModelLineViewLineCount(modelLineNumber:Int):Int {
        if (modelLineNumber < 1 || modelLineNumber > this.modelLineProjections.length) {
            // invalid arguments
            return 1;
        }
        return this.modelLineProjections[modelLineNumber - 1].getViewLineCount();
    }

    public function setTabSize(newTabSize:Int):Bool {
        if (this.tabSize == newTabSize) {
            return false;
        }
        this.tabSize = newTabSize;

        this._constructLines(/*resetHiddenAreas*/false, null);

        return true;
    }

    public function setWrappingSettings(fontInfo:FontInfo, wrappingStrategy:String, wrappingColumn:Int, wrappingIndent:WrappingIndent, wordBreak:String, ?wrappingIndentColumns:Int):Bool {
        final wrappingIndentColumns:Int = (wrappingIndentColumns == null ? this.wrappingIndentColumns : wrappingIndentColumns);
        final equalFontInfo = this.fontInfo.equals(fontInfo);
        final equalWrappingStrategy = (this.wrappingStrategy == wrappingStrategy);
        final equalWrappingColumn = (this.wrappingColumn == wrappingColumn);
        final equalWrappingIndent = (this.wrappingIndent == wrappingIndent && this.wrappingIndentColumns == wrappingIndentColumns);
        final equalWordBreak = (this.wordBreak == wordBreak);
        if (equalFontInfo && equalWrappingStrategy && equalWrappingColumn && equalWrappingIndent && equalWordBreak) {
            return false;
        }

        final onlyWrappingColumnChanged = (equalFontInfo && equalWrappingStrategy && !equalWrappingColumn && equalWrappingIndent && equalWordBreak);

        this.fontInfo = fontInfo;
        this.wrappingStrategy = wrappingStrategy;
        this.wrappingColumn = wrappingColumn;
        this.wrappingIndent = wrappingIndent;
        this.wrappingIndentColumns = wrappingIndentColumns;
        this.wordBreak = wordBreak;

        var previousLineBreaks:Null<Array<Null<ModelLineProjectionData>>> = null;
        if (onlyWrappingColumnChanged) {
            previousLineBreaks = [];
            for (i in 0...this.modelLineProjections.length) {
                previousLineBreaks[i] = this.modelLineProjections[i].getProjectionData();
            }
        }

        this._constructLines(/*resetHiddenAreas*/false, previousLineBreaks);

        return true;
    }

    public function createLineBreaksComputer():ILineBreaksComputer {
        final lineBreaksComputerFactory = (
            this.wrappingStrategy == 'advanced'
                ? this._domLineBreaksComputerFactory
                : this._monospaceLineBreaksComputerFactory
        );
        return lineBreaksComputerFactory.createLineBreaksComputer(this.fontInfo, this.tabSize, this.wrappingColumn, this.wrappingIndent, this.wordBreak, this.wrappingIndentColumns);
    }

    public function onModelFlushed():Void {
        this._constructLines(/*resetHiddenAreas*/true, null);
    }

    public function onModelLinesDeleted(versionId:Null<Int>, fromLineNumber:Int, toLineNumber:Int):Null<ViewLinesDeletedEvent> {
        if (versionId == null || versionId == 0 || versionId <= this._validModelVersionId) {
            // Here we check for versionId in case the lines were reconstructed in the meantime.
            // We don't want to apply stale change events on top of a newer read model state.
            return null;
        }

        final outputFromLineNumber = (fromLineNumber == 1 ? 1 : this.projectedModelLineLineCounts.getPrefixSum(fromLineNumber - 1) + 1);
        final outputToLineNumber = this.projectedModelLineLineCounts.getPrefixSum(toLineNumber);

        this.modelLineProjections.splice(fromLineNumber - 1, toLineNumber - fromLineNumber + 1);
        this.projectedModelLineLineCounts.removeValues(fromLineNumber - 1, toLineNumber - fromLineNumber + 1);

        return new ViewLinesDeletedEvent(outputFromLineNumber, outputToLineNumber);
    }

    public function onModelLinesInserted(versionId:Null<Int>, fromLineNumber:Int, _toLineNumber:Int, lineBreaks:Array<Null<ModelLineProjectionData>>):Null<ViewLinesInsertedEvent> {
        if (versionId == null || versionId == 0 || versionId <= this._validModelVersionId) {
            // Here we check for versionId in case the lines were reconstructed in the meantime.
            // We don't want to apply stale change events on top of a newer read model state.
            return null;
        }

        // cannot use this.getHiddenAreas() because those decorations have already seen the effect of this model change
        final isInHiddenArea = (fromLineNumber > 2 && !this.modelLineProjections[fromLineNumber - 2].isVisible());

        final outputFromLineNumber = (fromLineNumber == 1 ? 1 : this.projectedModelLineLineCounts.getPrefixSum(fromLineNumber - 1) + 1);

        var totalOutputLineCount = 0;
        final insertLines:Array<IModelLineProjection> = [];
        final insertPrefixSumValues:Array<Int> = [];

        for (i in 0...lineBreaks.length) {
            final line = ModelLineProjections.createModelLineProjection(lineBreaks[i], !isInHiddenArea);
            insertLines.push(line);

            final outputLineCount = line.getViewLineCount();
            totalOutputLineCount += outputLineCount;
            insertPrefixSumValues[i] = outputLineCount;
        }

        this.modelLineProjections =
            this.modelLineProjections.slice(0, fromLineNumber - 1)
                .concat(insertLines)
                .concat(this.modelLineProjections.slice(fromLineNumber - 1));

        this.projectedModelLineLineCounts.insertValues(fromLineNumber - 1, insertPrefixSumValues);

        return new ViewLinesInsertedEvent(outputFromLineNumber, outputFromLineNumber + totalOutputLineCount - 1);
    }

    public function onModelLineChanged(versionId:Null<Int>, lineNumber:Int, lineBreakData:Null<ModelLineProjectionData>):ModelLineChangedResult {
        if (versionId != null && versionId <= this._validModelVersionId) {
            // Here we check for versionId in case the lines were reconstructed in the meantime.
            // We don't want to apply stale change events on top of a newer read model state.
            return {lineMappingChanged: false, linesChangedEvent: null, linesInsertedEvent: null, linesDeletedEvent: null};
        }

        final lineIndex = lineNumber - 1;

        final oldOutputLineCount = this.modelLineProjections[lineIndex].getViewLineCount();
        final isVisible = this.modelLineProjections[lineIndex].isVisible();
        final line = ModelLineProjections.createModelLineProjection(lineBreakData, isVisible);
        this.modelLineProjections[lineIndex] = line;
        final newOutputLineCount = this.modelLineProjections[lineIndex].getViewLineCount();

        var lineMappingChanged = false;
        var changeFrom = 0;
        var changeTo = -1;
        var insertFrom = 0;
        var insertTo = -1;
        var deleteFrom = 0;
        var deleteTo = -1;

        if (oldOutputLineCount > newOutputLineCount) {
            changeFrom = this.projectedModelLineLineCounts.getPrefixSum(lineNumber - 1) + 1;
            changeTo = changeFrom + newOutputLineCount - 1;
            deleteFrom = changeTo + 1;
            deleteTo = deleteFrom + (oldOutputLineCount - newOutputLineCount) - 1;
            lineMappingChanged = true;
        } else if (oldOutputLineCount < newOutputLineCount) {
            changeFrom = this.projectedModelLineLineCounts.getPrefixSum(lineNumber - 1) + 1;
            changeTo = changeFrom + oldOutputLineCount - 1;
            insertFrom = changeTo + 1;
            insertTo = insertFrom + (newOutputLineCount - oldOutputLineCount) - 1;
            lineMappingChanged = true;
        } else {
            changeFrom = this.projectedModelLineLineCounts.getPrefixSum(lineNumber - 1) + 1;
            changeTo = changeFrom + newOutputLineCount - 1;
        }

        this.projectedModelLineLineCounts.setValue(lineIndex, newOutputLineCount);

        final viewLinesChangedEvent = (changeFrom <= changeTo ? new ViewLinesChangedEvent(changeFrom, changeTo - changeFrom + 1) : null);
        final viewLinesInsertedEvent = (insertFrom <= insertTo ? new ViewLinesInsertedEvent(insertFrom, insertTo) : null);
        final viewLinesDeletedEvent = (deleteFrom <= deleteTo ? new ViewLinesDeletedEvent(deleteFrom, deleteTo) : null);

        return {
            lineMappingChanged: lineMappingChanged,
            linesChangedEvent: viewLinesChangedEvent,
            linesInsertedEvent: viewLinesInsertedEvent,
            linesDeletedEvent: viewLinesDeletedEvent
        };
    }

    public function acceptVersionId(versionId:Int):Void {
        this._validModelVersionId = versionId;
        if (this.modelLineProjections.length == 1 && !this.modelLineProjections[0].isVisible()) {
            // At least one line must be visible => reset hidden areas
            this.setHiddenAreas([]);
        }
    }

    public function getViewLineCount():Int {
        return this.projectedModelLineLineCounts.getTotalSum();
    }

    function _toValidViewLineNumber(viewLineNumber:Int):Int {
        if (viewLineNumber < 1) {
            return 1;
        }
        final viewLineCount = this.getViewLineCount();
        if (viewLineNumber > viewLineCount) {
            return viewLineCount;
        }
        return viewLineNumber;
    }

    public function getActiveIndentGuide(viewLineNumber:Int, minLineNumber:Int, maxLineNumber:Int):IActiveIndentGuideInfo {
        viewLineNumber = this._toValidViewLineNumber(viewLineNumber);
        minLineNumber = this._toValidViewLineNumber(minLineNumber);
        maxLineNumber = this._toValidViewLineNumber(maxLineNumber);

        final modelPosition = this.convertViewPositionToModelPosition(viewLineNumber, this.getViewLineMinColumn(viewLineNumber));
        final modelMinPosition = this.convertViewPositionToModelPosition(minLineNumber, this.getViewLineMinColumn(minLineNumber));
        final modelMaxPosition = this.convertViewPositionToModelPosition(maxLineNumber, this.getViewLineMinColumn(maxLineNumber));
        final result = this.model.guides.getActiveIndentGuide(modelPosition.lineNumber, modelMinPosition.lineNumber, modelMaxPosition.lineNumber);

        final viewStartPosition = this.convertModelPositionToViewPosition(result.startLineNumber, 1);
        final viewEndPosition = this.convertModelPositionToViewPosition(result.endLineNumber, this.model.getLineMaxColumn(result.endLineNumber));
        return {
            startLineNumber: viewStartPosition.lineNumber,
            endLineNumber: viewEndPosition.lineNumber,
            indent: result.indent
        };
    }

    // #region ViewLineInfo

    function getViewLineInfo(viewLineNumber:Int):ViewLineInfo {
        viewLineNumber = this._toValidViewLineNumber(viewLineNumber);
        final r = this.projectedModelLineLineCounts.getIndexOf(viewLineNumber - 1);
        final lineIndex = r.index;
        final remainder = r.remainder;
        return new ViewLineInfo(lineIndex + 1, remainder);
    }

    function getMinColumnOfViewLine(viewLineInfo:ViewLineInfo):Int {
        return this.modelLineProjections[viewLineInfo.modelLineNumber - 1].getViewLineMinColumn(
            this.simpleModel,
            viewLineInfo.modelLineNumber,
            viewLineInfo.modelLineWrappedLineIdx
        );
    }

    function getMaxColumnOfViewLine(viewLineInfo:ViewLineInfo):Int {
        return this.modelLineProjections[viewLineInfo.modelLineNumber - 1].getViewLineMaxColumn(
            this.simpleModel,
            viewLineInfo.modelLineNumber,
            viewLineInfo.modelLineWrappedLineIdx
        );
    }

    function getModelStartPositionOfViewLine(viewLineInfo:ViewLineInfo):Position {
        final line = this.modelLineProjections[viewLineInfo.modelLineNumber - 1];
        final minViewColumn = line.getViewLineMinColumn(
            this.simpleModel,
            viewLineInfo.modelLineNumber,
            viewLineInfo.modelLineWrappedLineIdx
        );
        final column = line.getModelColumnOfViewPosition(
            viewLineInfo.modelLineWrappedLineIdx,
            minViewColumn
        );
        return new Position(viewLineInfo.modelLineNumber, column);
    }

    function getModelEndPositionOfViewLine(viewLineInfo:ViewLineInfo):Position {
        final line = this.modelLineProjections[viewLineInfo.modelLineNumber - 1];
        final maxViewColumn = line.getViewLineMaxColumn(
            this.simpleModel,
            viewLineInfo.modelLineNumber,
            viewLineInfo.modelLineWrappedLineIdx
        );
        final column = line.getModelColumnOfViewPosition(
            viewLineInfo.modelLineWrappedLineIdx,
            maxViewColumn
        );
        return new Position(viewLineInfo.modelLineNumber, column);
    }

    function getViewLineInfosGroupedByModelRanges(viewStartLineNumber:Int, viewEndLineNumber:Int):Array<ViewLineInfoGroupedByModelRange> {
        final startViewLine = this.getViewLineInfo(viewStartLineNumber);
        final endViewLine = this.getViewLineInfo(viewEndLineNumber);

        final result = new Array<ViewLineInfoGroupedByModelRange>();
        var lastVisibleModelPos:Null<Position> = this.getModelStartPositionOfViewLine(startViewLine);
        var viewLines = new Array<ViewLineInfo>();

        for (curModelLine in startViewLine.modelLineNumber...endViewLine.modelLineNumber + 1) {
            final line = this.modelLineProjections[curModelLine - 1];

            if (line.isVisible()) {
                final startOffset =
                    curModelLine == startViewLine.modelLineNumber
                        ? startViewLine.modelLineWrappedLineIdx
                        : 0;

                final endOffset =
                    curModelLine == endViewLine.modelLineNumber
                        ? endViewLine.modelLineWrappedLineIdx + 1
                        : line.getViewLineCount();

                for (i in startOffset...endOffset) {
                    viewLines.push(new ViewLineInfo(curModelLine, i));
                }
            }

            if (!line.isVisible() && lastVisibleModelPos != null) {
                final lastVisibleModelPos2 = new Position(curModelLine - 1, this.model.getLineMaxColumn(curModelLine - 1) + 1);

                final modelRange = Range.fromPositions(lastVisibleModelPos, lastVisibleModelPos2);
                result.push(new ViewLineInfoGroupedByModelRange(modelRange, viewLines));
                viewLines = [];

                lastVisibleModelPos = null;
            } else if (line.isVisible() && lastVisibleModelPos == null) {
                lastVisibleModelPos = new Position(curModelLine, 1);
            }
        }

        if (lastVisibleModelPos != null) {
            final modelRange = Range.fromPositions(lastVisibleModelPos, this.getModelEndPositionOfViewLine(endViewLine));
            result.push(new ViewLineInfoGroupedByModelRange(modelRange, viewLines));
        }

        return result;
    }

    // #endregion

    public function getViewLinesBracketGuides(viewStartLineNumber:Int, viewEndLineNumber:Int, activeViewPosition:Null<IPosition>, options:BracketGuideOptions):Array<Array<IndentGuide>> {
        final modelActivePosition = activeViewPosition != null ? this.convertViewPositionToModelPosition(activeViewPosition.lineNumber, activeViewPosition.column) : null;
        final resultPerViewLine:Array<Array<IndentGuide>> = [];

        for (group in this.getViewLineInfosGroupedByModelRanges(viewStartLineNumber, viewEndLineNumber)) {
            final modelRangeStartLineNumber = group.modelRange.startLineNumber;

            final bracketGuidesPerModelLine = this.model.guides.getLinesBracketGuides(
                modelRangeStartLineNumber,
                group.modelRange.endLineNumber,
                modelActivePosition,
                options
            );

            for (viewLineInfo in group.viewLines) {

                final bracketGuides = bracketGuidesPerModelLine[viewLineInfo.modelLineNumber - modelRangeStartLineNumber];

                // visibleColumns stay as they are (this is a bug and needs to be fixed, but it is not a regression)
                // model-columns must be converted to view-model columns.
                final result:Array<Null<IndentGuide>> = bracketGuides.map(g -> {
                    if (g.forWrappedLinesAfterColumn != -1) {
                        final p = this.modelLineProjections[viewLineInfo.modelLineNumber - 1].getViewPositionOfModelPosition(0, g.forWrappedLinesAfterColumn);
                        if (p.lineNumber >= viewLineInfo.modelLineWrappedLineIdx) {
                            return null;
                        }
                    }

                    if (g.forWrappedLinesBeforeOrAtColumn != -1) {
                        final p = this.modelLineProjections[viewLineInfo.modelLineNumber - 1].getViewPositionOfModelPosition(0, g.forWrappedLinesBeforeOrAtColumn);
                        if (p.lineNumber < viewLineInfo.modelLineWrappedLineIdx) {
                            return null;
                        }
                    }

                    if (g.horizontalLine == null) {
                        return g;
                    }

                    var column = -1;
                    if (g.column != -1) {
                        final p = this.modelLineProjections[viewLineInfo.modelLineNumber - 1].getViewPositionOfModelPosition(0, g.column);
                        if (p.lineNumber == viewLineInfo.modelLineWrappedLineIdx) {
                            column = p.column;
                        } else if (p.lineNumber < viewLineInfo.modelLineWrappedLineIdx) {
                            column = this.getMinColumnOfViewLine(viewLineInfo);
                        } else if (p.lineNumber > viewLineInfo.modelLineWrappedLineIdx) {
                            return null;
                        }
                    }

                    final viewPosition = this.convertModelPositionToViewPosition(viewLineInfo.modelLineNumber, g.horizontalLine.endColumn);
                    final p = this.modelLineProjections[viewLineInfo.modelLineNumber - 1].getViewPositionOfModelPosition(0, g.horizontalLine.endColumn);
                    if (p.lineNumber == viewLineInfo.modelLineWrappedLineIdx) {
                        return new IndentGuide(g.visibleColumn, column, g.className,
                            new IndentGuideHorizontalLine(g.horizontalLine.top,
                                viewPosition.column),
                            -1,
                            -1
                        );
                    } else if (p.lineNumber < viewLineInfo.modelLineWrappedLineIdx) {
                        return null;
                    } else {
                        if (g.visibleColumn != -1) {
                            // Don't repeat horizontal lines that use visibleColumn for unrelated lines.
                            return null;
                        }
                        return new IndentGuide(g.visibleColumn, column, g.className,
                            new IndentGuideHorizontalLine(g.horizontalLine.top,
                                this.getMaxColumnOfViewLine(viewLineInfo)
                            ),
                            -1,
                            -1
                        );
                    }
                });
                resultPerViewLine.push([for (r in result) if (r != null) r]);
            }
        }

        return resultPerViewLine;
    }

    public function getViewLinesIndentGuides(viewStartLineNumber:Int, viewEndLineNumber:Int):Array<Int> {
        // TODO: Use the same code as in `getViewLinesBracketGuides`.
        // Future TODO: Merge with `getViewLinesBracketGuides`.
        // However, this requires more refactoring of indent guides.
        viewStartLineNumber = this._toValidViewLineNumber(viewStartLineNumber);
        viewEndLineNumber = this._toValidViewLineNumber(viewEndLineNumber);

        final modelStart = this.convertViewPositionToModelPosition(viewStartLineNumber, this.getViewLineMinColumn(viewStartLineNumber));
        final modelEnd = this.convertViewPositionToModelPosition(viewEndLineNumber, this.getViewLineMaxColumn(viewEndLineNumber));

        var result:Array<Int> = [];
        final resultRepeatCount:Array<Int> = [];
        final resultRepeatOption:Array<IndentGuideRepeatOption> = [];
        final modelStartLineIndex = modelStart.lineNumber - 1;
        final modelEndLineIndex = modelEnd.lineNumber - 1;

        var reqStart:Null<Position> = null;
        for (modelLineIndex in modelStartLineIndex...modelEndLineIndex + 1) {
            final line = this.modelLineProjections[modelLineIndex];
            if (line.isVisible()) {
                final viewLineStartIndex = line.getViewLineNumberOfModelPosition(0, modelLineIndex == modelStartLineIndex ? modelStart.column : 1);
                final viewLineEndIndex = line.getViewLineNumberOfModelPosition(0, this.model.getLineMaxColumn(modelLineIndex + 1));
                final count = viewLineEndIndex - viewLineStartIndex + 1;
                var option = IndentGuideRepeatOption.BlockNone;
                if (count > 1 && line.getViewLineMinColumn(this.simpleModel, modelLineIndex + 1, viewLineEndIndex) == 1) {
                    // wrapped lines should block indent guides
                    option = (viewLineStartIndex == 0 ? IndentGuideRepeatOption.BlockSubsequent : IndentGuideRepeatOption.BlockAll);
                }
                resultRepeatCount.push(count);
                resultRepeatOption.push(option);
                // merge into previous request
                if (reqStart == null) {
                    reqStart = new Position(modelLineIndex + 1, 0);
                }
            } else {
                // hit invisible line => flush request
                if (reqStart != null) {
                    result = result.concat(this.model.guides.getLinesIndentGuides(reqStart.lineNumber, modelLineIndex));
                    reqStart = null;
                }
            }
        }

        if (reqStart != null) {
            result = result.concat(this.model.guides.getLinesIndentGuides(reqStart.lineNumber, modelEnd.lineNumber));
            reqStart = null;
        }

        final viewLineCount = viewEndLineNumber - viewStartLineNumber + 1;
        final viewIndents = [for (_ in 0...viewLineCount) 0];
        var currIndex = 0;
        for (i in 0...result.length) {
            var value = result[i];
            final count = (viewLineCount - currIndex < resultRepeatCount[i] ? viewLineCount - currIndex : resultRepeatCount[i]);
            final option = resultRepeatOption[i];
            var blockAtIndex:Int;
            if (option == IndentGuideRepeatOption.BlockAll) {
                blockAtIndex = 0;
            } else if (option == IndentGuideRepeatOption.BlockSubsequent) {
                blockAtIndex = 1;
            } else {
                blockAtIndex = count;
            }
            for (j in 0...count) {
                if (j == blockAtIndex) {
                    value = 0;
                }
                viewIndents[currIndex++] = value;
            }
        }
        return viewIndents;
    }

    public function getViewLineContent(viewLineNumber:Int):String {
        final info = this.getViewLineInfo(viewLineNumber);
        return this.modelLineProjections[info.modelLineNumber - 1].getViewLineContent(this.simpleModel, info.modelLineNumber, info.modelLineWrappedLineIdx);
    }

    public function getViewLineLength(viewLineNumber:Int):Int {
        final info = this.getViewLineInfo(viewLineNumber);
        return this.modelLineProjections[info.modelLineNumber - 1].getViewLineLength(this.simpleModel, info.modelLineNumber, info.modelLineWrappedLineIdx);
    }

    public function getViewLineMinColumn(viewLineNumber:Int):Int {
        final info = this.getViewLineInfo(viewLineNumber);
        return this.modelLineProjections[info.modelLineNumber - 1].getViewLineMinColumn(this.simpleModel, info.modelLineNumber, info.modelLineWrappedLineIdx);
    }

    public function getViewLineMaxColumn(viewLineNumber:Int):Int {
        final info = this.getViewLineInfo(viewLineNumber);
        return this.modelLineProjections[info.modelLineNumber - 1].getViewLineMaxColumn(this.simpleModel, info.modelLineNumber, info.modelLineWrappedLineIdx);
    }

    public function getViewLineData(viewLineNumber:Int):ViewLineData {
        final info = this.getViewLineInfo(viewLineNumber);
        return this.modelLineProjections[info.modelLineNumber - 1].getViewLineData(this.simpleModel, info.modelLineNumber, info.modelLineWrappedLineIdx);
    }

    public function getViewLinesData(viewStartLineNumber:Int, viewEndLineNumber:Int, needed:Array<Bool>):Array<Null<ViewLineData>> {

        viewStartLineNumber = this._toValidViewLineNumber(viewStartLineNumber);
        viewEndLineNumber = this._toValidViewLineNumber(viewEndLineNumber);

        final start = this.projectedModelLineLineCounts.getIndexOf(viewStartLineNumber - 1);
        var viewLineNumber = viewStartLineNumber;
        final startModelLineIndex = start.index;
        final startRemainder = start.remainder;

        final result:Array<Null<ViewLineData>> = [];
        for (modelLineIndex in startModelLineIndex...this.model.getLineCount()) {
            final line = this.modelLineProjections[modelLineIndex];
            if (!line.isVisible()) {
                continue;
            }
            final fromViewLineIndex = (modelLineIndex == startModelLineIndex ? startRemainder : 0);
            var remainingViewLineCount = line.getViewLineCount() - fromViewLineIndex;

            var lastLine = false;
            if (viewLineNumber + remainingViewLineCount > viewEndLineNumber) {
                lastLine = true;
                remainingViewLineCount = viewEndLineNumber - viewLineNumber + 1;
            }

            line.getViewLinesData(this.simpleModel, modelLineIndex + 1, fromViewLineIndex, remainingViewLineCount, viewLineNumber - viewStartLineNumber, needed, result);

            viewLineNumber += remainingViewLineCount;

            if (lastLine) {
                break;
            }
        }

        return result;
    }

    public function validateViewPosition(viewLineNumber:Int, viewColumn:Int, expectedModelPosition:Position):Position {
        viewLineNumber = this._toValidViewLineNumber(viewLineNumber);

        final r = this.projectedModelLineLineCounts.getIndexOf(viewLineNumber - 1);
        final lineIndex = r.index;
        final remainder = r.remainder;

        final line = this.modelLineProjections[lineIndex];

        final minColumn = line.getViewLineMinColumn(this.simpleModel, lineIndex + 1, remainder);
        final maxColumn = line.getViewLineMaxColumn(this.simpleModel, lineIndex + 1, remainder);
        if (viewColumn < minColumn) {
            viewColumn = minColumn;
        }
        if (viewColumn > maxColumn) {
            viewColumn = maxColumn;
        }

        final computedModelColumn = line.getModelColumnOfViewPosition(remainder, viewColumn);
        final computedModelPosition = this.model.validatePosition(new Position(lineIndex + 1, computedModelColumn));

        if (computedModelPosition.equals(expectedModelPosition)) {
            return new Position(viewLineNumber, viewColumn);
        }

        return this.convertModelPositionToViewPosition(expectedModelPosition.lineNumber, expectedModelPosition.column);
    }

    public function validateViewRange(viewRange:Range, expectedModelRange:Range):Range {
        final validViewStart = this.validateViewPosition(viewRange.startLineNumber, viewRange.startColumn, expectedModelRange.getStartPosition());
        final validViewEnd = this.validateViewPosition(viewRange.endLineNumber, viewRange.endColumn, expectedModelRange.getEndPosition());
        return new Range(validViewStart.lineNumber, validViewStart.column, validViewEnd.lineNumber, validViewEnd.column);
    }

    public function convertViewPositionToModelPosition(viewLineNumber:Int, viewColumn:Int):Position {
        final info = this.getViewLineInfo(viewLineNumber);

        final inputColumn = this.modelLineProjections[info.modelLineNumber - 1].getModelColumnOfViewPosition(info.modelLineWrappedLineIdx, viewColumn);
        return this.model.validatePosition(new Position(info.modelLineNumber, inputColumn));
    }

    public function convertViewRangeToModelRange(viewRange:Range):Range {
        final start = this.convertViewPositionToModelPosition(viewRange.startLineNumber, viewRange.startColumn);
        final end = this.convertViewPositionToModelPosition(viewRange.endLineNumber, viewRange.endColumn);
        return new Range(start.lineNumber, start.column, end.lineNumber, end.column);
    }

    public function convertModelPositionToViewPosition(_modelLineNumber:Int, _modelColumn:Int, affinity:PositionAffinity = PositionAffinity.None, allowZeroLineNumber:Bool = false, belowHiddenRanges:Bool = false):Position {

        final validPosition = this.model.validatePosition(new Position(_modelLineNumber, _modelColumn));
        final inputLineNumber = validPosition.lineNumber;
        final inputColumn = validPosition.column;

        var lineIndex = inputLineNumber - 1, lineIndexChanged = false;
        if (belowHiddenRanges) {
            while (lineIndex < this.modelLineProjections.length && !this.modelLineProjections[lineIndex].isVisible()) {
                lineIndex++;
                lineIndexChanged = true;
            }
        } else {
            while (lineIndex > 0 && !this.modelLineProjections[lineIndex].isVisible()) {
                lineIndex--;
                lineIndexChanged = true;
            }
        }
        if (lineIndex == 0 && !this.modelLineProjections[lineIndex].isVisible()) {
            // Could not reach a real line
            return new Position(allowZeroLineNumber ? 0 : 1, 1);
        }
        final deltaLineNumber = 1 + this.projectedModelLineLineCounts.getPrefixSum(lineIndex);

        var r:Position;
        if (lineIndexChanged) {
            if (belowHiddenRanges) {
                r = this.modelLineProjections[lineIndex].getViewPositionOfModelPosition(deltaLineNumber, 1, affinity);
            } else {
                r = this.modelLineProjections[lineIndex].getViewPositionOfModelPosition(deltaLineNumber, this.model.getLineMaxColumn(lineIndex + 1), affinity);
            }
        } else {
            r = this.modelLineProjections[inputLineNumber - 1].getViewPositionOfModelPosition(deltaLineNumber, inputColumn, affinity);
        }

        return r;
    }

    /**
     * @param affinity The affinity in case of an empty range. Has no effect for non-empty ranges.
     */
    public function convertModelRangeToViewRange(modelRange:Range, affinity:PositionAffinity = PositionAffinity.Left):Range {
        if (modelRange.isEmpty()) {
            final start = this.convertModelPositionToViewPosition(modelRange.startLineNumber, modelRange.startColumn, affinity);
            return Range.fromPositions(start);
        } else {
            final start = this.convertModelPositionToViewPosition(modelRange.startLineNumber, modelRange.startColumn, PositionAffinity.Right);
            final end = this.convertModelPositionToViewPosition(modelRange.endLineNumber, modelRange.endColumn, PositionAffinity.Left);
            return new Range(start.lineNumber, start.column, end.lineNumber, end.column);
        }
    }

    public function getViewLineNumberOfModelPosition(modelLineNumber:Int, modelColumn:Int):Int {
        var lineIndex = modelLineNumber - 1;
        if (this.modelLineProjections[lineIndex].isVisible()) {
            // this model line is visible
            final deltaLineNumber = 1 + this.projectedModelLineLineCounts.getPrefixSum(lineIndex);
            return this.modelLineProjections[lineIndex].getViewLineNumberOfModelPosition(deltaLineNumber, modelColumn);
        }

        // this model line is not visible
        while (lineIndex > 0 && !this.modelLineProjections[lineIndex].isVisible()) {
            lineIndex--;
        }
        if (lineIndex == 0 && !this.modelLineProjections[lineIndex].isVisible()) {
            // Could not reach a real line
            return 1;
        }
        final deltaLineNumber = 1 + this.projectedModelLineLineCounts.getPrefixSum(lineIndex);
        return this.modelLineProjections[lineIndex].getViewLineNumberOfModelPosition(deltaLineNumber, this.model.getLineMaxColumn(lineIndex + 1));
    }

    public function getDecorationsInRange(range:Range, ownerId:Int, filterOutValidation:Bool, onlyMinimapDecorations:Bool, onlyMarginDecorations:Bool):Array<IModelDecoration> {
        final modelStart = this.convertViewPositionToModelPosition(range.startLineNumber, range.startColumn);
        final modelEnd = this.convertViewPositionToModelPosition(range.endLineNumber, range.endColumn);

        if (modelEnd.lineNumber - modelStart.lineNumber <= range.endLineNumber - range.startLineNumber) {
            // most likely there are no hidden lines => fast path
            // fetch decorations from column 1 to cover the case of wrapped lines that have whole line decorations at column 1
            return this.model.getDecorationsInRange(new Range(modelStart.lineNumber, 1, modelEnd.lineNumber, modelEnd.column), ownerId, filterOutValidation, onlyMinimapDecorations, onlyMarginDecorations);
        }

        var result:Array<IModelDecoration> = [];
        final modelStartLineIndex = modelStart.lineNumber - 1;
        final modelEndLineIndex = modelEnd.lineNumber - 1;

        var reqStart:Null<Position> = null;
        for (modelLineIndex in modelStartLineIndex...modelEndLineIndex + 1) {
            final line = this.modelLineProjections[modelLineIndex];
            if (line.isVisible()) {
                // merge into previous request
                if (reqStart == null) {
                    reqStart = new Position(modelLineIndex + 1, modelLineIndex == modelStartLineIndex ? modelStart.column : 1);
                }
            } else {
                // hit invisible line => flush request
                if (reqStart != null) {
                    final maxLineColumn = this.model.getLineMaxColumn(modelLineIndex);
                    result = result.concat(this.model.getDecorationsInRange(new Range(reqStart.lineNumber, reqStart.column, modelLineIndex, maxLineColumn), ownerId, filterOutValidation, onlyMinimapDecorations));
                    reqStart = null;
                }
            }
        }

        if (reqStart != null) {
            result = result.concat(this.model.getDecorationsInRange(new Range(reqStart.lineNumber, reqStart.column, modelEnd.lineNumber, modelEnd.column), ownerId, filterOutValidation, onlyMinimapDecorations));
            reqStart = null;
        }

        haxe.ds.ArraySort.sort(result, (a, b) -> {
            final res = Range.compareRangesUsingStarts(a.range, b.range);
            if (res == 0) {
                if (a.id < b.id) {
                    return -1;
                }
                if (a.id > b.id) {
                    return 1;
                }
                return 0;
            }
            return res;
        });

        // Eliminate duplicate decorations that might have intersected our visible ranges multiple times
        final finalResult:Array<IModelDecoration> = [];
        var prevDecId:Null<String> = null;
        for (dec in result) {
            final decId = dec.id;
            if (prevDecId == decId) {
                // skip
                continue;
            }
            prevDecId = decId;
            finalResult.push(dec);
        }

        return finalResult;
    }

    public function getInjectedTextAt(position:Position):Null<InjectedText> {
        final info = this.getViewLineInfo(position.lineNumber);
        return this.modelLineProjections[info.modelLineNumber - 1].getInjectedTextAt(info.modelLineWrappedLineIdx, position.column);
    }

    public function normalizePosition(position:Position, affinity:PositionAffinity):Position {
        final info = this.getViewLineInfo(position.lineNumber);
        return this.modelLineProjections[info.modelLineNumber - 1].normalizePosition(info.modelLineWrappedLineIdx, position, affinity);
    }

    public function getLineIndentColumn(lineNumber:Int):Int {
        final info = this.getViewLineInfo(lineNumber);
        if (info.modelLineWrappedLineIdx == 0) {
            return this.model.getLineIndentColumn(info.modelLineNumber);
        }

        // wrapped lines have no indentation.
        // We deliberately don't handle the case that indentation is wrapped
        // to avoid two view lines reporting indentation for the very same model line.
        return 0;
    }

    /**
     * Cityscape: the projection of a model line (for the renderer and tests).
     */
    public function getModelLineProjection(modelLineNumber:Int):IModelLineProjection {
        return this.modelLineProjections[modelLineNumber - 1];
    }

    /**
     * Overlapping unsorted ranges:
     * [   )      [ )       [  )
     *    [    )      [       )
     * ->
     * Non overlapping sorted ranges:
     * [       )  [ ) [        )
     *
     * Note: This function only considers line information! Columns are ignored.
     */
    static function normalizeLineRanges(ranges:Array<Range>):Array<Range> {
        if (ranges.length == 0) {
            return [];
        }

        final sortedRanges = ranges.copy();
        haxe.ds.ArraySort.sort(sortedRanges, Range.compareRangesUsingStarts);

        final result:Array<Range> = [];
        var currentRangeStart = sortedRanges[0].startLineNumber;
        var currentRangeEnd = sortedRanges[0].endLineNumber;

        for (i in 1...sortedRanges.length) {
            final range = sortedRanges[i];

            if (range.startLineNumber > currentRangeEnd + 1) {
                result.push(new Range(currentRangeStart, 1, currentRangeEnd, 1));
                currentRangeStart = range.startLineNumber;
                currentRangeEnd = range.endLineNumber;
            } else if (range.endLineNumber > currentRangeEnd) {
                currentRangeEnd = range.endLineNumber;
            }
        }
        result.push(new Range(currentRangeStart, 1, currentRangeEnd, 1));
        return result;
    }

}

/**
 * Represents a view line. Can be used to efficiently query more information about it.
 */
private class ViewLineInfo {

    public var isWrappedLineContinuation(get, never):Bool;
    inline function get_isWrappedLineContinuation():Bool {
        return this.modelLineWrappedLineIdx > 0;
    }

    public final modelLineNumber:Int;
    public final modelLineWrappedLineIdx:Int;

    public function new(modelLineNumber:Int, modelLineWrappedLineIdx:Int) {
        this.modelLineNumber = modelLineNumber;
        this.modelLineWrappedLineIdx = modelLineWrappedLineIdx;
    }

}

/**
 * A list of view lines that have a contiguous span in the model.
 */
private class ViewLineInfoGroupedByModelRange {

    public final modelRange:Range;
    public final viewLines:Array<ViewLineInfo>;

    public function new(modelRange:Range, viewLines:Array<ViewLineInfo>) {
        this.modelRange = modelRange;
        this.viewLines = viewLines;
    }

}

class CoordinatesConverter implements ICoordinatesConverter {

    final _lines:ViewModelLinesFromProjectedModel;

    public function new(lines:ViewModelLinesFromProjectedModel) {
        this._lines = lines;
    }

    // View -> Model conversion and related methods

    public function convertViewPositionToModelPosition(viewPosition:Position):Position {
        return this._lines.convertViewPositionToModelPosition(viewPosition.lineNumber, viewPosition.column);
    }

    public function convertViewRangeToModelRange(viewRange:Range):Range {
        return this._lines.convertViewRangeToModelRange(viewRange);
    }

    public function validateViewPosition(viewPosition:Position, expectedModelPosition:Position):Position {
        return this._lines.validateViewPosition(viewPosition.lineNumber, viewPosition.column, expectedModelPosition);
    }

    public function validateViewRange(viewRange:Range, expectedModelRange:Range):Range {
        return this._lines.validateViewRange(viewRange, expectedModelRange);
    }

    // Model -> View conversion and related methods

    public function convertModelPositionToViewPosition(modelPosition:Position, ?affinity:PositionAffinity, ?allowZero:Bool, ?belowHiddenRanges:Bool):Position {
        return this._lines.convertModelPositionToViewPosition(modelPosition.lineNumber, modelPosition.column, affinity == null ? PositionAffinity.None : affinity, allowZero == true, belowHiddenRanges == true);
    }

    public function convertModelRangeToViewRange(modelRange:Range, ?affinity:PositionAffinity):Range {
        return this._lines.convertModelRangeToViewRange(modelRange, affinity == null ? PositionAffinity.Left : affinity);
    }

    public function modelPositionIsVisible(modelPosition:Position):Bool {
        return this._lines.modelPositionIsVisible(modelPosition.lineNumber, modelPosition.column);
    }

    public function getModelLineViewLineCount(modelLineNumber:Int):Int {
        return this._lines.getModelLineViewLineCount(modelLineNumber);
    }

    public function getViewLineNumberOfModelPosition(modelLineNumber:Int, modelColumn:Int):Int {
        return this._lines.getViewLineNumberOfModelPosition(modelLineNumber, modelColumn);
    }

}

enum abstract IndentGuideRepeatOption(Int) from Int to Int {
    var BlockNone = 0;
    var BlockSubsequent = 1;
    var BlockAll = 2;
}

class ViewModelLinesFromModelAsIs implements IViewModelLines {

    public final model:ITextModel;

    public function new(model:ITextModel) {
        this.model = model;
    }

    public function dispose():Void {}

    public function createCoordinatesConverter():ICoordinatesConverter {
        return new IdentityCoordinatesConverter(this);
    }

    public function getHiddenAreas():Array<Range> {
        return [];
    }

    public function setHiddenAreas(_ranges:Array<Range>):Bool {
        return false;
    }

    public function setTabSize(_newTabSize:Int):Bool {
        return false;
    }

    public function setWrappingSettings(_fontInfo:FontInfo, _wrappingStrategy:String, _wrappingColumn:Int, _wrappingIndent:WrappingIndent, _wordBreak:String, ?_wrappingIndentColumns:Int):Bool {
        return false;
    }

    public function createLineBreaksComputer():ILineBreaksComputer {
        return new NullLineBreaksComputer();
    }

    public function onModelFlushed():Void {}

    public function onModelLinesDeleted(_versionId:Null<Int>, fromLineNumber:Int, toLineNumber:Int):Null<ViewLinesDeletedEvent> {
        return new ViewLinesDeletedEvent(fromLineNumber, toLineNumber);
    }

    public function onModelLinesInserted(_versionId:Null<Int>, fromLineNumber:Int, toLineNumber:Int, lineBreaks:Array<Null<ModelLineProjectionData>>):Null<ViewLinesInsertedEvent> {
        return new ViewLinesInsertedEvent(fromLineNumber, toLineNumber);
    }

    public function onModelLineChanged(_versionId:Null<Int>, lineNumber:Int, lineBreakData:Null<ModelLineProjectionData>):ModelLineChangedResult {
        return {lineMappingChanged: false, linesChangedEvent: new ViewLinesChangedEvent(lineNumber, 1), linesInsertedEvent: null, linesDeletedEvent: null};
    }

    public function acceptVersionId(_versionId:Int):Void {}

    public function getViewLineCount():Int {
        return this.model.getLineCount();
    }

    public function getActiveIndentGuide(viewLineNumber:Int, _minLineNumber:Int, _maxLineNumber:Int):IActiveIndentGuideInfo {
        return {
            startLineNumber: viewLineNumber,
            endLineNumber: viewLineNumber,
            indent: 0
        };
    }

    public function getViewLinesBracketGuides(startLineNumber:Int, endLineNumber:Int, activePosition:Null<IPosition>, options:BracketGuideOptions):Array<Array<IndentGuide>> {
        // `new Array(n).fill([])`: the same empty array for every line
        final empty:Array<IndentGuide> = [];
        return [for (_ in 0...endLineNumber - startLineNumber + 1) empty];
    }

    public function getViewLinesIndentGuides(viewStartLineNumber:Int, viewEndLineNumber:Int):Array<Int> {
        final viewLineCount = viewEndLineNumber - viewStartLineNumber + 1;
        return [for (_ in 0...viewLineCount) 0];
    }

    public function getViewLineContent(viewLineNumber:Int):String {
        return this.model.getLineContent(viewLineNumber);
    }

    public function getViewLineLength(viewLineNumber:Int):Int {
        return this.model.getLineLength(viewLineNumber);
    }

    public function getViewLineMinColumn(viewLineNumber:Int):Int {
        return this.model.getLineMinColumn(viewLineNumber);
    }

    public function getViewLineMaxColumn(viewLineNumber:Int):Int {
        return this.model.getLineMaxColumn(viewLineNumber);
    }

    public function getViewLineData(viewLineNumber:Int):ViewLineData {
        final lineTokens = this.model.tokenization.getLineTokens(viewLineNumber);
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

    public function getViewLinesData(viewStartLineNumber:Int, viewEndLineNumber:Int, needed:Array<Bool>):Array<Null<ViewLineData>> {
        final lineCount = this.model.getLineCount();
        viewStartLineNumber = Std.int(Math.min(Math.max(1, viewStartLineNumber), lineCount));
        viewEndLineNumber = Std.int(Math.min(Math.max(1, viewEndLineNumber), lineCount));

        final result:Array<Null<ViewLineData>> = [];
        for (lineNumber in viewStartLineNumber...viewEndLineNumber + 1) {
            final idx = lineNumber - viewStartLineNumber;
            result[idx] = needed[idx] ? this.getViewLineData(lineNumber) : null;
        }

        return result;
    }

    public function getDecorationsInRange(range:Range, ownerId:Int, filterOutValidation:Bool, onlyMinimapDecorations:Bool, onlyMarginDecorations:Bool):Array<IModelDecoration> {
        return this.model.getDecorationsInRange(range, ownerId, filterOutValidation, onlyMinimapDecorations, onlyMarginDecorations);
    }

    public function normalizePosition(position:Position, affinity:PositionAffinity):Position {
        return this.model.normalizePosition(position, affinity);
    }

    public function getLineIndentColumn(lineNumber:Int):Int {
        return this.model.getLineIndentColumn(lineNumber);
    }

    public function getInjectedTextAt(position:Position):Null<InjectedText> {
        // Identity lines collection does not support injected text.
        return null;
    }

}

private class NullLineBreaksComputer implements ILineBreaksComputer {

    final result:Array<Null<ModelLineProjectionData>> = [];

    public function new() {}

    public function addRequest(lineText:String, injectedText:Null<Array<LineInjectedText>>, previousLineBreakData:Null<ModelLineProjectionData>):Void {
        result.push(null);
    }

    public function finalize():Array<Null<ModelLineProjectionData>> {
        return result;
    }

}

class IdentityCoordinatesConverter implements ICoordinatesConverter {

    final _lines:ViewModelLinesFromModelAsIs;

    public function new(lines:ViewModelLinesFromModelAsIs) {
        this._lines = lines;
    }

    function _validPosition(pos:Position):Position {
        return this._lines.model.validatePosition(pos);
    }

    function _validRange(range:Range):Range {
        return this._lines.model.validateRange(range);
    }

    // View -> Model conversion and related methods

    public function convertViewPositionToModelPosition(viewPosition:Position):Position {
        return this._validPosition(viewPosition);
    }

    public function convertViewRangeToModelRange(viewRange:Range):Range {
        return this._validRange(viewRange);
    }

    public function validateViewPosition(_viewPosition:Position, expectedModelPosition:Position):Position {
        return this._validPosition(expectedModelPosition);
    }

    public function validateViewRange(_viewRange:Range, expectedModelRange:Range):Range {
        return this._validRange(expectedModelRange);
    }

    // Model -> View conversion and related methods

    public function convertModelPositionToViewPosition(modelPosition:Position, ?affinity:PositionAffinity, ?allowZeroLineNumber:Bool, ?belowHiddenRanges:Bool):Position {
        return this._validPosition(modelPosition);
    }

    public function convertModelRangeToViewRange(modelRange:Range, ?affinity:PositionAffinity):Range {
        return this._validRange(modelRange);
    }

    public function modelPositionIsVisible(modelPosition:Position):Bool {
        final lineCount = this._lines.model.getLineCount();
        if (modelPosition.lineNumber < 1 || modelPosition.lineNumber > lineCount) {
            // invalid arguments
            return false;
        }
        return true;
    }

    public function modelRangeIsVisible(modelRange:Range):Bool {
        final lineCount = this._lines.model.getLineCount();
        if (modelRange.startLineNumber < 1 || modelRange.startLineNumber > lineCount) {
            // invalid arguments
            return false;
        }
        if (modelRange.endLineNumber < 1 || modelRange.endLineNumber > lineCount) {
            // invalid arguments
            return false;
        }
        return true;
    }

    public function getModelLineViewLineCount(modelLineNumber:Int):Int {
        return 1;
    }

    public function getViewLineNumberOfModelPosition(modelLineNumber:Int, modelColumn:Int):Int {
        return modelLineNumber;
    }

}
