package backend;

/**
 * Configuration options for loading texture/image resources in the Clay backend.
 * 
 * These options control how images are loaded and processed, including
 * alpha channel handling which is important for correct rendering.
 */
typedef LoadTextureOptions = {

    /**
     * The loading method to use for this texture resource.
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
     * Whether to premultiply the alpha channel with RGB values.
     * 
     * - true: Premultiply alpha (required for correct blending in most cases)
     * - false: Keep straight alpha (raw image data)
     * 
     * Most rendering pipelines expect premultiplied alpha for proper
     * transparency blending. Default is typically true.
     */
    @:optional var premultiplyAlpha:Bool;

}
