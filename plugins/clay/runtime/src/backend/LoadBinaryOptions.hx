package backend;

/**
 * Configuration options for loading binary data in the Clay backend.
 * 
 * These options control how binary files are loaded, allowing
 * developers to choose between synchronous and asynchronous loading
 * based on their needs.
 */
typedef LoadBinaryOptions = {

    /**
     * The loading method to use for this binary resource.
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

}
