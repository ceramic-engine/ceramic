package ceramic;

import ceramic.Assert.*;
import ceramic.ReadOnlyArray;
import tracker.Events;

/**
 * A type-safe collection for managing CollectionEntry items.
 * 
 * Collection provides an efficient way to store and access items by ID,
 * with support for:
 * - Fast lookup by string ID
 * - Array-like indexing
 * - Iteration support
 * - Random element selection
 * - Collection combining and filtering
 * 
 * Collections are particularly useful for managing game entities that need
 * to be accessed both by ID and by index.
 * 
 * Example usage:
 * ```haxe
 * var enemies = new Collection<Enemy>();
 * enemies.push(new Enemy("goblin1"));
 * enemies.push(new Enemy("goblin2"));
 * 
 * // Access by ID
 * var goblin = enemies.get("goblin1");
 * 
 * // Access by index
 * var firstEnemy = enemies[0];
 * 
 * // Iterate
 * for (enemy in enemies) {
 *     enemy.update();
 * }
 * ```
 * 
 * @param T The type of entries, must implement CollectionEntry
 * @see CollectionEntry
 * @see CollectionUtils
 */
@:forward
@:keep
@:keepSub
abstract Collection<T:CollectionEntry>(CollectionImpl<T>) {

    inline public function new() {

        this = new CollectionImpl();

    }

    @:arrayAccess public inline function arrayAccess(index:Int) {

        return this.getByIndex(index);

    }

    /**
     * Returns a random element from the collection.
     * @return A random element, or null if the collection is empty
     */
    public function randomElement():T {

        this.checkCombined();
        if (this.entriesDirty) this.computeEntries();

        return Extensions.randomElement(this.entries.original);

    }

    /**
     * Returns a random element from the collection, excluding a specific element.
     * @param except The element to exclude from selection
     * @param unsafe If true, avoids array allocation but may loop forever if only 'except' exists
     * @return A random element different from 'except', or null if none found
     */
    public function randomElementExcept(except:T, unsafe:Bool = false):T {

        this.checkCombined();
        if (this.entriesDirty) this.computeEntries();

        return Extensions.randomElementExcept(this.entries.original, except, unsafe);

    }

    /**
     * Returns a random element that passes the validator function.
     * @param validator A function that returns true for valid elements
     * @return A random valid element, or null if none found
     */
    public function randomElementMatchingValidator(validator:T->Bool):T {

        this.checkCombined();
        if (this.entriesDirty) this.computeEntries();

        return Extensions.randomElementMatchingValidator(this.entries.original, validator);

    }

}

/**
 * Internal implementation of the Collection abstract.
 * Handles the actual storage, indexing, and management of collection entries.
 */
@:allow(ceramic.Collection)
@:allow(ceramic.CollectionUtils)
class CollectionImpl<T:CollectionEntry> implements Events {

    static var _lastCheckedCombined:Dynamic = null;

    static var _nextInternalId:Int = 0;

    var internalId:Int = _nextInternalId++;

    var lastChange:Int = 0;

    /**
     * The array of entries in the collection.
     * Read-only access from outside the class.
     */
    public var entries(default, null):ReadOnlyArray<T> = [];

    /** Whether the ID index needs to be rebuilt */
    var indexDirty:Bool = true;

    /** Whether combined entries need to be recomputed */
    var entriesDirty:Bool = false;

    /** Map for fast lookup by ID */
    var byId:Map<String,T> = null;

    /** Optional filter function for combined collections */
    var filter:Array<T>->Array<T> = null;

    /** Collections being combined into this one */
    var combinedCollections:Array<CollectionImpl<T>> = null;
    /** Track changes in combined collections */
    var combinedCollectionLastChanges:Array<Int> = null;

    /**
     * The number of entries in the collection.
     */
    public var length(get,never):Int;
    function get_length():Int {
        this.checkCombined();
        if (this.entriesDirty) this.computeEntries();
        return entries.length;
    }

    public function new() {}

    /**
     * Adds multiple entries to the collection at once.
     * @param entries Array of entries to add
     */
    public function pushAll(entries:Array<T>) {

        assert(combinedCollections == null, 'Cannot add entries to combined collections');

        for (entry in entries) {
            this.entries.original.push(entry);
        }

        indexDirty = true;
        lastChange = lastChange > 999999999 ? -999999999 : lastChange + 1;
        _lastCheckedCombined = null;

    }

