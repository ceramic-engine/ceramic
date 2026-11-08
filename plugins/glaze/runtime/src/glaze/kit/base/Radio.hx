// Ported from gpui-kit 0.8.1: crates/base/src/radio.rs
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

using glaze.kit.base.StyledExt;

/**
 * An unstyled radio control that owns activation, focus, and accessibility behavior.
 *
 * The application owns its indicator, label, layout, colors, and state styling.
 * Selection is controlled through `checked`; activating an unchecked radio
 * requests `true` through `onChange`.
 *
 * Interactive styles and listeners go to `base` (see `glaze.kit.base.Button`).
 */
class Radio extends Component implements Styled implements ParentElement {

    var radioId:ElementId;

    /** The stateful element the radio renders. */
    public final base:Div;

    final radioStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:RadioStyles = new RadioStyles();

    @prop var checked:Bool = false;

    @prop var disabled:Bool = false;

    final childElements:Array<AnyElement> = [];

    /**
     * Handles a requested selection change.
     *
     * The callback receives `true`. Activating an already checked radio is a
     * no-op because a radio cannot deselect itself.
     */
    @prop var onChange:Null<(Bool, ClickEvent, Window, App) -> Void> = null;

    @prop var accessibilityLabel:Null<String> = null;

    @prop var tabIndex:Int = 0;

    @prop var tabStop:Bool = true;

    /**
     * Uses a caller-owned focus handle instead of creating keyed state.
     *
     * A styled radio needs this to draw its own focus ring from the same
     * handle the primitive tracks.
     */
    @prop var trackFocus:Null<FocusHandle> = null;

    var positionInSet:Null<Int> = null;

    var sizeOfSet:Null<Int> = null;

    /** The accessibility properties the radio exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.RadioButton);

    public function new(id:ElementIdArg) {
        super();
        this.radioId = id;
        this.base = div().id(id);
    }

    /**
     * Updates the element identity used when the radio is rendered.
     *
     * A group that assigns positional ids after construction needs this so
     * each radio keeps a distinct element identity.
     */
    public function id(id:ElementIdArg):Radio {
        base.id(id);
        radioId = id;
        return this;
    }

    public inline function style():StyleRefinement {
        return radioStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Radio {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Radio {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    /**
     * Configures application-owned styles for the radio's semantic states.
     */
    public function styles(build:(RadioStyles) -> RadioStyles):Radio {
        semanticStyles = build(semanticStyles);
        return this;
    }

    @:allow(tests)
    function resolvedStyle():StyleRefinement {
        final states = [];
        if (checked) states.push(semanticStyles.checkedStyle);
        if (disabled) states.push(semanticStyles.disabledStyle);
        return StateStyle.resolveStyle(radioStyle, states);
    }

    /**
     * Sets this radio's one-based position and its group's total size, so
     * assistive technology can announce "option 2 of 5".
     */
    public function setPosition(position:Int, size:Int):Radio {
        positionInSet = position;
        sizeOfSet = size;
        return this;
    }

    /** Interactive style while hovered (on `base`). */
    public function hover(f:(StyleBuilder) -> StyleBuilder):Radio {
        base.hover(f);
        return this;
    }

    /** Interactive style while pressed (on `base`). */
    public function active(f:(StyleBuilder) -> StyleBuilder):Radio {
        base.active(f);
        return this;
    }

    /** Interactive style while focused by the keyboard (on `base`). */
    public function focusVisible(f:(StyleBuilder) -> StyleBuilder):Radio {
        base.focusVisible(f);
        return this;
    }

    /** A mouse down listener (on `base`). */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):Radio {
        base.onMouseDown(button, listener);
        return this;
    }

    function focusHandle(window:Window, cx:App):FocusHandle {
        if (trackFocus != null) return trackFocus;
        return window.useKeyedState(radioId, cx, _ -> cx.focusHandle()).read(cx).value;
    }

    public function render(window:Window, cx:App):IntoElement {
        final focusHandle = this.focusHandle(window, cx);
        final disabled = this.disabled;
        final checked = this.checked;
        final style = resolvedStyle();
        final onChange = this.onChange;

        final element = base;
        a11y.toggled = checked ? Toggled.True : Toggled.False;
        // A radio is both "toggled" and "selected"; different assistive
        // technology reads one or the other, so state both rather than
        // making callers choose.
        a11y.selected = checked;
        if (accessibilityLabel != null) a11y.label = accessibilityLabel;
        if (positionInSet != null) a11y.positionInSet = positionInSet;
        if (sizeOfSet != null) a11y.sizeOfSet = sizeOfSet;
        if (!disabled) {
            element.trackFocus(focusHandle.tabIndex(tabIndex).tabStop(tabStop));
        }
        if (!disabled && !checked && onChange != null) {
            a11y.clickable = true;
            element.onClick((event, window, cx) -> onChange(!checked, event, window, cx));
        }
        element.extend(childElements);
        a11y.disabled = disabled;
        return element.refineStyle(style);
    }

}

/**
 * Semantic root styles supported by `Radio`.
 */
class RadioStyles {

    @:allow(glaze.kit.base)
    final checkedStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit.base)
    final disabledStyle:StyleRefinement = new StyleRefinement();

    public function new() {}

    public function checked(build:(StateStyle) -> StateStyle):RadioStyles {
        checkedStyle.refine(build(new StateStyle()).intoRefinement());
        return this;
    }

    public function disabled(build:(StateStyle) -> StateStyle):RadioStyles {
        disabledStyle.refine(build(new StateStyle()).intoRefinement());
        return this;
    }

}
