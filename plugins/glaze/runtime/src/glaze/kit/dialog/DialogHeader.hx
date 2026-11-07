// Ported from gpui-kit 0.8.1: crates/component/src/dialog/header.rs
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

import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * Header section of a dialog, typically contains DialogTitle and DialogDescription.
 */
class DialogHeader implements RenderOnce implements Styled implements ParentElement {

    final headerStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return headerStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):DialogHeader {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(_:Window, _:App):IntoElement {
        final element = vFlex()
            .gap2()
            .refineStyle(headerStyle);
        element.extend(childElements);
        return element;
    }

}
