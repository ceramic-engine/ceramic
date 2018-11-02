package ceramic;

import haxe.ds.Vector;
import ceramic.Assert.assert;

/** Port of https://github.com/mikvor/hashmapTest/blob/55669a0c3ee1f9c2525580e4ace06e910d5972ec/src/main/java/map/intint/IntIntMap4a.java to haxe */
class IntIntMap {

    static inline var INT_PHI = 0x9E3779B9;

    static inline var FREE_KEY = 0;

    public static inline var NO_VALUE = 0;

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
    var size:Int;

    /** Mask to calculate the original position */
    var mask:Int;
    /** Mask to calculate the original position */
    var mask2:Int;

    public function new(size:Int, fillFactor:Float) {

        assert(fillFactor > 0 || fillFactor < 1, "fillFactor must be in 0 (excluded) and 1 (excluded)");
        assert(size > 0, "size must be positive");

        var capacity = arraySize(size, fillFactor);
        mask = capacity - 1;
        mask2 = capacity * 2 - 1;
        this.fillFactor = fillFactor;

        data = new Vector(capacity * 2);
        threshold = Std.int(capacity * fillFactor);

    } //new

    public function get(key:Int) {

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
            result = x;
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
