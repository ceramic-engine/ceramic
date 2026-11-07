// Ported from gpui-kit 0.8.1: crates/component/src/dialog/content.rs
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

import gpui.base.Prelude.*;

using gpui.base.StyledExt;

/**
 * Content container for a dialog.
 */
class DialogContent implements RenderOnce implements Styled implements ParentElement {

    final contentStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return contentStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):DialogContent {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):DialogContent {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(_:Window, cx:App):IntoElement {
        final element = vFlex()
            .wFull()
            .flex1()
            .rounded(Theme.global(cx).radiusLg)
            .refineStyle(contentStyle);
        element.extend(childElements);
        return element;
    }

}
