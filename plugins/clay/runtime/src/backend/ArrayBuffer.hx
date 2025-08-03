package backend;

/**
 * Type alias for JavaScript ArrayBuffer in the Clay backend.
 * 
 * This represents a fixed-length raw binary data buffer, commonly used
 * for efficient storage and manipulation of binary data. In the Clay
 * backend, this is mapped to the native JavaScript ArrayBuffer type.
 * 
 * ArrayBuffers are used internally for:
 * - Audio data storage and processing
 * - Image pixel data manipulation
 * - Binary file content storage
 * - WebGL vertex/index buffer data
 * 
 * @see Float32Array For typed array views over ArrayBuffer
 * @see UInt8Array For byte-level access to ArrayBuffer data
 */
typedef ArrayBuffer = Dynamic;
