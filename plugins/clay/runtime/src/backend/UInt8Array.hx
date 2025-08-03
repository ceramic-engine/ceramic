package backend;

/**
 * Type alias for Clay's UInt8Array implementation.
 * 
 * UInt8Array provides a typed array of 8-bit unsigned integers (bytes),
 * commonly used for:
 * - Raw binary data manipulation
 * - Image pixel data (RGBA channels)
 * - File I/O operations
 * - Network packet construction
 * - Audio data in 8-bit formats
 * 
 * This maps to the platform-specific implementation:
 * - JavaScript/Web: Native Uint8Array
 * - C++: Custom buffer implementation with byte pointer access
 * 
 * The array provides efficient byte-level access to binary data
 * and is essential for low-level data operations.
 * 
 * @see ceramic.UInt8Array For the high-level cross-platform interface
 * @see Float32Array For floating-point data arrays
 */
typedef UInt8Array = clay.buffers.Uint8Array;
