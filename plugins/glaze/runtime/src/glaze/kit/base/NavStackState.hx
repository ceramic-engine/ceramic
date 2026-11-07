// Ported from gpui-kit 0.8.1: crates/base/src/nav_stack.rs (NavStackState, NavOperation, NavMotion, NavStackEvent, Transit)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyView;
import glaze.Context;
import glaze.Model;
import haxe.ds.ReadOnlyArray;

/**
 * What a running transition is doing, in Qt's terms.
 *
 * The operation decides paint order and lets a renderer move a pushed view
 * differently from a popped one.
 */
enum abstract NavOperation(Int) {
    /** A view was pushed over the previous top. */
    var Push = 0;
    /** The top was popped, revealing the view below. */
    var Pop = 1;
    /** The top was swapped for another view. */
    var Replace = 2;
}

/**
 * Whether one change runs the `NavStack`'s transition, as UIKit's
 * `animated:` and Qt's `StackView.Immediate` decide per call.
 *
 * `Immediate` switches views on the spot even when the element has a
 * transition, which is what restoring a stack at launch or jumping to a page
 * from a command wants. A `NavStack` without a transition is always
 * immediate, whatever is passed here.
 */
enum abstract NavMotion(Int) {
    var Animated = 0;
    var Immediate = 1;
}

/**
 * Emitted by `NavStackState` after the stack changed. A plain enum (not an
 * `enum abstract`) so that `cx.subscribe(stack, NavStackEvent, ...)` can
 * match it.
 */
enum NavStackEvent {
    Pushed;
    Popped;
    Forwarded;
    Replaced;
    Cleared;
}

/**
 * The view leaving the stack, kept mounted until its exit transition
 * finishes (Rust's private `Transit`). The element samples that transition
 * as a `Presence` keyed by the view, so an interrupted change reverses from
 * where it is.
 */
class NavTransit {

    public final outgoing:AnyView;

    /** The position the outgoing view had on the stack. */
    public final index:Int;

    public final operation:NavOperation;

    public final motion:NavMotion;

    public function new(outgoing:AnyView, index:Int, operation:NavOperation, motion:NavMotion) {
        this.outgoing = outgoing;
        this.index = index;
        this.operation = operation;
        this.motion = motion;
    }

}

/**
 * A stack of views, one visible at a time, with the pages popped off it
 * kept for `forward`.
 *
 * This is SwiftUI's `NavigationStack`, Qt's `StackView` and WinUI's
 * `Frame`: navigation between pages. Underneath it is a `History` of views
 * from the root through the current page. A popped page becomes a forward
 * entry until a push discards that forward branch.
 *
 * The stack owns which view is current and the lifecycle of a change: after
 * a push, pop or replace, the outgoing view stays mounted until the
 * `NavStack`'s transition finishes, so the application can animate it. The
 * views themselves, and what a transition looks like, belong to the
 * application.
 *
 * `pop` keeps the root, as Qt's `StackView` and UIKit's navigation
 * controller do; `clear` is the way to empty the stack. A back button is
 * shown when `depth() > 1`, a forward button when `forwardViews()` is not
 * empty.
 *
 * Reactivity: `history` is an `@observe` field mutated in place, so every
 * change calls `invalidateHistory()`, which redraws the views that read the
 * stack (a `NavStack` reads it while rendering). `transit` is not observable:
 * `NavStack` clears it while rendering, which must not invalidate the view
 * being drawn. Changes still call `cx.notify()` for `cx.observe` observers,
 * as in Rust.
 */
class NavStackState extends Model {

    @observe var history:History<AnyView> = new History();

    /**
     * The change in transit, if any (read by `NavStack`, and by tests).
     */
    public var transit(default, null):Null<NavTransit> = null;

    public function new() {
        super();
    }

    /**
     * The number of views on the stack.
     */
    public inline function depth():Int {
        return history.entries().length;
    }

    public inline function isEmpty():Bool {
        return history.entries().length == 0;
    }

    /**
     * The view on top of the stack, which is the one shown once any
     * transition has finished.
     */
    public inline function current():Null<AnyView> {
        return history.current();
    }

