package backend;

import ceramic.Files;
import ceramic.Point;
import ceramic.Utils;
import clay.Clay;
import haxe.io.Bytes;

#if clay_sdl
import clay.sdl.SDL;
#end

/**
 * Clay backend screen and window management implementation.
 * 
 * This class handles screen-related operations including:
 * - Window dimensions and display properties
 * - Window title and fullscreen state management
 * - Screenshot capture functionality (texture, PNG, raw pixels)
 * - Mouse and touch input event handling
 * - Audio context resumption on web platforms
 * 
 * Platform-specific features:
 * - Web: HTML5 Canvas and Electron integration for fullscreen
 * - Desktop (SDL): Direct OpenGL framebuffer reading for screenshots
 * - Mobile: Touch input event handling and audio context management
 */
#if clay_sdl
@:cppFileCode('#include <SDL3/SDL.h>')
#end
class Screen implements tracker.Events #if !completion implements spec.Screen #end {

    /**
     * Creates a new Screen backend instance.
     */
    public function new() {}

/// Events

    /**
     * Fired when the screen/window is resized.
     */
    @event function resize();

    /**
     * Fired when a mouse button is pressed down.
     * @param buttonId Mouse button ID (0=left, 1=middle, 2=right)
     * @param x Mouse X coordinate
     * @param y Mouse Y coordinate
     */
    @event function mouseDown(buttonId:Int, x:Float, y:Float);
    
    /**
     * Fired when a mouse button is released.
     * @param buttonId Mouse button ID (0=left, 1=middle, 2=right)
     * @param x Mouse X coordinate
     * @param y Mouse Y coordinate
     */
    @event function mouseUp(buttonId:Int, x:Float, y:Float);
    
    /**
     * Fired when the mouse wheel is scrolled.
     * @param x Horizontal scroll amount
     * @param y Vertical scroll amount
     */
    @event function mouseWheel(x:Float, y:Float);
    
    /**
     * Fired when the mouse cursor moves.
     * @param x Mouse X coordinate
     * @param y Mouse Y coordinate
     */
    @event function mouseMove(x:Float, y:Float);

    /**
     * Fired when a touch begins on the screen.
     * @param touchIndex Touch point index for multi-touch
     * @param x Touch X coordinate
     * @param y Touch Y coordinate
     */
    @event function touchDown(touchIndex:Int, x:Float, y:Float);
    
    /**
     * Fired when a touch ends.
     * @param touchIndex Touch point index for multi-touch
     * @param x Touch X coordinate
     * @param y Touch Y coordinate
     */
    @event function touchUp(touchIndex:Int, x:Float, y:Float);
    
    /**
     * Fired when a touch point moves.
     * @param touchIndex Touch point index for multi-touch
     * @param x Touch X coordinate
     * @param y Touch Y coordinate
     */
    @event function touchMove(touchIndex:Int, x:Float, y:Float);

#if (web && !no_resume_audio_context)

/// Resume audio context after first click/touch on web

    var didTryResumeAudioContext:Bool = false;

    inline function willEmitMouseDown(buttonId:Int, x:Float, y:Float):Void {
        tryResumeAudioContextIfNeeded();
    }

    inline function willEmitTouchDown(buttonId:Int, x:Float, y:Float):Void {
        tryResumeAudioContextIfNeeded();
    }

    function tryResumeAudioContextIfNeeded():Void {
        if (!didTryResumeAudioContext) {
            didTryResumeAudioContext = true;
            ceramic.App.app.backend.audio.resumeAudioContext(function(resumed:Bool) {
                if (resumed) {
                    ceramic.Shortcuts.log.success('Did resume audio context');
                }
                else {
                    ceramic.Shortcuts.log.error('Failed to resume audio context');
                }
            });
        }
    }

#end

