// Ported from gpui-kit 0.8.1: crates/component/src/input/token.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.input;

import gpui.App;
import gpui.IntoElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.input.InlineTokenContext;
import gpui.component.Icon;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * The element an `InlineToken` renders as by default. Editing and
 * activation belong to the input.
 */
class InputToken implements RenderOnce implements Styled {

    final context:InlineTokenContext;

    var iconValue:Null<Icon> = null;

    final tokenStyle:StyleRefinement = new StyleRefinement();

    public function new(context:InlineTokenContext) {
        this.context = context;
    }

    public function icon(icon:IntoIcon):InputToken {
        iconValue = icon;
        return this;
    }

    public inline function style():StyleRefinement {
        return tokenStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final element = div()
            .id("input-token")
            .flex()
            .itemsCenter()
            .gap1()
            .px1()
            .h(context.lineHeight())
            .maxW(context.availableWidth())
            .rounded(theme.radius)
            .border1();
        // The selection color is translucent as a fill; its opaque form
        // is the matching border.
        if (context.isSelected()) {
            element.bg(theme.selection).borderColor(theme.selection.alpha(1.));
        } else {
            element.bg(theme.muted).borderColor(theme.border);
        }
        element.textColor(theme.foreground);
        if (context.isDisabled()) element.opacity(0.5);
        if (iconValue != null) element.child(iconValue.size3().flexShrink0());
        element.child(div().minW0().textEllipsis().child(context.token().label()));
        return element.refineStyle(tokenStyle);
    }

}
