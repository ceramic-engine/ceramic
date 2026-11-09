// Ported from vscode src/vs/editor/common/diff/defaultLinesDiffComputer/computeMovedLines.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.diff.defaultLinesDiffComputer;

import cityscape.base.common.Arrays;
import cityscape.common.core.LineRange;
import cityscape.common.core.Range;
import cityscape.common.diff.RangeMapping.DetailedLineRangeMapping;
import cityscape.common.diff.RangeMapping.LineRangeMapping;
import cityscape.common.diff.defaultLinesDiffComputer.Utils.CharKeys;
import cityscape.common.diff.defaultLinesDiffComputer.Utils.LineRangeFragment;
import cityscape.common.diff.defaultLinesDiffComputer.Utils.isSpace;
import cityscape.common.diff.defaultLinesDiffComputer.algorithms.DiffAlgorithm;
import cityscape.common.diff.defaultLinesDiffComputer.algorithms.MyersDiffAlgorithm;
import haxe.ds.ArraySort;

private class PossibleMapping {
    public var modifiedLineRange:LineRange;
    public var originalLineRange:LineRange;

    public function new(modifiedLineRange:LineRange, originalLineRange:LineRange) {
        this.modifiedLineRange = modifiedLineRange;
        this.originalLineRange = originalLineRange;
    }
}

/**
 * Module functions of computeMovedLines.ts.
 */
class ComputeMovedLines {

    public static function computeMovedLines(
        changes:Array<DetailedLineRangeMapping>,
        originalLines:Array<String>,
        modifiedLines:Array<String>,
        hashedOriginalLines:Array<Int>,
        hashedModifiedLines:Array<Int>,
        timeout:ITimeout
    ):Array<LineRangeMapping> {
        final simple = computeMovesFromSimpleDeletionsToSimpleInsertions(changes, originalLines, modifiedLines, timeout);
        var moves = simple.moves;
        final excludedChanges = simple.excludedChanges;

        if (!timeout.isValid()) {
            return [];
        }

        final filteredChanges = changes.filter(c -> excludedChanges.indexOf(c) == -1);
        final unchangedMoves = computeUnchangedMoves(filteredChanges, hashedOriginalLines, hashedModifiedLines, originalLines, modifiedLines, timeout);
        Arrays.pushMany(moves, unchangedMoves);

        moves = joinCloseConsecutiveMoves(moves);
        // Ignore too short moves
        moves = moves.filter(current -> {
            final lines = current.original.toOffsetRange().slice(originalLines).map(l -> Utils.jsTrim(l));
            final originalText = lines.join('\n');
            return originalText.length >= 15 && countWhere(lines, l -> l.length >= 2) >= 2;
        });
        moves = removeMovesInSameDiff(changes, moves);

        return moves;
    }

    static function countWhere<T>(arr:Array<T>, predicate:(t:T) -> Bool):Int {
        var count = 0;
        for (t in arr) {
            if (predicate(t)) {
                count++;
            }
        }
        return count;
    }

    static function computeMovesFromSimpleDeletionsToSimpleInsertions(
        changes:Array<DetailedLineRangeMapping>,
        originalLines:Array<String>,
        modifiedLines:Array<String>,
        timeout:ITimeout
    ):{moves:Array<LineRangeMapping>, excludedChanges:Array<DetailedLineRangeMapping>} {
        final moves:Array<LineRangeMapping> = [];

        final chrKeys = new CharKeys();
        final deletions = changes
            .filter(c -> c.modified.isEmpty && c.original.length >= 3)
            .map(d -> new LineRangeFragment(d.original, originalLines, d, chrKeys));
        // A JavaScript `Set`: insertion order, `delete` keeps the order of the others
        final insertions = changes
            .filter(c -> c.original.isEmpty && c.modified.length >= 3)
            .map(d -> new LineRangeFragment(d.modified, modifiedLines, d, chrKeys));

        final excludedChanges:Array<DetailedLineRangeMapping> = [];

        for (deletion in deletions) {
            var highestSimilarity:Float = -1;
            var best:Null<LineRangeFragment> = null;
            for (insertion in insertions) {
                final similarity = deletion.computeSimilarity(insertion);
                if (similarity > highestSimilarity) {
                    highestSimilarity = similarity;
                    best = insertion;
                }
            }

            if (highestSimilarity > 0.90 && best != null) {
                insertions.remove(best);
                moves.push(new LineRangeMapping(deletion.range, best.range));
                if (excludedChanges.indexOf(deletion.source) == -1) {
                    excludedChanges.push(deletion.source);
                }
                if (excludedChanges.indexOf(best.source) == -1) {
                    excludedChanges.push(best.source);
                }
            }

            if (!timeout.isValid()) {
                return {moves: moves, excludedChanges: excludedChanges};
            }
        }

        return {moves: moves, excludedChanges: excludedChanges};
    }