/// Public API

    /**
     * Gets the current screen width in pixels.
     * @return Screen width in pixels
     */
    inline public function getWidth():Int {

        return Clay.app.screenWidth;

    }

    /**
     * Gets the current screen height in pixels.
     * @return Screen height in pixels
     */
    inline public function getHeight():Int {

        return Clay.app.screenHeight;

    }

    /**
     * Gets the current screen pixel density/scale factor.
     * @return Pixel density (1.0 = standard, 2.0 = retina/high-DPI, etc.)
     */
    inline public function getDensity():Float {

        return Clay.app.screenDensity;

    }

    /**
     * Sets the window background color.
     * 
     * Note: This method is currently unused as background clearing
     * is handled directly in the draw loop.
     * 
     * @param background Background color as integer
     */
    public function setBackground(background:Int):Void {

        // Already handled in draw loop, no need to do anything here.

    }

    /**
     * Sets the window title text.
     * @param title New window title
     */
    public function setWindowTitle(title:String):Void {

        Clay.app.runtime.setWindowTitle(title);

    }

    /**
     * Sets the window fullscreen state.
     * 
     * On web platforms, this checks for Electron runner integration
     * and uses native fullscreen if available, otherwise falls back
     * to HTML5 fullscreen API.
     * 
     * @param fullscreen True to enable fullscreen, false to disable
     */
    public function setWindowFullscreen(fullscreen:Bool):Void {

        #if web
        // If using electron runner, use that to handle fullscreen instead of html fullscreen
        if (ElectronRunner.electronRunner != null && ElectronRunner.electronRunner.setFullscreen != null) {
            ElectronRunner.electronRunner.setFullscreen(fullscreen);
            return;
        }
        #end

        if (!Clay.app.runtime.setWindowFullscreen(fullscreen)) {
            // Failed to change fullscreen setting, restore previous setting
            ceramic.App.app.settings.fullscreen = !fullscreen;
        }

    }

    public function minimizeWindow():Void {

        Clay.app.runtime.minimizeWindow();

    }

    public function maximizeWindow():Void {

        Clay.app.runtime.maximizeWindow();

    }

    public function restoreWindow():Void {

        Clay.app.runtime.restoreWindow();

    }

    public function isWindowMaximized():Bool {

        return Clay.app.runtime.isWindowMaximized();

    }

    public function showWindowMenu(x:Float, y:Float):Void {

        Clay.app.runtime.showWindowMenu(x, y);

    }

    public function setWindowHitRegions(regions:Array<Float>):Void {

        Clay.app.runtime.setWindowHitRegions(regions);

    }

    public function setCursorVisible(visible:Bool):Void {

        cursorVisible = visible;
        if (cursor == ceramic.MouseCursor.ARROW) {
            // Default shape: unchanged behaviour
            Clay.app.runtime.setCursorVisible(visible);
        }
        else {
            applyCursor();
        }

    }

