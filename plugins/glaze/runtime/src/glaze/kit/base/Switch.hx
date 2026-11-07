// Ported from gpui-kit 0.8.1: crates/base/src/switch.rs
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

using glaze.kit.base.StyledExt;

/**
 * An unstyled binary control that owns switch interaction and semantics.
 *
 * The checked value is controlled by the application. Activation reports the
 * next value through `onChange`; the application must render that value back
 * through `checked`. Children and all visual states remain application-owned.
 *
 * Interactive styles and listeners go to `base` (see `glaze.kit.base.Button`).
 */
class Switch implements RenderOnce implements Styled implements ParentElement {

    final id:ElementId;

    /** The stateful element the switch renders. */
    public final base:Div;

    final switchStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:SwitchStyles = new SwitchStyles();

    var checkedValue:Bool = false;

    var disabledValue:Bool = false;

    final childElements:Array<AnyElement> = [];

    var onChangeHandler:Null<(Bool, ClickEvent, Window, App) -> Void> = null;

    var accessibilityLabelValue:Null<String> = null;

    var tabIndexValue:Int = 0;

    var tabStopValue:Bool = true;

    var providedFocusHandle:Null<FocusHandle> = null;

    /** The accessibility properties the switch exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.Switch);

    public function new(id:ElementIdArg) {
        this.id = id;
        this.base = div().id(id);
    }

    public inline function style():StyleRefinement {
        return switchStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Switch {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Switch {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    /**
     * Sets the application-controlled checked value.
     */
    public function checked(checked:Bool):Switch {
        checkedValue = checked;
        return this;
    }

    /**
     * Sets whether pointer and keyboard activation are ignored.
     */
    public function disabled(disabled:Bool):Switch {
        disabledValue = disabled;
        return this;
    }

    /**
     * Configures application-owned styles for the switch's semantic states.
     */
    public function styles(build:(SwitchStyles) -> SwitchStyles):Switch {
        semanticStyles = build(semanticStyles);
        return this;
    }

    @:allow(tests)
    function resolvedStyle():StyleRefinement {
        final states = [];
        if (checkedValue) states.push(semanticStyles.checkedStyle);
        if (disabledValue) states.push(semanticStyles.disabledStyle);
        return StateStyle.resolveStyle(switchStyle, states);
    }

    /**
     * Handles activation with the next checked value and its input event.
     */
    public function onChange(handler:(Bool, ClickEvent, Window, App) -> Void):Switch {
        onChangeHandler = handler;
        return this;
    }

    /**
     * Sets the name exposed to accessibility clients.
     *
     * A switch without text children has no accessible name, so set this
     * whenever it is drawn without visible text.
     */
    public function accessibilityLabel(label:String):Switch {
        accessibilityLabelValue = label;
        return this;
    }

    /**
     * Sets the focus traversal index. Use this within a GPUI tab group.
     */
    public function tabIndex(tabIndex:Int):Switch {
        tabIndexValue = tabIndex;
        return this;
    }

    /**
     * Sets whether the switch participates in keyboard focus traversal.
     */
    public function tabStop(tabStop:Bool):Switch {
        tabStopValue = tabStop;
        return this;
    }

    /**
     * Uses a caller-owned focus handle instead of creating keyed state.
     */
    public function trackFocus(focusHandle:FocusHandle):Switch {
        providedFocusHandle = focusHandle;
        return this;
    }

    /** Interactive style while hovered (on `base`). */
    public function hover(f:(StyleBuilder) -> StyleBuilder):Switch {
        base.hover(f);
        return this;
    }

    /** Interactive style while pressed (on `base`). */
    public function active(f:(StyleBuilder) -> StyleBuilder):Switch {
        base.active(f);
        return this;
    }

    /** Interactive style while focused by the keyboard (on `base`). */
    public function focusVisible(f:(StyleBuilder) -> StyleBuilder):Switch {
        base.focusVisible(f);
        return this;
    }

