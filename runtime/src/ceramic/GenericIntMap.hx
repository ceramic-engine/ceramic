package ceramic;

import haxe.ds.Vector;

/**
 * A map with integer keys and typed values, compiled once per value type.
 *
 * `GenericIntMap` is marked `@:generic`: every value type gets its own
 * class (`GenericIntMap_glaze_AtlasTile` and so on). On hxcpp and C#,
 * `get` returns values with their own type: on hxcpp, no call into the
 * hxcpp library (`haxe.ds.IntMap`) and no `Dynamic` return converted by
 * the caller (`haxe.ds.IntMap` and `ceramic.IntMap`). Use it on hot lookup
 * paths; elsewhere, `ceramic.IntMap` makes less code.
 *
 * On hxcpp and C#, it is an open addressing table with linear probing,
 * the same algorithm as `IntIntMap` (keys mixed with the golden ratio,
 * entries shifted back on removal), with keys and values in two parallel
 * vectors. On other targets it wraps `haxe.ds.IntMap`, which is already
 * typed there.
 *
 * A class used as value type must be known where the map is declared: a
 * `@:generic` class can only be instantiated with concrete types, or with
 * the type parameters of another `@:generic` class or function. Refer to
 * it by its name: with an import alias (`import ceramic.GenericIntMap as
 * M`), Haxe 4.3 types nested maps of a `@:generic` class as the plain,
 * non specialized class.
 *
 * `get` returns `null` for a missing key. A `null` value can be stored and
 * is then told apart from a missing key with `exists`. With a basic value
 * type (`Int`, `Float`, `Bool`) on a static target, `get` returns a
 * `Null<V>` (boxed on hxcpp): prefer `IntIntMap`, `IntFloatMap` and
 * `IntBoolMap` for those.
 *
 * Iteration (`keys`, `iterator`, `keyValueIterator`) is not meant for hot
 * paths: it walks a copy of the keys (and values) taken when it starts, in
 * storage order, so the map can be changed while iterating.
 *
 * Example usage:
 * ```haxe
 * var map = new GenericIntMap<String>();
 * map.set(42, "hello");
 * trace(map.get(42)); // "hello"
 * trace(map.exists(7)); // false
 * ```
 *
 * @see IntMap
 * @see IntIntMap
 */
@:generic
class GenericIntMap<V> {

    #if (cpp || cs)

    /** Keys, `FREE_KEY` for an empty slot (key 0 is stored apart) */
    var keyData:Vector<Int>;

    /** Values, at the index of their key */
    var valueData:Vector<Null<V>>;

    /** Whether key 0 is in the map */
    var hasFreeKey:Bool = false;

    /** Value of key 0 */
    var freeValue:Null<V> = null;

    var fillFactor:Float;

    /** Number of keys above which the table grows */
    var threshold:Int;

    var mask:Int;

    #else

    var map:haxe.ds.IntMap<V>;

    #end

    /**
     * Number of keys in the map.
     */
    public var size(default, null):Int = 0;

    /**
     * Creates a new map.
     * @param size Expected number of keys (default: 16)
     * @param fillFactor Fill factor of the table, in 0 (excluded) and 1 (excluded) (default: 0.5)
     */
    public function new(size:Int = 16, fillFactor:Float = 0.5) {

        #if (cpp || cs)
        this.fillFactor = fillFactor;
        allocate(GenericIntMapTools.arraySize(size, fillFactor));
        #else
        map = new haxe.ds.IntMap();
        #end

    }

    /**
     * Gets the value associated with the given key.
     * @param key The integer key
     * @return The value, or `null` if the key doesn't exist
     */
    public function get(key:Int):Null<V> {

        return getInline(key);

    }

    inline public function getInline(key:Int):Null<V> {

        #if (cpp || cs)
        var res:Null<V> = null;
        if (key == GenericIntMapTools.FREE_KEY) {
            if (hasFreeKey)
                res = freeValue;
        }
        else {
            final keyData = this.keyData;
            final mask = this.mask;
            var ptr = GenericIntMapTools.phiMix(key) & mask;
            while (true) {
                final k = keyData.get(ptr);
                if (k == key) {
                    res = valueData.get(ptr);
                    break;
                }
                if (k == GenericIntMapTools.FREE_KEY)
                    break;
                ptr = (ptr + 1) & mask;
            }
        }
        return res;
        #else
        return map.get(key);
        #end

    }

