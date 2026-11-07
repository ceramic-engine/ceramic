// Ported from gpui-kit 0.8.1: crates/base/src/checkbox.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.Div;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;

import glaze.Prelude.*;

using glaze.kit.base.A11y.RoleOverrideTools;
using glaze.kit.base.StyledExt;

/**
 * The semantic value exposed by an unstyled `Checkbox` (default `Unchecked`).
 */
enum abstract CheckboxState(Int) {

    var Unchecked;
    var Checked;
    var Indeterminate;

    @:allow(glaze.kit.base)
    function toggled():Toggled {
        return switch (cast this:CheckboxState) {
            case Unchecked: Toggled.False;
            case Checked: Toggled.True;
            case Indeterminate: Toggled.Mixed;
        }
    }

    @:allow(glaze.kit.base)
    function activated():CheckboxState {
        return switch (cast this:CheckboxState) {
            case Unchecked | Indeterminate: Checked;
            case Checked: Unchecked;
        }
    }

}

/**
 * An unstyled checkbox that owns toggle, focus, keyboard, and accessibility behavior.
 *
 * The application owns all layout and visual state rendering. Child elements can
 * present the check mark, indeterminate mark, label, or any other design-system UI.
 *
 * Interactive styles and listeners go to `base` (see `glaze.kit.base.Button`).
 */
class Checkbox implements RenderOnce implements Styled implements ParentElement {

    final id:ElementId;

    /** The stateful element the checkbox renders. */
    public final base:Div;

    final checkboxStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:CheckboxStyles = new CheckboxStyles();

    var stateValue:CheckboxState = Unchecked;

    var disabledValue:Bool = false;

    final childElements:Array<AnyElement> = [];

    var onChangeHandler:Null<(CheckboxState, ClickEvent, Window, App) -> Void> = null;

    var accessibilityLabelValue:Null<String> = null;

    var tabIndexValue:Int = 0;

    var tabStopValue:Bool = true;

    var providedFocusHandle:Null<FocusHandle> = null;

    var roleValue:RoleOverride = Implicit;

    /** The accessibility properties the checkbox exports (filled by `render`). */
    public final a11y:A11y = new A11y();

    /**
     * Creates an unchecked checkbox with a stable element identifier.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
        this.base = div().id(id);
    }

    public inline function style():StyleRefinement {
        return checkboxStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Checkbox {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Checkbox {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function role(role:RoleOverride):Checkbox {
        roleValue = role;
        return this;
    }

    /**
     * Sets the controlled semantic state.
     */
    public function state(state:CheckboxState):Checkbox {
        stateValue = state;
        return this;
    }

    /**
     * Sets the checked state, clearing any indeterminate state.
     */
    public function checked(checked:Bool):Checkbox {
        return state(checked ? Checked : Unchecked);
    }

    /**
     * Sets or clears the indeterminate state.
     *
     * Clearing indeterminate leaves the checkbox unchecked. Applications with a
     * controlled value can call `state` when another fallback is desired.
     */
    public function indeterminate(indeterminate:Bool):Checkbox {
        if (indeterminate) {
            return state(Indeterminate);
        } else if (stateValue == Indeterminate) {
            return state(Unchecked);
        } else {
            return this;
        }
    }

    /**
     * Sets whether pointer and keyboard activation are ignored.
     */
    public function disabled(disabled:Bool):Checkbox {
        disabledValue = disabled;
        return this;
    }

    /**
     * Defines application-owned styles for the checkbox's semantic states.
     */
    public function styles(build:(CheckboxStyles) -> CheckboxStyles):Checkbox {
        semanticStyles = build(semanticStyles);
        return this;
    }

    /**
     * Sets the label exposed to accessibility clients.
     *
     * A checkbox without text children has no accessible name, so set this
     * whenever it is drawn without visible text.
     */
    public function accessibilityLabel(label:String):Checkbox {
        accessibilityLabelValue = label;
        return this;
    }

    /**
     * Handles an activation with the next controlled state.
     *
     * An indeterminate checkbox becomes checked when activated. The activating
     * `ClickEvent` is reported so callers can read its modifiers, for example
     * to extend a selection.
     */
    public function onChange(handler:(CheckboxState, ClickEvent, Window, App) -> Void):Checkbox {
        onChangeHandler = handler;
        return this;
    }

    /**
     * Sets the focus traversal index. The default is `0`.
     */
    public function tabIndex(tabIndex:Int):Checkbox {
        tabIndexValue = tabIndex;
        return this;
    }

    /**
     * Sets whether this checkbox participates in keyboard focus traversal.
     */
    public function tabStop(tabStop:Bool):Checkbox {
        tabStopValue = tabStop;
        return this;
    }

    /**
     * Uses a caller-owned focus handle instead of creating keyed state.
     */
    public function trackFocus(focusHandle:FocusHandle):Checkbox {
        providedFocusHandle = focusHandle;
        return this;
    }

    /** Interactive style while hovered (on `base`). */
    public function hover(f:(StyleBuilder) -> StyleBuilder):Checkbox {
        base.hover(f);
        return this;
    }

