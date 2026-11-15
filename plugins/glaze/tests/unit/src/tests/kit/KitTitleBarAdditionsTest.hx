// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.Modifiers;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.OperatingSystem;
import glaze.PlatformWindowOperations;
import glaze.Point;
import glaze.ResizeEdge;
import glaze.Window;
import glaze.kit.TitleBar;
import glaze.kit.TitleBarPlatform;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The title bar additions without upstream equivalent (KIT-005): the
 * platform of one instance, and window control buttons that handle their
 * clicks on the Windows look.
 */
class KitTitleBarAdditionsTest extends KitAdditionsTestCase {

    var previousOs:OperatingSystem;

    var previousIsWeb:Bool;

    override function setup() {
        super.setup();
        previousOs = OperatingSystem.current;
        previousIsWeb = TitleBar.isWeb;
        TitleBar.isWeb = false;
    }

    override function teardown() {
        OperatingSystem.current = previousOs;
        TitleBar.isWeb = previousIsWeb;
        super.teardown();
    }

    /** A 600 px window with one title bar; returns the operations it requests. */
    function titleBar(configure:(TitleBar) -> TitleBar, ?ops:TitleBarOperations):VisualTestContext {
        final cx = open((_, _) -> div().sizeFull().child(configure(TitleBar.component().child(probe('title', div().child('Library'))))), 600, 400);
        if (ops != null) {
            cx.update((window, _) -> window.platformOperations = ops);
            rerender(cx);
        }
        cx.update((window, _) -> {
            window.refresh();
            window.draw();
        });
        return cx;
    }

    function areas(cx:VisualTestContext):String {
        return cx.update((window, _) -> [for (entry in window.windowControlHitboxes()) switch entry.area {
            case Drag: 'drag';
            case Close: 'close';
            case Max: 'max';
            case Min: 'min';
        }].join(','));
    }

    function testAnInstanceTakesThePlatformItIsGiven() {
        OperatingSystem.current = OperatingSystem.Mac;
        assertEquals('drag', areas(titleBar(bar -> bar)));
        assertEquals(80., boundsOf(titleBar(bar -> bar), 'title').left());

        final windows = titleBar(bar -> bar.platform(TitleBarPlatform.Windows));
        assertEquals('drag,min,max,close', areas(windows));
        assertEquals(12., boundsOf(windows, 'title').left());
        assertEquals('', areas(titleBar(bar -> bar.platform(TitleBarPlatform.Web))));
        // Linux shows its buttons on a client decorated window only, as before.
        assertEquals('drag', areas(titleBar(bar -> bar.platform(TitleBarPlatform.Linux))));
        // The global setting, which also decides the key bindings, did not move.
        assertEquals(OperatingSystem.Mac, OperatingSystem.current);

        OperatingSystem.current = OperatingSystem.Windows;
        final mac = titleBar(bar -> bar.platform(TitleBarPlatform.Mac));
        assertEquals('drag', areas(mac));
        assertEquals(80., boundsOf(mac, 'title').left());
        TitleBar.isWeb = true;
        assertEquals('drag,min,max,close', areas(titleBar(bar -> bar.platform(TitleBarPlatform.Windows))));
    }

    function testAGivenPlatformDrawsWhatTheOperatingSystemDraws() {
        final looks:Array<{os:OperatingSystem, platform:TitleBarPlatform}> = [
            {os: OperatingSystem.Mac, platform: TitleBarPlatform.Mac},
            {os: OperatingSystem.Windows, platform: TitleBarPlatform.Windows},
            {os: OperatingSystem.Linux, platform: TitleBarPlatform.Linux},
        ];
        for (look in looks) {
            OperatingSystem.current = look.os;
            final expected = sceneSignature(titleBar(bar -> bar));
            OperatingSystem.current = look.os == OperatingSystem.Mac ? OperatingSystem.Windows : OperatingSystem.Mac;
            assertEquals(expected, sceneSignature(titleBar(bar -> bar.platform(look.platform))), '${look.platform}');
        }
    }

