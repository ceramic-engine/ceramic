// Ported from gpui-kit 0.8.1: crates/base/src/radio.rs
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

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * An unstyled radio control that owns activation, focus, and accessibility behavior.
 *
 * The application owns its indicator, label, layout, colors, and state styling.
 * Selection is controlled through `checked`; activating an unchecked radio
 * requests `true` through `onChange`.
 *
 * Interactive styles and listeners go to `base` (see `gpui.base.Button`).
 */
class Radio implements RenderOnce implements Styled implements ParentElement {

    var radioId:ElementId;

    /** The stateful element the radio renders. */
    public final base:Div;

    final radioStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:RadioStyles = new RadioStyles();

    var checkedValue:Bool = false;

    var disabledValue:Bool = false;

    final childElements:Array<AnyElement> = [];

    var onChangeHandler:Null<(Bool, ClickEvent, Window, App) -> Void> = null;

    var accessibilityLabelValue:Null<String> = null;

    var tabIndexValue:Int = 0;

    var tabStopValue:Bool = true;

    var providedFocusHandle:Null<FocusHandle> = null;

    var positionInSet:Null<Int> = null;

    var sizeOfSet:Null<Int> = null;

    /** The accessibility properties the radio exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.RadioButton);

    public function new(id:ElementIdArg) {
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

    public function checked(checked:Bool):Radio {
        checkedValue = checked;
        return this;
    }

    public function disabled(disabled:Bool):Radio {
        disabledValue = disabled;
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
        if (checkedValue) states.push(semanticStyles.checkedStyle);
        if (disabledValue) states.push(semanticStyles.disabledStyle);
        return StateStyle.resolveStyle(radioStyle, states);
    }

    public function accessibilityLabel(label:String):Radio {
        accessibilityLabelValue = label;
        return this;
    }

    /**
     * Handles a requested selection change.
     *
     * The callback receives `true`. Activating an already checked radio is a
     * no-op because a radio cannot deselect itself.
     */
    public function onChange(handler:(Bool, ClickEvent, Window, App) -> Void):Radio {
        onChangeHandler = handler;
        return this;
    }

    /**
     * Uses a caller-owned focus handle instead of creating keyed state.
     *
     * A styled radio needs this to draw its own focus ring from the same
     * handle the primitive tracks.
     */
    public function trackFocus(focusHandle:FocusHandle):Radio {
        providedFocusHandle = focusHandle;
        return this;
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

    public function tabIndex(tabIndex:Int):Radio {
        tabIndexValue = tabIndex;
        return this;
    }

    public function tabStop(tabStop:Bool):Radio {
        tabStopValue = tabStop;
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
        if (providedFocusHandle != null) return providedFocusHandle;
        return window.useKeyedState(radioId, cx, _ -> cx.focusHandle()).read(cx).value;
    }

    public function render(window:Window, cx:App):IntoElement {
        final focusHandle = this.focusHandle(window, cx);
        final disabled = disabledValue;
        final checked = checkedValue;
        final style = resolvedStyle();
        final onChange = onChangeHandler;

        final element = base;
        a11y.toggled = checked ? Toggled.True : Toggled.False;
        // A radio is both "toggled" and "selected"; different assistive
        // technology reads one or the other, so state both rather than
        // making callers choose.
        a11y.selected = checked;
        if (accessibilityLabelValue != null) a11y.label = accessibilityLabelValue;
        if (positionInSet != null) a11y.positionInSet = positionInSet;
        if (sizeOfSet != null) a11y.sizeOfSet = sizeOfSet;
        if (!disabled) {
            element.trackFocus(focusHandle.tabIndex(tabIndexValue).tabStop(tabStopValue));
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

    @:allow(gpui.base)
    final checkedStyle:StyleRefinement = new StyleRefinement();

    @:allow(gpui.base)
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