    /**
     * Removes all entries from the collection.
     */
    public function clear() {

        assert(combinedCollections == null, 'Cannot clear combined collections');

        var len = this.entries.length;
        if (len > 0) {
            this.entries.original.splice(0, len);
        }

        indexDirty = true;
        lastChange = lastChange > 999999999 ? -999999999 : lastChange + 1;
        _lastCheckedCombined = null;

    }

    /**
     * Adds a single entry to the collection.
     * @param entry The entry to add
     */
    public function push(entry:T) {

        assert(combinedCollections == null, 'Cannot add entries to combined collections');

        this.entries.original.push(entry);
        indexDirty = true;
        lastChange = lastChange > 999999999 ? -999999999 : lastChange + 1;
        _lastCheckedCombined = null;

    }

    /**
     * Removes an entry from the collection.
     * @param entry The entry to remove
     */
    public function remove(entry:T) {

        assert(combinedCollections == null, 'Cannot remove entries from combined collections');

        this.entries.original.remove(entry);
        indexDirty = true;
        lastChange = lastChange > 999999999 ? -999999999 : lastChange + 1;
        _lastCheckedCombined = null;

    }

    /**
     * Forces immediate synchronization of the collection's internal state.
     * Normally done automatically when accessing entries.
     */
    public function synchronize():Void {

        if (entriesDirty) computeEntries();
        if (indexDirty) computeIndex();

    }

    /**
     * Gets an entry by its ID.
     * @param id The ID of the entry to retrieve
     * @return The entry with the given ID, or null if not found
     * @throws String If id is null (unless ceramic_no_strict_collection_get is defined)
     */
    public function get(id:String):T {

        #if !ceramic_no_strict_collection_get
        if (id == null) {
            throw 'Cannot get a collection entry with a null id!';
        }
        #else
        if (id == null) {
            log.error('Cannot get a collection entry with a null id! Returning null instead...');
            return null;
        }
        #end

        checkCombined();

        if (entriesDirty) computeEntries();
        if (indexDirty) computeIndex();

        return byId.get(id);

    }

    /**
     * Gets an entry by its index in the collection.
     * @param index The index of the entry
     * @return The entry at the given index
     */
    public function getByIndex(index:Int):T {

        checkCombined();

        if (entriesDirty) computeEntries();

        return entries[index];

    }

    /**
     * Gets the index of an entry by its ID.
     * @param id The ID to search for
     * @return The index of the entry, or -1 if not found
     */
    public function indexOfId(id:String):Int {

        var entry = get(id);
        if (entry == null)
            return -1;

        return indexOf(entry);

    }

    /**
     * Gets the index of an entry in the collection.
     * @param entry The entry to find
     * @return The index of the entry, or -1 if not found
     */
    public function indexOf(entry:T):Int {

        checkCombined();

        if (entriesDirty) computeEntries();

        return entries.indexOf(entry);

    }

    /**
     * Returns an iterator for the collection.
     * Enables for-in loop iteration.
     * @return An iterator over the collection entries
     */
    inline public function iterator():Iterator<T> {

        checkCombined();

        if (entriesDirty) computeEntries();

        return entries.iterator();

    }

/// Internal

    inline function checkCombined() {

        // Always check that the combined collection we depend on hasn't changed
        if (combinedCollections != null) {
            if (_lastCheckedCombined != this) {
                for (i in 0...combinedCollections.length) {
                    var collection = combinedCollections[i];
                    var collectionLastChange = combinedCollectionLastChanges[i];
                    if (collectionLastChange != collection.lastChange) {
                        entriesDirty = true;
                        break;
                    }
                }
                _lastCheckedCombined = this;
            }
        }

    }

    function computeIndex() {

        if (entriesDirty) computeEntries();

        byId = new Map();

        for (entry in entries) {
            if (!byId.exists(entry.id)) {
                byId.set(entry.id, entry);
            }
        }

        indexDirty = false;

    }

    function computeEntries() {

        assert(combinedCollections != null, 'Entries only need to be computed on combined collections');

        entries = [];
        for (i in 0...combinedCollections.length) {
            var collection = combinedCollections[i];
            for (entry in collection) {
                entries.original.push(entry);
            }
            combinedCollectionLastChanges[i] = collection.lastChange;
        }

        if (filter != null) {
            entries = filter(entries.original);
        }

        entriesDirty = false;
        indexDirty = true;
        if (_lastCheckedCombined != this) _lastCheckedCombined = null;

    }

}
