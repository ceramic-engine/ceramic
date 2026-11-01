// Ported from gpui-kit 0.8.1: crates/component/src/checkbox.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.checkbox;

import gpui.AnyElement;
import gpui.App;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.Pixels;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.Checkbox.CheckboxIndicator;
import gpui.base.ComponentTraits;
import gpui.base.motion.Motion;
import gpui.base.motion.TransitionId;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.Size.IntoSize;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import gpui.component.tooltip.Tooltip.ComponentTooltip;

using gpui.base.StyledExt;
using gpui.component.StyleSized;
using gpui.component.ThemeStyled;

/**
 * A Checkbox element.
 *
 * The label is a plain string (Rust `Text::String`; rich text views come
 * with the text module). The tooltip is a managed tooltip
 * (`gpui.component.tooltip`).
 */
class Checkbox implements RenderOnce implements Styled implements ParentElement implements Sizable implements Disableable implements Selectable implements FocusableExt {

    final id:ElementId;

    /** The Base checkbox the component renders (interactive listeners go to `base.base`). */
    public final base:gpui.base.Checkbox;

    @:allow(tests)
    final checkboxStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var labelValue:Null<String> = null;

    @:allow(tests)
    var accessibilityLabelValue:Null<String> = null;

    final childElements:Array<AnyElement> = [];

    @:allow(tests)
    var checkedValue:Bool = false;

    @:allow(tests)
    var disabledValue:Bool = false;

    var sizeValue:Size = Medium;

    var tabStopValue:Bool = true;

    var tabIndexValue:Int = 0;

    var onClickHandler:Null<(Bool, Window, App) -> Void> = null;

    var tooltipText:Null<String> = null;

    var tooltipShowDelayValue:Null<Float> = null;

    var roleValue:RoleOverride = Implicit;

    var focusRingEnabled:Bool = true;

    /**
     * Create a new Checkbox with the given id.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
        this.base = new gpui.base.Checkbox(id);
    }

    public inline function style():StyleRefinement {
        return checkboxStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Checkbox {
        childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Checkbox {
        for (child in children) childElements.push(child);
        return this;
    }

    public function role(role:RoleOverride):Checkbox {
        roleValue = role;
        return this;
    }

    /**
     * Set tooltip text for the checkbox.
     */
    public function tooltip(tooltip:String):Checkbox {
        tooltipText = tooltip;
        return this;
    }

    /**
     * Overrides how long the pointer must rest before the tooltip shows, in seconds.
     */
    public function tooltipShowDelay(delay:Float):Checkbox {
        tooltipShowDelayValue = delay;
        return this;
    }

    /**
     * Set the label for the checkbox.
     */
    public function label(label:String):Checkbox {
        labelValue = label;
        return this;
    }

    /**
     * Set the name a screen reader announces, overriding the visible label.
     *
     * This does not change the label drawn on screen. A checkbox without a
     * `label` or text children has no accessible name, so set this whenever
     * the checkbox is drawn without visible text.
     */
    public function accessibilityLabel(label:String):Checkbox {
        accessibilityLabelValue = label;
        return this;
    }

    /**
     * Set the checked state for the checkbox.
     */
    public function checked(checked:Bool):Checkbox {
        checkedValue = checked;
        return this;
    }

    /**
     * Alias for `onChange`. The last callback registered with either name wins.
     */
    public function onClick(handler:(Bool, Window, App) -> Void):Checkbox {
        return onChange(handler);
    }

    /**
     * Handle a requested checked value from pointer or keyboard activation.
     *
     * This is a controlled value: the owner must write the requested value to
     * render it. Disabled controls do not call the handler. This and `onClick`
     * share one callback; chaining them replaces the previous handler instead
     * of calling both.
     */
    public function onChange(handler:(Bool, Window, App) -> Void):Checkbox {
        onClickHandler = handler;
        return this;
    }

    /**
     * Set the tab stop for the checkbox, default is true.
     */
    public function tabStop(tabStop:Bool):Checkbox {
        tabStopValue = tabStop;
        return this;
    }

    /**
     * Set the tab index for the checkbox, default is 0.
     */
    public function tabIndex(tabIndex:Int):Checkbox {
        tabIndexValue = tabIndex;
        return this;
    }

    public function disabled(disabled:Bool):Checkbox {
        disabledValue = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        disabledValue = disabled;
    }

    public function focusRing(enabled:Bool):Checkbox {
        focusRingEnabled = enabled;
        return this;
    }

    public function setFocusRing(enabled:Bool):Void {
        focusRingEnabled = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return focusRingEnabled;
    }

    public function selected(selected:Bool):Checkbox {
        return checked(selected);
    }

