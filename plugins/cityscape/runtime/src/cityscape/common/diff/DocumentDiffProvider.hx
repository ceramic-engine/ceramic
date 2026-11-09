// Ported from vscode src/vs/editor/common/diff/documentDiffProvider.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.diff;

import cityscape.common.diff.LinesDiffComputer.MovedText;
import cityscape.common.diff.RangeMapping.DetailedLineRangeMapping;

typedef IDocumentDiffProviderOptions = {
    /**
     * When set to true, the diff should ignore whitespace changes.
     */
    final ignoreTrimWhitespace:Bool;

    /**
     * A diff computation should throw if it takes longer than this value.
     */
    final maxComputationTimeMs:Float;

    /**
     * If set, the diff computation should compute moves in addition to insertions and deletions.
     */
    final computeMoves:Bool;
}

/**
 * Represents a diff between two text models.
 */
class IDocumentDiff {

    /**
     * If true, both text models are identical (byte-wise).
     */
    public final identical:Bool;

    /**
     * If true, the diff computation timed out and the diff might not be accurate.
     */
    public final quitEarly:Bool;

    /**
     * Maps all modified line ranges in the original to the corresponding line ranges in the modified text model.
     */
    public final changes:Array<DetailedLineRangeMapping>;

    /**
     * Sorted by original line ranges.
     * The original line ranges and the modified line ranges must be disjoint (but can be touching).
     */
    public final moves:Array<MovedText>;

    public function new(changes:Array<DetailedLineRangeMapping>, identical:Bool, quitEarly:Bool, moves:Array<MovedText>) {
        this.changes = changes;
        this.identical = identical;
        this.quitEarly = quitEarly;
        this.moves = moves;
    }

}
