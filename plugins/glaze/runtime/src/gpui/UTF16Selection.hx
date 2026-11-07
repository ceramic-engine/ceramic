// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A selection in a text buffer, in UTF-16 code units.
 * This is different from a range because the head may be before the tail.
 */
class UTF16Selection {

    /**
     * The range of text in the document this selection corresponds to,
     * in UTF-16 code units.
     */
    public final range:Range;

    /**
     * Whether the head of this selection is at the start (true), or end (false)
     * of the range
     */
    public final reversed:Bool;

    public function new(range:Range, reversed:Bool = false) {
        this.range = range;
        this.reversed = reversed;
    }

    public function equals(other:Null<UTF16Selection>):Bool {
        return other != null && range.equals(other.range) && reversed == other.reversed;
    }

    public function toString():String {
        return 'UTF16Selection(' + range + (reversed ? ', reversed' : '') + ')';
    }

}
