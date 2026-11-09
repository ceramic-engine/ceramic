// Ported from vscode src/vs/base/common/diff/diff.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common.diff;

import cityscape.base.common.Hash;
import cityscape.base.common.Strings;
import haxe.extern.EitherType;

/**
 * A sequence of elements to diff: numbers, or strings (hashed, then compared).
 *
 * Monaco's `getElements(): Int32Array | number[] | string[]` returns an
 * `Array<Int>` or an `Array<String>` here; its optional `getStrictElement`
 * returns null in the sequences that have none (Monaco then compares
 * `null` with `null`).
 */
interface ISequence {
    function getElements():EitherType<Array<Int>, Array<String>>;
    function getStrictElement(index:Int):Null<String>;
}

/**
 * The change of a diff (`DiffChange` implements it).
 */
typedef IDiffChange = DiffChange;

/**
 * Called during the computation: return false to stop it early.
 */
typedef IContinueProcessingPredicate = (furthestOriginalIndex:Int, matchLengthOfLongest:Float) -> Bool;

typedef IDiffResult = {
    var quitEarly:Bool;
    var changes:Array<DiffChange>;
}

class StringDiffSequence implements ISequence {

    final source:String;

    public function new(source:String) {
        this.source = source;
    }

    public function getElements():EitherType<Array<Int>, Array<String>> {
        final source = this.source;
        final characters:Array<Int> = [];
        for (i in 0...source.length) {
            characters.push(StringTools.fastCodeAt(source, i));
        }
        return characters;
    }

    public function getStrictElement(index:Int):Null<String> {
        return null;
    }

}

/**
 * Module functions of diff.ts.
 */
class Diff {

    public static function stringDiff(original:String, modified:String, pretty:Bool):Array<DiffChange> {
        return new LcsDiff(new StringDiffSequence(original), new StringDiffSequence(modified)).ComputeDiff(pretty).changes;
    }

}

//
// The code below has been ported from a C# implementation in VS
//

private class Debug {

    public static function Assert(condition:Bool, message:String):Void {
        if (!condition) {
            throw new haxe.Exception(message);
        }
    }

}

private class MyArray {
    /**
     * Copies a range of elements from an Array starting at the specified source index and pastes
     * them to another Array starting at the specified destination index.
     */
    public static function Copy<T>(sourceArray:Array<T>, sourceIndex:Int, destinationArray:Array<T>, destinationIndex:Int, length:Int):Void {
        for (i in 0...length) {
            destinationArray[destinationIndex + i] = sourceArray[sourceIndex + i];
        }
    }

    public static function Copy2(sourceArray:Array<Int>, sourceIndex:Int, destinationArray:Array<Int>, destinationIndex:Int, length:Int):Void {
        for (i in 0...length) {
            destinationArray[destinationIndex + i] = sourceArray[sourceIndex + i];
        }
    }
}

//*****************************************************************************
// LcsDiff.cs
//
// An implementation of the difference algorithm described in
// "An O(ND) Difference Algorithm and its variations" by Eugene W. Myers
//
// Copyright (C) 2008 Microsoft Corporation @minifier_do_not_preserve
//*****************************************************************************

/**
 * A utility class which helps to create the set of DiffChanges from
 * a difference operation. This class accepts original DiffElements and
 * modified DiffElements that are involved in a particular change. The
 * MarkNextChange() method can be called to mark the separation between
 * distinct changes. At the end, the Changes property can be called to retrieve
 * the constructed changes.
 */
private class DiffChangeHelper {

    var m_changes:Array<DiffChange>;
    var m_originalStart:Int;
    var m_modifiedStart:Int;
    var m_originalCount:Int;
    var m_modifiedCount:Int;

    /**
     * Constructs a new DiffChangeHelper for the given DiffSequences.
     */
    public function new() {
        this.m_changes = [];
        this.m_originalStart = LcsDiff.MAX_SAFE_SMALL_INTEGER;
        this.m_modifiedStart = LcsDiff.MAX_SAFE_SMALL_INTEGER;
        this.m_originalCount = 0;
        this.m_modifiedCount = 0;
    }

    /**
     * Marks the beginning of the next change in the set of differences.
     */
    public function MarkNextChange():Void {
        // Only add to the list if there is something to add
        if (this.m_originalCount > 0 || this.m_modifiedCount > 0) {
            // Add the new change to our list
            this.m_changes.push(new DiffChange(this.m_originalStart, this.m_originalCount, this.m_modifiedStart, this.m_modifiedCount));
        }

        // Reset for the next change
        this.m_originalCount = 0;
        this.m_modifiedCount = 0;
        this.m_originalStart = LcsDiff.MAX_SAFE_SMALL_INTEGER;
        this.m_modifiedStart = LcsDiff.MAX_SAFE_SMALL_INTEGER;
    }

    /**
     * Adds the original element at the given position to the elements
     * affected by the current change. The modified index gives context
     * to the change position with respect to the original sequence.
     */
    public function AddOriginalElement(originalIndex:Int, modifiedIndex:Int):Void {
        // The 'true' start index is the smallest of the ones we've seen
        this.m_originalStart = originalIndex < this.m_originalStart ? originalIndex : this.m_originalStart;
        this.m_modifiedStart = modifiedIndex < this.m_modifiedStart ? modifiedIndex : this.m_modifiedStart;

        this.m_originalCount++;
    }

    /**
     * Adds the modified element at the given position to the elements
     * affected by the current change. The original index gives context
     * to the change position with respect to the modified sequence.
     */
    public function AddModifiedElement(originalIndex:Int, modifiedIndex:Int):Void {
        // The 'true' start index is the smallest of the ones we've seen
        this.m_originalStart = originalIndex < this.m_originalStart ? originalIndex : this.m_originalStart;
        this.m_modifiedStart = modifiedIndex < this.m_modifiedStart ? modifiedIndex : this.m_modifiedStart;

        this.m_modifiedCount++;
    }

    /**
     * Retrieves all of the changes marked by the class.
     */
    public function getChanges():Array<DiffChange> {
        if (this.m_originalCount > 0 || this.m_modifiedCount > 0) {
            // Finish up on whatever is left
            this.MarkNextChange();
        }

        return this.m_changes;
    }

