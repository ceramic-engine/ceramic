// Ported from gpui-kit 0.8.1: crates/component/src/input/otp_input.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.input;

import gpui.AnyElement;
import gpui.App;
import gpui.ElementId;
import gpui.Entity;
import gpui.IntoElement;
import gpui.RenderOnce;
import gpui.Window;
import gpui.base.ComponentTraits;
import gpui.base.OtpInput.OtpState;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.Size.IntoSize;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

using gpui.component.StyleSized;
using gpui.component.ThemeStyled;

/**
 * A One Time Password (OTP) input element.
 *
 * This can accept a fixed length number and can be masked.
 *
 * Use case example:
 *
 * - SMS OTP
 * - Authenticator OTP
 *
 * `OtpEvent` and `OtpState` are gpui-base's (`gpui.base.OtpInput`),
 * re-exported by Rust.
 */
class OtpInput implements RenderOnce implements Sizable implements Disableable implements FocusableExt {

    final state:Entity<OtpState>;

    var numberOfGroups:Int = 2;

    var size:Size = Medium;

    var focusRingEnabled:Bool = true;

    var disabledValue:Bool = false;

    /** Create a new `OtpInput` element bind to the `OtpState`. */
    public function new(state:Entity<OtpState>) {
        this.state = state;
    }

    /** Set number of groups in the OTP Input. */
    public function groups(n:Int):OtpInput {
        numberOfGroups = n;
        return this;
    }

    @:allow(tests)
    static function resolvedGroups(length:Int, requested:Int):Int {
        final atLeastOne = requested > 1 ? requested : 1;
        final maxGroups = length > 1 ? length : 1;
        return atLeastOne < maxGroups ? atLeastOne : maxGroups;
    }

    public function disabled(disabled:Bool):OtpInput {
        disabledValue = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        disabledValue = disabled;
    }

    public function focusRing(enabled:Bool):OtpInput {
        focusRingEnabled = enabled;
        return this;
    }

    public function setFocusRing(enabled:Bool):Void {
        focusRingEnabled = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return focusRingEnabled;
    }

    public function withSize(size:IntoSize):OtpInput {
        this.size = size;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        @:privateAccess AnyInputState.syncFocusedInputRegistry(AnyInputState.otp(this.state), window, cx);
        final theme = Theme.global(cx);
        final state = this.state.read(cx);
        final blinkShow = state.cursorVisible(cx);
        final isFocused = state.focusHandle.isFocused(window);

        final chars = [for (c in new haxe.iterators.StringIteratorUnicode(state.value())) c];
        final lastIx = state.len() > 0 ? state.len() - 1 : 0;
        final cursorIx = chars.length < lastIx ? chars.length : lastIx;
        final numberOfGroups = resolvedGroups(state.len(), this.numberOfGroups);
        final groups:Array<Array<IntoElement>> = [];
        var groupIx = 0;
        final perGroup = Math.ceil(state.len() / numberOfGroups);
        final groupItemsCount = perGroup > 1 ? perGroup : 1;
        for (_ in 0...numberOfGroups) {
            groups.push([]);
        }

        final colors = @:privateAccess Input.inputStyleColors(disabledValue, cx);
        final bg = colors.background;
        final fg = colors.foreground;
        final entity = this.state;

        for (ix in 0...state.len()) {
            final c:Null<Int> = ix < chars.length ? chars[ix] : null;
            if (ix % groupItemsCount == 0 && ix != 0) {
                groupIx += 1;
            }

            final isInputFocused = ix == cursorIx && isFocused;
            final focusVisible = isInputFocused && !disabledValue && focusRingEnabled;

            final cell = hFlex()
                .id(ix)
                .border1()
                .borderColor(theme.input)
                .bg(bg)
                .textColor(fg);
            if (disabledValue) cell.opacity(0.5);
            if (focusVisible) cell.borderColor(theme.ring);
            cell.itemsCenter().justifyCenter().rounded(theme.radius);
            switch size {
                case Size(v): cell.textSize(px(v * 0.5));
                case _: cell.inputTextSize(size);
            }
            switch size {
                case XSmall: cell.w6().h6();
                case Small: cell.w6().h6();
                case Medium: cell.w8().h8();
                case Large: cell.w11().h11();
                case Size(v): cell.w(px(v)).h(px(v));
            }
            if (focusVisible) cell.focusRingStyle(window, cx);
            cell.onMouseDown(Left, (_, window, cx) -> entity.read(cx).focusHandle.focus(window, cx));
            if (c != null) {
                if (state.isMasked()) {
                    final icon = new Icon(IconName.Asterisk).textColor(theme.secondaryForeground);
                    if (disabledValue) icon.textColor(theme.mutedForeground);
                    cell.child(icon);
                } else {
                    final buf = new StringBuf();
                    buf.addChar(c);
                    cell.child(buf.toString());
                }
            } else {
                if (isInputFocused && blinkShow) {
                    cell.child(div().h4().w0().borderL3().borderColor(theme.caret));
                }
            }
            groups[groupIx].push(cell);
        }

        return new gpui.base.OtpInput(this.state)
            .disabled(disabledValue)
            .child(
                vFlex()
                    .id(ElementId.NamedInteger("otp-input", this.state.entityId()))
                    .itemsCenter()
                    .child(
                        hFlex().itemsCenter().gap5().children([for (inputs in groups) hFlex().itemsCenter().gap1().children(inputs)])
                    )
            );
    }

}
