// Ported from gpui-kit 0.8.1: crates/component/src/carousel/carousel.rs (CarouselPagination)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.carousel;

import gpui.AnyElement;
import gpui.App;
import gpui.ElementId;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.component.I18n;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * A composable container for Carousel pagination items.
 *
 * The group role and its label are kept but not exported (no
 * accessibility tree in the GPUI port).
 */
class CarouselPagination implements RenderOnce implements Styled implements ParentElement {

    final id:ElementId;

    final paginationStyle:StyleRefinement = new StyleRefinement();

    var accessibilityLabelValue:String;

    final childElements:Array<AnyElement> = [];

    /** Creates an empty pagination container, identified by its call site. */
    public function new(?pos:haxe.PosInfos) {
        id = ElementId.CodeLocation(pos.fileName, pos.lineNumber);
        accessibilityLabelValue = I18n.t('Carousel.pagination');
    }

    /** Sets the name announced for the pagination group. */
    public function accessibilityLabel(label:String):CarouselPagination {
        accessibilityLabelValue = label;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):CarouselPagination {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):CarouselPagination {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public inline function style():StyleRefinement {
        return paginationStyle;
    }

    public function render(_:Window, _:App):IntoElement {
        final element = div()
            .id(id)
            .flex()
            .itemsCenter()
            .justifyCenter()
            .gap2();
        element.extend(childElements);
        return element.refineStyle(paginationStyle);
    }

}
