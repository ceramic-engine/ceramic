package unityengine;

/**
 * Represents an asynchronous resource loading operation.
 * Returned by Resources.LoadAsync() for non-blocking asset loading.
 * 
 * In Ceramic's Unity backend, ResourceRequests enable loading
 * assets without freezing the main thread, important for:
 * - Loading large textures or audio files
 * - Smooth loading screens
 * - Streaming content during gameplay
 * 
 * The loading happens over multiple frames, allowing the game
 * to remain responsive while assets load in the background.
 * 
 * @example Async texture loading:
 * ```haxe
 * var request = Resources.LoadAsync<Texture2D>("textures/large");
 * // Later, check if done:
 * if (request.isDone) {
 *     var texture = cast(request.asset, Texture2D);
 * }
 * ```
 * 
 * @see Resources
 * @see Object
 */
@:native('UnityEngine.ResourceRequest')
extern class ResourceRequest {

    /**
     * The loaded asset once loading is complete.
     * 
     * Null while loading (isDone = false).
     * Contains the loaded asset when isDone = true.
     * 
     * Must be cast to the expected type:
     * ```haxe
     * var texture = cast(request.asset, Texture2D);
     * var audio = cast(request.asset, AudioClip);
     * ```
     * 
     * Returns null if loading failed.
     */
    var asset(default,null):Object;

    /**
     * Whether to automatically activate a loaded scene.
     * 
     * Only applies when loading scenes asynchronously.
     * When false, scene loads to 90% then waits for manual activation.
     * 
     * Not used for regular asset loading (textures, audio, etc.).
     * Included for API compatibility.
     */
    var allowSceneActivation:Bool;

    /**
     * Whether the loading operation has completed.
     * 
     * Check this before accessing the asset property.
     * Once true, the asset is ready to use (or null if failed).
     * 
     * @example Polling for completion:
     * ```haxe
     * function update() {
     *     if (request.isDone) {
     *         // Asset is ready
     *         useAsset(request.asset);
     *     }
     * }
     * ```
     */
    var isDone(default,null):Bool;

    /**
     * Loading priority when multiple requests are queued.
     * 
     * Higher values = higher priority.
     * Default is 0.
     * 
     * Unity processes higher priority requests first
     * when multiple async loads are active.
     * 
     * Useful for prioritizing critical assets:
     * ```haxe
     * uiRequest.priority = 1;  // Load UI first
     * bgRequest.priority = -1; // Load background last
     * ```
     */
    var priority:Int;

    /**
     * Loading progress from 0.0 to 1.0.
     * 
     * Useful for displaying loading bars:
     * - 0.0 = Just started
     * - 0.5 = Halfway loaded  
     * - 1.0 = Fully loaded (isDone = true)
     * 
     * Note: Progress may not be linear and can jump.
     * For scenes, stops at 0.9 if allowSceneActivation = false.
     * 
     * @example Progress bar:
     * ```haxe
     * loadingBar.scaleX = request.progress;
     * ```
     */
    var progress(default,null):Single;

}
