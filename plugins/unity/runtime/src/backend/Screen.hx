package backend;

import ceramic.Files;
import ceramic.IntIntMap;
import haxe.io.Bytes;
import unityengine.ImageConversion;
import unityengine.RenderTexture;
import unityengine.ScreenCapture;
import unityengine.Texture2D;
import unityengine.inputsystem.Mouse;
import unityengine.inputsystem.TouchPhase;
import unityengine.inputsystem.Touchscreen;
import unityengine.inputsystem.controls.TouchControl;

using ceramic.Extensions;

#if !no_backend_docs
/**
 * Unity backend implementation for screen and input handling.
 * Manages window properties, mouse/touch input, and screenshot capture functionality.
 * Handles Unity's Input System for both mouse and multi-touch interactions.
 */
#end
@:keep
@:allow(Main)
class Screen implements tracker.Events #if !completion implements spec.Screen #end {

    #if !no_backend_docs
    /**
     * Creates a new Screen instance and initializes display properties.
     * Automatically detects screen dimensions and calculates pixel density.
     */
    #end
    public function new() {

        isEditor = untyped __cs__('UnityEngine.Application.isEditor');

        readOverrides();
        readPixelSize();
        density = computeDensity();
        width = toLogicalSize(pixelWidth, density);
        height = toLogicalSize(pixelHeight, density);

    }

    #if !no_backend_docs
    /**
     * Screen density forced by the `CERAMIC_UNITY_DENSITY` environment
     * variable (a number above 0), or 0 when not forced.
     */
    #end
    var densityOverride:Float = 0;

    #if !no_backend_docs
    /**
     * Screen size in pixels forced by the `CERAMIC_UNITY_SCREEN_SIZE`
     * environment variable (`<width>x<height>`, for example `1024x1024`),
     * or 0 when not forced.
     */
    #end
    var pixelWidthOverride:Int = 0;

    #if !no_backend_docs
    /**
     * Whether `CERAMIC_UNITY_SCREEN_SIZE` is `window`: the screen takes the
     * size of the window the app asks for at startup (`settings.windowWidth`
     * and `windowHeight`, else `targetWidth` and `targetHeight`, like the
     * window of the clay backend), times the density.
     */
    #end
    var screenSizeFromWindowSettings:Bool = false;

    #if !no_backend_docs
    /**
     * See `pixelWidthOverride`.
     */
    #end
    var pixelHeightOverride:Int = 0;

    #if !no_backend_docs
    /**
     * Reads the density and screen size overrides once. They give a
     * deterministic screen when there is no real one (batch mode, tests
     * rendered at a fixed size and density).
     */
    #end
    function readOverrides():Void {

        var densityValue = Sys.getEnv('CERAMIC_UNITY_DENSITY');
        if (densityValue != null && densityValue != '') {
            var value = Std.parseFloat(densityValue);
            if (!Math.isNaN(value) && value > 0) {
                densityOverride = value;
            }
            else {
                ceramic.Shortcuts.log.warning('Ignoring invalid CERAMIC_UNITY_DENSITY: $densityValue');
            }
        }

        var sizeValue = Sys.getEnv('CERAMIC_UNITY_SCREEN_SIZE');
        if (sizeValue == 'window') {
            screenSizeFromWindowSettings = true;
        }
        else if (sizeValue != null && sizeValue != '') {
            var parts = sizeValue.split('x');
            var w = parts.length == 2 ? Std.parseInt(parts[0]) : null;
            var h = parts.length == 2 ? Std.parseInt(parts[1]) : null;
            if (w != null && h != null && w > 0 && h > 0) {
                pixelWidthOverride = w;
                pixelHeightOverride = h;
            }
            else {
                ceramic.Shortcuts.log.warning('Ignoring invalid CERAMIC_UNITY_SCREEN_SIZE: $sizeValue');
            }
        }

    }

    #if !no_backend_docs
    /**
     * Reads the size of the screen in pixels (or its override).
     */
    #end
    function readPixelSize():Void {

        if (pixelWidthOverride > 0) {
            pixelWidth = pixelWidthOverride;
            pixelHeight = pixelHeightOverride;
        }
        else if (screenSizeFromWindowSettings && ceramic.App.app != null && ceramic.App.app.settings != null
            && (ceramic.App.app.settings.windowWidth > 0 || ceramic.App.app.settings.targetWidth > 0)) {
            // Resolved once, from the size the app asks for at startup, and
            // kept as the override: once the app runs, the window settings
            // follow the actual screen (`ceramic.Screen.syncWindowSize()`),
            // so reading them again would feed the screen size back to
            // itself (a 640x480 default screen stayed 640x480 whatever the
            // window settings asked). `setWindowSize()` changes it afterwards.
            var settings = ceramic.App.app.settings;
            var screenDensity = computeDensity();
            pixelWidthOverride = Math.round((settings.windowWidth > 0 ? settings.windowWidth : settings.targetWidth) * screenDensity);
            pixelHeightOverride = Math.round((settings.windowHeight > 0 ? settings.windowHeight : settings.targetHeight) * screenDensity);
            pixelWidth = pixelWidthOverride;
            pixelHeight = pixelHeightOverride;
        }
        else {
            pixelWidth = untyped __cs__('UnityEngine.Screen.width');
            pixelHeight = untyped __cs__('UnityEngine.Screen.height');
        }

    }

    #if !no_backend_docs
    /**
     * Density of the screen: its override, 1 in the editor, otherwise
     * `round(dpi / 160)` (at least 1).
     */
    #end
    function computeDensity():Float {

        if (densityOverride > 0) {
            return densityOverride;
        }
        if (isEditor) {
            return 1;
        }
        var dpi:Single = untyped __cs__('UnityEngine.Screen.dpi');
        var result:Float = Math.round(dpi / 160);
        if (result < 1) {
            result = 1;
        }
        return result;

    }

    #if !no_backend_docs
    /**
     * Converts a size in pixels to a logical size, rounded up so that
     * the logical area always covers every pixel of the screen
     * (slightly overflowing it if needed), with a small tolerance
     * for density values that are not exact as floats.
     */
    #end
    inline static function toLogicalSize(pixelSize:Int, density:Float):Int {

        return Math.ceil(pixelSize / density - 0.0001);

    }

    #if !no_backend_docs
    /**
     * Current screen width in actual pixels.
     */
    #end
    @:allow(backend.Draw)
    var pixelWidth:Int = 0;

    #if !no_backend_docs
    /**
     * Current screen height in actual pixels.
     */
    #end
    @:allow(backend.Draw)
    var pixelHeight:Int = 0;

    #if !no_backend_docs
    /**
     * Current screen width in logical pixels (after density scaling).
     */
    #end
    var width:Int = 0;

    #if !no_backend_docs
    /**
     * Current screen height in logical pixels (after density scaling).
     */
    #end
    var height:Int = 0;

    #if !no_backend_docs
    /**
     * Screen pixel density multiplier (DPI / 160).
     * Used to convert between physical and logical pixels.
     */
    #end
    var density:Float = 1;

    #if !no_backend_docs
    /**
     * Whether the application is running in Unity Editor.
     * Editor mode uses density = 1 regardless of display DPI.
     */
    #end
    var isEditor:Bool = false;

