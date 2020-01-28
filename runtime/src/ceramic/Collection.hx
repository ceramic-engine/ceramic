package ceramic;

import ceramic.Assert.*;

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

    /** Return a random element contained in the collection */
    public function randomElement():T {

        this.checkCombined();
        if (this.entriesDirty) this.computeEntries();

        return Extensions.randomElement(this.entries);

    }

    /** Return a random element contained in the given array that is not equal to the `except` arg.
        @param except The element we don't want
        @param unsafe If set to `true`, will prevent allocating a new array (and may be faster) but will loop forever if there is no element except the one we don't want
        @return The random element or `null` if nothing was found */
    public function randomElementExcept(except:T, unsafe:Bool = false):T {

        this.checkCombined();
        if (this.entriesDirty) this.computeEntries();

        return Extensions.randomElementExcept(this.entries, except, unsafe);

    }

    /** Return a random element contained in the given array that is validated by the provided validator.
        If no item is valid, returns null.
        @param array  The array in which we extract the element from
        @param validator A function that returns true if the item is valid, false if not
        @return The random element or `null` if nothing was found */
    public function randomElementMatchingValidator(validator:T->Bool):T {

        this.checkCombined();
        if (this.entriesDirty) this.computeEntries();

        return Extensions.randomElementMatchingValidator(this.entries, validator);

    }

}

@:allow(ceramic.Collection)
@:allow(ceramic.Collections)
class CollectionImpl<T:CollectionEntry> implements Events {

    static var _lastCheckedCombined:Dynamic = null;

    static var _nextInternalId:Int = 0;

    var internalId:Int = _nextInternalId++;

    var lastChange:Int = 0;

    var entries:Array<T> = [];

    var indexDirty:Bool = true;

    var entriesDirty:Bool = false;

    var byId:Map<String,T> = null;

    var filter:Array<T>->Array<T> = null;

    var combinedCollections:Array<CollectionImpl<T>> = null;
    var combinedCollectionLastChanges:Array<Int> = null;
    
	public var length(get,never):Int;
    function get_length():Int {
        this.checkCombined();
        if (this.entriesDirty) this.computeEntries();
        return entries.length;
    }

    public function new() {}

	public function pushAll(entries:Array<T>) {

        assert(combinedCollections == null, 'Cannot add entries to combined collections');

        for (entry in entries) {
            this.entries.push(entry);
        }

        indexDirty = true;
        lastChange = lastChange > 999999999 ? -999999999 : lastChange + 1;
        _lastCheckedCombined = null;

    }

    public function clear() {

        assert(combinedCollections == null, 'Cannot clear combined collections');

        var len = this.entries.length;
        if (len > 0) {
            this.entries.splice(0, len);
        }
        
        indexDirty = true;
        lastChange = lastChange > 999999999 ? -999999999 : lastChange + 1;
        _lastCheckedCombined = null;

    }

	public function push(entry:T) {

        assert(combinedCollections == null, 'Cannot add entries to combined collections');

        this.entries.push(entry);
        indexDirty = true;
        lastChange = lastChange > 999999999 ? -999999999 : lastChange + 1;
        _lastCheckedCombined = null;

    }

    public function get(id:String):T {

        checkCombined();

        if (entriesDirty) computeEntries();
        if (indexDirty) computeIndex();

        return byId.get(id);

    }

    public function getByIndex(index:Int):T {

        checkCombined();

        if (entriesDirty) computeEntries();

        return entries[index];

    }

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
                entries.push(entry);
            }
            combinedCollectionLastChanges[i] = collection.lastChange;
        }

        if (filter != null) {
            entries = filter(entries);
        }

        entriesDirty = false;
        indexDirty = true;
        if (_lastCheckedCombined != this) _lastCheckedCombined = null;

    }

}
