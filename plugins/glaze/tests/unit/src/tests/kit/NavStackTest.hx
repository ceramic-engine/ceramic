// Ported from gpui-kit 0.8.1: crates/base/src/nav_stack.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.AnyView;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.kit.base.NavStack;
import glaze.kit.base.NavStackState;
import glaze.kit.base.motion.Transition;

import glaze.Prelude.*;

class NavTestPage extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }

}

class NavTestHost extends Model implements Render {

    final stack:Entity<NavStackState>;

    public function new(stack:Entity<NavStackState>) {
        super();
        this.stack = stack;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new NavStack(stack).sizeFull().transition(new Transition(0.2));
    }

}

/**
 * Tests of `glaze.kit.base.NavStackState` and `NavStack` (Rust `nav_stack.rs`).
 */
class NavStackTest extends KitTestCase {

    function page():AnyView {
        return app.newEntity(_ -> new NavTestPage());
    }

    function stack(events:Array<NavStackEvent>):Entity<NavStackState> {
        final stack = app.newEntity(_ -> new NavStackState());
        app.subscribe(stack, NavStackEvent, (_, event, _) -> events.push(event));
        return stack;
    }

    static inline function state(stack:Entity<NavStackState>):NavStackState {
        return stack;
    }

    function testPushAndPopKeepTheRoot() {
        final events:Array<NavStackEvent> = [];
        final stack = stack(events);
        final root = page();
        final second = page();

        stack.update(app, (stack, cx) -> stack.push(root, Animated, cx));
        assertNull(state(stack).transit);

        stack.update(app, (stack, cx) -> stack.push(second, Animated, cx));
        assertEquals(2, state(stack).depth());
        assertTrue(state(stack).current() == second);
        var transit = state(stack).transit;
        assertNotNull(transit, 'push over a view transitions');
        assertEquals(Push, transit.operation);
        assertTrue(transit.outgoing == root);

        final popped = stack.update(app, (stack, cx) -> stack.pop(Animated, cx));
        assertTrue(popped == second);
        assertEquals(1, state(stack).views().length);
        assertTrue(state(stack).views()[0] == root);
        transit = state(stack).transit;
        assertNotNull(transit, 'pop transitions');
        assertEquals(Pop, transit.operation);
        assertTrue(transit.outgoing == second);
        assertEquals(1, transit.index, 'the popped view keeps its position');

        assertNull(stack.update(app, (stack, cx) -> stack.pop(Animated, cx)));
        assertEquals(1, state(stack).depth());
        assertEquals('Pushed,Pushed,Popped', events.join(','));
    }

    function testPopToRootReturnsEverythingAboveIt() {
        final stack = stack([]);
        final pages = [for (_ in 0...3) page()];
        for (view in pages) {
            stack.update(app, (stack, cx) -> stack.push(view, Animated, cx));
        }

        final popped = stack.update(app, (stack, cx) -> stack.popToRoot(Animated, cx));
        assertEquals(2, popped.length);
        assertTrue(popped[0] == pages[1] && popped[1] == pages[2]);
        assertEquals(1, state(stack).views().length);
        assertTrue(state(stack).views()[0] == pages[0]);
        final transit = state(stack).transit;
        assertNotNull(transit, 'pop_to_root transitions');
        assertTrue(transit.outgoing == pages[2]);
        assertEquals(2, transit.index, 'the previous top keeps its position');
        assertEquals(0, stack.update(app, (stack, cx) -> stack.popToRoot(Animated, cx)).length);
    }

    function testReplaceSwapsTheTopAndPushesIntoAnEmptyStack() {
        final events:Array<NavStackEvent> = [];
        final stack = stack(events);
        final first = page();
        final second = page();

        assertNull(stack.update(app, (stack, cx) -> stack.replace(first, Animated, cx)));
        assertTrue(stack.update(app, (stack, cx) -> stack.replace(second, Animated, cx)) == first);
        assertEquals(1, state(stack).views().length);
        assertTrue(state(stack).views()[0] == second);
        final transit = state(stack).transit;
        assertNotNull(transit, 'replace transitions');
        assertEquals(Replace, transit.operation);
        assertTrue(transit.outgoing == first);
        assertEquals(0, transit.index, 'the replaced view sat where the new one sits');

        stack.update(app, (stack, cx) -> stack.clear(cx));
        assertTrue(state(stack).isEmpty());
        assertNull(state(stack).transit);
        assertEquals('Pushed,Replaced,Cleared', events.join(','));
    }

