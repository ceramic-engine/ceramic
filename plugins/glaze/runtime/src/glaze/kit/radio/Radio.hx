// Ported from gpui-kit 0.8.1: crates/component/src/radio.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.radio;

import gpui.AnyElement;
import gpui.App;
import gpui.Axis;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.ComponentTraits;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.Size.IntoSize;
import gpui.component.checkbox.Checkbox;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import gpui.component.tooltip.Tooltip.ComponentTooltip;

using gpui.base.StyledExt;
using gpui.component.StyleSized;
using gpui.component.ThemeStyled;

/**
 * A Radio element.
 *
 * This does not include the radio group behavior: manage the group yourself
 * or use `RadioGroup`. The label is a plain string (Rust `Text::String`).
 * The tooltip is a managed tooltip (`gpui.component.tooltip`).
 */
class Radio implements RenderOnce implements Styled implements ParentElement implements Sizable implements FocusableExt {

    /** The Base radio the component renders (interactive listeners go to `base.base`). */
    public final base:gpui.base.Radio;

    final radioStyle:StyleRefinement = new StyleRefinement();

    @:allow(gpui.component, tests)
    var id:ElementId;

    @:allow(gpui.component, tests)
    var labelValue:Null<String> = null;

    /** The announced name, when the visible label is not it. */
    @:allow(gpui.component, tests)
    var accessibilityLabelValue:Null<String> = null;

    final childElements:Array<AnyElement> = [];

    var checkedValue:Bool = false;

    @:allow(gpui.component, tests)
    var disabledValue:Bool = false;

    var tabStopValue:Bool = true;

    var tabIndexValue:Int = 0;

    var sizeValue:Size = Medium;

    var onClickHandler:Null<(Bool, Window, App) -> Void> = null;

    var tooltipText:Null<String> = null;

    var tooltipShowDelayValue:Null<Float> = null;

    @:allow(gpui.component, tests)
    var positionInSet:Null<Int> = null;

    @:allow(gpui.component, tests)
    var sizeOfSet:Null<Int> = null;

    var focusRingEnabled:Bool = true;

    /**
     * Create a new Radio element with the given id.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
        this.base = new gpui.base.Radio(id);
    }

    /**
     * A radio labeled with `label`, which is also its id (Rust `From<&str>`).
     */
    public static function labeled(label:String):Radio {
        return new Radio(label).label(label);
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
     * Set tooltip text for the radio.
     */
    public function tooltip(tooltip:String):Radio {
        tooltipText = tooltip;
        return this;
    }

    /**
     * Overrides how long the pointer must rest before the tooltip shows, in seconds.
     */
    public function tooltipShowDelay(delay:Float):Radio {
        tooltipShowDelayValue = delay;
        return this;
    }

    /**
     * Set the label of the Radio element.
     */
    public function label(label:String):Radio {
        labelValue = label;
        return this;
    }

    /**
     * Set the name a screen reader announces, when the visible label is not it.
     */
    public function accessibilityLabel(label:String):Radio {
        accessibilityLabelValue = label;
        return this;
    }

    /**
     * Set the checked state of the Radio element, default is `false`.
     */
    public function checked(checked:Bool):Radio {
        checkedValue = checked;
        return this;
    }

    /**
     * Set the disabled state of the Radio element, default is `false`.
     */
    public function disabled(disabled:Bool):Radio {
        disabledValue = disabled;
        return this;
    }

    /**
     * Set the tab index for the Radio element, default is `0`.
     */
    public function tabIndex(tabIndex:Int):Radio {
        tabIndexValue = tabIndex;
        return this;
    }

    /**
     * Set the tab stop for the Radio element, default is `true`.
     */
    public function tabStop(tabStop:Bool):Radio {
        tabStopValue = tabStop;
        return this;
    }

    /**
     * Alias for `onChange`. The last callback registered with either name wins.
     */
    public function onClick(handler:(Bool, Window, App) -> Void):Radio {
        return onChange(handler);
    }

    /**
     * Handle a requested checked value from pointer or keyboard activation.
     *
     * This is a controlled value: the owner must write the requested value to
     * render it. Disabled controls do not call the handler.
     */
    public function onChange(handler:(Bool, Window, App) -> Void):Radio {
        onClickHandler = handler;
        return this;
    }

    public function withSize(size:IntoSize):Radio {
        this.sizeValue = size;
        return this;
    }

    public function focusRing(enabled:Bool):Radio {
        focusRingEnabled = enabled;
        return this;
    }

    public function setFocusRing(enabled:Bool):Void {
        focusRingEnabled = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return focusRingEnabled;
    }

    public function render(window:Window, cx:App):IntoElement {
        final size = sizeValue;
        final theme = Theme.global(cx);
        final checked = checkedValue;
        final hasContent = labelValue != null || childElements.length > 0;
        final indicatorSize = switch size {
            case XSmall: 0.75;
            case Small: 0.875;
            case Large: 1.125;
            case _: 1.;
        }
        final focusHandle:FocusHandle = window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
        final isFocused = focusHandle.isFocused(window);
        final disabled = disabledValue;
        final accessibilityLabel = accessibilityLabelValue != null ? accessibilityLabelValue : labelValue;

        var borderColor = checked ? theme.primary : theme.input;
        var bg = checked ? theme.primary : theme.input.opacity(0.5);
        if (disabled) {
            borderColor = borderColor.opacity(0.5);
            bg = bg.opacity(0.5);
        }

        final element = base.id(id).checked(checkedValue).disabled(disabledValue).trackFocus(focusHandle).tabStop(tabStopValue).tabIndex(tabIndexValue);
        if (accessibilityLabel != null) element.accessibilityLabel(accessibilityLabel);
        if (positionInSet != null && sizeOfSet != null) element.setPosition(positionInSet, sizeOfSet);
        element.hFlex().gapX2().textColor(theme.foreground).itemsStart().lineHeight(gpui.Prelude.relative(1.)).rounded(theme.radius * 0.5);
        if (isFocused && focusRingEnabled) element.focusRingStyle(window, cx);
        switch size {
            case Size(_):
            case _: element.inputTextSize(size);
        }
        element.refineStyle(radioStyle);

        final indicator = div().relative().size(rems(indicatorSize));
        // Center on the first 1.25em line, including when the label wraps.
        if (hasContent) indicator.mt(rems(indicatorSize * 0.125));
        indicator.flexShrink0().roundedFullStyle(cx).border1().borderColor(borderColor);
        if (!checkedValue) {
            indicator.bg(theme.inputBackground());
        } else if (disabled) {
            indicator.bg(bg);
        } else {
            indicator.bg(theme.tokens.primary.background);
        }
        indicator.child(@:privateAccess Checkbox.checkboxCheckIcon(id, size, checked, disabled, window, cx));
        element.child(indicator);

        if (childElements.length > 0 || labelValue != null) {
            final column = vFlex().wFull().lineHeight(gpui.Prelude.relative(1.25)).gap1();
            if (labelValue != null) {
                final labelDiv = div().sizeFull();
                if (disabledValue) labelDiv.textColor(theme.mutedForeground);
                column.child(labelDiv.child(labelValue));
            }
            for (child in childElements) column.child(child);
            element.child(column);
        }
        element.onMouseDown(Left, (_, window, _) -> window.preventDefault());
        final onClick = onClickHandler;
        if (onClick != null) {
            element.onChange((next, _, window, cx) -> {
                window.preventDefault();
                onClick(next, window, cx);
            });
        }
        return ComponentTooltip.of(tooltipText, tooltipShowDelayValue).apply(element, element.base);
    }

}

/**
 * A Radio group element.
 */
class RadioGroup implements RenderOnce implements Styled {

