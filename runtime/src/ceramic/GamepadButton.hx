package ceramic;

/**
 * Represents gamepad button mappings.
 * 
 * This enum abstract defines the standard buttons available on modern gamepads,
 * following a common layout similar to Xbox/PlayStation controllers:
 * - Face buttons (A, B, X, Y)
 * - Shoulder buttons (L1/R1) and triggers (L2/R2)
 * - Control buttons (SELECT/BACK, START/MENU)
 * - Analog stick buttons (L3/R3 - pressing the sticks)
 * - Directional pad (D-Pad) buttons
 * 
 * Note: Button labels follow Xbox conventions but map to equivalent
 * buttons on other controllers (e.g., A maps to Cross on PlayStation).
 * 
 * @see Input
 */
enum abstract GamepadButton(Int) from Int to Int {

    /**
     * A button (bottom face button).
     * Maps to Cross on PlayStation, B on Nintendo.
     */
    var A:GamepadButton = 0;

    /**
     * B button (right face button).
     * Maps to Circle on PlayStation, A on Nintendo.
     */
    var B:GamepadButton = 1;

    /**
     * X button (left face button).
     * Maps to Square on PlayStation, Y on Nintendo.
     */
    var X:GamepadButton = 2;

    /**
     * Y button (top face button).
     * Maps to Triangle on PlayStation, X on Nintendo.
     */
    var Y:GamepadButton = 3;

    /**
     * Left shoulder button (bumper).
     * Maps to L1 on PlayStation, L on Nintendo.
     */
    var L1:GamepadButton = 4;

    /**
     * Right shoulder button (bumper).
     * Maps to R1 on PlayStation, R on Nintendo.
     */
    var R1:GamepadButton = 5;

    /**
     * Left trigger button (digital press).
     * Maps to L2 on PlayStation, ZL on Nintendo.
     * Note: For analog trigger values, use GamepadAxis.LEFT_TRIGGER.
     */
    var L2:GamepadButton = 6;

    /**
     * Right trigger button (digital press).
     * Maps to R2 on PlayStation, ZR on Nintendo.
     * Note: For analog trigger values, use GamepadAxis.RIGHT_TRIGGER.
     */
    var R2:GamepadButton = 7;

    /**
     * Select/Back button.
     * Maps to Share on PlayStation, Minus on Nintendo.
     */
    var SELECT:GamepadButton = 8;

    /**
     * Start/Menu button.
     * Maps to Options on PlayStation, Plus on Nintendo.
     */
    var START:GamepadButton = 9;

    /**
     * Left analog stick button (L3).
     * Activated by pressing down on the left analog stick.
     */
    var L3:GamepadButton = 10;

    /**
     * Right analog stick button (R3).
     * Activated by pressing down on the right analog stick.
     */
    var R3:GamepadButton = 11;

    /**
     * D-Pad up button.
     * Part of the directional pad for discrete directional input.
     */
    var DPAD_UP:GamepadButton = 12;

    /**
     * D-Pad down button.
     * Part of the directional pad for discrete directional input.
     */
    var DPAD_DOWN:GamepadButton = 13;

    /**
     * D-Pad left button.
     * Part of the directional pad for discrete directional input.
     */
    var DPAD_LEFT:GamepadButton = 14;

    /**
     * D-Pad right button.
     * Part of the directional pad for discrete directional input.
     */
    var DPAD_RIGHT:GamepadButton = 15;

    /**
     * Returns a string representation of this gamepad button.
     * @return The button name as a string (e.g., "A", "START", "DPAD_UP")
     */
    inline function toString() {
        return switch this {
            case A: 'A';
            case B: 'B';
            case X: 'X';
            case Y: 'Y';
            case L1: 'L1';
            case R1: 'R1';
            case L2: 'L2';
            case R2: 'R2';
            case SELECT: 'SELECT';
            case START: 'START';
            case L3: 'L3';
            case R3: 'R3';
            case DPAD_UP: 'DPAD_UP';
            case DPAD_DOWN: 'DPAD_DOWN';
            case DPAD_LEFT: 'DPAD_LEFT';
            case DPAD_RIGHT: 'DPAD_RIGHT';
            case _: '$this';
        }
    }

}