/// Events

    #if !no_backend_docs
    /**
     * Emitted when the screen dimensions or density changes.
     */
    #end
    @event function resize();

    #if !no_backend_docs
    /**
     * Emitted when a mouse button is pressed.
     * @param buttonId Button identifier (0=left, 1=middle, 2=right)
     * @param x Mouse X position in logical pixels
     * @param y Mouse Y position in logical pixels
     */
    #end
    @event function mouseDown(buttonId:Int, x:Float, y:Float);
    
    #if !no_backend_docs
    /**
     * Emitted when a mouse button is released.
     * @param buttonId Button identifier (0=left, 1=middle, 2=right)
     * @param x Mouse X position in logical pixels
     * @param y Mouse Y position in logical pixels
     */
    #end
    @event function mouseUp(buttonId:Int, x:Float, y:Float);
    
    #if !no_backend_docs
    /**
     * Emitted when the mouse wheel is scrolled.
     * @param x Horizontal scroll delta
     * @param y Vertical scroll delta
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
     * Emitted when the mouse cursor moves.
     * @param x Mouse X position in logical pixels
     * @param y Mouse Y position in logical pixels
     */
    #end
    @event function mouseMove(x:Float, y:Float);

    #if !no_backend_docs
    /**
     * Emitted when a touch begins.
     * @param touchIndex Touch identifier (0-based index)
     * @param x Touch X position in logical pixels
     * @param y Touch Y position in logical pixels
     */
    #end
    @event function touchDown(touchIndex:Int, x:Float, y:Float);
    
    #if !no_backend_docs
    /**
     * Emitted when a touch ends.
     * @param touchIndex Touch identifier (0-based index)
     * @param x Touch X position in logical pixels
     * @param y Touch Y position in logical pixels
     */
    #end
    @event function touchUp(touchIndex:Int, x:Float, y:Float);
    
    #if !no_backend_docs
    /**
     * Emitted when a touch moves.
     * @param touchIndex Touch identifier (0-based index)
     * @param x Touch X position in logical pixels
     * @param y Touch Y position in logical pixels
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
     * system: Unity's `OnApplicationFocus`, and on mobile `OnApplicationPause`
     * (an app in background is not focused). See `handleApplicationFocus()`.
     * @param focused Whether the window now has the focus
     */
    @event function windowFocusChange(focused:Bool);

    /**
     * Fired when an item of the menu bar is chosen. Not fired by the Unity
     * backend (no menu bar).
     * @param id The `id` of the item
     */
    @event function menuAction(id:Int);

    /**
     * Fired right after the key down of a keystroke matching the shortcut
     * of a menu bar item. Not fired by the Unity backend.
     * @param id The `id` of the item
     */
    @event function menuKeyEquivalent(id:Int);

    /**
     * Fired when a menu of the menu bar opens. Not fired by the Unity backend.
     */
    @event function menuWillOpen();

    /**
     * Fired when the light or dark appearance of the system changes. Not
     * fired by the Unity backend yet.
     * @param appearance The new appearance
     */
    @event function systemAppearanceChange(appearance:ceramic.SystemAppearance);

    /**
     * Fired when the user's scrollbar preference changes. Not fired by the
     * Unity backend.
     * @param autoHide Whether scrollbars should only show while scrolling
     */
    @event function autoHideScrollbarsChange(autoHide:Bool);

