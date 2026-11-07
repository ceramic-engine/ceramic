// Ported from gpui-kit 0.8.1: crates/base/src/input/base/cursor.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * The cursors of an input. There is always at least one; index 0 is the
 * active one.
 */
class Selections {

    var selections:Array<CursorSelection>;

    var nextId:Int;

    public function new() {
        selections = [new CursorSelection(new CursorId(0), 0, 0)];
        nextId = 1;
    }

    /** `Selections::default()`. */
    public static inline function defaultValue():Selections {
        return new Selections();
    }

    /** Returns the active selection (mutable, Rust `active` and `active_mut`). */
    public inline function active():CursorSelection {
        return selections[0];
    }

    /** Returns the active selection, to mutate it. */
    public inline function activeMut():CursorSelection {
        return selections[0];
    }

    /** Replaces the active selection (Rust `*active_mut() = selection`). */
    public inline function setActive(selection:CursorSelection):Void {
        selections[0] = selection;
    }

    /** The selections, active first. Do not mutate the array. */
    public inline function iter():Array<CursorSelection> {
        return selections;
    }

    /** Returns the number of selections (always `>= 1`). */
    public inline function len():Int {
        return selections.length;
    }

    /** Returns true when there is exactly one selection. */
    public inline function isSingle():Bool {
        return selections.length == 1;
    }

    /** Generates a new unique cursor id. */
    public function generateId():CursorId {
        final id = new CursorId(nextId);
        nextId += 1;
        return id;
    }

    /** Adds an additional selection. */
    public inline function add(selection:CursorSelection):Void {
        selections.push(selection);
    }

    /**
     * Replaces all selections. Ignores an empty array to keep the "always at
     * least one selection" invariant.
     */
    public function replaceAll(selections:Array<CursorSelection>):Void {
        if (selections.length > 0) {
            this.selections = selections;
        }
    }

    /** Removes every selection except the active one (index 0). */
    public function removeAllButActive():Void {
        if (selections.length > 1) {
            selections.splice(1, selections.length - 1);
        }
    }

    /**
     * Merges overlapping selections.
     *
     * Selections are sorted by start and folded together when they overlap.
     * The active selection is preserved, propagated onto the merged result
     * if it was absorbed, and re-fronted afterwards.
     */
    public function mergeOverlapping():Void {
        if (selections.length <= 1) {
            return;
        }

        final activeId = active().id;

        // Rust `sort_by_key` is stable.
        stableSortByStart(selections);

        final merged:Array<CursorSelection> = [];
        for (selection in selections) {
            if (merged.length > 0) {
                final last = merged[merged.length - 1];
                if (selection.start <= last.end) {
                    // Overlapping or adjacent, extend the last one.
                    final didMerge = selection.start != last.start || selection.end != last.end;
                    last.end = last.end > selection.end ? last.end : selection.end;
                    if (selection.id == activeId) {
                        last.id = activeId;
                        last.reversed = selection.reversed;
                    }
                    // Reset the column anchor on a real merge.
                    if (didMerge) {
                        last.columnAnchor = null;
                    }
                    continue;
                }
            }
            merged.push(selection.copy());
        }

        // Re-front the active selection so it stays at index 0.
        for (pos in 0...merged.length) {
            if (merged[pos].id == activeId) {
                final first = merged[0];
                merged[0] = merged[pos];
                merged[pos] = first;
                break;
            }
        }

        this.selections = merged;
    }

    static function stableSortByStart(selections:Array<CursorSelection>):Void {
        // Insertion sort: stable, and the lists are short.
        for (i in 1...selections.length) {
            final item = selections[i];
            var j = i - 1;
            while (j >= 0 && selections[j].start > item.start) {
                selections[j + 1] = selections[j];
                j--;
            }
            selections[j + 1] = item;
        }
    }

}
