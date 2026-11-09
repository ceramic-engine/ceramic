// Ported from vscode src/vs/editor/common/diff/defaultLinesDiffComputer/algorithms/dynamicProgrammingDiffing.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.diff.defaultLinesDiffComputer.algorithms;

import cityscape.common.core.OffsetRange;
import cityscape.common.diff.defaultLinesDiffComputer.Utils.Array2D;
import cityscape.common.diff.defaultLinesDiffComputer.algorithms.DiffAlgorithm;

/**
 * A O(MN) diffing algorithm that supports a score function.
 * The algorithm can be improved by processing the 2d array diagonally.
 */
class DynamicProgrammingDiffing implements IDiffAlgorithm {

    public function new() {}

    public function compute(sequence1:ISequence, sequence2:ISequence, ?timeout:ITimeout):DiffAlgorithmResult {
        return computeWithScore(sequence1, sequence2, timeout, null);
    }

    /**
     * `compute` with Monaco's optional `equalityScore` argument (an
     * interface method takes no extra argument in Haxe).
     */
    public function computeWithScore(sequence1:ISequence, sequence2:ISequence, ?timeout:ITimeout, ?equalityScore:(offset1:Int, offset2:Int) -> Float):DiffAlgorithmResult {
        if (timeout == null) {
            timeout = InfiniteTimeout.instance;
        }
        if (sequence1.length == 0 || sequence2.length == 0) {
            return DiffAlgorithmResult.trivial(sequence1, sequence2);
        }

        final length1 = sequence1.length;
        final length2 = sequence2.length;

        /**
         * lcsLengths.get(i, j): Length of the longest common subsequence of sequence1.substring(0, i + 1) and sequence2.substring(0, j + 1).
         */
        final lcsLengths = new Array2D<Float>(length1, length2, 0.0);
        final directions = new Array2D<Int>(length1, length2, 0);
        final lengths = new Array2D<Int>(length1, length2, 0);

        // ==== Initializing lcsLengths ====
        for (s1 in 0...length1) {
            for (s2 in 0...length2) {
                if (!timeout.isValid()) {
                    return DiffAlgorithmResult.trivialTimedOut(sequence1, sequence2);
                }

                final horizontalLen:Float = s1 == 0 ? 0 : lcsLengths.get(s1 - 1, s2);
                final verticalLen:Float = s2 == 0 ? 0 : lcsLengths.get(s1, s2 - 1);

                var extendedSeqScore:Float;
                if (sequence1.getElement(s1) == sequence2.getElement(s2)) {
                    if (s1 == 0 || s2 == 0) {
                        extendedSeqScore = 0;
                    }
                    else {
                        extendedSeqScore = lcsLengths.get(s1 - 1, s2 - 1);
                    }
                    if (s1 > 0 && s2 > 0 && directions.get(s1 - 1, s2 - 1) == 3) {
                        // Prefer consecutive diagonals
                        extendedSeqScore += lengths.get(s1 - 1, s2 - 1);
                    }
                    extendedSeqScore += (equalityScore != null ? equalityScore(s1, s2) : 1);
                }
                else {
                    extendedSeqScore = -1;
                }

                final newValue = Math.max(Math.max(horizontalLen, verticalLen), extendedSeqScore);

                if (newValue == extendedSeqScore) {
                    // Prefer diagonals
                    final prevLen = s1 > 0 && s2 > 0 ? lengths.get(s1 - 1, s2 - 1) : 0;
                    lengths.set(s1, s2, prevLen + 1);
                    directions.set(s1, s2, 3);
                }
                else if (newValue == horizontalLen) {
                    lengths.set(s1, s2, 0);
                    directions.set(s1, s2, 1);
                }
                else if (newValue == verticalLen) {
                    lengths.set(s1, s2, 0);
                    directions.set(s1, s2, 2);
                }

                lcsLengths.set(s1, s2, newValue);
            }
        }

        // ==== Backtracking ====
        final result:Array<SequenceDiff> = [];
        var lastAligningPosS1:Int = length1;
        var lastAligningPosS2:Int = length2;

        function reportDecreasingAligningPositions(s1:Int, s2:Int):Void {
            if (s1 + 1 != lastAligningPosS1 || s2 + 1 != lastAligningPosS2) {
                result.push(new SequenceDiff(
                    new OffsetRange(s1 + 1, lastAligningPosS1),
                    new OffsetRange(s2 + 1, lastAligningPosS2)
                ));
            }
            lastAligningPosS1 = s1;
            lastAligningPosS2 = s2;
        }

        var s1 = length1 - 1;
        var s2 = length2 - 1;
        while (s1 >= 0 && s2 >= 0) {
            if (directions.get(s1, s2) == 3) {
                reportDecreasingAligningPositions(s1, s2);
                s1--;
                s2--;
            }
            else {
                if (directions.get(s1, s2) == 1) {
                    s1--;
                }
                else {
                    s2--;
                }
            }
        }
        reportDecreasingAligningPositions(-1, -1);
        result.reverse();
        return new DiffAlgorithmResult(result, false);
    }

}
