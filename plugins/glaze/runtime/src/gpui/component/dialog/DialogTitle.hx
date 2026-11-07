// Ported from gpui-kit 0.8.1: crates/component/src/dialog/title.rs
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

using gpui.base.StyledExt;

/**
 * Title element for a dialog header.
 */
class DialogTitle implements RenderOnce implements Styled implements ParentElement {

    final base:gpui.base.Dialog.DialogTitle = new gpui.base.Dialog.DialogTitle();

    final titleStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return titleStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):DialogTitle {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(_:Window, _:App):IntoElement {
        base.textBase()
            .fontSemibold()
            .lineHeight(gpui.Prelude.relative(1.25))
            .refineStyle(titleStyle);
        base.extend(childElements);
        return base;
    }

}
