// Ported from gpui-kit 0.8.1: crates/component/src/input/number_input.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified: deliberate deviation DEV-007 (the placeholder is used). See DEVIATIONS.md.
package gpui.component.input;

import gpui.AnyElement;
import gpui.App;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.ComponentTraits;
import gpui.base.input.InputState;
import gpui.component.I18n;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.Size.IntoSize;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.base.StyledExt;
using gpui.component.StyleSized;
using gpui.component.ThemeStyled;

/**
 * A number input element with increment and decrement buttons.
 *
 * `NumberInputEvent`, `NumberStep` and `StepAction` are gpui-base's
 * (`gpui.base.NumberInput.NumberInputEvent`, `gpui.base.NumberStep`,
 * `gpui.base.StepAction`), re-exported by Rust.
 */
class NumberInput implements RenderOnce implements Styled implements Sizable implements Disableable implements FocusableExt {

    final state:Entity<InputState>;

    // Passed to the input state when rendering (deliberate deviation DEV-007:
    // the original stored it but never used it).
    var placeholderValue:String = "";

    var size:Size = Medium;

    var prefixElement:Null<AnyElement> = null;

    var suffixElement:Null<AnyElement> = null;

    var appearanceValue:Bool = true;

    var focusRingEnabled:Bool = true;

    var disabledValue:Bool = false;

    var accessibilityLabelValue:Null<String> = null;

    final numberStyle:StyleRefinement = new StyleRefinement();

    /** Create a new `NumberInput` element bind to the `InputState`. */
    public function new(state:Entity<InputState>) {
        this.state = state;
    }

    /** Set the placeholder text of the number input. */
    public function placeholder(placeholder:String):NumberInput {
        placeholderValue = placeholder;
        return this;
    }

    /** Set the prefix element of the number input. */
    public function prefix(prefix:IntoElement):NumberInput {
        prefixElement = prefix;
        return this;
    }

    /** Set the suffix element of the number input. */
    public function suffix(suffix:IntoElement):NumberInput {
        suffixElement = suffix;
        return this;
    }

    /** Set the appearance of the number input, if false will no border and background. */
    public function appearance(appearance:Bool):NumberInput {
        appearanceValue = appearance;
        return this;
    }

    /**
     * Set the name a screen reader announces.
     *
     * A number input has no visible text of its own to be named by, so set
     * this whenever it is shown without one, for example next to a separate
     * label. This does not change what is displayed.
     */
    public function accessibilityLabel(label:String):NumberInput {
        accessibilityLabelValue = label;
        return this;
    }

    public function disabled(disabled:Bool):NumberInput {
        disabledValue = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        disabledValue = disabled;
    }

    public function focusRing(enabled:Bool):NumberInput {
        focusRingEnabled = enabled;
        return this;
    }

    public function setFocusRing(enabled:Bool):Void {
        focusRingEnabled = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return focusRingEnabled;
    }

    /** Rust `Focusable::focus_handle`. */
    public function focusHandle(cx:App):FocusHandle {
        return state.read(cx).focusHandle;
    }

    public function withSize(size:IntoSize):NumberInput {
        this.size = size;
        return this;
    }

    public inline function style():StyleRefinement {
        return numberStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final focused = state.read(cx).focusHandle.isFocused(window) && !disabledValue;
        final bg = @:privateAccess Input.inputStyleColors(disabledValue, cx).background;
        final borderColor = disabledValue ? theme.input.opacity(0.5) : theme.input;
        // Transparent like a ghost button, but tinted to the frame on hover.
        final buttonForeground = theme.secondaryForeground;
        final buttonHover = theme.input.opacity(0.4);
        final buttonActive = theme.input.opacity(0.6);
        final buttonSize = size;
        // The buttons sit inside the 1px frame, so their corners are a pixel
        // tighter than the frame's, or they paint over its inner curve.
        final buttonRadius:gpui.Pixels = appearanceValue ? Math.max(theme.radius - 1., 0.) : theme.radius;
        // Deliberate deviation DEV-007: the original never used the
        // placeholder. Pass it to the input state, only when it is set and
        // differs (`setPlaceholder` notifies).
        if (placeholderValue != "" && state.read(cx).presentation().placeholder() != placeholderValue) {
            final placeholder = placeholderValue;
            (cast state : Entity<gpui.base.input.InputBaseState>).update(cx, (input, cx) -> input.setPlaceholder(placeholder, window, cx));
        }
        final baseState = state;
        final content = new gpui.base.NumberInput(baseState).disabled(disabledValue);
        if (accessibilityLabelValue != null) content.accessibilityLabel(accessibilityLabelValue);
        content.sizeFull();
        content.decrementButton(button -> {
            button.accessibilityLabel(I18n.t("Input.Decrement"))
                .flex()
                .itemsCenter()
                .justifyCenter()
                .textColor(buttonForeground);
            button.hover(s -> s.bg(buttonHover)).active(s -> s.bg(buttonActive));
            // The frame owns the control height, so the buttons fill it
            // rather than setting their own and outgrowing the border.
            button.hFull();
            switch buttonSize {
                case XSmall | Small: button.minW6();
                case Medium | Large: button.minW8();
                case Size(size): button.minW(size);
            }
            // Only the outer corners are rounded, to follow the frame.
            return button.roundedTl(buttonRadius).roundedBl(buttonRadius).child(new Icon(IconName.Minus).withSize(buttonSize));
        });
        final input = new Input(state).appearance(false).withSize(buttonSize).hFull().disabled(disabledValue);
        input.gap0().roundedNone().textAlign(gpui.TextAlign.Center);
        if (prefixElement != null) input.prefix(prefixElement);
        if (suffixElement != null) input.suffix(suffixElement);
        content.input(input);
        content.incrementButton(button -> {
            button.accessibilityLabel(I18n.t("Input.Increment"))
                .flex()
                .itemsCenter()
                .justifyCenter()
                .textColor(buttonForeground);
            button.hover(s -> s.bg(buttonHover)).active(s -> s.bg(buttonActive));
            button.hFull();
            switch buttonSize {
                case XSmall | Small: button.minW6();
                case Medium | Large: button.minW8();
                case Size(size): button.minW(size);
            }
            return button.roundedTr(buttonRadius).roundedBr(buttonRadius).child(new Icon(IconName.Plus).withSize(buttonSize));
        });

        // The visual frame wraps the complete spinbutton. BaseNumberInput routes
        // application children into its text slot, so putting the ring on that
        // element would incorrectly surround only the editable middle region.
        final frame = div().flex1().inputH(size).rounded(theme.radius);
        if (appearanceValue) {
            frame.bg(bg).border1().borderColor(borderColor);
            if (focused) frame.border1().borderColor(theme.ring);
        }
        frame.refineStyle(numberStyle);
        if (disabledValue) frame.opacity(0.5);
        frame.child(content);
        if (focused && appearanceValue && focusRingEnabled) frame.focusRingStyle(window, cx);
        return frame;
    }

}