    function testPoppedViewsWaitForForwardUntilTheNextPush() {
        final events:Array<NavStackEvent> = [];
        final stack = stack(events);
        final pages = [for (_ in 0...3) page()];
        for (view in pages) {
            stack.update(app, (stack, cx) -> stack.push(view, Animated, cx));
        }
        assertNull(stack.update(app, (stack, cx) -> stack.forward(Animated, cx)));

        stack.update(app, (stack, cx) -> {
            stack.pop(Animated, cx);
            stack.pop(Animated, cx);
        });
        assertEquals(1, state(stack).depth());
        final forwardViews = state(stack).forwardViews();
        assertEquals(2, forwardViews.length);
        assertTrue(forwardViews[0] == pages[1] && forwardViews[1] == pages[2]);

        final broughtBack = stack.update(app, (stack, cx) -> stack.forward(Animated, cx));
        assertTrue(broughtBack == pages[1]);
        assertTrue(state(stack).current() == pages[1]);
        final transit = state(stack).transit;
        assertNotNull(transit, 'forward transitions like a push');
        assertEquals(Push, transit.operation);
        assertTrue(transit.outgoing == pages[0]);
        assertEquals(1, state(stack).forwardViews().length);

        final fresh = page();
        stack.update(app, (stack, cx) -> stack.push(fresh, Animated, cx));
        assertEquals(0, state(stack).forwardViews().length);
        assertEquals(Pushed, events[events.length - 1]);
        assertTrue(events.indexOf(Forwarded) >= 0);
    }

    function testAnImmediateChangeRecordsItsMotionAndSupersedesTheRunningOne() {
        final events:Array<NavStackEvent> = [];
        final stack = stack(events);
        final root = page();
        final second = page();
        final third = page();
        stack.update(app, (stack, cx) -> {
            stack.push(root, Animated, cx);
            stack.push(second, Animated, cx);
            stack.push(third, Immediate, cx);
        });
        assertTrue(state(stack).current() == third);
        var transit = state(stack).transit;
        assertNotNull(transit, 'the change is recorded');
        assertEquals(Immediate, transit.motion);
        assertTrue(transit.outgoing == second, 'the running push was superseded');

        assertTrue(stack.update(app, (stack, cx) -> stack.pop(Immediate, cx)) == third);
        transit = state(stack).transit;
        assertEquals(Immediate, transit.motion);
        assertTrue(transit.outgoing == third);
        assertEquals(4, events.length);
    }

    function testTheOutgoingViewIsDroppedOnceItsExitHasRun() {
        final stack = app.newEntity(_ -> new NavStackState());
        final root = page();
        final second = page();
        final opened = openWindow(_ -> new NavTestHost(stack));
        stack.update(app, (stack, cx) -> {
            stack.push(root, Immediate, cx);
            stack.push(second, Animated, cx);
        });

        opened.window.draw();
        assertNotNull(state(stack).transit);

        advanceClock(100);
        opened.window.draw();
        assertNotNull(state(stack).transit);

        advanceClock(150);
        opened.window.draw();
        assertNull(state(stack).transit);

        // An immediate change is gone after the frame that draws it.
        stack.update(app, (stack, cx) -> {
            stack.pop(Immediate, cx);
        });
        opened.window.draw();
        assertNull(state(stack).transit);
    }

    function testANewOperationReplacesTheRunningTransition() {
        final stack = stack([]);
        final pages = [for (_ in 0...3) page()];
        for (view in pages) {
            stack.update(app, (stack, cx) -> stack.push(view, Animated, cx));
        }
        stack.update(app, (stack, cx) -> {
            stack.pop(Animated, cx);
        });
        final transit = state(stack).transit;
        assertEquals(Pop, transit.operation);
        assertTrue(transit.outgoing == pages[2]);
    }

}