    /**
     * Retrieves all of the changes marked by the class in the reverse order
     */
    public function getReverseChanges():Array<DiffChange> {
        if (this.m_originalCount > 0 || this.m_modifiedCount > 0) {
            // Finish up on whatever is left
            this.MarkNextChange();
        }

        this.m_changes.reverse();
        return this.m_changes;
    }

}

/**
 * An implementation of the difference algorithm described in
 * "An O(ND) Difference Algorithm and its variations" by Eugene W. Myers
 */
class LcsDiff {

    /**
     * `Constants.MAX_SAFE_SMALL_INTEGER` and `MIN_SAFE_SMALL_INTEGER` (uint.ts).
     */
    @:allow(cityscape.base.common.diff)
    static inline final MAX_SAFE_SMALL_INTEGER:Int = 1 << 30;

    static inline final MIN_SAFE_SMALL_INTEGER:Int = -(1 << 30);

    // Our total memory usage for storing history is (worst-case):
    // 2 * [(MaxDifferencesHistory + 1) * (MaxDifferencesHistory + 1) - 1] * sizeof(int)
    // 2 * [1448*1448 - 1] * 4 = 16773624 = 16MB
    static inline final MaxDifferencesHistory:Int = 1447;

    final ContinueProcessingPredicate:Null<IContinueProcessingPredicate>;

    final _originalSequence:ISequence;
    final _modifiedSequence:ISequence;
    final _hasStrings:Bool;
    final _originalStringElements:Array<String>;
    final _originalElementsOrHash:Array<Int>;
    final _modifiedStringElements:Array<String>;
    final _modifiedElementsOrHash:Array<Int>;

    var m_forwardHistory:Array<Array<Int>>;
    var m_reverseHistory:Array<Array<Int>>;

    /**
     * Constructs the DiffFinder
     */
    public function new(originalSequence:ISequence, modifiedSequence:ISequence, ?continueProcessingPredicate:IContinueProcessingPredicate) {
        this.ContinueProcessingPredicate = continueProcessingPredicate;

        this._originalSequence = originalSequence;
        this._modifiedSequence = modifiedSequence;

        final original = LcsDiff._getElements(originalSequence);
        final modified = LcsDiff._getElements(modifiedSequence);

        this._hasStrings = (original.hasStrings && modified.hasStrings);
        this._originalStringElements = original.stringElements;
        this._originalElementsOrHash = original.elementsOrHash;
        this._modifiedStringElements = modified.stringElements;
        this._modifiedElementsOrHash = modified.elementsOrHash;

        this.m_forwardHistory = [];
        this.m_reverseHistory = [];
    }

    static function _getElements(sequence:ISequence):{stringElements:Array<String>, elementsOrHash:Array<Int>, hasStrings:Bool} {
        final elements:Array<Any> = cast sequence.getElements();

        if (elements.length > 0 && Std.isOfType(elements[0], std.String)) {
            final strings:Array<String> = cast elements;
            final hashes:Array<Int> = [];
            for (i in 0...strings.length) {
                hashes.push(Hash.stringHash(strings[i], 0));
            }
            return {stringElements: strings, elementsOrHash: hashes, hasStrings: true};
        }

        return {stringElements: [], elementsOrHash: cast elements, hasStrings: false};
    }

    function ElementsAreEqual(originalIndex:Int, newIndex:Int):Bool {
        if (this._originalElementsOrHash[originalIndex] != this._modifiedElementsOrHash[newIndex]) {
            return false;
        }
        return (this._hasStrings ? this._originalStringElements[originalIndex] == this._modifiedStringElements[newIndex] : true);
    }

    function ElementsAreStrictEqual(originalIndex:Int, newIndex:Int):Bool {
        if (!this.ElementsAreEqual(originalIndex, newIndex)) {
            return false;
        }
        final originalElement = this._originalSequence.getStrictElement(originalIndex);
        final modifiedElement = this._modifiedSequence.getStrictElement(newIndex);
        return (originalElement == modifiedElement);
    }

    function OriginalElementsAreEqual(index1:Int, index2:Int):Bool {
        if (this._originalElementsOrHash[index1] != this._originalElementsOrHash[index2]) {
            return false;
        }
        return (this._hasStrings ? this._originalStringElements[index1] == this._originalStringElements[index2] : true);
    }

    function ModifiedElementsAreEqual(index1:Int, index2:Int):Bool {
        if (this._modifiedElementsOrHash[index1] != this._modifiedElementsOrHash[index2]) {
            return false;
        }
        return (this._hasStrings ? this._modifiedStringElements[index1] == this._modifiedStringElements[index2] : true);
    }

    public function ComputeDiff(pretty:Bool):IDiffResult {
        return this._ComputeDiff(0, this._originalElementsOrHash.length - 1, 0, this._modifiedElementsOrHash.length - 1, pretty);
    }

    /**
     * Computes the differences between the original and modified input
     * sequences on the bounded range.
     * @returns An array of the differences between the two input sequences.
     */
    function _ComputeDiff(originalStart:Int, originalEnd:Int, modifiedStart:Int, modifiedEnd:Int, pretty:Bool):IDiffResult {
        final quitEarlyArr = [false];
        var changes = this.ComputeDiffRecursive(originalStart, originalEnd, modifiedStart, modifiedEnd, quitEarlyArr);

        if (pretty) {
            // We have to clean up the computed diff to be more intuitive
            // but it turns out this cannot be done correctly until the entire set
            // of diffs have been computed
            changes = this.PrettifyChanges(changes);
        }

        return {
            quitEarly: quitEarlyArr[0],
            changes: changes
        };
    }