/// Cursor shape

    /** Visibility requested with `setCursorVisible()` */
    var cursorVisible:Bool = true;

    /** Shape requested with `setCursor()` */
    var cursor:ceramic.MouseCursor = ceramic.MouseCursor.ARROW;

    public function setCursor(cursor:ceramic.MouseCursor):Void {

        if (this.cursor == cursor) return;
        this.cursor = cursor;
        applyCursor();

    }

    function applyCursor():Void {

        final hidden = !cursorVisible || cursor == ceramic.MouseCursor.NONE;

        #if web

        Clay.app.runtime.setCursorVisible(cursorVisible);
        final canvas:js.html.Element = cast Clay.app.runtime.window;
        if (canvas != null) {
            // Empty value when using the default shape, so that the canvas
            // keeps inheriting the visibility set on the document body
            canvas.style.cursor = hidden ? 'none' : (cursor == ceramic.MouseCursor.ARROW ? '' : cursor.toCss());
        }

        #elseif clay_sdl

        Clay.app.runtime.setCursorVisible(!hidden);
        if (!hidden) {
            final id:Int = switch cursor {
                case IBEAM: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_TEXT');
                case CROSSHAIR: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_CROSSHAIR');
                case CLOSED_HAND: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_GRABBING');
                case OPEN_HAND: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_GRAB');
                case POINTING_HAND: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_POINTER');
                case RESIZE_LEFT: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_W_RESIZE');
                case RESIZE_RIGHT: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_E_RESIZE');
                case RESIZE_LEFT_RIGHT: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_EW_RESIZE');
                case RESIZE_UP: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_N_RESIZE');
                case RESIZE_DOWN: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_S_RESIZE');
                case RESIZE_UP_DOWN: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_NS_RESIZE');
                case RESIZE_UP_LEFT_DOWN_RIGHT: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_NWSE_RESIZE');
                case RESIZE_UP_RIGHT_DOWN_LEFT: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_NESW_RESIZE');
                case RESIZE_COLUMN: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_COL_RESIZE');
                case RESIZE_ROW: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_ROW_RESIZE');
                case IBEAM_VERTICAL: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_VERTICAL_TEXT');
                case OPERATION_NOT_ALLOWED: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_NOT_ALLOWED');
                case DRAG_LINK: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_ALIAS');
                case DRAG_COPY: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_COPY');
                case CONTEXTUAL_MENU: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_CONTEXT_MENU');
                case _: untyped __cpp__('(int)SDL_SYSTEM_CURSOR_DEFAULT');
            }
            // System cursors are created once, then reused
            untyped __cpp__(
                '{ static SDL_Cursor* ceramicSystemCursors_[SDL_SYSTEM_CURSOR_COUNT] = { NULL }; int id_ = {0}; if (id_ >= 0 && id_ < SDL_SYSTEM_CURSOR_COUNT) { if (ceramicSystemCursors_[id_] == NULL) ceramicSystemCursors_[id_] = SDL_CreateSystemCursor((SDL_SystemCursor)id_); if (ceramicSystemCursors_[id_] == NULL) ceramicSystemCursors_[id_] = SDL_GetDefaultCursor(); if (ceramicSystemCursors_[id_] != NULL) SDL_SetCursor(ceramicSystemCursors_[id_]); } }',
                id
            );
        }

        #end

    }

