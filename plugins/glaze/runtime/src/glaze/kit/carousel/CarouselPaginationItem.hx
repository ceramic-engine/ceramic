// Ported from gpui-kit 0.8.1: crates/component/src/carousel/carousel.rs (CarouselPaginationItem)
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
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.button.Button;

using glaze.kit.base.StyledExt;

/**
 * One application-styled pagination control for a Carousel item.
 */
class CarouselPaginationItem extends Component implements Styled implements ParentElement implements Sizable {

    final id:ElementId;

    final index:Int;

    final state:Entity<CarouselState>;

    @:allow(tests)
    var size:Size = XSmall;

    final itemStyle:StyleRefinement = new StyleRefinement();

    /** Replaces the generated "Go to slide N" accessibility label. */
    @prop var accessibilityLabel:Null<String> = null;

    final childElements:Array<AnyElement> = [];

    /** Creates a pagination item for the zero-based `index`. */
    public function new(id:ElementIdArg, index:Int, state:Entity<CarouselState>) {
        super();
        this.id = id;
        this.index = index;
        this.state = state;
    }

    public function withSize(size:IntoSize):CarouselPaginationItem {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):CarouselPaginationItem {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):CarouselPaginationItem {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public inline function style():StyleRefinement {
        return itemStyle;
    }

    public function render(_:Window, cx:App):IntoElement {
        final snapshot = this.state.read(cx);
        final selected = snapshot.selectedIndex() == index;
        final disabled = index >= snapshot.itemCount();
        final focusHandle = snapshot.focusHandle(cx);
        final label = accessibilityLabel != null ? accessibilityLabel : I18n.t('Carousel.go_to_slide', {current: index + 1});
        final state = this.state;
        final index = this.index;

        final button = Button.component(id)
            .compact()
            .withSize(size)
            .selected(selected)
            .accessibilityLabel(label)
            .disabled(disabled);
        button.extend(childElements);
        if (!disabled) {
            button.onClick((event, window, cx) -> {
                state.update(cx, (state, cx) -> {
                    state.selectIndex(index, cx);
                });
                Carousel.focusAfterPointerClick(state, focusHandle, event, window, cx);
            });
        }
        return button.refineStyle(itemStyle);
    }

}
