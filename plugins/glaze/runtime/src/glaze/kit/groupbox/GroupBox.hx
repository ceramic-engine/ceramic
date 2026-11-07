// Ported from gpui-kit 0.8.1: crates/component/src/group_box.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.groupbox;

import glaze.AnyElement;
import glaze.App;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * The look of a `GroupBox`: no surface, a filled surface or an outlined one.
 */
enum abstract GroupBoxVariant(Int) {

    var Normal;
    var Fill;
    var Outline;

    public static function fromStr(s:String):GroupBoxVariant {
        return switch s.toLowerCase() {
            case 'fill': Fill;
            case 'outline': Outline;
            case _: Normal;
        }
    }

    public function asStr():String {
        return switch (cast this : GroupBoxVariant) {
            case Normal: 'normal';
            case Fill: 'fill';
            case Outline: 'outline';
        }
    }

}

/**
 * A titled group of content, with an optional footer.
 */
class GroupBox implements RenderOnce implements Styled implements ParentElement {

    var idValue:Null<ElementId> = null;

    var variant:GroupBoxVariant = Normal;

    final groupStyle:StyleRefinement = new StyleRefinement();

    var titleStyleValue:StyleRefinement = new StyleRefinement();

    var titleValue:Null<AnyElement> = null;

    var contentStyleValue:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    var footerValue:Null<AnyElement> = null;

    public function new() {}

    public function id(id:ElementIdArg):GroupBox {
        idValue = id;
        return this;
    }

    public function title(title:IntoElement):GroupBox {
        titleValue = title;
        return this;
    }

    public function titleStyle(style:StyleRefinement):GroupBox {
        titleStyleValue = style;
        return this;
    }

    public function contentStyle(style:StyleRefinement):GroupBox {
        contentStyleValue = style;
        return this;
    }

    public function footer(footer:IntoElement):GroupBox {
        footerValue = footer;
        return this;
    }

    public function withVariant(variant:GroupBoxVariant):GroupBox {
        this.variant = variant;
        return this;
    }

    public function normal():GroupBox return withVariant(Normal);

    public function fill():GroupBox return withVariant(Fill);

    public function outline():GroupBox return withVariant(Outline);

    public inline function style():StyleRefinement {
        return groupStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):GroupBox {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final hasPaddings = variant != Normal;

        final element = glaze.kit.base.Prelude.vFlex()
            .id(idValue != null ? idValue : ElementId.Name('group-box'))
            .wFull();
        if (hasPaddings) element.gap3() else element.gap4();
        element.refineStyle(groupStyle);
        if (titleValue != null) {
            element.child(
                div()
                    .textColor(theme.mutedForeground)
                    .lineHeight(glaze.Prelude.relative(1.25))
                    .refineStyle(titleStyleValue)
                    .child(titleValue)
            );
        }
        final surface = glaze.kit.base.Prelude.vFlex();
        if (variant == Fill) surface.bg(theme.tokens.groupBox.background);
        if (variant == Outline) surface.borderColor(theme.border).border1();
        surface.textColor(theme.groupBoxForeground);
        if (hasPaddings) surface.p4();
        surface.gap4().rounded(theme.radius).refineStyle(contentStyleValue);
        surface.extend(childElements);
        // The footer sits inside the surface's slot so its 8 px gap is
        // independent of the root gap between the title and surface.
        final slot = glaze.kit.base.Prelude.vFlex().gap2().child(surface);
        if (footerValue != null) {
            slot.child(div().textSm().textColor(theme.mutedForeground).child(footerValue));
        }
        element.child(slot);
        return element;
    }

}
