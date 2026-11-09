// Ported from vscode src/vs/editor/common/diff/rangeMapping.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.diff;

import cityscape.base.common.Errors.BugIndicatingError;
import cityscape.common.core.LineRange;
import cityscape.common.core.Position;
import cityscape.common.core.Range;

/**
 * Maps a line range in the original text model to a line range in the modified text model.
 */
class LineRangeMapping {

    /**
     * Monaco's `Number.MAX_SAFE_INTEGER` columns (a column past the end of
     * any line). Positions are 32 bit integers here: Cityscape uses
     * `Constants.MAX_SAFE_SMALL_INTEGER` (2^30), like the other ported code.
     */
    public static inline final MAX_COLUMN:Int = 1 << 30;

    public static function inverse(mapping:Array<LineRangeMapping>, originalLineCount:Int, modifiedLineCount:Int):Array<LineRangeMapping> {
        final result:Array<LineRangeMapping> = [];
        var lastOriginalEndLineNumber = 1;
        var lastModifiedEndLineNumber = 1;

        for (m in mapping) {
            final r = new LineRangeMapping(
                new LineRange(lastOriginalEndLineNumber, m.original.startLineNumber),
                new LineRange(lastModifiedEndLineNumber, m.modified.startLineNumber)
            );
            if (!r.modified.isEmpty) {
                result.push(r);
            }
            lastOriginalEndLineNumber = m.original.endLineNumberExclusive;
            lastModifiedEndLineNumber = m.modified.endLineNumberExclusive;
        }
        final r = new LineRangeMapping(
            new LineRange(lastOriginalEndLineNumber, originalLineCount + 1),
            new LineRange(lastModifiedEndLineNumber, modifiedLineCount + 1)
        );
        if (!r.modified.isEmpty) {
            result.push(r);
        }
        return result;
    }

    public static function clip(mapping:Array<LineRangeMapping>, originalRange:LineRange, modifiedRange:LineRange):Array<LineRangeMapping> {
        final result:Array<LineRangeMapping> = [];
        for (m in mapping) {
            final original = m.original.intersect(originalRange);
            final modified = m.modified.intersect(modifiedRange);
            if (original != null && !original.isEmpty && modified != null && !modified.isEmpty) {
                result.push(new LineRangeMapping(original, modified));
            }
        }
        return result;
    }

    /**
     * The line range in the original text model.
     */
    public final original:LineRange;

    /**
     * The line range in the modified text model.
     */
    public final modified:LineRange;

    public function new(originalRange:LineRange, modifiedRange:LineRange) {
        this.original = originalRange;
        this.modified = modifiedRange;
    }

    public function toString():String {
        return '{' + this.original.toString() + '->' + this.modified.toString() + '}';
    }

    public function flip():LineRangeMapping {
        return new LineRangeMapping(this.modified, this.original);
    }

    public function join(other:LineRangeMapping):LineRangeMapping {
        return new LineRangeMapping(
            this.original.join(other.original),
            this.modified.join(other.modified)
        );
    }

    public var changedLineCount(get, never):Int;
    function get_changedLineCount():Int {
        return Std.int(Math.max(this.original.length, this.modified.length));
    }

    /**
     * This method assumes that the LineRangeMapping describes a valid diff!
     * I.e. if one range is empty, the other range cannot be the entire document.
     * It avoids various problems when the line range points to non-existing line-numbers.
     */
    public function toRangeMapping():RangeMapping {
        final origInclusiveRange = this.original.toInclusiveRange();
        final modInclusiveRange = this.modified.toInclusiveRange();
        if (origInclusiveRange != null && modInclusiveRange != null) {
            return new RangeMapping(origInclusiveRange, modInclusiveRange);
        }
        else if (this.original.startLineNumber == 1 || this.modified.startLineNumber == 1) {
            if (!(this.modified.startLineNumber == 1 && this.original.startLineNumber == 1)) {
                // If one line range starts at 1, the other one must start at 1 as well.
                throw new BugIndicatingError('not a valid diff');
            }

            // Because one range is empty and both ranges start at line 1, none of the ranges can cover all lines.
            // Thus, `endLineNumberExclusive` is a valid line number.
            return new RangeMapping(
                new Range(this.original.startLineNumber, 1, this.original.endLineNumberExclusive, 1),
                new Range(this.modified.startLineNumber, 1, this.modified.endLineNumberExclusive, 1)
            );
        }
        else {
            // We can assume here that both startLineNumbers are greater than 1.
            return new RangeMapping(
                new Range(this.original.startLineNumber - 1, MAX_COLUMN, this.original.endLineNumberExclusive - 1, MAX_COLUMN),
                new Range(this.modified.startLineNumber - 1, MAX_COLUMN, this.modified.endLineNumberExclusive - 1, MAX_COLUMN)
            );
        }
    }

