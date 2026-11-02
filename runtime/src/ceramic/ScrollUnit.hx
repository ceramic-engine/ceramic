package ceramic;

/**
 * Unit of the deltas of a `Screen.mouseScroll` event.
 *
 * Pointing devices report scrolling either as a distance (trackpads, the
 * system's smooth scrolling of a mouse wheel, browsers with `deltaMode` 0)
 * or as a number of lines (notched mouse wheels, browsers with `deltaMode`
 * 1). An app that scrolls content converts lines with its own line height
 * (about 20 logical pixels in most text UIs) and uses pixel deltas as they
 * are, so both feel like the system's native scrolling.
 */
enum abstract ScrollUnit(Int) from Int to Int {

    /** The deltas are logical pixels (points), as reported by the device or the browser. */
    var PIXELS = 0;

    /** The deltas are lines; one line is one notch of a mouse wheel. */
    var LINES = 1;

}
