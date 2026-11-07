// Ported from gpui-kit 0.8.1: crates/base/src/input/base/undo_manager.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * One transaction handed back to be replayed, with the cursors to restore
 * once the changes have been applied.
 */
class Replay {

    public final changes:Array<Change>;

    public final selections:Null<Array<CursorSelection>>;

    public final autoClosedPairs:Null<AutoClosedPairs>;

    public function new(changes:Array<Change>, selections:Null<Array<CursorSelection>>, autoClosedPairs:Null<AutoClosedPairs>) {
        this.changes = changes;
        this.selections = selections;
        this.autoClosedPairs = autoClosedPairs;
    }

}
