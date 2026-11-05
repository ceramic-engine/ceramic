// Ported from gpui-kit 0.8.1: crates/component/src/marker.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.marker;

import gpui.AnyElement;
import gpui.App;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.StyledText;
import gpui.Window;
import gpui.base.A11y;
import gpui.component.shimmer.ShimmerText;
import gpui.component.spinner.Spinner;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.AnimationExt;
using gpui.base.StyledExt;

enum abstract MarkerVariant(Int) {
    var Plain;
    /** Lines on both sides of the label. */
    var Separator;
    /** A bottom border. */
    var Border;
}

enum abstract MarkerLoadingStyle(Int) {
    var Spinner;
    var Shimmer;
}

enum abstract MarkerAlignment(Int) {
    var Start;
    var Center;
    var End;
}

enum MarkerChild {
    MIcon(icon:MarkerIcon);
    MContent(content:MarkerContent);
    MElement(element:AnyElement);
}

/**
 * A status line: an optional icon, content, in a plain, separator or
 * bordered variant, optionally loading (a spinner, or shimmering text).
 */
class Marker implements RenderOnce implements Styled implements ParentElement {

    @:allow(tests) var idValue:Null<ElementId> = null;

    @:allow(tests) final markerStyle:StyleRefinement = new StyleRefinement();

    var separatorStyleValue:StyleRefinement = new StyleRefinement();

    @:allow(tests) var variant:MarkerVariant = Plain;

    @:allow(tests) var alignmentValue:Null<MarkerAlignment> = null;

    @:allow(tests) var loadingValue:Bool = false;

    @:allow(tests) var loadingStyle:MarkerLoadingStyle = Spinner;

    var shimmerStyle:gpui.component.shimmer.ShimmerText.ShimmerStyle = new gpui.component.shimmer.ShimmerText.ShimmerStyle();

    @:allow(tests) var roleValue:RoleOverride = Implicit;

    @:allow(tests) final markerChildren:Array<MarkerChild> = [];

    /** The accessibility properties the marker exports (filled by `render`). */
    public final a11y:A11y = new A11y();

    public function new() {}

    public function id(id:ElementIdArg):Marker {
        idValue = id;
        return this;
    }

    public function role(role:RoleOverride):Marker {
        roleValue = role;
        return this;
    }

    public function withVariant(variant:MarkerVariant):Marker {
        this.variant = variant;
        return this;
    }

    public function alignment(alignment:MarkerAlignment):Marker {
        alignmentValue = alignment;
        return this;
    }

    @:allow(tests)
    function resolvedAlignment():MarkerAlignment {
        if (alignmentValue != null)
            return alignmentValue;
        return variant == Separator ? Center : Start;
    }

    public function loading(loading:Bool):Marker {
        loadingValue = loading;
        return this;
    }

    public function withLoadingStyle(loadingStyle:MarkerLoadingStyle):Marker {
        this.loadingStyle = loadingStyle;
        return this;
    }

    public function withShimmerStyle(shimmerStyle:gpui.component.shimmer.ShimmerText.ShimmerStyle):Marker {
        this.shimmerStyle = shimmerStyle;
        return this;
    }

    public function separatorStyle(style:StyleRefinement):Marker {
        separatorStyleValue = style;
        return this;
    }

    public function icon(icon:MarkerIcon):Marker {
        markerChildren.push(MIcon(icon));
        return this;
    }

    public function content(content:MarkerContent):Marker {
        markerChildren.push(MContent(content));
        return this;
    }

