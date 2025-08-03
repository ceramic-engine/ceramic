package elements;

import ceramic.ReadOnlyArray;

/**
 * Abstract wrapper for tracking list view state changes and item operations.
 * 
 * ListStatus provides a type-safe interface for monitoring changes in a ListView
 * through a WindowItem. It tracks various state changes like selection changes,
 * item list modifications, and item operations (trash, lock, unlock, duplicate).
 * 
 * This abstract type implements implicit conversion to Bool, returning true when
 * any changes have occurred (either selection or items changed).
 * 
 * Features:
 * - Tracks selection changes
 * - Monitors item list modifications
 * - Provides access to lists of items by operation type
 * - Efficient change detection
 * - Read-only access to change arrays
 * 
 * Example usage:
 * ```haxe
 * var status:ListStatus = windowItem;
 * if (status.selectedChanged) {
 *     // Handle selection change
 * }
 * if (status.itemsChanged) {
 *     // Handle item list changes
 * }
 * var trashedItems = status.trashedItems;
 * ```
 * 
 * @see WindowItem
 * @see ListView
 */
abstract ListStatus(WindowItem) from WindowItem {

    /** Empty array used as default return value when no items are available */
    static final EMPTY_ARRAY:Array<Dynamic> = [];

    /**
     * Creates a new ListStatus instance from a WindowItem.
     * 
     * @param windowItem The WindowItem to wrap for status tracking
     */
    inline public function new(windowItem:WindowItem) {
        this = windowItem;
    }

    /**
     * Implicit conversion to Bool indicating if any changes occurred.
     * 
     * @return `true` if either selection or items changed, `false` otherwise
     */
    @:to inline function toBool():Bool {
        return selectedChanged || itemsChanged;
    }

    /**
     * Indicates whether the selected item changed this frame.
     * 
     * Compares the current selection index with the previous frame's selection
     * to detect changes in list selection.
     * 
     * @return `true` if a new item was selected this frame, `false` otherwise
     */
    public var selectedChanged(get,never):Bool;
    inline function get_selectedChanged():Bool {
        return this.int0 != this.int1;
    }

    /**
     * Indicates whether the item list was modified this frame.
     * 
     * Detects changes to the underlying list structure, such as items
     * being added, removed, or reordered.
     * 
     * @return `true` if the item list changed this frame, `false` otherwise
     */
    public var itemsChanged(get,never):Bool;
    inline function get_itemsChanged():Bool {
        return this.any0 != this.any1;
    }

    /**
     * Returns the list of items that were marked for deletion this frame.
     * 
     * Provides access to items that were trashed/deleted during the current
     * frame. Returns an empty array if no items were trashed.
     * 
     * @return Read-only array of items that were trashed this frame
     */
    public var trashedItems(get,never):ReadOnlyArray<Dynamic>;
    inline function get_trashedItems():ReadOnlyArray<Dynamic> {
        return this.any2 != null ? this.any2 : EMPTY_ARRAY;
    }

    /**
     * Returns the list of items that were locked this frame.
     * 
     * Provides access to items that had their locked state changed to true
     * during the current frame. Returns an empty array if no items were locked.
     * 
     * @return Read-only array of items that were locked this frame
     */
    public var lockedItems(get,never):ReadOnlyArray<Dynamic>;
    inline function get_lockedItems():ReadOnlyArray<Dynamic> {
        return this.any3 != null ? this.any3 : EMPTY_ARRAY;
    }

    /**
     * Returns the list of items that were unlocked this frame.
     * 
     * Provides access to items that had their locked state changed to false
     * during the current frame. Returns an empty array if no items were unlocked.
     * 
     * @return Read-only array of items that were unlocked this frame
     */
    public var unlockedItems(get,never):ReadOnlyArray<Dynamic>;
    inline function get_unlockedItems():ReadOnlyArray<Dynamic> {
        return this.any4 != null ? this.any4 : EMPTY_ARRAY;
    }

    /**
     * Returns the list of items that were marked for duplication this frame.
     * 
     * Provides access to items that were requested to be duplicated during
     * the current frame. Returns an empty array if no items were marked for duplication.
     * 
     * @return Read-only array of items that were marked for duplication this frame
     */
    public var duplicateItems(get,never):ReadOnlyArray<Dynamic>;
    inline function get_duplicateItems():ReadOnlyArray<Dynamic> {
        return this.any5 != null ? this.any5 : EMPTY_ARRAY;
    }

}