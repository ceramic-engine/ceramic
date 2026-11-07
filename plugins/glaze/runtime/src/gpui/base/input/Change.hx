// Ported from gpui-kit 0.8.1: crates/base/src/input/base/change.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * One text replacement, in the coordinates of the document as it stood
 * immediately before the replacement was applied.
 *
 * Mutable like the Rust struct (the undo manager extends the last change of
 * a typing run in place); `clone()` stands for Rust's clones.
 */
class Change {

    public var tokenDelta:Null<TokenDelta>;

    public var oldRange:Selection;

    public var oldText:String;

    public var newRange:Selection;

    public var newText:String;

    public function new(oldRange:Selection, oldText:String, newRange:Selection, newText:String) {
        this.tokenDelta = null;
        this.oldRange = oldRange;
        this.oldText = oldText;
        this.newRange = newRange;
        this.newText = newText;
    }

    /**
     * The same change as it would read after `delta` bytes were inserted
     * (positive) or removed (negative) ahead of it.
     */
    public function shifted(delta:Int):Change {
        inline function shift(offset:Int):Int {
            final value = offset + delta;
            return value > 0 ? value : 0;
        }
        final change = new Change(new Selection(shift(oldRange.start), shift(oldRange.end)), oldText,
            new Selection(shift(newRange.start), shift(newRange.end)), newText);
        change.tokenDelta = tokenDelta;
        return change;
    }

    public function clone():Change {
        final change = new Change(oldRange.copy(), oldText, newRange.copy(), newText);
        change.tokenDelta = tokenDelta;
        return change;
    }

    /** Rust `PartialEq`. */
    public function equals(other:Null<Change>):Bool {
        return other != null
            && (tokenDelta == null ? other.tokenDelta == null : tokenDelta.equals(other.tokenDelta))
            && other.oldRange.equals(oldRange) && other.oldText == oldText && other.newRange.equals(newRange)
            && other.newText == newText;
    }

    public function toString():String {
        return 'Change { old_range: ' + oldRange.start + '..' + oldRange.end + ', old_text: "' + oldText + '", new_range: '
            + newRange.start + '..' + newRange.end + ', new_text: "' + newText + '" }';
    }

}