/// Public API

    #if !no_backend_docs
    /**
     * Gets the current screen width in logical pixels.
     * @return Screen width after density scaling
     */
    #end
    inline public function getWidth():Int {

        return width;

    }

    #if !no_backend_docs
    /**
     * Gets the current screen height in logical pixels.
     * @return Screen height after density scaling
     */
    #end
    inline public function getHeight():Int {

        return height;

    }

    #if !no_backend_docs
    /**
     * Gets the current screen pixel density multiplier.
     * @return Density factor (DPI / 160), minimum 1.0
     */
    #end
    inline public function getDensity():Float {

        return density;

    }

    #if !no_backend_docs
    /**
     * Sets the background color for the screen.
     * Note: In Unity backend, this is handled during rendering.
     * @param background RGB color value (0xRRGGBB)
     */
    #end
    public function setBackground(background:Int):Void {

        // Background will be updated when drawing

    }

    #if !no_backend_docs
    /**
     * Sets the window title.
     * Note: Not implemented in Unity backend.
     * @param title Window title string
     */
    #end
    public function setWindowTitle(title:String):Void {

        // TODO

    }

    #if !no_backend_docs
    /**
     * Toggles fullscreen mode.
     * Note: Not implemented in Unity backend.
     * @param fullscreen Whether to enable fullscreen
     */
    #end
    public function setWindowFullscreen(fullscreen:Bool):Void {

        // TODO

    }

    #if !no_backend_docs
    /**
     * Resizes the window of a standalone player to the given logical size.
     * Does nothing in the editor, on mobile, in fullscreen,
     * or when the screen size is overridden.
     * @param width The new window width
     * @param height The new window height
     * @return `true` if the screen is changing size
     */
    #end
    public function setWindowSize(width:Int, height:Int):Bool {

        if (width <= 0 || height <= 0) {
            return false;
        }

        if (screenSizeFromWindowSettings) {
            // A screen sized from the window settings (no window): the new
            // size replaces the resolved one and is picked up by update()
            var screenDensity = computeDensity();
            var newPixelWidth:Int = Math.round(width * screenDensity);
            var newPixelHeight:Int = Math.round(height * screenDensity);
            if (newPixelWidth == pixelWidthOverride && newPixelHeight == pixelHeightOverride) {
                return false;
            }
            pixelWidthOverride = newPixelWidth;
            pixelHeightOverride = newPixelHeight;
            return true;
        }

        if (pixelWidthOverride > 0) {
            return false;
        }

        if (isEditor) {
            return false;
        }

        var isMobile:Bool = untyped __cs__('UnityEngine.Application.isMobilePlatform');
        var isFullscreen:Bool = untyped __cs__('UnityEngine.Screen.fullScreen');
        if (isMobile || isFullscreen) {
            return false;
        }

        var screenDensity = computeDensity();
        var newPixelWidth:Int = Math.round(width * screenDensity);
        var newPixelHeight:Int = Math.round(height * screenDensity);
        if (newPixelWidth == pixelWidth && newPixelHeight == pixelHeight) {
            return false;
        }

        // The new size is picked up by update(), which emits the resize event
        untyped __cs__('UnityEngine.Screen.SetResolution({0}, {1}, UnityEngine.Screen.fullScreenMode)', newPixelWidth, newPixelHeight);
        return true;

    }

    public function minimizeWindow():Void {}

    public function maximizeWindow():Void {}

    public function restoreWindow():Void {}

    public function isWindowMaximized():Bool {
        return false;
    }

    public function showWindowMenu(x:Float, y:Float):Void {}

    public function setWindowHitRegions(regions:Array<Float>):Void {}

    /** Not available yet on Unity: does nothing. */
    public function activateWindow():Void {}

    /**
     * Whether the app window has the focus: Unity's `OnApplicationFocus`
     * and `OnApplicationPause` messages (see `handleApplicationFocus()`).
     */
    public function isWindowFocused():Bool {
        return focusTracker.focused;
    }

