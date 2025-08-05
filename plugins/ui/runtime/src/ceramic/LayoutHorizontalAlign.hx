package ceramic;

/**
 * Horizontal alignment options for UI elements within their containers.
 * Controls how elements are positioned along the X-axis when they have
 * extra horizontal space available.
 * 
 * ```haxe
 * var view = new View();
 * view.layoutHorizontalAlign = CENTER; // Center child horizontally
 * view.layoutHorizontalAlign = LEFT;   // Align child to left edge
 * view.layoutHorizontalAlign = RIGHT;  // Align child to right edge
 * ```
 * 
 * @see View
 * @see LinearLayout
 * @see LayersLayout
 * @see LayoutVerticalAlign
 */
enum LayoutHorizontalAlign {

    /**
     * Align element to the left edge of its container.
     * The element's left edge will be positioned at the container's left edge
     * (plus any padding/margin).
     */
    LEFT;

    /**
     * Align element to the right edge of its container.
     * The element's right edge will be positioned at the container's right edge
     * (minus any padding/margin).
     */
    RIGHT;

    /**
     * Center element horizontally within its container.
     * The element will have equal space on both left and right sides,
     * appearing centered along the X-axis.
     */
    CENTER;

}
