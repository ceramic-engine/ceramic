// Ported from gpui-kit 0.8.1: crates/base/src/button.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.AnyElement;
import gpui.App;
import gpui.ClickEvent;
import gpui.Div;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.MouseButton;
import gpui.MouseDownEvent;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleBuilder;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.ComponentTraits.Selectable;

import gpui.Prelude.*;

using gpui.base.A11y.RoleOverrideTools;
using gpui.base.StyledExt;

/**
 * An unstyled button that owns interaction, focus, keyboard, and accessibility behavior.
 *
 * Layout and visual states are intentionally supplied by the application through
 * GPUI's `Styled` API.
 *
 * Interactive styles and listeners (`hover`, `active`, `focusVisible`,
 * `onMouseDown`, `onHover`...) go to `base`, the stateful `Div` the button
 * renders (Rust implements `InteractiveElement` by delegation). `onClick`
 * is the button's own activation handler, like the inherent Rust method.
 */
class Button implements RenderOnce implements Styled implements ParentElement implements Selectable {

    final id:ElementId;

    /** The stateful element the button renders. */
    public final base:Div;

    final buttonStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:ButtonStyles = new ButtonStyles();

    var selectedValue:Bool = false;

    var disabledValue:Bool = false;

    final childElements:Array<AnyElement> = [];

    var onClickHandler:Null<(ClickEvent, Window, App) -> Void> = null;

    var accessibilityLabelValue:Null<String> = null;

    var roleValue:RoleOverride = Implicit;

    var providedFocusHandle:Null<FocusHandle> = null;

    var tabIndexValue:Int = 0;

    var tabStopValue:Bool = true;

    var focusableValue:Bool = true;

    /**
     * The accessibility properties the button exports (filled by `render`,
     * or set by a styled owner such as `toggled`).
     */
    public final a11y:A11y = new A11y();

    public function new(id:ElementIdArg) {
        this.id = id;
        this.base = div().id(id);
    }

