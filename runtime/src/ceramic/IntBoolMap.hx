package ceramic;

using ceramic.Extensions;

/**
 * A map that uses int as keys and booleans as values.
 * 
 * IntBoolMap is a high-performance map optimized for storing boolean values
 * with integer keys. It's implemented as an abstract over IntIntMap, storing
 * booleans as 0 and 1 internally.
 * 
 * Features:
 * - O(1) average case get/set operations
 * - Minimal memory overhead
 * - Optional iteration support
 * - Zero allocation for boolean operations
 * 
 * Example usage:
 * ```haxe
 * var flags = new IntBoolMap();
 * flags.set(42, true);
 * flags.set(10, false);
 * 
 * if (flags.get(42)) {
 *     trace("Flag 42 is set");
 * }
 * 
 * // With iteration support
 * var iterableFlags = new IntBoolMap(16, 0.5, true);
 * for (key in iterableFlags.keys()) {
 *     trace('Flag $key = ${iterableFlags.get(key)}');
 * }
 * ```
 * 
 * @see IntIntMap
 * @see IntFloatMap
 * @see IntMap
 */
abstract IntBoolMap(IntIntMap) {

    public var size(get,never):Int;
    inline public function get_size():Int return this.size;

    public var iterableKeys(get,never):Array<Int>;
    inline function get_iterableKeys():Array<Int> return this.iterableKeys;

    inline function _asIntBoolMap():IntBoolMap {
        return untyped this;
    }

    /**
     * Creates a new IntBoolMap.
     * @param size Initial capacity (default: 16)
     * @param fillFactor Fill factor for internal map (default: 0.5)
     * @param iterable Enable iteration support (default: false)
     */
    inline public function new(size:Int = 16, fillFactor:Float = 0.5, iterable:Bool = false) {
        this = new IntIntMap(size, fillFactor, iterable);
    }

    /**
     * Checks if a key exists in the map.
     * @param key The integer key to check
     * @return True if the key exists
     */
    inline public function exists(key:Int):Bool {
        return this.exists(key);
    }

    /**
     * Inline version of exists for performance-critical code.
     * @param key The integer key to check
     * @return True if the key exists
     */
    inline public function existsInline(key:Int):Bool {
        return this.existsInline(key);
    }

    /**
     * Gets the boolean value for the given key.
     * @param key The integer key
     * @return The boolean value, or false if key doesn't exist
     */
    inline public function get(key:Int):Bool {
        return this.get(key) != 0;
    }

    /**
     * Inline version of get for performance-critical code.
     * @param key The integer key
     * @return The boolean value, or false if key doesn't exist
     */
    inline public function getInline(key:Int):Bool {
        return this.getInline(key) != 0;
    }

    /**
     * Sets a boolean value for the given key.
     * @param key The integer key
     * @param value The boolean value to set
     */
    inline public function set(key:Int, value:Bool):Void {
        this.set(key, value ? 1 : 0);
    }

    /**
     * Removes a key-value pair from the map.
     * @param key The integer key to remove
     * @return The previous boolean value
     */
    inline public function remove(key:Int):Bool {
        return this.remove(key) != 0;
    }

    /**
     * Clears all key-value pairs from the map.
     */
    inline public function clear():Void {
        this.clear();
    }

    /**
     * Creates a shallow copy of this map.
     * @return A new IntBoolMap with the same key-value pairs
     */
    public function copy():IntBoolMap {
        return cast this.copy();
    }

    /**
     * Returns an iterator over the boolean values in this map.
     * Note: Map must be created with iterable=true
     */
    inline public function iterator():IntBoolMapIterator {
        return new IntBoolMapIterator(_asIntBoolMap());
    }

    /**
     * Returns an iterator over the keys in this map.
     * Note: Map must be created with iterable=true
     */
    inline public function keys():IntBoolMapKeyIterator {
        return new IntBoolMapKeyIterator(_asIntBoolMap());
    }

    /**
     * Returns an iterator over key-value pairs in this map.
     * Note: Map must be created with iterable=true
     */
    inline public function keyValueIterator():IntBoolMapKeyValueIterator {
        return new IntBoolMapKeyValueIterator(_asIntBoolMap());
    }

}

@:allow(ceramic.IntBoolMap)
class IntBoolMapIterator {

    var intBoolMap:IntBoolMap;
    var i:Int;
    var len:Int;

    inline private function new(intBoolMap:IntBoolMap) {

        this.intBoolMap = intBoolMap;
        i = 0;
        var iterableKeys = this.intBoolMap.iterableKeys;
        len = iterableKeys != null ? iterableKeys.length : -1;

    }

    inline public function hasNext():Bool {
        return i < len;
    }

    inline public function next():Bool {

        var n = i++;
        var k = intBoolMap.iterableKeys.unsafeGet(n);
        return intBoolMap.get(k);

    }

}

@:allow(ceramic.IntBoolMap)
class IntBoolMapKeyIterator {

    var iterableKeys:Array<Int>;
    var i:Int;
    var len:Int;

    inline private function new(intBoolMap:IntBoolMap) {

        i = 0;
        iterableKeys = intBoolMap.iterableKeys;
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

@:allow(ceramic.IntBoolMap)
class IntBoolMapKeyValueIterator {

    var intBoolMap:IntBoolMap;
    var i:Int;
    var len:Int;

    inline private function new(intBoolMap:IntBoolMap) {

        this.intBoolMap = intBoolMap;
        i = 0;
        var iterableKeys = this.intBoolMap.iterableKeys;
        len = iterableKeys != null ? iterableKeys.length : -1;

    }

    inline public function hasNext():Bool {
        return i < len;
    }

    inline public function next():{ key:Int, value:Bool } {

        var n = i++;
        var k = intBoolMap.iterableKeys.unsafeGet(n);
        return { key: k, value: intBoolMap.get(k) };

    }

}

