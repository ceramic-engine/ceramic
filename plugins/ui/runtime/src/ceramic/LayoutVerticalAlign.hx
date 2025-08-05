package ceramic;

/**
 * Vertical alignment options for UI elements within their containers.
 * Controls how elements are positioned along the Y-axis when they have
 * extra vertical space available.
 * 
 * ```haxe
 * var view = new View();
 * view.layoutVerticalAlign = CENTER; // Center child vertically
 * view.layoutVerticalAlign = TOP;    // Align child to top edge
 * view.layoutVerticalAlign = BOTTOM; // Align child to bottom edge
 * ```
 * 
 * @see View
 * @see LinearLayout
 * @see LayersLayout
 * @see LayoutHorizontalAlign
 */
enum LayoutVerticalAlign {

    /**
     * Align element to the top edge of its container.
     * The element's top edge will be positioned at the container's top edge
     * (plus any padding/margin).
     */
    TOP;

    /**
     * Align element to the bottom edge of its container.
     * The element's bottom edge will be positioned at the container's bottom edge
     * (minus any padding/margin).
     */
    BOTTOM;

    /**
     * Center element vertically within its container.
     * The element will have equal space on both top and bottom sides,
     * appearing centered along the Y-axis.
     */
    CENTER;

}
