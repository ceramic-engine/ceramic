// Ported from gpui-pre 0.3.10: src/elements/canvas.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A canvas element, meant for accessing the low level paint API without
 * defining a whole custom element. Create one with `Prelude.canvas()`.
 */
class Canvas<T> extends Element implements Styled {

    var prepaintFn:Null<(Bounds, Window, App) -> T>;

    var paintFn:Null<(Bounds, T, Window, App) -> Void>;

    final canvasStyle:StyleRefinement = new StyleRefinement();

    var computedStyle:Null<Style> = null;

    var prepaintState:Null<T> = null;

    var measureFn:Null<TaffyLayoutEngine.MeasureFn> = null;

    public function new(prepaint:(Bounds, Window, App) -> T, paint:(Bounds, T, Window, App) -> Void) {
        this.prepaintFn = prepaint;
        this.paintFn = paint;
    }

    public inline function style():StyleRefinement {
        return canvasStyle;
    }

    /**
     * Computes the size of the canvas with `fn` (new in the Haxe port, GPUI
     * has no equivalent short of a custom element): the canvas becomes a
     * measured leaf of the layout, like text. The layout calls `fn` with what
     * it already knows: `known` holds, for each axis, the size given by the
     * style or the parent (or `null`), and `available` the space the canvas
     * can take: `Definite(n)` (at most n pixels), `MinContent` (the smallest
     * size) or `MaxContent` (the ideal size without constraint). `fn` returns
     * the size of the canvas. It can be called several times per layout, with
     * different constraints: it must give the same answer to the same
     * question and change nothing visible.
     *
     * ```haxe
     * // A chart 24 pixels high per series, as wide as it is given (400 by default)
     * canvas(prepaintChart, paintChart)
     *     .measure((known, available, window, cx) -> {
     *         final width = known.width ?? switch available.width {
     *             case Definite(n): n;
     *             case _: 400.;
     *         };
     *         return size(px(width), px(series.length * 24.));
     *     })
     * ```
     *
     * When the data changes, the view renders again (tracker or `notify()`)
     * and the layout measures again: nothing else to do.
     */
    public function measure(fn:TaffyLayoutEngine.MeasureFn):Canvas<T> {
        measureFn = fn;
        return this;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final style = new Style();
        style.refine(canvasStyle);
        computedStyle = style;
        final measure = measureFn;
        if (measure != null) {
            return window.requestMeasuredLayout(style, measure);
        }
        return window.requestLayout(style, null, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final prepaint = prepaintFn;
        prepaintFn = null;
        prepaintState = prepaint(bounds, window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final state = prepaintState;
        prepaintState = null;
        final paint = paintFn;
        paintFn = null;
        final style = computedStyle;
        final cornerRadii = style.paintBackground(bounds, window, cx);
        paint(bounds, state, window, cx);
        style.paintBorder(bounds, cornerRadii, window, cx);
    }

}
