// Ported from gpui-kit 0.8.1: crates/base/src/history.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import haxe.ds.ReadOnlyArray;

/**
 * A browser-style linear trail with a current entry.
 *
 * Entries before the current one can be revisited with `back`, and entries
 * left behind by going back can be restored with `forward`. Pushing after
 * going back starts a new branch and drops the forward entries.
 *
 * Methods returning Rust's `Option<T>` return `null` for `None`.
 */
class History<T> {

    /** Root to current. */
    final trail:Array<T> = [];

    /** Furthest first: the nearest forward entry is last. */
    final forwardStack:Array<T> = [];

    var limit:Int = 1000;

    public function new() {}

    /**
     * Sets the maximum number of root-to-current entries to keep, defaults to 1000.
     *
     * Lowering the limit immediately removes the oldest entries.
     */
    public function maxEntries(maxEntries:Int):History<T> {
        limit = maxEntries;
        enforceMaxEntries();
        return this;
    }

    /**
     * Pushes an entry and drops the forward branch.
     */
    public function push(entry:T):Void {
        forwardStack.resize(0);
        if (limit == 0) {
            return;
        }
        trail.push(entry);
        enforceMaxEntries();
    }

    /**
     * Returns the current entry.
     */
    public function current():Null<T> {
        return trail.length > 0 ? trail[trail.length - 1] : null;
    }

    /**
     * Replaces the current entry, or pushes when the trail is empty.
     */
    public function replaceCurrent(entry:T):Void {
        if (trail.length > 0) {
            trail[trail.length - 1] = entry;
        }
        else {
            push(entry);
        }
    }

    /**
     * Removes and returns the current entry without changing the forward branch.
     */
    public function removeCurrent():Null<T> {
        return trail.pop();
    }

    /**
     * Returns whether moving back would keep a root entry current.
     */
    public inline function canBack():Bool {
        return trail.length > 1;
    }

    /**
     * Returns whether a forward entry is available.
     */
    public inline function canForward():Bool {
        return forwardStack.length > 0;
    }

    /**
     * Moves back one entry and returns the new current entry.
     */
    public function back():Null<T> {
        if (trail.length <= 1) {
            return null;
        }
        forwardStack.push(trail.pop());
        return current();
    }

    /**
     * Moves forward one entry and returns the restored entry.
     */
    public function forward():Null<T> {
        if (limit == 0 || forwardStack.length == 0) {
            return null;
        }
        trail.push(forwardStack.pop());
        enforceMaxEntries();
        return current();
    }

    /**
     * The entries from the root to the current entry (a read-only view, not a copy).
     */
    public inline function entries():ReadOnlyArray<T> {
        return trail;
    }

    /**
     * The forward entries, from the nearest to the furthest (a new array).
     */
    public function forwardEntries():Array<T> {
        final result = forwardStack.copy();
        result.reverse();
        return result;
    }

    /**
     * The number of forward entries.
     */
    public inline function forwardLength():Int {
        return forwardStack.length;
    }

    /**
     * Keeps only entries accepted by `keep` on both sides of the current position.
     */
    public function retain(keep:(T) -> Bool):Void {
        retainIn(trail, keep);
        retainIn(forwardStack, keep);
    }

    static function retainIn<T>(array:Array<T>, keep:(T) -> Bool):Void {
        var write = 0;
        for (read in 0...array.length) {
            final entry = array[read];
            if (keep(entry)) {
                array[write++] = entry;
            }
        }
        array.resize(write);
    }

    /**
     * Clears current, back, and forward entries.
     */
    public function clear():Void {
        trail.resize(0);
        forwardStack.resize(0);
    }

    function enforceMaxEntries():Void {
        final excess = trail.length - limit;
        if (excess > 0) {
            trail.splice(0, excess);
        }
    }

}
