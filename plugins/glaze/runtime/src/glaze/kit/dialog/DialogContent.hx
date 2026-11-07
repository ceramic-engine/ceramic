// Ported from gpui-kit 0.8.1: crates/component/src/dialog/content.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.dialog;

import glaze.AnyElement;
import glaze.App;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.theme.Theme;

import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;

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
