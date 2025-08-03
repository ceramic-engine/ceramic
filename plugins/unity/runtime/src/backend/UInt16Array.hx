package backend;

import cs.types.UInt16;

#if !no_backend_docs
/**
 * Type alias for Unity's native 16-bit unsigned integer array.
 * Used for index buffers in rendering operations.
 * Maps directly to C# UInt16[] for efficient GPU data transfer.
 */
#end
typedef UInt16Array = cs.NativeArray<UInt16>;
