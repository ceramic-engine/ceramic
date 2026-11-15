// New code for the Haxe port of GPUI: the native window operations of GPUI's
// `PlatformWindow` (gpui-pre 0.3.10, src/platform.rs, Zed Industries,
// Apache-2.0), implemented with Ceramic's screen API. See NOTICE.md.
package glaze.platform;

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
     * Makes this window the one receiving the keyboard (`GlazeInput`) and
     * activates the app window (`ceramic.Screen.activateWindow`). The window
     * becomes active right away when the app window has the system focus,
     * otherwise once it gains it (like a native window becoming key).
     */
    public function activate():Void {
        GlazeInput.activateWindow(window);
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
        window.windowToScreen(position.x, position.y, point);
        ceramic.App.app.screen.showWindowMenu(point.x, point.y);
    }

    /**
     * The appearance of the system (`ceramic.Screen.systemAppearance`): the
     * window has no appearance of its own, like a macOS window that follows
     * the application.
     */
    public function appearance():WindowAppearance {
        return WindowAppearance.fromCeramic(ceramic.App.app.screen.systemAppearance);
    }

    public function titlebarDoubleClick(isResizable:Bool, isMinimizable:Bool):Void {
        // GPUI on Linux and Windows zooms the window (macOS follows a system
        // preference that SDL does not expose: zoom is its default)
        if (isResizable)
            zoom();
    }

    /**
     * The hit regions of `window` in screen coordinates, flat as
     * `ceramic.Screen.setWindowHitRegions` takes them (the last matching
     * region wins), in this order:
     *
     * - back to front, the drag areas of its window controls
     *   (`WindowControlArea.Drag`, kind `DRAGGABLE`) and, above a drag area,
     *   the elements that must keep receiving the presses (kind `NORMAL`):
     *   those with a listener of the left button (mouse down, mouse up, click,
     *   drag), those that block the mouse (`occlude()`,
     *   `blockMouseExceptScroll()`), the other window control areas (close,
     *   maximize, minimize: `ceramic.WindowHitKind` has no kind for them, so
     *   the app handles their clicks) and those marked `noWindowDrag()`.
     *   Each one is clipped to its content mask. A drag area drawn above such
     *   an element is draggable again.
     * - then (resizable, not maximized) its resize zones
     *   (`Window.nativeResizeZones`).
     *
     * The list is read from the hitboxes of the last frame, so the areas of
     * a view reused from the cache are kept.
     */
    public static function hitRegions(window:Window, screenPoint:ceramic.Point):Array<Float> {
        final regions:Array<Float> = [];
        final hitboxes = window.renderedHitboxes();
        // The drag areas met so far, flat as x, y, width, height (allocated
        // with the first one only)
        var drags:Null<Array<Float>> = null;
        for (index in 0...hitboxes.length) {
            final hitbox = hitboxes[index];
            final role = hitbox.windowDragRole;
            final hole = role == Hitbox.WINDOW_DRAG_HOLE || hitbox.behavior != HitboxBehavior.Normal;
            if (role != Hitbox.WINDOW_DRAG_AREA && (drags == null || !hole))
                continue;
            // The bounds clipped to the content mask, without allocating
            final b = hitbox.bounds;
            final m = hitbox.contentMask.bounds;
            var x = Math.max(b.origin.x, m.origin.x);
            var y = Math.max(b.origin.y, m.origin.y);
            var w = Math.min(b.origin.x + b.size.width, m.origin.x + m.size.width) - x;
            var h = Math.min(b.origin.y + b.size.height, m.origin.y + m.size.height) - y;
            if (w <= 0 || h <= 0)
                continue;
            final t = hitbox.transform;
            if (t != null) {
                // Inside an element transformation: where the hitbox is drawn
                final ax = x * t.m00 + t.tx;
                final bx = (x + w) * t.m00 + t.tx;
                final ay = y * t.m11 + t.ty;
                final by = (y + h) * t.m11 + t.ty;
                x = Math.min(ax, bx);
                y = Math.min(ay, by);
                w = Math.abs(bx - ax);
                h = Math.abs(by - ay);
                if (w <= 0 || h <= 0)
                    continue;
            }
            if (role == Hitbox.WINDOW_DRAG_AREA) {
                if (drags == null) drags = [];
                drags.push(x);
                drags.push(y);
                drags.push(w);
                drags.push(h);
                pushRegion(window, regions, x, y, w, h, WindowHitKind.DRAGGABLE, screenPoint);
            }
            else {
                // Only where it covers a drag area drawn before it
                var covers = false;
                var i = 0;
                while (i < drags.length) {
                    if (x < drags[i] + drags[i + 2] && drags[i] < x + w && y < drags[i + 1] + drags[i + 3] && drags[i + 1] < y + h) {
                        covers = true;
                        break;
                    }
                    i += 4;
                }
                if (covers)
                    pushRegion(window, regions, x, y, w, h, WindowHitKind.NORMAL, screenPoint);
            }
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
        window.windowToScreen(x, y, p);
        final x0 = p.x;
        final y0 = p.y;
        window.windowToScreen(x + w, y + h, p);
        regions.push(Math.min(x0, p.x));
        regions.push(Math.min(y0, p.y));
        regions.push(Math.abs(p.x - x0));
        regions.push(Math.abs(p.y - y0));
        regions.push(kind);
    }

}
