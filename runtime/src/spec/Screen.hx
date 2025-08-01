package spec;

import backend.Texture;
import haxe.io.Bytes;

/**
 * Backend interface for screen and window management.
 * 
 * This interface provides access to display properties, window control,
 * and screenshot functionality. It handles platform-specific window
 * management while providing a unified API.
 * 
 * The screen coordinates and dimensions are in logical pixels, which
 * may differ from physical pixels on high-DPI displays. Use getDensity()
 * to convert between logical and physical pixels.
 * 
 * Note: This interface also dispatches input events to the App, though
 * those methods are implemented internally by each backend.
 */
interface Screen {

    /**
     * Gets the current screen width in logical pixels.
     * This is the drawable area available to the application.
     * @return The screen width in logical pixels
     */
    function getWidth():Int;

    /**
     * Gets the current screen height in logical pixels.
     * This is the drawable area available to the application.
     * @return The screen height in logical pixels
     */
    function getHeight():Int;

    /**
     * Gets the screen density (device pixel ratio).
     * This is the ratio between physical pixels and logical pixels.
     * 
     * Examples:
     * - 1.0 on standard displays
     * - 2.0 on Retina/HiDPI displays
     * - Various values on mobile devices
     * 
     * @return The screen density multiplier
     */
    function getDensity():Float;

    /**
     * Sets the background color for the screen.
     * This color is shown when the screen is cleared and in areas
     * not covered by rendered content.
     * 
     * @param background The background color as a 32-bit ARGB integer (0xAARRGGBB)
     */
    function setBackground(background:Int):Void;

    /**
     * Sets the window title (desktop platforms only).
     * On mobile and web platforms, this may have no effect.
     * 
     * @param title The new window title text
     */
    function setWindowTitle(title:String):Void;

    /**
     * Sets the window fullscreen state.
     * 
     * Behavior varies by platform:
     * - Desktop: Toggles between windowed and fullscreen modes
     * - Mobile: May have no effect (always fullscreen)
     * - Web: May require user interaction due to browser security
     * 
     * @param fullscreen True to enter fullscreen, false to exit
     */
    function setWindowFullscreen(fullscreen:Bool):Void;

    /**
     * Captures the current screen content as a texture.
     * This is useful for post-processing effects or transitions.
     * 
     * @param done Callback invoked with the captured texture, or null on failure
     */
    function screenshotToTexture(done:(texture:Texture)->Void):Void;

    /**
     * Captures the current screen content as a PNG image.
     * 
     * @param path Optional file path to save the PNG (null to return data only)
     * @param done Callback invoked with the PNG data as bytes, or null on failure
     */
    function screenshotToPng(?path:String, done:(?data:Bytes)->Void):Void;

    /**
     * Captures the current screen content as raw pixel data.
     * Pixels are returned as RGBA bytes (4 bytes per pixel) in row-major order.
     * 
     * @param done Callback invoked with pixel data, width, and height
     */
    function screenshotToPixels(done:(pixels:ceramic.UInt8Array, width:Int, height:Int)->Void):Void;

}
