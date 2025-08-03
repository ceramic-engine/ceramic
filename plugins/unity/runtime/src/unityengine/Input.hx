package unityengine;

/**
 * Provides access to input devices (mouse, keyboard, touch, gamepad).
 * Unity's legacy input system for reading player input.
 * 
 * In Ceramic's Unity backend, this class is used internally to
 * capture input events that are then forwarded to Ceramic's
 * cross-platform input handling system.
 * 
 * Note: This is Unity's legacy input system. The new Input System
 * package provides more features but isn't used by Ceramic's backend.
 * 
 * Common button indices:
 * - 0: Left mouse button / Primary touch
 * - 1: Right mouse button
 * - 2: Middle mouse button
 * 
 * @see Vector3
 * @see Vector2
 */
@:native('UnityEngine.Input')
extern class Input {

    /**
     * Current mouse position in screen coordinates.
     * 
     * Coordinates:
     * - x: Pixels from left edge (0 to Screen.width)
     * - y: Pixels from bottom edge (0 to Screen.height)  
     * - z: Always 0 for 2D mouse position
     * 
     * Note: Bottom-left origin differs from some systems.
     * Updated every frame when mouse moves.
     * 
     * @example Converting to Ceramic coordinates:
     * ```haxe
     * var mousePos = Input.mousePosition;
     * // Flip Y for top-left origin if needed
     * var ceramicY = Screen.height - mousePos.y;
     * ```
     */
    static var mousePosition(default, null):Vector3;

    /**
     * Mouse scroll wheel delta for current frame.
     * 
     * Values:
     * - x: Horizontal scroll (touchpad/mouse with tilt wheel)
     * - y: Vertical scroll (standard wheel)
     *      Positive = scroll up/forward
     *      Negative = scroll down/backward
     * 
     * Typically ranges from -1 to 1 per frame.
     * Returns (0,0) when no scrolling occurred.
     * 
     * Platform notes:
     * - macOS: May have momentum scrolling
     * - Windows: Usually discrete steps
     * - Touch: Two-finger swipe gestures
     */
    static var mouseScrollDelta(default, null):Vector2;

    /**
     * Returns whether the specified mouse button is currently held down.
     * True every frame while button is pressed.
     * 
     * @param button Mouse button index:
     *              0 = Left button (primary)
     *              1 = Right button (secondary)
     *              2 = Middle button (wheel click)
     *              3+ = Additional buttons
     * @return True if button is currently pressed
     * 
     * @example Detecting mouse drag:
     * ```haxe
     * if (Input.GetMouseButton(0)) {
     *     // Left button held - handle dragging
     * }
     * ```
     * 
     * Note: Use GetMouseButtonDown/Up for single frame events.
     */
    static function GetMouseButton(button:Int):Bool;

}
