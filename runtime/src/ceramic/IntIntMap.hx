package ceramic;

#if cpp

import haxe.ds.Vector;
import ceramic.Assert.assert;

/** Port of https://github.com/mikvor/hashmapTest/blob/55669a0c3ee1f9c2525580e4ace06e910d5972ec/src/main/java/map/intint/IntIntMap4a.java to haxe */
class IntIntMap {

    static inline var INT_PHI = 0x9E3779B9;

    static inline var FREE_KEY = 0;

    static inline var NO_VALUE = 0;

    /** Keys and values */
    var data:Vector<Int>;

    /** Do we have `free` key in the map? */
    var hasFreeKey:Bool;
    /** Value of `free` key */
    var freeValue:Int;

    /** Fill factor, must be between 0 (excluded) and 1 (excluded) */
    var fillFactor:Float;
    /** We will resize a map once it reaches this size */
    var threshold:Int;
    /** Current map size */
    public var size(default,null):Int;

    /** When this map is marked as iterable, this array will contain every key. */
    public var iterableKeys(default,null):Array<Int> = null;

    /** Mask to calculate the original position */
    var mask:Int;
    /** Mask to calculate the original position */
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
        }

    } //new

    public function exists(key:Int):Bool {

        var ptr = (phiMix(key) & mask) << 1;

        if (key == FREE_KEY)
            return hasFreeKey ? true : false;

        var k = data.get(ptr);

        if (k == FREE_KEY) {
            // End of chain already
            return false;
        }
        if (k == key) {
            // We check FREE prior to this call
            return true;
        }

        while (true)
        {
            // That's next index
            ptr = (ptr + 2) & mask2;
            k = data.get(ptr);
            if (k == FREE_KEY) {
                return false;
            }
            if (k == key) {
                return true;
            }
        }

    } //exists

    public function get(key:Int):Int {

        var ptr = (phiMix(key) & mask) << 1;

        if (key == FREE_KEY)
            return hasFreeKey ? freeValue : NO_VALUE;

        var k = data.get(ptr);

        if (k == FREE_KEY) {
            // End of chain already
            return NO_VALUE;
        }
        if (k == key) {
            // We check FREE prior to this call
            return data.get(ptr + 1);
        }

        while (true)
        {
            // That's next index
            ptr = (ptr + 2) & mask2;
            k = data.get(ptr);
            if (k == FREE_KEY) {
                return NO_VALUE;
            }
            if (k == key) {
                return data.get(ptr + 1);
            }
        }

    } //get

    public function set(key:Int, value:Int):Int {

        if (key == FREE_KEY)
        {
            var ret = freeValue;
            if (!hasFreeKey) {
                if (iterableKeys != null) {
                    iterableKeys.push(key);
                }
                size++;
            }
            hasFreeKey = true;
            freeValue = value;
            return ret;
        }

        var ptr = (phiMix(key) & mask) << 1;
        var k = data.get(ptr);
        if (k == FREE_KEY) // End of chain already
        {
            data.set(ptr, key);
            data.set(ptr + 1, value);
            if (size >= threshold) {
                rehash(data.length * 2); // Size is set inside
            } else {
                size++;
            }
            if (iterableKeys != null) {
                iterableKeys.push(key);
            }
            return NO_VALUE;
        }
        else if (k == key) // We check FREE prior to this call
        {
            var ret = data.get(ptr + 1);
            data.set(ptr + 1, value);
            return ret;
        }

        while (true)
        {
            ptr = (ptr + 2) & mask2; // That's next index calculation
            k = data.get(ptr);
            if (k == FREE_KEY)
            {
                data.set(ptr, key);
                data.set(ptr + 1, value);
                if (size >= threshold) {
                    rehash(data.length * 2); // Size is set inside
                }
                else {
                    size++;
                }
                if (iterableKeys != null) {
                    iterableKeys.push(key);
                }
                return NO_VALUE;
            }
            else if (k == key)
            {
                var ret = data.get(ptr + 1);
                data.set(ptr + 1, value);
                return ret;
            }
        }

    } //set

    public function remove(key:Int):Int {

        if (key == FREE_KEY)
        {
            if (!hasFreeKey) {
                return NO_VALUE;
            }
            hasFreeKey = false;
            size--;
            if (iterableKeys != null) {
                iterableKeys.splice(iterableKeys.indexOf(key), 1);
            }
            return freeValue; // Value is not cleaned
        }

        var ptr = (phiMix(key) & mask) << 1;
        var k = data.get(ptr);
        if (k == key) // We check FREE prior to this call
        {
            var res = data.get(ptr + 1);
            shiftKeys(ptr);
            size--;
            if (iterableKeys != null) {
                iterableKeys.splice(iterableKeys.indexOf(key), 1);
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
                var res = data.get(ptr + 1);
                shiftKeys(ptr);
                size--;
                if (iterableKeys != null) {
                    iterableKeys.splice(iterableKeys.indexOf(key), 1);
                }
                return res;
            }
            else if (k == FREE_KEY) {
                return NO_VALUE;
            }
        }

    } //remove

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

    } //shiftKeys

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

    } //rehash

/// Tools

    /** Return the least power of two greater than or equal to the specified value. */
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

    } //nextPowerOfTwo

    /** Returns the least power of two smaller than or equal to 2^30 and larger than or equal to ```Math.ceil(expected / fillFactor)``` **/
    inline static function arraySize(expected:Int, fillFactor:Float):Int {

   		var s = Math.max(2, nextPowerOfTwo(Math.ceil(expected / fillFactor)));
   		assert(s <= (1 << 30), "array size too large (" + expected + " expected elements with fill factor " + fillFactor + ")");
   		return Std.int(s);

    } //arraySize

    inline static function phiMix(x:Int):Int {

   		var h = x * INT_PHI;
   		return h ^ (h >> 16);

   	} //phiMix

} //IntIntMap

#else

@:forward(get, set, exists)
abstract IntIntMap(Map<Int,Int>) {

    inline public function new(size:Int = 16, fillFactor:Float = 0.5, iterable:Bool = false) {
        this = new Map<Int,Int>();
    }

    public var size(get,never):Int;
    inline function get_size():Int {
        return Lambda.count(this);
    }

    public var iterableKeys(get,never):Array<Int>;
    inline function get_iterableKeys():Array<Int> {
        var keys = [];
        for (k in this.keys()) {
            keys.push(k);
        }
        return keys;
    }

    inline public function remove(key:Int):Int {
        return this.remove(key) ? 1 : 0;
    }

} //IntIntMap

#end
