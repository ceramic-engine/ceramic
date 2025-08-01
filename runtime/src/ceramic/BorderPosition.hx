package ceramic;

/**
 * Defines where a border is positioned relative to a shape's edge.
 * 
 * Used by various shape classes to control how borders/strokes are drawn
 * in relation to the defined dimensions.
 * 
 * @see Arc.borderPosition
 * @see Border.borderPosition
 */
enum BorderPosition {

    /**
     * Border is drawn inside the shape's boundaries.
     * 
     * The border width is subtracted from the shape's area,
     * keeping the outer dimensions unchanged. Useful when you
     * need the shape to fit exactly within specified bounds.
     * 
     * For Arc: Creates filled shapes when thickness equals radius.
     */
    INSIDE;

    /**
     * Border is drawn outside the shape's boundaries.
     * 
     * The border width extends beyond the shape's defined size,
     * increasing the total visual area. The shape's content area
     * remains at the specified dimensions.
     */
    OUTSIDE;

    /**
     * Border is centered on the shape's edge.
     * 
     * Half the border width extends inside, half outside.
     * This is often the most visually balanced option and
     * is the default for most shapes.
     */
    MIDDLE;

}
