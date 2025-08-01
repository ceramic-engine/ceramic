package ceramic;

import ceramic.Collection.CollectionImpl;
import haxe.DynamicAccess;
import haxe.rtti.Meta;

using ceramic.Extensions;

/**
 * Utility functions for working with Collections.
 * 
 * CollectionUtils provides methods for:
 * - Converting arrays to collections
 * - Creating filtered views of collections
 * - Combining multiple collections into one
 * 
 * Combined and filtered collections are cached for performance,
 * automatically updating when source collections change.
 * 
 * @see Collection
 * @see CollectionEntry
 */
@:keep
@:keepSub
class CollectionUtils {

    /** Cache for combined collections to avoid recreating them */
    static var combinedCollections:Map<String,Dynamic> = new Map();

    /** Cache for filtered collections with specific cache keys */
    static var filteredCollections:Map<String,Dynamic> = new Map();

    public function new() {}

    /**
     * Converts an array to a Collection.
     * Each array element is wrapped in a ValueEntry.
     * 
     * @param array The array to convert
     * @return A new Collection containing the array elements
     */
    public static function toCollection<T>(array:Array<T>):Collection<ValueEntry<T>> {

        var collection = new Collection<ValueEntry<T>>();
        for (item in array) {
            var entry = new ValueEntry(item);
            collection.push(entry);
        }
        return collection;

    }

    /**
     * Creates a filtered view of a collection.
     * 
     * The filtered collection automatically updates when the source changes.
     * Use cacheKey to reuse the same filtered collection across calls.
     * 
     * @param collection The source collection to filter
     * @param filter Function that filters the entries array
     * @param cacheKey Optional key to cache and reuse the filtered collection
     * @return A filtered collection that updates with the source
     */
    public static function filtered<T:CollectionEntry>(collection:Collection<T>, filter:Array<T>->Array<T>, ?cacheKey:String):Collection<T> {

        if (cacheKey != null) {
            var cached:CollectionImpl<T> = filteredCollections.get(cacheKey);
            if (cached != null) {
                return cast cached;
            }
        }

        var collectionImpl:CollectionImpl<T> = cast collection;
        var combinedCollection:Collection<T> = null;
        if (collectionImpl.combinedCollections != null) {
            combinedCollection = cast collectionImpl;
        } else {
            combinedCollection = combined([collection]);
        }
        var newCollection = combined([combinedCollection], false);
        var impl:CollectionImpl<T> = cast newCollection;

        impl.filter = filter;

        if (cacheKey != null) {
            filteredCollections.set(cacheKey, impl);
        }

        return newCollection;

    }

    /**
     * Combines multiple collections into a single collection.
     * 
     * The combined collection automatically updates when any source changes.
     * Entries from all collections are merged in order.
     * 
     * Example:
     * ```haxe
     * var allEnemies = CollectionUtils.combined([
     *     groundEnemies,
     *     flyingEnemies,
     *     bossEnemies
     * ]);
     * ```
     * 
     * @param collections Array of collections to combine
     * @param cache Whether to cache the combined collection (default: true)
     * @return A collection containing all entries from all source collections
     */
    public static function combined<T:CollectionEntry>(collections:Array<Collection<T>>, cache:Bool = true):Collection<T> {
    //public static function combined<T:CollectionEntry>(collections:Array<Collection<T>>, cache:Bool = true):Collection<T> {

        // Create key to check if the combined collection already exists
        var keyBuf = new StringBuf();
        var i = 0;
        for (col in collections) {
            var colImpl:CollectionImpl<T> = cast col;
            if (i > 0) keyBuf.add('_');
            keyBuf.add(colImpl.internalId);
            i++;
        }
        var key = keyBuf.toString();

        // Try to get existing collection from key
        var collection:CollectionImpl<T> = combinedCollections.get(key);
        if (collection == null) {
        
            // No combined collection exist, create one and cache it
            collection = new CollectionImpl<T>();
            collection.combinedCollections = cast collections.concat([]);
            collection.combinedCollectionLastChanges = [];
            for (col in collections) {
                var colImpl:CollectionImpl<T> = cast col;
                collection.combinedCollectionLastChanges.push(colImpl.lastChange);
            }
            collection.entriesDirty = true;

            // Cache combined collection
            if (cache) combinedCollections.set(key, collection);
        }

        return cast collection;

    }

}
