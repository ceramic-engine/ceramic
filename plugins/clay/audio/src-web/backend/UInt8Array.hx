package backend;

/**
 * UInt8Array implementation for the web audio worklets context.
 *
 * A thin abstract over the native JS type, generating no code at all — the
 * same shape as the clay implementation, kept deliberately minimal so that
 * nothing else from clay ends up in the audio worklet scope.
 *
 * Kept API-compatible with the clay implementation, since the same worklet
 * code is also compiled against it.
 */
@:forward
@:arrayAccess
abstract UInt8Array(js.lib.Uint8Array)
    from js.lib.Uint8Array
    to js.lib.Uint8Array {

    public static inline var BYTES_PER_ELEMENT:Int = 1;

    inline public function new(elements:Int) {
        this = new js.lib.Uint8Array(elements);
    }

    @:arrayAccess extern inline function __get(index:Int):Int {
        return this[index];
    }

    @:arrayAccess extern inline function __set(index:Int, value:Int):Void {
        this[index] = value;
    }

    /**
     * Creates a buffer holding a copy of the given array.
     */
    public static inline function fromArray(array:Array<Int>):UInt8Array {
        return new js.lib.Uint8Array(untyped array);
    }

}
