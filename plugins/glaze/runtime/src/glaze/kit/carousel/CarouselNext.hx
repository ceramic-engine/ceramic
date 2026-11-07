// Ported from gpui-kit 0.8.1: crates/component/src/carousel/carousel.rs (CarouselNext)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.carousel;

import glaze.AnyElement;
import glaze.App;
import glaze.Entity;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;

/**
 * A next-slide control positioned around the Carousel viewport.
 */
class CarouselNext implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<CarouselState>;

    @:allow(tests)
    var size:Size = Medium;

    final controlStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var accessibilityLabelValue:Null<String> = null;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Creates a next-slide control bound to `state`. */
    public function new(state:Entity<CarouselState>) {
        this.state = state;
    }

    /** Replaces the generated next-slide accessibility label and tooltip. */
    public function accessibilityLabel(label:String):CarouselNext {
        accessibilityLabelValue = label;
        return this;
    }

    public function withSize(size:IntoSize):CarouselNext {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    public inline function style():StyleRefinement {
        return controlStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):CarouselNext {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):CarouselNext {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(_:Window, cx:App):IntoElement {
        return Carousel.carouselControl(state, size, controlStyle, accessibilityLabelValue, childElements, true, cx);
    }

}
