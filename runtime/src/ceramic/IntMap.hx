package ceramic;

import haxe.ds.Vector;

/** An object map that uses integers as key. */
class IntMap<V> {

    inline static var NO_VALUE = 0;

    inline static var NULL_VALUE = 1;

    inline static var RESERVED_GAP = 2;

    var keys:IntIntMap;

    var nextFreeIndex:Int = 0;

    /** When this map is marked as iterable, this array will contain every key. */
    public var iterableKeys(default,null):Array<Int> = null;

    /** Values as they are stored.
        Can be used to iterate on values directly,
        but can contain null values. */
    #if (cs && unity)
    public var values(default,null):Vector<Any>;
    #else
    public var values(default,null):Vector<V>;
    #end

    public function new(size:Int = 16, fillFactor:Float = 0.5, iterable:Bool = false) {

        keys = new IntIntMap(size, fillFactor);
        values = new Vector(size);
        
        if (iterable) {
            iterableKeys = [];
        }

    }

    public function get(key:Int):V {

        return getInline(key);

    }

    inline public function getInline(key:Int):V {

        var index = keys.getInline(key);
        return index >= RESERVED_GAP ? values.get(index - RESERVED_GAP) : null;

    }

    public function exists(key:Int) {

        return existsInline(key);

    }

    inline public function existsInline(key:Int) {

        return keys.existsInline(key);

    }

    public function set(key:Int, value:V):Void {

        var index = keys.get(key);
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
                keys.set(key, NULL_VALUE);
            }
        }
        else if (value == null) {
            if (index != NULL_VALUE) {
                // New key, but null value,
                // no need to touch values array
                keys.set(key, NULL_VALUE);
                // Update iterable keys
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
            keys.set(key, nextFreeIndex + RESERVED_GAP);

            // Update iterable keys if new value
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

    public function remove(key:Int) {

        var index = keys.get(key);
        if (index != 0) {
            // Key exists, set value to null
            values.set(index - RESERVED_GAP, null);
            // Update next free index if needed
            if (nextFreeIndex >= index) {
                nextFreeIndex = index - 1;
            }
            // Remove key
            keys.remove(key);
            // Update iterable keys
            if (iterableKeys != null) {
                iterableKeys.splice(iterableKeys.indexOf(key), 1);
            }
        }

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
