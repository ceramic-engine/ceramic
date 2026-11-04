package ceramic;

/**
 * Converts the raw wheel deltas of a platform, one event at a time, into the
 * deltas of `ceramic.Screen.mouseScroll`: browser sign (positive when the
 * content moves up or left), lines for notched wheels, pixels (points) for
 * precise devices.
 *
 * The raw y is positive away from the user (SDL, Unity's Input System), so
 * `deltaY` is the opposite of the raw y; `deltaX` keeps the raw sign.
 *
 * Two rules:
 *
 * - `fractionalIsPrecise` (macOS, the rule of clay's SDL runtime): a whole
 *   value comes from a notched wheel and is taken as lines; a fractional
 *   value comes from a precise device (trackpad, Magic Mouse, smooth
 *   scrolling) reported in tenths of points, taken as pixels once multiplied
 *   by `pixelsPerUnit`. A precise gesture can still produce a whole value now
 *   and then: once a fractional value was seen, the events of the next
 *   `preciseStickiness` seconds stay pixels.
 * - otherwise (Windows, Linux): always lines, fractional on high resolution
 *   wheels.
 *
 * In both cases the raw values are first divided by `unitsPerLine` (120 for
 * the raw values of Windows, 1 elsewhere).
 */
class MouseScrollConverter {

    /** Whether a fractional value means a precise device (macOS rule). */
    public var fractionalIsPrecise:Bool;

    /** Raw units per line (one notch of a classic wheel). */
    public var unitsPerLine:Float;

    /** Pixels per unit of a precise device (clay: 10, SDL gives points times 0.1 on macOS). */
    public var pixelsPerUnit:Float = 10.0;

    /** Seconds during which events stay pixels after a fractional value. */
    public var preciseStickiness:Float = 0.5;

    /** Horizontal delta of the last converted event. */
    public var deltaX(default, null):Float = 0;

    /** Vertical delta of the last converted event. */
    public var deltaY(default, null):Float = 0;

    /** Unit of the last converted event. */
    public var unit(default, null):ScrollUnit = ScrollUnit.LINES;

    var hasSeenPrecise:Bool = false;

    var lastPreciseTime:Float = 0;

    public function new(fractionalIsPrecise:Bool, unitsPerLine:Float = 1.0) {

        this.fractionalIsPrecise = fractionalIsPrecise;
        this.unitsPerLine = unitsPerLine;

    }

    /**
     * Converts one raw event. The result is in `deltaX`, `deltaY` and `unit`.
     * @param rawX Raw horizontal value of the event
     * @param rawY Raw vertical value of the event (positive away from the user)
     * @param time Time of the event in seconds (any clock that only goes forward)
     */
    public function convert(rawX:Float, rawY:Float, time:Float):Void {

        final x = unitsPerLine != 1.0 ? rawX / unitsPerLine : rawX;
        final y = unitsPerLine != 1.0 ? rawY / unitsPerLine : rawY;

        if (fractionalIsPrecise) {
            final whole = x == Math.fround(x) && y == Math.fround(y);
            if (!whole) {
                hasSeenPrecise = true;
                lastPreciseTime = time;
            }
            if (whole && (!hasSeenPrecise || time - lastPreciseTime > preciseStickiness)) {
                deltaX = x;
                deltaY = -y;
                unit = ScrollUnit.LINES;
            }
            else {
                deltaX = x * pixelsPerUnit;
                deltaY = -y * pixelsPerUnit;
                unit = ScrollUnit.PIXELS;
            }
        }
        else {
            deltaX = x;
            deltaY = -y;
            unit = ScrollUnit.LINES;
        }

        // No negative zero
        if (deltaX == 0) deltaX = 0;
        if (deltaY == 0) deltaY = 0;

    }

    /** Forgets the precise device seen recently. */
    public function reset():Void {

        hasSeenPrecise = false;
        lastPreciseTime = 0;

    }

}
