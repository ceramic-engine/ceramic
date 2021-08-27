package ceramic;

enum abstract AssetsLoadMethod(Int) {

    /**
     * Ensure asset loading is non blocking, at least between each asset.
     * This is useful when we need to update screen during asset loading.
     * Backends may adapt how they load assets from this setting as well
     */
    var ASYNC = 1;

    /**
     * Try to load assets synchronously (if supported on the current backend).
     * This means calling `assets.load()` will trigger `complete` event synchronously if possible.
     */
    var SYNC = 2;

}