    static function computeUnchangedMoves(
        changes:Array<DetailedLineRangeMapping>,
        hashedOriginalLines:Array<Int>,
        hashedModifiedLines:Array<Int>,
        originalLines:Array<String>,
        modifiedLines:Array<String>,
        timeout:ITimeout
    ):Array<LineRangeMapping> {
        final moves:Array<LineRangeMapping> = [];

        // Monaco's `SetMap<string, { range: LineRange }>` (the values are distinct objects, kept in insertion order)
        final original3LineHashes = new Map<String, Array<LineRange>>();

        for (change in changes) {
            var i = change.original.startLineNumber;
            while (i < change.original.endLineNumberExclusive - 2) {
                final key = hashedOriginalLines[i - 1] + ':' + hashedOriginalLines[i + 1 - 1] + ':' + hashedOriginalLines[i + 2 - 1];
                var values = original3LineHashes.get(key);
                if (values == null) {
                    values = [];
                    original3LineHashes.set(key, values);
                }
                values.push(new LineRange(i, i + 3));
                i++;
            }
        }

        final possibleMappings:Array<PossibleMapping> = [];

        ArraySort.sort(changes, Arrays.compareByNumber((c:DetailedLineRangeMapping) -> c.modified.startLineNumber));

        for (change in changes) {
            var lastMappings:Array<PossibleMapping> = [];
            var i = change.modified.startLineNumber;
            while (i < change.modified.endLineNumberExclusive - 2) {
                final key = hashedModifiedLines[i - 1] + ':' + hashedModifiedLines[i + 1 - 1] + ':' + hashedModifiedLines[i + 2 - 1];
                final currentModifiedRange = new LineRange(i, i + 3);

                final nextMappings:Array<PossibleMapping> = [];
                final values = original3LineHashes.get(key);
                if (values != null) {
                    for (range in values) {
                        var extended = false;
                        for (lastMapping in lastMappings) {
                            // does this match extend some last match?
                            if (lastMapping.originalLineRange.endLineNumberExclusive + 1 == range.endLineNumberExclusive &&
                                lastMapping.modifiedLineRange.endLineNumberExclusive + 1 == currentModifiedRange.endLineNumberExclusive) {
                                lastMapping.originalLineRange = new LineRange(lastMapping.originalLineRange.startLineNumber, range.endLineNumberExclusive);
                                lastMapping.modifiedLineRange = new LineRange(lastMapping.modifiedLineRange.startLineNumber, currentModifiedRange.endLineNumberExclusive);
                                nextMappings.push(lastMapping);
                                extended = true;
                                break;
                            }
                        }
                        if (extended) {
                            continue;
                        }

                        final mapping = new PossibleMapping(currentModifiedRange, range);
                        possibleMappings.push(mapping);
                        nextMappings.push(mapping);
                    }
                }
                lastMappings = nextMappings;
                i++;
            }

            if (!timeout.isValid()) {
                return [];
            }
        }

        ArraySort.sort(possibleMappings, Arrays.reverseOrder(Arrays.compareByNumber((m:PossibleMapping) -> m.modifiedLineRange.length)));

        final modifiedSet = new LineRangeSet();
        final originalSet = new LineRangeSet();

        for (mapping in possibleMappings) {

            final diffOrigToMod = mapping.modifiedLineRange.startLineNumber - mapping.originalLineRange.startLineNumber;
            final modifiedSections = modifiedSet.subtractFrom(mapping.modifiedLineRange);
            final originalTranslatedSections = originalSet.subtractFrom(mapping.originalLineRange).getWithDelta(diffOrigToMod);

            final modifiedIntersectedSections = modifiedSections.getIntersection(originalTranslatedSections);

            for (s in modifiedIntersectedSections.ranges) {
                if (s.length < 3) {
                    continue;
                }
                final modifiedLineRange = s;
                final originalLineRange = s.delta(-diffOrigToMod);

                moves.push(new LineRangeMapping(originalLineRange, modifiedLineRange));

                modifiedSet.addRange(modifiedLineRange);
                originalSet.addRange(originalLineRange);
            }
        }

        ArraySort.sort(moves, Arrays.compareByNumber((m:LineRangeMapping) -> m.original.startLineNumber));

        final monotonousChanges = new MonotonousArray(changes);
        for (i in 0...moves.length) {
            final move = moves[i];
            final firstTouchingChangeOrig = monotonousChanges.findLastMonotonous(c -> c.original.startLineNumber <= move.original.startLineNumber);
            final firstTouchingChangeMod = Arrays.findLastMonotonous(changes, c -> c.modified.startLineNumber <= move.modified.startLineNumber);
            final linesAbove = Std.int(Math.max(
                move.original.startLineNumber - firstTouchingChangeOrig.original.startLineNumber,
                move.modified.startLineNumber - firstTouchingChangeMod.modified.startLineNumber
            ));

            final lastTouchingChangeOrig = monotonousChanges.findLastMonotonous(c -> c.original.startLineNumber < move.original.endLineNumberExclusive);
            final lastTouchingChangeMod = Arrays.findLastMonotonous(changes, c -> c.modified.startLineNumber < move.modified.endLineNumberExclusive);
            final linesBelow = Std.int(Math.max(
                lastTouchingChangeOrig.original.endLineNumberExclusive - move.original.endLineNumberExclusive,
                lastTouchingChangeMod.modified.endLineNumberExclusive - move.modified.endLineNumberExclusive
            ));

            var extendToTop = 0;
            while (extendToTop < linesAbove) {
                final origLine = move.original.startLineNumber - extendToTop - 1;
                final modLine = move.modified.startLineNumber - extendToTop - 1;
                if (origLine > originalLines.length || modLine > modifiedLines.length) {
                    break;
                }
                if (modifiedSet.contains(modLine) || originalSet.contains(origLine)) {
                    break;
                }
                if (!areLinesSimilar(originalLines[origLine - 1], modifiedLines[modLine - 1], timeout)) {
                    break;
                }
                extendToTop++;
            }

            if (extendToTop > 0) {
                originalSet.addRange(new LineRange(move.original.startLineNumber - extendToTop, move.original.startLineNumber));
                modifiedSet.addRange(new LineRange(move.modified.startLineNumber - extendToTop, move.modified.startLineNumber));
            }

            var extendToBottom = 0;
            while (extendToBottom < linesBelow) {
                final origLine = move.original.endLineNumberExclusive + extendToBottom;
                final modLine = move.modified.endLineNumberExclusive + extendToBottom;
                if (origLine > originalLines.length || modLine > modifiedLines.length) {
                    break;
                }
                if (modifiedSet.contains(modLine) || originalSet.contains(origLine)) {
                    break;
                }
                if (!areLinesSimilar(originalLines[origLine - 1], modifiedLines[modLine - 1], timeout)) {
                    break;
                }
                extendToBottom++;
            }

            if (extendToBottom > 0) {
                originalSet.addRange(new LineRange(move.original.endLineNumberExclusive, move.original.endLineNumberExclusive + extendToBottom));
                modifiedSet.addRange(new LineRange(move.modified.endLineNumberExclusive, move.modified.endLineNumberExclusive + extendToBottom));
            }

            if (extendToTop > 0 || extendToBottom > 0) {
                moves[i] = new LineRangeMapping(
                    new LineRange(move.original.startLineNumber - extendToTop, move.original.endLineNumberExclusive + extendToBottom),
                    new LineRange(move.modified.startLineNumber - extendToTop, move.modified.endLineNumberExclusive + extendToBottom)
                );
            }
        }

        return moves;
    }

