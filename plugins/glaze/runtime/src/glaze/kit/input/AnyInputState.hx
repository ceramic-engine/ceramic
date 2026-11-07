// Ported from gpui-kit 0.8.1: crates/component/src/input/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.input;

import glaze.App;
import glaze.Bounds;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Window;
import glaze.kit.base.OtpInput.OtpState;
import glaze.kit.base.input.EditorState;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputState;
import glaze.kit.base.input.TextareaState;
import glaze.kit.WindowState;

/**
 * Any input-like state, regardless of which input element renders it.
 *
 * `InputState`, `TextareaState`, `EditorState` and `OtpState` are separate
 * types, so an API that refers to "whatever input is here" takes this type
 * instead of one of them. `WindowExt.focusedInput` returns it.
 *
 * Use `asInput` and friends to get the concrete state back, or `value` and
 * `focusHandle` when the kind does not matter. Compare with `equals` (Rust
 * `PartialEq`: the same entity).
 *
 * Rust is an enum with the variants `Input`, `Textarea`, `Editor` and `Otp`.
 * A Haxe enum would import constructors named like the `Input` and
 * `Textarea` elements wherever the type is imported, so this is a class:
 * `kind` is the variant (`InputKind`, `TextareaKind`, `EditorKind`, `OtpKind`), `AnyInputState.input(state)` (and `textarea`,
 * `editor`, `otp`) builds one.
 */
class AnyInputState {

    public final kind:AnyInputStateKind;

    final model:glaze.Model;

    function new(kind:AnyInputStateKind, model:glaze.Model) {
        this.kind = kind;
        this.model = model;
    }

    /** A single-line `Input` state. */
    public static function input(state:Entity<InputState>):AnyInputState {
        return new AnyInputState(InputKind, state);
    }

    /** A multi-line `Textarea` state. */
    public static function textarea(state:Entity<TextareaState>):AnyInputState {
        return new AnyInputState(TextareaKind, state);
    }

    /** A source-code `Editor` state. */
    public static function editor(state:Entity<EditorState>):AnyInputState {
        return new AnyInputState(EditorKind, state);
    }

    /** A one-time-code `OtpInput` state. */
    public static function otp(state:Entity<OtpState>):AnyInputState {
        return new AnyInputState(OtpKind, state);
    }

    /** Rust `impl From<Entity<..>> for AnyInputState`, by the state's mode. */
    public static function fromBase(state:Entity<InputBaseState>):AnyInputState {
        final model:InputBaseState = state;
        if (Std.isOfType(model, InputState)) return new AnyInputState(InputKind, model);
        if (Std.isOfType(model, TextareaState)) return new AnyInputState(TextareaKind, model);
        return new AnyInputState(EditorKind, model);
    }

    /** Rust `PartialEq`: the same kind and the same entity. */
    public function equals(other:Null<AnyInputState>):Bool {
        return other != null && kind == other.kind && model == other.model;
    }

    /** The engine of an input, textarea or editor state; null for an OTP state. */
    inline function base():Null<InputBaseState> {
        return kind == OtpKind ? null : cast model;
    }

    @:allow(glaze.kit)
    function inputBounds(cx:App):Null<Bounds> {
        final state = base();
        return state != null ? state.inputBounds : null;
    }

    @:allow(glaze.kit)
    function setSelectionFocus(focus:Null<FocusHandle>, cx:App):Void {
        final state = base();
        if (state != null) {
            (state : Entity<InputBaseState>).update(cx, (state, cx) -> state.setSelectionFocus(focus, cx));
        }
    }

    /** Returns the `InputState`, if this is an `Input` state. */
    public function asInput():Null<Entity<InputState>> {
        return kind == InputKind ? (cast model : InputState) : null;
    }

    /** Returns the `TextareaState`, if this is a `Textarea` state. */
    public function asTextarea():Null<Entity<TextareaState>> {
        return kind == TextareaKind ? (cast model : TextareaState) : null;
    }

    /** Returns the `EditorState`, if this is an `Editor` state. */
    public function asEditor():Null<Entity<EditorState>> {
        return kind == EditorKind ? (cast model : EditorState) : null;
    }

    /** Returns the `OtpState`, if this is an `OtpInput` state. */
    public function asOtp():Null<Entity<OtpState>> {
        return kind == OtpKind ? (cast model : OtpState) : null;
    }