/// Application focus and pause

    #if !no_backend_docs
    /**
     * Whether the app runs in batch mode (`-batchmode`).
     */
    #end
    static final isBatchMode:Bool = untyped __cs__('UnityEngine.Application.isBatchMode');

    #if !no_backend_docs
    /**
     * Window focus from Unity's messages, the pause and the virtual keyboard.
     * In batch mode the window starts focused (nothing has the focus there,
     * and tests expect active windows, like the headless backend).
     */
    #end
    final focusTracker:ceramic.WindowFocusTracker = new ceramic.WindowFocusTracker(
        isBatchMode ? true : untyped __cs__('UnityEngine.Application.isFocused')
    );

    /**
     * Whether `OnApplicationPause` means that the app goes to background
     * (`App` background and foreground events, window not focused): true on
     * mobile platforms (`Application.isMobilePlatform`). On desktop Unity
     * pauses an app that loses the focus when it does not run in background,
     * and the editor pauses with its pause button: the focus events cover
     * the first case and the second one is not a background state.
     */
    public var pauseMeansBackground:Bool = untyped __cs__('UnityEngine.Application.isMobilePlatform');

    /**
     * Whether Unity's focus and pause messages are honored in batch mode.
     * False by default: a batch editor has no focused window, the app keeps
     * the focus. Tests that simulate the messages set it to true.
     */
    public var applicationFocusInBatchMode:Bool = false;

    /**
     * Unity's `OnApplicationFocus` (from `UnityLifecycle`, the component that
     * `Main` adds to the Ceramic game object).
     * @param focused Whether the app now has the focus
     */
    public function handleApplicationFocus(focused:Bool):Void {

        if (isBatchMode && !applicationFocusInBatchMode) return;
        if (focusTracker.setSystemFocused(focused)) {
            emitWindowFocusChange(focusTracker.focused);
        }

    }

    /**
     * Unity's `OnApplicationPause`. When it means background
     * (`pauseMeansBackground`), emits the background or foreground events of
     * the app (like clay on mobile), and the window is not focused while
     * paused.
     * @param paused Whether the app is paused
     */
    public function handleApplicationPause(paused:Bool):Void {

        if (isBatchMode && !applicationFocusInBatchMode) return;
        if (!pauseMeansBackground) return;
        if (paused == focusTracker.paused) return;

        final app = ceramic.App.app;
        if (paused) {
            @:privateAccess app.emitBeginEnterBackground();
            @:privateAccess app.emitFinishEnterBackground();
        }
        else {
            // The focus may have changed while paused
            if (!isBatchMode) {
                focusTracker.setSystemFocused(untyped __cs__('UnityEngine.Application.isFocused'));
            }
            @:privateAccess app.emitBeginEnterForeground();
            @:privateAccess app.emitFinishEnterForeground();
        }
        final wasFocused = focusTracker.focused;
        focusTracker.setPaused(paused);
        if (focusTracker.focused != wasFocused) {
            emitWindowFocusChange(focusTracker.focused);
        }

    }

    #if !no_backend_docs
    /**
     * The virtual keyboard of the app was shown or hidden (`TextInput`):
     * Android takes the focus of the app while its keyboard is visible,
     * which must not deactivate the edited field. Once hidden, the focus is
     * read again from Unity.
     */
    #end
    @:allow(backend.TextInput)
    function virtualKeyboardVisibilityChange(visible:Bool):Void {

        final wasFocused = focusTracker.focused;
        focusTracker.setKeyboardVisible(visible);
        if (!visible && !isBatchMode) {
            focusTracker.setSystemFocused(untyped __cs__('UnityEngine.Application.isFocused'));
        }
        if (focusTracker.focused != wasFocused) {
            emitWindowFocusChange(focusTracker.focused);
        }

    }

    #if !no_backend_docs
    /**
     * Touches also go to the text input, which follows taps for its virtual
     * keyboard.
     */
    #end
    function willEmitTouchDown(touchIndex:Int, x:Float, y:Float):Void {
        ceramic.App.app.backend.textInput.handleTouchDown(touchIndex, x, y);
    }

    function willEmitTouchMove(touchIndex:Int, x:Float, y:Float):Void {
        ceramic.App.app.backend.textInput.handleTouchMove(touchIndex, x, y);
    }

    function willEmitTouchUp(touchIndex:Int, x:Float, y:Float):Void {
        ceramic.App.app.backend.textInput.handleTouchUp(touchIndex, x, y);
    }

    function willEmitTouchCancel(touchIndex:Int, x:Float, y:Float):Void {
        ceramic.App.app.backend.textInput.handleTouchCancel(touchIndex, x, y);
    }

    /** The menus of the last `setMenuBar()` call (no menu bar on Unity). */
    public var menuBar(default, null):Array<ceramic.MenuItem> = null;

    var menuItemEnabled:(id:Int)->Bool = null;

    /** No menu bar on Unity: keeps the menus (`menuBar`, `isMenuItemEnabled`), like the headless backend. */
    public function setMenuBar(menus:Array<ceramic.MenuItem>, isEnabled:(id:Int)->Bool):Void {
        menuBar = menus;
        menuItemEnabled = isEnabled;
    }

    /** What the system would ask to validate the item with the given id (menu bar or dock menu). */
    public function isMenuItemEnabled(id:Int):Bool {
        if (menuItemEnabled != null && menuItemEnabled(id)) return true;
        return dockMenuItemEnabled != null && dockMenuItemEnabled(id);
    }

    /** The dock menu last installed (no dock menu on Unity: nothing is shown). */
    public var dockMenu(default, null):Array<ceramic.MenuItem> = null;

    var dockMenuItemEnabled:(id:Int)->Bool = null;

    /** No dock menu on Unity: keeps the items (`dockMenu`, `isMenuItemEnabled`), like the headless backend. */
    public function setDockMenu(items:Array<ceramic.MenuItem>, isEnabled:(id:Int)->Bool):Void {
        dockMenu = items;
        dockMenuItemEnabled = isEnabled;
    }

    /** Not read yet on Unity: always `LIGHT`. */
    public function getSystemAppearance():ceramic.SystemAppearance {
        return LIGHT;
    }

    /** Not read yet on Unity: always false. */
    public function getAutoHideScrollbars():Bool {
        return false;
    }

    #if !no_backend_docs
    /**
     * Shows or hides the mouse cursor.
     * @param visible Whether the cursor is visible
     */
    #end
    public function setCursorVisible(visible:Bool):Void {

        cursorVisible = visible;
        untyped __cs__('UnityEngine.Cursor.visible = {0}', visible && cursor != ceramic.MouseCursor.NONE);

    }

    var cursorVisible:Bool = true;

    var cursor:ceramic.MouseCursor = ceramic.MouseCursor.ARROW;

    #if !no_backend_docs
    /**
     * Sets the mouse cursor shape.
     * Unity only supports custom cursor textures (`Cursor.SetCursor`), not system
     * cursor shapes, so this only handles `NONE` (hidden cursor). Other shapes
     * keep the default cursor.
     * @param cursor The cursor shape
     */
    #end
    public function setCursor(cursor:ceramic.MouseCursor):Void {

        this.cursor = cursor;
        untyped __cs__('UnityEngine.Cursor.visible = {0}', cursorVisible && cursor != ceramic.MouseCursor.NONE);

    }

