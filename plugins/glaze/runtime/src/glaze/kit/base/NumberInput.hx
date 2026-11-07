// Ported from gpui-kit 0.8.1: crates/base/src/number_input.rs (`NumberInput`, `NumberInputText`,
// `NumberInputEvent`, `Increment`, `Decrement`, `init`, `apply_number_step`, `step_value`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.Action;
import glaze.AnyElement;
import glaze.App;
import glaze.AppContext;
import glaze.Context;
import glaze.ElementId;
import glaze.Entity;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.input.InputBase;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputState;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * Steps the value up (bound to `up` in the `NumberInput` context).
 */
@:action(namespace = number_input) class Increment implements Action {}

/**
 * Steps the value down (bound to `down` in the `NumberInput` context).
 */
@:action(namespace = number_input) class Decrement implements Action {}

/**
 * The event a `NumberInput` state emits when stepping is left to the caller
 * (subscribe with `cx.subscribe(state, NumberInputEvent, ...)`).
 */
enum NumberInputEvent {
    Step(action:StepAction);
}

/**
 * An unstyled spinbutton root composed from the foundational `InputBase` frame.
 */
class NumberInput implements RenderOnce implements Styled implements ParentElement {

    static inline final CONTEXT:String = "NumberInput";

    public static function init(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("up", new Increment(), CONTEXT),
            new KeyBinding("down", new Decrement(), CONTEXT),
        ]);
    }

    final numberStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    var disabledValue:Bool = false;

    final state:Entity<InputState>;

    var onStepHandler:Null<(StepAction, Window, App) -> Void> = null;

    var decrementDecorator:Null<(Button) -> Button> = null;

    var incrementDecorator:Null<(Button) -> Button> = null;

    var inputElement:Null<AnyElement> = null;

    var controlsRightValue:Bool = false;

    var accessibilityLabelValue:Null<String> = null;

    public function new(state:Entity<InputState>) {
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return numberStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):NumberInput {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):NumberInput {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function disabled(disabled:Bool):NumberInput {
        disabledValue = disabled;
        return this;
    }

    public function onStep(handler:(StepAction, Window, App) -> Void):NumberInput {
        onStepHandler = handler;
        return this;
    }

    /** Decorate the built-in decrement button with application-owned content and styles. */
    public function decrementButton(decorate:(Button) -> Button):NumberInput {
        decrementDecorator = decorate;
        return this;
    }

    /** Decorate the built-in increment button with application-owned content and styles. */
    public function incrementButton(decorate:(Button) -> Button):NumberInput {
        incrementDecorator = decorate;
        return this;
    }

    /** Decorate the built-in text region with an editor, adornments, and styles. */
    public function input(input:IntoElement):NumberInput {
        inputElement = input;
        return this;
    }

    /** Stack both step buttons on the right side of the text region. */
    public function controlsRight():NumberInput {
        controlsRightValue = true;
        return this;
    }

    /**
     * Sets the name exposed to accessibility clients.
     *
     * A number input has no visible text of its own to be named by, so set
     * this unless the input is named some other way.
     */
    public function accessibilityLabel(label:String):NumberInput {
        accessibilityLabelValue = label;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final disabled = disabledValue;
        final controlsRight = controlsRightValue;
        final onStep:(StepAction, Window, App) -> Void = if (onStepHandler != null) onStepHandler else {
            final state = this.state;
            (action, window, cx) -> {
                (cast state : Entity<InputBaseState>).update(cx, (s, cx) -> {
                    s.focus(window, cx);
                    applyNumberStep(cast s, action, window, cx);
                });
            };
        }
        state.read(cx).ensureNumberMask();
        final value = parseF64(state.read(cx).value());
        final decrementButton = decrementDecorator != null ? decrementDecorator(new Button("decrement")) : new Button("decrement");
        final incrementButton = incrementDecorator != null ? incrementDecorator(new Button("increment")) : new Button("increment");
        final text = new NumberInputText();
        if (inputElement != null) text.child(inputElement);

        // Stepping is driven from the focused editor, so the buttons never take
        // focus themselves; otherwise every press would pull the focus ring off
        // the frame and hand it straight back.
        if (controlsRight) decrementButton.flex1().minH0();
        if (!controlsRight) decrementButton.flexNone();
        decrementButton.focusable(false).disabled(disabled).onClick((_, window, cx) -> {
            onStep(Decrement, window, cx);
        });
        if (controlsRight) incrementButton.flex1().minH0();
        if (!controlsRight) incrementButton.flexNone();
        incrementButton.focusable(false).disabled(disabled).onClick((_, window, cx) -> {
            onStep(Increment, window, cx);
        });

        for (child in childElements) text.child(child);
        final content:IntoElement = if (controlsRight) {
            div()
                .flex()
                .itemsCenter()
                .sizeFull()
                .child(text)
                .child(
                    div()
                        .hFull()
                        .flex()
                        .flexCol()
                        .child(incrementButton)
                        .child(decrementButton)
                );
        } else {
            div()
                .flex()
                .itemsCenter()
                .sizeFull()
                .child(decrementButton)
                .child(text)
                .child(incrementButton);
        }

        final root = new InputBase(ElementId.NamedInteger("number-input", state.entityId()))
            .trackFocus(state.read(cx).focusHandle);
        root.flex().itemsCenter();
        root.disabled(disabled).role(Explicit(Role.SpinButton));
        if (accessibilityLabelValue != null) root.accessibilityLabel(accessibilityLabelValue);
        if (value != null) root.a11y.numericValue = value;
        root.base.keyContext(CONTEXT);
        root.base.onAction(Increment, (_, window, cx) -> {
            if (disabled) {
                cx.propagate();
            } else {
                onStep(Increment, window, cx);
            }
        });
        root.base.onAction(Decrement, (_, window, cx) -> {
            if (disabled) {
                cx.propagate();
            } else {
                onStep(Decrement, window, cx);
            }
        });
        root.child(content);
        root.refineStyle(numberStyle);
        return root.render(window, cx);
    }

    /**
     * Apply a number-input step or emit a step event when stepping is
     * caller-controlled (Rust `InputState::apply_number_step`).
     */
    @:allow(glaze)
    static function applyNumberStep(state:InputState, action:StepAction, window:Window, cx:Context<InputBaseState>):Void {
        if (state.disabled) {
            return;
        }
        final step = state.numberStep;
        if (step != null) {
            final value = state.unmaskValue();
            final parsed = parseF64(StringTools.trim(value));
            final current = parsed != null ? parsed : 0.;
            final stepValue = step.value(current, action, cx.app);
            final newValue = NumberInput.stepValue(value, action, stepValue, state.numberMin, state.numberMax);
            if (newValue != null) {
                if (state.isValidInput(newValue, cx)) {
                    final range = state.rangeToUtf16(new glaze.Range(0, utf8Length(state.value())));
                    state.replaceTextInRangeSilent(range, newValue, window, cx);
                    return;
                }
            } else {
                return;
            }
        }
        cx.emit(NumberInputEvent.Step(action));
    }

    /**
     * Step a numeric string while preserving decimal precision and range direction.
     */
    public static function stepValue(value:String, action:StepAction, step:Float, min:Null<Float>, max:Null<Float>):Null<String> {
        function fractionDigits(value:String):Int {
            final parts = value.split(".");
            return parts.length > 1 ? utf8Length(parts[1]) : 0;
        }

        final current = parseF64(StringTools.trim(value));
        final base = current != null ? current : 0.;
        var newValue = switch action {
            case Increment: base + step;
            case Decrement: base - step;
        }
        var digits = maxInt(fractionDigits(value), fractionDigits(f64ToString(step)));
        if (min != null && newValue < min) {
            newValue = min;
            digits = maxInt(digits, fractionDigits(f64ToString(min)));
        }
        if (max != null && newValue > max) {
            newValue = max;
            digits = maxInt(digits, fractionDigits(f64ToString(max)));
        }

        if (current != null) {
            final moved = switch action {
                case Increment: newValue > current;
                case Decrement: newValue < current;
            }
            if (!moved) {
                return null;
            }
        }

        return formatFixed(newValue, digits);
    }

    static inline function maxInt(a:Int, b:Int):Int {
        return a > b ? a : b;
    }

    static function utf8Length(s:String):Int {
        return haxe.io.Bytes.ofString(s).length;
    }

    /**
     * Rust `str::parse::<f64>()`: a decimal number (optional sign, digits,
     * optional fraction and exponent), `inf`, `infinity` and `nan`; null for
     * anything else (Haxe's `parseFloat` accepts trailing garbage).
     */
    @:allow(glaze)
    static function parseF64(s:String):Null<Float> {
        if (~/^[+-]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?$/.match(s)) {
            return Std.parseFloat(s);
        }
        var unsigned = s.toLowerCase();
        var negative = false;
        if (unsigned.charAt(0) == "+" || unsigned.charAt(0) == "-") {
            negative = unsigned.charAt(0) == "-";
            unsigned = unsigned.substr(1);
        }
        if (unsigned == "inf" || unsigned == "infinity") {
            return negative ? Math.NEGATIVE_INFINITY : Math.POSITIVE_INFINITY;
        }
        if (unsigned == "nan") {
            return Math.NaN;
        }
        return null;
    }

    /** Rust's `{}` of an `f64` (shortest representation that parses back). */
    static function f64ToString(value:Float):String {
        if (Math.isNaN(value))
            return "NaN";
        if (value == Math.POSITIVE_INFINITY)
            return "inf";
        if (value == Math.NEGATIVE_INFINITY)
            return "-inf";
        if (value == Math.ffloor(value) && Math.abs(value) < 1e15) {
            return formatFixed(value, 0);
        }
        for (digits in 1...18) {
            var s = formatFixed(value, digits);
            if (Std.parseFloat(s) == value) {
                while (s.charAt(s.length - 1) == "0")
                    s = s.substr(0, s.length - 1);
                return s;
            }
        }
        return Std.string(value);
    }

    /**
     * Rust `format!("{value:.digits$}")`: fixed notation rounded to `digits`
     * fraction digits, ties to even.
     */
    @:allow(glaze)
    static function formatFixed(value:Float, digits:Int):String {
        if (Math.isNaN(value))
            return "NaN";
        if (!Math.isFinite(value))
            return value > 0 ? "inf" : "-inf";
        final negative = value < 0 || (value == 0 && 1 / value < 0);
        final scale = Math.pow(10, digits);
        final scaled = Math.abs(value) * scale;
        var n = Math.ffloor(scaled);
        final frac = scaled - n;
        if (frac > 0.5 || (frac == 0.5 && n % 2 != 0)) n += 1;
        var intPart = Math.ffloor(n / scale);
        var fracPart = n - intPart * scale;
        var intString = Std.string(intPart);
        final dot = intString.indexOf(".");
        if (dot >= 0)
            intString = intString.substr(0, dot);
        var s = intString;
        if (digits > 0) {
            var fracString = Std.string(Math.fround(fracPart));
            final fdot = fracString.indexOf(".");
            if (fdot >= 0)
                fracString = fracString.substr(0, fdot);
            while (fracString.length < digits)
                fracString = "0" + fracString;
            s += "." + fracString;
        }
        return negative ? "-" + s : s;
    }

}

/**
 * The built-in text region of a `NumberInput`.
 *
 * Applications provide the editor itself as a child and can style this region
 * without having to recreate the number input's fixed three-part structure.
 */
class NumberInputText implements RenderOnce implements Styled implements ParentElement {

    final textStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return textStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):NumberInputText {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):NumberInputText {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final element = div().minW0().flex1();
        element.extend(childElements);
        return element.refineStyle(textStyle);
    }

}
