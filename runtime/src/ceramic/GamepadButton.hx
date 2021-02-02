package ceramic;

enum abstract GamepadButton(Int) from Int to Int {

    var A:GamepadButton = 0;

    var B:GamepadButton = 1;

    var X:GamepadButton = 2;

    var Y:GamepadButton = 3;

    var L1:GamepadButton = 4;

    var R1:GamepadButton = 5;

    var L2:GamepadButton = 6;

    var R2:GamepadButton = 7;

    var SELECT:GamepadButton = 8;

    var START:GamepadButton = 9;

    var L3:GamepadButton = 10;

    var R3:GamepadButton = 11;

    var DPAD_UP:GamepadButton = 12;

    var DPAD_DOWN:GamepadButton = 13;

    var DPAD_LEFT:GamepadButton = 14;

    var DPAD_RIGHT:GamepadButton = 15;

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
