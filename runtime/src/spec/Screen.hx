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
     * Minimizes the window (does nothing where windows cannot be minimized:
     * web, mobile, headless).
     */
    function minimizeWindow():Void;

    /**
     * Maximizes the window (does nothing where windows cannot be maximized).
     */
    function maximizeWindow():Void;

    /**
     * Restores a minimized or maximized window to its normal size.
     */
    function restoreWindow():Void;

    /**
     * Whether the window is maximized (always false where windows cannot be
     * maximized).
     */
    function isWindowMaximized():Bool;

    /**
     * Opens the system menu of the window at the given position, in native
     * window coordinates (points), where the platform has one.
     */
    function showWindowMenu(x:Float, y:Float):Void;

    /**
     * Sets the regions of the window that move or resize it when the pointer
     * drags them, for windows that draw their own title bar and borders: a
     * flat list of `x, y, width, height, kind` in native window coordinates
     * (points), the last matching region wins (`kind` is a
     * `ceramic.WindowHitKind`). An empty list removes them. Does nothing
     * where the platform has no such regions (web, mobile, headless).
     */
    function setWindowHitRegions(regions:Array<Float>):Void;

    /**
     * Brings the app window to the front and gives it the keyboard focus,
     * activating the app on desktop platforms. Does nothing where an app
     * cannot activate its window (web, mobile, headless, hidden windows).
     */
    function activateWindow():Void;

    /**
     * Whether the app window has the keyboard focus of the system (true where
     * the platform does not tell). Backends emit `windowFocusChange` when it
     * changes.
     */
    function isWindowFocused():Bool;

    /**
     * Installs the application menu bar (macOS native builds), replacing the
     * current one. Every item has its `id` set. Backends emit `menuAction(id)`
     * when an item is chosen, `menuKeyEquivalent(id)` right after the key
     * down of a keystroke that matches the shortcut of an item (the app sees
     * the key first and decides whether the item runs), and `menuWillOpen()`
     * when a menu opens. `isEnabled(id)` is asked when the system validates
     * an item. Does nothing where the platform has no menu bar for the app
     * (web, Windows and Linux windows, mobile, headless, Unity).
     */
    function setMenuBar(menus:Array<ceramic.MenuItem>, isEnabled:(id:Int)->Bool):Void;

    /**
     * Shows or hides the mouse cursor while it is over the app.
     * Has no effect on platforms without a mouse cursor.
     * 
     * @param visible True to show the cursor, false to hide it
     */
    function setCursorVisible(visible:Bool):Void;

    /**
     * Sets the shape of the mouse cursor while it is over the app.
     * Backends without a matching shape use the closest one, or do nothing.
     * Hiding the cursor with `setCursorVisible(false)` takes precedence.
     *
     * @param cursor The cursor shape
     */
    function setCursor(cursor:ceramic.MouseCursor):Void;

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
