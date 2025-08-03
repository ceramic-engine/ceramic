package ceramic;

/**
 * Defines scaling modes for ImageView to control how images are sized within their bounds.
 * 
 * @see ImageView
 */
enum ImageViewScaling {

    /**
     * Uses a custom scale factor specified by imageScale property.
     * The image is scaled by the exact factor regardless of view bounds.
     * Useful for pixel-perfect rendering or specific zoom levels.
     * 
     * @example
     * ```haxe
     * imageView.scaling = CUSTOM;
     * imageView.imageScale = 2.0; // Double size
     * ```
     */
    CUSTOM;

    /**
     * Scales the image to fit within the view bounds while maintaining aspect ratio.
     * The entire image will be visible, but there may be empty space if the
     * aspect ratios don't match. This is the default mode.
     * 
     * @example
     * ```haxe
     * imageView.scaling = FIT;
     * // Image will be fully visible within bounds
     * ```
     */
    FIT;

    /**
     * Scales the image to fill the entire view bounds while maintaining aspect ratio.
     * The image will cover the entire area, but parts may be cropped if the
     * aspect ratios don't match. Centers the image and crops edges as needed.
     * 
     * @example
     * ```haxe
     * imageView.scaling = FILL;
     * // Image will cover entire view, may be cropped
     * ```
     */
    FILL;

}

