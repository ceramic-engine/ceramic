// Ported from gpui-kit 0.8.1: crates/component/src/collapsible.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.collapsible;

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
import glaze.kit.base.motion.Motion;
import glaze.kit.base.motion.TransitionId;
import glaze.kit.theme.Theme;

using glaze.kit.base.StyledExt;

/**
 * An interactive element which expands/collapses.
 */
class Collapsible implements RenderOnce implements Styled implements ParentElement {

    final base:glaze.kit.base.BaseCollapsible = glaze.kit.base.BaseCollapsible.component();

    final collapsibleStyle:StyleRefinement = new StyleRefinement();

    var motionIdValue:Null<ElementId> = null;

    var openValue:Bool = false;

    /**
     * Creates a new `Collapsible` instance.
     */
    public function new() {}

    /**
     * Sets whether the collapsible is open. default is false.
     */
    public function open(open:Bool):Collapsible {
        openValue = open;
        base.open(open);
        return this;
    }

    /**
     * Enables a reversible measured reveal under a stable identity.
     */
    public function motionId(id:ElementIdArg):Collapsible {
        motionIdValue = id;
        return this;
    }

    /**
     * Sets the content of the collapsible.
     *
     * If `open` is false, content will be hidden.
     */
    public function content(content:IntoElement):Collapsible {
        base.content(content);
        return this;
    }

    public inline function style():StyleRefinement {
        return collapsibleStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        base.extend(elements);
    }

    public function child(child:IntoElement):Collapsible {
        if (child != null) base.child(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Collapsible {
        for (child in children) if (child != null) base.child(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final id = motionIdValue;
        if (id != null) {
            final progress = Motion.spring(
                TransitionId.named(id, 'reveal'),
                openValue ? 1.0 : 0.0,
                Theme.global(cx).motionTokens().springControl,
                window,
                cx
            );
            base.reveal(id, progress);
        }
        return base.vFlex().refineStyle(collapsibleStyle);
    }

}
