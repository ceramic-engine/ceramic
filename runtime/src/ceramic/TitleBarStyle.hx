package ceramic;

/**
 * How the title bar of the app window is shown, chosen with
 * `settings.titleBarStyle`.
 *
 * Only macOS native builds have an overlay title bar for now: other
 * platforms keep the title bar of the system whatever the value (an app
 * that draws its own title bar there uses `settings.windowBorderless` and
 * `screen.setWindowHitRegions`).
 *
 * @see Settings.titleBarStyle
 * @see Settings.trafficLightPosition
 */
enum abstract TitleBarStyle(Int) from Int to Int {

    /** The title bar of the system, above the content of the window. */
    var DEFAULT = 0;

    /**
     * The content takes the whole window, under a transparent title bar
     * whose title is hidden. The window buttons stay, and can be moved
     * (`settings.trafficLightPosition`).
     */
    var OVERLAY = 1;

    public function toString():String {
        return this == OVERLAY ? 'OVERLAY' : 'DEFAULT';
    }

}
