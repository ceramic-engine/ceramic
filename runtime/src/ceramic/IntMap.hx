package ceramic;

import haxe.ds.Vector;

using ceramic.Extensions;

/**
 * An object map that uses integers as key.
 * 
 * IntMap provides efficient storage and retrieval of values indexed by integers.
 * It's optimized for performance with support for null values and optional iteration.
 * 
 * Features:
 * - O(1) average case get/set operations
 * - Support for null values with proper handling
 * - Optional iteration support with iterableKeys
 * - Automatic resizing of internal storage
 * - Memory-efficient storage using vectors
 * 
 * The implementation uses IntIntMap internally to map keys to value indices,
 * with special handling for null values to distinguish between "no value" and
 * "null value" cases.
 * 
 * Example usage:
 * ```haxe
 * var map = new IntMap<String>();
 * map.set(42, "hello");
 * map.set(10, null); // Null values are supported
 * trace(map.get(42)); // "hello"
 * trace(map.exists(10)); // true (even though value is null)
 * ```
 * 
 * @see IntIntMap
 * @see IntFloatMap
 * @see IntBoolMap
 */
class IntMap<V> {

    inline static var NO_VALUE = 0;

    inline static var NULL_VALUE = 1;

    inline static var RESERVED_GAP = 2;

    static final RET_NULL:Any = null;

    var _keys:IntIntMap;

    var nextFreeIndex:Int = 0;

    var initialSize:Int;

    var initialFillFactor:Float;

    /**
     * When this map is marked as iterable, this array will contain every key.
     */
    public var iterableKeys(default,null):Array<Int> = null;

    /**
     * Values as they are stored.
     * Can be used to iterate on values directly,
     * but can contain null values.
     */
    #if (cs && unity)
    public var values(default,null):Vector<Any>;
    #else
    public var values(default,null):Vector<V>;
    #end

    /**
     * Creates a new IntMap.
     * @param size Initial capacity (default: 16)
     * @param fillFactor Fill factor for internal map (default: 0.5)
     * @param iterable Enable iteration support (default: false)
     */
    public function new(size:Int = 16, fillFactor:Float = 0.5, iterable:Bool = false) {

        initialSize = size;
        initialFillFactor = fillFactor;

        _keys = new IntIntMap(size, fillFactor);
        values = new Vector(size);

        if (iterable) {
            iterableKeys = [];
        }

    }

    /**
     * Gets the value associated with the given key.
     * @param key The integer key
     * @return The value, or null if key doesn't exist
     */
    public function get(key:Int):V {

        return getInline(key);

    }

    inline public function getInline(key:Int):V {

        var index = _keys.getInline(key);
        return index >= RESERVED_GAP ? values.get(index - RESERVED_GAP) : RET_NULL;

    }

    /**
     * Checks if a key exists in the map.
     * @param key The integer key to check
     * @return True if the key exists (even if value is null)
     */
    public function exists(key:Int) {

        return existsInline(key);

    }

    inline public function existsInline(key:Int) {

        return _keys.existsInline(key);

    }

    /**
     * Sets a value for the given key.
     * @param key The integer key
     * @param value The value to set (can be null)
     */
    public function set(key:Int, value:V):Void {

        var index = _keys.get(key);
        if (index >= RESERVED_GAP) {
            index -= RESERVED_GAP;
            if (value != null) {
                // Replace value in array with same index and key
                values.set(index, value);
            } else {
                // Key exists, set value to null and free this space
                values.set(index, null);
                // Update next free index if needed
                if (nextFreeIndex > index) {
                    nextFreeIndex = index;
                }
                // Set key to NULL_VALUE
                _keys.set(key, NULL_VALUE);
            }
        }
        else if (value == null) {
            if (index != NULL_VALUE) {
                // New key, but null value,
                // no need to touch values array
                _keys.set(key, NULL_VALUE);
                // Update iterable _keys
                if (iterableKeys != null) {
                    iterableKeys.push(key);
                }
            }
        }
        else {
            // Non-null value, use next free index
            var valuesLen = values.length;
            if (nextFreeIndex >= valuesLen) {
                resizeValues(values.length * 2);
            }
            values.set(nextFreeIndex, value);
            _keys.set(key, nextFreeIndex + RESERVED_GAP);

            // Update iterable _keys if new value
            if (index != NULL_VALUE && iterableKeys != null) {
                iterableKeys.push(key);
            };

            do {
                // Move free index to next location
                nextFreeIndex++;
            }
            while (nextFreeIndex < valuesLen && values.get(nextFreeIndex) != null);
        }

    }

