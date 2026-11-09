// Ported from vscode src/vs/editor/common/diff/defaultLinesDiffComputer/algorithms/diffAlgorithm.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.diff.defaultLinesDiffComputer.algorithms;

import cityscape.base.common.Arrays;
import cityscape.base.common.Errors.BugIndicatingError;
import cityscape.common.core.OffsetRange;

/**
 * A diff algorithm (Myers, dynamic programming).
 */
interface IDiffAlgorithm {
    function compute(sequence1:ISequence, sequence2:ISequence, ?timeout:ITimeout):DiffAlgorithmResult;
}

class DiffAlgorithmResult {

    public static function trivial(seq1:ISequence, seq2:ISequence):DiffAlgorithmResult {
        return new DiffAlgorithmResult([new SequenceDiff(OffsetRange.ofLength(seq1.length), OffsetRange.ofLength(seq2.length))], false);
    }

    public static function trivialTimedOut(seq1:ISequence, seq2:ISequence):DiffAlgorithmResult {
        return new DiffAlgorithmResult([new SequenceDiff(OffsetRange.ofLength(seq1.length), OffsetRange.ofLength(seq2.length))], true);
    }

    public final diffs:Array<SequenceDiff>;

    /**
     * Indicates if the time out was reached.
     * In that case, the diffs might be an approximation and the user should be asked to rerun the diff with more time.
     */
    public final hitTimeout:Bool;

    public function new(diffs:Array<SequenceDiff>, hitTimeout:Bool) {
        this.diffs = diffs;
        this.hitTimeout = hitTimeout;
    }

}

class SequenceDiff {

    public static function invert(sequenceDiffs:Array<SequenceDiff>, doc1Length:Int):Array<SequenceDiff> {
        final result:Array<SequenceDiff> = [];
        Arrays.forEachAdjacent(sequenceDiffs, (a, b) -> {
            result.push(SequenceDiff.fromOffsetPairs(
                a != null ? a.getEndExclusives() : OffsetPair.zero,
                b != null ? b.getStarts() : new OffsetPair(doc1Length, (a != null ? a.seq2Range.endExclusive - a.seq1Range.endExclusive : 0) + doc1Length)
            ));
        });
        return result;
    }

    public static function fromOffsetPairs(start:OffsetPair, endExclusive:OffsetPair):SequenceDiff {
        return new SequenceDiff(
            new OffsetRange(start.offset1, endExclusive.offset1),
            new OffsetRange(start.offset2, endExclusive.offset2)
        );
    }

    public static function assertSorted(sequenceDiffs:Array<SequenceDiff>):Void {
        var last:Null<SequenceDiff> = null;
        for (cur in sequenceDiffs) {
            if (last != null) {
                if (!(last.seq1Range.endExclusive <= cur.seq1Range.start && last.seq2Range.endExclusive <= cur.seq2Range.start)) {
                    throw new BugIndicatingError('Sequence diffs must be sorted');
                }
            }
            last = cur;
        }
    }

    public final seq1Range:OffsetRange;
    public final seq2Range:OffsetRange;

    public function new(seq1Range:OffsetRange, seq2Range:OffsetRange) {
        this.seq1Range = seq1Range;
        this.seq2Range = seq2Range;
    }

    public function swap():SequenceDiff {
        return new SequenceDiff(this.seq2Range, this.seq1Range);
    }

    public function toString():String {
        return this.seq1Range.toString() + ' <-> ' + this.seq2Range.toString();
    }

    public function join(other:SequenceDiff):SequenceDiff {
        return new SequenceDiff(this.seq1Range.join(other.seq1Range), this.seq2Range.join(other.seq2Range));
    }

    public function delta(offset:Int):SequenceDiff {
        if (offset == 0) {
            return this;
        }
        return new SequenceDiff(this.seq1Range.delta(offset), this.seq2Range.delta(offset));
    }

