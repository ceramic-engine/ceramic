package ceramic;

import haxe.ds.Vector;

/** An float map that uses integers as key. */
class IntFloatMap {

    inline static var NO_VALUE = 0;

    inline static var FREE_VALUE = 2147483647.0; // We may use a better value later?

    inline static var RESERVED_GAP = 1;

    var keys:IntIntMap;

    var nextFreeIndex:Int = 0;

    /** When this map is marked as iterable, this array will contain every key. */
    public var iterableKeys(get,never):Array<Int>;
    inline function get_iterableKeys():Array<Int> return keys.iterableKeys;

    /** Values as they are stored.
        Can be used to iterate on values directly,
        but can contain null values. */
    public var values(default,null):Vector<Float>;

    public function new(size:Int = 16, fillFactor:Float = 0.5, iterable:Bool = false) {

        keys = new IntIntMap(size, fillFactor, iterable);
        values = new Vector(size);

    } //new

    inline public function get(key:Int):Float {

        var index = keys.get(key);
        return index >= RESERVED_GAP ? values.get(index - RESERVED_GAP) : 0.0;

    } //get

    inline public function exists(key:Int) {

        return keys.exists(key);

    } //exists

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

            do {
                // Move free index to next location
                nextFreeIndex++;
            }
            while (nextFreeIndex < valuesLen && values.get(nextFreeIndex) != FREE_VALUE);
        }

    } //set

    public function remove(key:Int) {

        var index = keys.get(key);
        if (index != 0) {
            // Key exists, set value to FREE (make slot available)
            values.set(index - RESERVED_GAP, FREE_VALUE);
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
        values = new Vector<Float>(targetSize);
        for (i in 0...prevValues.length) {
            values.set(i, prevValues.get(i));
        }

    } //resizeValues

} //IntFloatMap
