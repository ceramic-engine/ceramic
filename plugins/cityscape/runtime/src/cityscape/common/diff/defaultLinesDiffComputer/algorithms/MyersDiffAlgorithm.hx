// Ported from vscode src/vs/editor/common/diff/defaultLinesDiffComputer/algorithms/myersDiffAlgorithm.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.diff.defaultLinesDiffComputer.algorithms;

import cityscape.common.core.OffsetRange;
import cityscape.common.diff.defaultLinesDiffComputer.algorithms.DiffAlgorithm;

/**
 * An O(ND) diff algorithm that has a quadratic space worst-case complexity.
 */
class MyersDiffAlgorithm implements IDiffAlgorithm {

    public function new() {}

    public function compute(seq1:ISequence, seq2:ISequence, ?timeout:ITimeout):DiffAlgorithmResult {
        if (timeout == null) {
            timeout = InfiniteTimeout.instance;
        }
        // These are common special cases.
        // The early return improves performance dramatically.
        if (seq1.length == 0 || seq2.length == 0) {
            return DiffAlgorithmResult.trivial(seq1, seq2);
        }

        final seqX = seq1; // Text on the x axis
        final seqY = seq2; // Text on the y axis
        final seqXLength = seqX.length;
        final seqYLength = seqY.length;

        inline function getXAfterSnake(x:Int, y:Int):Int {
            while (x < seqXLength && y < seqYLength && seqX.getElement(x) == seqY.getElement(y)) {
                x++;
                y++;
            }
            return x;
        }

        var d = 0;
        // V[k]: X value of longest d-line that ends in diagonal k.
        // d-line: path from (0,0) to (x,y) that uses exactly d non-diagonals.
        // diagonal k: Set of points (x,y) with x-y = k.
        // k=1 -> (1,0),(2,1)
        final V = new FastInt32Array();
        V.set(0, getXAfterSnake(0, 0));

        final paths = new FastArrayNegativeIndices<Null<SnakePath>>();
        paths.set(0, V.get(0) == 0 ? null : new SnakePath(null, 0, 0, V.get(0)));

        var k = 0;

        var done = false;
        while (!done) {
            d++;
            if (!timeout.isValid()) {
                return DiffAlgorithmResult.trivialTimedOut(seqX, seqY);
            }
            // The paper has `for (k = -d; k <= d; k += 2)`, but we can ignore diagonals that cannot influence the result.
            final lowerBound = -Std.int(Math.min(d, seqYLength + (d % 2)));
            final upperBound = Std.int(Math.min(d, seqXLength + (d % 2)));
            k = lowerBound;
            while (k <= upperBound) {
                // We can use the X values of (d-1)-lines to compute X value of the longest d-lines.
                final maxXofDLineTop = k == upperBound ? -1 : V.get(k + 1); // We take a vertical non-diagonal (add a symbol in seqX)
                final maxXofDLineLeft = k == lowerBound ? -1 : V.get(k - 1) + 1; // We take a horizontal non-diagonal (+1 x) (delete a symbol in seqX)
                final x = Std.int(Math.min(Math.max(maxXofDLineTop, maxXofDLineLeft), seqXLength));
                final y = x - k;
                if (x > seqXLength || y > seqYLength) {
                    // This diagonal is irrelevant for the result.
                    // TODO: Don't pay the cost for this in the next iteration.
                    k += 2;
                    continue;
                }
                final newMaxX = getXAfterSnake(x, y);
                V.set(k, newMaxX);
                final lastPath = x == maxXofDLineTop ? paths.get(k + 1) : paths.get(k - 1);
                paths.set(k, newMaxX != x ? new SnakePath(lastPath, x, y, newMaxX - x) : lastPath);

                if (V.get(k) == seqXLength && V.get(k) - k == seqYLength) {
                    done = true;
                    break;
                }
                k += 2;
            }
        }

        var path = paths.get(k);
        final result:Array<SequenceDiff> = [];
        var lastAligningPosS1:Int = seqXLength;
        var lastAligningPosS2:Int = seqYLength;

        while (true) {
            final endX = path != null ? path.x + path.length : 0;
            final endY = path != null ? path.y + path.length : 0;

            if (endX != lastAligningPosS1 || endY != lastAligningPosS2) {
                result.push(new SequenceDiff(
                    new OffsetRange(endX, lastAligningPosS1),
                    new OffsetRange(endY, lastAligningPosS2)
                ));
            }
            if (path == null) {
                break;
            }
            lastAligningPosS1 = path.x;
            lastAligningPosS2 = path.y;

            path = path.prev;
        }

        result.reverse();
        return new DiffAlgorithmResult(result, false);
    }

}

private class SnakePath {

    public final prev:Null<SnakePath>;
    public final x:Int;
    public final y:Int;
    public final length:Int;

    public function new(prev:Null<SnakePath>, x:Int, y:Int, length:Int) {
        this.prev = prev;
        this.x = x;
        this.y = y;
        this.length = length;
    }

}

/**
 * An array that supports fast negative indices.
 */
private class FastInt32Array {

    var positiveArr:Array<Int> = [for (_ in 0...10) 0];
    var negativeArr:Array<Int> = [for (_ in 0...10) 0];

    public function new() {}

    public function get(idx:Int):Int {
        if (idx < 0) {
            idx = -idx - 1;
            return this.negativeArr[idx];
        }
        else {
            return this.positiveArr[idx];
        }
    }

    public function set(idx:Int, value:Int):Void {
        if (idx < 0) {
            idx = -idx - 1;
            if (idx >= this.negativeArr.length) {
                final arr = this.negativeArr;
                this.negativeArr = grow(arr);
            }
            this.negativeArr[idx] = value;
        }
        else {
            if (idx >= this.positiveArr.length) {
                final arr = this.positiveArr;
                this.positiveArr = grow(arr);
            }
            this.positiveArr[idx] = value;
        }
    }

    static function grow(arr:Array<Int>):Array<Int> {
        final result = [for (_ in 0...arr.length * 2) 0];
        for (i in 0...arr.length) {
            result[i] = arr[i];
        }
        return result;
    }

}

/**
 * An array that supports fast negative indices.
 */
private class FastArrayNegativeIndices<T> {

    final positiveArr:Array<T> = [];
    final negativeArr:Array<T> = [];

    public function new() {}

    public function get(idx:Int):T {
        if (idx < 0) {
            idx = -idx - 1;
            return this.negativeArr[idx];
        }
        else {
            return this.positiveArr[idx];
        }
    }

    public function set(idx:Int, value:T):Void {
        if (idx < 0) {
            idx = -idx - 1;
            this.negativeArr[idx] = value;
        }
        else {
            this.positiveArr[idx] = value;
        }
    }

}
