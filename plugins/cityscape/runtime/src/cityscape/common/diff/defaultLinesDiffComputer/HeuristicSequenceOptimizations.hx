// Ported from vscode src/vs/editor/common/diff/defaultLinesDiffComputer/heuristicSequenceOptimizations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.diff.defaultLinesDiffComputer;

import cityscape.base.common.Arrays;
import cityscape.base.common.Strings;
import cityscape.common.core.OffsetRange;
import cityscape.common.diff.defaultLinesDiffComputer.algorithms.DiffAlgorithm;

/**
 * Module functions of heuristicSequenceOptimizations.ts.
 */
class HeuristicSequenceOptimizations {

    public static function optimizeSequenceDiffs(sequence1:ISequence, sequence2:ISequence, sequenceDiffs:Array<SequenceDiff>):Array<SequenceDiff> {
        var result = sequenceDiffs;
        result = joinSequenceDiffsByShifting(sequence1, sequence2, result);
        // Sometimes, calling this function twice improves the result.
        // Uncomment the second invocation and run the tests to see the difference.
        result = joinSequenceDiffsByShifting(sequence1, sequence2, result);
        result = shiftSequenceDiffs(sequence1, sequence2, result);
        return result;
    }

    /**
     * This function fixes issues like this:
     * ```
     * import { Baz, Bar } from "foo";
     * ```
     * <->
     * ```
     * import { Baz, Bar, Foo } from "foo";
     * ```
     * Computed diff: [ {Add "," after Bar}, {Add "Foo " after space} }
     * Improved diff: [{Add ", Foo" after Bar}]
     */
    static function joinSequenceDiffsByShifting(sequence1:ISequence, sequence2:ISequence, sequenceDiffs:Array<SequenceDiff>):Array<SequenceDiff> {
        if (sequenceDiffs.length == 0) {
            return sequenceDiffs;
        }

        final result:Array<SequenceDiff> = [];
        result.push(sequenceDiffs[0]);

        // First move them all to the left as much as possible and join them if possible
        for (i in 1...sequenceDiffs.length) {
            final prevResult = result[result.length - 1];
            var cur = sequenceDiffs[i];

            if (cur.seq1Range.isEmpty || cur.seq2Range.isEmpty) {
                final length = cur.seq1Range.start - prevResult.seq1Range.endExclusive;
                var d = 1;
                while (d <= length) {
                    if (
                        sequence1.getElement(cur.seq1Range.start - d) != sequence1.getElement(cur.seq1Range.endExclusive - d) ||
                        sequence2.getElement(cur.seq2Range.start - d) != sequence2.getElement(cur.seq2Range.endExclusive - d)) {
                        break;
                    }
                    d++;
                }
                d--;

                if (d == length) {
                    // Merge previous and current diff
                    result[result.length - 1] = new SequenceDiff(
                        new OffsetRange(prevResult.seq1Range.start, cur.seq1Range.endExclusive - length),
                        new OffsetRange(prevResult.seq2Range.start, cur.seq2Range.endExclusive - length)
                    );
                    continue;
                }

                cur = cur.delta(-d);
            }

            result.push(cur);
        }

        final result2:Array<SequenceDiff> = [];
        // Then move them all to the right and join them again if possible
        for (i in 0...result.length - 1) {
            final nextResult = result[i + 1];
            var cur = result[i];

            if (cur.seq1Range.isEmpty || cur.seq2Range.isEmpty) {
                final length = nextResult.seq1Range.start - cur.seq1Range.endExclusive;
                var d = 0;
                while (d < length) {
                    if (
                        !sequence1.isStronglyEqual(cur.seq1Range.start + d, cur.seq1Range.endExclusive + d) ||
                        !sequence2.isStronglyEqual(cur.seq2Range.start + d, cur.seq2Range.endExclusive + d)
                    ) {
                        break;
                    }
                    d++;
                }

                if (d == length) {
                    // Merge previous and current diff, write to result!
                    result[i + 1] = new SequenceDiff(
                        new OffsetRange(cur.seq1Range.start + length, nextResult.seq1Range.endExclusive),
                        new OffsetRange(cur.seq2Range.start + length, nextResult.seq2Range.endExclusive)
                    );
                    continue;
                }

                if (d > 0) {
                    cur = cur.delta(d);
                }
            }

            result2.push(cur);
        }

        if (result.length > 0) {
            result2.push(result[result.length - 1]);
        }

        return result2;
    }

