// Ported from gpui-kit 0.8.1: crates/component/src/switch.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.switch_;

import glaze.App;
import glaze.kit.CheckedListener;
import glaze.Background;
import glaze.Component;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.IntoHsla;
import glaze.Pixels;
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
class Switch extends Component implements Styled implements Sizable implements Disableable implements FocusableExt {

    final id:ElementId;

    final switchStyle:StyleRefinement = new StyleRefinement();

    /**
     * Set the checked state of the switch.
     */
    @prop var checked:Bool = false;

    @prop var disabled:Bool = false;

    /**
     * Set the label of the switch.
     */
    @:allow(tests)
    @prop var label:Null<String> = null;

    /**
     * Set the name a screen reader announces, when the visible label is not
     * it. A switch without a label has no accessible name, so set this
     * whenever the switch is drawn without visible text.
     */
    @:allow(tests)
    @prop var accessibilityLabel:Null<String> = null;

    var labelSide:Side = Right;

    var onClickHandler:Null<(Bool, Window, App) -> Void> = null;

    var sizeValue:Size = Medium;

    @prop var color:Null<Hsla> = null;

    /**
     * Set tooltip text for the switch.
     */
    @prop var tooltip:Null<String> = null;

    /**
     * Overrides how long the pointer must rest before the tooltip shows, in seconds.
     */
    @prop var tooltipShowDelay:Null<Float> = null;

    /**
     * Set whether the switch participates in keyboard focus traversal,
     * default is true.
     */
    @prop var tabStop:Bool = true;

    /**
     * Set the focus traversal index within a GPUI tab group, default is 0.
     */
    @prop var tabIndex:Int = 0;

    @prop var focusRing:Bool = true;

    /**
     * Create a new Switch element.
     */
    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    public inline function style():StyleRefinement {
        return switchStyle;
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
        this.color = color;
        return this;
    }

    public function withSize(size:IntoSize):Switch {
        this.sizeValue = size;
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

    public function render(window:Window, cx:App):IntoElement {
        final size = sizeValue;
        final theme = Theme.global(cx);
        final checked = this.checked;
        final onClick = onClickHandler;
        final accessibilityLabel = this.accessibilityLabel != null ? this.accessibilityLabel : label;
        final focusHandle:FocusHandle = window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
        final isFocused = focusHandle.isFocused(window);

        final checkedBg:Background = color != null ? Background.fromHsla(color) : theme.tokens.primary.background;
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
            .disabled(disabled)
            .styles(styles -> styles.disabled(s -> s.textColor(disabledLabelColor).cursorNotAllowed()));
        if (accessibilityLabel != null) base.accessibilityLabel(accessibilityLabel);
        if (onClick != null) base.onChange((next, _, window, cx) -> onClick(next, window, cx));
        base.tabStop(tabStop).tabIndex(tabIndex).trackFocus(focusHandle);
        base.hFlex().gap2().itemsStart();
        if (labelSide.isLeft()) base.flexRowReverse();

        // Switch Bar
        final track = SwitchTrack.component(ElementId.NamedChild(id, 'track'))
            .checked(checked)
            .disabled(disabled)
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
        if (isFocused && focusRing) track.focusRingStyle(window, cx);
        ComponentTooltip.of(tooltip, tooltipShowDelay).apply(track, @:privateAccess track.base);
        // Switch Toggle
        track.child(SwitchThumb.component(checked).rounded(radius).size(barWidth).left(glaze.Prelude.px(thumbX)).bg(toggleBg));
        base.child(track);

        if (label != null) {
            final labelDiv = div().minW0().lineHeight(bgHeight).child(label);
            switch size {
                case Size(_): labelDiv.inputTextSize(Medium);
                case _: labelDiv.inputTextSize(size);
            }
            base.child(labelDiv);
        }

        return div().refineStyle(switchStyle).child(base);
    }

}
