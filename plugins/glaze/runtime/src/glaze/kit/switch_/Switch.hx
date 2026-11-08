// Ported from gpui-kit 0.8.1: crates/component/src/switch.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.switch_;

import glaze.App;
import glaze.kit.CheckedListener;
import glaze.Background;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.IntoHsla;
import glaze.Pixels;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits;
import glaze.kit.base.Geometry.Side;
import glaze.kit.base.Switch.SwitchThumb;
import glaze.kit.base.Switch.SwitchTrack;
import glaze.kit.base.motion.Motion;
import glaze.kit.base.motion.TransitionId;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.tooltip.Tooltip.ComponentTooltip;

using glaze.kit.base.StyledExt;
using glaze.kit.StyleSized;
using glaze.kit.ThemeStyled;

/**
 * A Switch element that can be toggled on or off.
 *
 * The package is `switch_` because `switch` is a Haxe keyword. The label is
 * a plain string (Rust `Text::String`). The tooltip is a managed tooltip on
 * the track (`glaze.kit.tooltip`).
 */
class Switch implements RenderOnce implements Styled implements Sizable implements Disableable implements FocusableExt {

    final id:ElementId;

    final switchStyle:StyleRefinement = new StyleRefinement();

    var checkedValue:Bool = false;

    var disabledValue:Bool = false;

    @:allow(tests)
    var labelValue:Null<String> = null;

    /** The announced name, when the visible label is not it. */
    @:allow(tests)
    var accessibilityLabelValue:Null<String> = null;

    var labelSide:Side = Right;

    var onClickHandler:Null<(Bool, Window, App) -> Void> = null;

    var sizeValue:Size = Medium;

    var colorValue:Null<Hsla> = null;

    var tooltipText:Null<String> = null;

    var tooltipShowDelayValue:Null<Float> = null;

    var tabStopValue:Bool = true;

    var tabIndexValue:Int = 0;

    var focusRingEnabled:Bool = true;

    /**
     * Create a new Switch element.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return switchStyle;
    }

    /**
     * Set the checked state of the switch.
     */
    public function checked(checked:Bool):Switch {
        checkedValue = checked;
        return this;
    }

    /**
     * Set the label of the switch.
     */
    public function label(label:String):Switch {
        labelValue = label;
        return this;
    }

    /**
     * Set the name a screen reader announces, when the visible label is not
     * it. A switch without a label has no accessible name, so set this
     * whenever the switch is drawn without visible text.
     */
    public function accessibilityLabel(label:String):Switch {
        accessibilityLabelValue = label;
        return this;
    }

    /**
     * Alias for `onChange`. The last callback registered with either name wins.
     */
    public function onClick(handler:CheckedListener):Switch {
        return onChange(handler);
    }

    /**
     * Handle a requested checked value from pointer or keyboard activation.
     *
     * This is a controlled value: the owner must write the requested value to
     * render it. Disabled controls do not call the handler. Also written
     * `onChange(on -> ...)` or `onChange(() -> ...)` (`CheckedListener`).
     */
    public function onChange(handler:CheckedListener):Switch {
        onClickHandler = handler;
        return this;
    }

    /**
     * Set the background color of the switch when checked.
     * Defaults to the theme's primary color.
     */
    public function color(color:IntoHsla):Switch {
        colorValue = color;
        return this;
    }

    /**
     * Set tooltip text for the switch.
     */
    public function tooltip(tooltip:String):Switch {
        tooltipText = tooltip;
        return this;
    }

    /**
     * Overrides how long the pointer must rest before the tooltip shows, in seconds.
     */
    public function tooltipShowDelay(delay:Float):Switch {
        tooltipShowDelayValue = delay;
        return this;
    }

    /**
     * Set whether the switch participates in keyboard focus traversal,
     * default is true.
     */
    public function tabStop(tabStop:Bool):Switch {
        tabStopValue = tabStop;
        return this;
    }

    /**
     * Set the focus traversal index within a GPUI tab group, default is 0.
     */
    public function tabIndex(tabIndex:Int):Switch {
        tabIndexValue = tabIndex;
        return this;
    }

    public function withSize(size:IntoSize):Switch {
        this.sizeValue = size;
        return this;
    }

    public function disabled(disabled:Bool):Switch {
        disabledValue = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        disabledValue = disabled;
    }

