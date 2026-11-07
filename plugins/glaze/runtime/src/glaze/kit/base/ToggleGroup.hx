// Ported from gpui-kit 0.8.1: crates/base/src/toggle_group.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.Axis;
import glaze.ClickEvent;
import glaze.Div;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * An unstyled container for a set of toggle elements.
 *
 * Listeners go to `base`, the stateful `Div` the group renders (Rust
 * implements `InteractiveElement` by delegation).
 */
class ToggleGroup implements RenderOnce implements Styled implements ParentElement {

    /** The stateful element the group renders. */
    public final base:Div;

    final groupStyle:StyleRefinement = new StyleRefinement();

    var axisValue:Axis = Axis.Horizontal;

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the group exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.Toolbar);

    public function new(id:ElementIdArg) {
        base = div().id(id);
    }

    public inline function style():StyleRefinement {
        return groupStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):ToggleGroup {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):ToggleGroup {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    /**
     * Sets the semantic axis of the group.
     */
    public function axis(axis:Axis):ToggleGroup {
        axisValue = axis;
        return this;
    }

    /** A click listener on the group element (on `base`). */
    public function onClick(listener:(ClickEvent, Window, App) -> Void):ToggleGroup {
        base.onClick(listener);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        a11y.orientation = axisValue == Axis.Horizontal ? Orientation.Horizontal : Orientation.Vertical;
        base.extend(childElements);
        return base.refineStyle(groupStyle);
    }

}
