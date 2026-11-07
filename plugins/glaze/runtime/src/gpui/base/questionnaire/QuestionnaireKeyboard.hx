// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/keyboard.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.questionnaire;

import gpui.App;
import gpui.Entity;
import gpui.KeyDownEvent;
import gpui.OperatingSystem;
import gpui.Window;

/**
 * Rust's free function `questionnaire::handle_key_down`.
 */
class QuestionnaireKeyboard {

    /**
     * Routes a key press to the questionnaire's behavior and reports whether
     * it was consumed (by preventing the default). The skin installs it on the
     * root; the contract (arrows move between answers and items, Enter
     * confirms a filled answer, a bare letter or digit activates a shortcut)
     * lives here so a different skin keeps it.
     */
    public static function handleKeyDown(state:Entity<QuestionnaireState>, event:KeyDownEvent, window:Window, cx:App):Void {
        if (window.defaultPrevented()
            || event.isHeld
            || event.preferCharacterInput
            || event.keystroke.isImeInProgress()) {
            return;
        }

        final modifiers = event.keystroke.modifiers;
        final key = event.keystroke.key;
        final inputFocused = state.read(cx).isCurrentInputFocused(window);
        final inputHasText = inputFocused && state.read(cx).currentInputHasText(cx);
        final singleRadioFocused = {
            final state = state.read(cx);
            final item = state.currentItem();
            final itemState = item != null ? state.itemState(item) : null;
            itemState != null && !itemState.isMultiple() && state.focusedCurrentChoice(window) != null;
        };

        final update = (f:(QuestionnaireState, gpui.Context<QuestionnaireState>) -> Bool) -> state.update(cx, f);

        final handled = if (key == 'enter' && modifiers.secondary(OperatingSystem.current) && modifiers.numberOfModifiers() == 1) {
            update((state, cx) -> state.confirmCurrent(window, cx));
        }
        else if (modifiers.numberOfModifiers() != 0) {
            false;
        }
        else if (inputFocused) {
            switch key {
                case 'enter' if (focusedAnswerIsFilled(state, window, cx)):
                    update((state, cx) -> state.confirmCurrent(window, cx));
                case 'up' if (!inputHasText):
                    update((state, cx) -> state.focusPreviousAnswer(window, cx));
                case 'down' if (!inputHasText):
                    update((state, cx) -> state.focusNextAnswer(window, cx));
                case _:
                    false;
            }
        }
        else {
            switch key {
                case 'up':
                    update((state, cx) -> state.focusPreviousAnswer(window, cx))
                        || (singleRadioFocused && update((state, cx) -> state.moveCurrentRadio(-1, window, cx)));
                case 'down':
                    update((state, cx) -> state.focusNextAnswer(window, cx))
                        || (singleRadioFocused && update((state, cx) -> state.moveCurrentRadio(1, window, cx)));
                case 'left' if (singleRadioFocused):
                    update((state, cx) -> state.moveCurrentRadio(-1, window, cx));
                case 'right' if (singleRadioFocused):
                    update((state, cx) -> state.moveCurrentRadio(1, window, cx));
                case 'left':
                    update((state, cx) -> state.goPrevious(window, cx));
                case 'right' if (state.read(cx).navigationState().isConfirmable()):
                    update((state, cx) -> state.goNext(window, cx));
                case 'right':
                    false;
                case 'enter' if (focusedAnswerIsFilled(state, window, cx)):
                    update((state, cx) -> state.confirmCurrent(window, cx));
                case 'enter':
                    false;
                case _:
                    update((state, cx) -> state.activateShortcut(key, window, cx));
            }
        };

        if (handled) {
            window.preventDefault();
        }
    }

    static function focusedAnswerIsFilled(state:Entity<QuestionnaireState>, window:Window, cx:App):Bool {
        final state = state.read(cx);
        final item = state.currentItem();
        if (item == null) {
            return false;
        }
        if (state.isCurrentInputFocused(window)) {
            final answer = state.answer(item);
            return answer != null && answer.freeform() != null;
        }
        final value = state.focusedCurrentChoice(window);
        if (value == null) return false;
        final choice = state.choiceState(item, value);
        return choice != null && choice.isSelected();
    }

}
