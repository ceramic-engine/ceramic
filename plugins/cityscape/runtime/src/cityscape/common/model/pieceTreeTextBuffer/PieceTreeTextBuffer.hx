// Ported from vscode src/vs/editor/common/model/pieceTreeTextBuffer/pieceTreeTextBuffer.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.pieceTreeTextBuffer;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Strings;
import cityscape.common.Model;
import cityscape.common.core.EolCounter;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.TextChange;
import cityscape.common.model.pieceTreeTextBuffer.PieceTreeBase.StringBuffer;

class IValidatedEditOperation {

    public var sortIndex:Int;

    public var identifier:Null<ISingleEditOperationIdentifier>;

    public var range:Range;

    public var rangeOffset:Int;

    public var rangeLength:Int;

    public var text:String;

    public var eolCount:Int;

    public var firstLineLength:Int;

    public var lastLineLength:Int;

    public var forceMoveMarkers:Bool;

    public var isAutoWhitespaceEdit:Bool;

    public function new(sortIndex:Int, identifier:Null<ISingleEditOperationIdentifier>, range:Range, rangeOffset:Int, rangeLength:Int, text:String, eolCount:Int, firstLineLength:Int, lastLineLength:Int, forceMoveMarkers:Bool, isAutoWhitespaceEdit:Bool) {
        this.sortIndex = sortIndex;
        this.identifier = identifier;
        this.range = range;
        this.rangeOffset = rangeOffset;
        this.rangeLength = rangeLength;
        this.text = text;
        this.eolCount = eolCount;
        this.firstLineLength = firstLineLength;
        this.lastLineLength = lastLineLength;
        this.forceMoveMarkers = forceMoveMarkers;
        this.isAutoWhitespaceEdit = isAutoWhitespaceEdit;
    }

}

/**
 * An undo edit with its sort index (Monaco's `IReverseSingleEditOperation`).
 */
typedef IReverseSingleEditOperation = IValidEditOperation & {
    var sortIndex:Int;
}

class PieceTreeTextBuffer extends Disposable implements ITextBuffer {

    final _pieceTree:PieceTreeBase;

    final _BOM:String;

    var _mightContainRTL:Bool;

    var _mightContainUnusualLineTerminators:Bool;

    var _mightContainNonBasicASCII:Bool;

    final _onDidChangeContent:VoidEmitter;

    public final onDidChangeContent:VoidEvent;

    /**
     * `eol` is `'\r\n'` or `'\n'`.
     */
    public function new(chunks:Array<StringBuffer>, BOM:String, eol:String, containsRTL:Bool, containsUnusualLineTerminators:Bool, isBasicASCII:Bool, eolNormalized:Bool) {
        super();
        this._onDidChangeContent = this._register(new VoidEmitter());
        this.onDidChangeContent = this._onDidChangeContent.event;
        this._BOM = BOM;
        this._mightContainNonBasicASCII = !isBasicASCII;
        this._mightContainRTL = containsRTL;
        this._mightContainUnusualLineTerminators = containsUnusualLineTerminators;
        this._pieceTree = new PieceTreeBase(chunks, eol, eolNormalized);
    }

    // #region TextBuffer

    public function equals(other:ITextBuffer):Bool {
        if (!Std.isOfType(other, PieceTreeTextBuffer)) {
            return false;
        }
        final other:PieceTreeTextBuffer = cast other;
        if (this._BOM != other._BOM) {
            return false;
        }
        if (this.getEOL() != other.getEOL()) {
            return false;
        }
        return this._pieceTree.equal(other._pieceTree);
    }

    public function mightContainRTL():Bool {
        return this._mightContainRTL;
    }

    public function mightContainUnusualLineTerminators():Bool {
        return this._mightContainUnusualLineTerminators;
    }

    public function resetMightContainUnusualLineTerminators():Void {
        this._mightContainUnusualLineTerminators = false;
    }

    public function mightContainNonBasicASCII():Bool {
        return this._mightContainNonBasicASCII;
    }

    public function getBOM():String {
        return this._BOM;
    }