    /**
     * Removes a key-value pair from the map.
     * @param key The integer key to remove
     */
    public function remove(key:Int) {

        var index = _keys.get(key);
        if (index != NO_VALUE) {
            if (index != NULL_VALUE) {
                index -= RESERVED_GAP;

                // Key is mapping to a non null value, set value to null
                values.set(index, null);

                // Update next free index if needed
                if (nextFreeIndex > index) {
                    nextFreeIndex = index;
                }
            }

            // Remove key
            _keys.remove(key);

            // Update iterable _keys
            if (iterableKeys != null) {
                iterableKeys.splice(iterableKeys.indexOf(key), 1);
            }
        }

    }

    /**
     * Creates a shallow copy of this map.
     * @return A new IntMap with the same key-value pairs
     */
    public function copy():IntMap<V> {

        var map = new IntMap<V>();

        map.initialSize = initialSize;
        map.initialFillFactor = initialFillFactor;
        map._keys = _keys.copy();
        map.nextFreeIndex = nextFreeIndex;
        map.iterableKeys = iterableKeys != null ? iterableKeys.copy() : null;
        map.values = values.copy();

        return map;

    }

    /**
     * Clears all key-value pairs from the map.
     */
    public function clear():Void {

        _keys = new IntIntMap(initialSize, initialFillFactor);
        values = new Vector(initialSize);
        nextFreeIndex = 0;

        if (iterableKeys != null) {
            iterableKeys.setArrayLength(0);
        }

    }

    /**
     * Returns an iterator over the values in this map.
     * Note: Map must be created with iterable=true
     */
    public inline function iterator():IntMapIterator<V> {
        return new IntMapIterator(this);
    }

    /**
     * Returns an iterator over the keys in this map.
     * Note: Map must be created with iterable=true
     */
    public inline function keys():IntMapKeyIterator<V> {
        return new IntMapKeyIterator(this);
    }

    /**
     * Returns an iterator over key-value pairs in this map.
     * Note: Map must be created with iterable=true
     */
    public inline function keyValueIterator():IntMapKeyValueIterator<V> {
        return new IntMapKeyValueIterator(this);
    }

/// Internal

    function resizeValues(targetSize:Int) {

        var prevValues = values;
        #if (cs && unity)
        var valuesDyn:Dynamic = new Vector<V>(targetSize);
        values = valuesDyn;
        #else
        values = new Vector<V>(targetSize);
        #end
        for (i in 0...prevValues.length) {
            values.set(i, prevValues.get(i));
        }

    }

}

/**
 * Iterator implementation for IntMap values.
 * Allows iterating over values in the map when it was created with iterable=true.
 */
@:allow(ceramic.IntMap)
class IntMapIterator<V> {

    var intMap:IntMap<V>;

    var i:Int;

    var len:Int;

    inline private function new(intMap:IntMap<V>) {

        this.intMap = intMap;
        i = 0;
        var iterableKeys = this.intMap.iterableKeys;
        len = iterableKeys != null ? iterableKeys.length : -1;

    }

    inline public function hasNext():Bool {
        return i < len;
    }

    inline public function next():V {

        var n = i++;
        var k = intMap.iterableKeys.unsafeGet(n);
        return intMap.get(k);

    }

}

/**
 * Iterator implementation for IntMap keys.
 * Allows iterating over keys in the map when it was created with iterable=true.
 */
@:allow(ceramic.IntMap)
class IntMapKeyIterator<V> {

    var iterableKeys:Array<Int>;

    var i:Int;

    var len:Int;

    inline private function new(intMap:IntMap<V>) {

        i = 0;
        iterableKeys = intMap.iterableKeys;
        len = iterableKeys != null ? iterableKeys.length : -1;

    }

    inline public function hasNext():Bool {
        return i < len;
    }

    inline public function next():Int {

        var n = i++;
        var k = iterableKeys.unsafeGet(n);
        return k;

    }

}

@:allow(ceramic.IntMap)
class IntMapKeyValueIterator<V> {

    var intMap:IntMap<V>;

    var i:Int;

    var len:Int;

    inline private function new(intMap:IntMap<V>) {

        this.intMap = intMap;
        i = 0;
        var iterableKeys = this.intMap.iterableKeys;
        len = iterableKeys != null ? iterableKeys.length : -1;

    }

    inline public function hasNext():Bool {
        return i < len;
    }

    inline public function next():{key:Int, value:V} {

        var n = i++;
        var k = intMap.iterableKeys.unsafeGet(n);
        return { key: k, value: intMap.get(k) };

    }

}
