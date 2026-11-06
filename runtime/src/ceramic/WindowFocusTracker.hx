package ceramic;

/**
 * Decides whether the app window counts as focused (`screen.windowFocused`)
 * from what a platform reports: its focus events, its pause events (the app
 * going to background on mobile) and whether the virtual keyboard of the app
 * is visible. A backend feeds it and emits `windowFocusChange` when a call
 * returns `true`.
 *
 * - A paused app is never focused.
 * - While the virtual keyboard of the app is visible, a focus loss is not
 *   reported: on Android the keyboard takes the focus of the app (Unity
 *   sends `OnApplicationFocus(false)` when it opens), and deactivating the
 *   window would blur the text field the keyboard edits.
 */
class WindowFocusTracker {

    /** Whether the window counts as focused. */
    public var focused(default, null):Bool;

    /** The focus last reported by the platform. */
    public var systemFocused(default, null):Bool;

    /** Whether the app is paused (in background). */
    public var paused(default, null):Bool = false;

    /** Whether the virtual keyboard of the app is visible. */
    public var keyboardVisible(default, null):Bool = false;

    public function new(systemFocused:Bool = true) {

        this.systemFocused = systemFocused;
        focused = compute();

    }

    /**
     * The platform gave or took the focus.
     * @return Whether `focused` changed
     */
    public function setSystemFocused(value:Bool):Bool {

        systemFocused = value;
        return refresh();

    }

    /**
     * The app was paused (sent to background) or resumed.
     * @return Whether `focused` changed
     */
    public function setPaused(value:Bool):Bool {

        paused = value;
        return refresh();

    }

    /**
     * The virtual keyboard of the app was shown or hidden.
     * @return Whether `focused` changed
     */
    public function setKeyboardVisible(value:Bool):Bool {

        keyboardVisible = value;
        return refresh();

    }

    inline function compute():Bool {

        return !paused && (systemFocused || keyboardVisible);

    }

    function refresh():Bool {

        final value = compute();
        if (value == focused) return false;
        focused = value;
        return true;

    }

}
