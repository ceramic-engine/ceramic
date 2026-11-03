// New code for the Haxe port of GPUI: the native window operations of GPUI's
// `PlatformWindow` (gpui-pre 0.3.10, src/platform.rs, Zed Industries,
// Apache-2.0), implemented with Ceramic's screen API. See NOTICE.md.
package gpui.platform;

import ceramic.WindowHitKind;

/**
 * `PlatformWindowOperations` on the Ceramic app window (`ceramic.Screen`):
 * activate, minimize, maximize / restore, the system window menu and the title bar
 * double click act on the native window (SDL on native targets; they do
 * nothing on the web and in headless builds).
 *
 * Interactive moves and resizes are done by the operating system through
 * hit regions (SDL's window hit test), which a window publishes after each
 * frame from its window control hitboxes and the resize zones of its
 * window border (`hitRegions`): a press on a title bar drag area moves the window without
 * GPUI having to call `startWindowMove`, like GPUI on Windows (where the
 * window control areas answer `WM_NCHITTEST`). `startWindowMove` and
 * `startWindowResize` therefore have nothing left to do.
 */
class CeramicWindowOperations implements PlatformWindowOperations {

    final window:Window;

    final point = new ceramic.Point();

    public function new(window:Window) {
        this.window = window;
    }

    /**
     * Makes this window the one receiving the keyboard (`GpuiInput`) and
     * activates the app window (`ceramic.Screen.activateWindow`). The window
     * becomes active right away when the app window has the system focus,
     * otherwise once it gains it (like a native window becoming key).
     */
    public function activate():Void {
        GpuiInput.activateWindow(window);
        ceramic.App.app.screen.activateWindow();
    }

    public function minimize():Void {
        ceramic.App.app.screen.minimizeWindow();
    }

    public function zoom():Void {
        final screen = ceramic.App.app.screen;
        if (screen.windowMaximized)
            screen.restoreWindow();
        else
            screen.maximizeWindow();
    }

    public function isMaximized():Bool {
        return ceramic.App.app.screen.windowMaximized;
    }

    public function startWindowMove():Void {
        // Done by the operating system through the hit regions
    }

    public function startWindowResize(edge:ResizeEdge):Void {
        // Done by the operating system through the hit regions
    }

    public function showWindowMenu(position:Point):Void {
        window.renderable.visualToScreen(position.x, position.y, point);
        ceramic.App.app.screen.showWindowMenu(point.x, point.y);
    }

    public function titlebarDoubleClick(isResizable:Bool, isMinimizable:Bool):Void {
        // GPUI on Linux and Windows zooms the window (macOS follows a system
        // preference that SDL does not expose: zoom is its default)
        if (isResizable)
            zoom();
    }

    /**
     * The hit regions of `window` in screen coordinates, flat as
     * `ceramic.Screen.setWindowHitRegions` takes them: the drag areas of its
     * window controls, then (resizable, not maximized) its resize zones
     * (`Window.nativeResizeZones`).
     */
    public static function hitRegions(window:Window, screenPoint:ceramic.Point):Array<Float> {
        final regions:Array<Float> = [];
        for (control in window.windowControlHitboxes()) {
            if (control.area != WindowControlArea.Drag)
                continue;
            final hitbox = control.hitbox;
            final bounds = hitbox.bounds.intersect(hitbox.contentMask.bounds);
            if (bounds.size.width <= 0 || bounds.size.height <= 0)
                continue;
            pushRegion(window, regions, bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height, WindowHitKind.DRAGGABLE, screenPoint);
        }
        final zones = window.nativeResizeZones;
        if (zones != null && window.isResizable() && !window.isMaximized()) {
            var i = 0;
            while (i + 4 < zones.length) {
                pushRegion(window, regions, zones[i], zones[i + 1], zones[i + 2], zones[i + 3], Std.int(zones[i + 4]), screenPoint);
                i += 5;
            }
        }
        return regions;
    }

    static function pushRegion(window:Window, regions:Array<Float>, x:Float, y:Float, w:Float, h:Float, kind:WindowHitKind, p:ceramic.Point):Void {
        window.renderable.visualToScreen(x, y, p);
        final x0 = p.x;
        final y0 = p.y;
        window.renderable.visualToScreen(x + w, y + h, p);
        regions.push(Math.min(x0, p.x));
        regions.push(Math.min(y0, p.y));
        regions.push(Math.abs(p.x - x0));
        regions.push(Math.abs(p.y - y0));
        regions.push(kind);
    }

}