    /**
     * Private helper method which computes the differences on the bounded range
     * recursively.
     * @returns An array of the differences between the two input sequences.
     */
    function ComputeDiffRecursive(originalStart:Int, originalEnd:Int, modifiedStart:Int, modifiedEnd:Int, quitEarlyArr:Array<Bool>):Array<DiffChange> {
        quitEarlyArr[0] = false;

        // Find the start of the differences
        while (originalStart <= originalEnd && modifiedStart <= modifiedEnd && this.ElementsAreEqual(originalStart, modifiedStart)) {
            originalStart++;
            modifiedStart++;
        }

        // Find the end of the differences
        while (originalEnd >= originalStart && modifiedEnd >= modifiedStart && this.ElementsAreEqual(originalEnd, modifiedEnd)) {
            originalEnd--;
            modifiedEnd--;
        }

        // In the special case where we either have all insertions or all deletions or the sequences are identical
        if (originalStart > originalEnd || modifiedStart > modifiedEnd) {
            var changes:Array<DiffChange>;

            if (modifiedStart <= modifiedEnd) {
                Debug.Assert(originalStart == originalEnd + 1, 'originalStart should only be one more than originalEnd');

                // All insertions
                changes = [
                    new DiffChange(originalStart, 0, modifiedStart, modifiedEnd - modifiedStart + 1)
                ];
            }
            else if (originalStart <= originalEnd) {
                Debug.Assert(modifiedStart == modifiedEnd + 1, 'modifiedStart should only be one more than modifiedEnd');

                // All deletions
                changes = [
                    new DiffChange(originalStart, originalEnd - originalStart + 1, modifiedStart, 0)
                ];
            }
            else {
                Debug.Assert(originalStart == originalEnd + 1, 'originalStart should only be one more than originalEnd');
                Debug.Assert(modifiedStart == modifiedEnd + 1, 'modifiedStart should only be one more than modifiedEnd');

                // Identical sequences - No differences
                changes = [];
            }

            return changes;
        }

        // This problem can be solved using the Divide-And-Conquer technique.
        final midOriginalArr = [0];
        final midModifiedArr = [0];
        final result = this.ComputeRecursionPoint(originalStart, originalEnd, modifiedStart, modifiedEnd, midOriginalArr, midModifiedArr, quitEarlyArr);

        final midOriginal = midOriginalArr[0];
        final midModified = midModifiedArr[0];

        if (result != null) {
            // Result is not-null when there was enough memory to compute the changes while
            // searching for the recursion point
            return result;
        }
        else if (!quitEarlyArr[0]) {
            // We can break the problem down recursively by finding the changes in the
            // First Half:   (originalStart, modifiedStart) to (midOriginal, midModified)
            // Second Half:  (midOriginal + 1, minModified + 1) to (originalEnd, modifiedEnd)
            // NOTE: ComputeDiff() is inclusive, therefore the second range starts on the next point

            final leftChanges = this.ComputeDiffRecursive(originalStart, midOriginal, modifiedStart, midModified, quitEarlyArr);
            var rightChanges:Array<DiffChange> = [];

            if (!quitEarlyArr[0]) {
                rightChanges = this.ComputeDiffRecursive(midOriginal + 1, originalEnd, midModified + 1, modifiedEnd, quitEarlyArr);
            }
            else {
                // We didn't have time to finish the first half, so we don't have time to compute this half.
                // Consider the entire rest of the sequence different.
                rightChanges = [
                    new DiffChange(midOriginal + 1, originalEnd - (midOriginal + 1) + 1, midModified + 1, modifiedEnd - (midModified + 1) + 1)
                ];
            }

            return this.ConcatenateChanges(leftChanges, rightChanges);
        }

        // If we hit here, we quit early, and so can't return anything meaningful
        return [
            new DiffChange(originalStart, originalEnd - originalStart + 1, modifiedStart, modifiedEnd - modifiedStart + 1)
        ];
    }

