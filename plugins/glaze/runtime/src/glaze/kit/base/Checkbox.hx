// Ported from gpui-kit 0.8.1: crates/base/src/checkbox.rs
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
class Checkbox extends Component implements Styled implements ParentElement {

    final id:ElementId;

    /** The stateful element the checkbox renders. */
    public final base:Div;

    final checkboxStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:CheckboxStyles = new CheckboxStyles();

    /**
     * Sets the controlled semantic state.
     */
    @prop var state:CheckboxState = Unchecked;

    /**
     * Sets whether pointer and keyboard activation are ignored.
     */
    @prop var disabled:Bool = false;

    final childElements:Array<AnyElement> = [];

    var onChangeHandler:Null<(CheckboxState, ClickEvent, Window, App) -> Void> = null;

    /**
     * Sets the label exposed to accessibility clients.
     *
     * A checkbox without text children has no accessible name, so set this
     * whenever it is drawn without visible text.
     */
    @prop var accessibilityLabel:Null<String> = null;

    /**
     * Sets the focus traversal index. The default is `0`.
     */
    @prop var tabIndex:Int = 0;

    /**
     * Sets whether this checkbox participates in keyboard focus traversal.
     */
    @prop var tabStop:Bool = true;

    /**
     * Uses a caller-owned focus handle instead of creating keyed state.
     */
    @prop var trackFocus:Null<FocusHandle> = null;

    @prop var role:RoleOverride = Implicit;

    /** The accessibility properties the checkbox exports (filled by `render`). */
    public final a11y:A11y = new A11y();

    /**
     * Creates an unchecked checkbox with a stable element identifier.
     */
    public function new(id:ElementIdArg) {
        super();
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

    /**
     * Sets the checked state, clearing any indeterminate state.
     */
    public function checked(checked:Bool):Checkbox {
        this.state = checked ? Checked : Unchecked;
        return this;
    }

    /**
     * Sets or clears the indeterminate state.
     *
     * Clearing indeterminate leaves the checkbox unchecked. Applications with a
     * controlled value can call `state` when another fallback is desired.
     */
    public function indeterminate(indeterminate:Bool):Checkbox {
        if (indeterminate) {
            this.state = Indeterminate;
            return this;
        } else if (this.state == Indeterminate) {
            this.state = Unchecked;
            return this;
        } else {
            return this;
        }
    }

    /**
     * Defines application-owned styles for the checkbox's semantic states.
     */
    public function styles(build:(CheckboxStyles) -> CheckboxStyles):Checkbox {
        semanticStyles = build(semanticStyles);
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
        if (trackFocus != null) return trackFocus;
        return window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
    }

    @:allow(tests)
    function resolvedStyle():StyleRefinement {
        final states = [];
        switch state {
            case Unchecked:
            case Checked: states.push(semanticStyles.checkedStyle);
            case Indeterminate: states.push(semanticStyles.indeterminateStyle);
        }
        if (disabled) states.push(semanticStyles.disabledStyle);
        return StateStyle.resolveStyle(checkboxStyle, states);
    }

    public function render(window:Window, cx:App):IntoElement {
        final focusHandle = this.focusHandle(window, cx);
        final disabled = this.disabled;
        final nextState = state.activated();
        final style = resolvedStyle();
        final onChange = onChangeHandler;

        final element = base;
        final role = this.role.resolve(() -> Role.CheckBox);
        if (role != null) a11y.role = role;
        a11y.toggled = state.toggled();
        if (accessibilityLabel != null) a11y.label = accessibilityLabel;
        if (!disabled) {
            element.trackFocus(focusHandle.tabIndex(tabIndex).tabStop(tabStop));
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
class CheckboxIndicator extends Component implements Styled implements ParentElement {

    final indicatorStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:CheckboxStyles = new CheckboxStyles();

    @prop var state:CheckboxState = Unchecked;

    @prop var disabled:Bool = false;

    final childElements:Array<AnyElement> = [];

    public function new() {
        super();
    }

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

    public function checked(checked:Bool):CheckboxIndicator {
        this.state = checked ? Checked : Unchecked;
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
        switch state {
            case Unchecked:
            case Checked: states.push(semanticStyles.checkedStyle);
            case Indeterminate: states.push(semanticStyles.indeterminateStyle);
        }
        if (disabled) states.push(semanticStyles.disabledStyle);
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