    public function getEOL():String {
        return this._pieceTree.getEOL();
    }

    public function createSnapshot(preserveBOM:Bool):ITextSnapshot {
        return this._pieceTree.createSnapshot(preserveBOM ? this._BOM : '');
    }

    public function getOffsetAt(lineNumber:Int, column:Int):Int {
        return this._pieceTree.getOffsetAt(lineNumber, column);
    }

    public function getPositionAt(offset:Int):Position {
        return this._pieceTree.getPositionAt(offset);
    }

    public function getRangeAt(start:Int, length:Int):Range {
        final end = start + length;
        final startPosition = this.getPositionAt(start);
        final endPosition = this.getPositionAt(end);
        return new Range(startPosition.lineNumber, startPosition.column, endPosition.lineNumber, endPosition.column);
    }

    public function getValueInRange(range:Range, eol:EndOfLinePreference):String {
        if (range.isEmpty()) {
            return '';
        }

        final lineEnding = this._getEndOfLine(eol);
        return this._pieceTree.getValueInRange(range, lineEnding);
    }

    public function getValueLengthInRange(range:Range, eol:EndOfLinePreference):Int {
        if (range.isEmpty()) {
            return 0;
        }

        if (range.startLineNumber == range.endLineNumber) {
            return (range.endColumn - range.startColumn);
        }

        final startOffset = this.getOffsetAt(range.startLineNumber, range.startColumn);
        final endOffset = this.getOffsetAt(range.endLineNumber, range.endColumn);

        // offsets use the text EOL, so we need to compensate for length differences
        // if the requested EOL doesn't match the text EOL
        var eolOffsetCompensation = 0;
        final desiredEOL = this._getEndOfLine(eol);
        final actualEOL = this.getEOL();
        if (desiredEOL.length != actualEOL.length) {
            final delta = desiredEOL.length - actualEOL.length;
            final eolCount = range.endLineNumber - range.startLineNumber;
            eolOffsetCompensation = delta * eolCount;
        }

        return endOffset - startOffset + eolOffsetCompensation;
    }

    public function getCharacterCountInRange(range:Range, eol:EndOfLinePreference):Int {
        if (this._mightContainNonBasicASCII) {
            // we must count by iterating

            var result = 0;

            final fromLineNumber = range.startLineNumber;
            final toLineNumber = range.endLineNumber;
            for (lineNumber in fromLineNumber...toLineNumber + 1) {
                final lineContent = this.getLineContent(lineNumber);
                final fromOffset = (lineNumber == fromLineNumber ? range.startColumn - 1 : 0);
                final toOffset = (lineNumber == toLineNumber ? range.endColumn - 1 : lineContent.length);

                var offset = fromOffset;
                while (offset < toOffset) {
                    if (offset < lineContent.length && Strings.isHighSurrogate(StringTools.fastCodeAt(lineContent, offset))) {
                        result = result + 1;
                        offset = offset + 1;
                    }
                    else {
                        result = result + 1;
                    }
                    offset++;
                }
            }

            result += this._getEndOfLine(eol).length * (toLineNumber - fromLineNumber);

            return result;
        }

        return this.getValueLengthInRange(range, eol);
    }

    public function getNearestChunk(offset:Int):String {
        return this._pieceTree.getNearestChunk(offset);
    }

    public function getLength():Int {
        return this._pieceTree.getLength();
    }

    public function getLineCount():Int {
        return this._pieceTree.getLineCount();
    }

    public function getLinesContent():Array<String> {
        return this._pieceTree.getLinesContent();
    }

    public function getLineContent(lineNumber:Int):String {
        return this._pieceTree.getLineContent(lineNumber);
    }

    public function getLineCharCode(lineNumber:Int, index:Int):Int {
        return this._pieceTree.getLineCharCode(lineNumber, index);
    }

    public function getCharCode(offset:Int):Int {
        return this._pieceTree.getCharCode(offset);
    }

    public function getLineLength(lineNumber:Int):Int {
        return this._pieceTree.getLineLength(lineNumber);
    }

