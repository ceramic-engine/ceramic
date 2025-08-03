package backend;

#if !no_backend_docs
/**
 * External interface to Unity's native CeramicCommandBufferPool C# class.
 * 
 * Manages a pool of reusable command buffers to avoid the overhead of
 * creating and destroying them frequently. This is a critical optimization
 * for high-performance rendering, as command buffer allocation can be
 * expensive in Unity.
 * 
 * The pooling pattern ensures that:
 * - Command buffers are reused across frames
 * - Memory allocation is minimized
 * - GC pressure is reduced
 * - Performance remains consistent
 * 
 * Usage pattern:
 * 1. Get() a buffer from the pool
 * 2. Clear() and fill it with commands
 * 3. Execute the buffer
 * 4. Release() it back to the pool
 * 
 * The C# implementation maintains a stack of available buffers and
 * creates new ones only when the pool is exhausted.
 * 
 * @see CeramicCommandBuffer The command buffer type being pooled
 * @see backend.Draw Primary consumer of pooled command buffers
 */
#end
@:native('CeramicCommandBufferPool')
extern class CeramicCommandBufferPool {

    #if !no_backend_docs
    /**
     * Gets a command buffer from the pool.
     * If the pool is empty, a new buffer is created.
     * The returned buffer may contain commands from previous usage,
     * so Clear() should be called before use.
     * 
     * @return A reusable command buffer instance
     */
    #end
    static function Get():CeramicCommandBuffer;

    #if !no_backend_docs
    /**
     * Returns a command buffer to the pool for reuse.
     * The buffer is not cleared automatically to avoid unnecessary
     * overhead if it will be cleared anyway on next use.
     * 
     * @param cmd The command buffer to return to the pool
     */
    #end
    static function Release(cmd:CeramicCommandBuffer):Void;

}
