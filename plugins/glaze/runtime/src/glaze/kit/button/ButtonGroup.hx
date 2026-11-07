// Ported from gpui-kit 0.8.1: crates/component/src/button/button_group.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.button;

import glaze.App;
import glaze.Axis;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.button.Button;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A ButtonGroup element, to wrap multiple buttons in a group.
 */
class ButtonGroup implements RenderOnce implements Styled implements Sizable implements Disableable {

    final id:ElementId;

    final groupStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit, tests)
    final childButtons:Array<Button> = [];

    @:allow(glaze.kit, tests)
    var multipleValue:Bool = false;

    @:allow(glaze.kit, tests)
    var disabledValue:Bool = false;

    @:allow(glaze.kit, tests)
    var layoutValue:Axis = Axis.Horizontal;

    // The button props
    @:allow(glaze.kit, tests)
    var compactValue:Bool = false;

    @:allow(glaze.kit, tests)
    var outlineValue:Bool = false;

    @:allow(glaze.kit, tests)
    var variantValue:Null<ButtonVariant> = null;

    @:allow(glaze.kit, tests)
    var sizeValue:Null<Size> = null;

    @:allow(glaze.kit, tests)
    var onClickHandler:Null<(Array<Int>, Window, App) -> Void> = null;

    /**
     * Creates a new ButtonGroup.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return groupStyle;
    }

    public function disabled(disabled:Bool):ButtonGroup {
        disabledValue = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        disabledValue = disabled;
    }

    /**
     * Adds a button as a child to the ButtonGroup (it takes the group's
     * disabled state as set so far).
     */
    public function child(child:Button):ButtonGroup {
        if (child != null) childButtons.push(child.disabled(disabledValue));
        return this;
    }

    /**
     * Adds multiple buttons as children to the ButtonGroup.
     */
    public function children(children:Array<Button>):ButtonGroup {
        for (child in children) if (child != null) childButtons.push(child);
        return this;
    }

    /**
     * With the multiple selection mode, default is false (single selection).
     */
    public function multiple(multiple:Bool):ButtonGroup {
        multipleValue = multiple;
        return this;
    }

    /**
     * Set the layout of the button group. Default is `Axis.Horizontal`.
     */
    public function layout(layout:Axis):ButtonGroup {
        layoutValue = layout;
        return this;
    }

    /**
     * With the compact mode for the ButtonGroup (see `Button.compact`).
     */
    public function compact():ButtonGroup {
        compactValue = true;
        return this;
    }

    /**
     * With the outline mode for the ButtonGroup (see `Button.outline`).
     */
    public function outline():ButtonGroup {
        outlineValue = true;
        return this;
    }

    /**
     * Sets the onClick handler for the ButtonGroup.
     *
     * The handler first argument is the indices of the clicked buttons
     * (selected in `multiple` mode): `[0, 2, 3]` means the first, third and
     * fourth buttons. A group handler replaces the click handlers of its
     * buttons, and only pointer clicks reach it.
     */
    public function onClick(handler:(Array<Int>, Window, App) -> Void):ButtonGroup {
        onClickHandler = handler;
        return this;
    }

    public function withSize(size:IntoSize):ButtonGroup {
        sizeValue = size;
        return this;
    }

    public function withVariant(variant:ButtonVariant):ButtonGroup {
        variantValue = variant;
        return this;
    }

    public inline function primary():ButtonGroup return withVariant(Primary);

    public inline function secondary():ButtonGroup return withVariant(Secondary);

    public inline function danger():ButtonGroup return withVariant(Danger);

    public inline function warning():ButtonGroup return withVariant(Warning);

    public inline function success():ButtonGroup return withVariant(Success);

    public inline function info():ButtonGroup return withVariant(Info);

    public inline function ghost():ButtonGroup return withVariant(Ghost);

    public inline function link():ButtonGroup return withVariant(Link);

    public inline function text():ButtonGroup return withVariant(Text);

    public inline function custom(style:ButtonCustomVariant):ButtonGroup return withVariant(Custom(style));

    public function render(window:Window, cx:App):IntoElement {
        final childrenLen = childButtons.length;
        final selectedIxs:Array<Int> = [];
        final state:Array<Null<Int>> = [null];

        for (ix in 0...childButtons.length) {
            if (childButtons[ix].selectedValue) selectedIxs.push(ix);
        }

        final vertical = layoutValue == Axis.Vertical;

        final element = div().id(id).flex();
        if (vertical) element.flexCol().justifyCenter();
        if (!vertical) element.itemsCenter();
        element.refineStyle(groupStyle);

        for (childIndex in 0...childButtons.length) {
            // The group as a whole is a toggle control, so every child
            // advertises its pressed state.
            var child = childButtons[childIndex];
            child.toggled(child.selectedValue);
            if (childrenLen == 1) {
                // Single
            } else if (childIndex == 0) {
                // First
                child.withBorderCorners(true, vertical, false, !vertical).withBorderEdges(true, true, true, true);
            } else if (childIndex == childrenLen - 1) {
                // Last
                child.withBorderEdges(!vertical, true, true, vertical).withBorderCorners(false, !vertical, true, vertical);
            } else {
                // Middle
                child.withBorderCorners(false, false, false, false).withBorderEdges(!vertical, true, true, vertical);
            }
            if (sizeValue != null) child.withSize(sizeValue);
            if (variantValue != null) child.withVariant(variantValue);
            if (compactValue) child.compact();
            if (outlineValue) child.outline();
            if (onClickHandler != null) {
                final ix = childIndex;
                child.onClick((_, _, _) -> state[0] = ix);
            }
            element.child(child);
        }

        final onClick = onClickHandler;
        final multiple = multipleValue;
        if (onClick != null && !disabledValue) {
            element.onClick((_, window, cx) -> {
                final next = selectedIxs.copy();
                final ix = state[0];
                if (ix != null) {
                    if (multiple) {
                        final pos = next.indexOf(ix);
                        if (pos >= 0) {
                            next.splice(pos, 1);
                        } else {
                            next.push(ix);
                        }
                    } else {
                        next.resize(0);
                        next.push(ix);
                    }
                }
                onClick(next, window, cx);
            });
        }
        return element;
    }

}