    function WALKTRACE(diagonalForwardBase:Int, diagonalForwardStart:Int, diagonalForwardEnd:Int, diagonalForwardOffset:Int,
            diagonalReverseBase:Int, diagonalReverseStart:Int, diagonalReverseEnd:Int, diagonalReverseOffset:Int,
            forwardPoints:Array<Int>, reversePoints:Array<Int>,
            originalIndex:Int, originalEnd:Int, midOriginalArr:Array<Int>,
            modifiedIndex:Int, modifiedEnd:Int, midModifiedArr:Array<Int>,
            deltaIsEven:Bool, quitEarlyArr:Array<Bool>
        ):Array<DiffChange> {
        var forwardChanges:Null<Array<DiffChange>> = null;
        var reverseChanges:Null<Array<DiffChange>> = null;

        // First, walk backward through the forward diagonals history
        var changeHelper = new DiffChangeHelper();
        var diagonalMin = diagonalForwardStart;
        var diagonalMax = diagonalForwardEnd;
        var diagonalRelative = (midOriginalArr[0] - midModifiedArr[0]) - diagonalForwardOffset;
        var lastOriginalIndex = MIN_SAFE_SMALL_INTEGER;
        var historyIndex = this.m_forwardHistory.length - 1;

        do {
            // Get the diagonal index from the relative diagonal number
            final diagonal = diagonalRelative + diagonalForwardBase;

            // Figure out where we came from
            if (diagonal == diagonalMin || (diagonal < diagonalMax && forwardPoints[diagonal - 1] < forwardPoints[diagonal + 1])) {
                // Vertical line (the element is an insert)
                originalIndex = forwardPoints[diagonal + 1];
                modifiedIndex = originalIndex - diagonalRelative - diagonalForwardOffset;
                if (originalIndex < lastOriginalIndex) {
                    changeHelper.MarkNextChange();
                }
                lastOriginalIndex = originalIndex;
                changeHelper.AddModifiedElement(originalIndex + 1, modifiedIndex);
                diagonalRelative = (diagonal + 1) - diagonalForwardBase; //Setup for the next iteration
            }
            else {
                // Horizontal line (the element is a deletion)
                originalIndex = forwardPoints[diagonal - 1] + 1;
                modifiedIndex = originalIndex - diagonalRelative - diagonalForwardOffset;
                if (originalIndex < lastOriginalIndex) {
                    changeHelper.MarkNextChange();
                }
                lastOriginalIndex = originalIndex - 1;
                changeHelper.AddOriginalElement(originalIndex, modifiedIndex + 1);
                diagonalRelative = (diagonal - 1) - diagonalForwardBase; //Setup for the next iteration
            }

            if (historyIndex >= 0) {
                forwardPoints = this.m_forwardHistory[historyIndex];
                diagonalForwardBase = forwardPoints[0]; //We stored this in the first spot
                diagonalMin = 1;
                diagonalMax = forwardPoints.length - 1;
            }
        } while (--historyIndex >= -1);

        // Ironically, we get the forward changes as the reverse of the
        // order we added them since we technically added them backwards
        forwardChanges = changeHelper.getReverseChanges();

        if (quitEarlyArr[0]) {
            // TODO: Calculate a partial from the reverse diagonals.
            //       For now, just assume everything after the midOriginal/midModified point is a diff

            var originalStartPoint = midOriginalArr[0] + 1;
            var modifiedStartPoint = midModifiedArr[0] + 1;

            if (forwardChanges != null && forwardChanges.length > 0) {
                final lastForwardChange = forwardChanges[forwardChanges.length - 1];
                originalStartPoint = Std.int(Math.max(originalStartPoint, lastForwardChange.getOriginalEnd()));
                modifiedStartPoint = Std.int(Math.max(modifiedStartPoint, lastForwardChange.getModifiedEnd()));
            }

            reverseChanges = [
                new DiffChange(originalStartPoint, originalEnd - originalStartPoint + 1,
                    modifiedStartPoint, modifiedEnd - modifiedStartPoint + 1)
            ];
        }
        else {
            // Now walk backward through the reverse diagonals history
            changeHelper = new DiffChangeHelper();
            diagonalMin = diagonalReverseStart;
            diagonalMax = diagonalReverseEnd;
            diagonalRelative = (midOriginalArr[0] - midModifiedArr[0]) - diagonalReverseOffset;
            lastOriginalIndex = MAX_SAFE_SMALL_INTEGER;
            historyIndex = (deltaIsEven) ? this.m_reverseHistory.length - 1 : this.m_reverseHistory.length - 2;

            do {
                // Get the diagonal index from the relative diagonal number
                final diagonal = diagonalRelative + diagonalReverseBase;

                // Figure out where we came from
                if (diagonal == diagonalMin || (diagonal < diagonalMax && reversePoints[diagonal - 1] >= reversePoints[diagonal + 1])) {
                    // Horizontal line (the element is a deletion))
                    originalIndex = reversePoints[diagonal + 1] - 1;
                    modifiedIndex = originalIndex - diagonalRelative - diagonalReverseOffset;
                    if (originalIndex > lastOriginalIndex) {
                        changeHelper.MarkNextChange();
                    }
                    lastOriginalIndex = originalIndex + 1;
                    changeHelper.AddOriginalElement(originalIndex + 1, modifiedIndex + 1);
                    diagonalRelative = (diagonal + 1) - diagonalReverseBase; //Setup for the next iteration
                }
                else {
                    // Vertical line (the element is an insertion)
                    originalIndex = reversePoints[diagonal - 1];
                    modifiedIndex = originalIndex - diagonalRelative - diagonalReverseOffset;
                    if (originalIndex > lastOriginalIndex) {
                        changeHelper.MarkNextChange();
                    }
                    lastOriginalIndex = originalIndex;
                    changeHelper.AddModifiedElement(originalIndex + 1, modifiedIndex + 1);
                    diagonalRelative = (diagonal - 1) - diagonalReverseBase; //Setup for the next iteration
                }

                if (historyIndex >= 0) {
                    reversePoints = this.m_reverseHistory[historyIndex];
                    diagonalReverseBase = reversePoints[0]; //We stored this in the first spot
                    diagonalMin = 1;
                    diagonalMax = reversePoints.length - 1;
                }
            } while (--historyIndex >= -1);

            // There are cases where the reverse history will find diffs that
            // are correct, but not intuitive, so we need shift them.
            reverseChanges = changeHelper.getChanges();
        }

        return this.ConcatenateChanges(forwardChanges, reverseChanges);
    }

