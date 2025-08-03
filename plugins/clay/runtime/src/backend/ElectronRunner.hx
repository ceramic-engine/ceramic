package backend;

/**
 * Static holder for the Electron runner instance used in web builds.
 * 
 * When running Ceramic applications in Electron (desktop web runtime),
 * this class provides access to the Electron runner object which handles:
 * - Window management
 * - Native menu integration
 * - File system access
 * - System dialog boxes
 * - Inter-process communication
 * 
 * The electronRunner object is typically injected by the Electron main
 * process when initializing the Ceramic application. It remains null
 * when running in a regular web browser.
 * 
 * @see ceramic.Platform.resolveElectron() For safe Electron detection
 */
class ElectronRunner {

    /**
     * Reference to the Electron runner object.
     * This is set by the Electron environment at startup and provides
     * access to Electron-specific APIs that aren't available in browsers.
     * 
     * Value is null when:
     * - Running in a web browser
     * - Running on non-web platforms (native desktop/mobile)
     * - Electron is not available or not initialized
     */
    public static var electronRunner:Dynamic;

}