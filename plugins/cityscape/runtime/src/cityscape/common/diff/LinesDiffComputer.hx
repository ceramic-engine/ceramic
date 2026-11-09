// Ported from vscode src/vs/editor/common/diff/linesDiffComputer.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.diff;

import cityscape.common.diff.RangeMapping.DetailedLineRangeMapping;
import cityscape.common.diff.RangeMapping.LineRangeMapping;

interface ILinesDiffComputer {
    function computeDiff(originalLines:Array<String>, modifiedLines:Array<String>, options:ILinesDiffComputerOptions):LinesDiff;
}

typedef ILinesDiffComputerOptions = {
    final ignoreTrimWhitespace:Bool;
    final maxComputationTimeMs:Float;
    final computeMoves:Bool;
}

class LinesDiff {

    public final changes:Array<DetailedLineRangeMapping>;

    /**
     * Sorted by original line ranges.
     * The original line ranges and the modified line ranges must be disjoint (but can be touching).
     */
    public final moves:Array<MovedText>;

    /**
     * Indicates if the time out was reached.
     * In that case, the diffs might be an approximation and the user should be asked to rerun the diff with more time.
     */
    public final hitTimeout:Bool;

    public function new(changes:Array<DetailedLineRangeMapping>, moves:Array<MovedText>, hitTimeout:Bool) {
        this.changes = changes;
        this.moves = moves;
        this.hitTimeout = hitTimeout;
    }

}

class MovedText {

    public final lineRangeMapping:LineRangeMapping;

    /**
     * The diff from the original text to the moved text.
     * Must be contained in the original/modified line range.
     * Can be empty if the text didn't change (only moved).
     */
    public final changes:Array<DetailedLineRangeMapping>;

    public function new(lineRangeMapping:LineRangeMapping, changes:Array<DetailedLineRangeMapping>) {
        this.lineRangeMapping = lineRangeMapping;
        this.changes = changes;
    }

    public function flip():MovedText {
        return new MovedText(this.lineRangeMapping.flip(), this.changes.map(c -> c.flip()));
    }

}
