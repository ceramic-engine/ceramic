// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/control.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.questionnaire;

import glaze.App;
import glaze.ElementIdArg;
import glaze.Entity;
import glaze.KeyDownEvent;
import glaze.Window;
import glaze.kit.base.Checkbox;
import glaze.kit.base.Radio;

/**
 * The answer control for one choice, wired to the questionnaire's behavior.
 *
 * A multiple-answer item hands back a `Checkbox` and a single-answer item a
 * `Radio`, each already carrying its checked state, disabled state,
 * accessibility name, position in set, focus handle, confirm key and change
 * handler. Activation goes through `QuestionnaireState.choose`, so a `Radio`
 * confirms its item once chosen. The skin decides what the control looks
 * like and what it contains.
 *
 * The listeners Rust adds through `InteractiveElement` (the confirm key, the
 * radio click) go to the control's `base` element, and the accessibility
 * description and position to its `a11y` record.
 */
enum QuestionnaireChoiceControl {
    Checkbox(checkbox:glaze.kit.base.Checkbox);
    Radio(radio:glaze.kit.base.Radio);
}

class QuestionnaireChoiceControlTools {

    /**
     * Rust `QuestionnaireChoiceControl::new`. Returns `null` when the item or
     * the choice is not part of the schema.
     */
    public static function create(state:Entity<QuestionnaireState>, item:String, value:String, id:ElementIdArg, cx:App):Null<QuestionnaireChoiceControl> {
        final snapshot = state.read(cx);
        final choice = snapshot.choiceState(item, value);
        if (choice == null) return null;
        final itemState = snapshot.itemState(item);
        if (itemState == null) return null;
        final multiple = itemState.isMultiple();
        final definition = snapshot.choiceDefinition(item, value);
        if (definition == null) return null;
        final label = definition.accessibilityLabel();
        final description = definition.description();
        final position = snapshot.choicePosition(item, value);
        final focusHandle = snapshot.choiceFocusHandle(item, value);
        final selected = choice.isSelected();
        final disabled = choice.isDisabled();

        // Enter confirms an answer that is already selected; an unselected
        // control keeps Enter for activation.
        final confirmState = state;
        final confirm = (event:KeyDownEvent, window:Window, cx:App) -> {
            if (selected
                && !window.defaultPrevented()
                && !event.isHeld
                && event.keystroke.key == 'enter'
                && event.keystroke.modifiers.numberOfModifiers() == 0
                && confirmState.update(cx, (state, cx) -> state.confirmCurrent(window, cx))) {
                window.preventDefault();
            }
        };

        if (multiple) {
            final checkbox = glaze.kit.base.Checkbox.component(id)
                .state(selected ? CheckboxState.Checked : CheckboxState.Unchecked)
                .disabled(disabled)
                .accessibilityLabel(label);
            if (description != null) checkbox.a11y.description = description;
            if (position != null) {
                checkbox.a11y.positionInSet = position.position;
                checkbox.a11y.sizeOfSet = position.total;
            }
            if (focusHandle != null) checkbox.trackFocus(focusHandle);
            checkbox.base.captureKeyDown(confirm);
            checkbox.onChange((_, _, window, cx) -> {
                state.update(cx, (state, cx) -> state.choose(item, value, window, cx));
            });
            return QuestionnaireChoiceControl.Checkbox(checkbox);
        }
        else {
            final radio = glaze.kit.base.Radio.component(id)
                .checked(selected)
                .disabled(disabled)
                .accessibilityLabel(label);
            if (description != null) radio.a11y.description = description;
            if (position != null) radio.setPosition(position.position, position.total);
            if (focusHandle != null) radio.trackFocus(focusHandle);
            radio.base.captureKeyDown(confirm);
            // `onChange` would leave a checked radio inert, but choosing the
            // selected answer again still confirms it.
            if (!disabled) {
                radio.base.onClick((_, window, cx) -> {
                    state.update(cx, (state, cx) -> state.choose(item, value, window, cx));
                });
            }
            return QuestionnaireChoiceControl.Radio(radio);
        }
    }

}
