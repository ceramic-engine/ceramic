// Ported from gpui-kit 0.8.1: crates/base/src/toggle.rs
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
 * An unstyled, controlled toggle button.
 *
 * This primitive owns activation, focus, and accessibility behavior. The
 * application owns all layout, visual states, sizes, and variants.
 *
 * Interactive styles and listeners go to `base` (see `gpui.base.Button`).
 */
class Toggle implements RenderOnce implements Styled implements ParentElement {

    final id:ElementId;

    /** The stateful element the toggle renders. */
    public final base:Div;

    final toggleStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:ToggleStyles = new ToggleStyles();

    var pressedValue:Bool = false;

    var disabledValue:Bool = false;

    final childElements:Array<AnyElement> = [];

    var onChangeHandler:Null<(Bool, ClickEvent, Window, App) -> Void> = null;

    var accessibilityLabelValue:Null<String> = null;

    var tabIndexValue:Int = 0;

    var tabStopValue:Bool = true;

    var trackedFocus:Null<FocusHandle> = null;

    /** The accessibility properties the toggle exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.Button);

    public function new(id:ElementIdArg) {
        this.id = id;
        this.base = div().id(id);
    }

    public inline function style():StyleRefinement {
        return toggleStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Toggle {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Toggle {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function pressed(pressed:Bool):Toggle {
        pressedValue = pressed;
        return this;
    }

    public function disabled(disabled:Bool):Toggle {
        disabledValue = disabled;
        return this;
    }

    /**
     * Configures application-owned styles for the toggle's semantic states.
     */
    public function styles(build:(ToggleStyles) -> ToggleStyles):Toggle {
        semanticStyles = build(semanticStyles);
        return this;
    }

    @:allow(tests)
    function resolvedStyle():StyleRefinement {
        final states = [];
        if (pressedValue) states.push(semanticStyles.pressedStyle);
        if (disabledValue) states.push(semanticStyles.disabledStyle);
        return StateStyle.resolveStyle(toggleStyle, states);
    }

    public function accessibilityLabel(label:String):Toggle {
        accessibilityLabelValue = label;
        return this;
    }

    /**
     * Handles a request to change the controlled pressed state.
     */
    public function onChange(handler:(Bool, ClickEvent, Window, App) -> Void):Toggle {
        onChangeHandler = handler;
        return this;
    }

    public function tabIndex(tabIndex:Int):Toggle {
        tabIndexValue = tabIndex;
        return this;
    }

    public function tabStop(tabStop:Bool):Toggle {
        tabStopValue = tabStop;
        return this;
    }

    public function trackFocus(focusHandle:FocusHandle):Toggle {
        trackedFocus = focusHandle;
        return this;
    }

    /** Interactive style while hovered (on `base`). */
    public function hover(f:(StyleBuilder) -> StyleBuilder):Toggle {
        base.hover(f);
        return this;
    }

    /** Interactive style while pressed (on `base`). */
    public function active(f:(StyleBuilder) -> StyleBuilder):Toggle {
        base.active(f);
        return this;
    }

    /** Interactive style while focused by the keyboard (on `base`). */
    public function focusVisible(f:(StyleBuilder) -> StyleBuilder):Toggle {
        base.focusVisible(f);
        return this;
    }

    /** A mouse down listener (on `base`). */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):Toggle {
        base.onMouseDown(button, listener);
        return this;
    }

    /** A click listener on the element itself (on `base`), Rust `StatefulInteractiveElement::on_click`. */
    public function onClick(listener:(ClickEvent, Window, App) -> Void):Toggle {
        base.onClick(listener);
        return this;
    }

    function focusHandle(window:Window, cx:App):FocusHandle {
        return window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
    }

    public function render(window:Window, cx:App):IntoElement {
        final focusHandle = trackedFocus != null ? trackedFocus : this.focusHandle(window, cx);
        final pressed = pressedValue;
        final disabled = disabledValue;
        final style = resolvedStyle();
        final onChange = onChangeHandler;

        // Match Button's neutral control geometry: a fixed-size toggle
        // centers ordinary content, while callers still own its size,
        // spacing and visual treatment.
        final element = base.flex().itemsCenter().justifyCenter().lineHeight(gpui.Prelude.relative(1.));
        a11y.toggled = pressed ? Toggled.True : Toggled.False;
        if (accessibilityLabelValue != null) a11y.label = accessibilityLabelValue;
        if (!disabled) {
            element.trackFocus(focusHandle.tabIndex(tabIndexValue).tabStop(tabStopValue));
        }
        if (disabled) {
            element.onMouseDown(Left, (_, _, cx) -> cx.stopPropagation());
        }
        if (!disabled && onChange != null) {
            a11y.clickable = true;
            element.onClick((event, window, cx) -> onChange(!pressed, event, window, cx));
        }
        element.extend(childElements);
        a11y.disabled = disabled;
        return element.refineStyle(style);
    }

}

/**
 * Semantic root styles supported by `Toggle`.
 */
class ToggleStyles {

    @:allow(gpui.base)
    final pressedStyle:StyleRefinement = new StyleRefinement();

    @:allow(gpui.base)
    final disabledStyle:StyleRefinement = new StyleRefinement();

    public function new() {}

    public function pressed(build:(StateStyle) -> StateStyle):ToggleStyles {
        pressedStyle.refine(build(new StateStyle()).intoRefinement());
        return this;
    }

    public function disabled(build:(StateStyle) -> StateStyle):ToggleStyles {
        disabledStyle.refine(build(new StateStyle()).intoRefinement());
        return this;
    }

}
