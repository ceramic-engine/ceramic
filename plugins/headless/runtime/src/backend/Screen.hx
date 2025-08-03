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
     * In headless mode, this always returns null since there's no visual content to capture.
     * 
     * @param path Optional file path to save the PNG to
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
