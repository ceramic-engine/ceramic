// Ported from gpui-kit 0.8.1: crates/base/src/input/input/mod.rs (`InputState`),
// crates/base/src/input/base/state.rs (`impl InputBaseState<InputMode>`),
// crates/base/src/input/base/inline_tokens.rs (`token_api!(InputMode)`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.App;
import gpui.Context;
import gpui.Range;
import gpui.TextInputConfiguration.Autocapitalize;
import gpui.TextInputConfiguration.TextInputAction;
import gpui.Window;
import gpui.base.NumberStep;
import gpui.base.StepAction;
import gpui.base.input.InputBaseState.IntoMaskPattern;

using gpui.base.input.InputTokens;

/**
 * State for a single-line text input.
 *
 * This is the shared editing engine in its single-line kind (Rust
 * `InputBaseState<InputMode>`). Multi-line layout, auto-grow, and
 * code-editor configuration do not exist on this type: those methods live
 * on `TextareaState` and `EditorState`.
 *
 * The builders of `InputBaseState` are overridden here with this type as
 * their result, so that a chain keeps it.
 */
class InputState extends InputBaseState {

    /** Create a single-line text input state. */
    public function new(window:Window, cx:Context<Dynamic>) {
        super(InputMode.instance, window, cx);
    }

    /**
     * Set a custom step function of the `NumberInput`.
     *
     * The `f` receives the current value and the `StepAction`, and returns
     * the step to apply, so the step can vary with the value.
     */
    public function stepBy(f:(Float, StepAction, App) -> Float):InputState {
        numberStep = NumberStep.ByValue(f);
        return this;
    }

    /** Set with password masked state. */
    public function withMasked(masked:Bool):InputState {
        this.masked = masked;
        return this;
    }

    /** Set the password masked state of the input field. */
    public function setMasked(masked:Bool, window:Window, cx:Context<InputBaseState>):Void {
        this.masked = masked;
        cx.notify();
    }

    /** Set the regular expression pattern of the input field. */
    public function withPattern(pattern:EReg):InputState {
        this.pattern = pattern;
        return this;
    }

    /** Set the regular expression pattern of the input field with reference. */
    public function setPattern(pattern:EReg, window:Window, cx:Context<InputBaseState>):Void {
        this.pattern = pattern;
    }

    /** Set the validation function of the input field. */
    public function withValidate(f:(String, App) -> Bool):InputState {
        validate = f;
        return this;
    }

    public function setValidator(validate:(String, App) -> Bool, cx:Context<InputBaseState>):Void {
        this.validate = validate;
    }

    /**
     * Set the step value of the `NumberInput` for increment/decrement.
     *
     * If any of `step`, `min`, `max` is set, the `NumberInput` will update the
     * value internally (step by `step`, default 1, clamp to the `min`/`max`
     * range and emit `InputEvent.Change`) instead of emitting
     * `NumberInputEvent.Step`.
     */
    public function step(step:IntoNumberStep):InputState {
        numberStep = step;
        return this;
    }

    /**
     * Set the minimum value of the `NumberInput`.
     *
     * The value will be clamped to the minimum value on stepping and on
     * blur (only if the clamped value passes the `pattern`/`validate` check).
     */
    public function min(min:Float):InputState {
        numberMin = min;
        return this;
    }

    /**
     * Set the maximum value of the `NumberInput`.
     *
     * The value will be clamped to the maximum value on stepping and on
     * blur (only if the clamped value passes the `pattern`/`validate` check).
     */
    public function max(max:Float):InputState {
        numberMax = max;
        return this;
    }

    /**
     * Update the step value after construction, `null` to fall back to
     * emitting `NumberInputEvent.Step` (if `min`, `max` are unset).
     */
    public function setStep(step:Null<IntoNumberStep>, window:Window, cx:Context<InputBaseState>):Void {
        numberStep = step;
    }

    /** Update the minimum value after construction. */
    public function setMin(min:Null<Float>, window:Window, cx:Context<InputBaseState>):Void {
        numberMin = min;
    }

    /** Update the maximum value after construction. */
    public function setMax(max:Null<Float>, window:Window, cx:Context<InputBaseState>):Void {
        numberMax = max;
    }

    /** Set true to show spinner at the input right. */
    public function setLoading(loading:Bool, window:Window, cx:Context<InputBaseState>):Void {
        this.loading = loading;
        cx.notify();
    }

    // Token API (Rust `token_api!`)

    /** Replace the selection with an atomic token; no delimiter is added. Returns the error, or null. */
    public function replaceWithToken(token:InlineToken, window:Window, cx:Context<InputBaseState>):Null<InlineTokenError> {
        return InputTokens.replaceWithToken(this, token, window, cx);
    }

    /** Replace a UTF-8 byte range, expanding overlaps to whole tokens. Returns the error, or null. */
    public function replaceRangeWithToken(range:Range, token:InlineToken, window:Window, cx:Context<InputBaseState>):Null<InlineTokenError> {
        return InputTokens.replaceRangeWithToken(this, range, token, window, cx);
    }

    public function tokens():Array<InlineTokenSpan> {
        return InputTokens.tokens(this);
    }

    /** The text with its tokens, as `setValue` accepts it. */
    public function content():InputContent {
        return InputTokens.content(this);
    }

    // Builders of `InputBaseState`, with this type as their result.

    override public function contextMenu(enable:Bool):InputState {
        return cast super.contextMenu(enable);
    }

    override public function withReplaceable(allow:Bool):InputState {
        return cast super.withReplaceable(allow);
    }

    override public function withPlaceholder(placeholder:String):InputState {
        return cast super.withPlaceholder(placeholder);
    }

    override public function withDisabled(disabled:Bool):InputState {
        return cast super.withDisabled(disabled);
    }

    override public function withReadonly(readonly:Bool):InputState {
        return cast super.withReadonly(readonly);
    }

    override public function withCleanOnEscape():InputState {
        return cast super.withCleanOnEscape();
    }

    override public function withSubmitOnEnter(submit:Bool):InputState {
        return cast super.withSubmitOnEnter(submit);
    }

    override public function withInputAction(action:TextInputAction):InputState {
        return cast super.withInputAction(action);
    }

    override public function withAutocorrect(autocorrect:Bool):InputState {
        return cast super.withAutocorrect(autocorrect);
    }

    override public function withAutocapitalize(autocapitalize:Autocapitalize):InputState {
        return cast super.withAutocapitalize(autocapitalize);
    }

    override public function withShowWhitespaces(show:Bool):InputState {
        return cast super.withShowWhitespaces(show);
    }

    override public function withScrollBeyondLastLine(rows:Null<Int>):InputState {
        return cast super.withScrollBeyondLastLine(rows);
    }

    override public function withCursorSurroundingLines(lines:Null<Int>):InputState {
        return cast super.withCursorSurroundingLines(lines);
    }

    override public function defaultValue(value:String):InputState {
        return cast super.defaultValue(value);
    }

    override public function withMaskPattern(pattern:IntoMaskPattern):InputState {
        return cast super.withMaskPattern(pattern);
    }

}