    /** Interactive style while pressed (on `base`). */
    public function active(f:(StyleBuilder) -> StyleBuilder):Checkbox {
        base.active(f);
        return this;
    }

    /** Interactive style while focused by the keyboard (on `base`). */
    public function focusVisible(f:(StyleBuilder) -> StyleBuilder):Checkbox {
        base.focusVisible(f);
        return this;
    }

    /** A mouse down listener (on `base`). */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):Checkbox {
        base.onMouseDown(button, listener);
        return this;
    }

    function focusHandle(window:Window, cx:App):FocusHandle {
        if (providedFocusHandle != null) return providedFocusHandle;
        return window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
    }

    @:allow(tests)
    function resolvedStyle():StyleRefinement {
        final states = [];
        switch stateValue {
            case Unchecked:
            case Checked: states.push(semanticStyles.checkedStyle);
            case Indeterminate: states.push(semanticStyles.indeterminateStyle);
        }
        if (disabledValue) states.push(semanticStyles.disabledStyle);
        return StateStyle.resolveStyle(checkboxStyle, states);
    }

    public function render(window:Window, cx:App):IntoElement {
        final focusHandle = this.focusHandle(window, cx);
        final disabled = disabledValue;
        final nextState = stateValue.activated();
        final style = resolvedStyle();
        final onChange = onChangeHandler;

        final element = base;
        final role = roleValue.resolve(() -> Role.CheckBox);
        if (role != null) a11y.role = role;
        a11y.toggled = stateValue.toggled();
        if (accessibilityLabelValue != null) a11y.label = accessibilityLabelValue;
        if (!disabled) {
            element.trackFocus(focusHandle.tabIndex(tabIndexValue).tabStop(tabStopValue));
        }
        if (!disabled && onChange != null) {
            a11y.clickable = true;
            element.onClick((event, window, cx) -> onChange(nextState, event, window, cx));
        }
        element.extend(childElements);
        a11y.disabled = disabled;
        return element.refineStyle(style);
    }

}

/**
 * Semantic styles supported by `Checkbox`.
 */
class CheckboxStyles {

    @:allow(glaze.kit.base)
    final checkedStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit.base)
    final indeterminateStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit.base)
    final disabledStyle:StyleRefinement = new StyleRefinement();

    public function new() {}

    /**
     * Refines the root style when the checkbox is checked.
     */
    public function checked(build:(StateStyle) -> StateStyle):CheckboxStyles {
        checkedStyle.refine(build(new StateStyle()).intoRefinement());
        return this;
    }

    /**
     * Refines the root style when the checkbox is indeterminate.
     */
    public function indeterminate(build:(StateStyle) -> StateStyle):CheckboxStyles {
        indeterminateStyle.refine(build(new StateStyle()).intoRefinement());
        return this;
    }

    /**
     * Refines the root style when the checkbox is disabled.
     */
    public function disabled(build:(StateStyle) -> StateStyle):CheckboxStyles {
        disabledStyle.refine(build(new StateStyle()).intoRefinement());
        return this;
    }

}

/**
 * An unstyled checkbox indicator part with typed checkbox-state projection.
 *
 * This renders its `Div` directly. Applications own its geometry, visual
 * presentation, and children.
 */
class CheckboxIndicator implements RenderOnce implements Styled implements ParentElement {

    final indicatorStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:CheckboxStyles = new CheckboxStyles();

    var stateValue:CheckboxState = Unchecked;

    var disabledValue:Bool = false;

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return indicatorStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):CheckboxIndicator {
        if (child != null) childElements.push(child);
        return this;
    }

    public function state(state:CheckboxState):CheckboxIndicator {
        stateValue = state;
        return this;
    }

    public function checked(checked:Bool):CheckboxIndicator {
        return state(checked ? Checked : Unchecked);
    }

    public function disabled(disabled:Bool):CheckboxIndicator {
        disabledValue = disabled;
        return this;
    }

    /**
     * Semantic styles of the indicator (Rust `CheckboxIndicatorStyles`, the
     * same three states as `CheckboxStyles`).
     */
    public function styles(build:(CheckboxStyles) -> CheckboxStyles):CheckboxIndicator {
        semanticStyles = build(semanticStyles);
        return this;
    }

    @:allow(tests)
    function resolvedStyle():StyleRefinement {
        final states = [];
        switch stateValue {
            case Unchecked:
            case Checked: states.push(semanticStyles.checkedStyle);
            case Indeterminate: states.push(semanticStyles.indeterminateStyle);
        }
        if (disabledValue) states.push(semanticStyles.disabledStyle);
        return StateStyle.resolveStyle(indicatorStyle, states);
    }

    public function render(window:Window, cx:App):IntoElement {
        final style = resolvedStyle();
        final element = div();
        element.extend(childElements);
        return element.refineStyle(style);
    }

}

/**
 * Semantic styles supported by `CheckboxIndicator` (the same states as
 * `CheckboxStyles`).
 */
typedef CheckboxIndicatorStyles = CheckboxStyles;
