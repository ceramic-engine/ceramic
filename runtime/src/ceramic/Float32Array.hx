package ceramic;

/**
 * A typed array of 32-bit floating point values.
 * 
 * Float32Array provides a view of an array-like buffer of 32-bit floating point numbers,
 * offering improved performance over regular Arrays when working with large amounts of
 * numeric data, particularly in graphics and audio processing contexts.
 * 
 * This is a cross-platform abstraction that maps to native implementations:
 * - On web targets: Maps to JavaScript's native Float32Array
 * - On native targets (Clay): Uses optimized buffer implementations
 * - On headless targets: Falls back to a standard Array<Float>
 * 
 * Float32Arrays are commonly used in Ceramic for:
 * - Mesh vertex data and attributes
 * - Audio sample buffers
 * - Shader uniform arrays
 * - Performance-critical numeric computations
 * 
 * Example:
 * ```haxe
 * // Create a Float32Array with 100 elements
 * var buffer = new Float32Array(100);
 * 
 * // Set values
 * buffer[0] = 1.5;
 * buffer[1] = 2.7;
 * 
 * // Iterate through values
 * for (i in 0...buffer.length) {
 *     trace(buffer[i]);
 * }
 * ```
 * 
 * @see UInt8Array For 8-bit unsigned integer arrays
 * @see ceramic.Mesh For usage in vertex data
 * @see ceramic.AudioFilterBuffer For usage in audio processing
 */
typedef Float32Array = backend.Float32Array;
