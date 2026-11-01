// Ported from gpui-kit 0.8.1: crates/base/src/event.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.App;
import gpui.ClickEvent;
import gpui.Div;
import gpui.Window;

using gpui.ClickEvent.ClickEventTools;

/**
 * Interaction helpers on a `Div` with an id, as a static extension:
 * `using gpui.base.InteractiveElementExt;`.
 *
 * Rust's `OngoingScrollExt::lock_axis` (axis lock of wheel gestures, a no-op
 * on wasm) has no counterpart: the port has no `OngoingScroll`.
 */
class InteractiveElementExt {

    /**
     * Locks scrolling to the gesture's dominant axis (GPUI's
     * `restrict_scroll_to_axis`).
     */
    public static function lockScrollAxis(self:Div):Div {
        return self.restrictScrollToAxis();
    }

    /**
     * Set the listener for a double click event.
     */
    public static function onDoubleClick(self:Div, listener:(ClickEvent, Window, App) -> Void):Div {
        self.interactivity.onClick((event, window, cx) -> {
            if (event.clickCount() == 2) {
                listener(event, window, cx);
            }
        });
        return self;
    }

}
