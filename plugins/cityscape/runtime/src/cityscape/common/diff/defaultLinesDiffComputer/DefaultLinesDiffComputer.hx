// Ported from vscode src/vs/editor/common/diff/defaultLinesDiffComputer/defaultLinesDiffComputer.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.diff.defaultLinesDiffComputer;

import cityscape.base.common.Arrays;
import cityscape.base.common.Assert;
import cityscape.common.core.LineRange;
import cityscape.common.core.OffsetRange;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.diff.LinesDiffComputer;
import cityscape.common.diff.RangeMapping.DetailedLineRangeMapping;
import cityscape.common.diff.RangeMapping.LineRangeMapping;
import cityscape.common.diff.RangeMapping.RangeMapping;
import cityscape.common.diff.defaultLinesDiffComputer.HeuristicSequenceOptimizations;
import cityscape.common.diff.defaultLinesDiffComputer.algorithms.DiffAlgorithm;
import cityscape.common.diff.defaultLinesDiffComputer.algorithms.DynamicProgrammingDiffing;
import cityscape.common.diff.defaultLinesDiffComputer.algorithms.MyersDiffAlgorithm;

class DefaultLinesDiffComputer implements ILinesDiffComputer {

    final dynamicProgrammingDiffing = new DynamicProgrammingDiffing();
    final myersDiffingAlgorithm = new MyersDiffAlgorithm();

    public function new() {}

    public function computeDiff(originalLines:Array<String>, modifiedLines:Array<String>, options:ILinesDiffComputerOptions):LinesDiff {
        if (originalLines.length <= 1 && Arrays.equals(originalLines, modifiedLines, (a, b) -> a == b)) {
            return new LinesDiff([], [], false);
        }

        if (originalLines.length == 1 && originalLines[0].length == 0 || modifiedLines.length == 1 && modifiedLines[0].length == 0) {
            return new LinesDiff([
                new DetailedLineRangeMapping(
                    new LineRange(1, originalLines.length + 1),
                    new LineRange(1, modifiedLines.length + 1),
                    [
                        new RangeMapping(
                            new Range(1, 1, originalLines.length, originalLines[originalLines.length - 1].length + 1),
                            new Range(1, 1, modifiedLines.length, modifiedLines[modifiedLines.length - 1].length + 1)
                        )
                    ]
                )
            ], [], false);
        }

        final timeout:ITimeout = options.maxComputationTimeMs == 0 ? InfiniteTimeout.instance : new DateTimeout(options.maxComputationTimeMs);
        final considerWhitespaceChanges = !options.ignoreTrimWhitespace;

        final perfectHashes = new Map<String, Int>();
        var perfectHashesSize = 0;
        function getOrCreateHash(text:String):Int {
            var hash = perfectHashes.get(text);
            if (hash == null) {
                hash = perfectHashesSize++;
                perfectHashes.set(text, hash);
            }
            return hash;
        }

        final originalLinesHashes = originalLines.map((l) -> getOrCreateHash(Utils.jsTrim(l)));
        final modifiedLinesHashes = modifiedLines.map((l) -> getOrCreateHash(Utils.jsTrim(l)));

        final sequence1 = new LineSequence(originalLinesHashes, originalLines);
        final sequence2 = new LineSequence(modifiedLinesHashes, modifiedLines);

        final lineAlignmentResult = if (sequence1.length + sequence2.length < 1700) {
            // Use the improved algorithm for small files
            this.dynamicProgrammingDiffing.computeWithScore(
                sequence1,
                sequence2,
                timeout,
                (offset1, offset2) ->
                    originalLines[offset1] == modifiedLines[offset2]
                        ? (modifiedLines[offset2].length == 0
                            ? 0.1
                            : 1 + Math.log(1 + modifiedLines[offset2].length))
                        : 0.99
            );
        }
        else {
            this.myersDiffingAlgorithm.compute(
                sequence1,
                sequence2,
                timeout
            );
        }

        var lineAlignments = lineAlignmentResult.diffs;
        var hitTimeout = lineAlignmentResult.hitTimeout;
        lineAlignments = HeuristicSequenceOptimizations.optimizeSequenceDiffs(sequence1, sequence2, lineAlignments);
        lineAlignments = HeuristicSequenceOptimizations.removeVeryShortMatchingLinesBetweenDiffs(sequence1, sequence2, lineAlignments);

        final alignments:Array<RangeMapping> = [];

        var seq1LastStart = 0;
        var seq2LastStart = 0;

        final scanForWhitespaceChanges = (equalLinesCount:Int) -> {
            if (!considerWhitespaceChanges) {
                return;
            }

            for (i in 0...equalLinesCount) {
                final seq1Offset = seq1LastStart + i;
                final seq2Offset = seq2LastStart + i;
                if (originalLines[seq1Offset] != modifiedLines[seq2Offset]) {
                    // This is because of whitespace changes, diff these lines
                    final characterDiffs = this.refineDiff(originalLines, modifiedLines, new SequenceDiff(
                        new OffsetRange(seq1Offset, seq1Offset + 1),
                        new OffsetRange(seq2Offset, seq2Offset + 1)
                    ), timeout, considerWhitespaceChanges);
                    for (a in characterDiffs.mappings) {
                        alignments.push(a);
                    }
                    if (characterDiffs.hitTimeout) {
                        hitTimeout = true;
                    }
                }
            }
        };

        for (diff in lineAlignments) {
            Assert.assertFn(() -> diff.seq1Range.start - seq1LastStart == diff.seq2Range.start - seq2LastStart);

            final equalLinesCount = diff.seq1Range.start - seq1LastStart;

            scanForWhitespaceChanges(equalLinesCount);

            seq1LastStart = diff.seq1Range.endExclusive;
            seq2LastStart = diff.seq2Range.endExclusive;

            final characterDiffs = this.refineDiff(originalLines, modifiedLines, diff, timeout, considerWhitespaceChanges);
            if (characterDiffs.hitTimeout) {
                hitTimeout = true;
            }
            for (a in characterDiffs.mappings) {
                alignments.push(a);
            }
        }

        scanForWhitespaceChanges(originalLines.length - seq1LastStart);

        final changes = lineRangeMappingFromRangeMappings(alignments, originalLines, modifiedLines);

        var moves:Array<MovedText> = [];
        if (options.computeMoves) {
            moves = this.computeMoves(changes, originalLines, modifiedLines, originalLinesHashes, modifiedLinesHashes, timeout, considerWhitespaceChanges);
        }

        // Make sure all ranges are valid
        Assert.assertFn(() -> {
            function validatePosition(pos:Position, lines:Array<String>):Bool {
                if (pos.lineNumber < 1 || pos.lineNumber > lines.length) {
                    return false;
                }
                final line = lines[pos.lineNumber - 1];
                if (pos.column < 1 || pos.column > line.length + 1) {
                    return false;
                }
                return true;
            }

            function validateRange(range:LineRange, lines:Array<String>):Bool {
                if (range.startLineNumber < 1 || range.startLineNumber > lines.length + 1) {
                    return false;
                }
                if (range.endLineNumberExclusive < 1 || range.endLineNumberExclusive > lines.length + 1) {
                    return false;
                }
                return true;
            }

            for (c in changes) {
                if (c.innerChanges == null) {
                    return false;
                }
                for (ic in c.innerChanges) {
                    final valid = validatePosition(ic.modifiedRange.getStartPosition(), modifiedLines) && validatePosition(ic.modifiedRange.getEndPosition(), modifiedLines) &&
                        validatePosition(ic.originalRange.getStartPosition(), originalLines) && validatePosition(ic.originalRange.getEndPosition(), originalLines);
                    if (!valid) {
                        return false;
                    }
                }
                if (!validateRange(c.modified, modifiedLines) || !validateRange(c.original, originalLines)) {
                    return false;
                }
            }
            return true;
        });

        return new LinesDiff(changes, moves, hitTimeout);
    }

