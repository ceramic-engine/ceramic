package ceramic;

enum abstract ScreenOrientation(Int) from Int to Int {

    var NONE = 0;

    var PORTRAIT_UPRIGHT = 1 << 0;

    var PORTRAIT_UPSIDE_DOWN = 1 << 1;

    var LANDSCAPE_LEFT = 1 << 2;

    var LANDSCAPE_RIGHT = 1 << 3;

    /**
     * Both `PORTRAIT_UPRIGHT` and `PORTRAIT_UPSIDE_DOWN`
     */
    var PORTRAIT = (1 << 0) | (1 << 1);

    /**
     * Both `LANDSCAPE_LEFT` and `LANDSCAPE_RIGHT`
     */
    var LANDSCAPE = (1 << 2) | (1 << 3);

}
