// Ported from vscode src/vs/editor/common/viewLayout/linesLayout.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.viewLayout;

import cityscape.base.common.Strings;
import cityscape.common.ViewModel.IEditorWhitespace;
import cityscape.common.ViewModel.IPartialViewLinesViewportData;
import cityscape.common.ViewModel.IViewWhitespaceViewportData;
import cityscape.common.ViewModel.IWhitespaceChangeAccessor;

private typedef IPendingChange = {id:String, newAfterLineNumber:Int, newHeight:Float};
private typedef IPendingRemove = {id:String};

private class PendingChanges {

    var _hasPending:Bool;
    var _inserts:Array<EditorWhitespace>;
    var _changes:Array<IPendingChange>;
    var _removes:Array<IPendingRemove>;

    public function new() {
        this._hasPending = false;
        this._inserts = [];
        this._changes = [];
        this._removes = [];
    }

    public function insert(x:EditorWhitespace):Void {
        this._hasPending = true;
        this._inserts.push(x);
    }

    public function change(x:IPendingChange):Void {
        this._hasPending = true;
        this._changes.push(x);
    }

    public function remove(x:IPendingRemove):Void {
        this._hasPending = true;
        this._removes.push(x);
    }

    public function mustCommit():Bool {
        return this._hasPending;
    }

    public function commit(linesLayout:LinesLayout):Void {
        if (!this._hasPending) {
            return;
        }

        final inserts = this._inserts;
        final changes = this._changes;
        final removes = this._removes;

        this._hasPending = false;
        this._inserts = [];
        this._changes = [];
        this._removes = [];

        linesLayout._commitPendingChanges(inserts, changes, removes);
    }

}

class EditorWhitespace {

    public var id:String;
    public var afterLineNumber:Int;
    public var ordinal:Int;
    public var height:Float;
    public var minWidth:Float;
    public var prefixSum:Float;

    public function new(id:String, afterLineNumber:Int, ordinal:Int, height:Float, minWidth:Float) {
        this.id = id;
        this.afterLineNumber = afterLineNumber;
        this.ordinal = ordinal;
        this.height = height;
        this.minWidth = minWidth;
        this.prefixSum = 0;
    }

    public function toEditorWhitespace():IEditorWhitespace {
        return {id: id, afterLineNumber: afterLineNumber, height: height};
    }

}

private class WhitespaceChangeAccessor implements IWhitespaceChangeAccessor {

    final layout:LinesLayout;

    public var hadAChange:Bool = false;

    public function new(layout:LinesLayout) {
        this.layout = layout;
    }

    public function insertWhitespace(afterLineNumber:Int, ordinal:Int, heightInPx:Float, minWidth:Float):String {
        hadAChange = true;
        return layout._insertPending(afterLineNumber, ordinal, LinesLayout.toInt32(heightInPx), LinesLayout.toInt32(minWidth));
    }

    public function changeOneWhitespace(id:String, newAfterLineNumber:Int, newHeight:Float):Void {
        hadAChange = true;
        layout._changePending(id, newAfterLineNumber, LinesLayout.toInt32(newHeight));
    }

    public function removeWhitespace(id:String):Void {
        hadAChange = true;
        layout._removePending(id);
    }

}

/**
 * Layouting of objects that take vertical space (by having a height) and push down other objects.
 *
 * These objects are basically either text (lines) or spaces between those lines (whitespaces).
 * This provides commodity operations for working with lines that contain whitespace that pushes lines lower (vertically).
 */
class LinesLayout {

    static var INSTANCE_COUNT = 0;

    final _instanceId:String;
    final _pendingChanges:PendingChanges;
    var _lastWhitespaceId:Int;
    var _arr:Array<EditorWhitespace>;
    var _prefixSumValidIndex:Int;
    var _minWidth:Float;
    var _lineCount:Int;
    var _lineHeight:Float;
    var _paddingTop:Float;
    var _paddingBottom:Float;

