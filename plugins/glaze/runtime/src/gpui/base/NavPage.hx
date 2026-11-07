// Ported from gpui-kit 0.8.1: crates/base/src/nav_stack.rs (NavPage)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.AnyView;
import gpui.App;
import gpui.Div;
import gpui.IntoElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.NavStackState.NavOperation;
import gpui.base.motion.Presence.PresencePhase;

import gpui.Prelude.div;

/**
 * One mounted view of a `NavStack`, handed to the item renderer.
 *
 * The item fills its container. Its readers describe where the view is in
 * the change that is running, so the renderer can move it: `phase` says
 * whether it is arriving, settled, or leaving; `operation` says which
 * change; `progress` runs from `0.0` to `1.0` over the transition, already
 * eased, and is shared by both views of one change.
 */
class NavPage implements RenderOnce implements Styled {

    final base:Div;

    final styleRefinement:StyleRefinement = new StyleRefinement();

    final pageView:AnyView;

    final pageIndex:Int;

    final pagePhase:PresencePhase;

    final pageOperation:Null<NavOperation>;

    final pageProgress:Float;

    @:allow(gpui.base.NavStack)
    function new(view:AnyView, index:Int, phase:PresencePhase, operation:Null<NavOperation>, progress:Float) {
        this.base = div();
        this.pageView = view;
        this.pageIndex = index;
        this.pagePhase = phase;
        this.pageOperation = operation;
        this.pageProgress = progress;
    }

    public function style():StyleRefinement {
        return styleRefinement;
    }

    public inline function view():AnyView {
        return pageView;
    }

    /**
     * The view's position on the stack, root first. A view on its way out
     * keeps the position it had.
     */
    public inline function index():Int {
        return pageIndex;
    }

    public inline function phase():PresencePhase {
        return pagePhase;
    }

    /**
     * The change in progress, or `null` once the stack has settled.
     */
    public inline function operation():Null<NavOperation> {
        return pageOperation;
    }

    public inline function progress():Float {
        return pageProgress;
    }

    public function render(window:Window, cx:App):IntoElement {
        final base = this.base.absolute().inset0().child(pageView.intoAnyElement());
        base.style().refine(styleRefinement);
        return base;
    }

}
