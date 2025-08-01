package ceramic;

import ceramic.macros.EnumAbstractMacro;

/**
 * Defines how assets should be loaded by the system.
 * 
 * This affects both the loading behavior and how the application
 * responds during asset loading.
 * 
 * @see Assets.loadMethod
 */
enum abstract AssetsLoadMethod(Int) {

    /**
     * Ensure asset loading is non-blocking, at least between each asset.
     * 
     * Benefits:
     * - Allows screen updates and animations during loading
     * - Prevents UI freezing on large asset loads
     * - Better user experience with loading indicators
     * 
     * Backends may adapt their loading strategy based on this setting.
     */
    var ASYNC = 1;

    /**
     * Try to load assets synchronously (if supported by the backend).
     * 
     * When possible, `assets.load()` will block until loading completes
     * and trigger the `complete` event synchronously.
     * 
     * Benefits:
     * - Simpler code flow
     * - Immediate asset availability after load()
     * - Good for loading screens or initial setup
     * 
     * Note: Not all backends support true synchronous loading.
     */
    var SYNC = 2;

    function toString() {
        return EnumAbstractMacro.toStringSwitch(AssetsLoadMethod, abstract);
    }

}
