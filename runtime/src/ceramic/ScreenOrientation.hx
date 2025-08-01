package ceramic;

/**
 * Defines screen orientation modes for mobile and desktop applications.
 * 
 * ScreenOrientation uses bit flags to allow combining multiple orientations,
 * enabling applications to specify which orientations they support. This is
 * particularly important for mobile apps where device rotation is common.
 * 
 * The orientation values can be combined using bitwise OR operations to
 * create orientation masks that support multiple modes.
 * 
 * Example usage:
 * ```haxe
 * // Support only portrait orientations
 * app.settings.orientation = ScreenOrientation.PORTRAIT;
 * 
 * // Support all orientations
 * app.settings.orientation = ScreenOrientation.PORTRAIT | ScreenOrientation.LANDSCAPE;
 * 
 * // Support specific orientations
 * app.settings.orientation = ScreenOrientation.PORTRAIT_UPRIGHT | ScreenOrientation.LANDSCAPE_LEFT;
 * ```
 * 
 * @see Settings#orientation
 * @see Screen
 */
enum abstract ScreenOrientation(Int) from Int to Int {

    /**
     * No specific orientation. The app doesn't enforce any orientation constraints.
     */
    var NONE = 0;

    /**
     * Portrait orientation with the device held upright (home button at bottom).
     * This is the standard portrait mode for most devices.
     */
    var PORTRAIT_UPRIGHT = 1 << 0;

    /**
     * Portrait orientation with the device held upside down (home button at top).
     * Note: Some devices (particularly iOS) may not support this orientation.
     */
    var PORTRAIT_UPSIDE_DOWN = 1 << 1;

    /**
     * Landscape orientation with the device rotated left (home button on right).
     * The screen content is rotated 90 degrees counter-clockwise from portrait.
     */
    var LANDSCAPE_LEFT = 1 << 2;

    /**
     * Landscape orientation with the device rotated right (home button on left).
     * The screen content is rotated 90 degrees clockwise from portrait.
     */
    var LANDSCAPE_RIGHT = 1 << 3;

    /**
     * Both portrait orientations (upright and upside down).
     * 
     * This is a convenience value that combines PORTRAIT_UPRIGHT and PORTRAIT_UPSIDE_DOWN,
     * allowing the device to rotate between both portrait modes.
     */
    var PORTRAIT = (1 << 0) | (1 << 1);

    /**
     * Both landscape orientations (left and right).
     * 
     * This is a convenience value that combines LANDSCAPE_LEFT and LANDSCAPE_RIGHT,
     * allowing the device to rotate between both landscape modes.
     */
    var LANDSCAPE = (1 << 2) | (1 << 3);

}