    static function areLinesSimilar(line1:String, line2:String, timeout:ITimeout):Bool {
        if (Utils.jsTrim(line1) == Utils.jsTrim(line2)) {
            return true;
        }
        if (line1.length > 300 && line2.length > 300) {
            return false;
        }

        final myersDiffingAlgorithm = new MyersDiffAlgorithm();
        final result = myersDiffingAlgorithm.compute(
            new LinesSliceCharSequence([line1], new Range(1, 1, 1, line1.length), false),
            new LinesSliceCharSequence([line2], new Range(1, 1, 1, line2.length), false),
            timeout
        );
        var commonNonSpaceCharCount = 0;
        final inverted = SequenceDiff.invert(result.diffs, line1.length);
        for (seq in inverted) {
            for (idx in seq.seq1Range.start...seq.seq1Range.endExclusive) {
                // JavaScript's charCodeAt out of range is NaN, which is not a space
                if (idx >= line1.length || !isSpace(StringTools.fastCodeAt(line1, idx))) {
                    commonNonSpaceCharCount++;
                }
            }
        }

        function countNonWsChars(str:String):Int {
            var count = 0;
            for (i in 0...line1.length) {
                if (i >= str.length || !isSpace(StringTools.fastCodeAt(str, i))) {
                    count++;
                }
            }
            return count;
        }

        final longerLineLength = countNonWsChars(line1.length > line2.length ? line1 : line2);
        final r = commonNonSpaceCharCount / longerLineLength > 0.6 && longerLineLength > 10;
        return r;
    }

