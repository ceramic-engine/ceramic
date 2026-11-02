// Ported from gpui-pre-web 0.3.10: src/events.rs (click counting, key names, wheel deltas, modifiers)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: rewritten in Haxe on top of Ceramic's input events. See NOTICE.md.
package gpui;

import ceramic.Key;
import ceramic.KeyCode;
import ceramic.KeyModifiers;

/**
 * The platform input bridge: converts Ceramic input (screen mouse events,
 * keyboard events, app focus) into GPUI `PlatformInput` and dispatches it
 * to the right `Window`, like a platform window would (GPUI's web
 * `events.rs`, Ceramic's `ImGuiSystem.bindInput()`).
 *
 * - Mouse events go to the topmost window whose renderable is under the
 *   pointer (in reverse creation order), with coordinates converted to the
 *   window space with `renderable.screenToVisual()` (visual transform and
 *   window size: window space is logical pixels, density is handled by the
 *   renderable's `sceneScale`). While a button is pressed, events keep going
 *   to the window it was pressed on. Moving from a window to another sends
 *   `MouseExitEvent` to the previous one.
 * - Click counts follow GPUI's web platform: a press within 400ms and 5px of
 *   the previous one increments the count.
 * - Wheel deltas are pixels; Ceramic's positive y scrolls down, GPUI's
 *   positive y scrolls up, so deltas are negated.
 * - Touches become raw `TouchEvent`s, like GPUI's web platform turns touch
 *   pointer events into `PlatformInput::Touch` (events.rs:236-600): GPUI's
 *   gesture recognizer in the window makes taps, pans with momentum, long
 *   presses and touch drags of them. Each touch gets an identifier that is
 *   never reused and goes to the window it started on. A cancelled touch
 *   (Ceramic `touchCancel`, followed by its `touchUp`) is `Cancelled`.
 * - Virtual keyboard: Ceramic asks, inside the browser's touch release
 *   handler, whether a tap lands on a text input
 *   (`input.textEditingTapFilter`); the answer comes from the text inputs
 *   painted in the last frame (`Window.textInputRegionAt`), so that the web
 *   backend can focus its hidden field within the gesture, as mobile
 *   browsers require (GPUI web events.rs:357-370, 497-530).
 * - Keyboard events go to the active window: the last window pressed with
 *   the mouse, or the last bound window. Modifier changes are sent as
 *   `ModifiersChangedEvent` first; modifier only keys are not sent as key
 *   events (like the web platform).
 * - The app going to background deactivates the windows (focus events report
 *   an empty focus path), coming back reactivates the active one.
 * - Text input: each bound window gets a `TextInputBridge` (its
 *   `textInputPlatform`, unless one is already set) that receives the key
 *   downs and Ceramic's `textCommit` / `textComposition` events, and starts or
 *   stops Ceramic text editing when an input handler gains or loses focus.
 *   Ctrl + alt with a character (AltGr, outside macOS) is dispatched with
 *   `preferCharacterInput`.
 *
 * Windows are bound when created with `bindInput: true` (the default).
 */
class GpuiInput extends ceramic.Entity {

    static var instance:Null<GpuiInput> = null;

    static final boundWindows:Array<Window> = [];

    /**
     * Binds the given window to Ceramic input.
     */
    public static function bind(window:Window):Void {
        if (boundWindows.indexOf(window) != -1)
            return;
        boundWindows.push(window);
        if (window.textInputPlatform == null) {
            window.textInputPlatform = new TextInputBridge(window);
        }
        if (instance == null || instance.destroyed) {
            instance = new GpuiInput();
        }
        if (instance.activeWindow == null) {
            instance.activeWindow = window;
        }
    }

