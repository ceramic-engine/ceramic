package ceramic;

/**
 * Interface for objects that can report their loading progress.
 * 
 * Any class that implements this interface can be used with a `Preloader`
 * to track loading progress. The preloadable object is responsible for
 * calling the update callback whenever its loading state changes.
 * 
 * This is typically used for assets, scenes, or other resources that
 * need to be loaded before being ready for use.
 * 
 * Example usage:
 * ```haxe
 * class MyAsset implements Preloadable {
 *     var updatePreload:(Int, Int, PreloadStatus)->Void;
 *     
 *     public function requestPreloadUpdate(update) {
 *         this.updatePreload = update;
 *         // Start loading...
 *         updatePreload(0, 100, LOADING);
 *     }
 *     
 *     function onProgress(loaded:Int, total:Int) {
 *         updatePreload(loaded, total, LOADING);
 *     }
 *     
 *     function onComplete() {
 *         updatePreload(100, 100, SUCCESS);
 *     }
 * }
 * ```
 * 
 * @see Preloader
 * @see PreloadStatus
 */
interface Preloadable {

    /**
     * Called by the preloader to register an update callback.
     * 
     * The preloadable object must store the provided callback and call it
     * whenever its loading progress changes. The callback should be called
     * with the current progress, total expected progress, and status.
     * 
     * The preloadable is expected to:
     * - Call the update callback immediately with the current state
     * - Continue calling it whenever progress changes
     * - Call it with status SUCCESS when loading completes
     * - Call it with status FAILED if loading fails
     * 
     * @param updatePreload Callback function to report progress.
     *                      Parameters are:
     *                      - progress: Current progress value (0 to total)
     *                      - total: Total expected progress value
     *                      - status: Current loading status
     */
    function requestPreloadUpdate(updatePreload:(progress:Int, total:Int, status:PreloadStatus)->Void):Void;

}
