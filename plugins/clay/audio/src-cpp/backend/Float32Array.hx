package backend;

import haxe.ds.Vector;

/**
 * Float32Array implementation for the standalone audio worklets context.
 *
 * Backed by a `haxe.ds.Vector`: a fixed-size contiguous buffer, allocated
 * once, with a raw `float*` available for interop — no dynamic growth and
 * no per-access bounds check on the audio path.
 *
 * Kept API-compatible with the clay implementation, since the same worklet
 * code is also compiled against it.
 */
abstract Float32Array(Vector<cxx.num.Float32>) {

    public static inline var BYTES_PER_ELEMENT:Int = 4;

    public var length(get,never):Int;

    inline function get_length():Int {
        return this.length;
    }

    inline public function new(elements:Int) {
        this = new Vector<cxx.num.Float32>(elements);
    }

    @:arrayAccess
    public inline function get(index:Int):cxx.num.Float32 {
        return this[index];
    }

    @:arrayAccess
    public inline function set(index:Int, value:cxx.num.Float32):cxx.num.Float32 {
        this[index] = value;
        return value;
    }

    /**
     * Sets every element to the given value.
     */
    public inline function fill(value:cxx.num.Float32):Void {
        this.fill(value);
    }

    /**
     * Creates a buffer holding a copy of the given array.
     */
    public static inline function fromArray(array:Array<Float>):Float32Array {
        final result = new Float32Array(array.length);
        for (i in 0...array.length) {
            result.set(i, array[i]);
        }
        return result;
    }

    /**
     * The underlying contiguous storage, to pass to C or C++ code.
     */
    public inline function data():cxx.Ptr<cxx.num.Float32> {
        return this.toData().data();
    }

}
