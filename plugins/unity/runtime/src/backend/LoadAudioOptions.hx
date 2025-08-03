package backend;

#if !no_backend_docs
/**
 * Options for loading audio files in the Unity backend.
 * 
 * These options control how audio resources are loaded from disk
 * and prepared for playback. The settings can affect memory usage,
 * loading performance, and playback characteristics.
 * 
 * @see backend.Audio.load() Uses these options when loading audio
 */
#end
typedef LoadAudioOptions = {

    #if !no_backend_docs
    /**
     * Optional callback queue for deferred execution.
     * If provided, the load completion callback will be queued
     * on this Immediate instance rather than called directly.
     */
    #end
    @:optional var immediate:ceramic.Immediate;

    #if !no_backend_docs
    /**
     * The loading method to use (SYNC or ASYNC).
     * - SYNC: Blocks until the audio is fully loaded
     * - ASYNC: Loads in the background and calls callback when ready
     * 
     * Note: Unity backend currently loads synchronously regardless
     * of this setting, but respects the callback timing.
     */
    #end
    @:optional var loadMethod:ceramic.AssetsLoadMethod;

    #if !no_backend_docs
    /**
     * Whether to stream the audio from disk during playback.
     * - true: Audio is streamed, reducing memory usage but requiring disk access
     * - false: Audio is fully loaded into memory for faster playback
     * 
     * Streaming is recommended for long music tracks but not for
     * frequently-played short sound effects.
     */
    #end
    @:optional var stream:Bool;

}