/// Screenshot

    /**
     * Index counter for generating unique screenshot identifiers.
     */
    var nextScreenshotIndex:Int = 0;

    #if web

    /**
     * Captures a screenshot and converts it to a texture (web platform).
     * 
     * Uses the HTML5 Canvas toBlob API to capture the current frame buffer
     * and converts it to a Clay texture object that can be used for rendering.
     * 
     * @param done Callback function receiving the texture (null if failed)
     */
    public function screenshotToTexture(done:(texture:Texture)->Void):Void {

        var window = clay.Clay.app.runtime.window;
        window.toBlob(function(blob:Dynamic) {
            blob.arrayBuffer().then(function(buffer:js.lib.ArrayBuffer) {
                var pngBytes = ceramic.UInt8Array.fromBuffer(buffer, 0, buffer.byteLength);
                clay.Clay.app.assets.imageFromBytes(pngBytes, 'png', 4, true, function(image) {
                    if (image != null) {
                        var id = 'screenshot:' + (nextScreenshotIndex++);
                        var texture = clay.graphics.Texture.fromImage(image);
                        texture.id = id;
                        texture.init();
                        done(texture);
                    }
                    else {
                        done(null);
                    }
                });
            });
        }, 'image/png');

    }

    public function screenshotToPng(?path:String, done:(?data:Bytes)->Void):Void {

        var window = clay.Clay.app.runtime.window;
        window.toBlob(function(blob:Dynamic) {
            blob.arrayBuffer().then(function(buffer:js.lib.ArrayBuffer) {
                var pngBytes = ceramic.UInt8Array.fromBuffer(buffer, 0, buffer.byteLength).toBytes();
                if (path != null) {
                    Files.saveBytes(path, pngBytes);
                    done();
                }
                else {
                    done(pngBytes);
                }
            });
        }, 'image/png');

    }

    public function screenshotToPixels(done:(pixels:ceramic.UInt8Array, width:Int, height:Int)->Void):Void {

        var window = clay.Clay.app.runtime.window;
        window.toBlob(function(blob:Dynamic) {
            blob.arrayBuffer().then(function(buffer:js.lib.ArrayBuffer) {
                var pngBytes = ceramic.UInt8Array.fromBuffer(buffer, 0, buffer.byteLength);
                clay.Clay.app.assets.imageFromBytes(pngBytes, 'png', 4, false, function(image) {
                    if (image != null) {
                        done(image.pixels, image.width, image.height);
                    }
                    else {
                        done(null, 0, 0);
                    }
                });
            });
        }, 'image/png');

    }

    #elseif clay_sdl

    static var _point = new Point(0, 0);

    function _sdlScreenshot(point:Point):ceramic.UInt8Array {
        var width = Clay.app.runtime.windowWidth();
        var height = Clay.app.runtime.windowHeight();
        var pixels = new clay.buffers.Uint8Array(width * height * 4);
        for (i in 0...pixels.length) {
            pixels[i] = 0;
        }

        // Actual screenshot using cross-platform Graphics API
        Clay.app.graphics.readPixels(0, 0, width, height, pixels);

        _sdlSurfacePixelsToRgbaPixels(pixels, width, height);

        _point.x = width;
        _point.y = height;

        return ceramic.UInt8Array.fromBuffer(pixels.buffer, 0, pixels.length);
    }

    function _sdlSurfacePixelsToRgbaPixels(pixels:clay.buffers.Uint8Array, width:Int, height:Int):Void {
        // Flip the image vertically (OpenGL reads bottom-to-top)
        var halfHeight = Std.int(Math.floor(height / 2));
        var rowSize = width * 4;
        var temp:Int;
        for (y in 0...halfHeight) {
            for (x in 0...rowSize) {
                var i = y * rowSize + x;
                var i2 = (height - y - 1) * rowSize + x;
                temp = pixels[i];
                pixels[i] = pixels[i2];
                pixels[i2] = temp;
            }
        }
    }

    public function screenshotToTexture(done:(texture:Texture)->Void):Void {

        var pixels = _sdlScreenshot(_point);

        done(ceramic.App.app.backend.textures.createTexture(Std.int(_point.x), Std.int(_point.y), pixels));

    }

    public function screenshotToPng(?path:String, done:(?data:Bytes)->Void):Void {

        var pixels = _sdlScreenshot(_point);
        var bytes = pixels.toBytes();

        if (path != null) {
            stb.ImageWrite.write_png(path, Std.int(_point.x), Std.int(_point.y), 4, bytes.getData(), 0, bytes.length, Std.int(_point.x * 4));
            done();
        }
        else {
            // This part could be improved if we exposed stbi_write_png_to_func
            // and skipped the write to disk part, but that will do for now.
            var tmpFile = Utils.uniqueId() + '_screenshot.png';
            var storageDir = ceramic.App.app.backend.info.storageDirectory();
            var tmpPath = ceramic.Path.join([storageDir, tmpFile]);
            stb.ImageWrite.write_png(tmpPath, Std.int(_point.x), Std.int(_point.y), 4, bytes.getData(), 0, bytes.length, Std.int(_point.x * 4));
            var data = Files.getBytes(tmpPath);
            Files.deleteFile(tmpPath);
            done(data);
        }

    }

    public function screenshotToPixels(done:(pixels:ceramic.UInt8Array, width:Int, height:Int)->Void):Void {

        var pixels = _sdlScreenshot(_point);

        done(pixels, Std.int(_point.x), Std.int(_point.y));

    }

    #else

    public function screenshotToTexture(done:(texture:Texture)->Void):Void {

        done(null);

    }

    public function screenshotToPng(?path:String, done:(?data:Bytes)->Void):Void {

        done(null);

    }

    public function screenshotToPixels(done:(pixels:ceramic.UInt8Array, width:Int, height:Int)->Void):Void {

        done(null, 0, 0);

    }

    #end

}
