// Ported from gpui-kit 0.8.1: crates/base/src/otp_input.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.AnyElement;
import gpui.App;
import gpui.Context;
import gpui.ElementId;
import gpui.Empty;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.KeyDownEvent;
import gpui.Model;
import gpui.ParentElement;
import gpui.Render;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Subscription;
import gpui.Window;
import gpui.base.input.BlinkCursor;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * A semantic notification from a one-time-code state.
 */
enum OtpEvent {
    /** The value changed through keyboard editing. */
    Change;
    /** Keyboard editing filled the final cell. */
    Complete;
    Focus;
    Blur;
}

/**
 * Stateful input and focus behavior for a fixed-length numeric one-time code.
 *
 * Rust keeps the fields private behind `Focusable::focus_handle` and
 * accessors; `focusHandle` is a read-only field here, like on the input
 * states.
 */
class OtpState extends Model implements Render {

    public final focusHandle:FocusHandle;

    @observe var _value:String = "";

    final blinkCursor:Entity<BlinkCursor>;

    /**
     * The blink phase, mirrored from `blinkCursor` so that the views reading
     * `cursorVisible` re-render when it changes (Rust tracks the entities a
     * view reads; the port tracks observable fields).
     */
    @observe var _cursorVisible:Bool = false;

    @observe var _masked:Bool = false;

    final length:Int;

    final _subscriptions:Array<Subscription>;

    public function new(length:Int, window:Window, cx:Context<OtpState>) {
        super();
        final focusHandle = cx.focusHandle();
        final blinkCursor = cx.newEntity(cx -> new BlinkCursor(cx));
        this.focusHandle = focusHandle;
        this.blinkCursor = blinkCursor;
        this.length = length;
        _subscriptions = [
            cx.observe(blinkCursor, (this_, _, cx) -> {
                this_._cursorVisible = this_.blinkCursor.read(cx).visible();
                cx.notify();
            }),
            cx.observeWindowActivation(window, (this_, window, cx) -> {
                if (window.isWindowActive() && this_.focusHandle.isFocused(window)) {
                    this_.blinkCursor.update(cx, (cursor, cx) -> cursor.start(cx));
                }
            }),
            cx.onFocus(focusHandle, window, (this_, window, cx) -> this_.onFocus(window, cx)),
            cx.onBlur(focusHandle, window, (this_, window, cx) -> this_.onBlur(window, cx)),
        ];
    }

    public function defaultValue(value:String):OtpState {
        _value = value;
        return this;
    }

    public function setValue(value:String, window:Window, cx:Context<OtpState>):Void {
        _value = value;
        cx.notify();
    }

    public inline function value():String {
        return _value;
    }

    public inline function len():Int {
        return length;
    }

    public inline function isEmpty():Bool {
        return _value.length == 0;
    }

    public inline function isMasked():Bool {
        return _masked;
    }

    public function cursorVisible(cx:App):Bool {
        // Read the mirror too, so that a render depending on it re-renders.
        final _ = _cursorVisible;
        return blinkCursor.read(cx).visible();
    }

    /** Rust builder `masked(bool)` (the name is taken by the reader in Haxe). */
    public function withMasked(masked:Bool):OtpState {
        _masked = masked;
        return this;
    }

    public function setMasked(masked:Bool, window:Window, cx:Context<OtpState>):Void {
        _masked = masked;
        cx.notify();
    }

    public function focus(window:Window, cx:Context<OtpState>):Void {
        focusHandle.focus(window, cx.app);
    }

    static function toDigitChar(value:Int):Null<Int> {
        if (value >= "0".code && value <= "9".code) {
            return value;
        }
        final digit = value - 0xFF10; // '０'
        if (digit < 0 || digit > 9) {
            return null;
        }
        return "0".code + digit;
    }

    static function chars(value:String):Array<Int> {
        return [for (c in new haxe.iterators.StringIteratorUnicode(value)) c];
    }

    static function fromChars(chars:Array<Int>):String {
        final buf = new StringBuf();
        for (c in chars) buf.addChar(c);
        return buf.toString();
    }

    @:allow(tests)
    static function editValue(value:String, key:String, keyChar:Null<String>, length:Int):Null<String> {
        final chars = OtpState.chars(value);
        if (key == "backspace") {
            chars.pop();
        } else {
            final keyChars = OtpState.chars(key);
            var digit:Null<Int> = keyChars.length > 0 ? toDigitChar(keyChars[0]) : null;
            if (digit == null && keyChar != null) {
                final keyCharChars = OtpState.chars(keyChar);
                digit = keyCharChars.length > 0 ? toDigitChar(keyCharChars[0]) : null;
            }
            if (digit == null) {
                return null;
            }
            if (chars.length >= length) {
                return null;
            }
            chars.push(digit);
        }
        return fromChars(chars);
    }

    function onKeyDown(event:KeyDownEvent, window:Window, cx:Context<OtpState>):Void {
        final value = editValue(_value, event.keystroke.key, event.keystroke.keyChar, length);
        if (value == null) {
            return;
        }
        window.preventDefault();
        cx.stopPropagation();
        blinkCursor.update(cx, (cursor, cx) -> cursor.pause(cx));
        _value = value;
        cx.emit(OtpEvent.Change);
        if (OtpState.chars(_value).length == length) {
            cx.emit(OtpEvent.Complete);
        }
        cx.notify();
    }

    function onFocus(window:Window, cx:Context<OtpState>):Void {
        blinkCursor.update(cx, (cursor, cx) -> cursor.start(cx));
        cx.emit(OtpEvent.Focus);
    }

    function onBlur(window:Window, cx:Context<OtpState>):Void {
        blinkCursor.update(cx, (cursor, cx) -> cursor.stop(cx));
        cx.emit(OtpEvent.Blur);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new Empty();
    }

}

/**
 * Unstyled OTP interaction root. Applications provide the visual cells as children.
 */
class OtpInput implements RenderOnce implements Styled implements ParentElement {

    final state:Entity<OtpState>;

    var disabledValue:Bool = false;

    final otpStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new(state:Entity<OtpState>) {
        this.state = state;
    }

    public function disabled(disabled:Bool):OtpInput {
        disabledValue = disabled;
        return this;
    }

    public inline function style():StyleRefinement {
        return otpStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):OtpInput {
        childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):OtpInput {
        for (child in children) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final state = this.state;
        final element = div()
            .id(ElementId.NamedInteger("base-otp-input", state.entityId()))
            .trackFocus(state.read(cx).focusHandle);
        if (!disabledValue) {
            element.onKeyDown((event, window, cx) -> state.update(cx, (state, cx) -> @:privateAccess state.onKeyDown(event, window, cx)));
        }
        element.extend(childElements);
        return element.refineStyle(otpStyle);
    }

}