    public function getLineMinColumn(lineNumber:Int):Int {
        return 1;
    }

    public function getLineMaxColumn(lineNumber:Int):Int {
        return this.getLineLength(lineNumber) + 1;
    }

    public function getLineFirstNonWhitespaceColumn(lineNumber:Int):Int {
        final result = Strings.firstNonWhitespaceIndex(this.getLineContent(lineNumber));
        if (result == -1) {
            return 0;
        }
        return result + 1;
    }

    public function getLineLastNonWhitespaceColumn(lineNumber:Int):Int {
        final result = Strings.lastNonWhitespaceIndex(this.getLineContent(lineNumber));
        if (result == -1) {
            return 0;
        }
        return result + 2;
    }

    function _getEndOfLine(eol:EndOfLinePreference):String {
        return switch eol {
            case EndOfLinePreference.LF:
                '\n';
            case EndOfLinePreference.CRLF:
                '\r\n';
            case EndOfLinePreference.TextDefined:
                this.getEOL();
            default:
                throw 'Unknown EOL preference';
        }
    }

    public function setEOL(newEOL:String):Void {
        this._pieceTree.setEOL(newEOL);
    }

    public function applyEdits(rawOperations:Array<ValidAnnotatedEditOperation>, recordTrimAutoWhitespace:Bool, computeUndoEdits:Bool):ApplyEditsResult {
        var mightContainRTL = this._mightContainRTL;
        var mightContainUnusualLineTerminators = this._mightContainUnusualLineTerminators;
        var mightContainNonBasicASCII = this._mightContainNonBasicASCII;
        var canReduceOperations = true;

        var operations:Array<IValidatedEditOperation> = [];
        final eolCounter = new EolCount();
        for (i in 0...rawOperations.length) {
            final op = rawOperations[i];
            if (canReduceOperations && op._isTracked) {
                canReduceOperations = false;
            }
            final validatedRange = op.range;
            final opText = op.text;
            final hasText = (opText != null && opText.length > 0);
            if (hasText) {
                var textMightContainNonBasicASCII = true;
                if (!mightContainNonBasicASCII) {
                    textMightContainNonBasicASCII = !Strings.isBasicASCII(opText);
                    mightContainNonBasicASCII = textMightContainNonBasicASCII;
                }
                if (!mightContainRTL && textMightContainNonBasicASCII) {
                    // check if the new inserted text contains RTL
                    mightContainRTL = Strings.containsRTL(opText);
                }
                if (!mightContainUnusualLineTerminators && textMightContainNonBasicASCII) {
                    // check if the new inserted text contains unusual line terminators
                    mightContainUnusualLineTerminators = Strings.containsUnusualLineTerminators(opText);
                }
            }

            var validText = '';
            var eolCount = 0;
            var firstLineLength = 0;
            var lastLineLength = 0;
            if (hasText) {
                EolCounter.countEOL(opText, eolCounter);
                eolCount = eolCounter.eolCount;
                firstLineLength = eolCounter.firstLineLength;
                lastLineLength = eolCounter.lastLineLength;
                final strEOL = eolCounter.eol;

                final bufferEOL = this.getEOL();
                final expectedStrEOL = (bufferEOL == '\r\n' ? StringEOL.CRLF : StringEOL.LF);
                if (strEOL == StringEOL.Unknown || strEOL == expectedStrEOL) {
                    validText = opText;
                }
                else {
                    validText = Strings.replaceLineBreaks(opText, bufferEOL);
                }
            }

            operations[i] = new IValidatedEditOperation(
                i,
                op.identifier,
                validatedRange,
                this.getOffsetAt(validatedRange.startLineNumber, validatedRange.startColumn),
                this.getValueLengthInRange(validatedRange, EndOfLinePreference.TextDefined),
                validText,
                eolCount,
                firstLineLength,
                lastLineLength,
                op.forceMoveMarkers,
                op.isAutoWhitespaceEdit
            );
        }

        // Sort operations ascending
        operations.sort(PieceTreeTextBuffer._sortOpsAscending);

        var hasTouchingRanges = false;
        for (i in 0...operations.length - 1) {
            final rangeEnd = operations[i].range.getEndPosition();
            final nextRangeStart = operations[i + 1].range.getStartPosition();

            if (nextRangeStart.isBeforeOrEqual(rangeEnd)) {
                if (nextRangeStart.isBefore(rangeEnd)) {
                    // overlapping ranges
                    throw 'Overlapping ranges are not allowed!';
                }
                hasTouchingRanges = true;
            }
        }

        if (canReduceOperations) {
            operations = this._reduceOperations(operations);
        }

        // Delta encode operations
        final reverseRanges = (computeUndoEdits || recordTrimAutoWhitespace ? PieceTreeTextBuffer._getInverseEditRanges(operations) : []);
        final newTrimAutoWhitespaceCandidates:Array<{lineNumber:Int, oldContent:String}> = [];
        if (recordTrimAutoWhitespace) {
            for (i in 0...operations.length) {
                final op = operations[i];
                final reverseRange = reverseRanges[i];

                if (op.isAutoWhitespaceEdit && op.range.isEmpty()) {
                    // Record already the future line numbers that might be auto whitespace removal candidates on next edit
                    for (lineNumber in reverseRange.startLineNumber...reverseRange.endLineNumber + 1) {
                        var currentLineContent = '';
                        if (lineNumber == reverseRange.startLineNumber) {
                            currentLineContent = this.getLineContent(op.range.startLineNumber);
                            if (Strings.firstNonWhitespaceIndex(currentLineContent) != -1) {
                                continue;
                            }
                        }
                        newTrimAutoWhitespaceCandidates.push({lineNumber: lineNumber, oldContent: currentLineContent});
                    }
                }
            }
        }

        var reverseOperations:Null<Array<IReverseSingleEditOperation>> = null;
        if (computeUndoEdits) {

            var reverseRangeDeltaOffset = 0;
            reverseOperations = [];
            for (i in 0...operations.length) {
                final op = operations[i];
                final reverseRange = reverseRanges[i];
                final bufferText = this.getValueInRange(op.range, EndOfLinePreference.TextDefined);
                final reverseRangeOffset = op.rangeOffset + reverseRangeDeltaOffset;
                reverseRangeDeltaOffset += (op.text.length - bufferText.length);

                reverseOperations[i] = {
                    sortIndex: op.sortIndex,
                    identifier: op.identifier,
                    range: reverseRange,
                    text: bufferText,
                    textChange: new TextChange(op.rangeOffset, bufferText, reverseRangeOffset, op.text)
                };
            }

            // Can only sort reverse operations when the order is not significant
            if (!hasTouchingRanges) {
                reverseOperations.sort((a, b) -> a.sortIndex - b.sortIndex);
            }
        }

        this._mightContainRTL = mightContainRTL;
        this._mightContainUnusualLineTerminators = mightContainUnusualLineTerminators;
        this._mightContainNonBasicASCII = mightContainNonBasicASCII;

        final contentChanges = this._doApplyEdits(operations);

        var trimAutoWhitespaceLineNumbers:Null<Array<Int>> = null;
        if (recordTrimAutoWhitespace && newTrimAutoWhitespaceCandidates.length > 0) {
            // sort line numbers auto whitespace removal candidates for next edit descending
            haxe.ds.ArraySort.sort(newTrimAutoWhitespaceCandidates, (a, b) -> b.lineNumber - a.lineNumber);

            trimAutoWhitespaceLineNumbers = [];
            for (i in 0...newTrimAutoWhitespaceCandidates.length) {
                final lineNumber = newTrimAutoWhitespaceCandidates[i].lineNumber;
                if (i > 0 && newTrimAutoWhitespaceCandidates[i - 1].lineNumber == lineNumber) {
                    // Do not have the same line number twice
                    continue;
                }

                final prevContent = newTrimAutoWhitespaceCandidates[i].oldContent;
                final lineContent = this.getLineContent(lineNumber);

                if (lineContent.length == 0 || lineContent == prevContent || Strings.firstNonWhitespaceIndex(lineContent) != -1) {
                    continue;
                }

                trimAutoWhitespaceLineNumbers.push(lineNumber);
            }
        }

        this._onDidChangeContent.fire();

        return new ApplyEditsResult(
            cast reverseOperations,
            contentChanges,
            trimAutoWhitespaceLineNumbers
        );
    }

