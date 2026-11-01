// Ported from gpui-kit 0.8.1: crates/base/src/undo_history.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

/**
 * A history of grouped undo transactions.
 *
 * Methods returning Rust's `Option<Vec<T>>` return `null` for `None`.
 *
 * Rust stamps changes with `Instant::now()`. Here the clock is a function
 * returning seconds, `haxe.Timer.stamp` by default; pass another one (such
 * as `cx.backgroundExecutor().now`) to follow a test clock.
 */
class UndoHistory<T> {

    final undos:Array<Array<T>> = [];

    final redos:Array<Array<T>> = [];

    /** When the last change was pushed, in clock seconds, or `NaN` (Rust `None`). */
    var lastChangedAt:Float = Math.NaN;

    var undoLimit:Int = 1000;

    /** The grouping interval in seconds, or a negative value (Rust `None`). */
    var groupSeconds:Float = -1.0;

    var grouping:Bool = false;

    var ignoring:Bool = false;

    final clock:Void->Float;

    public function new(?clock:Void->Float) {
        this.clock = clock != null ? clock : haxe.Timer.stamp;
    }

    /**
     * Set the maximum number of undo transactions to keep, defaults to 1000.
     *
     * Lowering the limit immediately removes the oldest undo transactions.
     */
    public function maxUndos(maxUndos:Int):UndoHistory<T> {
        undoLimit = maxUndos;
        enforceMaxUndos();
        return this;
    }

    /**
     * Set the interval, in seconds, in which consecutive changes are grouped.
     *
     * A successful undo or redo ends timed grouping. Explicit grouping is
     * independent and can still append to the current transaction.
     */
    public function groupInterval(groupInterval:Float):UndoHistory<T> {
        groupSeconds = groupInterval;
        return this;
    }

    /**
     * Start explicitly grouping pushed changes into one transaction.
     */
    public function startGrouping():Void {
        grouping = true;
    }

    /**
     * End explicit grouping of pushed changes.
     */
    public function endGrouping():Void {
        grouping = false;
    }

    /**
     * Returns whether history recording is currently ignored.
     */
    public inline function isIgnoring():Bool {
        return ignoring;
    }

    /**
     * Sets whether history recording is currently ignored.
     */
    public function setIgnoring(ignoring:Bool):Void {
        this.ignoring = ignoring;
    }

    /**
     * Pushes a change into the current transaction or starts a new one.
     */
    public function push(item:T):Void {
        if (ignoring || undoLimit == 0) {
            return;
        }

        final groupWithPrevious = grouping
            || (!Math.isNaN(lastChangedAt) && groupSeconds >= 0 && clock() - lastChangedAt <= groupSeconds);

        if (groupWithPrevious && undos.length > 0) {
            undos[undos.length - 1].push(item);
        }
        else {
            undos.push([item]);
            enforceMaxUndos();
        }

        lastChangedAt = clock();
        redos.resize(0);
    }

    /**
     * Undoes the latest transaction, returning changes newest first.
     */
    public function undo():Null<Array<T>> {
        final transaction = undos.pop();
        if (transaction == null) {
            return null;
        }
        final changes = transaction.copy();
        changes.reverse();
        redos.push(transaction);
        lastChangedAt = Math.NaN;
        return changes;
    }

    /**
     * Redoes the latest undone transaction, returning changes oldest first.
     */
    public function redo():Null<Array<T>> {
        if (undoLimit == 0) {
            return null;
        }
        final transaction = redos.pop();
        if (transaction == null) {
            return null;
        }
        final changes = transaction.copy();
        undos.push(transaction);
        enforceMaxUndos();
        lastChangedAt = Math.NaN;
        return changes;
    }

    /**
     * Returns whether an undo transaction is available.
     */
    public inline function canUndo():Bool {
        return undos.length > 0;
    }

    /**
     * Returns whether a redo transaction is available.
     */
    public inline function canRedo():Bool {
        return redos.length > 0;
    }

    /**
     * Clears both undo and redo transactions.
     */
    public function clear():Void {
        undos.resize(0);
        redos.resize(0);
        lastChangedAt = Math.NaN;
    }

    function enforceMaxUndos():Void {
        final excess = undos.length - undoLimit;
        if (excess > 0) {
            undos.splice(0, excess);
        }
    }

}