    public function deltaStart(offset:Int):SequenceDiff {
        if (offset == 0) {
            return this;
        }
        return new SequenceDiff(this.seq1Range.deltaStart(offset), this.seq2Range.deltaStart(offset));
    }

    public function deltaEnd(offset:Int):SequenceDiff {
        if (offset == 0) {
            return this;
        }
        return new SequenceDiff(this.seq1Range.deltaEnd(offset), this.seq2Range.deltaEnd(offset));
    }

    public function intersectsOrTouches(other:SequenceDiff):Bool {
        return this.seq1Range.intersectsOrTouches(other.seq1Range) || this.seq2Range.intersectsOrTouches(other.seq2Range);
    }

    public function intersect(other:SequenceDiff):Null<SequenceDiff> {
        final i1 = this.seq1Range.intersect(other.seq1Range);
        final i2 = this.seq2Range.intersect(other.seq2Range);
        if (i1 == null || i2 == null) {
            return null;
        }
        return new SequenceDiff(i1, i2);
    }

    public function getStarts():OffsetPair {
        return new OffsetPair(this.seq1Range.start, this.seq2Range.start);
    }

    public function getEndExclusives():OffsetPair {
        return new OffsetPair(this.seq1Range.endExclusive, this.seq2Range.endExclusive);
    }

}

class OffsetPair {

    public static final zero = new OffsetPair(0, 0);

    /**
     * Monaco's `Number.MAX_SAFE_INTEGER` offsets: offsets are 32 bit
     * integers here, `Constants.MAX_SAFE_SMALL_INTEGER` (2^30) is used.
     */
    public static final max = new OffsetPair(1 << 30, 1 << 30);

    public final offset1:Int;
    public final offset2:Int;

    public function new(offset1:Int, offset2:Int) {
        this.offset1 = offset1;
        this.offset2 = offset2;
    }

    public function toString():String {
        return this.offset1 + ' <-> ' + this.offset2;
    }

    public function delta(offset:Int):OffsetPair {
        if (offset == 0) {
            return this;
        }
        return new OffsetPair(this.offset1 + offset, this.offset2 + offset);
    }

    public function equals(other:OffsetPair):Bool {
        return this.offset1 == other.offset1 && this.offset2 == other.offset2;
    }

}

/**
 * A sequence to diff. Monaco's optional `getBoundaryScore` is required
 * here (both sequences of the default diff computer have it).
 */
interface ISequence {

    function getElement(offset:Int):Int;

    var length(get, never):Int;

    /**
     * The higher the score, the better that offset can be used to split the sequence.
     * Is used to optimize insertions.
     * Must not be negative.
     */
    function getBoundaryScore(length:Int):Int;

    /**
     * For line sequences, getElement returns a number representing trimmed lines.
     * This however checks equality for the original lines.
     * It prevents shifting to less matching lines.
     */
    function isStronglyEqual(offset1:Int, offset2:Int):Bool;

}

interface ITimeout {
    function isValid():Bool;
}

class InfiniteTimeout implements ITimeout {

    public static final instance = new InfiniteTimeout();

    public function new() {}

    public function isValid():Bool {
        return true;
    }

}

class DateTimeout implements ITimeout {

    final startTime:Float = haxe.Timer.stamp() * 1000;
    var valid:Bool = true;
    var timeout:Float;
    var disabled:Bool = false;

    public function new(timeout:Float) {
        this.timeout = timeout;
        if (timeout <= 0) {
            throw new BugIndicatingError('timeout must be positive');
        }
    }

    public function isValid():Bool {
        if (disabled) {
            return true;
        }
        final valid = haxe.Timer.stamp() * 1000 - this.startTime < this.timeout;
        if (!valid && this.valid) {
            this.valid = false; // timeout reached
        }
        return this.valid;
    }

    public function disable():Void {
        this.timeout = 9007199254740991.0;
        this.disabled = true;
        this.valid = true;
    }

}
