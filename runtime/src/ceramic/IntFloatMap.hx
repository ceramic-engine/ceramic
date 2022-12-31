package ceramic;

import haxe.ds.Vector;

using ceramic.Extensions;

#if (!documentation && (cpp || cs))

/**
 * An float map that uses integers as key.
 */
class IntFloatMap {

    inline static var NO_VALUE = 0;

    inline static var FREE_VALUE = 2147483647.0; // We may use a better value later?

    inline static var RESERVED_GAP = 1;

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
    public var values(default,null):Vector<Float>;

    public function new(size:Int = 16, fillFactor:Float = 0.5, iterable:Bool = false) {

        initialSize = size;
        initialFillFactor = fillFactor;

        _keys = new IntIntMap(size, fillFactor, false);
        values = new Vector(size);

        if (iterable) {
            iterableKeys = [];
        }

    }

    public function get(key:Int):Float {

        return getInline(key);

    }

    inline public function getInline(key:Int):Float {

        var index = _keys.getInline(key);
        return index >= RESERVED_GAP ? values.get(index - RESERVED_GAP) : 0.0;

    }

    public function clear():Void {

        _keys = new IntIntMap(initialSize, initialFillFactor);
        values = new Vector(initialSize);
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
            values.set(index - RESERVED_GAP, value);
        }
        else {
            // New key, use next free index
            var valuesLen = values.length;
            if (nextFreeIndex >= valuesLen) {
                resizeValues(valuesLen * 2);
            }
            values.set(nextFreeIndex, value);
            _keys.set(key, nextFreeIndex + RESERVED_GAP);
            // Update iterable keys
            if (iterableKeys != null) {
                iterableKeys.push(key);
            }

            do {
                // Move free index to next location
                nextFreeIndex++;
            }
            while (nextFreeIndex < valuesLen && values.get(nextFreeIndex) != FREE_VALUE);
        }

    }

    public function remove(key:Int) {

        var index = _keys.get(key);
        if (index != NO_VALUE) {
            index -= RESERVED_GAP;

            // Key exists, set value to FREE (make slot available)
            values.set(index, FREE_VALUE);

            // Update next free index if needed
            if (nextFreeIndex > index) {
                nextFreeIndex = index;
            }

            // Remove key
            _keys.remove(key);

            // Update iterable keys
            if (iterableKeys != null) {
                iterableKeys.splice(iterableKeys.indexOf(key), 1);
            }
        }

    }

    public function copy():IntFloatMap {

        var map = new IntFloatMap();

        map.initialSize = initialSize;
        map.initialFillFactor = initialFillFactor;
        map._keys = _keys.copy();
        map.nextFreeIndex = nextFreeIndex;
        map.iterableKeys = iterableKeys != null ? iterableKeys.copy() : null;
        map.values = values.copy();

        return map;

    }

/// Internal

    function resizeValues(targetSize:Int) {

        var prevValues = values;
        values = new Vector<Float>(targetSize);
        for (i in 0...prevValues.length) {
            values.set(i, prevValues.get(i));
        }
        for (i in prevValues.length...targetSize) {
            values.set(i, FREE_VALUE);
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

class IntFloatMap {

    /**
     * Backing map
     */
    var intMap:Map<Int,Float>;

    /**
     * When this map is marked as iterable, this array will contain every key.
     */
    public var iterableKeys(default,null):Array<Int> = null;
    var iterableKeysUsed:IntBoolMap = null;

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

    inline public function next():Float {

        var n = i++;
        return iterableKeys.unsafeGet(n);

    }

}

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