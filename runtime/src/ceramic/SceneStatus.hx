package ceramic;

enum abstract SceneStatus(Int) from Int to Int {

    var NONE:Int = 0;

    var PRELOAD:Int = 1;

    var LOAD:Int = 2;

    var CREATE:Int = 3;

    var FADE_IN:Int = 4;

    var READY:Int = 5;

    var FADE_OUT:Int = 6;

    var DISABLED:Int = 7;

    function toString() {

        return switch this {
            case NONE: 'NONE';
            case PRELOAD: 'PRELOAD';
            case LOAD: 'LOAD';
            case CREATE: 'CREATE';
            case FADE_IN: 'FADE_IN';
            case READY: 'READY';
            case FADE_OUT: 'FADE_OUT';
            case DISABLED: 'DISABLED';
            case _: '_';
        }

    }

}