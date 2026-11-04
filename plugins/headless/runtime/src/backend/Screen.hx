package backend;

import haxe.io.Bytes;

#if !no_backend_docs
/**
 * Screen and window management implementation for the headless backend.
 * 
 * This class provides virtual screen functionality and input event handling
 * for the headless environment. Since there's no actual display or window
 * in headless mode, this provides mock implementations that maintain
 * API compatibility.
 * 
 * The screen dimensions are taken from the application's target settings,
 * and all visual operations are no-ops.
 */
#end
class Screen implements tracker.Events #if !completion implements spec.Screen #end {

    #if !no_backend_docs
    /**
     * Creates a new headless screen system.
     */
    #end
    public function new() {}

/// Events

    #if !no_backend_docs
    /**
     * Fired when the screen/window is resized.
     */
    #end
    @event function resize();

    #if !no_backend_docs
    /**
     * Fired when a mouse button is pressed down.
     * 
     * @param buttonId The mouse button ID (0=left, 1=right, 2=middle)
     * @param x X coordinate of the mouse cursor
     * @param y Y coordinate of the mouse cursor
     */
    #end
    @event function mouseDown(buttonId:Int, x:Float, y:Float);
    
    #if !no_backend_docs
    /**
     * Fired when a mouse button is released.
     * 
     * @param buttonId The mouse button ID (0=left, 1=right, 2=middle)
     * @param x X coordinate of the mouse cursor
     * @param y Y coordinate of the mouse cursor
     */
    #end
    @event function mouseUp(buttonId:Int, x:Float, y:Float);
    
    #if !no_backend_docs
    /**
     * Fired when the mouse wheel is scrolled.
     * 
     * @param x Horizontal scroll amount
     * @param y Vertical scroll amount
     */
    #end
    @event function mouseWheel(x:Float, y:Float);

    /**
     * Fired when the user scrolls, with the deltas as the device reports
     * them: logical pixels (`ceramic.ScrollUnit.PIXELS`, trackpads and smooth
     * scrolling) or lines (`LINES`, notched mouse wheels), positive when the
     * content should move up or left. Nothing is scaled or rounded.
     * @param deltaX Horizontal delta
     * @param deltaY Vertical delta
     * @param unit Unit of the deltas
     */
    @event function mouseScroll(deltaX:Float, deltaY:Float, unit:ceramic.ScrollUnit);
    
    #if !no_backend_docs
    /**
     * Fired when the mouse cursor is moved.
     * 
     * @param x New X coordinate of the mouse cursor
     * @param y New Y coordinate of the mouse cursor
     */
    #end
    @event function mouseMove(x:Float, y:Float);

    #if !no_backend_docs
    /**
     * Fired when a touch begins.
     * 
     * @param touchIndex The touch point index (for multi-touch)
     * @param x X coordinate of the touch
     * @param y Y coordinate of the touch
     */
    #end
    @event function touchDown(touchIndex:Int, x:Float, y:Float);
    
    #if !no_backend_docs
    /**
     * Fired when a touch ends.
     * 
     * @param touchIndex The touch point index (for multi-touch)
     * @param x X coordinate of the touch
     * @param y Y coordinate of the touch
     */
    #end
    @event function touchUp(touchIndex:Int, x:Float, y:Float);
    
    #if !no_backend_docs
    /**
     * Fired when a touch point moves.
     * 
     * @param touchIndex The touch point index (for multi-touch)
     * @param x New X coordinate of the touch
     * @param y New Y coordinate of the touch
     */
    #end
    @event function touchMove(touchIndex:Int, x:Float, y:Float);

    /**
     * Fired when the system takes over a touch (native gesture, touch
     * removed): no `touchUp` follows from the platform for that touch.
     * @param touchIndex Touch point index for multi-touch
     * @param x Touch X coordinate
     * @param y Touch Y coordinate
     */
    @event function touchCancel(touchIndex:Int, x:Float, y:Float);

    /**
     * Fired when the app window gains or loses the keyboard focus of the
     * system. Never fired by the headless backend: tests emit it to simulate focus changes.
     * @param focused Whether the window now has the focus
     */
    @event function windowFocusChange(focused:Bool);

    /**
     * Fired when an item of the menu bar is chosen. Never fired by the
     * headless backend: tests emit it to simulate a click in a native menu.
     * @param id The `id` of the item
     */
    @event function menuAction(id:Int);

    /**
     * Fired right after the key down of a keystroke matching the shortcut
     * of a menu bar item. Never fired by the headless backend: tests emit it
     * to simulate a native menu shortcut.
     * @param id The `id` of the item
     */
    @event function menuKeyEquivalent(id:Int);

    /**
     * Fired when a menu of the menu bar opens. Never fired by the headless
     * backend.
     */
    @event function menuWillOpen();

    /**
     * Fired when the light or dark appearance of the system changes. Never
     * fired by the headless backend: tests emit it to simulate a change (the
     * appearance then reads the emitted value).
     * @param appearance The new appearance
     */
    @event function systemAppearanceChange(appearance:ceramic.SystemAppearance);

    /**
     * Fired when the user's scrollbar preference changes. Never fired by the
     * headless backend: tests emit it to simulate a change.
     * @param autoHide Whether scrollbars should only show while scrolling
     */
    @event function autoHideScrollbarsChange(autoHide:Bool);

