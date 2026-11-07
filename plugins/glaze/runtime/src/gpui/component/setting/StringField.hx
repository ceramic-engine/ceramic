// Ported from gpui-kit 0.8.1: crates/component/src/setting/fields/string.rs
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
import gpui.base.input.InputBaseState;
import gpui.base.input.InputEvent;
import gpui.base.input.InputState;
import gpui.component.input.Input;
import gpui.component.setting.SettingField.AnySettingField;
import gpui.component.setting.SettingField.SettingFieldRender;

using gpui.base.Geometry.AxisExt;
using gpui.base.StyledExt;

/**
 * Renders a string field as an input.
 */
@:allow(gpui.component.setting)
class StringField implements SettingFieldRender {

    /**
     * The setting's title, the input's accessible name.
     */
    final title:String;

    function new(title:String) {
        this.title = title;
    }

    public function render(field:AnySettingField, options:RenderOptions, style:StyleRefinement, window:Window, cx:App):AnyElement {
        final value:String = SettingField.getValueOf(field, cx);
        final setValue:(String, App) -> Void = SettingField.setValueOf(field, cx);

        final stateEntity = window.useKeyedState('string-state-${options.pageIx()}-${options.groupIx()}-${options.itemIx()}', cx, window -> {
            final input:Entity<InputState> = cx.newEntity(c -> new InputState(window, c).defaultValue(value));
            final subscription = cx.subscribe(input, InputEvent, (input, event, cx) -> {
                switch event {
                    case Change:
                        final value = input.read(cx).value();
                        setValue(value, cx);
                    case _:
                }
            });

            new StringFieldState(input, subscription);
        });

        // Sync the displayed value when the underlying setting changed externally
        stateEntity.update(cx, (state, cx) -> {
            if (state.value.input.read(cx).value() != value) {
                state.value.input.update(cx, (input, cx) -> {
                    input.setValue(value, window, cast cx);
                });
            }
        });

        final state = stateEntity.read(cx).value;

        final input = new Input(state.input)
            .ariaLabel(title)
            .disabled(options.isDisabled())
            .withSize(options.size());
        if (options.layout().isHorizontal()) {
            input.w64();
        } else {
            input.wFull();
        }
        input.refineStyle(style);
        return (input : IntoElement).intoAnyElement();
    }

}

/**
 * The keyed state of a string field: its input and the subscription that
 * writes the input's changes to the setting.
 */
@:allow(gpui.component.setting)
class StringFieldState implements gpui.Droppable {

    final input:Entity<InputState>;

    final subscription:Subscription;

    function new(input:Entity<InputState>, subscription:Subscription) {
        this.input = input;
        this.subscription = subscription;
    }

    /**
     * Rust drops the subscription and the input with the state.
     */
    public function drop():Void {
        subscription.dispose();
    }

}