    /**
     * Given the range to compute the diff on, this method finds the point:
     * (midOriginal, midModified)
     * that exists in the middle of the LCS of the two sequences and
     * is the point at which the LCS problem may be broken down recursively.
     * This method will try to keep the LCS trace in memory. If the LCS recursion
     * point is calculated and the full trace is available in memory, then this method
     * will return the change list.
     * @returns The diff changes, if available, otherwise null
     */
    function ComputeRecursionPoint(originalStart:Int, originalEnd:Int, modifiedStart:Int, modifiedEnd:Int, midOriginalArr:Array<Int>, midModifiedArr:Array<Int>, quitEarlyArr:Array<Bool>):Null<Array<DiffChange>> {
        var originalIndex = 0, modifiedIndex = 0;
        var diagonalForwardStart = 0, diagonalForwardEnd = 0;
        var diagonalReverseStart = 0, diagonalReverseEnd = 0;

        // To traverse the edit graph and produce the proper LCS, our actual
        // start position is just outside the given boundary
        originalStart--;
        modifiedStart--;

        // We set these up to make the compiler happy, but they will
        // be replaced before we return with the actual recursion point
        midOriginalArr[0] = 0;
        midModifiedArr[0] = 0;

        // Clear out the history
        this.m_forwardHistory = [];
        this.m_reverseHistory = [];

        // Each cell in the two arrays corresponds to a diagonal in the edit graph.
        // The integer value in the cell represents the originalIndex of the furthest
        // reaching point found so far that ends in that diagonal.
        // The modifiedIndex can be computed mathematically from the originalIndex and the diagonal number.
        final maxDifferences = (originalEnd - originalStart) + (modifiedEnd - modifiedStart);
        final numDiagonals = maxDifferences + 1;
        final forwardPoints = newInt32Array(numDiagonals);
        final reversePoints = newInt32Array(numDiagonals);
        // diagonalForwardBase: Index into forwardPoints of the diagonal which passes through (originalStart, modifiedStart)
        // diagonalReverseBase: Index into reversePoints of the diagonal which passes through (originalEnd, modifiedEnd)
        final diagonalForwardBase = (modifiedEnd - modifiedStart);
        final diagonalReverseBase = (originalEnd - originalStart);
        // diagonalForwardOffset: Geometric offset which allows modifiedIndex to be computed from originalIndex and the
        //    diagonal number (relative to diagonalForwardBase)
        // diagonalReverseOffset: Geometric offset which allows modifiedIndex to be computed from originalIndex and the
        //    diagonal number (relative to diagonalReverseBase)
        final diagonalForwardOffset = (originalStart - modifiedStart);
        final diagonalReverseOffset = (originalEnd - modifiedEnd);

        // delta: The difference between the end diagonal and the start diagonal. This is used to relate diagonal numbers
        //   relative to the start diagonal with diagonal numbers relative to the end diagonal.
        // The Even/Oddn-ness of this delta is important for determining when we should check for overlap
        final delta = diagonalReverseBase - diagonalForwardBase;
        final deltaIsEven = (delta % 2 == 0);

        // Here we set up the start and end points as the furthest points found so far
        // in both the forward and reverse directions, respectively
        forwardPoints[diagonalForwardBase] = originalStart;
        reversePoints[diagonalReverseBase] = originalEnd;

        // Remember if we quit early, and thus need to do a best-effort result instead of a real result.
        quitEarlyArr[0] = false;

        // A couple of points:
        // --With this method, we iterate on the number of differences between the two sequences.
        //   The more differences there actually are, the longer this will take.
        // --Also, as the number of differences increases, we have to search on diagonals further
        //   away from the reference diagonal (which is diagonalForwardBase for forward, diagonalReverseBase for reverse).
        // --We extend on even diagonals (relative to the reference diagonal) only when numDifferences
        //   is even and odd diagonals only when numDifferences is odd.
        var numDifferences = 1;
        while (numDifferences <= (maxDifferences / 2) + 1) {
            var furthestOriginalIndex = 0;
            var furthestModifiedIndex = 0;

            // Run the algorithm in the forward direction
            diagonalForwardStart = this.ClipDiagonalBound(diagonalForwardBase - numDifferences, numDifferences, diagonalForwardBase, numDiagonals);
            diagonalForwardEnd = this.ClipDiagonalBound(diagonalForwardBase + numDifferences, numDifferences, diagonalForwardBase, numDiagonals);
            var diagonal = diagonalForwardStart;
            while (diagonal <= diagonalForwardEnd) {
                // STEP 1: We extend the furthest reaching point in the present diagonal
                // by looking at the diagonals above and below and picking the one whose point
                // is further away from the start point (originalStart, modifiedStart)
                if (diagonal == diagonalForwardStart || (diagonal < diagonalForwardEnd && forwardPoints[diagonal - 1] < forwardPoints[diagonal + 1])) {
                    originalIndex = forwardPoints[diagonal + 1];
                }
                else {
                    originalIndex = forwardPoints[diagonal - 1] + 1;
                }
                modifiedIndex = originalIndex - (diagonal - diagonalForwardBase) - diagonalForwardOffset;

                // Save the current originalIndex so we can test for false overlap in step 3
                final tempOriginalIndex = originalIndex;

                // STEP 2: We can continue to extend the furthest reaching point in the present diagonal
                // so long as the elements are equal.
                while (originalIndex < originalEnd && modifiedIndex < modifiedEnd && this.ElementsAreEqual(originalIndex + 1, modifiedIndex + 1)) {
                    originalIndex++;
                    modifiedIndex++;
                }
                forwardPoints[diagonal] = originalIndex;

                if (originalIndex + modifiedIndex > furthestOriginalIndex + furthestModifiedIndex) {
                    furthestOriginalIndex = originalIndex;
                    furthestModifiedIndex = modifiedIndex;
                }

                // STEP 3: If delta is odd (overlap first happens on forward when delta is odd)
                // and diagonal is in the range of reverse diagonals computed for numDifferences-1
                // (the previous iteration; we haven't computed reverse diagonals for numDifferences yet)
                // then check for overlap.
                if (!deltaIsEven && Math.abs(diagonal - diagonalReverseBase) <= (numDifferences - 1)) {
                    if (originalIndex >= reversePoints[diagonal]) {
                        midOriginalArr[0] = originalIndex;
                        midModifiedArr[0] = modifiedIndex;

                        if (tempOriginalIndex <= reversePoints[diagonal] && MaxDifferencesHistory > 0 && numDifferences <= (MaxDifferencesHistory + 1)) {
                            // BINGO! We overlapped, and we have the full trace in memory!
                            return this.WALKTRACE(diagonalForwardBase, diagonalForwardStart, diagonalForwardEnd, diagonalForwardOffset,
                                diagonalReverseBase, diagonalReverseStart, diagonalReverseEnd, diagonalReverseOffset,
                                forwardPoints, reversePoints,
                                originalIndex, originalEnd, midOriginalArr,
                                modifiedIndex, modifiedEnd, midModifiedArr,
                                deltaIsEven, quitEarlyArr
                            );
                        }
                        else {
                            // Either false overlap, or we didn't have enough memory for the full trace
                            // Just return the recursion point
                            return null;
                        }
                    }
                }
                diagonal += 2;
            }

            // Check to see if we should be quitting early, before moving on to the next iteration.
            final matchLengthOfLongest:Float = ((furthestOriginalIndex - originalStart) + (furthestModifiedIndex - modifiedStart) - numDifferences) / 2;

            if (this.ContinueProcessingPredicate != null && !this.ContinueProcessingPredicate(furthestOriginalIndex, matchLengthOfLongest)) {
                // We can't finish, so skip ahead to generating a result from what we have.
                quitEarlyArr[0] = true;

                // Use the furthest distance we got in the forward direction.
                midOriginalArr[0] = furthestOriginalIndex;
                midModifiedArr[0] = furthestModifiedIndex;

                if (matchLengthOfLongest > 0 && MaxDifferencesHistory > 0 && numDifferences <= (MaxDifferencesHistory + 1)) {
                    // Enough of the history is in memory to walk it backwards
                    return this.WALKTRACE(diagonalForwardBase, diagonalForwardStart, diagonalForwardEnd, diagonalForwardOffset,
                        diagonalReverseBase, diagonalReverseStart, diagonalReverseEnd, diagonalReverseOffset,
                        forwardPoints, reversePoints,
                        originalIndex, originalEnd, midOriginalArr,
                        modifiedIndex, modifiedEnd, midModifiedArr,
                        deltaIsEven, quitEarlyArr
                    );
                }
                else {
                    // We didn't actually remember enough of the history.

                    //Since we are quitting the diff early, we need to shift back the originalStart and modified start
                    //back into the boundary limits since we decremented their value above beyond the boundary limit.
                    originalStart++;
                    modifiedStart++;

                    return [
                        new DiffChange(originalStart, originalEnd - originalStart + 1,
                            modifiedStart, modifiedEnd - modifiedStart + 1)
                    ];
                }
            }

            // Run the algorithm in the reverse direction
            diagonalReverseStart = this.ClipDiagonalBound(diagonalReverseBase - numDifferences, numDifferences, diagonalReverseBase, numDiagonals);
            diagonalReverseEnd = this.ClipDiagonalBound(diagonalReverseBase + numDifferences, numDifferences, diagonalReverseBase, numDiagonals);
            diagonal = diagonalReverseStart;
            while (diagonal <= diagonalReverseEnd) {
                // STEP 1: We extend the furthest reaching point in the present diagonal
                // by looking at the diagonals above and below and picking the one whose point
                // is further away from the start point (originalEnd, modifiedEnd)
                if (diagonal == diagonalReverseStart || (diagonal < diagonalReverseEnd && reversePoints[diagonal - 1] >= reversePoints[diagonal + 1])) {
                    originalIndex = reversePoints[diagonal + 1] - 1;
                }
                else {
                    originalIndex = reversePoints[diagonal - 1];
                }
                modifiedIndex = originalIndex - (diagonal - diagonalReverseBase) - diagonalReverseOffset;

                // Save the current originalIndex so we can test for false overlap
                final tempOriginalIndex = originalIndex;

                // STEP 2: We can continue to extend the furthest reaching point in the present diagonal
                // as long as the elements are equal.
                while (originalIndex > originalStart && modifiedIndex > modifiedStart && this.ElementsAreEqual(originalIndex, modifiedIndex)) {
                    originalIndex--;
                    modifiedIndex--;
                }
                reversePoints[diagonal] = originalIndex;

                // STEP 4: If delta is even (overlap first happens on reverse when delta is even)
                // and diagonal is in the range of forward diagonals computed for numDifferences
                // then check for overlap.
                if (deltaIsEven && Math.abs(diagonal - diagonalForwardBase) <= numDifferences) {
                    if (originalIndex <= forwardPoints[diagonal]) {
                        midOriginalArr[0] = originalIndex;
                        midModifiedArr[0] = modifiedIndex;

                        if (tempOriginalIndex >= forwardPoints[diagonal] && MaxDifferencesHistory > 0 && numDifferences <= (MaxDifferencesHistory + 1)) {
                            // BINGO! We overlapped, and we have the full trace in memory!
                            return this.WALKTRACE(diagonalForwardBase, diagonalForwardStart, diagonalForwardEnd, diagonalForwardOffset,
                                diagonalReverseBase, diagonalReverseStart, diagonalReverseEnd, diagonalReverseOffset,
                                forwardPoints, reversePoints,
                                originalIndex, originalEnd, midOriginalArr,
                                modifiedIndex, modifiedEnd, midModifiedArr,
                                deltaIsEven, quitEarlyArr
                            );
                        }
                        else {
                            // Either false overlap, or we didn't have enough memory for the full trace
                            // Just return the recursion point
                            return null;
                        }
                    }
                }
                diagonal += 2;
            }

            // Save current vectors to history before the next iteration
            if (numDifferences <= MaxDifferencesHistory) {
                // We are allocating space for one extra int, which we fill with
                // the index of the diagonal base index
                var temp = newInt32Array(diagonalForwardEnd - diagonalForwardStart + 2);
                temp[0] = diagonalForwardBase - diagonalForwardStart + 1;
                MyArray.Copy2(forwardPoints, diagonalForwardStart, temp, 1, diagonalForwardEnd - diagonalForwardStart + 1);
                this.m_forwardHistory.push(temp);

                temp = newInt32Array(diagonalReverseEnd - diagonalReverseStart + 2);
                temp[0] = diagonalReverseBase - diagonalReverseStart + 1;
                MyArray.Copy2(reversePoints, diagonalReverseStart, temp, 1, diagonalReverseEnd - diagonalReverseStart + 1);
                this.m_reverseHistory.push(temp);
            }

            numDifferences++;
        }

        // If we got here, then we have the full trace in history. We just have to convert it to a change list
        // NOTE: This part is a bit messy
        return this.WALKTRACE(diagonalForwardBase, diagonalForwardStart, diagonalForwardEnd, diagonalForwardOffset,
            diagonalReverseBase, diagonalReverseStart, diagonalReverseEnd, diagonalReverseOffset,
            forwardPoints, reversePoints,
            originalIndex, originalEnd, midOriginalArr,
            modifiedIndex, modifiedEnd, midModifiedArr,
            deltaIsEven, quitEarlyArr
        );
    }

