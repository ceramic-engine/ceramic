// New code for the Haxe port of GPUI (no GPUI origin): support of the port's
// default view caching. See ViewElement and NOTICE.md.
package glaze;

import haxe.ds.IntMap;
import haxe.ds.ObjectMap;

/**
 * The shared scroll states (`ListState`, `ScrollHandle`, uniform list
 * handles) that the views cached by default read while they were drawn.
 *
 * In GPUI, views are not cached unless embedded with `.cached(style)`: when
 * a window draws, every other view renders again and reads the current
 * state of its scroll handles. A handle is often changed by an element of
 * another view, which notifies its own view only: gpui-kit's `ScrollBounce`
 * of a scrollable `TextView` moves the list of the text view state (a child
 * view) and notifies the view painting the text view. With default caching,
 * the child view would be reused with its previous scroll position.
 *
 * So the elements reading a shared handle record it here with a check of
 * its state, and when the window draws its next frame, a view whose handle
 * changed since is dirty like a notified view (its ancestors too). This
 * never makes the window dirty: frames are drawn exactly when GPUI draws
 * them. Views inside a view cached with a style are not recorded: that view
 * is reused or rendered whole, like in GPUI.
 */
class ViewDependencies {

    /** Changed checks by view id */
    final byView:IntMap<ViewChecks> = new IntMap();

    /** The values of `byView`, iterated without allocating (a map's iteration copies them) */
    final views:Array<ViewChecks> = [];

    /**
     * Depth of the views cached with a style (`.cached(style)`) being
     * rendered, prepainted or painted.
     */
    @:allow(glaze)
    var cachedStyleDepth:Int = 0;

    public function new() {}

    /**
     * Records that the view being drawn read `state`. `changed` tells
     * whether the state differs from what the view has drawn.
     */
    public function record(window:Window, state:{}, changed:() -> Bool):Void {
        if (cachedStyleDepth > 0 || !window.viewCaching || window.viewCachingDisabled) {
            return;
        }
        final stack = @:privateAccess window.renderedEntityStack;
        if (stack.length == 0) {
            return;
        }
        final viewId = stack[stack.length - 1].entityId;
        var checks = byView.get(viewId);
        if (checks == null) {
            checks = new ViewChecks(viewId);
            byView.set(viewId, checks);
            views.push(checks);
        }
        checks.set(state, changed);
    }

    /**
     * Whether a recorded state changed since it was drawn (what
     * `invalidateChanged` would mark dirty), without marking anything.
     */
    @:allow(glaze)
    function anyChanged():Bool {
        for (view in views) {
            for (check in view.checks) {
                if (check()) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * Called when a frame starts: marks dirty (`Window.markViewDirty`) every
     * view of the last frame whose recorded states changed, and forgets them
     * (they render and record again). Views missing from the last frame are
     * forgotten.
     */
    @:allow(glaze)
    function invalidateChanged(lastFrame:DispatchTree, window:Window):Void {
        final views = this.views;
        var kept = 0;
        for (i in 0...views.length) {
            final view = views[i];
            final viewId = view.viewId;
            var stale = !lastFrame.containsView(viewId);
            if (!stale) {
                final checks = view.checks;
                for (j in 0...checks.length) {
                    if (checks[j]()) {
                        @:privateAccess window.markViewDirty(viewId);
                        stale = true;
                        break;
                    }
                }
            }
            if (stale) {
                byView.remove(viewId);
            }
            else {
                views[kept++] = view;
            }
        }
        views.resize(kept);
    }

}

/** The changed checks of one view, by state */
private class ViewChecks {

    public final viewId:Int;

    /** Index of each state in `checks` */
    final indexes:ObjectMap<{}, Int> = new ObjectMap();

    public final checks:Array<() -> Bool> = [];

    public function new(viewId:Int) {
        this.viewId = viewId;
    }

    public function set(state:{}, changed:() -> Bool):Void {
        final index = indexes.get(state);
        if (index != null) {
            checks[index] = changed;
        }
        else {
            indexes.set(state, checks.length);
            checks.push(changed);
        }
    }

}
