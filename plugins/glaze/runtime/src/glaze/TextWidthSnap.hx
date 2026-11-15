// Original code for Glaze (not a port): how the measured width of a text is rounded up (ADD-015 in docs/DEVIATIONS.md).
package glaze;

/**
 * How the width of a text is rounded up when its box is measured
 * (`Window.textWidthSnap`).
 */
enum abstract TextWidthSnap(Int) {

    /**
     * To a whole logical pixel, as GPUI does (`elements/text.rs`: the
     * measured width is `ceil()`ed). The default.
     */
    var WholePixel = 0;

    /**
     * To a device pixel only (the rounding every measured leaf gets from
     * the layout engine): half a logical pixel at a scale factor of 2. The
     * box is still at least as wide as its text and still ends on the
     * device pixel grid. At a scale factor of 1 this is `WholePixel`.
     */
    var DevicePixel = 1;

}
