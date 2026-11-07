// Ported from gpui-kit 0.8.1: crates/component/src/dialog/dispatch_anchor.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.dialog;

import gpui.Action;
import gpui.App;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Window;

import gpui.Prelude.*;

/**
 * A focus node of a dialog control's own, so the control can dispatch its
 * action on the dialog it sits in rather than on whatever holds focus when
 * it is clicked.
 *
 * `Window.dispatchAction` routes along the focused element. A surface that
 * keeps taking focus back (a native web view, an always-on-top window)
 * leaves every dialog button inert that way. Dispatching from a node inside
 * the control instead walks the control's own ancestors, which end at
 * exactly the dialog it belongs to, stacked dialogs included.
 *
 * Create it where the control renders, so the keyed state lives in that
 * control's scope, and place `element()` inside the control.
 */
@:allow(gpui.component)
class DialogDispatchAnchor {

    final handle:FocusHandle;

    function new(key:String, window:Window, cx:App) {
        this.handle = window.useKeyedState(key, cx, _ -> cx.focusHandle()).read(cx).value;
    }

    /**
     * A zero-size, out-of-flow node that tracks the handle. It is never
     * hovered, so it takes no focus of its own and does not enter the Tab
     * order; it only gives the handle a place in the dispatch tree.
     */
    function element():IntoElement {
        return div().absolute().size0().trackFocus(handle);
    }

    /**
     * Dispatches `action` from the anchor, falling back to the focused
     * element only if the anchor was never rendered.
     */
    function dispatch(action:Action, window:Window, cx:App):Void {
        if (handle.isFocused(window) || isRendered(window)) {
            handle.dispatchAction(action, window, cx);
        }
        else {
            window.dispatchAction(action, cx);
        }
    }

    function isRendered(window:Window):Bool {
        // `FocusHandle.dispatchAction` is a no-op for a handle the rendered
        // frame does not contain; `contains` answers from that same frame.
        return handle.contains(handle, window);
    }

}