    /**
     * Transform operations such that they represent the same logic edit,
     * but that they also do not cause OOM crashes.
     */
    function _reduceOperations(operations:Array<IValidatedEditOperation>):Array<IValidatedEditOperation> {
        if (operations.length < 1000) {
            // We know from empirical testing that a thousand edits work fine regardless of their shape.
            return operations;
        }

        // At one point, due to how events are emitted and how each operation is handled,
        // some operations can trigger a high amount of temporary string allocations,
        // that will immediately get edited again.
        // e.g. a formatter inserting ridiculous ammounts of \n on a model with a single line
        // Therefore, the strategy is to collapse all the operations into a huge single edit operation
        return [this._toSingleEditOperation(operations)];
    }

    public function _toSingleEditOperation(operations:Array<IValidatedEditOperation>):IValidatedEditOperation {
        var forceMoveMarkers = false;
        final firstEditRange = operations[0].range;
        final lastEditRange = operations[operations.length - 1].range;
        final entireEditRange = new Range(firstEditRange.startLineNumber, firstEditRange.startColumn, lastEditRange.endLineNumber, lastEditRange.endColumn);
        var lastEndLineNumber = firstEditRange.startLineNumber;
        var lastEndColumn = firstEditRange.startColumn;
        final result = new StringBuf();

        for (i in 0...operations.length) {
            final operation = operations[i];
            final range = operation.range;

            forceMoveMarkers = forceMoveMarkers || operation.forceMoveMarkers;

            // (1) -- Push old text
            result.add(this.getValueInRange(new Range(lastEndLineNumber, lastEndColumn, range.startLineNumber, range.startColumn), EndOfLinePreference.TextDefined));

            // (2) -- Push new text
            if (operation.text.length > 0) {
                result.add(operation.text);
            }

            lastEndLineNumber = range.endLineNumber;
            lastEndColumn = range.endColumn;
        }

        final text = result.toString();
        final count = EolCounter.countEOL(text);

        return new IValidatedEditOperation(
            0,
            operations[0].identifier,
            entireEditRange,
            this.getOffsetAt(entireEditRange.startLineNumber, entireEditRange.startColumn),
            this.getValueLengthInRange(entireEditRange, EndOfLinePreference.TextDefined),
            text,
            count.eolCount,
            count.firstLineLength,
            count.lastLineLength,
            forceMoveMarkers,
            false
        );
    }