    // align character level diffs at whitespace characters
    // import { IBar } from "foo";
    // import { I[Arr, I]Bar } from "foo";
    // ->
    // import { [IArr, ]IBar } from "foo";

    // import { ITransaction, observableValue, transaction } from 'vs/base/common/observable';
    // import { ITransaction, observable[FromEvent, observable]Value, transaction } from 'vs/base/common/observable';
    // ->
    // import { ITransaction, [observableFromEvent, ]observableValue, transaction } from 'vs/base/common/observable';

    // collectBrackets(level + 1, levelPerBracketType);
    // collectBrackets(level + 1, levelPerBracket[ + 1, levelPerBracket]Type);
    // ->
    // collectBrackets(level + 1, [levelPerBracket + 1, ]levelPerBracketType);

    static function shiftSequenceDiffs(sequence1:ISequence, sequence2:ISequence, sequenceDiffs:Array<SequenceDiff>):Array<SequenceDiff> {
        // Both sequences of the default computer have `getBoundaryScore`
        for (i in 0...sequenceDiffs.length) {
            final prevDiff = (i > 0 ? sequenceDiffs[i - 1] : null);
            final diff = sequenceDiffs[i];
            final nextDiff = (i + 1 < sequenceDiffs.length ? sequenceDiffs[i + 1] : null);

            final seq1ValidRange = new OffsetRange(prevDiff != null ? prevDiff.seq1Range.endExclusive + 1 : 0, nextDiff != null ? nextDiff.seq1Range.start - 1 : sequence1.length);
            final seq2ValidRange = new OffsetRange(prevDiff != null ? prevDiff.seq2Range.endExclusive + 1 : 0, nextDiff != null ? nextDiff.seq2Range.start - 1 : sequence2.length);

            if (diff.seq1Range.isEmpty) {
                sequenceDiffs[i] = shiftDiffToBetterPosition(diff, sequence1, sequence2, seq1ValidRange, seq2ValidRange);
            }
            else if (diff.seq2Range.isEmpty) {
                sequenceDiffs[i] = shiftDiffToBetterPosition(diff.swap(), sequence2, sequence1, seq2ValidRange, seq1ValidRange).swap();
            }
        }

        return sequenceDiffs;
    }

    static function shiftDiffToBetterPosition(diff:SequenceDiff, sequence1:ISequence, sequence2:ISequence, seq1ValidRange:OffsetRange, seq2ValidRange:OffsetRange):SequenceDiff {
        final maxShiftLimit = 100; // To prevent performance issues

        // don't touch previous or next!
        var deltaBefore = 1;
        while (
            diff.seq1Range.start - deltaBefore >= seq1ValidRange.start &&
            diff.seq2Range.start - deltaBefore >= seq2ValidRange.start &&
            sequence2.isStronglyEqual(diff.seq2Range.start - deltaBefore, diff.seq2Range.endExclusive - deltaBefore) && deltaBefore < maxShiftLimit
        ) {
            deltaBefore++;
        }
        deltaBefore--;

        var deltaAfter = 0;
        while (
            diff.seq1Range.start + deltaAfter < seq1ValidRange.endExclusive &&
            diff.seq2Range.endExclusive + deltaAfter < seq2ValidRange.endExclusive &&
            sequence2.isStronglyEqual(diff.seq2Range.start + deltaAfter, diff.seq2Range.endExclusive + deltaAfter) && deltaAfter < maxShiftLimit
        ) {
            deltaAfter++;
        }

        if (deltaBefore == 0 && deltaAfter == 0) {
            return diff;
        }

        // Visualize `[sequence1.text, diff.seq1Range.start + deltaAfter]`
        // and `[sequence2.text, diff.seq2Range.start + deltaAfter, diff.seq2Range.endExclusive + deltaAfter]`

        var bestDelta = 0;
        var bestScore = -1;
        // find best scored delta
        for (delta in -deltaBefore...deltaAfter + 1) {
            final seq2OffsetStart = diff.seq2Range.start + delta;
            final seq2OffsetEndExclusive = diff.seq2Range.endExclusive + delta;
            final seq1Offset = diff.seq1Range.start + delta;

            final score = sequence1.getBoundaryScore(seq1Offset) + sequence2.getBoundaryScore(seq2OffsetStart) + sequence2.getBoundaryScore(seq2OffsetEndExclusive);
            if (score > bestScore) {
                bestScore = score;
                bestDelta = delta;
            }
        }

        return diff.delta(bestDelta);
    }

