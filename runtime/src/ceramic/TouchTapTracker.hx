package ceramic;

/**
 * Follows the touches of a touch screen and tells when one of them completes
 * a tap: the first touch of a gesture, released within `slop` pixels of
 * where it started, without being cancelled, and without the viewport height
 * changing during the gesture (a virtual keyboard opening or closing reflows
 * the layout, so the release position no longer refers to what the user
 * aimed at).
 *
 * Backends use it where a decision must be taken synchronously inside the
 * platform's touch release handler, such as showing a virtual keyboard on
 * the web (see `ceramic.Input.textEditingTapFilter`). Same rules as GPUI's
 * web platform (`touch_tap_candidate`, 8 px touch slop).
 */
class TouchTapTracker {

    /** Distance a touch may travel and still be a tap */
    public var slop:Float;

    var touchId:Int = -1;

    var startX:Float = 0;

    var startY:Float = 0;

    var viewportHeight:Float = 0;

    public function new(slop:Float = 8) {
        this.slop = slop;
    }

    /**
     * A touch started at (x, y), with the current viewport height.
     */
    public function touchDown(id:Int, x:Float, y:Float, viewportHeight:Float):Void {
        if (touchId == -1) {
            touchId = id;
            startX = x;
            startY = y;
            this.viewportHeight = viewportHeight;
        }
    }

    /**
     * A touch moved to (x, y).
     */
    public function touchMove(id:Int, x:Float, y:Float):Void {
        if (id == touchId && beyondSlop(x, y)) {
            touchId = -1;
        }
    }

    /**
     * A touch was cancelled by the system.
     */
    public function touchCancel(id:Int):Void {
        if (id == touchId) {
            touchId = -1;
        }
    }

    /**
     * A touch ended at (x, y), with the current viewport height. Returns
     * whether it completes a tap.
     */
    public function touchUp(id:Int, x:Float, y:Float, viewportHeight:Float):Bool {
        if (id != touchId)
            return false;
        touchId = -1;
        return !beyondSlop(x, y) && viewportHeight == this.viewportHeight;
    }

    inline function beyondSlop(x:Float, y:Float):Bool {
        final dx = x - startX;
        final dy = y - startY;
        return Math.sqrt(dx * dx + dy * dy) > slop;
    }

}
