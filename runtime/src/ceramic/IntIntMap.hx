package ceramic;

import ceramic.Assert.assert;

using ceramic.Extensions;

#if (!documentation && (cpp || cs))

import haxe.ds.Vector;

/**
 * A high-performance map using integer keys and integer values.
 * 
 * IntIntMap is optimized for C++ and C# targets using a custom open-addressing
 * hash table implementation. It provides O(1) average case performance for
 * basic operations.
 * 
 * Features:
 * - Very fast get/set operations
 * - Minimal memory overhead
 * - Optional iteration support
 * - Automatic resizing based on fill factor
 * 
 * Based on mikvor's IntIntMap4a implementation from hashmapTest.
 * 
 * Example usage:
 * ```haxe
 * var map = new IntIntMap();
 * map.set(42, 100);
 * var value = map.get(42); // 100
 * var missing = map.get(99); // 0 (default)
 * ```
 * 
 * @see IntFloatMap
 * @see IntBoolMap
 */
class IntIntMap {

    static inline var INT_PHI = 0x9E3779B9;

    static inline var FREE_KEY = 0;

    static inline var NO_VALUE = 0;

    /**
     * Keys and values
     */
    var data:Vector<Int>;

    /**
     * Do we have `free` key in the map?
     */
    var hasFreeKey:Bool;
    /**
     * Value of `free` key
     */
    var freeValue:Int;

    /**
     * Fill factor, must be between 0 (excluded) and 1 (excluded)
     */
    var fillFactor:Float;
    /**
     * We will resize a map once it reaches this size
     */
    var threshold:Int;
    /**
     * Current map size
     */
    public var size(default,null):Int;

    /**
     * When this map is marked as iterable, this array will contain every key.
     */
    public var iterableKeys(default,null):Array<Int> = null;
    var iterableKeysUsed:IntBoolMap = null;

    /**
     * Mask to calculate the original position
     */
    var mask:Int;
    /**
     * Mask to calculate the original position
     */
    var mask2:Int;

    public function new(size:Int = 16, fillFactor:Float = 0.5, iterable:Bool = false) {

        assert(fillFactor > 0 || fillFactor < 1, "fillFactor must be in 0 (excluded) and 1 (excluded)");
        assert(size > 0, "size must be positive");

        var capacity = arraySize(size, fillFactor);
        mask = capacity - 1;
        mask2 = capacity * 2 - 1;
        this.fillFactor = fillFactor;

        data = new Vector(capacity * 2);
        threshold = Std.int(capacity * fillFactor);

        if (iterable) {
            iterableKeys = [];
            iterableKeysUsed = new IntBoolMap();
        }

    }

    public function clear():Void {

        hasFreeKey = false;
        freeValue = NO_VALUE;
        size = 0;

        for (i in 0...data.length) {
            data.set(i, NO_VALUE);
        }

        if (iterableKeys != null) {
            iterableKeys = [];
            iterableKeysUsed = new IntBoolMap(); // TODO use clear()
        }

    }

    public function exists(key:Int):Bool {

        return existsInline(key);

    }

    inline public function existsInline(key:Int):Bool {

        var res:Bool = false;

        if (key == FREE_KEY) {
            res = hasFreeKey ? true : false;
        }
        else {
            var ptr = (phiMix(key) & mask) << 1;

            var k = data.get(ptr);

            if (k != FREE_KEY) {
                if (k == key) {
                    // We check FREE prior to this call
                    res = true;
                }
                else {
                    while (true)
                    {
                        // That's next index
                        ptr = (ptr + 2) & mask2;
                        k = data.get(ptr);
                        if (k == FREE_KEY) {
                            // res = false;
                            break;
                        }
                        if (k == key) {
                            res = true;
                            break;
                        }
                    }
                }
            }
        }

        return res;

    }

    public function get(key:Int):Int {

        return getInline(key);

    }

