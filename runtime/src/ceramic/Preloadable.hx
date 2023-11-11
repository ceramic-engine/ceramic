package ceramic;

/**
 * Any class that implements this interface
 * can be used with a `Preloader`
 */
interface Preloadable {

    /**
     * Called by the **preloader** so that the **preloadable** can update the preload with its latest information.
     * This `Preloadable` instance is expected to call the provided `update()` method everytime `updatePreload()` is called.
     * @param update The update() method to call
     */
    function requestPreloadUpdate(updatePreload:(progress:Int, total:Int, status:PreloadStatus)->Void):Void;

}
