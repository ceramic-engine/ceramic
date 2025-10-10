package ceramic;

import haxe.ds.Vector;

using ceramic.Extensions;

#if (!documentation && (cpp || cs))

/**
 * A high-performance map using integer keys and float values.
 *
 * IntFloatMap provides fast access and storage for float values indexed by integers.
 * It uses a custom implementation on C++ and C# targets for better performance,
 * falling back to a standard Map on other platforms.
 *
 * Features:
 * - O(1) average case for get/set operations
 * - Optional iteration support (must be enabled at construction)
 * - Efficient memory usage with value pooling
 * - Zero default value for missing keys
 *
 * Example usage:
 * ```haxe
 * var scores = new IntFloatMap();
 * scores.set(playerId, 100.5);
 * var score = scores.get(playerId); // 100.5
 * var missing = scores.get(999); // 0.0 (default)
 * ```
 *
 * @see IntIntMap
 * @see IntBoolMap
 */
class IntFloatMap {

    inline static var NO_VALUE = 0;

    // Use a very specific unlikely float value as a marker
    inline static var FREE_VALUE = -3.4028234e38; // Near negative Float max

    inline static var RESERVED_GAP = 1;

    var _keys:IntIntMap;

    var nextFreeIndex:Int = 0;

    var initialSize:Int;

    var initialFillFactor:Float;

    /**
     * When this map is marked as iterable, this array will contain every key.
     * Only populated if iterable was set to true in constructor.
     */
    public var iterableKeys(default,null):Array<Int> = null;

    /**
     * Direct access to the values.
     * Can be used to iterate on values directly,
     * but may contain FREE_VALUE markers for removed entries.
     */
    public var values(default,null):Array<Float>;

    /**
     * Creates a new IntFloatMap.
     * @param size Initial capacity (will grow as needed)
     * @param fillFactor Load factor before resizing (0.5 = resize at 50% full)
     * @param iterable If true, enables iteration over keys/values
     */
    public function new(size:Int = 16, fillFactor:Float = 0.5, iterable:Bool = false) {

        initialSize = size;
        initialFillFactor = fillFactor;

        _keys = new IntIntMap(size, fillFactor, false);
        values = [];
        // Use the provided initial size, not hardcoded 16
        for (i in 0...initialSize) {
            values.push(FREE_VALUE);
        }

        if (iterable) {
            iterableKeys = [];
        }

    }

    public function get(key:Int):Float {

        return getInline(key);

    }

    inline public function getInline(key:Int):Float {

        var index = _keys.getInline(key);
        // When we store at position 0, _keys stores (0 + RESERVED_GAP) = 1
        // We need 1 >= 1 to be true to retrieve values[0]
        return if (index >= RESERVED_GAP) {
            var indexOffset = index - RESERVED_GAP;
            values.unsafeGet(indexOffset);
        }
        else {
            0.0;
        }

    }

    public function clear():Void {

        _keys.clear();
        values.setArrayLength(initialSize);
        for (i in 0...initialSize) {
            values[i] = FREE_VALUE;
        }
        nextFreeIndex = 0;

        if (iterableKeys != null) {
            iterableKeys.setArrayLength(0);
        }

    }

    public function exists(key:Int) {

        return existsInline(key);

    }

    inline public function existsInline(key:Int) {

        return _keys.existsInline(key);

    }

    public function set(key:Int, value:Float):Void {

        var index = _keys.get(key);
        if (index >= RESERVED_GAP) {
            // Replace value in array with same index and key
            values.unsafeSet(index - RESERVED_GAP, value);
        }
        else {
            // New key, use next free index
            var valuesLen = values.length;
            if (nextFreeIndex >= valuesLen) {
                resizeValues(valuesLen * 2);
                // Update length after resize
                valuesLen = values.length;
            }
            values.unsafeSet(nextFreeIndex, value);
            _keys.set(key, nextFreeIndex + RESERVED_GAP);
            // Update iterable keys
            if (iterableKeys != null) {
                iterableKeys.push(key);
            }

            // Find next free index - advance past the slot we just used
            do {
                nextFreeIndex++;
            }
            while (nextFreeIndex < valuesLen && values.unsafeGet(nextFreeIndex) != FREE_VALUE);
        }

    }

    public function remove(key:Int) {

        var index = _keys.get(key);
        // Check if key exists (index will be 0 if not found, >= RESERVED_GAP if found)
        if (index != NO_VALUE) {
            index -= RESERVED_GAP;

            // Key exists, set value to FREE (make slot available)
            values.unsafeSet(index, FREE_VALUE);

            // Update next free index if needed
            if (nextFreeIndex > index) {
                nextFreeIndex = index;
            }

            // Remove key
            _keys.remove(key);

            // Update iterable keys (with safety check for indexOf returning -1)
            if (iterableKeys != null) {
                var keyIndex = iterableKeys.indexOf(key);
                if (keyIndex >= 0) {
                    iterableKeys.splice(keyIndex, 1);
                }
            }
        }

    }

    public function copy():IntFloatMap {

        var map = new IntFloatMap(initialSize, initialFillFactor, iterableKeys != null);

        map._keys = _keys.copy();
        map.nextFreeIndex = nextFreeIndex;
        map.iterableKeys = iterableKeys != null ? iterableKeys.copy() : null;
        map.values = values.copy();

        return map;

    }

/// Internal

    function resizeValues(targetSize:Int) {

        var prevLength = values.length;
        for (i in prevLength...targetSize) {
            values.push(FREE_VALUE);
        }

    }

    inline public function iterator():IntFloatMapIterator {
        return new IntFloatMapIterator(this);
    }