    public static function removeShortMatches(sequence1:ISequence, sequence2:ISequence, sequenceDiffs:Array<SequenceDiff>):Array<SequenceDiff> {
        final result:Array<SequenceDiff> = [];
        for (s in sequenceDiffs) {
            final last = result.length > 0 ? result[result.length - 1] : null;
            if (last == null) {
                result.push(s);
                continue;
            }

            if (s.seq1Range.start - last.seq1Range.endExclusive <= 2 || s.seq2Range.start - last.seq2Range.endExclusive <= 2) {
                result[result.length - 1] = new SequenceDiff(last.seq1Range.join(s.seq1Range), last.seq2Range.join(s.seq2Range));
            }
            else {
                result.push(s);
            }
        }

        return result;
    }

    public static function extendDiffsToEntireWordIfAppropriate(sequence1:LinesSliceCharSequence, sequence2:LinesSliceCharSequence, sequenceDiffs:Array<SequenceDiff>):Array<SequenceDiff> {
        final equalMappings = SequenceDiff.invert(sequenceDiffs, sequence1.length);

        final additional:Array<SequenceDiff> = [];

        var lastPoint = new OffsetPair(0, 0);

        function scanWord(pair:OffsetPair, equalMapping:SequenceDiff):Void {
            if (pair.offset1 < lastPoint.offset1 || pair.offset2 < lastPoint.offset2) {
                return;
            }

            final w1 = sequence1.findWordContaining(pair.offset1);
            final w2 = sequence2.findWordContaining(pair.offset2);
            if (w1 == null || w2 == null) {
                return;
            }
            var w = new SequenceDiff(w1, w2);
            final equalPart = w.intersect(equalMapping);

            var equalChars1 = equalPart.seq1Range.length;
            var equalChars2 = equalPart.seq2Range.length;

            // The words do not touch previous equals mappings, as we would have processed them already.
            // But they might touch the next ones.

            while (equalMappings.length > 0) {
                final next = equalMappings[0];
                final intersects = next.seq1Range.intersects(w.seq1Range) || next.seq2Range.intersects(w.seq2Range);
                if (!intersects) {
                    break;
                }

                final v1 = sequence1.findWordContaining(next.seq1Range.start);
                final v2 = sequence2.findWordContaining(next.seq2Range.start);
                // Because there is an intersection, we know that the words are not empty.
                final v = new SequenceDiff(v1, v2);
                final equalPart = v.intersect(next);

                equalChars1 += equalPart.seq1Range.length;
                equalChars2 += equalPart.seq2Range.length;

                w = w.join(v);

                if (w.seq1Range.endExclusive >= next.seq1Range.endExclusive) {
                    // The word extends beyond the next equal mapping.
                    equalMappings.shift();
                }
                else {
                    break;
                }
            }

            if (equalChars1 + equalChars2 < (w.seq1Range.length + w.seq2Range.length) * 2 / 3) {
                additional.push(w);
            }

            lastPoint = w.getEndExclusives();
        }

        while (equalMappings.length > 0) {
            final next = equalMappings.shift();
            if (next.seq1Range.isEmpty) {
                continue;
            }
            scanWord(next.getStarts(), next);
            // The equal parts are not empty, so -1 gives us a character that is equal in both parts.
            scanWord(next.getEndExclusives().delta(-1), next);
        }

        final merged = mergeSequenceDiffs(sequenceDiffs, additional);
        return merged;
    }