    final id:ElementId;

    final groupStyle:StyleRefinement = new StyleRefinement();

    @:allow(gpui.component, tests)
    final radios:Array<Radio> = [];

    var layoutValue:Axis = Axis.Vertical;

    var selectedIndexValue:Null<Int> = null;

    var disabledValue:Bool = false;

    var onClickHandler:Null<(Int, Window, App) -> Void> = null;

    /**
     * Creates a radio group with vertical layout and no selected item.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
        new gpui.StyleBuilder(groupStyle).flex1();
    }

    /**
     * Create a new Radio group with default Vertical layout.
     */
    public static function vertical(id:ElementIdArg):RadioGroup {
        return new RadioGroup(id);
    }

    /**
     * Create a new Radio group with Horizontal layout.
     */
    public static function horizontal(id:ElementIdArg):RadioGroup {
        return new RadioGroup(id).layout(Axis.Horizontal);
    }

    public inline function style():StyleRefinement {
        return groupStyle;
    }

    /**
     * Set the layout of the Radio group. Default is `Axis.Vertical`.
     */
    public function layout(layout:Axis):RadioGroup {
        layoutValue = layout;
        return this;
    }

    /**
     * Alias for `onChange`. The last callback registered with either name wins.
     */
    public function onClick(handler:(Int, Window, App) -> Void):RadioGroup {
        return onChange(handler);
    }

    /**
     * Handle a requested selected index from pointer or keyboard activation.
     *
     * This is a controlled value: the owner must write the requested value to
     * render it. Disabled controls do not call the handler.
     */
    public function onChange(handler:(Int, Window, App) -> Void):RadioGroup {
        onClickHandler = handler;
        return this;
    }

    /**
     * Set the selected index.
     */
    public function selectedIndex(index:Null<Int>):RadioGroup {
        selectedIndexValue = index;
        return this;
    }

    /**
     * Set the disabled state.
     */
    public function disabled(disabled:Bool):RadioGroup {
        disabledValue = disabled;
        return this;
    }

    /**
     * Add a child Radio element.
     */
    public function child(child:Radio):RadioGroup {
        if (child != null) radios.push(child);
        return this;
    }

    /**
     * Add multiple child Radio elements.
     */
    public function children(children:Array<Radio>):RadioGroup {
        for (child in children) if (child != null) radios.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final onClick = onClickHandler;
        final disabled = disabledValue;
        final selectedIx = selectedIndexValue;

        final base = layoutValue == Axis.Vertical ? vFlex() : hFlex().wFull().flexWrap();

        final total = radios.length;
        base.gap3();
        for (ix in 0...radios.length) {
            final radio = radios[ix];
            final checked = selectedIx == ix;

            radio.id = Integer(ix);
            radio.positionInSet = ix + 1;
            radio.sizeOfSet = total;
            final itemDisabled = radio.disabledValue;
            radio.disabled(disabled || itemDisabled).checked(checked);
            if (onClick != null) {
                radio.onClick((_, window, cx) -> onClick(ix, window, cx));
            }
            base.child(radio);
        }
        return new gpui.base.RadioGroup(id).axis(layoutValue).refineStyle(groupStyle).child(base);
    }

}