    /**
     * Unbinds the given window.
     */
    public static function unbind(window:Window):Void {
        boundWindows.remove(window);
        final bridge = bridgeOf(window);
        if (bridge != null) {
            bridge.textInputStateChanged(FocusLost);
        }
        if (instance != null) {
            if (instance.activeWindow == window) instance.activeWindow = boundWindows.length > 0 ? boundWindows[boundWindows.length - 1] : null;
            if (instance.hoveredWindow == window) instance.hoveredWindow = null;
            if (instance.pressedWindow == window) instance.pressedWindow = null;
        }
    }

    /**
     * Shows the given cursor style (Ceramic `screen.cursor`).
     */
    public static function setCursor(style:CursorStyle):Void {
        final app = ceramic.App.app;
        if (app == null || app.screen == null)
            return;
        app.screen.cursor = (cast style : Int);
    }

    static function bridgeOf(window:Null<Window>):Null<TextInputBridge> {
        if (window == null || window.isDestroyed())
            return null;
        final platform = window.textInputPlatform;
        return Std.isOfType(platform, TextInputBridge) ? cast platform : null;
    }

    /**
     * The window receiving keyboard events.
     */
    public var activeWindow(default, null):Null<Window> = null;

    var hoveredWindow:Null<Window> = null;

    var pressedWindow:Null<Window> = null;

    var pressedButton:Null<MouseButton> = null;

    var lastModifiers:Modifiers = Modifiers.none();

    var lastCapslock:Bool = false;

    final heldKeys:Map<Int, Bool> = new Map();

    // Click state (GPUI web `ClickState`)
    var lastClickX:Float = 0;
    var lastClickY:Float = 0;
    var lastClickTime:Float = -1000;
    var clickCount:Int = 0;

    final point:ceramic.Point = new ceramic.Point();

    /** Next touch identifier (never reused) */
    var nextTouchId:Int = 1;

    /** Active touches: Ceramic touch index to GPUI touch identifier */
    final touchIds:Map<Int, Int> = new Map();

    /** Active touches: Ceramic touch index to the window the touch started on */
    final touchWindows:Map<Int, Window> = new Map();

    function new() {
        super();
        final app = ceramic.App.app;
        final screen = app.screen;
        screen.onMouseMove(this, handleMouseMove);
        screen.onMouseDown(this, handleMouseDown);
        screen.onMouseUp(this, handleMouseUp);
        screen.onMouseScroll(this, handleMouseScroll);
        screen.onTouchDown(this, handleTouchDown);
        screen.onTouchMove(this, handleTouchMove);
        screen.onTouchUp(this, handleTouchUp);
        screen.onTouchCancel(this, handleTouchCancel);
        app.input.textEditingTapFilter = textEditingTapFilter;
        app.input.onKeyDown(this, key -> handleKey(key, true));
        app.input.onKeyUp(this, key -> handleKey(key, false));
        app.input.onTextCommit(this, text -> {
            final bridge = bridgeOf(activeWindow);
            if (bridge != null) bridge.textCommit(text);
        });
        app.input.onTextComposition(this, (text, start, length) -> {
            final bridge = bridgeOf(activeWindow);
            if (bridge != null) bridge.textComposition(text, start, length);
        });
        // Input events are emitted before the update: end of the batch
        app.onPreUpdate(this, _ -> {
            for (window in boundWindows) {
                final bridge = bridgeOf(window);
                if (bridge != null) bridge.flush();
            }
        });
        app.onBeginEnterBackground(this, () -> {
            heldKeys.clear();
            for (window in boundWindows) window.setActive(false);
        });
        app.onBeginEnterForeground(this, () -> {
            if (activeWindow != null) activeWindow.setActive(true);
        });
    }

/// Mouse

    function windowAt(x:Float, y:Float):Null<Window> {
        var i = boundWindows.length - 1;
        while (i >= 0) {
            final window = boundWindows[i];
            final renderable = window.renderable;
            if (!window.isDestroyed() && renderable.computedVisible && renderable.hits(x, y)) {
                return window;
            }
            i--;
        }
        return null;
    }

