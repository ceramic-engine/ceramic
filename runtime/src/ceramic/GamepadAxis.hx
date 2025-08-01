package ceramic;

/**
 * Represents gamepad analog stick and trigger axes.
 * 
 * This enum abstract defines the standard axes available on modern gamepads:
 * - Left analog stick (X and Y axes)
 * - Right analog stick (X and Y axes)
 * - Left and right triggers (analog pressure)
 * 
 * Axis values typically range from -1.0 to 1.0 for sticks (centered at 0.0)
 * and 0.0 to 1.0 for triggers (fully released at 0.0).
 * 
 * @see Input
 */
enum abstract GamepadAxis(Int) from Int to Int {

    /**
     * Left analog stick horizontal axis.
     * Values range from -1.0 (left) to 1.0 (right), centered at 0.0.
     */
    var LEFT_X:GamepadAxis = 0;

    /**
     * Left analog stick vertical axis.
     * Values range from -1.0 (up) to 1.0 (down), centered at 0.0.
     */
    var LEFT_Y:GamepadAxis = 1;

    /**
     * Right analog stick horizontal axis.
     * Values range from -1.0 (left) to 1.0 (right), centered at 0.0.
     */
    var RIGHT_X:GamepadAxis = 2;

    /**
     * Right analog stick vertical axis.
     * Values range from -1.0 (up) to 1.0 (down), centered at 0.0.
     */
    var RIGHT_Y:GamepadAxis = 3;

    /**
     * Left trigger analog pressure.
     * Values range from 0.0 (fully released) to 1.0 (fully pressed).
     */
    var LEFT_TRIGGER:GamepadAxis = 4;

    /**
     * Right trigger analog pressure.
     * Values range from 0.0 (fully released) to 1.0 (fully pressed).
     */
    var RIGHT_TRIGGER:GamepadAxis = 5;

    /**
     * Returns a string representation of this gamepad axis.
     * @return The axis name as a string (e.g., "LEFT_X", "RIGHT_TRIGGER")
     */
    inline function toString() {
        return switch this {
            case LEFT_X: 'LEFT_X';
            case LEFT_Y: 'LEFT_Y';
            case RIGHT_X: 'RIGHT_X';
            case RIGHT_Y: 'RIGHT_Y';
            case LEFT_TRIGGER: 'LEFT_TRIGGER';
            case RIGHT_TRIGGER: 'RIGHT_TRIGGER';
            case _: '$this';
        }
    }

}