    function computeMoves(
        changes:Array<DetailedLineRangeMapping>,
        originalLines:Array<String>,
        modifiedLines:Array<String>,
        hashedOriginalLines:Array<Int>,
        hashedModifiedLines:Array<Int>,
        timeout:ITimeout,
        considerWhitespaceChanges:Bool
    ):Array<MovedText> {
        final moves = ComputeMovedLines.computeMovedLines(
            changes,
            originalLines,
            modifiedLines,
            hashedOriginalLines,
            hashedModifiedLines,
            timeout
        );
        final movesWithDiffs = moves.map(m -> {
            final moveChanges = this.refineDiff(originalLines, modifiedLines, new SequenceDiff(
                m.original.toOffsetRange(),
                m.modified.toOffsetRange()
            ), timeout, considerWhitespaceChanges);
            final mappings = lineRangeMappingFromRangeMappings(moveChanges.mappings, originalLines, modifiedLines, true);
            return new MovedText(m, mappings);
        });
        return movesWithDiffs;
    }

    function refineDiff(originalLines:Array<String>, modifiedLines:Array<String>, diff:SequenceDiff, timeout:ITimeout, considerWhitespaceChanges:Bool):{mappings:Array<RangeMapping>, hitTimeout:Bool} {
        final lineRangeMapping = toLineRangeMapping(diff);
        final rangeMapping = lineRangeMapping.toRangeMapping2(originalLines, modifiedLines);

        final slice1 = new LinesSliceCharSequence(originalLines, rangeMapping.originalRange, considerWhitespaceChanges);
        final slice2 = new LinesSliceCharSequence(modifiedLines, rangeMapping.modifiedRange, considerWhitespaceChanges);

        final diffResult = slice1.length + slice2.length < 500
            ? this.dynamicProgrammingDiffing.compute(slice1, slice2, timeout)
            : this.myersDiffingAlgorithm.compute(slice1, slice2, timeout);

        var diffs = diffResult.diffs;
        diffs = HeuristicSequenceOptimizations.optimizeSequenceDiffs(slice1, slice2, diffs);
        diffs = HeuristicSequenceOptimizations.extendDiffsToEntireWordIfAppropriate(slice1, slice2, diffs);
        diffs = HeuristicSequenceOptimizations.removeShortMatches(slice1, slice2, diffs);
        diffs = HeuristicSequenceOptimizations.removeVeryShortMatchingTextBetweenLongDiffs(slice1, slice2, diffs);

        final result = diffs.map(
            (d) ->
                new RangeMapping(
                    slice1.translateRange(d.seq1Range),
                    slice2.translateRange(d.seq2Range)
                )
        );

        // Assert: result applied on original should be the same as diff applied to original

        return {
            mappings: result,
            hitTimeout: diffResult.hitTimeout,
        };
    }

