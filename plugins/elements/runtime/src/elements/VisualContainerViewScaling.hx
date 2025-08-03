package elements;

/**
 * Defines the scaling behavior options for VisualContainerView.
 * 
 * This enum specifies how a visual element should be scaled within its container,
 * providing different strategies for handling size relationships between the
 * container and its content.
 * 
 * ## Scaling Modes
 * 
 * - **CUSTOM**: Use a manually specified scale factor
 * - **FIT**: Scale to fit within container bounds while maintaining aspect ratio
 * - **FILL**: Stretch to completely fill the container (may distort aspect ratio)
 * 
 * ## Usage Examples
 * 
 * ```haxe
 * var container = new VisualContainerView();
 * 
 * // Scale to fit within bounds (maintains aspect ratio)
 * container.scaling = VisualContainerViewScaling.FIT;
 * 
 * // Stretch to fill entire container
 * container.scaling = VisualContainerViewScaling.FILL;
 * 
 * // Use custom scale factor
 * container.scaling = VisualContainerViewScaling.CUSTOM;
 * container.visualScale = 2.0; // 200% scale
 * ```
 * 
 * @see VisualContainerView
 * @see VisualContainerView.scaling
 * @see VisualContainerView.visualScale
 */
enum VisualContainerViewScaling {

    /**
     * Use a custom, manually specified scale factor.
     * 
     * In this mode, the visual is scaled according to the value set in
     * VisualContainerView.visualScale. This allows for precise control
     * over the scaling factor, independent of the container size.
     * 
     * @see VisualContainerView.visualScale
     */
    CUSTOM;

    /**
     * Scale the visual to fit within the container bounds while maintaining aspect ratio.
     * 
     * This mode automatically calculates the largest scale factor that allows
     * the entire visual to fit within the container without distortion.
     * The visual may not fill the entire container if the aspect ratios differ.
     */
    FIT;

    /**
     * Stretch the visual to completely fill the container.
     * 
     * This mode scales the visual separately in X and Y directions to make it
     * exactly fill the container bounds. This may distort the aspect ratio
     * if the container proportions differ from the visual's original proportions.
     */
    FILL;

}
