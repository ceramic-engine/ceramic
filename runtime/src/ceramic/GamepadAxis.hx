package ceramic;

enum abstract GamepadAxis(Int) from Int to Int {

    var LEFT_X:GamepadAxis = 0;

    var LEFT_Y:GamepadAxis = 1;

    var RIGHT_X:GamepadAxis = 2;

    var RIGHT_Y:GamepadAxis = 3;

    inline function toString() {
        return switch this {
            case LEFT_X: 'LEFT_X';
            case LEFT_Y: 'LEFT_Y';
            case RIGHT_X: 'RIGHT_X';
            case RIGHT_Y: 'RIGHT_Y';
            case _: '$this';
        }
    }

}
