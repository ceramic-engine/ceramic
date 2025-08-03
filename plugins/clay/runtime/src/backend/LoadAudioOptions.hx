package backend;

/**
 * Configuration options for loading audio resources in the Clay backend.
 * 
 * These options control how audio files are loaded and processed,
 * allowing fine-tuning of loading behavior based on the audio's
 * intended use (background music vs sound effects, etc.).
 */
typedef LoadAudioOptions = {

    /**
     * The loading method to use for this audio resource.
     * 
     * - ASYNC: Load in background (default)
     * - SYNC: Block until loaded
     * 
     * @see ceramic.AssetsLoadMethod
     */
    @:optional var loadMethod:ceramic.AssetsLoadMethod;

    /**
     * Optional immediate callback queue for batch processing.
     * 
     * When provided, callbacks are queued for batch execution
     * rather than being called immediately, improving performance
     * when loading multiple assets.
     */
    @:optional var immediate:ceramic.Immediate;

    /**
     * Whether to stream the audio instead of loading it entirely into memory.
     * 
     * - true: Stream from disk/network (good for music, saves memory)
     * - false: Load entirely into memory (good for short sound effects)
     * 
     * Note: Streaming support depends on the platform and audio format.
     */
    @:optional var stream:Bool;

}
