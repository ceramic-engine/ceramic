// Ported from gpui-kit 0.8.1: crates/base/src/input/base/undo_manager.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified: deliberate deviation DEV-015 (a typing run may start by replacing text). See DEVIATIONS.md.
package gpui.base.input;

import gpui.util.Utf8;



private class UndoTransaction {

    public var intent:EditIntent;

    public var changes:Array<Change>;

    /**
     * How many changes the most recently appended batch contributed. A batch
     * is one logical edit with one change per cursor. Only a following batch
     * of the same length can coalesce into this transaction.
     */
    public var lastBatchLen:Int;

    /**
     * How many changes were recorded into this transaction. A run of
     * single-cursor keystrokes is merged into one change, so this, not
     * `changes.length`, decides when the transaction is full.
     */
    public var recordedChanges:Int;

    /** The cursors as they stood before this transaction, restored on undo. */
    public var selectionsBefore:Null<Array<CursorSelection>> = null;

    /** The cursors as they stood after it, restored on redo. */
    public var selectionsAfter:Null<Array<CursorSelection>> = null;

    public var autoClosedPairsBefore:Null<AutoClosedPairs> = null;

    public var autoClosedPairsAfter:Null<AutoClosedPairs> = null;

    public function new(intent:EditIntent, lastBatchLen:Int, recordedChanges:Int, changes:Array<Change>) {
        this.intent = intent;
        this.lastBatchLen = lastBatchLen;
        this.recordedChanges = recordedChanges;
        this.changes = changes;
    }

    /**
     * The changes contributed by the most recent batch, which are the ones a
     * following batch has to be adjacent to.
     */
    public function trailingBatch():Array<Change> {
        return changes.slice(changes.length - lastBatchLen);
    }

}

/**
 * A batch of changes being collected between `beginTransaction` and the
 * matching `commitTransaction`.
 */
private class PendingTransaction {

    public var intent:EditIntent;

    public var changes:Array<Change> = [];

    public var selectionsBefore:Null<Array<CursorSelection>> = null;

    public var selectionsAfter:Null<Array<CursorSelection>> = null;

    public var autoClosedPairsBefore:Null<AutoClosedPairs> = null;

    public var autoClosedPairsAfter:Null<AutoClosedPairs> = null;

    public function new(intent:EditIntent) {
        this.intent = intent;
    }

}

/**
 * Coordinates undo and redo as explicit editing transactions.
 *
 * Each edit first creates a transaction. Compatible adjacent transactions
 * may then coalesce until an explicit boundary is encountered. Callers that
 * perform one logical edit through several changes (IME composition, and
 * any multi-cursor edit) bracket those changes with `beginTransaction` and
 * `commitTransaction`. The bracket nests, so an outer caller can group
 * several already-bracketed edits into one undo entry.
 *
 * The recorded changes, selections and pairs are owned by the manager once
 * handed over (Rust moves them in): pass copies when the caller keeps
 * mutating its own. Replays hand out copies.
 */
class UndoManager {

    public static inline final MAX_UNDO_TRANSACTIONS = 1000;

    public static inline final MAX_CHANGES_PER_TRANSACTION = 1000;

    var undoTransactions:Array<UndoTransaction> = [];

    var redoTransactions:Array<UndoTransaction> = [];

    var ignoring:Bool = false;

    var transactionDepth:Int = 0;

    var pending:Null<PendingTransaction> = null;

    var pendingIntent:Null<EditIntent> = null;

    var coalescingBoundary:Bool = false;

    public function new() {}

    /**
     * The intent requested for the next recorded change, taken by the edit
     * that records it.
     */
    public function takePendingIntent():Null<EditIntent> {
        final intent = pendingIntent;
        pendingIntent = null;
        return intent;
    }

    /** Request the intent to record the next change with. */
    public function setPendingIntent(intent:EditIntent):Void {
        pendingIntent = intent;
    }

    public function recordTransaction(change:Change, intent:EditIntent):Bool {
        if (ignoring) {
            return false;
        }
        if (change.tokenDelta == null && change.oldRange.equals(change.newRange) && change.oldText == change.newText) {
            breakTransactionCoalescing();
            return false;
        }

        if (pending != null) {
            pending.changes.push(change);
        }
        else {
            pushBatch([change], intent);
        }
        return true;
    }

    /** Open a transaction whose changes commit as one atomic undo entry. */
    public function beginTransaction():Void {
        beginTransactionWith(Atomic);
    }

    /**
     * Open a transaction that commits with `intent`, so a following batch of
     * the same intent and shape can coalesce into it. Multi-cursor typing
     * uses this to group a burst of keystrokes the way single-cursor typing
     * does.
     *
     * Only the outermost bracket decides the intent. A nested
     * `beginTransaction` merely keeps the batch open.
     */
    public function beginTransactionWith(intent:EditIntent):Void {
        transactionDepth += 1;
        if (transactionDepth == 1) {
            pending = new PendingTransaction(intent);
        }
    }

