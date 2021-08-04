package ceramic;

enum abstract SceneTransitionStatus(Int) from Int to Int {

    var NONE:Int = 0;

    var FADE_IN:Int = 1;

    var READY:Int = 2;

    var FADE_OUT:Int = 3;

    var DISABLED:Int = 4;

    function toString() {

        return switch this {
            case NONE: 'NONE';
            case FADE_IN: 'FADE_IN';
            case READY: 'READY';
            case FADE_OUT: 'FADE_OUT';
            case DISABLED: 'DISABLED';
            case _: '_';
        }

    }

}