// Ported from gpui-kit 0.8.1: crates/component/src/resizable.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.resizable;

import glaze.AnyElement;
import glaze.App;
import glaze.Axis;
import glaze.ElementIdArg;
import glaze.Pixels;
import glaze.Window;
import glaze.kit.base.motion.Motion;
import glaze.kit.base.motion.Transition;
import glaze.kit.base.resizable.ResizablePanel;
import glaze.kit.base.resizable.ResizablePanelGroup;
import glaze.kit.base.resizable.ResizeHandle;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

/**
 * What this design system paints inside a resize handle.
 *
 * Base owns the band, the cursor and the drag; everything here is appearance.
 * A divider rests as the same hairline it has always been, and answers the
 * pointer with a pill that grows and solidifies as the pointer engages it:
 * available, held, being dragged.
 *
 * The other types (`ResizablePanel`, `ResizablePanelGroup`, `ResizableState`,
 * `ResizeHandle`, `HandleEdge`) are gpui-base's, in `glaze.kit.base.resizable`.
 */
class Resizable {

    /**
     * How thick the indicator is across the divider it sits on.
     */
    static inline final INDICATOR_THICKNESS:Pixels = 3.;

    /**
     * Create a `ResizablePanelGroup` with horizontal resizing.
     */
    public static function hResizable(id:ElementIdArg):ResizablePanelGroup {
        return glaze.kit.base.resizable.Resizable.hResizable(id).withHandleAppearance(resizeHandleAppearance());
    }

    /**
     * Create a `ResizablePanelGroup` with vertical resizing.
     */
    public static function vResizable(id:ElementIdArg):ResizablePanelGroup {
        return glaze.kit.base.resizable.Resizable.vResizable(id).withHandleAppearance(resizeHandleAppearance());
    }

    /**
     * Create a `ResizablePanel`.
     */
    public static inline function resizablePanel():ResizablePanel {
        return glaze.kit.base.resizable.Resizable.resizablePanel();
    }

    /**
     * Create a standalone `ResizeHandle` wearing this design system's
     * divider, for an edge no `ResizablePanelGroup` owns (an application's
     * sidebar, say). What the drag resizes is the caller's.
     */
    public static function resizeHandle<T>(id:ElementIdArg, axis:Axis):ResizeHandle<T> {
        return ResizeHandle.resizeHandle(id, axis).withAppearance(resizeHandleAppearance());
    }

    /**
     * This design system's divider appearance, for a handle that base does
     * not already hand it (a dock edge, or a hand-rolled handle).
     */
    public static function resizeHandleAppearance():ResizeHandleRenderer {
        return (handle, window, cx) -> renderResizeHandle(handle, window, cx);
    }

    /**
     * How long the indicator is at each level of engagement, and how solid
     * (length, opacity).
     *
     * Idle draws nothing. The hairline is the resting appearance of a
     * divider.
     */
    @:allow(glaze.kit, tests)
    static function indicator(state:ResizeHandleState):{length:Pixels, opacity:Float} {
        return switch state {
            case Idle: {length: 0., opacity: 0.};
            case Hovered: {length: 20., opacity: 0.35};
            case Pressed: {length: 28., opacity: 0.6};
            case Dragging: {length: 44., opacity: 0.9};
        }
    }

    /**
     * The hairline, and the indicator riding on it.
     */
    @:allow(glaze.kit, tests)
    static function renderResizeHandle(handle:ResizeHandleContext, window:Window, cx:App):AnyElement {
        final theme = Theme.global(cx);
        final axis = handle.axis();
        final target = indicator(handle.state());
        final motion = theme.motionTokens();
        final policy = new Transition(motion.durationFast).easing(motion.easingMove);

        // Both values are sampled on every frame the handle is rendered,
        // whatever it is showing. A transition asks for a frame only while it
        // is moving, so a resting handle costs nothing.
        final length = Motion.transition('resizable-handle-indicator-length', target.length, policy, window, cx);
        // An overshooting theme curve may carry the length past its target,
        // but the opacity has to stay a valid alpha.
        var opacity = Motion.transition('resizable-handle-indicator-opacity', target.opacity, policy, window, cx);
        opacity = opacity < 0. ? 0. : (opacity > 1. ? 1. : opacity);

        final line = div()
            // The hairline fills the handle's content area exactly, so it has
            // nothing to give: shrinking it collapses the divider.
            .flexNone()
            .flex()
            .bg(theme.border);
        // Along the hairline the pill is far shorter than the line, so
        // centring it there is safe. Across the hairline it is thicker than
        // the line and has to overhang, so that axis is offset by hand.
        switch axis {
            case Horizontal: line.w(px(1.)).hFull().itemsCenter();
            case _: line.h(px(1.)).wFull().itemsStart().justifyCenter();
        }
        if (length > 0.5) {
            final pill = div()
                // `flexNone` keeps the one-pixel line from squashing it.
                .flexNone()
                .rounded(theme.radiusFull())
                .bg(theme.mutedForeground)
                .opacity(opacity);
            // Half the overhang, pulled back so the pill straddles the
            // hairline evenly.
            switch axis {
                case Horizontal:
                    pill.w(px(INDICATOR_THICKNESS)).h(px(length)).ml(px((INDICATOR_THICKNESS - 1.) * -0.5));
                case _:
                    pill.h(px(INDICATOR_THICKNESS)).w(px(length)).mt(px((INDICATOR_THICKNESS - 1.) * -0.5));
            }
            // A hugging handle's hairline is its container's outermost pixel,
            // so the pill's outer pixel lies past the boundary, where a
            // dock's clip would take it off. Deferring the pill (and only the
            // pill, only while it is up) paints it after the tree under the
            // window's mask, so it keeps that pixel.
            if (handle.edge() != null) {
                line.child(deferred(pill));
            } else {
                line.child(pill);
            }
        }
        return line.intoAnyElement();
    }

}
