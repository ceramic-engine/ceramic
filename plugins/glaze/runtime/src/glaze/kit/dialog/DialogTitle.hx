// Ported from gpui-kit 0.8.1: crates/component/src/dialog/title.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.dialog;

import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;

using glaze.kit.base.StyledExt;

/**
 * Title element for a dialog header.
 */
class DialogTitle extends Component implements Styled implements ParentElement {

    final base:glaze.kit.base.Dialog.DialogTitle = new glaze.kit.base.Dialog.DialogTitle();

    final titleStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {
        super();
    }

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
            .lineHeight(glaze.Prelude.relative(1.25))
            .refineStyle(titleStyle);
        base.extend(childElements);
        return base;
    }

}
