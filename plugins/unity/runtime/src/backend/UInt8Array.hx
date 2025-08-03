package backend;

import cs.types.UInt8;

#if !no_backend_docs
/**
 * Type alias for Unity's native 8-bit unsigned integer array.
 * Used for pixel data and binary file operations.
 * Maps directly to C# byte[] for efficient memory operations.
 */
#end
typedef UInt8Array = cs.NativeArray<UInt8>;
