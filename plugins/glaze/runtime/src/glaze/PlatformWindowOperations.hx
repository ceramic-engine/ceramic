// New code for the Haxe port of GPUI: the operations GPUI's `PlatformWindow`
// performs on the native window (gpui-pre 0.3.10, src/platform.rs, Zed
// Industries, Apache-2.0). See NOTICE.md.
package gpui;

/**
 * The native window operations of GPUI's `PlatformWindow`: activate, minimize, zoom
 * (maximize or restore), interactive move and resize, the window menu, the
 * title bar double click and the window appearance.
 *
 * Windows use `gpui.platform.CeramicWindowOperations` by default, which acts
 * on the Ceramic app window (`ceramic.Screen`: SDL on native targets, nothing
 * on the web and in headless builds). Embedders and tests can set their own
 * on `Window.platformOperations` (null ignores every request, like GPUI's
 * headless and test windows).
 */
interface PlatformWindowOperations {

    /** Bring the window to the front and give it the keyboard focus (`PlatformWindow::activate`). */
    function activate():Void;

    /** Minimize the window (`PlatformWindow::minimize`). */
    function minimize():Void;

    /** Maximize or restore the window (`PlatformWindow::zoom`). */
    function zoom():Void;

    /** Whether the window is maximized (`PlatformWindow::is_maximized`). */
    function isMaximized():Bool;

    /** Let the system move the window with the pointer (`PlatformWindow::start_window_move`). */
    function startWindowMove():Void;

    /** Let the system resize the window from `edge` (`PlatformWindow::start_window_resize`). */
    function startWindowResize(edge:ResizeEdge):Void;

    /** Open the system window menu at `position` (`PlatformWindow::show_window_menu`). */
    function showWindowMenu(position:Point):Void;

    /** Run the system action of a title bar double click (`PlatformWindow::titlebar_double_click`). */
    function titlebarDoubleClick(isResizable:Bool, isMinimizable:Bool):Void;

    /**
     * The appearance of the window (`PlatformWindow::appearance`). The window
     * reads it again when the platform reports a change (Ceramic's
     * `systemAppearanceChange`, see `Window.observeWindowAppearance`).
     */
    function appearance():WindowAppearance;

}
