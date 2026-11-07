// Ported from gpui-kit 0.8.1: crates/base/src/nav_stack.rs (NavStack)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.AnyView;
import gpui.App;
import gpui.Div;
import gpui.ElementId;
import gpui.Entity;
import gpui.IntoElement;
import gpui.RenderOnce;
import gpui.SpringMath.f32;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.NavStackState;
import gpui.base.motion.Presence;
import gpui.base.motion.Transition;
import gpui.base.motion.TransitionId;

import gpui.Prelude.div;

/**
 * An unstyled host for a `NavStackState`.
 *
 * The container is positioned so that the two views of a transition can
 * overlap; each mounted view is handed to the `item` renderer as a `NavPage`
 * that already fills the container. Everything else (size, clipping,
 * background, and how a transition moves) is the application's.
 *
 * Without a `transition` the stack switches views immediately, as it also
 * does under reduced motion.
 *
 * ```haxe
 * new NavStack(stack)
 *     .sizeFull()
 *     .transition(new Transition(0.2))
 *     .item((page, window, cx) -> page.left(px((1 - page.progress()) * 40)));
 * ```
 */
class NavStack implements RenderOnce implements Styled {

    final base:Div;

    final styleRefinement:StyleRefinement = new StyleRefinement();

    final state:Entity<NavStackState>;

    var policy:Null<Transition> = null;

    var renderItem:Null<(NavPage, Window, App) -> IntoElement> = null;

    public function new(state:Entity<NavStackState>) {
        this.base = div();
        this.state = state;
    }

    public function style():StyleRefinement {
        return styleRefinement;
    }

    /**
     * The timing every push, pop and replace runs under.
     */
    public function transition(transition:Transition):NavStack {
        policy = transition;
        return this;
    }

    /**
     * Renders each mounted view. The item is already positioned to fill the
     * container; refine it to move or fade the view by its phase and
     * progress, then return it.
     */
    public function item(render:(NavPage, Window, App) -> IntoElement):NavStack {
        renderItem = render;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final stack:NavStackState = state.read(cx);
        final current = stack.current();
        final depth = stack.depth();
        final transit = stack.transit;

        final immediate = cx.reduceMotion() || policy == null || (transit != null && transit.motion == Immediate);
        final transition = immediate ? new Transition(0) : policy;

        // The outgoing view's presence is the change's clock: its exit runs
        // 1 to 0, reversing if the change is interrupted, and both pages of
        // the change read their progress from it.
        var change:Null<NavTransit> = null;
        var progress = 1.0;
        if (transit != null) {
            final sample = new Presence(pageId(transit.outgoing), false).transition(transition).sample(window, cx);
            if (sample.shouldRender()) {
                change = transit;
                progress = f32(1.0 - sample.progress);
            }
            else {
                stack.clearTransit();
            }
        }

        // The current view's presence is sampled too, so a view brought back
        // by `forward` or revealed by `pop` starts its next exit from present.
        // With nothing changing it settles on the spot; the root does not
        // animate in.
        if (current != null) {
            new Presence(pageId(current), true).transition(change != null ? transition : new Transition(0)).sample(window, cx);
        }

        final items:Array<NavPage> = [];
        if (current != null) {
            final index = depth - 1;
            if (change != null) {
                final currentPage = new NavPage(current, index, Entering, change.operation, progress);
                final outgoingPage = new NavPage(change.outgoing, change.index, Exiting, change.operation, progress);
                // A pushed or replacing view paints over what it covers; a
                // popped view paints over what it reveals.
                switch change.operation {
                    case Push | Replace:
                        items.push(outgoingPage);
                        items.push(currentPage);
                    case Pop:
                        items.push(currentPage);
                        items.push(outgoingPage);
                }
            }
            else {
                items.push(new NavPage(current, index, Present, null, 1.0));
            }
        }
        final changing = items.length > 1;

        final base = this.base.relative();
        base.style().refine(styleRefinement);
        final render = renderItem;
        base.children([for (item in items) render != null ? render(item, window, cx) : (item : IntoElement)]);
        // Neither page takes pointer input while the change runs: the
        // outgoing one is on its way out, and the incoming one is not yet
        // where it will be.
        if (changing) {
            base.child(div().absolute().inset0().occlude());
        }
        return base;
    }

    static function pageId(view:AnyView):TransitionId {
        return ElementId.NamedInteger('nav-stack', view.entityId());
    }

}
