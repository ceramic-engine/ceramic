package ceramic.scriptable;

/**
 * Scriptable wrapper for MouseButton to expose mouse button constants to scripts.
 *
 * This class provides constants representing different mouse buttons that can be
 * detected in user input handling. In scripts, this type is exposed as
 * `MouseButton` (without the Scriptable prefix).
 *
 * These constants are used with mouse input events to determine which button
 * was pressed, released, or is being held down.
 *
 * ## Usage in Scripts
 *
 * ```haxe
 * // Handle mouse events
 * screen.onPointerDown(this, function(info) {
 *     if (info.button == MouseButton.LEFT) {
 *         trace("Left mouse button pressed");
 *     } else if (info.button == MouseButton.RIGHT) {
 *         trace("Right mouse button pressed");
 *     }
 * });
 *
 * // Check multiple buttons
 * screen.onPointerMove(this, function(info) {
 *     if (info.buttonId == MouseButton.LEFT) {
 *         trace("Dragging with left button");
 *     }
 * });
 *
 * // Handle middle button for panning
 * if (info.button == MouseButton.MIDDLE) {
 *     startPanning();
 * }
 * ```
 *
 * ## Button Types
 *
 * - **NONE**: No button pressed (value: 0)
 * - **LEFT**: Primary button, typically left click (value: 1)
 * - **MIDDLE**: Middle button/scroll wheel click (value: 2)
 * - **RIGHT**: Secondary button, typically right click (value: 3)
 * - **EXTRA1**: Additional button 4 (gaming mice)
 * - **EXTRA2**: Additional button 5 (gaming mice)
 *
 * @see ceramic.MouseButton The actual implementation
 * @see ceramic.TouchInfo For mouse/touch event data
 */
class ScriptableMouseButton {

    /**
     * No mouse buttons
     */
    public static var NONE:Int = 0;
    /**
     * Left mouse button
     */
    public static var LEFT:Int = 1;
    /**
     * Middle mouse button
     */
    public static var MIDDLE:Int = 2;
    /**
     * Right mouse button
     */
    public static var RIGHT:Int = 3;
    /**
     * Extra button pressed (4)
     */
    public static var EXTRA1:Int = 4;
    /**
     * Extra button pressed (5)
     */
    public static var EXTRA2:Int = 5;

}