    inline public function getInline(key:Int):Int {

        var res:Int = NO_VALUE;

        if (key == FREE_KEY) {
            res = hasFreeKey ? freeValue : NO_VALUE;
        }
        else {
            var ptr = (phiMix(key) & mask) << 1;
            var ptrPlus1 = ptr + 1;

            var k = data.get(ptr);

            if (k != FREE_KEY) {
                if (k == key) {
                    // We check FREE prior to this call
                    res = data.get(ptrPlus1);
                }
                else {
                    while (true)
                    {
                        // That's next index
                        ptr = (ptr + 2) & mask2;
                        k = data.get(ptr);
                        if (k == FREE_KEY) {
                            // res = NO_VALUE;
                            break;
                        }
                        if (k == key) {
                            ptrPlus1 = ptr + 1;
                            res = data.get(ptrPlus1);
                            break;
                        }
                    }
                }
            }
        }

        return res;

    }

    public function set(key:Int, value:Int):Int {

        if (key == FREE_KEY)
        {
            var ret = freeValue;
            if (!hasFreeKey) {
                if (iterableKeys != null) {
                    if (!iterableKeysUsed.get(key)) {
                        iterableKeysUsed.set(key, true);
                        iterableKeys.push(key);
                    }
                }
                size++;
            }
            hasFreeKey = true;
            freeValue = value;
            return ret;
        }

        var ptr = (phiMix(key) & mask) << 1;
        var ptrPlus1 = ptr + 1;
        var k = data.get(ptr);
        if (k == FREE_KEY) // End of chain already
        {
            data.set(ptr, key);
            data.set(ptrPlus1, value);
            if (size >= threshold) {
                rehash(data.length * 2); // Size is set inside
            } else {
                size++;
            }
            if (iterableKeys != null) {
                if (!iterableKeysUsed.get(key)) {
                    iterableKeysUsed.set(key, true);
                    iterableKeys.push(key);
                }
            }
            return NO_VALUE;
        }
        else if (k == key) // We check FREE prior to this call
        {
            var ret = data.get(ptrPlus1);
            data.set(ptrPlus1, value);
            return ret;
        }

        while (true)
        {
            ptr = (ptr + 2) & mask2; // That's next index calculation
            ptrPlus1 = ptr + 1;
            k = data.get(ptr);
            if (k == FREE_KEY)
            {
                data.set(ptr, key);
                data.set(ptrPlus1, value);
                if (size >= threshold) {
                    rehash(data.length * 2); // Size is set inside
                }
                else {
                    size++;
                }
                if (iterableKeys != null) {
                    if (!iterableKeysUsed.get(key)) {
                        iterableKeysUsed.set(key, true);
                        iterableKeys.push(key);
                    }
                }
                return NO_VALUE;
            }
            else if (k == key)
            {
                var ret = data.get(ptrPlus1);
                data.set(ptrPlus1, value);
                return ret;
            }
        }

    }

    public function remove(key:Int):Int {

        if (key == FREE_KEY)
        {
            if (!hasFreeKey) {
                return NO_VALUE;
            }
            hasFreeKey = false;
            size--;
            if (iterableKeys != null) {
                if (iterableKeysUsed.get(key)) {
                    iterableKeysUsed.set(key, false);
                    iterableKeys.splice(iterableKeys.indexOf(key), 1);
                }
            }
            return freeValue; // Value is not cleaned
        }

        var ptr = (phiMix(key) & mask) << 1;
        var ptrPlus1 = ptr + 1;
        var k = data.get(ptr);
        if (k == key) // We check FREE prior to this call
        {
            var res = data.get(ptrPlus1);
            shiftKeys(ptr);
            size--;
            if (iterableKeys != null) {
                if (iterableKeysUsed.get(key)) {
                    iterableKeysUsed.set(key, false);
                    iterableKeys.splice(iterableKeys.indexOf(key), 1);
                }
            }
            return res;
        }
        else if (k == FREE_KEY) {
            return NO_VALUE;  // End of chain already
        }
        while (true)
        {
            ptr = (ptr + 2) & mask2; // That's next index calculation
            k = data.get(ptr);
            if (k == key)
            {
                ptrPlus1 = ptr + 1;
                var res = data.get(ptrPlus1);
                shiftKeys(ptr);
                size--;
                if (iterableKeys != null) {
                    if (iterableKeysUsed.get(key)) {
                        iterableKeysUsed.set(key, false);
                        iterableKeys.splice(iterableKeys.indexOf(key), 1);
                    }
                }
                return res;
            }
            else if (k == FREE_KEY) {
                return NO_VALUE;
            }
        }

    }