    inline public function keys():IntFloatMapKeyIterator {
        return new IntFloatMapKeyIterator(this);
    }

    inline public function keyValueIterator():IntFloatMapKeyValueIterator {
        return new IntFloatMapKeyValueIterator(this);
    }

}

#else

/**
 * Fallback implementation of IntFloatMap for non-C++/C# targets.
 * Uses standard Map internally with additional tracking for iteration.
 */
class IntFloatMap {

    /**
     * Backing map for storing key-value pairs.
     */
    var intMap:Map<Int,Float>;

    /**
     * When this map is marked as iterable, this array will contain every key.
     * Only populated if iterable was set to true in constructor.
     */
    public var iterableKeys(default,null):Array<Int> = null;

    /** Tracks which keys are in iterableKeys to avoid duplicates */
    var iterableKeysUsed:IntBoolMap = null;

    /**
     * The number of entries in the map.
     */
    public var size(default,null):Int = 0;

    public function new(size:Int = 16, fillFactor:Float = 0.5, iterable:Bool = false) {
        intMap = new Map<Int,Float>();

        if (iterable) {
            iterableKeys = [];
            iterableKeysUsed = new IntBoolMap();
        }
    }

    public function clear() {
        intMap.clear();
        size = 0;
        if (iterableKeys != null) {
            iterableKeys = [];
            iterableKeysUsed = new IntBoolMap(); // TODO use clear()
        }
    }

    inline public function exists(key:Int):Bool {
        return existsInline(key);
    }

    public function set(key:Int, value:Float):Float {
        if (iterableKeys != null && !iterableKeysUsed.get(key)) {
            iterableKeysUsed.set(key, true);
            iterableKeys.push(key);
        }
        var k = Std.int(key);
        if (!intMap.exists(k)) {
            size++;
        }
        intMap.set(k, value);
        return value;
    }

    inline public function get(key:Int):Float {
        return getInline(key);
    }

    public function remove(key:Int):Float {
        var k = Std.int(key);
        var prev:Float = 0;
        if (iterableKeys != null && iterableKeysUsed.get(key)) {
            iterableKeysUsed.set(key, false);
            iterableKeys.splice(iterableKeys.indexOf(key), 1);
        }
        if (intMap.exists(k)) {
            prev = intMap.get(k);
            size--;
        }
        intMap.remove(k);
        return prev;
    }

    inline public function getInline(key:Int):Float {
        var value = intMap.get(Std.int(key));
        return value != null ? value : 0;
    }

    inline public function existsInline(key:Int):Bool {
        return intMap.exists(Std.int(key));
    }

    inline public function copy():IntFloatMap {

        var map = new IntFloatMap();

        map.intMap = intMap.copy();
        map.size = size;
        map.iterableKeys = iterableKeys != null ? iterableKeys.copy() : null;
        map.iterableKeysUsed = iterableKeysUsed != null ? iterableKeysUsed.copy() : null;

        return map;

    }

    inline public function iterator():IntFloatMapIterator {
        return new IntFloatMapIterator(this);
    }

    inline public function keys():IntFloatMapKeyIterator {
        return new IntFloatMapKeyIterator(this);
    }

    inline public function keyValueIterator():IntFloatMapKeyValueIterator {
        return new IntFloatMapKeyValueIterator(this);
    }

}

#end

/**
 * Iterator implementation for IntFloatMap values.
 * Allows iterating over float values in the map when it was created with iterable=true.
 */
@:allow(ceramic.IntFloatMap)
class IntFloatMapIterator {

    var intFloatMap:IntFloatMap;
    var i:Int;
    var len:Int;

    inline private function new(intFloatMap:IntFloatMap) {

        this.intFloatMap = intFloatMap;
        i = 0;
        var iterableKeys = this.intFloatMap.iterableKeys;
        len = iterableKeys != null ? iterableKeys.length : -1;

    }

    inline public function hasNext():Bool {
        return i < len;
    }

    inline public function next():Float {

        var n = i++;
        var k = intFloatMap.iterableKeys.unsafeGet(n);
        return intFloatMap.get(k);

    }

}

/**
 * Iterator implementation for IntFloatMap keys.
 * Allows iterating over integer keys in the map when it was created with iterable=true.
 */
@:allow(ceramic.IntFloatMap)
class IntFloatMapKeyIterator {

    var iterableKeys:Array<Int>;
    var i:Int;
    var len:Int;

    inline private function new(intFloatMap:IntFloatMap) {

        i = 0;
        iterableKeys = intFloatMap.iterableKeys;
        len = iterableKeys != null ? iterableKeys.length : -1;

    }

    inline public function hasNext():Bool {
        return i < len;
    }

    inline public function next():Int {

        var n = i++;
        return iterableKeys.unsafeGet(n);

    }

}

/**
 * Iterator implementation for IntFloatMap key-value pairs.
 * Returns objects with {key:Int, value:Float} when iterating.
 */
@:allow(ceramic.IntFloatMap)
class IntFloatMapKeyValueIterator {

    var intFloatMap:IntFloatMap;
    var i:Int;
    var len:Int;

    inline private function new(intFloatMap:IntFloatMap) {

        this.intFloatMap = intFloatMap;
        i = 0;
        var iterableKeys = this.intFloatMap.iterableKeys;
        len = iterableKeys != null ? iterableKeys.length : -1;

    }

    inline public function hasNext():Bool {
        return i < len;
    }

    inline public function next():{ key:Int, value:Float } {

        var n = i++;
        var k = intFloatMap.iterableKeys.unsafeGet(n);
        return { key: k, value: intFloatMap.get(k) };

    }

}