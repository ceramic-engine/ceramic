// New code for the Haxe port of GPUI (no GPUI origin): support of the port's
// default view caching. See ViewElement and NOTICE.md.
package gpui;

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

    /** Changed checks by view id, then by state */
    final byView:IntMap<ObjectMap<{}, Void->Bool>> = new IntMap();

    /**
     * Depth of the views cached with a style (`.cached(style)`) being
     * rendered, prepainted or painted.
     */
    @:allow(gpui)
    var cachedStyleDepth:Int = 0;

    public function new() {}

    /**
     * Records that the view being drawn read `state`. `changed` tells
     * whether the state differs from what the view has drawn.
     */
    public function record(window:Window, state:{}, changed:Void->Bool):Void {
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
            checks = new ObjectMap();
            byView.set(viewId, checks);
        }
        checks.set(state, changed);
    }

    /**
     * Called when a frame starts: calls `markDirty` with every view of the
     * last frame whose recorded states changed, and forgets them (they
     * render and record again). Views missing from the last frame are
     * forgotten.
     */
    @:allow(gpui)
    function invalidateChanged(lastFrame:DispatchTree, markDirty:Int->Void):Void {
        var forget:Null<Array<Int>> = null;
        for (viewId => checks in byView) {
            var stale = !lastFrame.containsView(viewId);
            if (!stale) {
                for (changed in checks) {
                    if (changed()) {
                        markDirty(viewId);
                        stale = true;
                        break;
                    }
                }
            }
            if (stale) {
                if (forget == null) forget = [];
                forget.push(viewId);
            }
        }
        if (forget != null) {
            for (viewId in forget) {
                byView.remove(viewId);
            }
        }
    }

}