    private function shiftKeys(pos:Int):Int {

        // Shift entries with the same hash.
        var last:Int = 0;
        var slot:Int = 0;
        var k:Int = 0;
        var data = this.data;
        while (true)
        {
            pos = ((last = pos) + 2) & mask2;
            while (true)
            {
                if ((k = data.get(pos)) == FREE_KEY)
                {
                    data.set(last, FREE_KEY);
                    return last;
                }
                slot = (phiMix(k) & mask) << 1; // Calculate the starting slot for the current key
                if (last <= pos ? last >= slot || slot > pos : last >= slot && slot > pos) break;
                pos = (pos + 2) & mask2; // Go to the next entry
            }
            data.set(last, k);
            data.set(last + 1, data.get(pos + 1));
        }

    }

    function rehash(newCapacity:Int):Void {

        threshold = Std.int(newCapacity/2 * fillFactor);
        mask = Std.int(newCapacity/2) - 1;
        mask2 = newCapacity - 1;

        var oldCapacity = data.length;
        var oldData = data;

        data = new Vector(newCapacity);
        size = hasFreeKey ? 1 : 0;

        var i = 0;
        while (i < oldCapacity) {
            var oldKey = oldData.get(i);
            if (oldKey != FREE_KEY)
                set(oldKey, oldData.get(i + 1));
            i += 2;
        }

    }

    public function copy():IntIntMap {

        var map = new IntIntMap();

        map.data = data.copy();
        map.hasFreeKey = hasFreeKey;
        map.freeValue = freeValue;
        map.fillFactor = fillFactor;
        map.threshold = threshold;
        map.size = size;
        map.iterableKeys = iterableKeys != null ? iterableKeys.copy() : null;
        map.iterableKeysUsed = iterableKeysUsed != null ? iterableKeysUsed.copy() : null;
        map.mask = mask;
        map.mask2 = mask2;

        return map;

    }

    public inline function iterator():IntIntMapIterator {
        return new IntIntMapIterator(this);
    }

    public inline function keys():IntIntMapKeyIterator {
        return new IntIntMapKeyIterator(this);
    }

    public inline function keyValueIterator():IntIntMapKeyValueIterator {
        return new IntIntMapKeyValueIterator(this);
    }

/// Tools

    /**
     * Return the least power of two greater than or equal to the specified value.
     */
    inline static function nextPowerOfTwo(x:Int):Int {

        var result = 1;
        if (x != 0) {
            x--;
            x |= x >> 1;
            x |= x >> 2;
            x |= x >> 4;
            x |= x >> 8;
            x |= x >> 16;
            result = (x | x >> 32) + 1;
        }
        return result;

    }

    /**
     * Returns the least power of two smaller than or equal to 2^30 and larger than or equal to ```Math.ceil(expected / fillFactor)```
     */
    inline static function arraySize(expected:Int, fillFactor:Float):Int {

           var s = Math.max(2, nextPowerOfTwo(Math.ceil(expected / fillFactor)));
           assert(s <= (1 << 30), "array size too large (" + expected + " expected elements with fill factor " + fillFactor + ")");
           return Std.int(s);

    }

    inline static function phiMix(x:Int):Int {

           var h = x * INT_PHI;
           return h ^ (h >> 16);

    }

}

#else

/**
 * Fallback implementation of IntIntMap for non-C++/C# targets.
 * Uses standard Map internally with additional tracking for iteration.
 */
