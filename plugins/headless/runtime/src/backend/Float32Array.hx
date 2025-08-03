package backend;

/**
 * Float32Array implementation for the headless backend.
 * 
 * This provides a typed array for 32-bit floating point numbers.
 * In headless mode, this is implemented using a regular Haxe Array<Float>
 * with array access forwarding for compatibility.
 * 
 * Float32Arrays are commonly used for vertex data, audio buffers,
 * and other numerical computations where memory layout is important.
 */
typedef Float32Array = Float32ArrayImplHeadless;

/**
 * Implementation class for Float32Array in headless mode.
 * 
 * This wraps a standard Haxe Array<Float> and provides the same
 * interface as platform-specific typed array implementations.
 */
@:forward
abstract Float32ArrayImplHeadless(Array<Float>) from Array<Float> to Array<Float> {

    /**
     * Creates a new Float32Array with the specified size.
     * 
     * The array is initialized with zero values.
     * 
     * @param size Number of float elements to allocate
     */
    public function new(size:Int) {

        this = [];
        if (size > 0) {
            // Pre-allocate array by setting the last element
            this[size-1] = 0.0;
        }

    }

}
