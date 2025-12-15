package backend;

/**
 * Configuration options for loading shader files in the Clay backend.
 *
 * These options control how shader files are loaded, supporting both
 * synchronous and asynchronous loading patterns for different use cases.
 */
typedef LoadShaderOptions = {

    /**
     * The loading method to use for this shader resource.
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