    static function newInt32Array(length:Int):Array<Int> {
        final result:Array<Int> = [];
        if (length > 0) {
            result[length - 1] = 0;
            for (i in 0...length) {
                result[i] = 0;
            }
        }
        return result;
    }

    /**
     * Shifts the given changes to provide a more intuitive diff.
     * While the first element in a diff matches the first element after the diff,
     * we shift the diff down.
     *
     * @param changes The list of changes to shift
     * @returns The shifted changes
     */
    function PrettifyChanges(changes:Array<DiffChange>):Array<DiffChange> {

        // Shift all the changes down first
        var i = 0;
        while (i < changes.length) {
            final change = changes[i];
            final originalStop = (i < changes.length - 1) ? changes[i + 1].originalStart : this._originalElementsOrHash.length;
            final modifiedStop = (i < changes.length - 1) ? changes[i + 1].modifiedStart : this._modifiedElementsOrHash.length;
            final checkOriginal = change.originalLength > 0;
            final checkModified = change.modifiedLength > 0;

            while (
                change.originalStart + change.originalLength < originalStop
                && change.modifiedStart + change.modifiedLength < modifiedStop
                && (!checkOriginal || this.OriginalElementsAreEqual(change.originalStart, change.originalStart + change.originalLength))
                && (!checkModified || this.ModifiedElementsAreEqual(change.modifiedStart, change.modifiedStart + change.modifiedLength))
            ) {
                final startStrictEqual = this.ElementsAreStrictEqual(change.originalStart, change.modifiedStart);
                final endStrictEqual = this.ElementsAreStrictEqual(change.originalStart + change.originalLength, change.modifiedStart + change.modifiedLength);
                if (endStrictEqual && !startStrictEqual) {
                    // moving the change down would create an equal change, but the elements are not strict equal
                    break;
                }
                change.originalStart++;
                change.modifiedStart++;
            }

            final mergedChangeArr:Array<Null<DiffChange>> = [null];
            if (i < changes.length - 1 && this.ChangesOverlap(changes[i], changes[i + 1], mergedChangeArr)) {
                changes[i] = mergedChangeArr[0];
                changes.splice(i + 1, 1);
                i--;
                i++;
                continue;
            }
            i++;
        }

        // Shift changes back up until we hit empty or whitespace-only lines
        i = changes.length - 1;
        while (i >= 0) {
            final change = changes[i];

            var originalStop = 0;
            var modifiedStop = 0;
            if (i > 0) {
                final prevChange = changes[i - 1];
                originalStop = prevChange.originalStart + prevChange.originalLength;
                modifiedStop = prevChange.modifiedStart + prevChange.modifiedLength;
            }

            final checkOriginal = change.originalLength > 0;
            final checkModified = change.modifiedLength > 0;

            var bestDelta = 0;
            var bestScore = this._boundaryScore(change.originalStart, change.originalLength, change.modifiedStart, change.modifiedLength);

            var delta = 1;
            while (true) {
                final originalStart = change.originalStart - delta;
                final modifiedStart = change.modifiedStart - delta;

                if (originalStart < originalStop || modifiedStart < modifiedStop) {
                    break;
                }

                if (checkOriginal && !this.OriginalElementsAreEqual(originalStart, originalStart + change.originalLength)) {
                    break;
                }

                if (checkModified && !this.ModifiedElementsAreEqual(modifiedStart, modifiedStart + change.modifiedLength)) {
                    break;
                }

                final touchingPreviousChange = (originalStart == originalStop && modifiedStart == modifiedStop);
                final score = (
                    (touchingPreviousChange ? 5 : 0)
                    + this._boundaryScore(originalStart, change.originalLength, modifiedStart, change.modifiedLength)
                );

                if (score > bestScore) {
                    bestScore = score;
                    bestDelta = delta;
                }
                delta++;
            }

            change.originalStart -= bestDelta;
            change.modifiedStart -= bestDelta;

            final mergedChangeArr:Array<Null<DiffChange>> = [null];
            if (i > 0 && this.ChangesOverlap(changes[i - 1], changes[i], mergedChangeArr)) {
                changes[i - 1] = mergedChangeArr[0];
                changes.splice(i, 1);
                i++;
                i--;
                continue;
            }
            i--;
        }

        // There could be multiple longest common substrings.
        // Give preference to the ones containing longer lines
        if (this._hasStrings) {
            for (i in 1...changes.length) {
                final aChange = changes[i - 1];
                final bChange = changes[i];
                final matchedLength = bChange.originalStart - aChange.originalStart - aChange.originalLength;
                final aOriginalStart = aChange.originalStart;
                final bOriginalEnd = bChange.originalStart + bChange.originalLength;
                final abOriginalLength = bOriginalEnd - aOriginalStart;
                final aModifiedStart = aChange.modifiedStart;
                final bModifiedEnd = bChange.modifiedStart + bChange.modifiedLength;
                final abModifiedLength = bModifiedEnd - aModifiedStart;
                // Avoid wasting a lot of time with these searches
                if (matchedLength < 5 && abOriginalLength < 20 && abModifiedLength < 20) {
                    final t = this._findBetterContiguousSequence(
                        aOriginalStart, abOriginalLength,
                        aModifiedStart, abModifiedLength,
                        matchedLength
                    );
                    if (t != null) {
                        final originalMatchStart = t[0];
                        final modifiedMatchStart = t[1];
                        if (originalMatchStart != aChange.originalStart + aChange.originalLength || modifiedMatchStart != aChange.modifiedStart + aChange.modifiedLength) {
                            // switch to another sequence that has a better score
                            aChange.originalLength = originalMatchStart - aChange.originalStart;
                            aChange.modifiedLength = modifiedMatchStart - aChange.modifiedStart;
                            bChange.originalStart = originalMatchStart + matchedLength;
                            bChange.modifiedStart = modifiedMatchStart + matchedLength;
                            bChange.originalLength = bOriginalEnd - bChange.originalStart;
                            bChange.modifiedLength = bModifiedEnd - bChange.modifiedStart;
                        }
                    }
                }
            }
        }

        return changes;
    }

