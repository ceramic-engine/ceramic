package ceramic;

#if (cpp && windows)
@:headerCode('
// Needed otherwise windows build fails :(
// But why?
#undef ERROR
')
#end
/**
 * Status values for preloadable resources.
 * 
 * Used to track the loading state of resources that implement
 * the Preloadable interface. The preloader uses these status
 * values to determine when loading is complete or has failed.
 * 
 * @see Preloadable
 * @see Preloader
 */
enum abstract PreloadStatus(Int) {

    /**
     * No loading status set yet.
     * This is the initial state before loading begins.
     */
    var NONE = 0;

    /**
     * Currently loading.
     * The resource is in the process of being loaded.
     */
    var LOADING = 1;

    /**
     * Loading completed successfully.
     * The resource has been fully loaded and is ready to use.
     */
    var SUCCESS = 2;

    /**
     * Loading failed with an error.
     * The resource could not be loaded due to an error.
     */
    var ERROR = -1;

    /**
     * Convert this status to a string representation.
     * @return The name of the status (e.g., "NONE", "LOADING", "SUCCESS", "ERROR")
     */
    function toString():String {

        return ceramic.macros.EnumAbstractMacro.toStringSwitch(PreloadStatus, abstract);

    }

}
