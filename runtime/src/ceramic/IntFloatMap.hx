package ceramic;

import haxe.ds.Vector;

#if (!documentation && (cpp || cs))

/**
 * An float map that uses integers as key.
 */
class IntFloatMap {

    inline static var NO_VALUE = 0;

    inline static var FREE_VALUE = 2147483647.0; // We may use a better value later?

    inline static var RESERVED_GAP = 1;

    var keys:IntIntMap;

    var nextFreeIndex:Int = 0;

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

        keys = new IntIntMap(size, fillFactor, false);
        values = new Vector(size);

        if (iterable) {
            iterableKeys = [];
        }

    }

    public function get(key:Int):Float {

        return getInline(key);

    }

    inline public function getInline(key:Int):Float {

        var index = keys.getInline(key);
        return index >= RESERVED_GAP ? values.get(index - RESERVED_GAP) : 0.0;

    }

    public function exists(key:Int) {

        return existsInline(key);

    }

    inline public function existsInline(key:Int) {

        return keys.existsInline(key);

    }

    public function set(key:Int, value:Float):Void {

        var index = keys.get(key);
        if (index >= RESERVED_GAP) {
            // Replace value in array with same index and key
            values.set(index - RESERVED_GAP, value);
        }
        else {
            // New key, use next free index
            var valuesLen = values.length;
            if (nextFreeIndex >= valuesLen) {
                resizeValues(values.length * 2);
            }
            values.set(nextFreeIndex, value);
            keys.set(key, nextFreeIndex + RESERVED_GAP);
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

        var index = keys.get(key);
        if (index != NO_VALUE) {
            index -= RESERVED_GAP;

            // Key exists, set value to FREE (make slot available)
            values.set(index, FREE_VALUE);

            // Update next free index if needed
            if (nextFreeIndex > index) {
                nextFreeIndex = index;
            }

            // Remove key
            keys.remove(key);

            // Update iterable keys
            if (iterableKeys != null) {
                iterableKeys.splice(iterableKeys.indexOf(key), 1);
            }
        }

    }

    public function copy():IntFloatMap {

        var map = new IntFloatMap();

        map.keys = keys.copy();
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

    }

}

#else

abstract IntFloatMap(Map<Int,Float>) {

    inline public function new(size:Int = 16, fillFactor:Float = 0.5, iterable:Bool = false) {
        this = new Map<Int,Float>();
    }

    public var size(get,never):Int;
    inline function get_size():Int {
        return Lambda.count(this);
    }

    public var iterableKeys(get,never):Array<Int>;
    inline function get_iterableKeys():Array<Int> {
        var keys:Array<Int> = [];
        for (k in this.keys()) {
            keys.push(k);
        }
        return keys;
    }

    inline public function exists(key:Int):Bool {
        return existsInline(key);
    }

    inline public function set(key:Int, value:Float):Float {
        this.set(Std.int(key), value);
        return value;
    }

    inline public function get(key:Int):Float {
        return getInline(key);
    }

    inline public function remove(key:Int):Void {
        this.remove(Std.int(key));
    }

    inline public function getInline(key:Int):Float {
        var value = this.get(Std.int(key));
        return value != null ? value : 0.0;
    }

    inline public function existsInline(key:Int):Bool {
        return this.exists(Std.int(key));
    }

    inline public function copy():IntFloatMap {
        return cast this.copy();
    }

}

#end