class IntIntMap {

    /**
     * Backing map
     */
    var intMap:Map<Int,Int>;

    /**
     * When this map is marked as iterable, this array will contain every key.
     */
    public var iterableKeys(default,null):Array<Int> = null;
    var iterableKeysUsed:IntBoolMap = null;

    public var size(default,null):Int = 0;

    public function new(size:Int = 16, fillFactor:Float = 0.5, iterable:Bool = false) {
        intMap = new Map<Int,Int>();

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

    public function set(key:Int, value:Int):Int {
        if (iterableKeys != null && !iterableKeysUsed.get(key)) {
            iterableKeysUsed.set(key, true);
            iterableKeys.push(key);
        }
        var k = Std.int(key);
        if (!intMap.exists(k)) {
            size++;
        }
        intMap.set(k, Std.int(value));
        return value;
    }

    inline public function get(key:Int):Int {
        return getInline(key);
    }

    public function remove(key:Int):Int {
        var k = Std.int(key);
        var prev:Int = 0;
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

    inline public function getInline(key:Int):Int {
        var value = intMap.get(Std.int(key));
        return value != null ? value : 0;
    }

    inline public function existsInline(key:Int):Bool {
        return intMap.exists(Std.int(key));
    }

    inline public function copy():IntIntMap {

        var map = new IntIntMap();

        map.intMap = intMap.copy();
        map.size = size;
        map.iterableKeys = iterableKeys != null ? iterableKeys.copy() : null;
        map.iterableKeysUsed = iterableKeysUsed != null ? iterableKeysUsed.copy() : null;

        return map;

    }

    inline public function iterator():IntIntMapIterator {
        return new IntIntMapIterator(this);
    }

    inline public function keys():IntIntMapKeyIterator {
        return new IntIntMapKeyIterator(this);
    }

    inline public function keyValueIterator():IntIntMapKeyValueIterator {
        return new IntIntMapKeyValueIterator(this);
    }

}

#end

/**
 * Iterator implementation for IntIntMap values.
 * Allows iterating over integer values in the map when it was created with iterable=true.
 */
@:allow(ceramic.IntIntMap)
class IntIntMapIterator {

    var intIntMap:IntIntMap;
    var i:Int;
    var len:Int;

    inline private function new(intIntMap:IntIntMap) {

        this.intIntMap = intIntMap;
        i = 0;
        var iterableKeys = this.intIntMap.iterableKeys;
        len = iterableKeys != null ? iterableKeys.length : -1;

    }

    inline public function hasNext():Bool {
        return i < len;
    }

    inline public function next():Int {

        var n = i++;
        var k = intIntMap.iterableKeys.unsafeGet(n);
        return intIntMap.get(k);

    }

}

/**
 * Iterator implementation for IntIntMap keys.
 * Allows iterating over integer keys in the map when it was created with iterable=true.
 */
@:allow(ceramic.IntIntMap)
class IntIntMapKeyIterator {

    var iterableKeys:Array<Int>;
    var i:Int;
    var len:Int;

    inline private function new(intIntMap:IntIntMap) {

        i = 0;
        iterableKeys = intIntMap.iterableKeys;
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
 * Iterator implementation for IntIntMap key-value pairs.
 * Returns objects with {key:Int, value:Int} when iterating.
 */
@:allow(ceramic.IntIntMap)
class IntIntMapKeyValueIterator {

    var intIntMap:IntIntMap;
    var i:Int;
    var len:Int;

    inline private function new(intIntMap:IntIntMap) {

        this.intIntMap = intIntMap;
        i = 0;
        var iterableKeys = this.intIntMap.iterableKeys;
        len = iterableKeys != null ? iterableKeys.length : -1;

    }

    inline public function hasNext():Bool {
        return i < len;
    }

    inline public function next():{ key:Int, value:Int } {

        var n = i++;
        var k = intIntMap.iterableKeys.unsafeGet(n);
        return { key: k, value: intIntMap.get(k) };

    }

}