    inline function toWindow(window:Window, x:Float, y:Float):Point {
        window.renderable.screenToVisual(x, y, point);
        return new Point(point.x, point.y);
    }

    function currentModifiers():Modifiers {
        final mods:KeyModifiers = ceramic.App.app.input.modifiers;
        return Modifiers.of(mods.ctrl, mods.alt, mods.shift, mods.meta, false);
    }

    function updateHovered(window:Null<Window>, x:Float, y:Float):Void {
        if (window == hoveredWindow)
            return;
        final previous = hoveredWindow;
        hoveredWindow = window;
        if (previous != null && !previous.isDestroyed()) {
            previous.hovered = false;
            previous.dispatchEvent(new MouseExitEvent(toWindow(previous, x, y), pressedButton, currentModifiers()));
        }
        if (window != null) {
            window.hovered = true;
            window.resetCursorStyle();
        }
        else {
            setCursor(Arrow);
        }
    }

    function handleMouseMove(x:Float, y:Float):Void {
        final under = windowAt(x, y);
        updateHovered(under, x, y);
        final target = pressedWindow != null ? pressedWindow : under;
        if (target == null)
            return;
        target.dispatchEvent(new MouseMoveEvent(toWindow(target, x, y), pressedButton, currentModifiers()));
    }

    static function mouseButton(buttonId:Int):MouseButton {
        // Ceramic: LEFT = 0, MIDDLE = 1, RIGHT = 2 (like the DOM)
        return switch buttonId {
            case 1: Middle;
            case 2: Right;
            case 3: NavigateBack;
            case 4: NavigateForward;
            case _: Left;
        }
    }

    function registerClick(x:Float, y:Float):Int {
        final time = haxe.Timer.stamp() * 1000.0;
        final dx = x - lastClickX;
        final dy = y - lastClickY;
        final distance = Math.sqrt(dx * dx + dy * dy);
        if (time - lastClickTime < 400.0 && distance < 5.0) {
            clickCount++;
        }
        else {
            clickCount = 1;
        }
        lastClickX = x;
        lastClickY = y;
        lastClickTime = time;
        return clickCount;
    }

    function handleMouseDown(buttonId:Int, x:Float, y:Float):Void {
        final window = windowAt(x, y);
        updateHovered(window, x, y);
        if (window == null)
            return;
        final button = mouseButton(buttonId);
        pressedButton = button;
        pressedWindow = window;
        if (activeWindow != window) {
            if (activeWindow != null && !activeWindow.isDestroyed()) activeWindow.setActive(false);
            activeWindow = window;
        }
        window.setActive(true);
        final position = toWindow(window, x, y);
        final count = registerClick(position.x, position.y);
        window.dispatchEvent(new MouseDownEvent(button, position, currentModifiers(), count, false));
    }

    function handleMouseUp(buttonId:Int, x:Float, y:Float):Void {
        final window = pressedWindow != null ? pressedWindow : windowAt(x, y);
        pressedWindow = null;
        pressedButton = null;
        if (window == null || window.isDestroyed())
            return;
        window.dispatchEvent(new MouseUpEvent(mouseButton(buttonId), toWindow(window, x, y), currentModifiers(), clickCount));
        updateHovered(windowAt(x, y), x, y);
    }

    /**
     * Ceramic's `mouseScroll` carries the deltas as the device reports them,
     * which is what GPUI's platforms hand to `ScrollWheelEvent`: pixels for
     * a precise device (`ScrollDelta::Pixels`, trackpads, the browser's
     * `deltaMode` 0) and lines for a notched wheel (`ScrollDelta::Lines`,
     * converted with the line height where the scroll is applied). GPUI's
     * deltas are positive when the content moves down or right, the opposite
     * of the browser sign Ceramic uses, hence the negation (like the web
     * platform of GPUI).
     */
    function handleMouseScroll(deltaX:Float, deltaY:Float, unit:ceramic.ScrollUnit):Void {
        final screen = ceramic.App.app.screen;
        final window = windowAt(screen.mouseX, screen.mouseY);
        if (window == null)
            return;
        final position = toWindow(window, screen.mouseX, screen.mouseY);
        window.dispatchEvent(new ScrollEvent(position, scrollDeltaOf(deltaX, deltaY, unit), currentModifiers(), Moved));
    }