    /**
     * Every view on the stack, root first.
     */
    public inline function views():ReadOnlyArray<AnyView> {
        return history.entries();
    }

    /**
     * The views popped since the last push, nearest first: the one `forward`
     * would bring back is the first.
     */
    public inline function forwardViews():Array<AnyView> {
        return history.forwardEntries();
    }

    /**
     * Pushes `view` on top of the stack and discards the forward views.
     *
     * Into an empty stack this is immediate, like Qt's `initialItem`. Over an
     * existing top it starts a `Push` transition, unless `motion` is
     * `Immediate`.
     */
    public function push(view:AnyView, motion:NavMotion, cx:Context<NavStackState>):Void {
        final outgoing = current();
        final index = depth() - 1;
        history.push(view);
        finish(outgoing, index, Push, motion, Pushed, cx);
    }

    /**
     * Pops the top view and returns it, starting a `Pop` transition to the
     * view below. The view waits in `forwardViews`.
     *
     * The root is never popped: this returns `null` at a depth of one or less.
     */
    public function pop(motion:NavMotion, cx:Context<NavStackState>):Null<AnyView> {
        if (depth() <= 1) {
            return null;
        }
        final popped = current();
        final index = depth() - 1;
        if (history.back() == null) {
            return null;
        }
        finish(popped, index, Pop, motion, Popped, cx);
        return popped;
    }

    /**
     * Pops every view above the root in one `Pop` transition from the
     * previous top, and returns them root-side first.
     */
    public function popToRoot(motion:NavMotion, cx:Context<NavStackState>):Array<AnyView> {
        final outgoing = current();
        final index = depth() - 1;
        final popped:Array<AnyView> = [];
        while (depth() > 1) {
            final view = current();
            if (view == null) {
                break;
            }
            if (history.back() == null) {
                break;
            }
            popped.push(view);
        }
        if (popped.length == 0) {
            return popped;
        }
        finish(outgoing, index, Pop, motion, Popped, cx);
        popped.reverse();
        return popped;
    }

    /**
     * Brings back the most recently popped view, starting a `Push` transition
     * over the current top, and returns it. `null` when nothing has been
     * popped since the last push.
     */
    public function forward(motion:NavMotion, cx:Context<NavStackState>):Null<AnyView> {
        final outgoing = current();
        final index = depth() - 1;
        final view = history.forward();
        if (view == null) {
            return null;
        }
        finish(outgoing, index, Push, motion, Forwarded, cx);
        return view;
    }

    /**
     * Swaps the top view for `view` and returns the one replaced, starting a
     * `Replace` transition. The forward views are kept. On an empty stack
     * this is a push.
     */
    public function replace(view:AnyView, motion:NavMotion, cx:Context<NavStackState>):Null<AnyView> {
        final replaced = current();
        if (replaced == null) {
            push(view, motion, cx);
            return null;
        }
        final index = depth() - 1;
        history.replaceCurrent(view);
        finish(replaced, index, Replace, motion, Replaced, cx);
        return replaced;
    }

    /**
     * Empties the stack and the forward views immediately, abandoning any
     * running transition.
     */
    public function clear(cx:Context<NavStackState>):Void {
        history.clear();
        invalidateHistory();
        transit = null;
        cx.emit(NavStackEvent.Cleared);
        cx.notify();
    }

    /**
     * Forgets the change in transit once its exit has run (written by
     * `NavStack` while it renders, without notifying, as Rust does).
     */
    @:allow(glaze.kit.base.NavStack)
    function clearTransit():Void {
        transit = null;
    }

    /**
     * Records the change: `outgoing` stays mounted until its exit transition
     * finishes, or not at all for an immediate change. A change already in
     * transit is superseded, so at most one outgoing view is ever mounted;
     * the element reverses its presence from wherever it is.
     */
    function finish(outgoing:Null<AnyView>, index:Int, operation:NavOperation, motion:NavMotion, event:NavStackEvent, cx:Context<NavStackState>):Void {
        transit = outgoing != null ? new NavTransit(outgoing, index, operation, motion) : null;
        invalidateHistory();
        cx.emit(event);
        cx.notify();
    }

}