    /**
     * This method assumes that the LineRangeMapping describes a valid diff!
     * I.e. if one range is empty, the other range cannot be the entire document.
     * It avoids various problems when the line range points to non-existing line-numbers.
     */
    public function toRangeMapping2(original:Array<String>, modified:Array<String>):RangeMapping {
        if (isValidLineNumber(this.original.endLineNumberExclusive, original)
            && isValidLineNumber(this.modified.endLineNumberExclusive, modified)) {
            return new RangeMapping(
                new Range(this.original.startLineNumber, 1, this.original.endLineNumberExclusive, 1),
                new Range(this.modified.startLineNumber, 1, this.modified.endLineNumberExclusive, 1)
            );
        }

        if (!this.original.isEmpty && !this.modified.isEmpty) {
            return new RangeMapping(
                Range.fromPositions(
                    new Position(this.original.startLineNumber, 1),
                    normalizePosition(new Position(this.original.endLineNumberExclusive - 1, MAX_COLUMN), original)
                ),
                Range.fromPositions(
                    new Position(this.modified.startLineNumber, 1),
                    normalizePosition(new Position(this.modified.endLineNumberExclusive - 1, MAX_COLUMN), modified)
                )
            );
        }

        if (this.original.startLineNumber > 1 && this.modified.startLineNumber > 1) {
            return new RangeMapping(
                Range.fromPositions(
                    normalizePosition(new Position(this.original.startLineNumber - 1, MAX_COLUMN), original),
                    normalizePosition(new Position(this.original.endLineNumberExclusive - 1, MAX_COLUMN), original)
                ),
                Range.fromPositions(
                    normalizePosition(new Position(this.modified.startLineNumber - 1, MAX_COLUMN), modified),
                    normalizePosition(new Position(this.modified.endLineNumberExclusive - 1, MAX_COLUMN), modified)
                )
            );
        }

        // Situation now: one range is empty and one range touches the last line and one range starts at line 1.
        // I don't think this can happen.

        throw new BugIndicatingError();
    }

    static function normalizePosition(position:Position, content:Array<String>):Position {
        if (position.lineNumber < 1) {
            return new Position(1, 1);
        }
        if (position.lineNumber > content.length) {
            return new Position(content.length, content[content.length - 1].length + 1);
        }
        final line = content[position.lineNumber - 1];
        if (position.column > line.length + 1) {
            return new Position(position.lineNumber, line.length + 1);
        }
        return position;
    }

    static function isValidLineNumber(lineNumber:Int, lines:Array<String>):Bool {
        return lineNumber >= 1 && lineNumber <= lines.length;
    }

}

/**
 * Maps a line range in the original text model to a line range in the modified text model.
 * Also contains inner range mappings.
 */
class DetailedLineRangeMapping extends LineRangeMapping {

    public static function fromRangeMappings(rangeMappings:Array<RangeMapping>):DetailedLineRangeMapping {
        final originalRange = LineRange.joinStatic(rangeMappings.map(r -> LineRange.fromRangeInclusive(r.originalRange)));
        final modifiedRange = LineRange.joinStatic(rangeMappings.map(r -> LineRange.fromRangeInclusive(r.modifiedRange)));
        return new DetailedLineRangeMapping(originalRange, modifiedRange, rangeMappings);
    }

    /**
     * If inner changes have not been computed, this is set to null.
     * Otherwise, it represents the character-level diff in this line range.
     * The original range of each range mapping should be contained in the original line range (same for modified), exceptions are new-lines.
     * Must not be an empty array.
     */
    public final innerChanges:Null<Array<RangeMapping>>;

    public function new(originalRange:LineRange, modifiedRange:LineRange, innerChanges:Null<Array<RangeMapping>>) {
        super(originalRange, modifiedRange);
        this.innerChanges = innerChanges;
    }

    override public function flip():DetailedLineRangeMapping {
        final innerChanges = this.innerChanges;
        return new DetailedLineRangeMapping(this.modified, this.original, innerChanges != null ? innerChanges.map(c -> c.flip()) : null);
    }

    public function withInnerChangesFromLineRanges():DetailedLineRangeMapping {
        return new DetailedLineRangeMapping(this.original, this.modified, [this.toRangeMapping()]);
    }

}

/**
 * Maps a range in the original text model to a range in the modified text model.
 */
class RangeMapping {

    public static function assertSorted(rangeMappings:Array<RangeMapping>):Void {
        for (i in 1...rangeMappings.length) {
            final previous = rangeMappings[i - 1];
            final current = rangeMappings[i];
            if (!(
                previous.originalRange.getEndPosition().isBeforeOrEqual(current.originalRange.getStartPosition())
                && previous.modifiedRange.getEndPosition().isBeforeOrEqual(current.modifiedRange.getStartPosition())
            )) {
                throw new BugIndicatingError('Range mappings must be sorted');
            }
        }
    }

    /**
     * The original range.
     */
    public final originalRange:Range;

    /**
     * The modified range.
     */
    public final modifiedRange:Range;

    public function new(originalRange:Range, modifiedRange:Range) {
        this.originalRange = originalRange;
        this.modifiedRange = modifiedRange;
    }

    public function toString():String {
        return '{' + this.originalRange.toString() + '->' + this.modifiedRange.toString() + '}';
    }

    public function flip():RangeMapping {
        return new RangeMapping(this.modifiedRange, this.originalRange);
    }

}
