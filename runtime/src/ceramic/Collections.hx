package ceramic;

import ceramic.Collection.CollectionImpl;
import haxe.DynamicAccess;
import haxe.rtti.Meta;

using ceramic.Extensions;

@:build(ceramic.macros.CollectionsMacro.build())
class Collections {

    static var combinedCollections:Map<String,Dynamic> = new Map();

    public function new() {}

    /** Returns a combined collection from the provided ones. */
    public static function combined<T:CollectionEntry>(collections:Array<Collection<T>>):Collection<T> {

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
        if (collection != null) {
            return cast collection;
        }
        
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
        combinedCollections.set(key, collection);

        return cast collection;

    } //combined

} //Collections
