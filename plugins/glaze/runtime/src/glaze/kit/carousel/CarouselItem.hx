// Ported from gpui-kit 0.8.1: crates/component/src/carousel/carousel.rs (CarouselItem)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.carousel;

import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Entity;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.I18n;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * One logical slide in a `CarouselContent`.
 *
 * The group role, its "Slide N of M" label and the position in the set are
 * computed (`accessibilityLabel`) but not exported: Glaze has no
 * accessibility tree.
 */
class CarouselItem extends Component implements Styled implements ParentElement {

    final id:ElementId;

    final index:Int;

    final state:Entity<CarouselState>;

    final itemStyle:StyleRefinement = new StyleRefinement();

    /** Replaces the generated "Slide N of M" accessibility label. */
    @prop var accessibilityLabel:Null<String> = null;

    final childElements:Array<AnyElement> = [];

    /** Creates the item at the zero-based `index` used by `state`. */
    public function new(id:ElementIdArg, index:Int, state:Entity<CarouselState>) {
        super();
        this.id = id;
        this.index = index;
        this.state = state;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):CarouselItem {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):CarouselItem {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public inline function style():StyleRefinement {
        return itemStyle;
    }

    public function render(_:Window, cx:App):IntoElement {
        final state = this.state.read(cx);
        final axis = state.axis();
        final count = state.itemCount();
        final label = accessibilityLabel != null ? accessibilityLabel : I18n.t('Carousel.slide', {current: index + 1, total: count});

        final element = div()
            .id(id)
            .minW0()
            .minH0()
            .flexNone();
        if (axis == Horizontal) element.wFull().pl4();
        if (axis == Vertical) element.hFull().pt4();
        element.extend(childElements);
        return element.refineStyle(itemStyle);
    }

}
