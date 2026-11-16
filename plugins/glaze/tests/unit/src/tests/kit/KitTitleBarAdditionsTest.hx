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

    // KIT-009

    function testWindowControlsOffDrawsNoButton() {
        OperatingSystem.current = OperatingSystem.Mac;
        final plain = titleBar(bar -> bar.platform(TitleBarPlatform.Windows));
        assertEquals('drag,min,max,close', areas(plain));
        // `true` is the default
        assertEquals(sceneSignature(plain), sceneSignature(titleBar(bar -> bar.platform(TitleBarPlatform.Windows).windowControls(true))));
        final bare = titleBar(bar -> bar.platform(TitleBarPlatform.Windows).windowControls(false));
        assertEquals('drag', areas(bare));
        // The look stays: the left padding of Windows, the drag area over the whole bar
        assertEquals(12., boundsOf(bare, 'title').left());
        final ops = new TitleBarOperations();
        final cx = titleBar(bar -> bar.platform(TitleBarPlatform.Windows).windowControls(false), ops);
        cx.simulateClick(new Point(583., 17.));
        cx.simulateClick(new Point(515., 17.));
        assertEquals('', ops.calls.join(','));
        assertFalse(cx.update((window, _) -> window.isDestroyed()));
        // Nothing to hide on the Mac look
        assertEquals(sceneSignature(titleBar(bar -> bar.platform(TitleBarPlatform.Mac))), sceneSignature(titleBar(bar -> bar.platform(TitleBarPlatform.Mac).windowControls(false))));
    }

    function controlLefts(cx:VisualTestContext):Array<Float> {
        return cx.update((window, _) -> [for (entry in window.windowControlHitboxes()) if (entry.area != Drag) entry.hitbox.bounds.left()]);
    }

    function testControlWidthSizesTheButtons() {
        OperatingSystem.current = OperatingSystem.Mac;
        // 34 px by default: three buttons at the right end of the 600 px bar
        assertEquals('498,532,566', controlLefts(titleBar(bar -> bar.platform(TitleBarPlatform.Windows))).join(','));
        final wide = titleBar(bar -> bar.platform(TitleBarPlatform.Windows).controlWidth(px(46.)));
        assertEquals('462,508,554', controlLefts(wide).join(','));
        final ops = new TitleBarOperations();
        final cx = titleBar(bar -> bar.platform(TitleBarPlatform.Windows).controlWidth(px(46.)), ops);
        cx.simulateClick(new Point(470., 17.));
        cx.simulateClick(new Point(520., 17.));
        assertEquals('minimize,zoom', ops.calls.join(','));
    }

    /** Bounds of the control buttons, left to right. */
    function controlBounds(cx:VisualTestContext):Array<glaze.Bounds> {
        return cx.update((window, _) -> [for (entry in window.windowControlHitboxes()) if (entry.area != Drag) entry.hitbox.bounds]);
    }

    /** The glyphs drawn in the control buttons: bounds in logical pixels and color. */
    function controlGlyphs(cx:VisualTestContext):Array<{bounds:glaze.Bounds, color:glaze.Hsla}> {
        final buttons = controlBounds(cx);
        return cx.update((window, _) -> {
            final scale = window.scaleFactor();
            final glyphs = [];
            for (sprite in window.renderedScene().monochromeSprites) {
                final bounds = new glaze.Bounds(new Point(sprite.boundsX / scale, sprite.boundsY / scale),
                    new glaze.Size(sprite.boundsWidth / scale, sprite.boundsHeight / scale));
                for (button in buttons) {
                    if (button.contains(bounds.center())) {
                        glyphs.push({bounds: bounds, color: new glaze.Hsla(sprite.colorH, sprite.colorS, sprite.colorL, sprite.colorA)});
                        break;
                    }
                }
            }
            return glyphs;
        });
    }

    function testControlHeightColorAndIconSize() {
        OperatingSystem.current = OperatingSystem.Mac;
        // by default: as high as the bar (34 px less its border), the theme's foreground, 14 px glyphs
        final plain = titleBar(bar -> bar.platform(TitleBarPlatform.Windows));
        final foreground = plain.update((_, app) -> glaze.kit.theme.Theme.global(app).foreground);
        for (bounds in controlBounds(plain)) {
            assertEquals(0., bounds.top());
            assertEquals(33., bounds.size.height);
        }
        final plainGlyphs = controlGlyphs(plain);
        assertEquals(3, plainGlyphs.length);
        for (glyph in plainGlyphs) {
            assertFloatEquals(14., glyph.bounds.size.width, 0.01);
            assertFloatEquals(14., glyph.bounds.size.height, 0.01);
            assertTrue(sameColor(foreground, glyph.color), 'foreground at rest');
        }
        final plainSignature = sceneSignature(plain);
        // options left null draw the same frame
        final unset = titleBar(bar -> bar.platform(TitleBarPlatform.Windows).controlHeight(null).controlColor(null).controlIconSize(null));
        assertEquals(plainSignature, sceneSignature(unset));

        // 46 x 24 buttons centered in the 33 px of the bar, 12 px glyphs of a given color
        final color:glaze.Hsla = glaze.Hsla.fromRgba(glaze.Prelude.rgb(0x336699));
        final ops = new TitleBarOperations();
        final cx = titleBar(bar -> bar.platform(TitleBarPlatform.Windows).controlWidth(px(46.)).controlHeight(px(24.)).controlColor(color).controlIconSize(px(12.)), ops);
        final lefts = [];
        for (bounds in controlBounds(cx)) {
            lefts.push(bounds.left());
            assertEquals(4.5, bounds.top());
            assertEquals(24., bounds.size.height);
            assertEquals(46., bounds.size.width);
        }
        assertEquals('462,508,554', lefts.join(','));
        final glyphs = controlGlyphs(cx);
        assertEquals(3, glyphs.length);
        for (glyph in glyphs) {
            assertFloatEquals(12., glyph.bounds.size.width, 0.01);
            assertFloatEquals(12., glyph.bounds.size.height, 0.01);
            assertFloatEquals(16.5, glyph.bounds.center().y, 0.01);
            assertTrue(sameColor(color, glyph.color), 'given color at rest');
        }
        // the buttons still act, and the color under the pointer is the theme's
        cx.simulateClick(new Point(470., 17.));
        assertEquals('minimize', ops.calls.join(','));
        cx.simulateMouseMove(new Point(300., 200.));
        cx.simulateMouseMove(new Point(472., 15.));
        for (_ in 0...2) {
            cx.runUntilParked();
            cx.update((window, _) -> {
                window.refresh();
                window.draw();
            });
        }
        final hoverColor = cx.update((_, app) -> glaze.kit.theme.Theme.global(app).secondaryForeground);
        var under = 0;
        var others = 0;
        for (glyph in controlGlyphs(cx)) {
            if (glyph.bounds.center().x < 508.) {
                under++;
                assertTrue(sameColor(hoverColor, glyph.color), 'theme color under the pointer');
            }
            else {
                others++;
                assertTrue(sameColor(color, glyph.color), 'given color at rest');
            }
        }
        assertEquals(1, under);
        assertEquals(2, others);
    }

    // KIT-030

    function cursorAt(cx:VisualTestContext, at:Point):glaze.CursorStyle {
        cx.simulateMouseMove(at);
        cx.runUntilParked();
        cx.update((window, _) -> {
            window.refresh();
            window.draw();
        });
        return cx.update((window, _) -> window.cursorStyle());
    }

    function testControlCursorIsTheCursorOverTheButtons() {
        OperatingSystem.current = OperatingSystem.Mac;
        // none by default, as in gpui-kit: the arrow
        final plain = titleBar(bar -> bar.platform(TitleBarPlatform.Windows));
        assertEquals(sceneSignature(plain), sceneSignature(titleBar(bar -> bar.platform(TitleBarPlatform.Windows).controlCursor(null))));
        assertEquals(glaze.CursorStyle.Arrow, cursorAt(plain, new Point(515., 17.)));
        final ops = new TitleBarOperations();
        final cx = titleBar(bar -> bar.platform(TitleBarPlatform.Windows).controlCursor(PointingHand), ops);
        for (x in [515., 549., 583.]) assertEquals(glaze.CursorStyle.PointingHand, cursorAt(cx, new Point(x, 17.)));
        // not over the rest of the bar
        assertEquals(glaze.CursorStyle.Arrow, cursorAt(cx, new Point(300., 17.)));
        // the buttons still act
        cx.simulateClick(new Point(515., 17.));
        assertEquals('minimize', ops.calls.join(','));
    }

    // KIT-031

    /** A row wider than the window: a part that can shrink, then 50 px that cannot. */
    static function wideRow():glaze.IntoElement {
        return div().flex().flex1().minW0()
            .child(div().flex1().minW0().overflowHidden().child(div().flexShrink0().w(px(1000.)).h(px(10.))))
            .child(div().flexShrink0().child(new tests.kit.KitAdditionsTestCase.AdditionsProbe('right', div().w(px(50.)).h(px(10.)))));
    }

    function testShrinkContentKeepsTheButtonsInTheWindow() {
        OperatingSystem.current = OperatingSystem.Mac;
        // gpui-kit: the content keeps the width of what it holds and pushes
        // the buttons out of the 600 px window
        final plain = titleBar(bar -> bar.platform(TitleBarPlatform.Windows).child(wideRow()));
        assertTrue(controlLefts(plain)[0] > 600., 'buttons at ${controlLefts(plain).join(',')}');
        // with nothing too wide, the option draws the same frame
        assertEquals(sceneSignature(titleBar(bar -> bar.platform(TitleBarPlatform.Windows))),
            sceneSignature(titleBar(bar -> bar.platform(TitleBarPlatform.Windows).shrinkContent(true))));
        final cx = titleBar(bar -> bar.platform(TitleBarPlatform.Windows).shrinkContent(true).child(wideRow()));
        assertEquals('498,532,566', controlLefts(cx).join(','));
        assertEquals(498., boundsOf(cx, 'right').right());
    }

    static function sameColor(a:glaze.Hsla, b:glaze.Hsla):Bool {
        return Math.abs(a.h - b.h) < 0.0001 && Math.abs(a.s - b.s) < 0.0001 && Math.abs(a.l - b.l) < 0.0001 && Math.abs(a.a - b.a) < 0.0001;
    }

    function testTheFullscreenPaddingIsForTheDefaultLeftPadding() {
        OperatingSystem.current = OperatingSystem.Mac;
        final settings = ceramic.App.app.settings;
        final previous = settings.fullscreen;
        assertEquals(80., boundsOf(titleBar(bar -> bar), 'title').left());
        assertEquals(20., boundsOf(titleBar(bar -> bar.pl(px(20.))), 'title').left());
        settings.fullscreen = true;
        final plain = boundsOf(titleBar(bar -> bar), 'title').left();
        final own = boundsOf(titleBar(bar -> bar.pl(px(20.))), 'title').left();
        final zero = boundsOf(titleBar(bar -> bar.pl(px(0.))), 'title').left();
        settings.fullscreen = previous;
        // As before: 12 px more than the padding of the look
        assertEquals(92., plain);
        // The caller's padding alone
        assertEquals(20., own);
        assertEquals(0., zero);
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
