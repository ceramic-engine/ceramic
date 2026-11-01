// Ported from gpui-kit 0.8.1: crates/component/src/title_bar.rs and window_border.rs (tests),
// crates/kit/tests/integration/components.rs (title_bar_and_window_controls_are_observable)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Context;
import gpui.Decorations;
import gpui.Edges;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.Modifiers;
import gpui.MouseButton;
import gpui.MouseDownEvent;
import gpui.MouseMoveEvent;
import gpui.MouseUpEvent;
import gpui.OperatingSystem;
import gpui.PlatformWindowOperations;
import gpui.Point;
import gpui.ResizeEdge;
import gpui.Rgba;
import gpui.Size;
import gpui.SpringMath;
import gpui.TestDispatcher;
import gpui.Decorations.Tiling;
import gpui.Window;
import gpui.WindowControlArea;
import gpui.component.Component;
import gpui.component.TitleBar;
import gpui.component.WindowBorder;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

/**
 * The `#[cfg(test)]` tests of gpui-component's `title_bar.rs` and
 * `window_border.rs`, gpui-kit's integration test of the title bar, and the
 * port's checks of the platform paths Rust compiles per target (the golden
 * reference renders the macOS path only).
 *
 * Rust's UI queries by id become the window control areas the title bar
 * records (`Window.windowControlHitboxes`) and the operations it requests
 * from the platform window (`Window.platformOperations`).
 */
class ComponentWindowTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    var previousOs:OperatingSystem;

    var previousIsWeb:Bool;

    override function setup() {
        previousOs = OperatingSystem.current;
        previousIsWeb = TitleBar.isWeb;
        TitleBar.isWeb = false;
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> Component.init(cx));
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        OperatingSystem.current = previousOs;
        TitleBar.isWeb = previousIsWeb;
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement, ?prepare:Window->Void, width:Float = 600, height:Float = 400):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render), width, height);
        contexts.push(opened.cx);
        if (prepare != null) opened.cx.update((window, _) -> prepare(window));
        opened.cx.update((window, _) -> {
            window.refresh();
            window.draw();
        });
        return opened.cx;
    }

    static function areas(cx:VisualTestContext):String {
        return cx.update((window, _) -> [for (entry in window.windowControlHitboxes()) areaName(entry.area)].join(','));
    }

    static function areaName(area:WindowControlArea):String {
        return switch area {
            case Drag: 'drag';
            case Close: 'close';
            case Max: 'max';
            case Min: 'min';
        }
    }

    /// title_bar.rs

    function testDefaultTitleBarBackground() {
        final titleBar = Hsla.black();
        final background = Hsla.white();

        final expected = linearGradient(
            180.,
            linearColorStop(Hsla.fromRgba(new Rgba(SpringMath.f32(0.45), SpringMath.f32(0.45), SpringMath.f32(0.45), 1.)), 0.),
            linearColorStop(titleBar, 1.)
        );
        assertTrue(expected.equals(@:privateAccess TitleBar.defaultTitleBarBackground(titleBar, background)));
    }

    /// window_border.rs

    function testOnlyClientDecoratedWindowsUseTheClientBorder() {
        assertFalse(@:privateAccess WindowBorder.usesClientBorder(Server));
        assertTrue(@:privateAccess WindowBorder.usesClientBorder(Client(new Tiling())));
    }

    /// integration/components.rs

    function titleBarWindow(?prepare:Window->Void):VisualTestContext {
        return open((_, _) -> div().sizeFull().child(new TitleBar().child('Library')), prepare);
    }

    function testTitleBarAndWindowControlsAreObservable() {
        // Windows draws the caption buttons in the title bar.
        OperatingSystem.current = Windows;
        final cx = titleBarWindow();
        assertEquals('drag,min,max,close', areas(cx));
        cx.update((window, _) -> {
            final hitboxes = window.windowControlHitboxes();
            final controls = hitboxes[1].hitbox.bounds.union(hitboxes[3].hitbox.bounds);
            for (entry in hitboxes.slice(1)) {
                assertTrue(controls.contains(entry.hitbox.bounds.center()));
                assertEquals(TitleBar.TITLE_BAR_HEIGHT, entry.hitbox.bounds.size.width);
            }
            // The close button ends the bar.
            assertEquals(600., hitboxes[3].hitbox.bounds.right());
        });

        // macOS and the web leave them to the system, and so does Linux under
        // the server-side decorations of the test window.
        for (os in [Mac, Linux]) {
            OperatingSystem.current = os;
            assertEquals('drag', areas(titleBarWindow()));
        }
        TitleBar.isWeb = true;
        OperatingSystem.current = Mac;
        assertEquals('', areas(titleBarWindow()));
    }

    /// Platform paths

    function testLinuxClientDecoratedControlsDriveTheWindow() {
        OperatingSystem.current = Linux;
        final ops = new RecordingOperations();
        final cx = titleBarWindow(window -> {
            window.platformDecorations = Client(new Tiling());
            window.platformOperations = ops;
        });
        // Linux buttons are not control areas: they handle their clicks.
        assertEquals('drag', areas(cx));
        // minimize, maximize, close from the right end of a 600px bar
        cx.simulateClick(new Point(515., 17.));
        cx.simulateClick(new Point(549., 17.));
        assertEquals('minimize,zoom', ops.calls.join(','));
        ops.isMaximizedValue = true;

        // A double click on the bar zooms, a right click opens the window menu.
        cx.simulateClick(new Point(200., 17.));
        cx.simulateEvent(new MouseDownEvent(Left, new Point(200., 17.), Modifiers.none(), 2, false));
        cx.simulateEvent(new MouseUpEvent(Left, new Point(200., 17.), Modifiers.none(), 2));
        cx.simulateEvent(new MouseDownEvent(Right, new Point(220., 20.), Modifiers.none(), 1, false));
        cx.simulateEvent(new MouseUpEvent(Right, new Point(220., 20.), Modifiers.none(), 1));
        assertEquals('minimize,zoom,zoom,menu 220 20', ops.calls.join(','));

        // Pressing on the bar then moving starts a window move, once.
        cx.simulateEvent(new MouseDownEvent(Left, new Point(300., 17.), Modifiers.none(), 1, false));
        cx.simulateEvent(new MouseMoveEvent(new Point(310., 17.), Left, Modifiers.none()));
        cx.simulateEvent(new MouseMoveEvent(new Point(320., 17.), Left, Modifiers.none()));
        cx.simulateEvent(new MouseUpEvent(Left, new Point(320., 17.), Modifiers.none(), 1));
        assertEquals('minimize,zoom,zoom,menu 220 20,move', ops.calls.join(','));

        // The close button removes the window at the end of the update.
        cx.simulateClick(new Point(583., 17.));
        cx.runUntilParked();
        assertTrue(cx.update((window, _) -> window.isDestroyed()));
    }

    function testLinuxCloseHandlerReplacesRemovingTheWindow() {
        OperatingSystem.current = Linux;
        var closes = 0;
        final cx = open((_, _) -> div().sizeFull().child(new TitleBar().onCloseWindow((_, _, _) -> closes++)), window -> {
            window.platformDecorations = Client(new Tiling());
        });
        cx.simulateClick(new Point(583., 17.));
        cx.runUntilParked();
        assertEquals(1, closes);
        assertFalse(cx.update((window, _) -> window.isDestroyed()));
    }

    function testMacosDoubleClickRunsTheTitleBarAction() {
        OperatingSystem.current = Mac;
        final ops = new RecordingOperations();
        final cx = titleBarWindow(window -> window.platformOperations = ops);
        cx.simulateClick(new Point(200., 17.));
        cx.simulateEvent(new MouseDownEvent(Left, new Point(200., 17.), Modifiers.none(), 2, false));
        cx.simulateEvent(new MouseUpEvent(Left, new Point(200., 17.), Modifiers.none(), 2));
        assertEquals('double-click', ops.calls.join(','));
    }

    function testClientBorderPaddingsAndResizeEdges() {
        OperatingSystem.current = Linux;
        assertEquals(20., WindowBorder.SHADOW_SIZE);
        final ops = new RecordingOperations();
        final cx = open((_, _) -> WindowBorder.windowBorder().child(div().sizeFull()), window -> {
            window.platformDecorations = Client(new Tiling(false, true, false, false));
            window.platformOperations = ops;
        });
        cx.update((window, _) -> {
            assertEquals(20., window.clientInset());
            assertTrue(new Edges(20., 20., 20., 0.).equals(WindowBorder.windowPaddings(window)));
            assertTrue(new Edges(21., 21., 21., 0.).equals(WindowBorder.windowContentInsets(window)));
            assertTrue(Edges.all(0.).equals(WindowBorder.windowSafeInsets(window)));
        });
        // Top right corner of the visible frame, then the bottom edge.
        cx.simulateEvent(new MouseDownEvent(Left, new Point(580., 21.), Modifiers.none(), 1, false));
        cx.simulateEvent(new MouseUpEvent(Left, new Point(580., 21.), Modifiers.none(), 1));
        cx.simulateEvent(new MouseDownEvent(Left, new Point(300., 382.), Modifiers.none(), 1, false));
        cx.simulateEvent(new MouseUpEvent(Left, new Point(300., 382.), Modifiers.none(), 1));
        // Away from the frame edges.
        cx.simulateEvent(new MouseDownEvent(Left, new Point(300., 200.), Modifiers.none(), 1, false));
        cx.simulateEvent(new MouseUpEvent(Left, new Point(300., 200.), Modifiers.none(), 1));
        assertEquals('resize TopRight,resize Bottom', ops.calls.join(','));
    }

    /**
     * Port addition: the regions a window publishes to the native window
     * (SDL hit test) are the drag areas of its window controls, then the
     * resize zones of its WindowBorder, in screen coordinates (the test
     * window's renderable sits at the screen origin).
     */
    function testNativeHitRegions() {
        OperatingSystem.current = Mac;
        final point = new ceramic.Point();
        final bar = titleBarWindow();
        bar.update((window, _) -> {
            final regions = gpui.platform.CeramicWindowOperations.hitRegions(window, point);
            assertEquals(5, regions.length);
            final drag = window.windowControlHitboxes()[0].hitbox.bounds;
            assertFloatEquals(drag.origin.x, regions[0], 1e-4);
            assertFloatEquals(drag.origin.y, regions[1], 1e-4);
            assertFloatEquals(drag.size.width, regions[2], 1e-4);
            assertFloatEquals(drag.size.height, regions[3], 1e-4);
            assertEquals((ceramic.WindowHitKind.DRAGGABLE:Int), Std.int(regions[4]));
        });

        OperatingSystem.current = Linux;
        final border = open((_, _) -> WindowBorder.windowBorder().child(div().sizeFull()), window -> {
            window.platformDecorations = Client(new Tiling(false, true, false, false));
        });
        border.update((window, _) -> {
            final regions = gpui.platform.CeramicWindowOperations.hitRegions(window, point);
            final kinds = [for (i in 0...Std.int(regions.length / 5)) Std.int(regions[i * 5 + 4])];
            // The left side is tiled (Tiling(top, left, right, bottom)): no
            // left edge nor left corners
            assertEquals([
                (ceramic.WindowHitKind.RESIZE_TOP:Int), (ceramic.WindowHitKind.RESIZE_BOTTOM:Int), (ceramic.WindowHitKind.RESIZE_RIGHT:Int),
                (ceramic.WindowHitKind.RESIZE_TOP_RIGHT:Int), (ceramic.WindowHitKind.RESIZE_BOTTOM_RIGHT:Int)
            ].join(','), kinds.join(','));
            // The top band surrounds the visible frame edge (shadow 20, hit size 4)
            assertFloatEquals(16., regions[1], 1e-4);
            assertFloatEquals(8., regions[3], 1e-4);
        });
    }

    function testResizeEdgeHitTesting() {
        final tiling = new Tiling();
        final size = new Size(600., 400.);
        final insets = Edges.all(20.);
        inline function edge(x:Float, y:Float):Null<ResizeEdge> {
            return @:privateAccess WindowBorder.resizeEdge(new Point(x, y), size, insets, tiling, 4.);
        }
        assertEquals(TopLeft, edge(18., 22.));
        assertEquals(TopRight, edge(582., 18.));
        assertEquals(BottomLeft, edge(20., 380.));
        assertEquals(BottomRight, edge(584., 384.));
        assertEquals(Top, edge(300., 16.));
        assertEquals(Bottom, edge(300., 383.));
        assertEquals(Left, edge(23., 200.));
        assertEquals(Right, edge(577., 200.));
        assertNull(edge(300., 200.));
        // The band does not extend along the shadow padding.
        assertNull(edge(10., 200.));
        assertNull(@:privateAccess WindowBorder.resizeEdge(new Point(18., 22.), size, insets, new Tiling(true, true, false, false), 4.));
        // Corners come after the edge strips, so they win the hit test.
        final zones = @:privateAccess WindowBorder.resizeHitZones(size, 20., 4., tiling);
        assertEquals(8, zones.length);
        assertEquals(0, (@:privateAccess WindowBorder.resizeHitZones(size, 20., 4., Tiling.tiled())).length);
    }

}

/**
 * Records the native window operations a window requests.
 */
private class RecordingOperations implements PlatformWindowOperations {

    public final calls:Array<String> = [];

    public var isMaximizedValue:Bool = false;

    public function new() {}

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
        calls.push('resize ' + edgeName(edge));
    }

    public function showWindowMenu(position:Point):Void {
        calls.push('menu ${position.x} ${position.y}');
    }

    public function titlebarDoubleClick(isResizable:Bool, isMinimizable:Bool):Void {
        calls.push('double-click');
    }

    static function edgeName(edge:ResizeEdge):String {
        return switch edge {
            case Top: 'Top';
            case TopRight: 'TopRight';
            case Right: 'Right';
            case BottomRight: 'BottomRight';
            case Bottom: 'Bottom';
            case BottomLeft: 'BottomLeft';
            case Left: 'Left';
            case TopLeft: 'TopLeft';
        }
    }

}
