package backend;

import haxe.ds.Vector;

/**
 * UInt8Array implementation for the standalone audio worklets context.
 *
 * Backed by a `haxe.ds.Vector`: a fixed-size contiguous buffer, allocated
 * once, with a raw `unsigned char*` available for interop — no dynamic growth and
 * no per-access bounds check on the audio path.
 *
 * Kept API-compatible with the clay implementation, since the same worklet
 * code is also compiled against it.
 */
abstract UInt8Array(Vector<cxx.num.UInt8>) {

    public static inline var BYTES_PER_ELEMENT:Int = 1;

    public var length(get,never):Int;

    inline function get_length():Int {
        return this.length;
    }

    inline public function new(elements:Int) {
        this = new Vector<cxx.num.UInt8>(elements);
    }

    @:arrayAccess
    public inline function get(index:Int):cxx.num.UInt8 {
        return this[index];
    }

    @:arrayAccess
    public inline function set(index:Int, value:cxx.num.UInt8):cxx.num.UInt8 {
        this[index] = value;
        return value;
    }

    /**
     * Sets every element to the given value.
     */
    public inline function fill(value:cxx.num.UInt8):Void {
        this.fill(value);
    }

    /**
     * Creates a buffer holding a copy of the given array.
     */
    public static inline function fromArray(array:Array<Int>):UInt8Array {
        final result = new UInt8Array(array.length);
        for (i in 0...array.length) {
            result.set(i, array[i]);
        }
        return result;
    }

    /**
     * The underlying contiguous storage, to pass to C or C++ code.
     */
    public inline function data():cxx.Ptr<cxx.num.UInt8> {
        return this.toData().data();
    }

}
