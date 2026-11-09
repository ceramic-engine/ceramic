// Ported from gpui-kit 0.8.1: crates/component/src/radio.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.radio;

import glaze.AnyElement;
import glaze.App;
import glaze.kit.CheckedListener;
import glaze.kit.ValueListener;
import glaze.Axis;
import glaze.Component;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.checkbox.Checkbox;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import glaze.kit.tooltip.Tooltip.ComponentTooltip;

using glaze.kit.base.StyledExt;
using glaze.kit.StyleSized;
using glaze.kit.ThemeStyled;

/**
 * A Radio element.
 *
 * This does not include the radio group behavior: manage the group yourself
 * or use `RadioGroup`. The label is a plain string (Rust `Text::String`).
 * The tooltip is a managed tooltip (`glaze.kit.tooltip`).
 */
class Radio extends Component implements Styled implements ParentElement implements Sizable implements FocusableExt {

    /** The Base radio the component renders (interactive listeners go to `base.base`). */
    public final base:glaze.kit.base.Radio;

    final radioStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit, tests)
    var id:ElementId;

    /**
     * Set the label of the Radio element.
     */
    @:allow(glaze.kit, tests)
    @prop var label:Null<String> = null;

    /**
     * Set the name a screen reader announces, when the visible label is not it.
     */
    @:allow(glaze.kit, tests)
    @prop var accessibilityLabel:Null<String> = null;

    final childElements:Array<AnyElement> = [];

    /**
     * Set the checked state of the Radio element, default is `false`.
     */
    @prop var checked:Bool = false;

    /**
     * Set the disabled state of the Radio element, default is `false`.
     */
    @:allow(glaze.kit, tests)
    @prop var disabled:Bool = false;

    /**
     * Set the tab stop for the Radio element, default is `true`.
     */
    @prop var tabStop:Bool = true;

    /**
     * Set the tab index for the Radio element, default is `0`.
     */
    @prop var tabIndex:Int = 0;

    var sizeValue:Size = Medium;

    var onClickHandler:Null<(Bool, Window, App) -> Void> = null;

    /**
     * Set tooltip text for the radio.
     */
    @prop var tooltip:Null<String> = null;

    /**
     * Overrides how long the pointer must rest before the tooltip shows, in seconds.
     */
    @prop var tooltipShowDelay:Null<Float> = null;

    @:allow(glaze.kit, tests)
    var positionInSet:Null<Int> = null;

    @:allow(glaze.kit, tests)
    var sizeOfSet:Null<Int> = null;

    @prop var focusRing:Bool = true;

    /**
     * Create a new Radio element with the given id.
     */
    public function new(id:ElementIdArg) {
        super();
        this.id = id;
        this.base = glaze.kit.base.Radio.component(id);
    }

    /**
     * A radio labeled with `label`, which is also its id (Rust `From<&str>`).
     */
    public static function labeled(label:String):Radio {
        return Radio.component(label).label(label);
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
     * Alias for `onChange`. The last callback registered with either name wins.
     */
    public function onClick(handler:CheckedListener):Radio {
        return onChange(handler);
    }

    /**
     * Handle a requested checked value from pointer or keyboard activation.
     *
     * This is a controlled value: the owner must write the requested value to
     * render it. Disabled controls do not call the handler. Also written
     * `onChange(checked -> ...)` or `onChange(() -> ...)` (`CheckedListener`).
     */
    public function onChange(handler:CheckedListener):Radio {
        onClickHandler = handler;
        return this;
    }

    public function withSize(size:IntoSize):Radio {
        this.sizeValue = size;
        return this;
    }

    public function setFocusRing(enabled:Bool):Void {
        focusRing = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return focusRing;
    }

    public function render(window:Window, cx:App):IntoElement {
        final size = sizeValue;
        final theme = Theme.global(cx);
        final checked = this.checked;
        final hasContent = label != null || childElements.length > 0;
        final indicatorSize = switch size {
            case XSmall: 0.75;
            case Small: 0.875;
            case Large: 1.125;
            case _: 1.;
        }
        final focusHandle:FocusHandle = window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
        final isFocused = focusHandle.isFocused(window);
        final disabled = this.disabled;
        final accessibilityLabel = this.accessibilityLabel != null ? this.accessibilityLabel : label;

        var borderColor = checked ? theme.primary : theme.input;
        var bg = checked ? theme.primary : theme.input.opacity(0.5);
        if (disabled) {
            borderColor = borderColor.opacity(0.5);
            bg = bg.opacity(0.5);
        }

        final element = base.id(id).checked(this.checked).disabled(this.disabled).trackFocus(focusHandle).tabStop(tabStop).tabIndex(tabIndex);
        if (accessibilityLabel != null) element.accessibilityLabel(accessibilityLabel);
        if (positionInSet != null && sizeOfSet != null) element.setPosition(positionInSet, sizeOfSet);
        element.hFlex().gapX2().textColor(theme.foreground).itemsStart().lineHeight(glaze.Prelude.relative(1.)).rounded(theme.radius * 0.5);
        if (isFocused && focusRing) element.focusRingStyle(window, cx);
        switch size {
            case Size(_):
            case _: element.inputTextSize(size);
        }
        element.refineStyle(radioStyle);

        final indicator = div().relative().size(rems(indicatorSize));
        // Center on the first 1.25em line, including when the label wraps.
        if (hasContent) indicator.mt(rems(indicatorSize * 0.125));
        indicator.flexShrink0().roundedFullStyle(cx).border1().borderColor(borderColor);
        if (!this.checked) {
            indicator.bg(theme.inputBackground());
        } else if (disabled) {
            indicator.bg(bg);
        } else {
            indicator.bg(theme.tokens.primary.background);
        }
        indicator.child(@:privateAccess Checkbox.checkboxCheckIcon(id, size, checked, disabled, window, cx));
        element.child(indicator);

        if (childElements.length > 0 || label != null) {
            final column = vFlex().wFull().lineHeight(glaze.Prelude.relative(1.25)).gap1();
            if (label != null) {
                final labelDiv = div().sizeFull();
                if (this.disabled) labelDiv.textColor(theme.mutedForeground);
                column.child(labelDiv.child(label));
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
        return ComponentTooltip.of(tooltip, tooltipShowDelay).apply(element, element.base);
    }

}

/**
 * A Radio group element.
 */
class RadioGroup extends Component implements Styled {

    final id:ElementId;

    final groupStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit, tests)
    final radios:Array<Radio> = [];

    /**
     * Set the layout of the Radio group. Default is `Axis.Vertical`.
     */
    @prop var layout:Axis = Axis.Vertical;

    /**
     * Set the selected index.
     */
    @prop var selectedIndex:Null<Int> = null;

    /**
     * Set the disabled state.
     */
    @prop var disabled:Bool = false;

    var onClickHandler:Null<(Int, Window, App) -> Void> = null;

    /**
     * Creates a radio group with vertical layout and no selected item.
     */
    public function new(id:ElementIdArg) {
        super();
        this.id = id;
        new glaze.StyleBuilder(groupStyle).flex1();
    }

    /**
     * Create a new Radio group with default Vertical layout.
     */
    public static function vertical(id:ElementIdArg):RadioGroup {
        return RadioGroup.component(id);
    }

    /**
     * Create a new Radio group with Horizontal layout.
     */
    public static function horizontal(id:ElementIdArg):RadioGroup {
        return RadioGroup.component(id).layout(Axis.Horizontal);
    }

    public inline function style():StyleRefinement {
        return groupStyle;
    }

    /**
     * Alias for `onChange`. The last callback registered with either name wins.
     */
    public function onClick(handler:ValueListener<Int>):RadioGroup {
        return onChange(handler);
    }

    /**
     * Handle a requested selected index from pointer or keyboard activation.
     *
     * This is a controlled value: the owner must write the requested value to
     * render it. Disabled controls do not call the handler. Also written
     * `onChange(index -> ...)` or `onChange(() -> ...)` (`ValueListener`).
     */
    public function onChange(handler:ValueListener<Int>):RadioGroup {
        onClickHandler = handler;
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
        final disabled = this.disabled;
        final selectedIx = selectedIndex;

        final base = layout == Axis.Vertical ? vFlex() : hFlex().wFull().flexWrap();

        final total = radios.length;
        base.gap3();
        for (ix in 0...radios.length) {
            final radio = radios[ix];
            final checked = selectedIx == ix;

            radio.id = Integer(ix);
            radio.positionInSet = ix + 1;
            radio.sizeOfSet = total;
            final itemDisabled = radio.disabledProp;
            radio.disabled(disabled || itemDisabled).checked(checked);
            if (onClick != null) {
                radio.onClick((_, window, cx) -> onClick(ix, window, cx));
            }
            base.child(radio);
        }
        return glaze.kit.base.RadioGroup.component(id).axis(layout).refineStyle(groupStyle).child(base);
    }

}