    public function commitTransaction():Void {
        if (transactionDepth == 0) {
            return;
        }

        transactionDepth -= 1;
        if (transactionDepth > 0) {
            return;
        }

        final pending = this.pending;
        this.pending = null;
        if (pending == null) {
            return;
        }
        // A composition that ends where it started (typed then canceled)
        // leaves the document untouched and must not become an undo entry.
        if (pending.changes.length == 0 || isNoopBatch(pending.changes)) {
            return;
        }
        pushBatch(pending.changes, pending.intent);
        if (pending.selectionsBefore != null) {
            recordSelectionsBefore(pending.selectionsBefore);
        }
        if (pending.selectionsAfter != null) {
            recordSelectionsAfter(pending.selectionsAfter);
        }
        // These snapshots were recorded with the edits. Commit them even when
        // replay has just enabled ignoring to flush an open IME transaction.
        if (undoTransactions.length > 0) {
            final transaction = undoTransactions[undoTransactions.length - 1];
            if (pending.autoClosedPairsBefore != null && transaction.autoClosedPairsBefore == null) {
                transaction.autoClosedPairsBefore = pending.autoClosedPairsBefore;
            }
            if (pending.autoClosedPairsAfter != null) {
                transaction.autoClosedPairsAfter = pending.autoClosedPairsAfter;
            }
        }
    }

    /**
     * Push one logical edit, which is one or more changes in application
     * order, onto the undo stack.
     */
    function pushBatch(changes:Array<Change>, intent:EditIntent):Void {
        if (changes.length == 0) {
            return;
        }

        redoTransactions.resize(0);
        final previous = undoTransactions.length > 0 ? undoTransactions[undoTransactions.length - 1] : null;
        final canCoalesce = !coalescingBoundary
            && intent != Atomic
            && previous != null
            && previous.intent == intent
            && previous.lastBatchLen == changes.length
            && previous.recordedChanges + changes.length <= MAX_CHANGES_PER_TRANSACTION
            && isAdjacentBatch(intent, previous.trailingBatch(), changes);

        if (canCoalesce) {
            previous.lastBatchLen = changes.length;
            previous.recordedChanges += changes.length;
            // Adjacent single-cursor keystrokes form one contiguous insertion.
            // Keep it as one change so undo and redo replay it as a single
            // edit rather than once per keystroke.
            if (intent == Typing && changes.length == 1 && previous.changes.length > 0) {
                final change = changes[0];
                final last = previous.changes[previous.changes.length - 1];
                // Rust `String::truncate` (byte length).
                last.newText = Utf8.substring(last.newText, 0, change.oldRange.start - last.newRange.start) + change.newText;
                last.newRange.end = change.newRange.end;
                return;
            }
            for (change in changes) previous.changes.push(change);
            return;
        }

        if (undoTransactions.length >= MAX_UNDO_TRANSACTIONS) {
            undoTransactions.shift();
        }
        undoTransactions.push(new UndoTransaction(intent, changes.length, changes.length, changes));
        coalescingBoundary = intent == Atomic;
    }

    /**
     * Record the cursors around the transaction being built, or around the
     * most recent one when no bracket is open.
     *
     * A transaction keeps the cursors it was entered with, so a coalescing
     * burst of keystrokes still undoes to where the burst began.
     */
    public function recordSelections(before:Array<CursorSelection>, after:Array<CursorSelection>):Void {
        if (ignoring) {
            return;
        }
        recordSelectionsBefore(before);
        recordSelectionsAfter(after);
    }

    public function recordAutoClosedPairs(before:AutoClosedPairs, after:AutoClosedPairs):Void {
        if (ignoring) {
            return;
        }
        if (pending != null) {
            if (pending.autoClosedPairsBefore == null) pending.autoClosedPairsBefore = before;
        }
        else if (undoTransactions.length > 0) {
            final transaction = undoTransactions[undoTransactions.length - 1];
            if (transaction.autoClosedPairsBefore == null) transaction.autoClosedPairsBefore = before;
        }
        recordAutoClosedPairsAfter(after);
    }

    public function recordAutoClosedPairsAfter(after:AutoClosedPairs):Void {
        if (ignoring) {
            return;
        }
        if (pending != null) {
            pending.autoClosedPairsAfter = after;
        }
        else if (undoTransactions.length > 0) {
            undoTransactions[undoTransactions.length - 1].autoClosedPairsAfter = after;
        }
    }

    function recordSelectionsBefore(before:Array<CursorSelection>):Void {
        if (pending != null) {
            if (pending.selectionsBefore == null) pending.selectionsBefore = before;
        }
        else if (undoTransactions.length > 0) {
            final transaction = undoTransactions[undoTransactions.length - 1];
            if (transaction.selectionsBefore == null) transaction.selectionsBefore = before;
        }
    }

    function recordSelectionsAfter(after:Array<CursorSelection>):Void {
        if (pending != null) {
            pending.selectionsAfter = after;
        }
        else if (undoTransactions.length > 0) {
            undoTransactions[undoTransactions.length - 1].selectionsAfter = after;
        }
    }

    /** True while a `beginTransaction` bracket is collecting changes. */
    public inline function hasOpenTransaction():Bool {
        return transactionDepth > 0;
    }

