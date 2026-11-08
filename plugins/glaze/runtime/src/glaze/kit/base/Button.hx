// Ported from gpui-kit 0.8.1: crates/base/src/button.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.Component;
import glaze.Div;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.ParentElement;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.ComponentTraits.Selectable;

import glaze.Prelude.*;

using glaze.kit.base.A11y.RoleOverrideTools;
using glaze.kit.base.StyledExt;

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
class Button extends Component implements Styled implements ParentElement implements Selectable {

    final id:ElementId;

    /** The stateful element the button renders. */
    public final base:Div;

    final buttonStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:ButtonStyles = new ButtonStyles();

    /**
     * Sets the application-controlled selected presentation state.
     *
     * This supports persistent trigger presentation while an associated menu
     * or popover is open. It is distinct from momentary `active`, Toggle's
     * `pressed` state, and accessibility toggle metadata; selecting a Button
     * does not automatically set `aria_toggled`.
     */
    @prop var selected:Bool = false;

    /**
     * Sets whether the button ignores pointer and keyboard activation.
     *
     * Disabled buttons are skipped during Tab traversal. If this button already
     * owns focus when it becomes disabled, it retains the focus binding until
     * focus moves away, so keyboard traversal can continue in either direction.
     */
    @prop var disabled:Bool = false;

    final childElements:Array<AnyElement> = [];

    /**
     * Sets the activation handler for pointer, Enter, and Space input.
     */
    @prop var onClick:Null<(ClickEvent, Window, App) -> Void> = null;

    /**
     * Sets the label exposed to accessibility clients.
     */
    @prop var accessibilityLabel:Null<String> = null;

    /**
     * Overrides the accessibility role. The default is `Role.Button`.
     */
    @prop var role:RoleOverride = Implicit;

    /**
     * Uses a caller-owned focus handle instead of creating keyed state.
     */
    @prop var trackFocus:Null<FocusHandle> = null;

    /**
     * Sets the focus traversal index. The default is `0`.
     */
    @prop var tabIndex:Int = 0;

    /**
     * Sets whether the button participates in keyboard focus traversal.
     */
    @prop var tabStop:Bool = true;

    /**
     * Sets whether pressing the button moves focus onto it. The default is `true`.
     *
     * A non-focusable button leaves focus wherever it already is, which keeps a
     * composed control from flickering its focus ring on every press. It also
     * gives up Enter and Space activation, so only use it for a button that a
     * focused sibling already exposes to the keyboard, such as a number input's
     * step buttons.
     */
    @prop var focusable:Bool = true;

    /**
     * The accessibility properties the button exports (filled by `render`,
     * or set by a styled owner such as `toggled`).
     */
    public final a11y:A11y = new A11y();

    public function new(id:ElementIdArg) {
        super();
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
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Button {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function setSelected(selected:Bool):Void {
        this.selected = selected;
    }

    public function isSelected():Bool {
        return selected;
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
        if (trackFocus != null) return trackFocus;
        return window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
    }

    @:allow(tests)
    function resolvedStyle():StyleRefinement {
        final states = [];
        if (selected) states.push(semanticStyles.selectedStyle);
        if (disabled) states.push(semanticStyles.disabledStyle);
        return StateStyle.resolveStyle(buttonStyle, states);
    }

    public function render(window:Window, cx:App):IntoElement {
        final focusHandle = this.focusHandle(window, cx);
        final disabled = this.disabled;
        final style = resolvedStyle();
        final onClick = this.onClick;

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
        final element = base.flex().itemsCenter().justifyCenter().lineHeight(glaze.Prelude.relative(1.));
        final role = this.role.resolve(() -> Role.Button);
        if (role != null) a11y.role = role;
        if (accessibilityLabel != null) a11y.label = accessibilityLabel;
        // Keep the current focus in the dispatch tree when activation
        // disables this button, so Tab can still leave it in either direction.
        if (focusable && (!disabled || focusHandle.isFocused(window))) {
            element.trackFocus(focusHandle.tabIndex(tabIndex).tabStop(tabStop && !disabled));
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

    @:allow(glaze.kit.base)
    final selectedStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit.base)
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
