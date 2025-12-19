package backend;

abstract AudioFilterBuffer(cxx.CArray<cxx.num.Float32>) {

    /**
     * Creates a new audio filter buffer wrapping a native C++ float pointer.
     * @param buffer Native pointer to float32 audio sample data
     */
    inline public function new(buffer:cxx.CArray<cxx.num.Float32>) {
        this = buffer;
    }

    /**
     * Updates the underlying buffer pointer.
     * Used when the audio system reallocates or switches buffers.
     * @param buffer New native pointer to float32 audio sample data
     */
    inline public function setBuffer(buffer:cxx.CArray<cxx.num.Float32>):Void {
        this = buffer;
    }

    /**
     * Array access operator for reading audio samples.
     * @param index Sample index in the buffer
     * @return Audio sample value at the given index
     */
    @:arrayAccess
    public inline function get(index:Int):cxx.num.Float32 {
        return this[index];
    }

    /**
     * Array access operator for writing audio samples.
     * @param index Sample index in the buffer
     * @param value Audio sample value to write
     * @return The written value
     */
    @:arrayAccess
    public inline function set(index:Int, value:cxx.num.Float32):cxx.num.Float32 {
        this[index] = value;
        return value;
    }

    /**
     * Allocates a new zero-initialized audio buffer of the specified length.
     * @param length Number of samples to allocate
     * @return New AudioFilterBuffer with zero-initialized samples
     */
    @:nativeFunctionCode("new float[{arg0}]()")
    public static function alloc(length:Int):AudioFilterBuffer {
        return cast null;
    }

    /**
     * Frees the memory allocated for this buffer.
     * Must be called when the buffer is no longer needed to prevent memory leaks.
     */
    @:nativeFunctionCode("delete[] {this}")
    public function destroy():Void {}

}