    /**
     * Returns the value of the input.
     *
     * A masked input returns its masked value, the same as what is rendered.
     */
    public function value(cx:App):String {
        final state = base();
        return state != null ? state.value() : (cast model : OtpState).value();
    }

    /** Returns the focus handle of the input. */
    public function focusHandle(cx:App):FocusHandle {
        final state = base();
        return state != null ? state.focusHandle : (cast model : OtpState).focusHandle;
    }

    public function toString():String {
        return 'AnyInputState.$kind(${model.entityId})';
    }

    /**
     * Registers `state` as the window's focused input while it holds focus,
     * and unregisters it once focus moves elsewhere (Rust
     * `sync_focused_input_registry`).
     */
    @:allow(glaze.kit)
    static function syncFocusedInputRegistry(state:AnyInputState, window:Window, cx:App):Void {
        final focused = state.focusHandle(cx).isFocused(window);
        // Every input syncs as it renders; only one that gains or loses focus
        // changes the registry, and notifying the window state otherwise would
        // draw the whole window again on every frame an input renders in.
        final root = WindowState.tryRead(window);
        if (root != null) {
            final registered = state.equals((root : WindowState).focusedInput);
            if (registered == focused) {
                return;
            }
        }
        WindowState.tryUpdate(window, cx, (root, _, cx) -> {
            if (focused) {
                root.focusedInput = state;
            } else if (state.equals(root.focusedInput)) {
                root.focusedInput = null;
            }
            cx.notify();
            return null;
        });
    }

}

/**
 * The variant of an `AnyInputState`.
 */
enum abstract AnyInputStateKind(Int) {
    var InputKind = 0;
    var TextareaKind = 1;
    var EditorKind = 2;
    var OtpKind = 3;

    public function toString():String {
        return switch (cast this : AnyInputStateKind) {
            case InputKind: 'Input';
            case TextareaKind: 'Textarea';
            case EditorKind: 'Editor';
            case OtpKind: 'Otp';
        }
    }
}

/**
 * The three states the `Input` element can render.
 *
 * `AnyInputState` also covers `OtpState`, which is a different engine with
 * none of these methods, so the element takes this narrower type instead.
 *
 * Rust is an enum over the three concrete states whose `dispatch!` macro
 * forwards every call to the shared engine; the port's three states share
 * one class, `InputBaseState`, so this holds it directly.
 */
class TextInputState {

    public final state:Entity<InputBaseState>;

    public function new(state:Entity<InputBaseState>) {
        this.state = state;
    }

    public inline function hasSelectionFocus(window:Window, cx:App):Bool {
        return state.read(cx).hasSelectionFocus(window, cx);
    }

    public inline function entityId():Int {
        return state.entityId();
    }

    public inline function presentation(cx:App):glaze.kit.base.input.InputPresentation {
        return state.read(cx).presentation();
    }

    /** The text of the input, borrowed from the state that owns it. */
    public inline function text(cx:App):ropey.Rope {
        return state.read(cx).text;
    }

    public function focus(window:Window, cx:App):Void {
        state.update(cx, (state, cx) -> state.focus(window, cx));
    }

    public function clean(window:Window, cx:App):Void {
        state.update(cx, (state, cx) -> state.clean(window, cx));
    }

    public function toggleMasked(window:Window, cx:App):Void {
        state.update(cx, (state, cx) -> state.toggleMasked(window, cx));
    }

    public function setTextAlign(align:glaze.TextAlign, cx:App):Void {
        state.update(cx, (state, cx) -> state.setTextAlign(align, cx));
    }

    public function setDisabled(disabled:Bool, cx:App):Void {
        state.update(cx, (state, cx) -> state.setDisabled(disabled, cx));
    }

    public function setReadonly(readonly:Bool, cx:App):Void {
        state.update(cx, (state, cx) -> state.setReadonly(readonly, cx));
    }

    /** Whether every character is already selected, so Select All has nothing left to offer. */
    public function isAllSelected(cx:App):Bool {
        final state = this.state.read(cx);
        final selected = state.selectedRange();
        return selected.start == 0 && selected.end == state.text.len();
    }

    /** The `AnyInputState` of this state (Rust `From<&TextInputState>`). */
    public inline function toAny():AnyInputState {
        return AnyInputState.fromBase(state);
    }

}