    /**
     * Checks if a key exists in the map.
     * @param key The integer key to check
     * @return True if the key exists (even if its value is `null`)
     */
    public function exists(key:Int):Bool {

        return existsInline(key);

    }

    inline public function existsInline(key:Int):Bool {

        #if (cpp || cs)
        return key == GenericIntMapTools.FREE_KEY ? hasFreeKey : find(key) != -1;
        #else
        return map.exists(key);
        #end

    }

    /**
     * Sets the value of the given key.
     * @param key The integer key
     * @param value The value to set (can be `null`)
     */
    public function set(key:Int, value:Null<V>):Void {

        #if (cpp || cs)
        if (key == GenericIntMapTools.FREE_KEY) {
            if (!hasFreeKey) {
                hasFreeKey = true;
                size++;
            }
            freeValue = value;
            return;
        }
        final mask = this.mask;
        var ptr = GenericIntMapTools.phiMix(key) & mask;
        while (true) {
            final k = keyData.get(ptr);
            if (k == key) {
                valueData.set(ptr, value);
                return;
            }
            if (k == GenericIntMapTools.FREE_KEY)
                break;
            ptr = (ptr + 1) & mask;
        }
        keyData.set(ptr, key);
        valueData.set(ptr, value);
        size++;
        if (size > threshold)
            rehash(keyData.length * 2);
        #else
        if (!map.exists(key))
            size++;
        map.set(key, value);
        #end

    }

    /**
     * Removes the given key from the map.
     * @param key The integer key to remove
     * @return True if the key was in the map
     */
    public function remove(key:Int):Bool {

        #if (cpp || cs)
        if (key == GenericIntMapTools.FREE_KEY) {
            if (!hasFreeKey)
                return false;
            hasFreeKey = false;
            freeValue = null;
            size--;
            return true;
        }
        final ptr = find(key);
        if (ptr == -1)
            return false;
        shiftKeys(ptr);
        size--;
        return true;
        #else
        if (map.remove(key)) {
            size--;
            return true;
        }
        return false;
        #end

    }

    /**
     * Removes every key from the map. The table keeps its current capacity.
     */
    public function clear():Void {

        #if (cpp || cs)
        final keyData = this.keyData;
        final valueData = this.valueData;
        for (i in 0...keyData.length) {
            keyData.set(i, GenericIntMapTools.FREE_KEY);
            valueData.set(i, null);
        }
        hasFreeKey = false;
        freeValue = null;
        #else
        map.clear();
        #end
        size = 0;

    }

    /**
     * Creates a shallow copy of this map.
     * @return A new map with the same keys and values
     */
    public function copy():GenericIntMap<V> {

        final result = new GenericIntMap<V>();
        #if (cpp || cs)
        result.keyData = keyData.copy();
        result.valueData = valueData.copy();
        result.hasFreeKey = hasFreeKey;
        result.freeValue = freeValue;
        result.fillFactor = fillFactor;
        result.threshold = threshold;
        result.mask = mask;
        #else
        result.map = map.copy();
        #end
        result.size = size;
        return result;

    }

    /**
     * Returns the keys of the map, in storage order, in a new array.
     */
    public function keysArray():Array<Int> {

        final result:Array<Int> = [];
        #if (cpp || cs)
        if (hasFreeKey)
            result.push(GenericIntMapTools.FREE_KEY);
        final keyData = this.keyData;
        for (i in 0...keyData.length) {
            final k = keyData.get(i);
            if (k != GenericIntMapTools.FREE_KEY)
                result.push(k);
        }
        #else
        for (k in map.keys())
            result.push(k);
        #end
        return result;

    }

    /**
     * Returns an iterator over the keys of this map.
     */
    public inline function keys():Iterator<Int> {
        return keysArray().iterator();
    }

