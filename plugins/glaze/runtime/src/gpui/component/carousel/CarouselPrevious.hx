// Ported from gpui-kit 0.8.1: crates/component/src/carousel/carousel.rs (CarouselPrevious)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.carousel;

import gpui.AnyElement;
import gpui.App;
import gpui.Entity;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.Size.IntoSize;

/**
 * A previous-slide control positioned around the Carousel viewport.
 */
class CarouselPrevious implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final state:Entity<CarouselState>;

    @:allow(tests)
    var size:Size = Medium;

    final controlStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var accessibilityLabelValue:Null<String> = null;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Creates a previous-slide control bound to `state`. */
    public function new(state:Entity<CarouselState>) {
        this.state = state;
    }

    /** Replaces the generated previous-slide accessibility label and tooltip. */
    public function accessibilityLabel(label:String):CarouselPrevious {
        accessibilityLabelValue = label;
        return this;
    }

    public function withSize(size:IntoSize):CarouselPrevious {
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

    public function child(child:IntoElement):CarouselPrevious {
        childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):CarouselPrevious {
        for (child in children) childElements.push(child);
        return this;
    }

    public function render(_:Window, cx:App):IntoElement {
        return Carousel.carouselControl(state, size, controlStyle, accessibilityLabelValue, childElements, false, cx);
    }

}