    function testTheButtonsOfTheWindowsLookDriveTheWindow() {
        OperatingSystem.current = OperatingSystem.Mac;
        final ops = new TitleBarOperations();
        final cx = titleBar(bar -> bar.platform(TitleBarPlatform.Windows), ops);
        // minimize, maximize, close from the right end of the 600 px bar
        cx.simulateClick(new Point(515., 17.));
        cx.simulateClick(new Point(549., 17.));
        assertEquals('minimize,zoom', ops.calls.join(','));
        // Maximized, the middle button restores.
        ops.isMaximizedValue = true;
        rerender(cx);
        cx.simulateClick(new Point(549., 17.));
        assertEquals('minimize,zoom,zoom', ops.calls.join(','));

        // A press on a button that moves does not start a window move.
        cx.simulateEvent(new MouseDownEvent(Left, new Point(515., 17.), Modifiers.none(), 1, false));
        cx.simulateEvent(new MouseMoveEvent(new Point(518., 17.), Left, Modifiers.none()));
        cx.simulateEvent(new MouseUpEvent(Left, new Point(518., 17.), Modifiers.none(), 1));
        assertEquals('minimize,zoom,zoom,minimize', ops.calls.join(','));

        // The close button removes the window at the end of the update.
        cx.simulateClick(new Point(583., 17.));
        cx.runUntilParked();
        assertTrue(cx.update((window, _) -> window.isDestroyed()));
    }

    function testTheSameButtonsWorkWhenWindowsIsTheOperatingSystem() {
        OperatingSystem.current = OperatingSystem.Windows;
        final ops = new TitleBarOperations();
        final cx = titleBar(bar -> bar, ops);
        cx.simulateClick(new Point(515., 17.));
        cx.simulateClick(new Point(549., 17.));
        assertEquals('minimize,zoom', ops.calls.join(','));
    }

    function testACloseHandlerReplacesRemovingTheWindow() {
        OperatingSystem.current = OperatingSystem.Mac;
        var closes = 0;
        // Set before the platform: the handler is kept either way.
        final cx = titleBar(bar -> bar.onCloseWindow((_, _, _) -> closes++).platform(Windows));
        cx.simulateClick(new Point(583., 17.));
        cx.runUntilParked();
        assertEquals(1, closes);
        assertFalse(cx.update((window, _) -> window.isDestroyed()));
    }

    function testWithoutControlClicksTheButtonsAreControlAreasOnly() {
        OperatingSystem.current = OperatingSystem.Windows;
        final ops = new TitleBarOperations();
        var closes = 0;
        final cx = titleBar(bar -> bar.controlClicks(false).onCloseWindow((_, _, _) -> closes++), ops);
        assertEquals('drag,min,max,close', areas(cx));
        cx.simulateClick(new Point(515., 17.));
        cx.simulateClick(new Point(549., 17.));
        cx.simulateClick(new Point(583., 17.));
        cx.runUntilParked();
        assertEquals('', ops.calls.join(','));
        assertEquals(0, closes);
        assertFalse(cx.update((window, _) -> window.isDestroyed()));
    }

}

private class TitleBarOperations implements PlatformWindowOperations {

    public final calls:Array<String> = [];

    public var isMaximizedValue:Bool = false;

    public function new() {}

    public function activate():Void {
        calls.push('activate');
    }

    public function minimize():Void {
        calls.push('minimize');
    }

    public function zoom():Void {
        calls.push('zoom');
    }

    public function isMaximized():Bool {
        return isMaximizedValue;
    }

    public function startWindowMove():Void {
        calls.push('move');
    }

    public function startWindowResize(edge:ResizeEdge):Void {
        calls.push('resize');
    }

    public function showWindowMenu(position:Point):Void {
        calls.push('menu');
    }

    public function titlebarDoubleClick(isResizable:Bool, isMinimizable:Bool):Void {
        calls.push('double-click');
    }

    public function appearance():glaze.WindowAppearance {
        return Light;
    }

}