    public function new(lineCount:Int, lineHeight:Float, paddingTop:Float, paddingBottom:Float) {
        this._instanceId = Strings.singleLetterHash(++LinesLayout.INSTANCE_COUNT);
        this._pendingChanges = new PendingChanges();
        this._lastWhitespaceId = 0;
        this._arr = [];
        this._prefixSumValidIndex = -1;
        this._minWidth = -1; /* marker for not being computed */
        this._lineCount = lineCount;
        this._lineHeight = lineHeight;
        this._paddingTop = paddingTop;
        this._paddingBottom = paddingBottom;
    }

    /**
     * `x | 0` in JavaScript.
     */
    @:noCompletion public static inline function toInt32(value:Float):Int {
        return Math.isNaN(value) || !Math.isFinite(value) ? 0 : Std.int(value);
    }

    /**
     * Find the insertion index for a new value inside a sorted array of values.
     * If the value is already present in the sorted array, the insertion index will be after the already existing value.
     */
    public static function findInsertionIndex(arr:Array<EditorWhitespace>, afterLineNumber:Int, ordinal:Int):Int {
        var low = 0;
        var high = arr.length;

        while (low < high) {
            final mid = ((low + high) >>> 1);

            if (afterLineNumber == arr[mid].afterLineNumber) {
                if (ordinal < arr[mid].ordinal) {
                    high = mid;
                } else {
                    low = mid + 1;
                }
            } else if (afterLineNumber < arr[mid].afterLineNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return low;
    }

    /**
     * Change the height of a line in pixels.
     */
    public function setLineHeight(lineHeight:Float):Void {
        this._checkPendingChanges();
        this._lineHeight = lineHeight;
    }

    /**
     * Changes the padding used to calculate vertical offsets.
     */
    public function setPadding(paddingTop:Float, paddingBottom:Float):Void {
        this._paddingTop = paddingTop;
        this._paddingBottom = paddingBottom;
    }

    /**
     * Set the number of lines.
     *
     * @param lineCount New number of lines.
     */
    public function onFlushed(lineCount:Int):Void {
        this._checkPendingChanges();
        this._lineCount = lineCount;
    }

    public function changeWhitespace(callback:(accessor:IWhitespaceChangeAccessor) -> Void):Bool {
        final accessor = new WhitespaceChangeAccessor(this);
        try {
            callback(accessor);
        } catch (e:haxe.Exception) {
            this._pendingChanges.commit(this);
            throw e;
        }
        this._pendingChanges.commit(this);
        return accessor.hadAChange;
    }

    @:allow(cityscape.common.viewLayout.WhitespaceChangeAccessor)
    function _insertPending(afterLineNumber:Int, ordinal:Int, heightInPx:Float, minWidth:Float):String {
        final id = this._instanceId + (++this._lastWhitespaceId);
        this._pendingChanges.insert(new EditorWhitespace(id, afterLineNumber, ordinal, heightInPx, minWidth));
        return id;
    }

    @:allow(cityscape.common.viewLayout.WhitespaceChangeAccessor)
    function _changePending(id:String, newAfterLineNumber:Int, newHeight:Float):Void {
        this._pendingChanges.change({id: id, newAfterLineNumber: newAfterLineNumber, newHeight: newHeight});
    }

    @:allow(cityscape.common.viewLayout.WhitespaceChangeAccessor)
    function _removePending(id:String):Void {
        this._pendingChanges.remove({id: id});
    }

    public function _commitPendingChanges(inserts:Array<EditorWhitespace>, changes:Array<IPendingChange>, removes:Array<IPendingRemove>):Void {
        if (inserts.length > 0 || removes.length > 0) {
            this._minWidth = -1; /* marker for not being computed */
        }

        if (inserts.length + changes.length + removes.length <= 1) {
            // when only one thing happened, handle it "delicately"
            for (insert in inserts) {
                this._insertWhitespace(insert);
            }
            for (change in changes) {
                this._changeOneWhitespace(change.id, change.newAfterLineNumber, change.newHeight);
            }
            for (remove in removes) {
                final index = this._findWhitespaceIndex(remove.id);
                if (index == -1) {
                    continue;
                }
                this._removeWhitespace(index);
            }
            return;
        }

        // simply rebuild the entire datastructure

        final toRemove = new Map<String, Bool>();
        for (remove in removes) {
            toRemove.set(remove.id, true);
        }

        final toChange = new Map<String, IPendingChange>();
        for (change in changes) {
            toChange.set(change.id, change);
        }

        final applyRemoveAndChange = (whitespaces:Array<EditorWhitespace>) -> {
            final result:Array<EditorWhitespace> = [];
            for (whitespace in whitespaces) {
                if (toRemove.exists(whitespace.id)) {
                    continue;
                }
                if (toChange.exists(whitespace.id)) {
                    final change = toChange.get(whitespace.id);
                    whitespace.afterLineNumber = change.newAfterLineNumber;
                    whitespace.height = change.newHeight;
                }
                result.push(whitespace);
            }
            return result;
        };

        final result = applyRemoveAndChange(this._arr).concat(applyRemoveAndChange(inserts));
        haxe.ds.ArraySort.sort(result, (a, b) -> {
            if (a.afterLineNumber == b.afterLineNumber) {
                return a.ordinal - b.ordinal;
            }
            return a.afterLineNumber - b.afterLineNumber;
        });

        this._arr = result;
        this._prefixSumValidIndex = -1;
    }

    function _checkPendingChanges():Void {
        if (this._pendingChanges.mustCommit()) {
            this._pendingChanges.commit(this);
        }
    }

    function _insertWhitespace(whitespace:EditorWhitespace):Void {
        final insertIndex = LinesLayout.findInsertionIndex(this._arr, whitespace.afterLineNumber, whitespace.ordinal);
        this._arr.insert(insertIndex, whitespace);
        if (insertIndex - 1 < this._prefixSumValidIndex) {
            this._prefixSumValidIndex = insertIndex - 1;
        }
    }

    function _findWhitespaceIndex(id:String):Int {
        final arr = this._arr;
        for (i in 0...arr.length) {
            if (arr[i].id == id) {
                return i;
            }
        }
        return -1;
    }

    function _changeOneWhitespace(id:String, newAfterLineNumber:Int, newHeight:Float):Void {
        final index = this._findWhitespaceIndex(id);
        if (index == -1) {
            return;
        }
        if (this._arr[index].height != newHeight) {
            this._arr[index].height = newHeight;
            if (index - 1 < this._prefixSumValidIndex) {
                this._prefixSumValidIndex = index - 1;
            }
        }
        if (this._arr[index].afterLineNumber != newAfterLineNumber) {
            // `afterLineNumber` changed for this whitespace

            // Record old whitespace
            final whitespace = this._arr[index];

            // Since changing `afterLineNumber` can trigger a reordering, we're gonna remove this whitespace
            this._removeWhitespace(index);

            whitespace.afterLineNumber = newAfterLineNumber;

            // And add it again
            this._insertWhitespace(whitespace);
        }
    }

    function _removeWhitespace(removeIndex:Int):Void {
        this._arr.splice(removeIndex, 1);
        if (removeIndex - 1 < this._prefixSumValidIndex) {
            this._prefixSumValidIndex = removeIndex - 1;
        }
    }

    /**
     * Notify the layouter that lines have been deleted (a continuous zone of lines).
     *
     * @param fromLineNumber The line number at which the deletion started, inclusive
     * @param toLineNumber The line number at which the deletion ended, inclusive
     */
    public function onLinesDeleted(fromLineNumber:Int, toLineNumber:Int):Void {
        this._checkPendingChanges();

        this._lineCount -= (toLineNumber - fromLineNumber + 1);
        for (i in 0...this._arr.length) {
            final afterLineNumber = this._arr[i].afterLineNumber;

            if (fromLineNumber <= afterLineNumber && afterLineNumber <= toLineNumber) {
                // The line this whitespace was after has been deleted
                //  => move whitespace to before first deleted line
                this._arr[i].afterLineNumber = fromLineNumber - 1;
            } else if (afterLineNumber > toLineNumber) {
                // The line this whitespace was after has been moved up
                //  => move whitespace up
                this._arr[i].afterLineNumber -= (toLineNumber - fromLineNumber + 1);
            }
        }
    }

    /**
     * Notify the layouter that lines have been inserted (a continuous zone of lines).
     *
     * @param fromLineNumber The line number at which the insertion started, inclusive
     * @param toLineNumber The line number at which the insertion ended, inclusive.
     */
    public function onLinesInserted(fromLineNumber:Int, toLineNumber:Int):Void {
        this._checkPendingChanges();

        this._lineCount += (toLineNumber - fromLineNumber + 1);
        for (i in 0...this._arr.length) {
            final afterLineNumber = this._arr[i].afterLineNumber;

            if (fromLineNumber <= afterLineNumber) {
                this._arr[i].afterLineNumber += (toLineNumber - fromLineNumber + 1);
            }
        }
    }

    /**
     * Get the sum of all the whitespaces.
     */
    public function getWhitespacesTotalHeight():Float {
        this._checkPendingChanges();
        if (this._arr.length == 0) {
            return 0;
        }
        return this.getWhitespacesAccumulatedHeight(this._arr.length - 1);
    }

    /**
     * Return the sum of the heights of the whitespaces at [0..index].
     * This includes the whitespace at `index`.
     *
     * @param index The index of the whitespace.
     * @return The sum of the heights of all whitespaces before the one at `index`, including the one at `index`.
     */
    public function getWhitespacesAccumulatedHeight(index:Int):Float {
        this._checkPendingChanges();

        var startIndex = (this._prefixSumValidIndex + 1 > 0 ? this._prefixSumValidIndex + 1 : 0);
        if (startIndex == 0) {
            this._arr[0].prefixSum = this._arr[0].height;
            startIndex++;
        }

        for (i in startIndex...index + 1) {
            this._arr[i].prefixSum = this._arr[i - 1].prefixSum + this._arr[i].height;
        }
        if (index > this._prefixSumValidIndex) {
            this._prefixSumValidIndex = index;
        }
        return this._arr[index].prefixSum;
    }

    /**
     * Get the sum of heights for all objects.
     *
     * @return The sum of heights for all objects.
     */
    public function getLinesTotalHeight():Float {
        this._checkPendingChanges();
        final linesHeight = this._lineHeight * this._lineCount;
        final whitespacesHeight = this.getWhitespacesTotalHeight();

        return linesHeight + whitespacesHeight + this._paddingTop + this._paddingBottom;
    }

    /**
     * Returns the accumulated height of whitespaces before the given line number.
     *
     * @param lineNumber The line number
     */
    public function getWhitespaceAccumulatedHeightBeforeLineNumber(lineNumber:Int):Float {
        this._checkPendingChanges();

        final lastWhitespaceBeforeLineNumber = this._findLastWhitespaceBeforeLineNumber(lineNumber);

        if (lastWhitespaceBeforeLineNumber == -1) {
            return 0;
        }

        return this.getWhitespacesAccumulatedHeight(lastWhitespaceBeforeLineNumber);
    }

    function _findLastWhitespaceBeforeLineNumber(lineNumber:Int):Int {
        // Find the whitespace before line number
        final arr = this._arr;
        var low = 0;
        var high = arr.length - 1;

        while (low <= high) {
            final delta = (high - low);
            final halfDelta = Std.int(delta / 2);
            final mid = (low + halfDelta);

            if (arr[mid].afterLineNumber < lineNumber) {
                if (mid + 1 >= arr.length || arr[mid + 1].afterLineNumber >= lineNumber) {
                    return mid;
                } else {
                    low = (mid + 1);
                }
            } else {
                high = (mid - 1);
            }
        }

        return -1;
    }

    function _findFirstWhitespaceAfterLineNumber(lineNumber:Int):Int {
        final lastWhitespaceBeforeLineNumber = this._findLastWhitespaceBeforeLineNumber(lineNumber);
        final firstWhitespaceAfterLineNumber = lastWhitespaceBeforeLineNumber + 1;

        if (firstWhitespaceAfterLineNumber < this._arr.length) {
            return firstWhitespaceAfterLineNumber;
        }

        return -1;
    }

    /**
     * Find the index of the first whitespace which has `afterLineNumber` >= `lineNumber`.
     * @return The index of the first whitespace with `afterLineNumber` >= `lineNumber` or -1 if no whitespace is found.
     */
    public function getFirstWhitespaceIndexAfterLineNumber(lineNumber:Int):Int {
        this._checkPendingChanges();
        return this._findFirstWhitespaceAfterLineNumber(lineNumber);
    }

    /**
     * Get the vertical offset (the sum of heights for all objects above) a certain line number.
     *
     * @param lineNumber The line number
     * @return The sum of heights for all objects above `lineNumber`.
     */
    public function getVerticalOffsetForLineNumber(lineNumber:Int, includeViewZones:Bool = false):Float {
        this._checkPendingChanges();

        var previousLinesHeight:Float;
        if (lineNumber > 1) {
            previousLinesHeight = this._lineHeight * (lineNumber - 1);
        } else {
            previousLinesHeight = 0;
        }

        final previousWhitespacesHeight = this.getWhitespaceAccumulatedHeightBeforeLineNumber(lineNumber - (includeViewZones ? 1 : 0));

        return previousLinesHeight + previousWhitespacesHeight + this._paddingTop;
    }

    /**
     * Get the vertical offset (the sum of heights for all objects above) a certain line number.
     *
     * @param lineNumber The line number
     * @return The sum of heights for all objects above `lineNumber`.
     */
    public function getVerticalOffsetAfterLineNumber(lineNumber:Int, includeViewZones:Bool = false):Float {
        this._checkPendingChanges();
        final previousLinesHeight = this._lineHeight * lineNumber;
        final previousWhitespacesHeight = this.getWhitespaceAccumulatedHeightBeforeLineNumber(lineNumber + (includeViewZones ? 1 : 0));
        return previousLinesHeight + previousWhitespacesHeight + this._paddingTop;
    }

    /**
     * Returns if there is any whitespace in the document.
     */
    public function hasWhitespace():Bool {
        this._checkPendingChanges();
        return this.getWhitespacesCount() > 0;
    }

    /**
     * The maximum min width for all whitespaces.
     */
    public function getWhitespaceMinWidth():Float {
        this._checkPendingChanges();
        if (this._minWidth == -1) {
            var minWidth:Float = 0;
            for (i in 0...this._arr.length) {
                minWidth = Math.max(minWidth, this._arr[i].minWidth);
            }
            this._minWidth = minWidth;
        }
        return this._minWidth;
    }

    /**
     * Check if `verticalOffset` is below all lines.
     */
    public function isAfterLines(verticalOffset:Float):Bool {
        this._checkPendingChanges();
        final totalHeight = this.getLinesTotalHeight();
        return verticalOffset > totalHeight;
    }

    public function isInTopPadding(verticalOffset:Float):Bool {
        if (this._paddingTop == 0) {
            return false;
        }
        this._checkPendingChanges();
        return (verticalOffset < this._paddingTop);
    }

    public function isInBottomPadding(verticalOffset:Float):Bool {
        if (this._paddingBottom == 0) {
            return false;
        }
        this._checkPendingChanges();
        final totalHeight = this.getLinesTotalHeight();
        return (verticalOffset >= totalHeight - this._paddingBottom);
    }

    /**
     * Find the first line number that is at or after vertical offset `verticalOffset`.
     * i.e. if getVerticalOffsetForLine(line) is x and getVerticalOffsetForLine(line + 1) is y, then
     * getLineNumberAtOrAfterVerticalOffset(i) = line, x <= i < y.
     *
     * @param verticalOffset The vertical offset to search at.
     * @return The line number at or after vertical offset `verticalOffset`.
     */
    public function getLineNumberAtOrAfterVerticalOffset(verticalOffset:Float):Int {
        this._checkPendingChanges();
        final verticalOffset = toInt32(verticalOffset);

        if (verticalOffset < 0) {
            return 1;
        }

        final linesCount = this._lineCount;
        final lineHeight = this._lineHeight;
        var minLineNumber = 1;
        var maxLineNumber = linesCount;

        while (minLineNumber < maxLineNumber) {
            final midLineNumber = Std.int((minLineNumber + maxLineNumber) / 2);

            final midLineNumberVerticalOffset = toInt32(this.getVerticalOffsetForLineNumber(midLineNumber));

            if (verticalOffset >= midLineNumberVerticalOffset + lineHeight) {
                // vertical offset is after mid line number
                minLineNumber = midLineNumber + 1;
            } else if (verticalOffset >= midLineNumberVerticalOffset) {
                // Hit
                return midLineNumber;
            } else {
                // vertical offset is before mid line number, but mid line number could still be what we're searching for
                maxLineNumber = midLineNumber;
            }
        }

        if (minLineNumber > linesCount) {
            return linesCount;
        }

        return minLineNumber;
    }

    /**
     * Get all the lines and their relative vertical offsets that are positioned between `verticalOffset1` and `verticalOffset2`.
     *
     * @param verticalOffset1 The beginning of the viewport.
     * @param verticalOffset2 The end of the viewport.
     * @return A structure describing the lines positioned between `verticalOffset1` and `verticalOffset2`.
     */
    public function getLinesViewportData(verticalOffset1:Float, verticalOffset2:Float):IPartialViewLinesViewportData {
        this._checkPendingChanges();
        final verticalOffset1 = toInt32(verticalOffset1);
        final verticalOffset2 = toInt32(verticalOffset2);
        final lineHeight = this._lineHeight;

        // Find first line number
        // We don't live in a perfect world, so the line number might start before or after verticalOffset1
        final startLineNumber = this.getLineNumberAtOrAfterVerticalOffset(verticalOffset1);
        final startLineNumberVerticalOffset = toInt32(this.getVerticalOffsetForLineNumber(startLineNumber));

        var endLineNumber = this._lineCount;

        // Also keep track of what whitespace we've got
        var whitespaceIndex = this.getFirstWhitespaceIndexAfterLineNumber(startLineNumber);
        final whitespaceCount = this.getWhitespacesCount();
        var currentWhitespaceHeight:Float;
        var currentWhitespaceAfterLineNumber:Int;

        if (whitespaceIndex == -1) {
            whitespaceIndex = whitespaceCount;
            currentWhitespaceAfterLineNumber = endLineNumber + 1;
            currentWhitespaceHeight = 0;
        } else {
            currentWhitespaceAfterLineNumber = this.getAfterLineNumberForWhitespaceIndex(whitespaceIndex);
            currentWhitespaceHeight = toInt32(this.getHeightForWhitespaceIndex(whitespaceIndex));
        }

        var currentVerticalOffset:Float = startLineNumberVerticalOffset;
        var currentLineRelativeOffset:Float = currentVerticalOffset;

        // IE (all versions) cannot handle units above about 1,533,908 px, so every 500k pixels bring numbers down
        final STEP_SIZE = 500000;
        var bigNumbersDelta:Float = 0;
        if (startLineNumberVerticalOffset >= STEP_SIZE) {
            // Compute a delta that guarantees that lines are positioned at `lineHeight` increments
            bigNumbersDelta = Math.floor(startLineNumberVerticalOffset / STEP_SIZE) * STEP_SIZE;
            bigNumbersDelta = Math.floor(bigNumbersDelta / lineHeight) * lineHeight;

            currentLineRelativeOffset -= bigNumbersDelta;
        }

        final linesOffsets:Array<Float> = [];

        final verticalCenter = verticalOffset1 + (verticalOffset2 - verticalOffset1) / 2;
        var centeredLineNumber = -1;

        // Figure out how far the lines go
        var lineNumber = startLineNumber;
        while (lineNumber <= endLineNumber) {

            if (centeredLineNumber == -1) {
                final currentLineTop = currentVerticalOffset;
                final currentLineBottom = currentVerticalOffset + lineHeight;
                if ((currentLineTop <= verticalCenter && verticalCenter < currentLineBottom) || currentLineTop > verticalCenter) {
                    centeredLineNumber = lineNumber;
                }
            }

            // Count current line height in the vertical offsets
            currentVerticalOffset += lineHeight;
            linesOffsets[lineNumber - startLineNumber] = currentLineRelativeOffset;

            // Next line starts immediately after this one
            currentLineRelativeOffset += lineHeight;
            while (currentWhitespaceAfterLineNumber == lineNumber) {
                // Push down next line with the height of the current whitespace
                currentLineRelativeOffset += currentWhitespaceHeight;

                // Count current whitespace in the vertical offsets
                currentVerticalOffset += currentWhitespaceHeight;
                whitespaceIndex++;

                if (whitespaceIndex >= whitespaceCount) {
                    currentWhitespaceAfterLineNumber = endLineNumber + 1;
                } else {
                    currentWhitespaceAfterLineNumber = this.getAfterLineNumberForWhitespaceIndex(whitespaceIndex);
                    currentWhitespaceHeight = toInt32(this.getHeightForWhitespaceIndex(whitespaceIndex));
                }
            }

            if (currentVerticalOffset >= verticalOffset2) {
                // We have covered the entire viewport area, time to stop
                endLineNumber = lineNumber;
                break;
            }
            lineNumber++;
        }

        if (centeredLineNumber == -1) {
            centeredLineNumber = endLineNumber;
        }

        final endLineNumberVerticalOffset = toInt32(this.getVerticalOffsetForLineNumber(endLineNumber));

        var completelyVisibleStartLineNumber = startLineNumber;
        var completelyVisibleEndLineNumber = endLineNumber;

        if (completelyVisibleStartLineNumber < completelyVisibleEndLineNumber) {
            if (startLineNumberVerticalOffset < verticalOffset1) {
                completelyVisibleStartLineNumber++;
            }
        }
        if (completelyVisibleStartLineNumber < completelyVisibleEndLineNumber) {
            if (endLineNumberVerticalOffset + lineHeight > verticalOffset2) {
                completelyVisibleEndLineNumber--;
            }
        }

        return {
            bigNumbersDelta: bigNumbersDelta,
            startLineNumber: startLineNumber,
            endLineNumber: endLineNumber,
            relativeVerticalOffset: linesOffsets,
            centeredLineNumber: centeredLineNumber,
            completelyVisibleStartLineNumber: completelyVisibleStartLineNumber,
            completelyVisibleEndLineNumber: completelyVisibleEndLineNumber,
            lineHeight: this._lineHeight,
        };
    }

    public function getVerticalOffsetForWhitespaceIndex(whitespaceIndex:Int):Float {
        this._checkPendingChanges();

        final afterLineNumber = this.getAfterLineNumberForWhitespaceIndex(whitespaceIndex);

        var previousLinesHeight:Float;
        if (afterLineNumber >= 1) {
            previousLinesHeight = this._lineHeight * afterLineNumber;
        } else {
            previousLinesHeight = 0;
        }

        var previousWhitespacesHeight:Float;
        if (whitespaceIndex > 0) {
            previousWhitespacesHeight = this.getWhitespacesAccumulatedHeight(whitespaceIndex - 1);
        } else {
            previousWhitespacesHeight = 0;
        }
        return previousLinesHeight + previousWhitespacesHeight + this._paddingTop;
    }

    public function getWhitespaceIndexAtOrAfterVerticallOffset(verticalOffset:Float):Int {
        this._checkPendingChanges();
        final verticalOffset = toInt32(verticalOffset);

        var minWhitespaceIndex = 0;
        var maxWhitespaceIndex = this.getWhitespacesCount() - 1;

        if (maxWhitespaceIndex < 0) {
            return -1;
        }

        // Special case: nothing to be found
        final maxWhitespaceVerticalOffset = this.getVerticalOffsetForWhitespaceIndex(maxWhitespaceIndex);
        final maxWhitespaceHeight = this.getHeightForWhitespaceIndex(maxWhitespaceIndex);
        if (verticalOffset >= maxWhitespaceVerticalOffset + maxWhitespaceHeight) {
            return -1;
        }

        while (minWhitespaceIndex < maxWhitespaceIndex) {
            final midWhitespaceIndex = Std.int(Math.floor((minWhitespaceIndex + maxWhitespaceIndex) / 2));

            final midWhitespaceVerticalOffset = this.getVerticalOffsetForWhitespaceIndex(midWhitespaceIndex);
            final midWhitespaceHeight = this.getHeightForWhitespaceIndex(midWhitespaceIndex);

            if (verticalOffset >= midWhitespaceVerticalOffset + midWhitespaceHeight) {
                // vertical offset is after whitespace
                minWhitespaceIndex = midWhitespaceIndex + 1;
            } else if (verticalOffset >= midWhitespaceVerticalOffset) {
                // Hit
                return midWhitespaceIndex;
            } else {
                // vertical offset is before whitespace, but midWhitespaceIndex might still be what we're searching for
                maxWhitespaceIndex = midWhitespaceIndex;
            }
        }
        return minWhitespaceIndex;
    }

    /**
     * Get exactly the whitespace that is layouted at `verticalOffset`.
     *
     * @param verticalOffset The vertical offset.
     * @return Precisely the whitespace that is layouted at `verticaloffset` or null.
     */
    public function getWhitespaceAtVerticalOffset(verticalOffset:Float):Null<IViewWhitespaceViewportData> {
        this._checkPendingChanges();
        final verticalOffset = toInt32(verticalOffset);

        final candidateIndex = this.getWhitespaceIndexAtOrAfterVerticallOffset(verticalOffset);

        if (candidateIndex < 0) {
            return null;
        }

        if (candidateIndex >= this.getWhitespacesCount()) {
            return null;
        }

        final candidateTop = this.getVerticalOffsetForWhitespaceIndex(candidateIndex);

        if (candidateTop > verticalOffset) {
            return null;
        }

        final candidateHeight = this.getHeightForWhitespaceIndex(candidateIndex);
        final candidateId = this.getIdForWhitespaceIndex(candidateIndex);
        final candidateAfterLineNumber = this.getAfterLineNumberForWhitespaceIndex(candidateIndex);

        return {
            id: candidateId,
            afterLineNumber: candidateAfterLineNumber,
            verticalOffset: candidateTop,
            height: candidateHeight
        };
    }

    /**
     * Get a list of whitespaces that are positioned between `verticalOffset1` and `verticalOffset2`.
     *
     * @param verticalOffset1 The beginning of the viewport.
     * @param verticalOffset2 The end of the viewport.
     * @return An array with all the whitespaces in the viewport. If no whitespace is in viewport, the array is empty.
     */
    public function getWhitespaceViewportData(verticalOffset1:Float, verticalOffset2:Float):Array<IViewWhitespaceViewportData> {
        this._checkPendingChanges();
        final verticalOffset1 = toInt32(verticalOffset1);
        final verticalOffset2 = toInt32(verticalOffset2);

        final startIndex = this.getWhitespaceIndexAtOrAfterVerticallOffset(verticalOffset1);
        final endIndex = this.getWhitespacesCount() - 1;

        if (startIndex < 0) {
            return [];
        }

        final result:Array<IViewWhitespaceViewportData> = [];
        for (i in startIndex...endIndex + 1) {
            final top = this.getVerticalOffsetForWhitespaceIndex(i);
            final height = this.getHeightForWhitespaceIndex(i);
            if (top >= verticalOffset2) {
                break;
            }

            result.push({
                id: this.getIdForWhitespaceIndex(i),
                afterLineNumber: this.getAfterLineNumberForWhitespaceIndex(i),
                verticalOffset: top,
                height: height
            });
        }

        return result;
    }

    /**
     * Get all whitespaces.
     */
    public function getWhitespaces():Array<IEditorWhitespace> {
        this._checkPendingChanges();
        return [for (w in this._arr) w.toEditorWhitespace()];
    }

    /**
     * The number of whitespaces.
     */
    public function getWhitespacesCount():Int {
        this._checkPendingChanges();
        return this._arr.length;
    }

    /**
     * Get the `id` for whitespace at index `index`.
     *
     * @param index The index of the whitespace.
     * @return `id` of whitespace at `index`.
     */
    public function getIdForWhitespaceIndex(index:Int):String {
        this._checkPendingChanges();
        return this._arr[index].id;
    }

    /**
     * Get the `afterLineNumber` for whitespace at index `index`.
     *
     * @param index The index of the whitespace.
     * @return `afterLineNumber` of whitespace at `index`.
     */
    public function getAfterLineNumberForWhitespaceIndex(index:Int):Int {
        this._checkPendingChanges();
        return this._arr[index].afterLineNumber;
    }

    /**
     * Get the `height` for whitespace at index `index`.
     *
     * @param index The index of the whitespace.
     * @return `height` of whitespace at `index`.
     */
    public function getHeightForWhitespaceIndex(index:Int):Float {
        this._checkPendingChanges();
        return this._arr[index].height;
    }

}
