// Ported from vscode src/vs/base/common/diff/diffChange.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common.diff;

/**
 * Represents information about a specific difference between two sequences.
 */
class DiffChange {

    /**
     * The position of the first element in the original sequence which
     * this change affects.
     */
    public var originalStart:Int;

    /**
     * The number of elements from the original sequence which were
     * affected.
     */
    public var originalLength:Int;

    /**
     * The position of the first element in the modified sequence which
     * this change affects.
     */
    public var modifiedStart:Int;

    /**
     * The number of elements from the modified sequence which were
     * affected (added).
     */
    public var modifiedLength:Int;

    /**
     * Constructs a new DiffChange with the given sequence information
     * and content.
     */
    public function new(originalStart:Int, originalLength:Int, modifiedStart:Int, modifiedLength:Int) {
        this.originalStart = originalStart;
        this.originalLength = originalLength;
        this.modifiedStart = modifiedStart;
        this.modifiedLength = modifiedLength;
    }

    /**
     * The end point (exclusive) of the change in the original sequence.
     */
    public function getOriginalEnd():Int {
        return this.originalStart + this.originalLength;
    }

    /**
     * The end point (exclusive) of the change in the modified sequence.
     */
    public function getModifiedEnd():Int {
        return this.modifiedStart + this.modifiedLength;
    }

}
