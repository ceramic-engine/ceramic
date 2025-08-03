package backend;

/**
 * Platform-specific audio filter buffer implementation for real-time audio processing.
 * 
 * This abstract type provides a unified interface for accessing audio sample data
 * across different platforms:
 * - C++ targets: Uses native pointer access for optimal performance
 * - JavaScript/Web targets: Uses Float32Array for Web Audio API compatibility
 * 
 * The buffer contains interleaved audio samples as 32-bit floating point values,
 * typically in the range [-1.0, 1.0]. Audio filters use these buffers to process
 * audio data in real-time, applying effects like low-pass, high-pass, or custom
 * DSP algorithms.
 * 
 * @see AudioFilter For the filter interface that processes these buffers
 * @see AudioFilterWorklet For Web Audio worklet implementations
 */
#if documentation

typedef AudioFilterBuffer = clay.buffers.Float32Array;

#elseif cpp
abstract AudioFilterBuffer(cpp.Pointer<cpp.Float32>) {

    /**
     * Creates a new audio filter buffer wrapping a native C++ float pointer.
     * @param buffer Native pointer to float32 audio sample data
     */
    inline public function new(buffer:cpp.Pointer<cpp.Float32>) {
        this = buffer;
    }

    /**
     * Updates the underlying buffer pointer.
     * Used when the audio system reallocates or switches buffers.
     * @param buffer New native pointer to float32 audio sample data
     */
    inline public function setBuffer(buffer:cpp.Pointer<cpp.Float32>):Void {
        this = buffer;
    }

    /**
     * Array access operator for reading audio samples.
     * @param index Sample index in the buffer
     * @return Audio sample value at the given index
     */
    @:arrayAccess
    public inline function get(index:Int):cpp.Float32 {
        return this[index];
    }

    /**
     * Array access operator for writing audio samples.
     * @param index Sample index in the buffer
     * @param value Audio sample value to write
     * @return The written value
     */
    @:arrayAccess
    public inline function set(index:Int, value:cpp.Float32):cpp.Float32 {
        this[index] = value;
        return value;
    }

}
#else
abstract AudioFilterBuffer(clay.buffers.Float32Array) {

    /**
     * Creates a new audio filter buffer wrapping a Float32Array.
     * @param buffer Float32Array containing audio sample data
     */
    inline public function new(buffer:clay.buffers.Float32Array) {
        this = buffer;
    }

    /**
     * Updates the underlying Float32Array.
     * Used when the audio system reallocates or switches buffers.
     * @param buffer New Float32Array containing audio sample data
     */
    inline public function setBuffer(buffer:clay.buffers.Float32Array):Void {
        this = buffer;
    }

    /**
     * Array access operator for reading audio samples.
     * @param index Sample index in the buffer
     * @return Audio sample value at the given index
     */
    @:arrayAccess
    public inline function get(index:Int):Float {
        return this[index];
    }

    /**
     * Array access operator for writing audio samples.
     * @param index Sample index in the buffer
     * @param value Audio sample value to write
     * @return The written value
     */
    @:arrayAccess
    public inline function set(index:Int, value:Float):Float {
        this[index] = value;
        return value;
    }

}
#end