    /** GPUI's `ScrollDelta` for a Ceramic `mouseScroll` (see `handleMouseScroll`). */
    public static function scrollDeltaOf(deltaX:Float, deltaY:Float, unit:ceramic.ScrollUnit):ScrollDelta {
        return unit == ceramic.ScrollUnit.LINES
            ? ScrollDelta.Lines(new Point(-deltaX, -deltaY))
            : ScrollDelta.Pixels(new Point(-deltaX, -deltaY));
    }

/// Touch

    function handleTouchDown(touchIndex:Int, x:Float, y:Float):Void {
        final window = windowAt(x, y);
        if (window == null)
            return;
        final id = nextTouchId++;
        touchIds.set(touchIndex, id);
        touchWindows.set(touchIndex, window);
        if (activeWindow != window) {
            if (activeWindow != null && !activeWindow.isDestroyed()) activeWindow.setActive(false);
            activeWindow = window;
        }
        window.setActive(true);
        window.dispatchEvent(new TouchEvent(id, Started, toWindow(window, x, y)));
    }

    function handleTouchMove(touchIndex:Int, x:Float, y:Float):Void {
        dispatchTouch(touchIndex, Moved, x, y, false);
    }

    function handleTouchUp(touchIndex:Int, x:Float, y:Float):Void {
        dispatchTouch(touchIndex, Ended, x, y, true);
    }

    function handleTouchCancel(touchIndex:Int, x:Float, y:Float):Void {
        dispatchTouch(touchIndex, Cancelled, x, y, true);
    }

    function dispatchTouch(touchIndex:Int, phase:TouchPhase, x:Float, y:Float, ends:Bool):Void {
        final id = touchIds.get(touchIndex);
        if (id == null)
            return;
        final window = touchWindows.get(touchIndex);
        if (ends) {
            touchIds.remove(touchIndex);
            touchWindows.remove(touchIndex);
        }
        if (window == null || window.isDestroyed())
            return;
        window.dispatchEvent(new TouchEvent(id, phase, toWindow(window, x, y)));
    }

    /**
     * Ceramic's `textEditingTapFilter`: whether a tap at (x, y) (screen
     * coordinates) lands on a text input accepting text in the last frame of
     * the window under it. When it does, that input's text assistance
     * preferences are applied first, so the keyboard opens configured for it.
     */
    function textEditingTapFilter(x:Float, y:Float):Bool {
        final window = windowAt(x, y);
        if (window == null)
            return false;
        final position = toWindow(window, x, y);
        return window.app.update(cx -> {
            final region = window.textInputRegionAt(position, cx);
            if (region == null)
                return false;
            TextInputBridge.applyConfiguration(region.handler.textInputConfiguration(window, cx));
            return true;
        });
    }

/// Keyboard