    public inline function style():StyleRefinement {
        return buttonStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Button {
        childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Button {
        for (child in children) childElements.push(child);
        return this;
    }

    /**
     * Sets whether the button ignores pointer and keyboard activation.
     *
     * Disabled buttons are skipped during Tab traversal. If this button already
     * owns focus when it becomes disabled, it retains the focus binding until
     * focus moves away, so keyboard traversal can continue in either direction.
     */
    public function disabled(disabled:Bool):Button {
        disabledValue = disabled;
        return this;
    }

    /**
     * Sets the application-controlled selected presentation state.
     *
     * This supports persistent trigger presentation while an associated menu
     * or popover is open. It is distinct from momentary `active`, Toggle's
     * `pressed` state, and accessibility toggle metadata; selecting a Button
     * does not automatically set `aria_toggled`.
     */
    public function selected(selected:Bool):Button {
        selectedValue = selected;
        return this;
    }

    public function setSelected(selected:Bool):Void {
        selectedValue = selected;
    }

    public function isSelected():Bool {
        return selectedValue;
    }

    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    public function isOpen():Bool {
        return isSelected();
    }

    /**
     * Defines application-owned styles for the button's semantic states.
     */
    public function styles(build:(ButtonStyles) -> ButtonStyles):Button {
        semanticStyles = build(semanticStyles);
        return this;
    }

    /**
     * Sets the label exposed to accessibility clients.
     */
    public function accessibilityLabel(label:String):Button {
        accessibilityLabelValue = label;
        return this;
    }

    /**
     * Overrides the accessibility role. The default is `Role.Button`.
     */
    public function role(role:RoleOverride):Button {
        roleValue = role;
        return this;
    }

    /**
     * Uses a caller-owned focus handle instead of creating keyed state.
     */
    public function trackFocus(focusHandle:FocusHandle):Button {
        providedFocusHandle = focusHandle;
        return this;
    }

    /**
     * Sets the activation handler for pointer, Enter, and Space input.
     */
    public function onClick(handler:(ClickEvent, Window, App) -> Void):Button {
        onClickHandler = handler;
        return this;
    }

    /**
     * Sets the focus traversal index. The default is `0`.
     */
    public function tabIndex(tabIndex:Int):Button {
        tabIndexValue = tabIndex;
        return this;
    }

    /**
     * Sets whether the button participates in keyboard focus traversal.
     */
    public function tabStop(tabStop:Bool):Button {
        tabStopValue = tabStop;
        return this;
    }

    /**
     * Sets whether pressing the button moves focus onto it. The default is `true`.
     *
     * A non-focusable button leaves focus wherever it already is, which keeps a
     * composed control from flickering its focus ring on every press. It also
     * gives up Enter and Space activation, so only use it for a button that a
     * focused sibling already exposes to the keyboard, such as a number input's
     * step buttons.
     */
    public function focusable(focusable:Bool):Button {
        focusableValue = focusable;
        return this;
    }

    /** Interactive style while hovered (on `base`). */
    public function hover(f:(StyleBuilder) -> StyleBuilder):Button {
        base.hover(f);
        return this;
    }

    /** Interactive style while pressed (on `base`). */
    public function active(f:(StyleBuilder) -> StyleBuilder):Button {
        base.active(f);
        return this;
    }

    /** Interactive style while the group is hovered (on `base`). */
    public function groupHover(groupName:String, f:(StyleBuilder) -> StyleBuilder):Button {
        base.groupHover(groupName, f);
        return this;
    }

    /** Interactive style while focused by the keyboard (on `base`). */
    public function focusVisible(f:(StyleBuilder) -> StyleBuilder):Button {
        base.focusVisible(f);
        return this;
    }

    /** A mouse down listener (on `base`). */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):Button {
        base.onMouseDown(button, listener);
        return this;
    }

    /** A hover listener (on `base`). */
    public function onHover(listener:(Bool, Window, App) -> Void):Button {
        base.onHover(listener);
        return this;
    }

    function focusHandle(window:Window, cx:App):FocusHandle {
        if (providedFocusHandle != null) return providedFocusHandle;
        return window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
    }

    @:allow(tests)
    function resolvedStyle():StyleRefinement {
        final states = [];
        if (selectedValue) states.push(semanticStyles.selectedStyle);
        if (disabledValue) states.push(semanticStyles.disabledStyle);
        return StateStyle.resolveStyle(buttonStyle, states);
    }

    public function render(window:Window, cx:App):IntoElement {
        final focusHandle = this.focusHandle(window, cx);
        final disabled = disabledValue;
        final style = resolvedStyle();
        final onClick = onClickHandler;

        // Centering is part of Button's control geometry. Without a flex
        // formatting context an ordinary child starts at the root's leading
        // edge, so a fixed-height unstyled Button cannot align its label even
        // though its neutral line height is correct.
        //
        // A neutral line height is geometry, not visual policy: with the
        // inherited value the text box is taller than the glyphs, so the
        // caller's padding no longer determines the control's height and a
        // button cannot be sized precisely. `relative(1.)` makes the text box
        // exactly the font size; anything the caller sets refines over it.
        final element = base.flex().itemsCenter().justifyCenter().lineHeight(gpui.Prelude.relative(1.));
        final role = roleValue.resolve(() -> Role.Button);
        if (role != null) a11y.role = role;
        if (accessibilityLabelValue != null) a11y.label = accessibilityLabelValue;
        // Keep the current focus in the dispatch tree when activation
        // disables this button, so Tab can still leave it in either direction.
        if (focusableValue && (!disabled || focusHandle.isFocused(window))) {
            element.trackFocus(focusHandle.tabIndex(tabIndexValue).tabStop(tabStopValue && !disabled));
        }
        if (disabled) {
            element.onMouseDown(Left, (_, _, cx) -> cx.stopPropagation());
        }
        if (!disabled && onClick != null) {
            a11y.clickable = true;
            element.onClick((event, window, cx) -> onClick(event, window, cx));
        }
        element.extend(childElements);
        a11y.disabled = disabled;
        return element.refineStyle(style);
    }

}

/**
 * Semantic styles supported by `Button`.
 */
class ButtonStyles {

    @:allow(gpui.base)
    final selectedStyle:StyleRefinement = new StyleRefinement();

    @:allow(gpui.base)
    final disabledStyle:StyleRefinement = new StyleRefinement();

    public function new() {}

    /**
     * Refines the root style when the button is selected.
     */
    public function selected(build:(StateStyle) -> StateStyle):ButtonStyles {
        selectedStyle.refine(build(new StateStyle()).intoRefinement());
        return this;
    }

    /**
     * Refines the root style when the button is disabled.
     */
    public function disabled(build:(StateStyle) -> StateStyle):ButtonStyles {
        disabledStyle.refine(build(new StateStyle()).intoRefinement());
        return this;
    }

}