/// Public API

    #if !no_backend_docs
    /**
     * Gets the width of the virtual screen.
     * 
     * In headless mode, this returns the target width from application settings.
     * 
     * @return The screen width in pixels
     */
    #end
    inline public function getWidth():Int {

        return ceramic.App.app.settings.targetWidth;

    }

    #if !no_backend_docs
    /**
     * Gets the height of the virtual screen.
     * 
     * In headless mode, this returns the target height from application settings.
     * 
     * @return The screen height in pixels
     */
    #end
    inline public function getHeight():Int {

        return ceramic.App.app.settings.targetHeight;

    }

    #if !no_backend_docs
    /**
     * Gets the screen density (pixels per inch scale factor).
     * 
     * In headless mode, this always returns 1.0 (standard density).
     * 
     * @return The screen density multiplier
     */
    #end
    inline public function getDensity():Float {

        return 1.0;

    }

    #if !no_backend_docs
    /**
     * Sets the background color of the screen/window.
     * 
     * In headless mode, this is a no-op since there's no visual display.
     * 
     * @param background The background color as an integer (0xRRGGBB)
     */
    #end
    public function setBackground(background:Int):Void {

        //

    }

    #if !no_backend_docs
    /**
     * Sets the title of the window.
     * 
     * In headless mode, this is a no-op since there's no window.
     * 
     * @param title The window title text
     */
    #end
    public function setWindowTitle(title:String):Void {

        //

    }

    #if !no_backend_docs
    /**
     * Sets whether the window should be fullscreen.
     * 
     * In headless mode, this is a no-op since there's no window.
     * 
     * @param fullscreen Whether to enable fullscreen mode
     */
    #end
    public function setWindowFullscreen(fullscreen:Bool):Void {

        //

    }

    public function minimizeWindow():Void {}

    public function maximizeWindow():Void {}

    public function restoreWindow():Void {}

    public function isWindowMaximized():Bool {
        return false;
    }

    public function showWindowMenu(x:Float, y:Float):Void {}

    public function setWindowHitRegions(regions:Array<Float>):Void {}

    /** No window to activate: does nothing. */
    public function activateWindow():Void {}

    var windowFocused:Bool = true;

    /** True unless a test emitted `windowFocusChange(false)`. */
    public function isWindowFocused():Bool {
        return windowFocused;
    }

    function willEmitWindowFocusChange(focused:Bool):Void {
        windowFocused = focused;
    }

    /** The menus last installed (nothing is shown). */
    public var menuBar(default, null):Array<ceramic.MenuItem> = null;

    var menuItemEnabled:(id:Int)->Bool = null;

    /** No menu bar: keeps the menus for tests (`menuBar`, `isMenuItemEnabled`). */
    public function setMenuBar(menus:Array<ceramic.MenuItem>, isEnabled:(id:Int)->Bool):Void {
        menuBar = menus;
        menuItemEnabled = isEnabled;
    }

    /** What the system would ask to validate the item with the given id (menu bar or dock menu). */
    public function isMenuItemEnabled(id:Int):Bool {
        if (menuItemEnabled != null && menuItemEnabled(id)) return true;
        return dockMenuItemEnabled != null && dockMenuItemEnabled(id);
    }

    /** The dock menu last installed (nothing is shown). */
    public var dockMenu(default, null):Array<ceramic.MenuItem> = null;

    var dockMenuItemEnabled:(id:Int)->Bool = null;

    /** No dock: keeps the items for tests (`dockMenu`, `isMenuItemEnabled`). */
    public function setDockMenu(items:Array<ceramic.MenuItem>, isEnabled:(id:Int)->Bool):Void {
        dockMenu = items;
        dockMenuItemEnabled = isEnabled;
    }

    var systemAppearance:ceramic.SystemAppearance = LIGHT;

    /** `LIGHT` unless a test emitted `systemAppearanceChange` with another value. */
    public function getSystemAppearance():ceramic.SystemAppearance {
        return systemAppearance;
    }

    function willEmitSystemAppearanceChange(appearance:ceramic.SystemAppearance):Void {
        systemAppearance = appearance;
    }

    var autoHideScrollbars:Bool = false;

    /**
     * False (like GPUI's test platform) unless a test emitted
     * `autoHideScrollbarsChange(true)`.
     */
    public function getAutoHideScrollbars():Bool {
        return autoHideScrollbars;
    }

    function willEmitAutoHideScrollbarsChange(autoHide:Bool):Void {
        autoHideScrollbars = autoHide;
    }

    public function setCursorVisible(visible:Bool):Void {

        //

    }

    #if !no_backend_docs
    /**
     * Sets the mouse cursor shape. No-op in headless mode.
     * @param cursor The cursor shape
     */
    #end
    public function setCursor(cursor:ceramic.MouseCursor):Void {

        //

    }

    #if !no_backend_docs
    /**
     * Captures a screenshot and returns it as a texture.
     * 
     * In headless mode, this always returns null since there's no visual content to capture.
     * 
     * @param done Callback function called with the screenshot texture (always null)
     */
    #end
    public function screenshotToTexture(done:(texture:Texture)->Void):Void {

        done(null);

    }

    #if !no_backend_docs
    /**
     * Captures a screenshot and saves it as a PNG file or returns the PNG data.
     * 
     * In headless mode, this always returns null since there's no visual content to capture,
     * and no file is written at `path`. Ceramic's `screen.toPng()` still calls its callback,
     * after the next draw.
     * 
     * @param path Optional file path to save the PNG to (ignored)
     * @param done Callback function called with the PNG data (always null)
     */
    #end
    public function screenshotToPng(?path:String, done:(?data:Bytes)->Void):Void {

        done(null);

    }

    #if !no_backend_docs
    /**
     * Captures a screenshot and returns the raw pixel data.
     * 
     * In headless mode, this always returns null since there's no visual content to capture.
     * 
     * @param done Callback function called with pixel data, width, and height (always null, 0, 0)
     */
    #end
    public function screenshotToPixels(done:(pixels:ceramic.UInt8Array, width:Int, height:Int)->Void):Void {

        done(null, 0, 0);

    }

}