    function handleKey(key:Key, down:Bool):Void {
        final window = activeWindow;
        if (window == null || window.isDestroyed())
            return;

        final mods = key.modifiers;
        final modifiers = Modifiers.of(mods.ctrl, mods.alt, mods.shift, mods.meta, false);
        final capslock = mods.capsLock;
        if (modifiers != lastModifiers || capslock != lastCapslock) {
            lastModifiers = modifiers;
            lastCapslock = capslock;
            window.dispatchEvent(new ModifiersChangedEvent(modifiers, capslock));
        }

        final name = gpuiKey(key.keyCode);
        if (name == null || isModifierOnlyKey(name))
            return;

        final keyChar = computeKeyChar(name, key.keyChar, modifiers);
        final keystroke = new Keystroke(modifiers, name, keyChar);
        final code:Int = key.keyCode;
        if (down) {
            final isHeld = heldKeys.exists(code);
            heldKeys.set(code, true);
            // AltGr is reported as control + alt with the composed character
            final preferCharacterInput = keyChar != null && modifiers.control && modifiers.alt && !OperatingSystem.current.isMac();
            final event = new KeyDownEvent(keystroke, isHeld, preferCharacterInput);
            final bridge = bridgeOf(window);
            if (bridge != null) {
                bridge.keyDown(event);
            }
            else {
                window.dispatchEvent(event);
            }
        }
        else {
            heldKeys.remove(code);
            window.dispatchEvent(new KeyUpEvent(keystroke));
        }
    }

    static function isModifierOnlyKey(key:String):Bool {
        return switch key {
            case 'control' | 'alt' | 'shift' | 'platform' | 'capslock' | 'compose' | 'process': true;
            case _: false;
        }
    }

    /**
     * GPUI web `compute_key_char`: no character for command / control
     * combinations (except AltGr, reported as control + alt).
     */
    static function computeKeyChar(key:String, keyChar:Null<String>, modifiers:Modifiers):Null<String> {
        if ((modifiers.platform || modifiers.control) && !(modifiers.control && modifiers.alt)) {
            return null;
        }
        if (key == 'space') {
            return ' ';
        }
        return keyChar;
    }

    /**
     * Converts a Ceramic key code to a GPUI key name (lower case, like
     * `Keystroke.key`), or `null` for keys GPUI has no name for.
     */
    public static function gpuiKey(keyCode:KeyCode):Null<String> {
        return switch keyCode {
            case ENTER | KP_ENTER: 'enter';
            case ESCAPE: 'escape';
            case BACKSPACE: 'backspace';
            case TAB: 'tab';
            case SPACE: 'space';
            case DELETE: 'delete';
            case INSERT: 'insert';
            case HOME: 'home';
            case END: 'end';
            case PAGEUP: 'pageup';
            case PAGEDOWN: 'pagedown';
            case LEFT: 'left';
            case RIGHT: 'right';
            case UP: 'up';
            case DOWN: 'down';
            case LCTRL | RCTRL: 'control';
            case LSHIFT | RSHIFT: 'shift';
            case LALT | RALT: 'alt';
            case LMETA | RMETA: 'platform';
            case CAPSLOCK: 'capslock';
            case F1: 'f1';
            case F2: 'f2';
            case F3: 'f3';
            case F4: 'f4';
            case F5: 'f5';
            case F6: 'f6';
            case F7: 'f7';
            case F8: 'f8';
            case F9: 'f9';
            case F10: 'f10';
            case F11: 'f11';
            case F12: 'f12';
            case F13: 'f13';
            case F14: 'f14';
            case F15: 'f15';
            case F16: 'f16';
            case F17: 'f17';
            case F18: 'f18';
            case F19: 'f19';
            case F20: 'f20';
            case F21: 'f21';
            case F22: 'f22';
            case F23: 'f23';
            case F24: 'f24';
            case KP_0: '0';
            case KP_1: '1';
            case KP_2: '2';
            case KP_3: '3';
            case KP_4: '4';
            case KP_5: '5';
            case KP_6: '6';
            case KP_7: '7';
            case KP_8: '8';
            case KP_9: '9';
            case KP_PERIOD: '.';
            case KP_DIVIDE: '/';
            case KP_MULTIPLY: '*';
            case KP_MINUS: '-';
            case KP_PLUS: '+';
            case KP_EQUALS: '=';
            case _:
                final code:Int = keyCode;
                // Printable keys: SDL key codes are the unshifted character
                if (code >= 32 && code < 127) {
                    String.fromCharCode(code).toLowerCase();
                }
                else {
                    null;
                }
        }
    }

}
