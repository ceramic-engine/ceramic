// Ported from gpui-kit 0.8.1: crates/base/src/touch_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Bounds;
import glaze.Hsla;
import glaze.Point;
import glaze.Size;
import glaze.Window;

import glaze.Prelude.*;

/**
 * The grab handle at one end of a touch selection: a bar down the caret
 * line with a knob at its outer end, the start's above and the end's below.
 */
class TouchHandle {

    /** How wide the finger may miss the knob and still take it. */
    public static inline final HIT_SIZE:Float = 44.;
    /** The knob's diameter. */
    public static inline final KNOB_SIZE:Float = 10.;
    /** The bar down the caret line. */
    public static inline final BAR_WIDTH:Float = 2.;
    /** Room the knob takes beyond the line, which an edit menu keeps clear. */
    public static inline final EXTENT:Float = 12.;

    /** The touch target, centered on the caret and reaching out past the knob. */
    public static function hitBounds(edge:SelectionEdge, caret:Bounds):Bounds {
        final top = edge == Start ? caret.top() - EXTENT : caret.top();
        return new Bounds(new Point(caret.left() - HIT_SIZE / 2., top), new Size(HIT_SIZE, caret.size.height + EXTENT));
    }

    /** Paints the handle for `edge` on the caret line box `caret`. */
    public static function paint(edge:SelectionEdge, caret:Bounds, color:Hsla, window:Window):Void {
        final bar = new Bounds(new Point(caret.left() - BAR_WIDTH / 2., caret.top()), new Size(BAR_WIDTH, caret.size.height));
        final knobTop = edge == Start ? caret.top() - KNOB_SIZE : caret.bottom();
        final knob = new Bounds(new Point(caret.left() - KNOB_SIZE / 2., knobTop), new Size(KNOB_SIZE, KNOB_SIZE));
        window.paintQuad(fill(bar, color));
        window.paintQuad(fill(knob, color).withCornerRadii(glaze.Corners.all(KNOB_SIZE / 2.)));
    }

}