    static function mergeSequenceDiffs(sequenceDiffs1:Array<SequenceDiff>, sequenceDiffs2:Array<SequenceDiff>):Array<SequenceDiff> {
        final result:Array<SequenceDiff> = [];

        while (sequenceDiffs1.length > 0 || sequenceDiffs2.length > 0) {
            final sd1 = sequenceDiffs1.length > 0 ? sequenceDiffs1[0] : null;
            final sd2 = sequenceDiffs2.length > 0 ? sequenceDiffs2[0] : null;

            var next:SequenceDiff;
            if (sd1 != null && (sd2 == null || sd1.seq1Range.start < sd2.seq1Range.start)) {
                next = sequenceDiffs1.shift();
            }
            else {
                next = sequenceDiffs2.shift();
            }

            if (result.length > 0 && result[result.length - 1].seq1Range.endExclusive >= next.seq1Range.start) {
                result[result.length - 1] = result[result.length - 1].join(next);
            }
            else {
                result.push(next);
            }
        }

        return result;
    }

    public static function removeVeryShortMatchingLinesBetweenDiffs(sequence1:LineSequence, _sequence2:LineSequence, sequenceDiffs:Array<SequenceDiff>):Array<SequenceDiff> {
        var diffs = sequenceDiffs;
        if (diffs.length == 0) {
            return diffs;
        }

        var counter = 0;
        var shouldRepeat:Bool;
        do {
            shouldRepeat = false;

            final result:Array<SequenceDiff> = [
                diffs[0]
            ];

            for (i in 1...diffs.length) {
                final cur = diffs[i];
                final lastResult = result[result.length - 1];

                function shouldJoinDiffs(before:SequenceDiff, after:SequenceDiff):Bool {
                    final unchangedRange = new OffsetRange(lastResult.seq1Range.endExclusive, cur.seq1Range.start);

                    final unchangedText = sequence1.getText(unchangedRange);
                    final unchangedTextWithoutWsLength = countNonWhitespace(unchangedText);
                    if (unchangedTextWithoutWsLength <= 4
                        && (before.seq1Range.length + before.seq2Range.length > 5 || after.seq1Range.length + after.seq2Range.length > 5)) {
                        return true;
                    }

                    return false;
                }

                final shouldJoin = shouldJoinDiffs(lastResult, cur);
                if (shouldJoin) {
                    shouldRepeat = true;
                    result[result.length - 1] = result[result.length - 1].join(cur);
                }
                else {
                    result.push(cur);
                }
            }

            diffs = result;
        } while (counter++ < 10 && shouldRepeat);

        return diffs;
    }

    /**
     * `text.replace(/\s/g, '').length`
     */
    static function countNonWhitespace(text:String):Int {
        var count = 0;
        for (i in 0...text.length) {
            if (!Strings.isJsWhitespace(StringTools.fastCodeAt(text, i))) {
                count++;
            }
        }
        return count;
    }

    /**
     * `text.split(/\r\n|\r|\n/).length > 1`
     */
    static function hasLineBreak(text:String):Bool {
        for (i in 0...text.length) {
            final c = StringTools.fastCodeAt(text, i);
            if (c == '\n'.code || c == '\r'.code) {
                return true;
            }
        }
        return false;
    }

