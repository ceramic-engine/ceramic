package ceramic;

/**
 * General-purpose alignment enumeration for UI layouts.
 * Provides directional alignment options that can be used in various
 * layout contexts for positioning child elements.
 * 
 * @see View
 * @see LinearLayout
 * @see LayersLayout
 */
enum LayoutAlign {

    /**
     * Align to the left edge.
     * When used horizontally, positions element at the leftmost position.
     */
    LEFT;

    /**
     * Align to the right edge.
     * When used horizontally, positions element at the rightmost position.
     */
    RIGHT;

    /**
     * Align to the top edge.
     * When used vertically, positions element at the topmost position.
     */
    TOP;

    /**
     * Align to the bottom edge.
     * When used vertically, positions element at the bottommost position.
     */
    BOTTOM;

    /**
     * Center alignment.
     * Centers the element along the relevant axis (horizontal or vertical).
     * When used in layouts, provides equal spacing on both sides.
     */
    CENTER;

}