/// Internal

    #if !no_backend_docs
    /**
     * Updates screen dimensions and processes input events.
     * Called internally by the backend each frame.
     */
    #end
    @:allow(backend.Backend)
    #if !no_backend_docs
    /**
     * Applies the window settings of the project to the screen before the
     * backend is ready (`Main`): with `CERAMIC_UNITY_SCREEN_SIZE=window` the
     * screen must have the requested size before the first resize of
     * `ceramic.Screen`, which copies the actual screen size into the window
     * settings. No event is emitted.
     */
    #end
    function applyStartupSettings():Void {

        readPixelSize();
        density = computeDensity();
        width = toLogicalSize(pixelWidth, density);
        height = toLogicalSize(pixelHeight, density);

    }

    function update() {

        readPixelSize();

        var newDensity = computeDensity();
        var newWidth = toLogicalSize(pixelWidth, newDensity);
        var newHeight = toLogicalSize(pixelHeight, newDensity);

        var didResize = (width != newWidth) || (height != newHeight) || (density != newDensity);

        width = newWidth;
        height = newHeight;
        density = newDensity;

        if (didResize) {
            emitResize();
        }

        updateMouseInput();
        updateTouchInput();

    }

/// Mouse input

    #if !no_backend_docs
    /**
     * Tracks left mouse button state.
     */
    #end
    var mouseLeftPressed:Bool = false;

    #if !no_backend_docs
    /**
     * Tracks middle mouse button state.
     */
    #end
    var mouseMiddlePressed:Bool = false;

    #if !no_backend_docs
    /**
     * Tracks right mouse button state.
     */
    #end
    var mouseRightPressed:Bool = false;

    #if !no_backend_docs
    /**
     * Current mouse X position in logical pixels.
     */
    #end
    var mouseX:Float = -1;

    #if !no_backend_docs
    /**
     * Current mouse Y position in logical pixels.
     */
    #end
    var mouseY:Float = -1;

    #if !no_backend_docs
    /**
     * Mouse scroll per event of the Input System (`mouseScroll`, `mouseWheel`).
     */
    #end
    public var scrollInput(default, null):ScrollInput = new ScrollInput();

    #if !no_backend_docs
    /**
     * Processes mouse input from Unity's Input System.
     * Handles button states, movement, and wheel scrolling.
     */
    #end
    function updateMouseInput() {

        scrollInput.bind();

        var mouse = Mouse.current;
        if (mouse != null) {

            var newMouseX = mouse.position.x.ReadValue() / density;
            var newMouseY = (pixelHeight - mouse.position.y.ReadValue()) / density;

            if (newMouseX != mouseX || newMouseY != mouseY) {
                mouseX = newMouseX;
                mouseY = newMouseY;
                emitMouseMove(mouseX, mouseY);
            }

            // Scroll, one mouseScroll per event of the Input System, at the
            // position just emitted (see backend.ScrollInput)
            scrollInput.flush(this);

            if (mouse.leftButton.isPressed) {
                if (!mouseLeftPressed) {
                    mouseLeftPressed = true;
                    emitMouseDown(0, mouseX, mouseY);
                }
            }
            else {
                if (mouseLeftPressed) {
                    mouseLeftPressed = false;
                    emitMouseUp(0, mouseX, mouseY);
                }
            }

            if (mouse.middleButton.isPressed) {
                if (!mouseMiddlePressed) {
                    mouseMiddlePressed = true;
                    emitMouseDown(1, mouseX, mouseY);
                }
            }
            else {
                if (mouseMiddlePressed) {
                    mouseMiddlePressed = false;
                    emitMouseUp(1, mouseX, mouseY);
                }
            }

            if (mouse.rightButton.isPressed) {
                if (!mouseRightPressed) {
                    mouseRightPressed = true;
                    emitMouseDown(2, mouseX, mouseY);
                }
            }
            else {
                if (mouseRightPressed) {
                    mouseRightPressed = false;
                    emitMouseUp(2, mouseX, mouseY);
                }
            }

        }

    }

