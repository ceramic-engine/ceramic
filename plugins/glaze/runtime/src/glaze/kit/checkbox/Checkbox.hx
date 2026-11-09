// Ported from gpui-kit 0.8.1: crates/component/src/checkbox.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.checkbox;

import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.kit.CheckedListener;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.Pixels;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.Checkbox.CheckboxIndicator;
import glaze.kit.base.ComponentTraits;
import glaze.kit.base.motion.Motion;
import glaze.kit.base.motion.TransitionId;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import glaze.kit.tooltip.Tooltip.ComponentTooltip;

using glaze.kit.base.StyledExt;
using glaze.kit.StyleSized;
using glaze.kit.ThemeStyled;

/**
 * A Checkbox element.
 *
 * The label is a plain string (Rust `Text::String`; rich text views come
 * with the text module). The tooltip is a managed tooltip
 * (`glaze.kit.tooltip`).
 */
class Checkbox extends Component implements Styled implements ParentElement implements Sizable implements Disableable implements Selectable implements FocusableExt {

    final id:ElementId;

    /** The Base checkbox the component renders (interactive listeners go to `base.base`). */
    public final base:glaze.kit.base.Checkbox;

    @:allow(tests)
    final checkboxStyle:StyleRefinement = new StyleRefinement();

    /**
     * Set the label for the checkbox.
     */
    @:allow(tests)
    @prop var label:Null<String> = null;

    /**
     * Set the name a screen reader announces, overriding the visible label.
     *
     * This does not change the label drawn on screen. A checkbox without a
     * `label` or text children has no accessible name, so set this whenever
     * the checkbox is drawn without visible text.
     */
    @:allow(tests)
    @prop var accessibilityLabel:Null<String> = null;

    final childElements:Array<AnyElement> = [];

    /**
     * Set the checked state for the checkbox.
     */
    @:allow(tests)
    @prop var checked:Bool = false;

    @:allow(tests)
    @prop var disabled:Bool = false;

    var sizeValue:Size = Medium;

    /**
     * Set the tab stop for the checkbox, default is true.
     */
    @prop var tabStop:Bool = true;

    /**
     * Set the tab index for the checkbox, default is 0.
     */
    @prop var tabIndex:Int = 0;

    var onClickHandler:Null<(Bool, Window, App) -> Void> = null;

    /**
     * Set tooltip text for the checkbox.
     */
    @prop var tooltip:Null<String> = null;

    /**
     * Overrides how long the pointer must rest before the tooltip shows, in seconds.
     */
    @prop var tooltipShowDelay:Null<Float> = null;

    @prop var role:RoleOverride = Implicit;

    @prop var focusRing:Bool = true;

    /**
     * Create a new Checkbox with the given id.
     */
    public function new(id:ElementIdArg) {
        super();
        this.id = id;
        this.base = glaze.kit.base.Checkbox.component(id);
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
     * Alias for `onChange`. The last callback registered with either name wins.
     */
    public function onClick(handler:CheckedListener):Checkbox {
        return onChange(handler);
    }

    /**
     * Handle a requested checked value from pointer or keyboard activation.
     *
     * This is a controlled value: the owner must write the requested value to
     * render it. Disabled controls do not call the handler. This and `onClick`
     * share one callback; chaining them replaces the previous handler instead
     * of calling both. Also written `onChange(v -> ...)` or
     * `onChange(() -> ...)` (`CheckedListener`).
     */
    public function onChange(handler:CheckedListener):Checkbox {
        onClickHandler = handler;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        this.disabled = disabled;
    }

    public function setFocusRing(enabled:Bool):Void {
        focusRing = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return focusRing;
    }

    public function selected(selected:Bool):Checkbox {
        this.checked = selected;
        return this;
    }

    public function setSelected(selected:Bool):Void {
        checked = selected;
    }

    public function isSelected():Bool {
        return checked;
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
    @:allow(glaze.kit)
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
        final checked = this.checked;
        final hasContent = label != null || childElements.length > 0;
        final indicatorSize = switch size {
            case XSmall: 0.75;
            case Small: 0.875;
            case Large: 1.125;
            case _: 1.;
        }

        final base = this.base;
        final children = childElements;
        final accessibilityLabel = this.accessibilityLabel != null ? this.accessibilityLabel : label;
        final onClick = onClickHandler;
        final focusHandle:FocusHandle = window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
        final isFocused = focusHandle.isFocused(window);

        final uncheckedBorder = theme.input;
        final checkedColor = theme.primary;
        final disabledIndicatorColor = checked ? checkedColor.opacity(0.5) : uncheckedBorder.opacity(0.5);
        final radius:Pixels = Math.min(theme.radius, 4.);
        final disabledTextColor = theme.mutedForeground;
        final instanceStyle = checkboxStyle.clone();
        base.role(role)
            .checked(checked)
            .disabled(disabled)
            .styles(styles -> styles.disabled(s -> s.textColor(disabledTextColor).refineStyle(instanceStyle)))
            .tabStop(tabStop)
            .tabIndex(tabIndex)
            .trackFocus(focusHandle);
        if (accessibilityLabel != null) base.accessibilityLabel(accessibilityLabel);
        if (onClick != null) {
            base.onChange((_, _, window, cx) -> {
                window.preventDefault();
                onClick(!checked, window, cx);
            });
        }
        base.hFlex().gap2().itemsStart().lineHeight(glaze.Prelude.relative(1.)).textColor(theme.foreground);
        switch size {
            case Size(_):
            case _: base.inputTextSize(size);
        }
        base.rounded(theme.radius * 0.5);
        if (isFocused && focusRing) {
            base.focusRingStyle(window, cx);
        }
        base.refineStyle(checkboxStyle);

        final indicator = CheckboxIndicator.component()
            .checked(checked)
            .disabled(disabled)
            .relative()
            .size(rems(indicatorSize));
        // Center on the first 1.25em line, including when the label wraps.
        if (hasContent) indicator.mt(rems(indicatorSize * 0.125));
        indicator.flexShrink0().border1().rounded(radius);
        if (!checked) {
            indicator.bg(theme.inputBackground());
            if (!disabled) indicator.borderColor(uncheckedBorder);
        }
        indicator.styles(styles -> styles
            .checked(s -> s.borderColor(checkedColor).bg(theme.tokens.primary.background))
            .disabled(s -> s.borderColor(disabledIndicatorColor).when(checked, s -> s.bg(disabledIndicatorColor))))
            .child(checkboxCheckIcon(id, size, checked, disabled, window, cx));
        base.child(indicator);

        if (label != null || children.length > 0) {
            final column = vFlex().flex1().overflowHidden().lineHeight(glaze.Prelude.relative(1.25)).gap1();
            if (label != null) {
                final labelDiv = div().sizeFull().textColor(theme.foreground);
                if (disabled) labelDiv.textColor(theme.mutedForeground);
                column.child(labelDiv.child(label));
            }
            for (child in children) column.child(child);
            base.child(column);
        }
        // Preserve the legacy Checkbox behavior: pointer presses do not move
        // focus, including while disabled.
        base.onMouseDown(Left, (_, window, _) -> window.preventDefault());
        return ComponentTooltip.of(tooltip, tooltipShowDelay).apply(base, base.base);
    }

}