    function _findBetterContiguousSequence(originalStart:Int, originalLength:Int, modifiedStart:Int, modifiedLength:Int, desiredLength:Int):Null<Array<Int>> {
        if (originalLength < desiredLength || modifiedLength < desiredLength) {
            return null;
        }
        final originalMax = originalStart + originalLength - desiredLength + 1;
        final modifiedMax = modifiedStart + modifiedLength - desiredLength + 1;
        var bestScore = 0;
        var bestOriginalStart = 0;
        var bestModifiedStart = 0;
        for (i in originalStart...originalMax) {
            for (j in modifiedStart...modifiedMax) {
                final score = this._contiguousSequenceScore(i, j, desiredLength);
                if (score > 0 && score > bestScore) {
                    bestScore = score;
                    bestOriginalStart = i;
                    bestModifiedStart = j;
                }
            }
        }
        if (bestScore > 0) {
            return [bestOriginalStart, bestModifiedStart];
        }
        return null;
    }

    function _contiguousSequenceScore(originalStart:Int, modifiedStart:Int, length:Int):Int {
        var score = 0;
        for (l in 0...length) {
            if (!this.ElementsAreEqual(originalStart + l, modifiedStart + l)) {
                return 0;
            }
            score += this._originalStringElements[originalStart + l].length;
        }
        return score;
    }