    public inline function style():StyleRefinement {
        return markerStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) markerChildren.push(MElement(element));
    }

    public function child(child:IntoElement):Marker {
        if (child != null) markerChildren.push(MElement(child));
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final tokens = Theme.global(cx).semanticTokens();
        final alignment = resolvedAlignment();
        final loading = loadingValue;
        var hasIcon = false;
        for (child in markerChildren) if (child.match(MIcon(_))) hasIcon = true;

        final row = gpui.base.Prelude.hFlex()
            .wFull()
            .minH(rems(1.))
            .gap2()
            .textSm()
            .lineHeight(gpui.Prelude.relative(1.5))
            .textColor(tokens.colors.mutedForeground);
        switch alignment {
            case Start: row.justifyStart().textLeft();
            case Center: row.justifyCenter().textCenter();
            case End: row.justifyEnd().textRight();
        }
        if (variant == Border) {
            row.borderB1().borderColor(tokens.colors.border).pb2();
        }
        if (variant == Separator && alignment != Start) {
            row.child(div().flex1().minW0().h(gpui.Prelude.px(1.)).mr1().bg(tokens.colors.border).refineStyle(separatorStyleValue));
        }
        if (loading && loadingStyle == Spinner && !hasIcon) {
            row.child(new MarkerIcon().child(new gpui.component.spinner.Spinner().xsmall()));
        }
        for (child in markerChildren) {
            switch child {
                case MIcon(icon): row.child(icon);
                case MContent(content):
                    content.shimmer = loading && loadingStyle == Shimmer;
                    content.shimmerStyle = shimmerStyle;
                    content.separator = variant == Separator;
                    content.alignment = alignment;
                    row.child(content);
                case MElement(element): row.child(element);
            }
        }
        if (variant == Separator && alignment != End) {
            row.child(div().flex1().minW0().h(gpui.Prelude.px(1.)).ml1().bg(tokens.colors.border).refineStyle(separatorStyleValue));
        }
        row.refineStyle(markerStyle);

        // `role` lives on the stateful element: accessibility nodes need the
        // stable identity that only an element id provides.
        if (idValue != null) {
            row.id(idValue);
            switch roleValue {
                case Explicit(role): a11y.role = role;
                case _:
            }
        }
        return row;
    }

}

/**
 * The icon slot of a `Marker` (a 1rem square).
 */
class MarkerIcon implements RenderOnce implements Styled implements ParentElement {

    final iconStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests) final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return iconStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):MarkerIcon {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final element = gpui.base.Prelude.hFlex().size4().flexNone().itemsCenter().justifyCenter().refineStyle(iconStyle);
        element.extend(childElements);
        return element;
    }

}

enum MarkerContentChild {
    Text(text:String);
    Element(element:AnyElement);
}

/**
 * The content of a `Marker`: text (shimmering while the marker loads with
 * the shimmer style) and elements.
 */
class MarkerContent implements RenderOnce implements Styled implements ParentElement {

    final contentStyle:StyleRefinement = new StyleRefinement();

    @:allow(gpui.component.marker) var shimmer:Bool = false;

    @:allow(gpui.component.marker) var shimmerStyle:gpui.component.shimmer.ShimmerText.ShimmerStyle = new gpui.component.shimmer.ShimmerText.ShimmerStyle();

    @:allow(gpui.component.marker) var separator:Bool = false;

    @:allow(gpui.component.marker) var alignment:MarkerAlignment = Start;

    @:allow(tests) final contentChildren:Array<MarkerContentChild> = [];

    public function new() {}

    public function text(text:String):MarkerContent {
        contentChildren.push(Text(text));
        return this;
    }

    public inline function style():StyleRefinement {
        return contentStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) contentChildren.push(Element(element));
    }

    public function child(child:IntoElement):MarkerContent {
        if (child != null) contentChildren.push(Element(child));
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final animate = shimmer && !cx.reduceMotion();
        var hasText = false;
        for (child in contentChildren) if (child.match(Text(_))) hasText = true;
        final baseOpacity = (contentStyle.mask & StyleRefinement.OPACITY) != 0 ? contentStyle.opacity : 1.;

        final content = div().minW0();
        // Between separator lines the label keeps its own width so the lines
        // take the rest; elsewhere it may shrink and wrap.
        if (separator) content.flexNone();
        switch alignment {
            case Start: content.textLeft();
            case Center: content.textCenter();
            case End: content.textRight();
        }
        content.refineStyle(contentStyle);
        for (index in 0...contentChildren.length) {
            switch contentChildren[index] {
                case Text(text) if (animate):
                    content.child(new ShimmerText(text).id(ElementId.NamedInteger('marker-loading-text', index)).withShimmerStyle(shimmerStyle));
                case Text(text):
                    content.child(new StyledText(text));
                case Element(element):
                    content.child(element);
            }
        }

        if (animate && !hasText) {
            return content.withAnimation('marker-loading-content', shimmerStyle.animation(), (element, phase) -> {
                final highlight = Math.cos(phase * Math.PI * 2.) * 0.5 + 0.5;
                return element.opacity(baseOpacity * (highlight * 0.4 + 0.6));
            });
        }
        return content;
    }

}
