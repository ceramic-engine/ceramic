package unityengine;

/**
 * Unity Application class extern binding for Ceramic.
 * Provides access to Unity application runtime data and settings.
 * 
 * This is a minimal binding that only includes the properties
 * needed by the Ceramic Unity backend.
 */
@:native('UnityEngine.Application')
extern class Application {

    /**
     * The absolute URL to the web player data folder.
     * For web builds, this returns the URL of the folder containing the build data.
     * Read-only property.
     */
    static var absoluteURL(default, null):String;

    /**
     * Instructs the game to try to render at a specific frame rate.
     * Set to -1 to render as fast as possible (default).
     * Set to a positive value like 60 or 30 to cap the frame rate.
     * 
     * Note: The actual frame rate may be lower if the hardware
     * cannot achieve the target rate.
     */
    static var targetFrameRate:Int;

}
