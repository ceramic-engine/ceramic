// Ported from gpui-pre 0.3.10: src/window.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.scene.BorderStyle;

/**
 * A rectangle to be rendered in the window at the given position and size.
 * Passed as an argument to `Window.paintQuad()`.
 *
 * Differences with GPUI: mutable, so the window can reuse one instance
 * (`Window.scratchPaintQuad()`). Border widths and colors are flat fields;
 * the background is either `background`, or the solid HSLA fields when
 * `background` is `null` (avoids allocating a `Background` for borders).
 */
class PaintQuad {

    /** The bounds of the quad within the window. */
    public var bounds:Bounds;

    /** The radii of the quad's corners. */
    public var cornerRadii:Corners;

    /** The background of the quad, or `null` to use the solid fields. */
    public var background:Null<Background> = null;

    public var solidH:Float = 0;
    public var solidS:Float = 0;
    public var solidL:Float = 0;
    public var solidA:Float = 0;

    /** The widths of the quad's borders. */
    public var borderWidthTop:Float = 0;
    public var borderWidthRight:Float = 0;
    public var borderWidthBottom:Float = 0;
    public var borderWidthLeft:Float = 0;

    /** The color of the quad's borders. */
    public var borderColorH:Float = 0;
    public var borderColorS:Float = 0;
    public var borderColorL:Float = 0;
    public var borderColorA:Float = 0;

    /** The style of the quad's borders. */
    public var borderStyle:BorderStyle = Solid;

    public function new(?bounds:Bounds, ?cornerRadii:Corners) {
        this.bounds = bounds != null ? bounds : new Bounds();
        this.cornerRadii = cornerRadii != null ? cornerRadii : new Corners();
    }

    public inline function setSolidBackground(h:Float, s:Float, l:Float, a:Float):Void {
        background = null;
        solidH = h;
        solidS = s;
        solidL = l;
        solidA = a;
    }

    public inline function setBorderWidths(top:Float, right:Float, bottom:Float, left:Float):Void {
        borderWidthTop = top;
        borderWidthRight = right;
        borderWidthBottom = bottom;
        borderWidthLeft = left;
    }

    public inline function setBorderColor(h:Float, s:Float, l:Float, a:Float):Void {
        borderColorH = h;
        borderColorS = s;
        borderColorL = l;
        borderColorA = a;
    }

    /** Sets the border widths of the quad (builder). */
    public function withBorderWidths(widths:Edges):PaintQuad {
        setBorderWidths(widths.top, widths.right, widths.bottom, widths.left);
        return this;
    }

    /** Sets the border color of the quad (builder). */
    public function withBorderColor(color:IntoHsla):PaintQuad {
        final c:Hsla = color;
        setBorderColor(c.h, c.s, c.l, c.a);
        return this;
    }

    /** Sets the corner radii of the quad (builder). */
    public function withCornerRadii(radii:Corners):PaintQuad {
        cornerRadii = radii;
        return this;
    }

    /** Sets the background of the quad (builder). */
    public function withBackground(background:IntoBackground):PaintQuad {
        this.background = background;
        return this;
    }

    /** Sets the border style of the quad (builder). */
    public function withBorderStyle(style:BorderStyle):PaintQuad {
        borderStyle = style;
        return this;
    }

}