    /** A mouse down listener (on `base`). */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):Switch {
        base.onMouseDown(button, listener);
        return this;
    }

    function focusHandle(window:Window, cx:App):FocusHandle {
        if (providedFocusHandle != null) return providedFocusHandle;
        return window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
    }

    public function render(window:Window, cx:App):IntoElement {
        final focusHandle = this.focusHandle(window, cx);
        final checked = checkedValue;
        final disabled = disabledValue;
        final style = resolvedStyle();
        final onChange = onChangeHandler;

        final element = base;
        a11y.toggled = checked ? Toggled.True : Toggled.False;
        if (accessibilityLabelValue != null) a11y.label = accessibilityLabelValue;
        if (!disabled) {
            element.trackFocus(focusHandle.tabIndex(tabIndexValue).tabStop(tabStopValue));
        }
        if (disabled) {
            element.onMouseDown(Left, (_, _, cx) -> cx.stopPropagation());
        }
        if (!disabled && onChange != null) {
            a11y.clickable = true;
            element.onClick((event, window, cx) -> onChange(!checked, event, window, cx));
        }
        element.extend(childElements);
        a11y.disabled = disabled;
        return element.refineStyle(style);
    }

}

/**
 * Semantic root styles supported by `Switch` (and by its `SwitchTrack` and
 * `SwitchThumb` parts: Rust `SwitchTrackStyles`, `SwitchThumbStyles`).
 */
class SwitchStyles {

    @:allow(glaze.kit.base)
    final checkedStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit.base)
    final disabledStyle:StyleRefinement = new StyleRefinement();

    public function new() {}

    public function checked(build:(StateStyle) -> StateStyle):SwitchStyles {
        checkedStyle.refine(build(new StateStyle()).intoRefinement());
        return this;
    }

    public function disabled(build:(StateStyle) -> StateStyle):SwitchStyles {
        disabledStyle.refine(build(new StateStyle()).intoRefinement());
        return this;
    }

}

typedef SwitchTrackStyles = SwitchStyles;

typedef SwitchThumbStyles = SwitchStyles;

/**
 * An unstyled switch track with typed checked and disabled state projection.
 */
class SwitchTrack implements RenderOnce implements Styled implements ParentElement {

    /** The stateful element the track renders. */
    @:allow(tests)
    final base:Div;

    @:allow(tests)
    final trackId:ElementId;

    final trackStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:SwitchStyles = new SwitchStyles();

    var checkedValue:Bool = false;

    var disabledValue:Bool = false;

    final childElements:Array<AnyElement> = [];

    public function new(id:ElementIdArg) {
        trackId = id;
        base = div().id(id);
    }

    public inline function style():StyleRefinement {
        return trackStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):SwitchTrack {
        if (child != null) childElements.push(child);
        return this;
    }

    public function checked(checked:Bool):SwitchTrack {
        checkedValue = checked;
        return this;
    }

    public function disabled(disabled:Bool):SwitchTrack {
        disabledValue = disabled;
        return this;
    }

    public function styles(build:(SwitchStyles) -> SwitchStyles):SwitchTrack {
        semanticStyles = build(semanticStyles);
        return this;
    }

    /** Rust `debug_selector` (on `base`). */
    public function debugSelector(selector:() -> String):SwitchTrack {
        base.debugSelector(selector);
        return this;
    }

    @:allow(tests)
    function resolvedStyle():StyleRefinement {
        final states = [];
        if (checkedValue) states.push(semanticStyles.checkedStyle);
        if (disabledValue) states.push(semanticStyles.disabledStyle);
        return StateStyle.resolveStyle(trackStyle, states);
    }

    public function render(window:Window, cx:App):IntoElement {
        final style = resolvedStyle();
        base.extend(childElements);
        return base.refineStyle(style);
    }

}

/**
 * An unstyled switch thumb with typed checked and disabled state projection.
 */
class SwitchThumb implements RenderOnce implements Styled implements ParentElement {

    final thumbStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:SwitchStyles = new SwitchStyles();

    final checkedValue:Bool;

    var disabledValue:Bool = false;

    final childElements:Array<AnyElement> = [];

    public function new(checked:Bool) {
        checkedValue = checked;
    }

    public inline function style():StyleRefinement {
        return thumbStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):SwitchThumb {
        if (child != null) childElements.push(child);
        return this;
    }

    public function disabled(disabled:Bool):SwitchThumb {
        disabledValue = disabled;
        return this;
    }

    public function styles(build:(SwitchStyles) -> SwitchStyles):SwitchThumb {
        semanticStyles = build(semanticStyles);
        return this;
    }

    @:allow(tests)
    function resolvedStyle():StyleRefinement {
        final states = [];
        if (checkedValue) states.push(semanticStyles.checkedStyle);
        if (disabledValue) states.push(semanticStyles.disabledStyle);
        return StateStyle.resolveStyle(thumbStyle, states);
    }

    public function render(window:Window, cx:App):IntoElement {
        final style = resolvedStyle();
        final element = div();
        element.extend(childElements);
        return element.refineStyle(style);
    }

}