    public function breakTransactionCoalescing():Void {
        // While a batch is open the boundary applies to that batch, so never
        // close a bracket the caller still owns.
        if (transactionDepth == 0) {
            commitAllTransactions();
        }
        coalescingBoundary = true;
    }

    /** Close every open bracket, committing whatever they collected. */
    function commitAllTransactions():Void {
        if (transactionDepth == 0) {
            return;
        }
        transactionDepth = 1;
        commitTransaction();
    }

    public inline function isIgnoring():Bool {
        return ignoring;
    }

    public function setIgnoring(ignoring:Bool):Void {
        this.ignoring = ignoring;
        if (ignoring) {
            commitAllTransactions();
        }
    }

    public function clear():Void {
        undoTransactions.resize(0);
        redoTransactions.resize(0);
        transactionDepth = 0;
        pending = null;
        pendingIntent = null;
        coalescingBoundary = false;
    }

    public function undo():Null<Replay> {
        commitAllTransactions();
        final transaction = undoTransactions.pop();
        if (transaction == null) {
            return null;
        }
        final changes = [for (change in transaction.changes) change.clone()];
        changes.reverse();
        final replay = new Replay(changes, copySelections(transaction.selectionsBefore), clonePairs(transaction.autoClosedPairsBefore));
        redoTransactions.push(transaction);
        coalescingBoundary = true;
        return replay;
    }

    public function redo():Null<Replay> {
        commitAllTransactions();
        final transaction = redoTransactions.pop();
        if (transaction == null) {
            return null;
        }
        final replay = new Replay([for (change in transaction.changes) change.clone()], copySelections(transaction.selectionsAfter),
            clonePairs(transaction.autoClosedPairsAfter));
        undoTransactions.push(transaction);
        coalescingBoundary = true;
        return replay;
    }

    @:allow(tests)
    function hasUndos():Bool {
        return undoTransactions.length > 0;
    }

    @:allow(tests)
    function undoCount():Int {
        return undoTransactions.length;
    }

    static inline function copySelections(selections:Null<Array<CursorSelection>>):Null<Array<CursorSelection>> {
        return selections != null ? CursorSelection.copyAll(selections) : null;
    }

    static inline function clonePairs(pairs:Null<AutoClosedPairs>):Null<AutoClosedPairs> {
        return pairs != null ? pairs.clone() : null;
    }

    /**
     * True when a chain of changes that each rewrite the region the previous
     * one produced leaves the document exactly as it was found.
     *
     * Changes that do not form such a chain (multi-cursor batches, for one)
     * always report `false`, so this only ever collapses the single-region
     * case.
     */
    static function isNoopBatch(changes:Array<Change>):Bool {
        for (c in changes) {
            if (c.tokenDelta != null) {
                return false;
            }
        }
        if (changes.length == 0) {
            return true;
        }
        final first = changes[0];

        var last = first;
        for (i in 1...changes.length) {
            final change = changes[i];
            if (last.newRange.start != change.oldRange.start || last.newRange.end != change.oldRange.end) {
                return false;
            }
            last = change;
        }

        return first.oldRange.start == last.newRange.start && first.oldRange.end == last.newRange.end && first.oldText == last.newText;
    }

    /**
     * True when every change in `current` continues the change at the same
     * position in `previous`, so the two batches are one editing gesture.
     *
     * A batch applies from the highest offset down, so each of its changes is
     * still to be shifted by the ones that follow it before the next batch,
     * made against the settled document, can line up with it.
     */
    static function isAdjacentBatch(intent:EditIntent, previous:Array<Change>, current:Array<Change>):Bool {
        if (previous.length != current.length) {
            return false;
        }

        final shifts = [for (_ in 0...previous.length) 0];
        var shift = 0;
        var index = previous.length - 1;
        while (index >= 0) {
            final change = previous[index];
            shifts[index] = shift;
            shift += Utf8.byteLength(change.newText) - Utf8.byteLength(change.oldText);
            index--;
        }

        for (i in 0...previous.length) {
            if (!isAdjacent(intent, previous[i].shifted(shifts[i]), current[i])) {
                return false;
            }
        }
        return true;
    }

    static function isAdjacent(intent:EditIntent, previous:Change, current:Change):Bool {
        if (previous.tokenDelta != null || current.tokenDelta != null) {
            return false;
        }
        return switch intent {
            // Deviation DEV-015: a typing run may start by replacing text (a
            // character typed over the selection), so the previous change no
            // longer needs an empty old range.
            case Typing:
                !hasLineBreak(previous.newText)
                    && !hasLineBreak(current.newText)
                    && previous.newRange.start <= current.oldRange.start
                    && previous.newRange.end == current.oldRange.end;
            case Backspace:
                previous.newText.length == 0 && current.newText.length == 0 && current.oldRange.end == previous.oldRange.start;
            case DeleteForward:
                previous.newText.length == 0 && current.newText.length == 0 && current.oldRange.start == previous.oldRange.start;
            case Atomic:
                false;
        }
    }

    static inline function hasLineBreak(text:String):Bool {
        return text.indexOf('\n') != -1 || text.indexOf('\r') != -1;
    }

}
