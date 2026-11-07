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

    public function new(prepaint:(Bounds, Window, App) -> T, paint:(Bounds, T, Window, App) -> Void) {
        this.prepaintFn = prepaint;
        this.paintFn = paint;
    }

    public inline function style():StyleRefinement {
        return canvasStyle;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final style = new Style();
        style.refine(canvasStyle);
        computedStyle = style;
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