    public static function removeVeryShortMatchingTextBetweenLongDiffs(sequence1:LinesSliceCharSequence, sequence2:LinesSliceCharSequence, sequenceDiffs:Array<SequenceDiff>):Array<SequenceDiff> {
        var diffs = sequenceDiffs;
        if (diffs.length == 0) {
            return diffs;
        }

        var counter = 0;
        var shouldRepeat:Bool;
        do {
            shouldRepeat = false;

            final result:Array<SequenceDiff> = [
                diffs[0]
            ];

            for (i in 1...diffs.length) {
                final cur = diffs[i];
                final lastResult = result[result.length - 1];

                function shouldJoinDiffs(before:SequenceDiff, after:SequenceDiff):Bool {
                    final unchangedRange = new OffsetRange(lastResult.seq1Range.endExclusive, cur.seq1Range.start);

                    final unchangedLineCount = sequence1.countLinesIn(unchangedRange);
                    if (unchangedLineCount > 5 || unchangedRange.length > 500) {
                        return false;
                    }

                    final unchangedText = Utils.jsTrim(sequence1.getText(unchangedRange));
                    if (unchangedText.length > 20 || hasLineBreak(unchangedText)) {
                        return false;
                    }

                    final beforeLineCount1 = sequence1.countLinesIn(before.seq1Range);
                    final beforeSeq1Length = before.seq1Range.length;
                    final beforeLineCount2 = sequence2.countLinesIn(before.seq2Range);
                    final beforeSeq2Length = before.seq2Range.length;

                    final afterLineCount1 = sequence1.countLinesIn(after.seq1Range);
                    final afterSeq1Length = after.seq1Range.length;
                    final afterLineCount2 = sequence2.countLinesIn(after.seq2Range);
                    final afterSeq2Length = after.seq2Range.length;

                    // TODO: Maybe a neural net can be used to derive the result from these numbers

                    final max = 2 * 40 + 50;
                    function cap(v:Float):Float {
                        return Math.min(v, max);
                    }

                    if (Math.pow(Math.pow(cap(beforeLineCount1 * 40 + beforeSeq1Length), 1.5) + Math.pow(cap(beforeLineCount2 * 40 + beforeSeq2Length), 1.5), 1.5)
                        + Math.pow(Math.pow(cap(afterLineCount1 * 40 + afterSeq1Length), 1.5) + Math.pow(cap(afterLineCount2 * 40 + afterSeq2Length), 1.5), 1.5) > (Math.pow(Math.pow(max, 1.5), 1.5)) * 1.3) {
                        return true;
                    }
                    return false;
                }

                final shouldJoin = shouldJoinDiffs(lastResult, cur);
                if (shouldJoin) {
                    shouldRepeat = true;
                    result[result.length - 1] = result[result.length - 1].join(cur);
                }
                else {
                    result.push(cur);
                }
            }

            diffs = result;
        } while (counter++ < 10 && shouldRepeat);

        final newDiffs:Array<SequenceDiff> = [];

        // Remove short suffixes/prefixes
        Arrays.forEachWithNeighbors(diffs, (prev, cur, next) -> {
            var newDiff = cur;

            function shouldMarkAsChanged(text:String):Bool {
                return text.length > 0 && Utils.jsTrim(text).length <= 3 && cur.seq1Range.length + cur.seq2Range.length > 100;
            }

            final fullRange1 = sequence1.extendToFullLines(cur.seq1Range);
            final prefix = sequence1.getText(new OffsetRange(fullRange1.start, cur.seq1Range.start));
            if (shouldMarkAsChanged(prefix)) {
                newDiff = newDiff.deltaStart(-prefix.length);
            }
            final suffix = sequence1.getText(new OffsetRange(cur.seq1Range.endExclusive, fullRange1.endExclusive));
            if (shouldMarkAsChanged(suffix)) {
                newDiff = newDiff.deltaEnd(suffix.length);
            }

            final availableSpace = SequenceDiff.fromOffsetPairs(
                prev != null ? prev.getEndExclusives() : OffsetPair.zero,
                next != null ? next.getStarts() : OffsetPair.max
            );
            final result = newDiff.intersect(availableSpace);
            if (newDiffs.length > 0 && result.getStarts().equals(newDiffs[newDiffs.length - 1].getEndExclusives())) {
                newDiffs[newDiffs.length - 1] = newDiffs[newDiffs.length - 1].join(result);
            }
            else {
                newDiffs.push(result);
            }
        });

        return newDiffs;
    }

}
