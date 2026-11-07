// Ported from gpui-pre 0.3.10: src/app.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Contains state associated with a tooltip. You'll only need this struct if you're implementing
 * tooltip behavior on a custom element. Otherwise, use `Div.tooltip()`.
 */
class AnyTooltip {

    /** The view used to display the tooltip */
    public final view:AnyView;

    /** The absolute position of the mouse when the tooltip was deployed. */
    public final mousePosition:Point;

    /**
     * Given the bounds of the tooltip, checks whether the tooltip should still be visible and
     * updates its state accordingly. This is needed atop the hovered element's mouse move handler
     * to handle the case where the element is not painted (e.g. via use of `visible_on_hover`).
     */
    public final checkVisibleAndUpdate:(Bounds, Window, App) -> Bool;

    public function new(view:AnyView, mousePosition:Point, checkVisibleAndUpdate:(Bounds, Window, App) -> Bool) {
        this.view = view;
        this.mousePosition = mousePosition;
        this.checkVisibleAndUpdate = checkVisibleAndUpdate;
    }

}
