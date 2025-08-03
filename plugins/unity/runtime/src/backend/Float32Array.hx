package backend;

#if !no_backend_docs
/**
 * Type alias for Unity's native float array.
 * 
 * Maps to C#'s NativeArray<float> (Single precision) for efficient
 * interop with Unity's native code and GPU operations. This type
 * is used throughout the backend for vertex data, audio samples,
 * and other performance-critical float arrays.
 * 
 * Native arrays provide:
 * - Direct memory access without managed overhead
 * - Zero-copy passing to Unity APIs
 * - Efficient GPU buffer uploads
 * - Predictable memory layout for native interop
 * 
 * @see ceramic.Float32Array The cross-platform abstraction
 * @see backend.Draw Uses for vertex buffer data
 * @see backend.Audio Uses for audio sample buffers
 */
#end
typedef Float32Array = cs.NativeArray<Single>;