    /**
     * `/^\s*$/.test(str)`
     */
    static function isWhitespaceOnly(str:String):Bool {
        for (i in 0...str.length) {
            if (!Strings.isJsWhitespace(StringTools.fastCodeAt(str, i))) {
                return false;
            }
        }
        return true;
    }

    function _OriginalIsBoundary(index:Int):Bool {
        if (index <= 0 || index >= this._originalElementsOrHash.length - 1) {
            return true;
        }
        return (this._hasStrings && isWhitespaceOnly(this._originalStringElements[index]));
    }

    function _OriginalRegionIsBoundary(originalStart:Int, originalLength:Int):Bool {
        if (this._OriginalIsBoundary(originalStart) || this._OriginalIsBoundary(originalStart - 1)) {
            return true;
        }
        if (originalLength > 0) {
            final originalEnd = originalStart + originalLength;
            if (this._OriginalIsBoundary(originalEnd - 1) || this._OriginalIsBoundary(originalEnd)) {
                return true;
            }
        }
        return false;
    }

    function _ModifiedIsBoundary(index:Int):Bool {
        if (index <= 0 || index >= this._modifiedElementsOrHash.length - 1) {
            return true;
        }
        return (this._hasStrings && isWhitespaceOnly(this._modifiedStringElements[index]));
    }

    function _ModifiedRegionIsBoundary(modifiedStart:Int, modifiedLength:Int):Bool {
        if (this._ModifiedIsBoundary(modifiedStart) || this._ModifiedIsBoundary(modifiedStart - 1)) {
            return true;
        }
        if (modifiedLength > 0) {
            final modifiedEnd = modifiedStart + modifiedLength;
            if (this._ModifiedIsBoundary(modifiedEnd - 1) || this._ModifiedIsBoundary(modifiedEnd)) {
                return true;
            }
        }
        return false;
    }

    function _boundaryScore(originalStart:Int, originalLength:Int, modifiedStart:Int, modifiedLength:Int):Int {
        final originalScore = (this._OriginalRegionIsBoundary(originalStart, originalLength) ? 1 : 0);
        final modifiedScore = (this._ModifiedRegionIsBoundary(modifiedStart, modifiedLength) ? 1 : 0);
        return (originalScore + modifiedScore);
    }

    /**
     * Concatenates the two input DiffChange lists and returns the resulting
     * list.
     */
    function ConcatenateChanges(left:Array<DiffChange>, right:Array<DiffChange>):Array<DiffChange> {
        final mergedChangeArr:Array<Null<DiffChange>> = [];

        if (left.length == 0 || right.length == 0) {
            return (right.length > 0) ? right : left;
        }
        else if (this.ChangesOverlap(left[left.length - 1], right[0], mergedChangeArr)) {
            // Since we break the problem down recursively, it is possible that we
            // might recurse in the middle of a change thereby splitting it into
            // two changes. Here in the combining stage, we detect and fuse those
            // changes back together
            final result:Array<DiffChange> = [];
            MyArray.Copy(left, 0, result, 0, left.length - 1);
            result[left.length - 1] = mergedChangeArr[0];
            MyArray.Copy(right, 1, result, left.length, right.length - 1);

            return result;
        }
        else {
            final result:Array<DiffChange> = [];
            MyArray.Copy(left, 0, result, 0, left.length);
            MyArray.Copy(right, 0, result, left.length, right.length);

            return result;
        }
    }

    /**
     * Returns true if the two changes overlap and can be merged into a single
     * change
     */
    function ChangesOverlap(left:DiffChange, right:DiffChange, mergedChangeArr:Array<Null<DiffChange>>):Bool {
        Debug.Assert(left.originalStart <= right.originalStart, 'Left change is not less than or equal to right change');
        Debug.Assert(left.modifiedStart <= right.modifiedStart, 'Left change is not less than or equal to right change');

        if (left.originalStart + left.originalLength >= right.originalStart || left.modifiedStart + left.modifiedLength >= right.modifiedStart) {
            final originalStart = left.originalStart;
            var originalLength = left.originalLength;
            final modifiedStart = left.modifiedStart;
            var modifiedLength = left.modifiedLength;

            if (left.originalStart + left.originalLength >= right.originalStart) {
                originalLength = right.originalStart + right.originalLength - left.originalStart;
            }
            if (left.modifiedStart + left.modifiedLength >= right.modifiedStart) {
                modifiedLength = right.modifiedStart + right.modifiedLength - left.modifiedStart;
            }

            mergedChangeArr[0] = new DiffChange(originalStart, originalLength, modifiedStart, modifiedLength);
            return true;
        }
        else {
            mergedChangeArr[0] = null;
            return false;
        }
    }

    /**
     * Helper method used to clip a diagonal index to the range of valid
     * diagonals. This also decides whether or not the diagonal index,
     * if it exceeds the boundary, should be clipped to the boundary or clipped
     * one inside the boundary depending on the Even/Odd status of the boundary
     * and numDifferences.
     */
    function ClipDiagonalBound(diagonal:Int, numDifferences:Int, diagonalBaseIndex:Int, numDiagonals:Int):Int {
        if (diagonal >= 0 && diagonal < numDiagonals) {
            // Nothing to clip, its in range
            return diagonal;
        }

        // diagonalsBelow: The number of diagonals below the reference diagonal
        // diagonalsAbove: The number of diagonals above the reference diagonal
        final diagonalsBelow = diagonalBaseIndex;
        final diagonalsAbove = numDiagonals - diagonalBaseIndex - 1;
        final diffEven = (numDifferences % 2 == 0);

        if (diagonal < 0) {
            final lowerBoundEven = (diagonalsBelow % 2 == 0);
            return (diffEven == lowerBoundEven) ? 0 : 1;
        }
        else {
            final upperBoundEven = (diagonalsAbove % 2 == 0);
            return (diffEven == upperBoundEven) ? numDiagonals - 1 : numDiagonals - 2;
        }
    }

}
