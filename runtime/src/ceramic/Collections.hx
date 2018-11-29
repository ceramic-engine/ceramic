package ceramic;

import ceramic.Collection.CollectionImpl;
import haxe.DynamicAccess;
import haxe.rtti.Meta;

using ceramic.Extensions;

@:build(ceramic.macros.CollectionsMacro.build())
class Collections {

    static var combinedCollections:Map<String,Dynamic> = new Map();

    static var filteredCollections:Map<String,Dynamic> = new Map();

    public function new() {}

    /** Converts an array to an equivalent collection */
    public static function toCollection<T>(array:Array<T>):Collection<ValueEntry<T>> {

        var collection = new Collection<ValueEntry<T>>();
        for (item in array) {
            var entry = new ValueEntry(item);
            collection.push(entry);
        }
        return collection;

    } //toCollection

    /** Returns a filtered collection from the provided collection and filter. */
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
        var collection = combined([combinedCollection], false);
        var impl:CollectionImpl<T> = cast collection;

        impl.filter = filter;

        if (cacheKey != null) {
            filteredCollections.set(cacheKey, impl);
        }

        return collection;

    } //filtered

    /** Returns a combined collection from the provided ones. */
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

    } //combined

} //Collections