    function _doApplyEdits(operations:Array<IValidatedEditOperation>):Array<IInternalModelContentChange> {
        operations.sort(PieceTreeTextBuffer._sortOpsDescending);

        final contentChanges:Array<IInternalModelContentChange> = [];

        // operations are from bottom to top
        for (i in 0...operations.length) {
            final op = operations[i];

            final startLineNumber = op.range.startLineNumber;
            final startColumn = op.range.startColumn;
            final endLineNumber = op.range.endLineNumber;
            final endColumn = op.range.endColumn;

            if (startLineNumber == endLineNumber && startColumn == endColumn && op.text.length == 0) {
                // no-op
                continue;
            }

            if (op.text.length > 0) {
                // replacement
                this._pieceTree.delete(op.rangeOffset, op.rangeLength);
                this._pieceTree.insert(op.rangeOffset, op.text, true);
            }
            else {
                // deletion
                this._pieceTree.delete(op.rangeOffset, op.rangeLength);
            }

            final contentChangeRange = new Range(startLineNumber, startColumn, endLineNumber, endColumn);
            contentChanges.push({
                range: contentChangeRange,
                rangeLength: op.rangeLength,
                text: op.text,
                rangeOffset: op.rangeOffset,
                forceMoveMarkers: op.forceMoveMarkers
            });
        }
        return contentChanges;
    }

