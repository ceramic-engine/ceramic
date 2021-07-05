package ceramic;

enum ScreenScaling {

    /**
     * Screen width and height match target size in settings.
     * Result is scaled to fit into native screen bounds.
     */
    FIT;

    /**
     * Screen width and height match target size in settings.
     * Result is scaled to fill native screen area.
     */
    FILL;

    /**
     * Screen width and height are automatically resized
     * to exactly match native screen size.
     */
    RESIZE;

    /**
     * Either width or height is increased so that aspect ratio
     * becomes the same as as native screen's aspect ratio.
     * Result is scaled to fit exactly into native screen bounds.
     */
    FIT_RESIZE;

}
