package backend;

#if !no_backend_docs
/**
 * External interface to Unity's native CeramicCommandBuffer C# class.
 * 
 * This is a lightweight wrapper around Unity's CommandBuffer system,
 * specifically tailored for Ceramic's rendering needs. Command buffers
 * allow queuing of rendering commands that Unity executes efficiently
 * in a single batch.
 * 
 * The actual implementation is in C# code that extends Unity's CommandBuffer
 * with Ceramic-specific optimizations for 2D rendering, such as:
 * - Efficient mesh batching
 * - Texture atlas support
 * - Custom shader property management
 * - Render state caching
 * 
 * @see CeramicCommandBufferPool Manages pooling of these buffers
 * @see backend.Draw Uses command buffers for rendering
 * @see Unity's CommandBuffer documentation for underlying functionality
 */
#end
@:native('CeramicCommandBuffer')
extern class CeramicCommandBuffer {

    #if !no_backend_docs
    /**
     * Clears all commands from this command buffer.
     * Should be called before reusing a pooled buffer to ensure
     * no commands from previous usage remain.
     */
    #end
    function Clear():Void;

}
