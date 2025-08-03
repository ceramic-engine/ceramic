package backend;

/**
 * ArrayBuffer type definition for the headless backend.
 * 
 * This provides a generic ArrayBuffer implementation that works
 * across different platforms. In headless mode, this is simply
 * aliased to Dynamic to provide maximum flexibility.
 * 
 * ArrayBuffers are used for binary data manipulation and are
 * typically the backing store for typed arrays like Float32Array
 * and UInt8Array.
 */
typedef ArrayBuffer = Dynamic;