/// Touch input

    #if !no_backend_docs
    /**
     * Maps Unity touch IDs to Ceramic touch indices.
     */
    #end
    var touchIdToIndex:IntIntMap = new IntIntMap(16, 0.5, false);

    #if !no_backend_docs
    /**
     * Tracks which touch indices are currently in use.
     * Maps index to Unity touch ID.
     */
    #end
    var usedTouchIndexes:IntIntMap = new IntIntMap(16, 0.5, false);

    #if !no_backend_docs
    /**
     * Touch indices processed in the current frame.
     */
    #end
    var processedTouchIndexes:Array<Int> = [];

    #if !no_backend_docs
    /**
     * Number of touches from the previous frame.
     */
    #end
    var prevNumTouches:Int = 0;

    #if !no_backend_docs
    /**
     * Touch indices from the previous frame.
     */
    #end
    var prevProcessedTouchIndexes:Array<Int> = [];

    #if !no_backend_docs
    /**
     * Touch positions for the current frame (x,y pairs).
     */
    #end
    var processedTouchPositions:Array<Float> = [];

    #if !no_backend_docs
    /**
     * Touch positions from the previous frame (x,y pairs).
     */
    #end
    var prevProcessedTouchPositions:Array<Float> = [];

    #if !no_backend_docs
    /**
     * Highest touch start time seen, used to filter stale touches.
     */
    #end
    var touchHighestStartTime:Float = -1;

    #if !no_backend_docs
    /**
     * Processes touch input from Unity's Input System.
     * Handles multi-touch with proper ID tracking and robustness checks.
     */
    #end
    function updateTouchInput() {

        var touchScreen = Touchscreen.current;

        // Skip if no touchscreen API available on this device
        if (touchScreen == null)
            return;

        var numTouches = touchScreen.touches.Count;
        var prevTouchHighestStartTime = touchHighestStartTime;

        #if ceramic_debug_unity_touch
        trace('DEBUGTOUCH -------');
        #end

        for (i in 0...numTouches) {
            processedTouchIndexes[i] = 0;

            var touch:TouchControl = untyped __cs__('{0}[{1}]', touchScreen.touches, i);

            var phase = touch.phase.ReadValue();

            #if ceramic_debug_unity_touch
            trace('DEBUGTOUCH ${touch.touchId.ReadValue()}-${phase}-${touch.startTime.ReadValue()}-[${touch.position.x.ReadValue()/density},${touch.position.y.ReadValue()/density}]');
            #end

            if (phase != TouchPhase.None) {
                var touchId = touch.touchId.ReadValue();

                if (touchId > 0) {
                    var index = touchIdToIndex.get(touchId);
                    var positionX = touch.position.x.ReadValue() / density;
                    var positionY = touch.position.y.ReadValue() / density;
                    var startTime:Float = touch.startTime.ReadValue();

                    if (index == 0) {
                        // We only accept touches that are starting.
                        // Or new touches with an id higher than previously processed touches
                        if (phase == TouchPhase.Ended) {
                            if (startTime <= prevTouchHighestStartTime)
                                continue;
                        }
                        else if (phase == TouchPhase.Canceled) {
                            continue;
                        }

                        if (startTime > touchHighestStartTime)
                            touchHighestStartTime = startTime;

                        index++;
                        while (usedTouchIndexes.get(index) != 0) {
                            index++;
                        }
                        usedTouchIndexes.set(index, touchId);
                        touchIdToIndex.set(touchId, index);

                        // Emit touch down
                        var x = positionX;
                        var y = pixelHeight / density - positionY;
                        emitTouchDown(index - 1, x, y);
                    }
                    processedTouchIndexes[i] = index;
                    processedTouchPositions[i * 2] = positionX;
                    processedTouchPositions[i * 2 + 1] = positionY;

                    if (phase == TouchPhase.Moved) {
                        var deltaX = touch.delta.x.ReadValue();
                        var deltaY = touch.delta.y.ReadValue();
                        if (deltaX != 0 || deltaY != 0) {
                            // Emit touch move
                            var x = positionX;
                            var y = pixelHeight / density - positionY;
                            emitTouchMove(index - 1, x, y);
                        }
                    }
                    // An ended touch is a touch up, a canceled one a touch cancel
                    // (ceramic.Screen ends it like a touch up after the cancel event)
                    else if (phase == TouchPhase.Ended || phase == TouchPhase.Canceled) {
                        var x = positionX;
                        var y = pixelHeight / density - positionY;
                        if (phase == TouchPhase.Canceled) {
                            emitTouchCancel(index - 1, x, y);
                        }
                        else {
                            emitTouchUp(index - 1, x, y);
                        }

                        usedTouchIndexes.remove(index);
                        touchIdToIndex.remove(touchId);
                    }
                }
            }

        }

        // Snippet for robustness: look for previously active touches that are not referenced
        // anymore by unity's input system. This is not supposed to happen, but from previous
        // tests on device, it does happen :(. Anyway we are safe with this check no matter what.
        for (i in 0...prevNumTouches) {
            var prevIndex = prevProcessedTouchIndexes.unsafeGet(i);
            if (prevIndex > 0 && usedTouchIndexes.get(prevIndex) != 0) {
                // Check that index is still processed this frame
                var foundIndex = false;
                for (n in 0...numTouches) {
                    var index = processedTouchIndexes.unsafeGet(n);
                    if (index == prevIndex) {
                        foundIndex = true;
                        break;
                    }
                }

                if (!foundIndex) {
                    // Index seems expired, remove it from list
                    // and emit touch up

                    var x = prevProcessedTouchPositions[i * 2];
                    var y = pixelHeight / density - prevProcessedTouchPositions[i * 2 + 1];
                    emitTouchUp(prevIndex - 1, x, y);

                    var touchId = usedTouchIndexes.get(prevIndex);
                    usedTouchIndexes.remove(prevIndex);
                    touchIdToIndex.remove(touchId);
                }
            }
        }

        // Swap processed indexes and positions for next iteration
        prevNumTouches = numTouches;
        var tmpProcessedIndexes = prevProcessedTouchIndexes;
        prevProcessedTouchIndexes = processedTouchIndexes;
        processedTouchIndexes = tmpProcessedIndexes;
        var tmpProcessedPosition = prevProcessedTouchPositions;
        prevProcessedTouchPositions = processedTouchPositions;
        processedTouchPositions = tmpProcessedPosition;

    }

