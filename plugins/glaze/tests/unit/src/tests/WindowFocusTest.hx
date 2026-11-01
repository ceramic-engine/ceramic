// Ported from gpui-pre 0.3.10: src/window.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import gpui.App;
import gpui.Bounds;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.TestDispatcher;
import gpui.Window;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

/**
 * The tests of `window.rs` about focus, frame callbacks and the root layout.
 *
 * Not ported: `test_focus_handle_release` and `test_dropped_focus_handle_blurs_only_its_windows`
 * (focus handles are never released in the port), the platform window tests
 * (frame journaling, frame demand and waker, throttling, scheduled frames and presentation,
 * visibility, displays, fully visible bounds, scale factor changes, raw handles, appearance),
 * `test_window_opened_during_draw_defers_arena_clear` (Rust element arena), file drag, touch,
 * back gesture, long press and inspector tests (not ported), and the underline tests (text system).
 *
 * `test_pending_next_frame_callbacks_are_not_stranded` and
 * `callback_queued_during_a_frame_requests_a_follow_up` drive the platform frame source in
 * Rust: here a frame request is `Window.simulateNextFrame()`, and a pending frame request is
 * `Window.hasNextFrameCallbacks()`.
 */
class WindowFocusTest extends TestCase {

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

    function addWindow<V:Model & Render>(build:(Window, Context<V>) -> V):Entity<V> {
        final opened = VisualTestContext.addWindowView(app, dispatcher, build);
        cx = opened.cx;
        return opened.view;
    }

    function testFocusMovedByFocusListenerIsDispatched() {
        var bFocusCount = 0;
        final window = addWindow((window, cx:Context<FocusForwarder>) -> {
            final a = cx.focusHandle();
            final b = cx.focusHandle();
            cx.onFocus(a, window, (self:FocusForwarder, window, cx) -> {
                final b = self.b;
                window.focus(b, cx.app);
            }).detach();
            cx.onFocus(b, window, (_, _, _) -> {
                bFocusCount++;
            }).detach();
            return new FocusForwarder(a, b);
        });

        cx.update((window, _) -> window.setActive(true));
        cx.runUntilParked();

        window.update(app, (self, cx) -> {
            final a = self.a;
            this.cx.window.focus(a, cx.app);
        });
        cx.runUntilParked();

        window.update(app, (self, _) -> {
            assertTrue(self.b.isFocused(this.cx.window));
        });
        assertEquals(1, bFocusCount);
    }

    /**
     * A frame request that arrives while next-frame callbacks are pending must never strand
     * them: the frame runs them.
     */
    function testPendingNextFrameCallbacksAreNotStranded() {
        addWindow((_, _) -> new EmptyView());
        // Establish a first frame
        cx.window.simulateNextFrame();

        var callbackRan = false;
        cx.update((window, _) -> {
            window.onNextFrame((_, _) -> callbackRan = true);
        });

        cx.window.simulateNextFrame();
        assertTrue(callbackRan || cx.window.hasNextFrameCallbacks(), 'a frame request with pending next-frame callbacks must either run them or re-arm the frame source');
        assertTrue(callbackRan);
    }

    function testCallbackQueuedDuringAFrameRequestsAFollowUp() {
        addWindow((_, _) -> new EmptyView());

        var callbackRan = false;
        cx.update((window, _) -> {
            window.setActive(true);
            window.onNextFrame((window, _) -> {
                window.onNextFrame((_, _) -> callbackRan = true);
            });
        });

        assertTrue(cx.window.simulateNextFrame() > 0);
        assertFalse(callbackRan);
        assertTrue(cx.window.hasNextFrameCallbacks(), 'a callback queued mid-frame must schedule a follow-up before the loop parks');

        assertTrue(cx.window.simulateNextFrame() > 0);
        assertTrue(callbackRan);
    }

    function testAutoSizedWindowRootFillsTheWindow() {
        final view = addWindow((_, _) -> new RootView(false)).read(app);

        final viewportSize = cx.update((window, _) -> {
            window.draw();
            return window.viewportSize();
        });

        assertTrue(view.childBounds.size.equals(viewportSize), 'child ${view.childBounds.size} viewport $viewportSize');
    }

    function testExplicitlySizedWindowRootKeepsItsSize() {
        final view = addWindow((_, _) -> new RootView(true)).read(app);

        cx.update((window, _) -> window.draw());

        assertTrue(view.childBounds.size.equals(size(px(300), px(200))), 'child ${view.childBounds.size}');
    }

}

private class EmptyView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }

}

private class FocusForwarder extends Model implements Render {

    public final a:FocusHandle;

    public final b:FocusHandle;

    public function new(a:FocusHandle, b:FocusHandle) {
        super();
        this.a = a;
        this.b = b;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .child(div().w(px(50)).h(px(50)).trackFocus(a))
            .child(div().w(px(50)).h(px(50)).trackFocus(b));
    }

}

private class RootView extends Model implements Render {

    final explicitSize:Bool;

    public var childBounds:Bounds = new Bounds();

    public function new(explicitSize:Bool) {
        super();
        this.explicitSize = explicitSize;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final root = div().flex().flexCol().child(
            canvas((bounds, _, _) -> {
                childBounds = bounds;
                return 0;
            }, (_, _, _, _) -> {}).sizeFull()
        );
        if (explicitSize) {
            return root.w(px(300)).h(px(200));
        }
        return root;
    }

}
