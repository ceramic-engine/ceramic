package backend;

/**
 * Type alias for Clay's Float32Array implementation.
 * 
 * Float32Array provides a typed array of 32-bit floating point values,
 * commonly used for:
 * - WebGL vertex data (positions, colors, texture coordinates)
 * - Audio sample data processing
 * - High-performance numeric computations
 * - Matrix and vector math operations
 * 
 * This maps to the platform-specific implementation:
 * - JavaScript/Web: Native Float32Array
 * - C++: Custom buffer implementation with float pointer access
 * 
 * The array provides direct memory access for optimal performance
 * when interfacing with graphics APIs and audio systems.
 * 
 * @see ceramic.Float32Array For the high-level cross-platform interface
 * @see UInt8Array For byte-level data access
 */
typedef Float32Array = clay.buffers.Float32Array;