    /**
     * Returns an iterator over the values of this map.
     */
    public function iterator():Iterator<Null<V>> {
        final values:Array<Null<V>> = [];
        for (k in keysArray())
            values.push(getInline(k));
        return values.iterator();
    }

    /**
     * Returns an iterator over the key-value pairs of this map.
     */
    public function keyValueIterator():KeyValueIterator<Int, Null<V>> {
        final pairs:Array<{key:Int, value:Null<V>}> = [];
        for (k in keysArray())
            pairs.push({key: k, value: getInline(k)});
        return pairs.iterator();
    }

    #if (cpp || cs)

/// Internal

    function allocate(capacity:Int):Void {

        keyData = new Vector(capacity);
        valueData = new Vector(capacity);
        for (i in 0...capacity) {
            keyData.set(i, GenericIntMapTools.FREE_KEY);
            valueData.set(i, null);
        }
        mask = capacity - 1;
        threshold = Std.int(capacity * fillFactor);

    }

    /** Index of a non zero key in the table, or -1 */
    function find(key:Int):Int {

        final keyData = this.keyData;
        final mask = this.mask;
        var ptr = GenericIntMapTools.phiMix(key) & mask;
        while (true) {
            final k = keyData.get(ptr);
            if (k == key)
                return ptr;
            if (k == GenericIntMapTools.FREE_KEY)
                return -1;
            ptr = (ptr + 1) & mask;
        }

    }

    /** Fills the slot at `pos` by moving back the entries that probed past it */
    function shiftKeys(pos:Int):Void {

        final keyData = this.keyData;
        final valueData = this.valueData;
        final mask = this.mask;
        var last = 0;
        var k = 0;
        var slot = 0;
        while (true) {
            last = pos;
            pos = (pos + 1) & mask;
            while (true) {
                k = keyData.get(pos);
                if (k == GenericIntMapTools.FREE_KEY) {
                    keyData.set(last, GenericIntMapTools.FREE_KEY);
                    valueData.set(last, null);
                    return;
                }
                slot = GenericIntMapTools.phiMix(k) & mask;
                if (last <= pos ? (last >= slot || slot > pos) : (last >= slot && slot > pos))
                    break;
                pos = (pos + 1) & mask;
            }
            keyData.set(last, k);
            valueData.set(last, valueData.get(pos));
        }

    }

    function rehash(newCapacity:Int):Void {

        final oldKeys = keyData;
        final oldValues = valueData;
        allocate(newCapacity);
        final mask = this.mask;
        final keyData = this.keyData;
        final valueData = this.valueData;
        for (i in 0...oldKeys.length) {
            final k = oldKeys.get(i);
            if (k != GenericIntMapTools.FREE_KEY) {
                var ptr = GenericIntMapTools.phiMix(k) & mask;
                while (keyData.get(ptr) != GenericIntMapTools.FREE_KEY)
                    ptr = (ptr + 1) & mask;
                keyData.set(ptr, k);
                valueData.set(ptr, oldValues.get(i));
            }
        }

    }

    #end

}

#if (cpp || cs)

/**
 * Constants and helpers of `GenericIntMap` (a `@:generic` class can't have
 * static fields).
 */
@:noCompletion
class GenericIntMapTools {

    public static inline var INT_PHI = 0x9E3779B9;

    /** Key of an empty slot */
    public static inline var FREE_KEY = 0;

    public inline static function nextPowerOfTwo(x:Int):Int {

        var result = 1;
        if (x != 0) {
            x--;
            x |= x >> 1;
            x |= x >> 2;
            x |= x >> 4;
            x |= x >> 8;
            x |= x >> 16;
            result = x + 1;
        }
        return result;

    }

    public inline static function arraySize(expected:Int, fillFactor:Float):Int {

        if (expected < 1)
            expected = 1;
        var s = nextPowerOfTwo(Math.ceil(expected / fillFactor));
        if (s < 2)
            s = 2;
        if (s > (1 << 30))
            throw 'GenericIntMap: table too large ($expected keys expected with fill factor $fillFactor)';
        return s;

    }

    public inline static function phiMix(x:Int):Int {

        final h = x * INT_PHI;
        return h ^ (h >> 16);

    }

}

#end