    public static function lineRangeMappingFromRangeMappings(alignments:Array<RangeMapping>, originalLines:Array<String>, modifiedLines:Array<String>, dontAssertStartLine:Bool = false):Array<DetailedLineRangeMapping> {
        final changes:Array<DetailedLineRangeMapping> = [];
        for (g in Arrays.groupAdjacentBy(
            alignments.map(a -> getLineRangeMapping(a, originalLines, modifiedLines)),
            (a1, a2) ->
                a1.original.overlapOrTouch(a2.original)
                || a1.modified.overlapOrTouch(a2.modified)
        )) {
            final first = g[0];
            final last = g[g.length - 1];

            changes.push(new DetailedLineRangeMapping(
                first.original.join(last.original),
                first.modified.join(last.modified),
                g.map(a -> a.innerChanges[0])
            ));
        }

        Assert.assertFn(() -> {
            if (!dontAssertStartLine && changes.length > 0) {
                if (changes[0].modified.startLineNumber != changes[0].original.startLineNumber) {
                    return false;
                }
                if (modifiedLines.length - changes[changes.length - 1].modified.endLineNumberExclusive != originalLines.length - changes[changes.length - 1].original.endLineNumberExclusive) {
                    return false;
                }
            }
            return Assert.checkAdjacentItems(changes,
                (m1, m2) -> m2.original.startLineNumber - m1.original.endLineNumberExclusive == m2.modified.startLineNumber - m1.modified.endLineNumberExclusive &&
                    // There has to be an unchanged line in between (otherwise both diffs should have been joined)
                    m1.original.endLineNumberExclusive < m2.original.startLineNumber &&
                    m1.modified.endLineNumberExclusive < m2.modified.startLineNumber
            );
        });

        return changes;
    }

    public static function getLineRangeMapping(rangeMapping:RangeMapping, originalLines:Array<String>, modifiedLines:Array<String>):DetailedLineRangeMapping {
        var lineStartDelta = 0;
        var lineEndDelta = 0;

        // rangeMapping describes the edit that replaces `rangeMapping.originalRange` with `newText := getText(modifiedLines, rangeMapping.modifiedRange)`.

        // original: ]xxx \n <- this line is not modified
        // modified: ]xx  \n
        if (rangeMapping.modifiedRange.endColumn == 1 && rangeMapping.originalRange.endColumn == 1
            && rangeMapping.originalRange.startLineNumber + lineStartDelta <= rangeMapping.originalRange.endLineNumber
            && rangeMapping.modifiedRange.startLineNumber + lineStartDelta <= rangeMapping.modifiedRange.endLineNumber) {
            // We can only do this if the range is not empty yet
            lineEndDelta = -1;
        }

        // original: xxx[ \n <- this line is not modified
        // modified: xxx[ \n
        if (rangeMapping.modifiedRange.startColumn - 1 >= modifiedLines[rangeMapping.modifiedRange.startLineNumber - 1].length
            && rangeMapping.originalRange.startColumn - 1 >= originalLines[rangeMapping.originalRange.startLineNumber - 1].length
            && rangeMapping.originalRange.startLineNumber <= rangeMapping.originalRange.endLineNumber + lineEndDelta
            && rangeMapping.modifiedRange.startLineNumber <= rangeMapping.modifiedRange.endLineNumber + lineEndDelta) {
            // We can only do this if the range is not empty yet
            lineStartDelta = 1;
        }

        final originalLineRange = new LineRange(
            rangeMapping.originalRange.startLineNumber + lineStartDelta,
            rangeMapping.originalRange.endLineNumber + 1 + lineEndDelta
        );
        final modifiedLineRange = new LineRange(
            rangeMapping.modifiedRange.startLineNumber + lineStartDelta,
            rangeMapping.modifiedRange.endLineNumber + 1 + lineEndDelta
        );

        return new DetailedLineRangeMapping(originalLineRange, modifiedLineRange, [rangeMapping]);
    }

    static function toLineRangeMapping(sequenceDiff:SequenceDiff):LineRangeMapping {
        return new LineRangeMapping(
            new LineRange(sequenceDiff.seq1Range.start + 1, sequenceDiff.seq1Range.endExclusive + 1),
            new LineRange(sequenceDiff.seq2Range.start + 1, sequenceDiff.seq2Range.endExclusive + 1)
        );
    }

}
