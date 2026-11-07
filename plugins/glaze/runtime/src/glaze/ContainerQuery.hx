// Ported from gpui-pre 0.3.10: src/elements/container_query.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A container query element, in the spirit of CSS container queries.
 * The element's own size is determined solely by its style and the space
 * offered by its parent. Create one with `Prelude.containerQuery()`.
 *
 * By default the element fills its parent (equivalent to `.sizeFull()`);
 * use the `Styled` methods to size it differently. Because the contents
 * don't exist until after layout, they cannot influence the element's size.
 */
class ContainerQuery extends Element implements Styled {

    var render:Null<(Size, Window, App) -> IntoElement>;

    final queryStyle:StyleRefinement = new StyleRefinement();

    var child:Null<AnyElement> = null;

    public function new(render:(Size, Window, App) -> IntoElement) {
        this.render = render;
        queryStyle.sizeWidth = Length.Definite(DefiniteLength.Fraction(1.));
        queryStyle.sizeHeight = Length.Definite(DefiniteLength.Fraction(1.));
    }

    public inline function style():StyleRefinement {
        return queryStyle;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final style = new Style();
        style.refine(queryStyle);
        return window.requestLayout(style, [], cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        final render = this.render;
        this.render = null;
        if (render == null) {
            child = null;
            return;
        }
        final element = render(bounds.size, window, cx).intoAnyElement();
        element.layoutAsRoot(bounds.size.mapOf(v -> AvailableSpace.Definite(v)), window, cx);
        element.prepaintAt(bounds.origin, window, cx);
        child = element;
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        if (child != null) {
            child.paint(window, cx);
        }
    }

}
