package backend;

/**
 * Float32Array implementation for the web audio worklets context.
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
abstract Float32Array(js.lib.Float32Array)
    from js.lib.Float32Array
    to js.lib.Float32Array {

    public static inline var BYTES_PER_ELEMENT:Int = 4;

    inline public function new(elements:Int) {
        this = new js.lib.Float32Array(elements);
    }

    @:arrayAccess extern inline function __get(index:Int):Float {
        return this[index];
    }

    @:arrayAccess extern inline function __set(index:Int, value:Float):Void {
        this[index] = value;
    }

    /**
     * Creates a buffer holding a copy of the given array.
     */
    public static inline function fromArray(array:Array<Float>):Float32Array {
        return new js.lib.Float32Array(untyped array);
    }

}
