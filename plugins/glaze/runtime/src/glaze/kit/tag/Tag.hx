// Ported from gpui-kit 0.8.1: crates/component/src/tag.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.tag;

import glaze.AbsoluteLength;
import glaze.AnyElement;
import glaze.App;
import glaze.Hsla;
import glaze.IntoAbsoluteLength;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.theme.ColorName;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A small labelled chip, in a color variant, filled or outlined.
 */
class Tag implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final tagStyle:StyleRefinement = new StyleRefinement();

    var variant:TagVariant = Secondary;

    var outlineValue:Bool = false;

    var size:Size = Medium;

    var roundedValue:Null<AbsoluteLength> = null;

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public static function primary():Tag return Tag.component().withVariant(Primary);

    public static function secondary():Tag return Tag.component().withVariant(Secondary);

    public static function danger():Tag return Tag.component().withVariant(Danger);

    public static function success():Tag return Tag.component().withVariant(Success);

    public static function warning():Tag return Tag.component().withVariant(Warning);

    public static function info():Tag return Tag.component().withVariant(Info);

    /**
     * Create a new tag with custom colors.
     */
    public static function custom(color:Hsla, foreground:Hsla, border:Hsla):Tag {
        return Tag.component().withVariant(Custom(color, foreground, border));
    }

    /**
     * Create a new tag with a color of the palette.
     */
    public static function color(color:ColorName):Tag {
        return Tag.component().withVariant(Color(color));
    }

    public function withVariant(variant:TagVariant):Tag {
        this.variant = variant;
        return this;
    }

    /**
     * Use outline style.
     */
    public function outline():Tag {
        outlineValue = true;
        return this;
    }

    /**
     * Set the corner radius (Rust `rounded`, which replaces the `Styled`
     * method of the same name).
     */
    public function rounded(radius:IntoAbsoluteLength):Tag {
        roundedValue = radius;
        return this;
    }

    /**
     * Set the corner radius to fully rounded (1rem).
     */
    public function roundedFull():Tag {
        roundedValue = AbsoluteLength.Rems(1.);
        return this;
    }

    public inline function style():StyleRefinement {
        return tagStyle;
    }

    public function withSize(size:IntoSize):Tag {
        this.size = size;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Tag {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Tag {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final bg = outlineValue ? transparentWhite() : variant.bg(cx);
        final fg = variant.fg(outlineValue, cx);
        final border = variant.border(cx);
        final rounded:AbsoluteLength = roundedValue != null ? roundedValue : AbsoluteLength.Pixels(switch size {
            case XSmall | Small: theme.radius / 2.;
            case _: theme.radius;
        });

        final element = div()
            .flex()
            .itemsCenter()
            .border1()
            .lineHeight(glaze.Prelude.relative(1.25));
        switch size {
            case XSmall | Small: element.textSize(rems(0.625));
            case Large: element.textSm();
            case _: element.textXs();
        }
        switch size {
            case XSmall | Small: element.px1p5().py0p5();
            case _: element.px2p5().py1();
        }
        element
            .bg(bg)
            .textColor(fg)
            .borderColor(border)
            .rounded(rounded)
            .hover(s -> s.opacity(0.9))
            .refineStyle(tagStyle);
        element.extend(childElements);
        return element;
    }

}