    public function focusRing(enabled:Bool):Switch {
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
        final onClick = onClickHandler;
        final accessibilityLabel = accessibilityLabelValue != null ? accessibilityLabelValue : labelValue;
        final focusHandle:FocusHandle = window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
        final isFocused = focusHandle.isFocused(window);

        final checkedBg:Background = colorValue != null ? Background.fromHsla(colorValue) : theme.tokens.primary.background;
        final uncheckedBg:Background = theme.tokens.switch_.background;
        // GPUI's element opacity multiplies each primitive's alpha instead of
        // compositing the subtree as one group, so fading the whole control
        // would let the track show through the thumb. Fading the track alone
        // lands on the pixels a grouped fade would: the thumb is `background`.
        final disabledBg = (checked ? checkedBg : uncheckedBg).opacity(0.5);
        final toggleBg:Background = theme.tokens.switchThumb.background;
        final disabledLabelColor = theme.mutedForeground;

        final bgWidth:Pixels = switch size {
            case XSmall | Small: 28.;
            case Large: 44.;
            case _: 36.;
        }
        final bgHeight:Pixels = switch size {
            case XSmall | Small: 16.;
            case Large: 24.;
            case _: 20.;
        }
        final barWidth:Pixels = switch size {
            case XSmall | Small: 12.;
            case Large: 20.;
            case _: 16.;
        }
        final inset:Pixels = 2.;
        final radius:Pixels = theme.radius >= 4. ? bgHeight : theme.radius;

        // The thumb's position is geometry, not a semantic state style: a
        // `checked` style setting `left` outranks the instance style by the
        // documented precedence, which left the travel visible in one direction
        // only. The spring owns it end to end and reverses from wherever the
        // thumb is when the switch is toggled again mid-travel.
        final thumbX = Motion.spring(TransitionId.named(id, 'thumb'), checked ? bgWidth - barWidth - inset * 2 : 0., theme.motionTokens().springMove, window, cx);

        final base = glaze.kit.base.Switch.component(id)
            .checked(checked)
            .disabled(disabledValue)
            .styles(styles -> styles.disabled(s -> s.textColor(disabledLabelColor).cursorNotAllowed()));
        if (accessibilityLabel != null) base.accessibilityLabel(accessibilityLabel);
        if (onClick != null) base.onChange((next, _, window, cx) -> onClick(next, window, cx));
        base.tabStop(tabStopValue).tabIndex(tabIndexValue).trackFocus(focusHandle);
        base.hFlex().gap2().itemsStart();
        if (labelSide.isLeft()) base.flexRowReverse();

        // Switch Bar
        final track = SwitchTrack.component(ElementId.NamedChild(id, 'track'))
            .checked(checked)
            .disabled(disabledValue)
            .w(bgWidth)
            .h(bgHeight)
            .flexShrink0()
            .rounded(radius)
            .flex()
            .itemsCenter()
            // The thumb inset is a 1px border plus 1px padding, not a 2px
            // border: the focus ring tints the border solid, and that 1px line
            // is what keeps the ring visible on an unchecked track. Its 50%
            // halo alone lands within a few values of `switch.background` in
            // both default modes.
            .border1()
            .borderColor(theme.transparent)
            .p(glaze.Prelude.px(inset - 1.));
        if (!checked) track.bg(uncheckedBg);
        track.styles(styles -> styles.checked(s -> s.bg(checkedBg)).disabled(s -> s.bg(disabledBg)));
        // The ring hugs the track, not the row, so the label stays outside it.
        if (isFocused && focusRingEnabled) track.focusRingStyle(window, cx);
        ComponentTooltip.of(tooltipText, tooltipShowDelayValue).apply(track, @:privateAccess track.base);
        // Switch Toggle
        track.child(SwitchThumb.component(checked).rounded(radius).size(barWidth).left(glaze.Prelude.px(thumbX)).bg(toggleBg));
        base.child(track);

        if (labelValue != null) {
            final labelDiv = div().minW0().lineHeight(bgHeight).child(labelValue);
            switch size {
                case Size(_): labelDiv.inputTextSize(Medium);
                case _: labelDiv.inputTextSize(size);
            }
            base.child(labelDiv);
        }

        return div().refineStyle(switchStyle).child(base);
    }

}
