// Ported from gpui-kit 0.8.1: crates/component/src/dialog/description.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.dialog;

import gpui.AnyElement;
import gpui.App;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.component.theme.Theme;

using gpui.base.StyledExt;

/**
 * Description element for a dialog header.
 *
 * Typically used inside a DialogHeader component to provide additional context.
 */
class DialogDescription implements RenderOnce implements Styled implements ParentElement {

    final base:gpui.base.Dialog.DialogDescription = new gpui.base.Dialog.DialogDescription();

    final descriptionStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return descriptionStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):DialogDescription {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(_:Window, cx:App):IntoElement {
        base.textSm()
            .textColor(Theme.global(cx).mutedForeground)
            .refineStyle(descriptionStyle);
        base.extend(childElements);
        return base;
    }

}
