package ceramic;

/**
 * Defines how the application's logical screen size is mapped to the native screen.
 * 
 * ScreenScaling determines how your app's content is displayed when the target
 * logical size doesn't match the actual device screen size. Each mode offers
 * different trade-offs between content visibility, aspect ratio preservation,
 * and screen utilization.
 * 
 * The scaling mode affects:
 * - How logical coordinates map to screen pixels
 * - Whether content might be cropped or letterboxed
 * - How the app responds to screen size changes
 * 
 * Example usage:
 * ```haxe
 * // Set up a fixed logical size with letterboxing
 * app.settings.targetWidth = 1280;
 * app.settings.targetHeight = 720;
 * app.settings.scaling = ScreenScaling.FIT;
 * 
 * // Or use dynamic sizing that matches device
 * app.settings.scaling = ScreenScaling.RESIZE;
 * ```
 * 
 * Visual comparison:
 * - **FIT**: Shows all content, may have black bars
 * - **FILL**: Fills screen completely, may crop content
 * - **RESIZE**: Content size changes with screen size
 * - **FIT_RESIZE**: Adjusts logical size to match aspect ratio
 * 
 * @see Settings#scaling
 * @see Screen#updateScaling
 */
enum ScreenScaling {

    /**
     * Scales content to fit within native screen bounds while preserving aspect ratio.
     * 
     * The logical screen size matches the target width/height in settings.
     * Content is scaled uniformly to fit completely within the native screen,
     * potentially resulting in letterboxing (black bars) on sides or top/bottom.
     * 
     * Best for:
     * - Games with fixed layouts
     * - Apps requiring pixel-perfect positioning
     * - Content that must be fully visible
     * 
     * Trade-offs:
     * - ✓ All content is always visible
     * - ✓ Aspect ratio is preserved
     * - ✗ May show black bars
     * - ✗ Doesn't use full screen on all devices
     */
    FIT;

    /**
     * Scales content to fill the entire native screen, potentially cropping edges.
     * 
     * The logical screen size matches the target width/height in settings.
     * Content is scaled uniformly to completely fill the native screen,
     * which may result in some content being cropped on devices with
     * different aspect ratios.
     * 
     * Best for:
     * - Full-screen experiences
     * - Background visuals that can extend beyond view
     * - Apps where edge content is non-critical
     * 
     * Trade-offs:
     * - ✓ Uses entire screen
     * - ✓ No black bars
     * - ✗ May crop content on some devices
     * - ✗ Important UI elements need safe zones
     */
    FILL;

    /**
     * Dynamically resizes logical screen to match native screen exactly.
     * 
     * The logical screen dimensions (width/height) automatically adjust
     * to match the native screen size. Your app needs to handle dynamic
     * layouts as screen properties change with device orientation or
     * window resizing.
     * 
     * Best for:
     * - Responsive applications
     * - Desktop apps with resizable windows
     * - Apps that adapt to any screen size
     * 
     * Trade-offs:
     * - ✓ Perfect screen utilization
     * - ✓ No scaling artifacts
     * - ✗ Requires responsive layout code
     * - ✗ Content positions/sizes vary by device
     */
    RESIZE;

    /**
     * Adjusts logical size to match native aspect ratio, then fits exactly.
     * 
     * Starting from the target width/height, either dimension is increased
     * to match the native screen's aspect ratio. The result is then scaled
     * to fit exactly into the native screen bounds without any letterboxing.
     * 
     * This mode provides a middle ground between fixed and dynamic sizing:
     * content layout remains relatively consistent while utilizing the full screen.
     * 
     * Best for:
     * - Apps wanting full screen without cropping
     * - Games with flexible layouts
     * - Content that can handle slight size variations
     * 
     * Trade-offs:
     * - ✓ Uses entire screen
     * - ✓ No content cropping
     * - ✓ Minimal layout variations
     * - ✗ Logical size varies slightly by device
     */
    FIT_RESIZE;

}
