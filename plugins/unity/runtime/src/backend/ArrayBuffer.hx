package backend;

#if !no_backend_docs
/**
 * Type alias for array buffer data in the Unity backend.
 * 
 * In the Unity backend, array buffers are represented as Dynamic
 * to allow flexible data handling between Haxe and Unity's C# layer.
 * This typically wraps Unity's byte arrays or similar binary data structures.
 * 
 * Used for:
 * - Raw binary data from files
 * - Audio buffer data
 * - Texture pixel data
 * - Network payload data
 * 
 * @see backend.Binaries For loading binary files
 * @see backend.AudioFilterBuffer For audio processing buffers
 */
#end
typedef ArrayBuffer = Dynamic;