    public function setSelected(selected:Bool):Void {
        checkedValue = selected;
    }

    public function isSelected():Bool {
        return checkedValue;
    }

    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    public function isOpen():Bool {
        return isSelected();
    }

    public function withSize(size:IntoSize):Checkbox {
        this.sizeValue = size;
        return this;
    }

    /**
     * The check mark of a checkbox or a radio: an icon fading in and out
     * with the theme's control spring.
     */
    @:allow(gpui.component)
    static function checkboxCheckIcon(id:ElementId, size:Size, checked:Bool, disabled:Bool, window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        // The mark keeps its path while the spring is still fading it out. Guarding
        // the path on `checked` alone unmounted the glyph the moment the box was
        // cleared, so only the fade-in was ever visible.
        final opacity = Motion.spring(TransitionId.named(id, 'mark'), checked ? 1. : 0., theme.motionTokens().springControl, window, cx);
        final color = disabled ? theme.primaryForeground.opacity(0.5) : theme.primaryForeground;

        final mark = svg().absolute().topPx().leftPx();
        switch size {
            case XSmall: mark.size2();
            case Small: mark.size2p5();
            case Medium: mark.size3();
            case Large: mark.size3p5();
            case _: mark.size3();
        }
        mark.textColor(color);
        if (opacity > 0.) {
            mark.path(Icon.resolveIconPath(IconName.Check.path(), cx)).opacity(opacity);
        }
        return mark;
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

        final base = this.base;
        final children = childElements;
        final accessibilityLabel = accessibilityLabelValue != null ? accessibilityLabelValue : labelValue;
        final onClick = onClickHandler;
        final focusHandle:FocusHandle = window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
        final isFocused = focusHandle.isFocused(window);

        final uncheckedBorder = theme.input;
        final checkedColor = theme.primary;
        final disabledIndicatorColor = checked ? checkedColor.opacity(0.5) : uncheckedBorder.opacity(0.5);
        final radius:Pixels = Math.min(theme.radius, 4.);
        final disabledTextColor = theme.mutedForeground;
        final instanceStyle = checkboxStyle.clone();
        base.role(roleValue)
            .checked(checked)
            .disabled(disabledValue)
            .styles(styles -> styles.disabled(s -> s.textColor(disabledTextColor).refineStyle(instanceStyle)))
            .tabStop(tabStopValue)
            .tabIndex(tabIndexValue)
            .trackFocus(focusHandle);
        if (accessibilityLabel != null) base.accessibilityLabel(accessibilityLabel);
        if (onClick != null) {
            base.onChange((_, _, window, cx) -> {
                window.preventDefault();
                onClick(!checked, window, cx);
            });
        }
        base.hFlex().gap2().itemsStart().lineHeight(gpui.Prelude.relative(1.)).textColor(theme.foreground);
        switch size {
            case Size(_):
            case _: base.inputTextSize(size);
        }
        base.rounded(theme.radius * 0.5);
        if (isFocused && focusRingEnabled) {
            base.focusRingStyle(window, cx);
        }
        base.refineStyle(checkboxStyle);

        final indicator = new CheckboxIndicator()
            .checked(checked)
            .disabled(disabledValue)
            .relative()
            .size(rems(indicatorSize));
        // Center on the first 1.25em line, including when the label wraps.
        if (hasContent) indicator.mt(rems(indicatorSize * 0.125));
        indicator.flexShrink0().border1().rounded(radius);
        if (!checked) {
            indicator.bg(theme.inputBackground());
            if (!disabledValue) indicator.borderColor(uncheckedBorder);
        }
        indicator.styles(styles -> styles
            .checked(s -> s.borderColor(checkedColor).bg(theme.tokens.primary.background))
            .disabled(s -> s.borderColor(disabledIndicatorColor).when(checked, s -> s.bg(disabledIndicatorColor))))
            .child(checkboxCheckIcon(id, size, checked, disabledValue, window, cx));
        base.child(indicator);

        if (labelValue != null || children.length > 0) {
            final column = vFlex().flex1().overflowHidden().lineHeight(gpui.Prelude.relative(1.25)).gap1();
            if (labelValue != null) {
                final labelDiv = div().sizeFull().textColor(theme.foreground);
                if (disabledValue) labelDiv.textColor(theme.mutedForeground);
                column.child(labelDiv.child(labelValue));
            }
            for (child in children) column.child(child);
            base.child(column);
        }
        // Preserve the legacy Checkbox behavior: pointer presses do not move
        // focus, including while disabled.
        base.onMouseDown(Left, (_, window, _) -> window.preventDefault());
        return ComponentTooltip.of(tooltipText, tooltipShowDelayValue).apply(base, base.base);
    }

}