    public function findMatchesLineByLine(searchRange:Range, searchData:SearchData, captureMatches:Bool, limitResultCount:Int):Array<FindMatch> {
        return this._pieceTree.findMatchesLineByLine(searchRange, searchData, captureMatches, limitResultCount);
    }

    // #endregion

    // #region helper

    /**
     * testing purpose.
     */
    public function getPieceTree():PieceTreeBase {
        return this._pieceTree;
    }

    public static function _getInverseEditRange(range:Range, text:String):Range {
        final startLineNumber = range.startLineNumber;
        final startColumn = range.startColumn;
        final count = EolCounter.countEOL(text);
        final eolCount = count.eolCount;
        final firstLineLength = count.firstLineLength;
        final lastLineLength = count.lastLineLength;
        var resultRange:Range;

        if (text.length > 0) {
            // the operation inserts something
            final lineCount = eolCount + 1;

            if (lineCount == 1) {
                // single line insert
                resultRange = new Range(startLineNumber, startColumn, startLineNumber, startColumn + firstLineLength);
            }
            else {
                // multi line insert
                resultRange = new Range(startLineNumber, startColumn, startLineNumber + lineCount - 1, lastLineLength + 1);
            }
        }
        else {
            // There is nothing to insert
            resultRange = new Range(startLineNumber, startColumn, startLineNumber, startColumn);
        }

        return resultRange;
    }

    /**
     * Assumes `operations` are validated and sorted ascending
     */
    public static function _getInverseEditRanges(operations:Array<IValidatedEditOperation>):Array<Range> {
        final result:Array<Range> = [];

        var prevOpEndLineNumber:Int = 0;
        var prevOpEndColumn:Int = 0;
        var prevOp:Null<IValidatedEditOperation> = null;
        for (i in 0...operations.length) {
            final op = operations[i];

            var startLineNumber:Int;
            var startColumn:Int;

            if (prevOp != null) {
                if (prevOp.range.endLineNumber == op.range.startLineNumber) {
                    startLineNumber = prevOpEndLineNumber;
                    startColumn = prevOpEndColumn + (op.range.startColumn - prevOp.range.endColumn);
                }
                else {
                    startLineNumber = prevOpEndLineNumber + (op.range.startLineNumber - prevOp.range.endLineNumber);
                    startColumn = op.range.startColumn;
                }
            }
            else {
                startLineNumber = op.range.startLineNumber;
                startColumn = op.range.startColumn;
            }

            var resultRange:Range;

            if (op.text.length > 0) {
                // the operation inserts something
                final lineCount = op.eolCount + 1;

                if (lineCount == 1) {
                    // single line insert
                    resultRange = new Range(startLineNumber, startColumn, startLineNumber, startColumn + op.firstLineLength);
                }
                else {
                    // multi line insert
                    resultRange = new Range(startLineNumber, startColumn, startLineNumber + lineCount - 1, op.lastLineLength + 1);
                }
            }
            else {
                // There is nothing to insert
                resultRange = new Range(startLineNumber, startColumn, startLineNumber, startColumn);
            }

            prevOpEndLineNumber = resultRange.endLineNumber;
            prevOpEndColumn = resultRange.endColumn;

            result.push(resultRange);
            prevOp = op;
        }

        return result;
    }

    static function _sortOpsAscending(a:IValidatedEditOperation, b:IValidatedEditOperation):Int {
        final r = Range.compareRangesUsingEnds(a.range, b.range);
        if (r == 0) {
            return a.sortIndex - b.sortIndex;
        }
        return r;
    }

    static function _sortOpsDescending(a:IValidatedEditOperation, b:IValidatedEditOperation):Int {
        final r = Range.compareRangesUsingEnds(a.range, b.range);
        if (r == 0) {
            return b.sortIndex - a.sortIndex;
        }
        return -r;
    }

    // #endregion

}
