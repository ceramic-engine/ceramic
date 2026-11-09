// Ported from gpui-kit 0.8.1: crates/base/src/collapsible.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.Div;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.motion.MotionReveal;

import glaze.Prelude.*;

/**
 * A child of a `BaseCollapsible`: an element always shown, or the content shown
 * while open (Rust's private `Child`).
 */
private enum CollapsibleChild {
    Element(element:AnyElement);
    Content(content:AnyElement);
}

/**
 * An unstyled controlled region whose content can be expanded or collapsed.
 *
 * Rust `gpui_base::Collapsible`, renamed: `glaze.kit.base.Collapsible` is the
 * component trait of `ComponentTraits`.
 */
class BaseCollapsible extends Component implements Styled implements ParentElement {

    final base:Div = div();

    final childEntries:Array<CollapsibleChild> = [];

    @prop var open:Bool = false;

    var revealId:Null<ElementId> = null;

    var revealProgress:Float = 0.;

    public function new() {
        super();
    }

    public function content(content:IntoElement):BaseCollapsible {
        if (content != null) childEntries.push(Content(content));
        return this;
    }

    /**
     * Keeps content mounted and reveals it at normalized `progress`.
     */
    public function reveal(id:ElementIdArg, progress:Float):BaseCollapsible {
        revealId = id;
        revealProgress = progress;
        return this;
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childEntries.push(Element(element));
    }

    public function child(child:IntoElement):BaseCollapsible {
        if (child != null) childEntries.push(Element(child));
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final children:Array<AnyElement> = [];
        for (child in childEntries) {
            switch child {
                case Element(element):
                    children.push(element);
                case Content(content):
                    if (revealId != null) {
                        children.push(new MotionReveal(revealId, revealProgress, content).intoAnyElement());
                    } else if (open) {
                        children.push(content);
                    }
            }
        }
        base.extend(children);
        return base;
    }

}