/// Screenshot

    #if !no_backend_docs
    /**
     * Counter for generating unique screenshot texture names.
     */
    #end
    var nextScreenshotIndex:Int = 0;

    #if !no_backend_docs
    /**
     * Captures the current screen as a texture.
     * @param done Callback with the captured texture (null on failure)
     */
    #end
    public function screenshotToTexture(done:(texture:Texture)->Void):Void {

        if (batchTarget != null) {
            pendingBatchScreenshots.push(() -> {
                var unityTexture = readBatchTarget();
                done(new TextureImpl('screenshot:' + (nextScreenshotIndex++), unityTexture, null #if unity_6000 , null #end));
            });
            return;
        }

        var unityTexture:Texture2D = ScreenCapture.CaptureScreenshotAsTexture(1);
        if (unityTexture != null) {
            var texture = new TextureImpl('screenshot:' + (nextScreenshotIndex++), unityTexture, null #if unity_6000 , null #end);
            done(texture);
        }
        else {
            ceramic.Shortcuts.log.warning('Failed to generate texture from screen');
            done(null);
        }

    }

    #if !no_backend_docs
    /**
     * Captures the current screen as PNG data.
     * @param path Optional file path to save the PNG
     * @param done Callback with PNG bytes (null if path provided or on failure)
     */
    #end
    public function screenshotToPng(?path:String, done:(?data:Bytes)->Void):Void {

        if (batchTarget != null) {
            pendingBatchScreenshots.push(() -> {
                var unityTexture = readBatchTarget();
                var pngBytesData = ImageConversion.EncodeToPNG(unityTexture);
                untyped __cs__('UnityEngine.Object.Destroy({0})', unityTexture);
                if (path != null) {
                    Files.saveBytes(path, Bytes.ofData(pngBytesData));
                    done();
                }
                else {
                    done(Bytes.ofData(pngBytesData));
                }
            });
            return;
        }

        // Always go through a texture: `ScreenCapture.CaptureScreenshot(path)` writes the file
        // at some later frame, which would make `done` fire before the screenshot exists
        var unityTexture:Texture2D = ScreenCapture.CaptureScreenshotAsTexture(1);
        if (unityTexture != null) {
            var pngBytesData = ImageConversion.EncodeToPNG(unityTexture);
            untyped __cs__('UnityEngine.Object.Destroy({0})', unityTexture);
            if (path != null) {
                Files.saveBytes(path, Bytes.ofData(pngBytesData));
                done();
            }
            else {
                done(Bytes.ofData(pngBytesData));
            }
        }
        else {
            ceramic.Shortcuts.log.warning('Failed to generate texture from screen');
            done(null);
        }

    }

    #if !no_backend_docs
    /**
     * Captures the current screen as raw pixel data.
     * @param done Callback with pixel array, width, and height (null array on failure)
     */
    #end
    public function screenshotToPixels(done:(pixels:ceramic.UInt8Array, width:Int, height:Int)->Void):Void {

        if (batchTarget != null) {
            pendingBatchScreenshots.push(() -> {
                var unityTexture = readBatchTarget();
                var texture = new TextureImpl('screenshot:' + (nextScreenshotIndex++), unityTexture, null #if unity_6000 , null #end);
                var pixels = ceramic.App.app.backend.textures.fetchTexturePixels(texture);
                var width = texture.width;
                var height = texture.height;
                ceramic.App.app.backend.textures.destroyTexture(texture);
                done(pixels, width, height);
            });
            return;
        }

        var unityTexture:Texture2D = ScreenCapture.CaptureScreenshotAsTexture(1);
        if (unityTexture != null) {
            var texture = new TextureImpl('screenshot:' + (nextScreenshotIndex++), unityTexture, null #if unity_6000 , null #end);
            var pixels = ceramic.App.app.backend.textures.fetchTexturePixels(texture);
            var width = texture.width;
            var height = texture.height;
            ceramic.App.app.backend.textures.destroyTexture(texture);
            done(pixels, width, height);
        }
        else {
            ceramic.Shortcuts.log.warning('Failed to generate texture from screen');
            done(null, 0, 0);
        }

    }

/// Batch mode offscreen target

    #if !no_backend_docs
    /**
     * Render texture the main camera renders into in batch mode with a
     * graphics device (`-batchmode` without `-nographics`): there is no
     * screen to render to then. Screenshots read it. Null otherwise.
     */
    #end
    var batchTarget:RenderTexture = null;

    #if !no_backend_docs
    /**
     * Screenshots asked while the batch target is used: they are taken at
     * the next `flushBatchScreenshots()`, once the frame that asked for them
     * has been rendered.
     */
    #end
    var pendingBatchScreenshots:Array<()->Void> = [];

    #if !no_backend_docs
    /**
     * Batch mode with a graphics device only: makes the main camera render
     * into a render texture of the size of the screen in pixels (see
     * `CERAMIC_UNITY_SCREEN_SIZE`), created again when that size changes.
     * Returns false when there is no graphics device or no main camera.
     */
    #end
    @:allow(Main)
    function updateBatchTarget():Bool {

        var hasDevice:Bool = untyped __cs__('UnityEngine.SystemInfo.graphicsDeviceType != UnityEngine.Rendering.GraphicsDeviceType.Null');
        if (!hasDevice) {
            return false;
        }
        var hasCamera:Bool = untyped __cs__('UnityEngine.Camera.main != null');
        if (!hasCamera) {
            return false;
        }

        if (batchTarget == null || batchTarget.width != pixelWidth || batchTarget.height != pixelHeight) {
            var previous = batchTarget;
            // Same format as the screen of the template (8 bits per channel, no MSAA)
            batchTarget = untyped __cs__('new UnityEngine.RenderTexture({0}, {1}, 24, UnityEngine.RenderTextureFormat.ARGB32)', pixelWidth, pixelHeight);
            untyped __cs__('{0}.antiAliasing = 1', batchTarget);
            untyped __cs__('{0}.Create()', batchTarget);
            untyped __cs__('UnityEngine.Camera.main.targetTexture = {0}', batchTarget);
            if (previous != null) {
                untyped __cs__('{0}.Release()', previous);
                untyped __cs__('UnityEngine.Object.Destroy({0})', previous);
            }
        }
        return true;

    }

    #if !no_backend_docs
    /**
     * Renders the main camera into the batch target now (which runs the
     * Ceramic render pass, so the app update and its drawing).
     */
    #end
    @:allow(Main)
    function renderBatchTarget():Void {

        untyped __cs__('UnityEngine.Camera.main.Render()');

    }

    #if !no_backend_docs
    /**
     * Takes the screenshots asked since the last call. Called by
     * `Main.regularUpdate()` before the next app update, so the batch
     * target holds the frame that asked for them.
     */
    #end
    @:allow(Main)
    function flushBatchScreenshots():Void {

        if (pendingBatchScreenshots.length == 0) {
            return;
        }
        var screenshots = pendingBatchScreenshots;
        pendingBatchScreenshots = [];
        for (screenshot in screenshots) {
            screenshot();
        }

    }

    #if !no_backend_docs
    /**
     * Copies the batch target into a new readable texture (the caller
     * destroys it).
     */
    #end
    function readBatchTarget():Texture2D {

        var texture:Texture2D = untyped __cs__('new UnityEngine.Texture2D({0}, {1}, UnityEngine.TextureFormat.RGBA32, false)', batchTarget.width, batchTarget.height);
        var previousActive = RenderTexture.active;
        RenderTexture.active = batchTarget;
        texture.ReadPixels(new unityengine.Rect(0, 0, batchTarget.width, batchTarget.height), 0, 0, false);
        texture.Apply(false, false);
        RenderTexture.active = previousActive;
        return texture;

    }

}