    static function joinCloseConsecutiveMoves(moves:Array<LineRangeMapping>):Array<LineRangeMapping> {
        if (moves.length == 0) {
            return moves;
        }

        ArraySort.sort(moves, Arrays.compareByNumber((m:LineRangeMapping) -> m.original.startLineNumber));

        final result = [moves[0]];
        for (i in 1...moves.length) {
            final last = result[result.length - 1];
            final current = moves[i];

            final originalDist = current.original.startLineNumber - last.original.endLineNumberExclusive;
            final modifiedDist = current.modified.startLineNumber - last.modified.endLineNumberExclusive;
            final currentMoveAfterLast = originalDist >= 0 && modifiedDist >= 0;

            if (currentMoveAfterLast && originalDist + modifiedDist <= 2) {
                result[result.length - 1] = last.join(current);
                continue;
            }

            result.push(current);
        }
        return result;
    }

    static function removeMovesInSameDiff(changes:Array<DetailedLineRangeMapping>, moves:Array<LineRangeMapping>):Array<LineRangeMapping> {
        final changesMonotonous = new MonotonousArray(changes);
        moves = moves.filter(m -> {
            final found:Null<LineRangeMapping> = changesMonotonous.findLastMonotonous(c -> c.original.startLineNumber < m.original.endLineNumberExclusive);
            final diffBeforeEndOfMoveOriginal:LineRangeMapping = found != null ? found
                : new LineRangeMapping(new LineRange(1, 1), new LineRange(1, 1));
            final diffBeforeEndOfMoveModified:Null<LineRangeMapping> = Arrays.findLastMonotonous(changes, c -> c.modified.startLineNumber < m.modified.endLineNumberExclusive);

            final differentDiffs = diffBeforeEndOfMoveOriginal != diffBeforeEndOfMoveModified;
            return differentDiffs;
        });
        return moves;
    }

}
