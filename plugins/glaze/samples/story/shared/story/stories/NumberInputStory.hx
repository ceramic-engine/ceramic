// Ported from gpui-kit 0.8.1: crates/story/src/stories/number_input_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.Subscription;
import glaze.kit.base.NumberInput.NumberInputEvent;
import glaze.kit.base.StepAction;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputState;
import glaze.kit.base.input.MaskPattern;
import glaze.kit.IconName;
import glaze.kit.button.Button;
import glaze.kit.input.NumberInput;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

class NumberInputStory extends Model implements Story {

    public static function title():String {
        return 'NumberInput';
    }

    public static function description():String {
        return 'Adjust constrained numeric values precisely with typing or increment and decrement controls.';
    }

    public static function closable():Bool {
        return false;
    }

    public static function init(_:App):Void {}

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<NumberInputStory> {
        return cx.newEntity((c:Context<NumberInputStory>) -> new NumberInputStory(window, c));
    }

    var numberInput1Value:Int;

    final numberInput1:Entity<InputState>;

    final numberInput2:Entity<InputState>;

    final numberInput3:Entity<InputState>;

    final numberInput4:Entity<InputState>;

    final disabledInput:Entity<InputState>;

    final subscriptions:Array<Subscription>;

    function new(window:Window, cx:Context<NumberInputStory>) {
        super();
        // Opt out of internal stepping via `setStep(null)`, so the
        // NumberInput emits NumberInputEvent.Step and the subscriber is
        // responsible for updating the value (see `onNumberInputEvent`).
        final numberInput1Value = 1;
        numberInput1 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withPlaceholder('Normal Integer')
            .defaultValue(Std.string(numberInput1Value)));
        numberInput1.update(cx, (state, cx) -> state.setStep(null, window, cast cx));
        // With min, the NumberInput steps the value internally (step
        // default: 1) and clamps it to the range, no event handling needed.
        numberInput2 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withPlaceholder('Unsized Integer')
            .withPattern(~/^\d+$/)
            .min(0.));
        numberInput3 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withPlaceholder('Mask pattern')
            .withMaskPattern(MaskPattern.Number(','.code, 2))
            .defaultValue('1234.56')
            .step(100.)
            .min(0.));
        // The step varies by direction at the boundary 1.0: 0.1 going down,
        // 0.5 going up.
        numberInput4 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withPlaceholder('Styling')
            .defaultValue('0.9')
            .stepBy((value, action, _) -> switch action {
                case Increment: value < 1.0 ? 0.1 : 0.5;
                case Decrement: value <= 1.0 ? 0.1 : 0.5;
            })
            .min(0.));
        disabledInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .defaultValue('100')
            .withPlaceholder('Disabled'));
        this.numberInput1Value = numberInput1Value;
        subscriptions = [
            cx.subscribeIn(numberInput1, InputEvent, window, onInputEvent),
            cx.subscribeIn(numberInput1, NumberInputEvent, window, onNumberInputEvent),
            cx.subscribeIn(numberInput2, InputEvent, window, onInputEvent),
            cx.subscribeIn(numberInput3, InputEvent, window, onInputEvent),
            cx.subscribeIn(numberInput4, InputEvent, window, onInputEvent),
            cx.subscribeIn(disabledInput, InputEvent, window, onInputEvent),
            cx.subscribeIn(disabledInput, NumberInputEvent, window, onNumberInputEvent),
        ];
    }

    static function onInputEvent(this_:NumberInputStory, state:Entity<InputState>, event:InputEvent, _:Window, cx:Context<NumberInputStory>):Void {
        switch event {
            case Change:
                final text = state.read(cx.app).value();
                if (state == this_.numberInput1) {
                    final value = Std.parseInt(text);
                    if (value != null && ~/^[+-]?\d+$/.match(text)) {
                        this_.numberInput1Value = value;
                    }
                }
                trace('Change: $text');
            case PressEnter(secondary, shift):
                trace('PressEnter secondary: $secondary, shift: $shift');
            case Focus:
                trace('Focus');
            case Blur:
                trace('Blur');
        }
    }

    static function onNumberInputEvent(this_:NumberInputStory, state:Entity<InputState>, event:NumberInputEvent, window:Window, cx:Context<NumberInputStory>):Void {
        switch event {
            case Step(stepAction):
                if (state == this_.numberInput1) {
                    switch stepAction {
                        case Decrement:
                            this_.numberInput1Value -= 1;
                        case Increment:
                            this_.numberInput1Value += 1;
                    }
                    final value = Std.string(this_.numberInput1Value);
                    state.update(cx, (input, cx) -> input.setValue(value, window, cast cx));
                }
        }
    }

    public function focusHandle(cx:App):FocusHandle {
        return numberInput1.read(cx).focusHandle;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        return vFlex()
            .id('input-story')
            .sizeFull()
            .justifyStart()
            .gap3()
            .child(section('Default')
                .description('Application-managed step events.')
                .w128()
                .itemsCenter()
                .child(new NumberInput(numberInput1).w(px(260.))))
            .child(section('Disabled')
                .description('Read-only disabled state.')
                .w128()
                .itemsCenter()
                .child(new NumberInput(disabledInput).w(px(260.)).disabled(true)))
            .child(section('Suffix')
                .description('Small size with a suffix action.')
                .w128()
                .itemsCenter()
                .child(new NumberInput(numberInput2)
                    .w(px(260.))
                    .small()
                    .suffix(new Button('info').text().icon(IconName.Info).xsmall())))
            .child(section('Number format')
                .description('Grouping, decimals, range, and step.')
                .w128()
                .itemsCenter()
                .child(new NumberInput(numberInput3).w(px(260.))))
            .child(section('Custom style')
                .description('Appearance-free input with dynamic steps.')
                .w128()
                .itemsCenter()
                .child(new NumberInput(numberInput4)
                    .w(px(260.))
                    .appearance(false)
                    .bg(theme.secondary)
                    .textColor(theme.info)));
    }

}
