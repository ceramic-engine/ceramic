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
    public var iterableKeys(get,never):Array<Int>;
    inline function get_iterableKeys():Array<Int> return keys.iterableKeys;

    /** Values as they are stored.
        Can be used to iterate on values directly,
        but can contain null values. */
    public var values(default,null):Vector<V>;

    public function new(size:Int = 16, fillFactor:Float = 0.5, iterable:Bool = false) {

        keys = new IntIntMap(size, fillFactor, iterable);
        values = new Vector(size);

    } //new

    inline public function get(key:Int):V {

        var index = keys.get(key);
        return index >= RESERVED_GAP ? values.get(index - RESERVED_GAP) : null;

    } //get

    inline public function exists(key:Int) {

        return keys.exists(key);

    } //exists

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
            }
        }
        else {
            // New key, use next free index
            var valuesLen = values.length;
            if (nextFreeIndex >= valuesLen) {
                resizeValues(values.length * 2);
            }
            values.set(nextFreeIndex, value);
            keys.set(key, nextFreeIndex + RESERVED_GAP);

            do {
                // Move free index to next location
                nextFreeIndex++;
            }
            while (nextFreeIndex < valuesLen && values.get(nextFreeIndex) != null);
        }

    } //set

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
        }

    } //remove

/// Internal

    function resizeValues(targetSize:Int) {

        var prevValues = values;
        values = new Vector<V>(targetSize);
        for (i in 0...prevValues.length) {
            values.set(i, prevValues.get(i));
        }

    } //resizeValues

} //IntMap
