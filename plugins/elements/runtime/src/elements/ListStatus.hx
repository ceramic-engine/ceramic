package elements;

import ceramic.ReadOnlyArray;

abstract ListStatus(WindowItem) from WindowItem {

    static final EMPTY_ARRAY:Array<Dynamic> = [];

    inline public function new(windowItem:WindowItem) {
        this = windowItem;
    }

    @:to inline function toBool():Bool {
        return selectedChanged || itemsChanged;
    }

    /**
     * `true` if a new item was selected this frame
     */
    public var selectedChanged(get,never):Bool;
    inline function get_selectedChanged():Bool {
        return this.int0 != this.int1;
    }

    /**
     * `true` if the item list changed this frame
     */
    public var itemsChanged(get,never):Bool;
    inline function get_itemsChanged():Bool {
        return this.any0 != this.any1;
    }

    /**
     * Return the list of trashed items this frame
     */
    public var trashedItems(get,never):ReadOnlyArray<Dynamic>;
    inline function get_trashedItems():ReadOnlyArray<Dynamic> {
        return this.any2 != null ? this.any2 : EMPTY_ARRAY;
    }

    /**
     * Return the list of just locked items this frame
     */
    public var lockedItems(get,never):ReadOnlyArray<Dynamic>;
    inline function get_lockedItems():ReadOnlyArray<Dynamic> {
        return this.any3 != null ? this.any3 : EMPTY_ARRAY;
    }

    /**
     * Return the list of just unlocked items this frame
     */
    public var unlockedItems(get,never):ReadOnlyArray<Dynamic>;
    inline function get_unlockedItems():ReadOnlyArray<Dynamic> {
        return this.any4 != null ? this.any4 : EMPTY_ARRAY;
    }

    /**
     * Return the list of items to duplicate this frame
     */
    public var duplicateItems(get,never):ReadOnlyArray<Dynamic>;
    inline function get_duplicateItems():ReadOnlyArray<Dynamic> {
        return this.any5 != null ? this.any5 : EMPTY_ARRAY;
    }

}