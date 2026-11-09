// Ported from gpui-kit 0.8.1: crates/component/src/toolbar.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.toolbar;

import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.StyleSized;

/**
 * An item of a toolbar: a sized control (it takes the toolbar's size when
 * rendered), or plain content.
 */
enum ToolbarItem {
    /** A sized control (the same object, as `Sizable` and as `RenderOnce`). */
    Sized(sizable:Sizable, item:RenderOnce);
    Content(content:AnyElement);
}

class ToolbarItemTools {

    /**
     * A sized control gets the toolbar presentation (Rust
     * `Sizable::prepare_for_toolbar`, which only `Button` overrides: a
     * compact ghost button) and the toolbar's size, in a row as tall as an
     * input of that size.
     */
    public static function intoElement(item:ToolbarItem, size:Size):AnyElement {
        return switch item {
            case Sized(sizable, item):
                if (Std.isOfType(sizable, glaze.kit.button.Button)) {
                    (cast sizable:glaze.kit.button.Button).prepareForToolbar();
                }
                sizable.setSize(size);
                div().flex().itemsCenter().inputH(size).child(item).intoAnyElement();
            case Content(content): content;
        }
    }

}

/**
 * A semantic subgroup of toolbar controls that shares one accessible label
 * and propagates its size to every control added with `child` or `children`.
 */
class ToolbarGroup extends Component implements Styled implements ParentElement implements Sizable {

    final id:ElementId;

    final groupStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var sizeValue:Size = Small;

    /**
     * Sets the accessible name announced for the group.
     */
    @prop var label:Null<String> = null;

    final items:Array<ToolbarItem> = [];

    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return groupStyle;
    }

    /**
     * Generic `ParentElement` extension treats elements as non-sized content.
     */
    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) items.push(Content(element));
    }

    /**
     * Append a control that inherits the group's final size.
     */
    public function child<T:Sizable & RenderOnce>(child:T):ToolbarGroup {
        if (child != null) items.push(Sized(child, child));
        return this;
    }

    /**
     * Append controls that inherit the group's final size.
     */
    public function children<T:Sizable & RenderOnce>(children:Array<T>):ToolbarGroup {
        for (child in children) if (child != null) items.push(Sized(child, child));
        return this;
    }

    /**
     * Append non-sized content to the group.
     */
    public function content(content:IntoElement):ToolbarGroup {
        if (content != null) items.push(Content(content));
        return this;
    }

    public function withSize(size:IntoSize):ToolbarGroup {
        this.sizeValue = switch (size:Size) {
            case Large: Medium;
            case other: other;
        }
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final size = sizeValue;
        final group = new glaze.kit.base.Toolbar.ToolbarGroup(id);
        if (label != null) group.label(label);
        group.extend([for (item in items) ToolbarItemTools.intoElement(item, size)]);
        return group.refineStyle(groupStyle);
    }

}

/**
 * A transparent horizontal container for commands in a window, pane, or
 * section.
 *
 * The toolbar owns layout and keyboard behavior while the surrounding header,
 * tab strip, or custom surface owns its background and border.
 *
 * The bar exposes `Toolbar` semantics to assistive technology and owns
 * roving keyboard focus: when focus is on one of its controls, the arrow
 * keys move focus along the bar, wrapping around at the ends. Hosted inputs
 * keep their own arrow-key caret behavior; place them at the trailing end of
 * the bar.
 *
 * `child` accepts `Sizable` controls and automatically applies the toolbar's
 * final size, regardless of builder order. Use `content` for separators,
 * labels, flexible spacers, and custom layout. Items render in source order.
 * An icon-only button must carry a tooltip and an accessible name.
 *
 * The id keeps the toolbar's keyboard-focus state stable across frames; give
 * each toolbar in a window a distinct id.
 */
class Toolbar extends Component implements Styled implements ParentElement implements Sizable {

    final id:ElementId;

    final toolbarStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var sizeValue:Size = Small;

    /**
     * Disable the toolbar's roving keyboard navigation.
     * Hosted controls must be disabled by their owner.
     */
    @:allow(tests)
    @prop var disabled:Bool = false;

    @:allow(tests)
    final items:Array<ToolbarItem> = [];

    /**
     * Create a new, empty `Toolbar` at `Size.Small`.
     */
    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return toolbarStyle;
    }

    /**
     * Generic `ParentElement` extension treats elements as non-sized content.
     * Prefer `child` / `children` for controls that should inherit the
     * toolbar size.
     */
    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) items.push(Content(element));
    }

    /**
     * Append a sized control. The toolbar applies its final size when it
     * renders, so builder call order does not matter.
     */
    public function child<T:Sizable & RenderOnce>(child:T):Toolbar {
        if (child != null) items.push(Sized(child, child));
        return this;
    }

    /**
     * Append sized controls.
     */
    public function children<T:Sizable & RenderOnce>(children:Array<T>):Toolbar {
        for (child in children) if (child != null) items.push(Sized(child, child));
        return this;
    }

    /**
     * Append non-sized content.
     */
    public function content(content:IntoElement):Toolbar {
        if (content != null) items.push(Content(content));
        return this;
    }

    /**
     * Append non-sized content.
     */
    public function contents(contents:Array<AnyElement>):Toolbar {
        for (content in contents) items.push(Content(content));
        return this;
    }

    public function withSize(size:IntoSize):Toolbar {
        this.sizeValue = switch (size:Size) {
            case Large: Medium;
            case other: other;
        }
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final size = sizeValue;
        final toolbar = glaze.kit.base.Toolbar.component(id).disabled(disabled);
        toolbar.flex().itemsCenter().flexShrink0();
        switch size {
            case XSmall: toolbar.minH7().p1().gap1().textXs();
            case Small: toolbar.minH8().p1().gap1().textSm();
            case _: toolbar.minH12().p2().gap2().textSm();
        }
        toolbar.refineStyle(toolbarStyle);
        toolbar.extend([for (item in items) ToolbarItemTools.intoElement(item, size)]);
        return toolbar;
    }

}
