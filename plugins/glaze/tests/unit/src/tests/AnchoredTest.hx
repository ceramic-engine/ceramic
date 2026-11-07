// Ported from gpui-pre 0.3.10: src/elements/anchored.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import gpui.App;
import gpui.Bounds;
import gpui.Context;
import gpui.IntoElement;
import gpui.Model;
import gpui.Point;
import gpui.Render;
import gpui.ScrollDelta;
import gpui.ScrollEvent;
import gpui.TestDispatcher;
import gpui.Window;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

/**
 * Tests of `anchored.rs`, all ported. Debug selectors are not ported: the
 * menu is a canvas recording its bounds at prepaint (Rust reads
 * `rendered_frame.debug_bounds["MENU"]`).
 */
class AnchoredTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var cx:Null<VisualTestContext> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (cx != null) {
            cx.destroy();
            cx = null;
        }
        ceramic.App.app.flushImmediate();
    }

    /** Rust `cx.open_window(size(px(800.), px(600.)), ...)` + `run_until_parked` */
    function openWindow(position:Point):AnchoredTestView {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _:Context<AnchoredTestView>) -> new AnchoredTestView(position), 800, 600);
        cx = opened.cx;
        cx.runUntilParked();
        return opened.view;
    }

    function testAnchoredPositionWithoutScroll() {
        final view = openWindow(new Point(100, 100));

        final menuBounds = view.menuBounds;
        assertNotNull(menuBounds, 'MENU bounds not found');
        assertTrue(menuBounds.origin.equals(new Point(100, 100)), 'origin ' + menuBounds.origin);
        assertTrue(menuBounds.size.equals(size(200, 300)), 'size ' + menuBounds.size);
    }

    function testAnchoredPositionWhenScrolled() {
        final view = openWindow(new Point(100, 100));

        cx.update((window, cx) -> {
            window.dispatchEvent(new ScrollEvent(new Point(400, 300), ScrollDelta.Pixels(new Point(0, -1000))), cx);
        });

        cx.runUntilParked();

        final menuBounds = view.menuBounds;
        assertNotNull(menuBounds, 'MENU bounds not found');
        assertTrue(menuBounds.origin.equals(new Point(100, 100)), 'origin ' + menuBounds.origin);
        assertTrue(menuBounds.size.equals(size(200, 300)), 'size ' + menuBounds.size);
    }

    function testAnchoredSnapsToWindow() {
        final view = openWindow(new Point(100, 500));

        final menuBounds = view.menuBounds;
        assertNotNull(menuBounds, 'MENU bounds not found');
        assertTrue(menuBounds.origin.equals(new Point(100, 300)), 'origin ' + menuBounds.origin);
        assertTrue(menuBounds.size.equals(size(200, 300)), 'size ' + menuBounds.size);
    }

}

private class AnchoredTestView extends Model implements Render {

    final position:Point;

    public var menuBounds:Null<Bounds> = null;

    public function new(position:Point) {
        super();
        this.position = position;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child(
            div()
                .id('scroll-container')
                .overflowYScroll()
                .sizeFull()
                .child(div().h(px(2000)).wFull())
                .child(
                    deferred(
                        anchored()
                            .snapToWindow()
                            .position(position)
                            .child(
                                canvas((bounds, _, _) -> {
                                    menuBounds = bounds;
                                    return 0;
                                }, (_, _, _, _) -> {})
                                .w(px(200))
                                .h(px(300))
                            )
                    )
                    .withPriority(1)
                )
        );
    }

}
