// Ported from gpui-kit 0.8.1: crates/component/src/setting/fields/number.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.setting;

import gpui.AnyElement;
import gpui.App;
import gpui.IntoElement;
import gpui.Entity;
import gpui.StyleRefinement;
import gpui.Subscription;
import gpui.Window;
import gpui.base.input.InputEvent;
import gpui.base.input.InputState;
import gpui.component.input.NumberInput;
import gpui.component.setting.SettingField.AnySettingField;
import gpui.component.setting.SettingField.SettingFieldRender;

using gpui.base.Geometry.AxisExt;
using gpui.base.StyledExt;

/**
 * The options of a number field.
 */
class NumberFieldOptions {

    /**
     * The minimum value for the number input, default is `f64::MIN`.
     */
    public var min:Float;

    /**
     * The maximum value for the number input, default is `f64::MAX`.
     */
    public var max:Float;

    /**
     * The step value for the number input, default is `1.0`.
     */
    public var step:Float;

    public function new(min:Float = -1.7976931348623157e308, max:Float = 1.7976931348623157e308, step:Float = 1.0) {
        this.min = min;
        this.max = max;
        this.step = step;
    }

    /** Rust `Clone`. */
    public function clone():NumberFieldOptions {
        return new NumberFieldOptions(min, max, step);
    }

}

/**
 * Renders a number field as a number input.
 */
@:allow(gpui.component.setting)
class NumberField implements SettingFieldRender {

    final options:NumberFieldOptions;

    /**
     * The setting's title, the input's accessible name.
     */
    final title:String;

    function new(options:Null<NumberFieldOptions>, title:String) {
        this.options = options != null ? options.clone() : new NumberFieldOptions();
        this.title = title;
    }

    /** Rust's `{}` of an `f64`. */
    static inline function f64ToString(value:Float):String {
        return @:privateAccess gpui.base.NumberInput.f64ToString(value);
    }

    public function render(field:AnySettingField, options:RenderOptions, style:StyleRefinement, window:Window, cx:App):AnyElement {
        final value:Float = SettingField.getValueOf(field, cx);
        final setValue:(Float, App) -> Void = SettingField.setValueOf(field, cx);
        final numOptions = this.options.clone();

        final stateEntity = window.useKeyedState('number-state-${options.pageIx()}-${options.groupIx()}-${options.itemIx()}', cx, window -> {
            // Configure stepping and bounds on the engine itself: `+` / `-`
            // and Up / Down step by `step` with precision handling, and
            // out-of-range text is tolerated while typing and clamped on
            // blur. Re-implementing either on `Change` breaks both.
            final input:Entity<InputState> = cx.newEntity(c -> new InputState(window, c)
                .defaultValue(f64ToString(value))
                .step(numOptions.step)
                .min(numOptions.min)
                .max(numOptions.max));
            final state = new NumberFieldState(input, value);
            state.subscriptions.push(cx.subscribe(input, InputEvent, (input, event, cx) -> {
                switch event {
                    case Change:
                        input.update(cx, (input, cx) -> {
                            final text = input.value();
                            if (text == f64ToString(state.initialValue)) {
                                return;
                            }

                            // Unparsable intermediates ("-", "", "1.") are
                            // left alone so the next keystroke can complete
                            // them. Out-of-range text stays too (the engine
                            // clamps it on blur), but the setting only ever
                            // receives a value inside `min..=max`.
                            final parsed = @:privateAccess gpui.base.NumberInput.parseF64(text);
                            if (parsed != null) {
                                final clamped = parsed < numOptions.min ? numOptions.min : (parsed > numOptions.max ? numOptions.max : parsed);
                                setValue(clamped, cx.app);
                                state.initialValue = clamped;
                            }
                        });
                    case _:
                }
            }));
            state;
        });

        // Sync engine config and displayed value when options or the
        // underlying setting changed externally.
        final syncOptions = this.options.clone();
        stateEntity.update(cx, (holder, cx) -> {
            final state = holder.value;
            state.input.update(cx, (input, cx) -> {
                input.setStep(syncOptions.step, window, cast cx);
                input.setMin(syncOptions.min, window, cast cx);
                input.setMax(syncOptions.max, window, cast cx);
            });
            if (state.initialValue != value) {
                state.initialValue = value;
                state.input.update(cx, (input, cx) -> {
                    input.setValue(f64ToString(value), window, cast cx);
                });
            }
        });

        final state = stateEntity.read(cx).value;

        final input = new NumberInput(state.input)
            .accessibilityLabel(title)
            .disabled(options.isDisabled())
            .withSize(options.size());
        if (options.layout().isHorizontal()) {
            input.w32();
        } else {
            input.wFull();
        }
        input.refineStyle(style);
        return (input : IntoElement).intoAnyElement();
    }

}

/**
 * The keyed state of a number field.
 */
@:allow(gpui.component.setting)
class NumberFieldState implements gpui.Droppable {

    final input:Entity<InputState>;

    var initialValue:Float;

    final subscriptions:Array<Subscription> = [];

    function new(input:Entity<InputState>, initialValue:Float) {
        this.input = input;
        this.initialValue = initialValue;
    }

    /**
     * Rust drops the subscriptions and the input with the state.
     */
    public function drop():Void {
        for (subscription in subscriptions) subscription.dispose();
    }

}
