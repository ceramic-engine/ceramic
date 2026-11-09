// Ported from vscode src/vs/editor/common/model/bracketPairsTextModelPart/bracketPairsTree/beforeEditPositionMapper.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree;

import cityscape.common.TextModelEvents.IModelContentChange;
import cityscape.common.core.Range;
import cityscape.common.core.TextLength;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;

class TextEditInfo {

    public static function fromModelContentChanges(changes:Array<IModelContentChange>):Array<TextEditInfo> {
        // Must be sorted in ascending order
        final edits = [for (c in changes) {
            final range = Range.lift(c.range);
            new TextEditInfo(
                Length.positionToLength(range.getStartPosition()),
                Length.positionToLength(range.getEndPosition()),
                Length.lengthOfString(c.text)
            );
        }];
        edits.reverse();
        return edits;
    }

    public final startOffset:Length;
    public final endOffset:Length;
    public final newLength:Length;

    public function new(startOffset:Length, endOffset:Length, newLength:Length) {
        this.startOffset = startOffset;
        this.endOffset = endOffset;
        this.newLength = newLength;
    }

    public function toString():String {
        return '[' + Length.lengthToObj(startOffset) + '...' + Length.lengthToObj(endOffset) + ') -> ' + Length.lengthToObj(newLength);
    }

}

class BeforeEditPositionMapper {

    var nextEditIdx = 0;
    var deltaOldToNewLineCount = 0;
    var deltaOldToNewColumnCount = 0;
    var deltaLineIdxInOld = -1;
    final edits:Array<TextEditInfoCache>;

    /**
     * @param edits Must be sorted by offset in ascending order.
     */
    public function new(edits:Array<TextEditInfo>) {
        this.edits = [for (edit in edits) TextEditInfoCache.from(edit)];
    }

    /**
     * @param offset Must be equal to or greater than the last offset this method has been called with.
     */
    public function getOffsetBeforeChange(offset:Length):Length {
        adjustNextEdit(offset);
        return translateCurToOld(offset);
    }

    /**
     * @param offset Must be equal to or greater than the last offset this method has been called with.
     * Returns null if there is no edit anymore.
     */
    public function getDistanceToNextChange(offset:Length):Null<Length> {
        adjustNextEdit(offset);

        if (nextEditIdx >= edits.length) {
            return null;
        }
        final nextEdit = edits[nextEditIdx];
        final nextChangeOffset = translateOldToCur(nextEdit.offsetObj);

        return Length.lengthDiffNonNegative(offset, nextChangeOffset);
    }

    function translateOldToCur(oldOffsetObj:TextLength):Length {
        if (oldOffsetObj.lineCount == deltaLineIdxInOld) {
            return Length.toLength(oldOffsetObj.lineCount + deltaOldToNewLineCount, oldOffsetObj.columnCount + deltaOldToNewColumnCount);
        }
        else {
            return Length.toLength(oldOffsetObj.lineCount + deltaOldToNewLineCount, oldOffsetObj.columnCount);
        }
    }

    function translateCurToOld(newOffset:Length):Length {
        final offsetObj = Length.lengthToObj(newOffset);
        if (offsetObj.lineCount - deltaOldToNewLineCount == deltaLineIdxInOld) {
            return Length.toLength(offsetObj.lineCount - deltaOldToNewLineCount, offsetObj.columnCount - deltaOldToNewColumnCount);
        }
        else {
            return Length.toLength(offsetObj.lineCount - deltaOldToNewLineCount, offsetObj.columnCount);
        }
    }

    function adjustNextEdit(offset:Length):Void {
        while (nextEditIdx < edits.length) {
            final nextEdit = edits[nextEditIdx];

            // After applying the edit, what is its end offset (considering all previous edits)?
            final nextEditEndOffsetInCur = translateOldToCur(nextEdit.endOffsetAfterObj);

            if (Length.lengthLessThanEqual(nextEditEndOffsetInCur, offset)) {
                // We are after the edit, skip it
                nextEditIdx++;

                final nextEditEndOffsetInCurObj = Length.lengthToObj(nextEditEndOffsetInCur);

                // Before applying the edit, what is its end offset (considering all previous edits)?
                final nextEditEndOffsetBeforeInCurObj = Length.lengthToObj(translateOldToCur(nextEdit.endOffsetBeforeObj));

                final lineDelta = nextEditEndOffsetInCurObj.lineCount - nextEditEndOffsetBeforeInCurObj.lineCount;
                deltaOldToNewLineCount += lineDelta;

                final previousColumnDelta = deltaLineIdxInOld == nextEdit.endOffsetBeforeObj.lineCount ? deltaOldToNewColumnCount : 0;
                final columnDelta = nextEditEndOffsetInCurObj.columnCount - nextEditEndOffsetBeforeInCurObj.columnCount;
                deltaOldToNewColumnCount = previousColumnDelta + columnDelta;
                deltaLineIdxInOld = nextEdit.endOffsetBeforeObj.lineCount;
            }
            else {
                // We are in or before the edit.
                break;
            }
        }
    }

}

private class TextEditInfoCache {

    public static function from(edit:TextEditInfo):TextEditInfoCache {
        return new TextEditInfoCache(edit.startOffset, edit.endOffset, edit.newLength);
    }

    public final endOffsetBeforeObj:TextLength;
    public final endOffsetAfterObj:TextLength;
    public final offsetObj:TextLength;

    public function new(startOffset:Length, endOffset:Length, textLength:Length) {
        endOffsetBeforeObj = Length.lengthToObj(endOffset);
        endOffsetAfterObj = Length.lengthToObj(Length.lengthAdd(startOffset, textLength));
        offsetObj = Length.lengthToObj(startOffset);
    }

}
