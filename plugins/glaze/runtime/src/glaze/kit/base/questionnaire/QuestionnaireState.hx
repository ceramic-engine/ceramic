// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.questionnaire;

import glaze.App;
import glaze.AppContext;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Model;
import glaze.Subscription;
import glaze.Task;
import glaze.Window;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputState;
import glaze.kit.base.questionnaire.QuestionnaireSubmission;

/**
 * The per item state the questionnaire keeps next to each definition.
 */
@:allow(glaze.kit.base.questionnaire)
class ItemRuntime {

    var disabled:Bool;

    var choiceDisabled:Array<Bool>;

    var inputDisabled:Bool;

    var answer:QuestionnaireAnswer;

    var initialAnswer:QuestionnaireAnswer;

    var initialInputValue:Null<String>;

    var skipped:Bool = false;

    var validationAttempted:Bool = false;

    var internalError:Null<QuestionnaireValidationError> = null;

    var externalError:Null<QuestionnaireValidationError> = null;

    var focusHandle:FocusHandle;

    var choiceFocusHandles:Array<FocusHandle>;

    var inputFocusHandle:Null<FocusHandle>;

    function new() {}

}

/**
 * Owns questionnaire answers, validation, navigation and focus state.
 *
 * Differences with Rust:
 * - `new` throws the `QuestionnaireSchemaError` Rust returns as `Err`, and so
 *   does the builder `withCurrentItem`. The other methods returning
 *   `Result<(), QuestionnaireSchemaError>` return the error, or `null` for
 *   `Ok(())`.
 * - Reactivity: `runtime`, `current` and `complete` are `@observe` fields;
 *   every place Rust calls `cx.notify()` also calls `invalidateRuntime()`, so
 *   the views that rendered the questionnaire redraw (GPUI re-renders the
 *   views that read the entity).
 * - Subscribe to `QuestionnaireEvent` with `cx.subscribe(state, QuestionnaireEvent, ...)`.
 */
class QuestionnaireState extends Model {

    /**
     * How long a newly chosen single answer stays on screen, selected, before
     * the item confirms, in seconds. Long enough to register the selection,
     * short enough not to read as a wait.
     */
    public static inline final CHOICE_CONFIRM_DELAY:Float = 0.15;

    final items:Array<QuestionnaireItemDefinition>;

    @observe var runtime:Array<ItemRuntime> = [];

    @observe var current:Null<Int> = null;

    var initialCurrent:Null<String> = null;

    var shortcutModeValue:Null<QuestionnaireShortcutMode> = null;

    @observe var complete:Bool = false;

    /**
     * The confirm a chosen single answer scheduled. Changing an answer or the
     * current item, or confirming by any other path, drops it first.
     */
    var pendingConfirm:Null<Task<Dynamic>> = null;

    final focusHandleValue:FocusHandle;

    final subscriptions:Array<Subscription> = [];

    /**
     * Throws a `QuestionnaireSchemaError` when the schema is invalid.
     */
    public function new(items:Array<QuestionnaireItemDefinition>, cx:Context<QuestionnaireState>) {
        super();
        final error = validateSchema(items);
        if (error != null) throw error;

        this.items = items;
        final runtime:Array<ItemRuntime> = [];

        for (item in items) {
            var answer = new QuestionnaireAnswer().withChoices([
                for (choice in item.choices()) if (choice.isDefaultSelected() && !choice.isDisabled()) choice.value()
            ]);

            var initialInputValue:Null<String> = null;
            var inputFocusHandle:Null<FocusHandle> = null;
            final input = item.input();
            if (input != null) {
                final state = input.state();
                state.update(cx, (state, c) -> {
                    state.setDisabled(item.isDisabled() || input.isDisabled(), cast c);
                });

                final value = state.read(cx).value();
                initialInputValue = value;
                inputFocusHandle = state.read(cx).focusHandle;
                if (!QuestionnaireAnswer.isWhitespaceOnly(value) && !input.isDisabled()) {
                    if (!item.isMultiple()) {
                        answer = new QuestionnaireAnswer();
                    }
                    answer.freeformValue = value;
                }

                subscriptions.push(cx.subscribe(state, InputEvent, (this_, input, event, cx) -> {
                    switch event {
                        case Change:
                            this_.onInputChange(input, cx);
                        case _:
                    }
                }));
            }

            final itemRuntime = new ItemRuntime();
            itemRuntime.disabled = item.isDisabled();
            itemRuntime.choiceDisabled = [for (choice in item.choices()) choice.isDisabled()];
            itemRuntime.inputDisabled = input == null || input.isDisabled();
            itemRuntime.initialAnswer = answer.clone();
            itemRuntime.initialInputValue = initialInputValue;
            itemRuntime.answer = answer;
            itemRuntime.focusHandle = cx.focusHandle();
            itemRuntime.choiceFocusHandles = [for (_ in item.choices()) cx.focusHandle()];
            itemRuntime.inputFocusHandle = inputFocusHandle;
            runtime.push(itemRuntime);
        }

        var current:Null<Int> = null;
        for (ix in 0...runtime.length) {
            if (!runtime[ix].disabled) {
                current = ix;
                break;
            }
        }
        this.runtime = runtime;
        this.current = current;
        this.initialCurrent = current != null ? items[current].name() : null;
        this.focusHandleValue = cx.focusHandle();
    }

    /**
     * Rust `validate_schema`: `null` when the schema is valid.
     */
    @:allow(tests)
    static function validateSchema(items:Array<QuestionnaireItemDefinition>):Null<QuestionnaireSchemaError> {
        final itemNames = new Map<String, Bool>();
        for (item in items) {
            if (itemNames.exists(item.name())) {
                return DuplicateItem(item.name());
            }
            itemNames.set(item.name(), true);

            final choices = new Map<String, Bool>();
            var defaults = 0;
            for (choice in item.choices()) {
                if (choices.exists(choice.value())) {
                    return DuplicateChoice(item.name(), choice.value());
                }
                choices.set(choice.value(), true);
                defaults += choice.isDefaultSelected() ? 1 : 0;
            }
            if (!item.isMultiple() && defaults > 1) {
                return MultipleDefaultsForSingleItem(item.name());
            }
        }
        return null;
    }

    /**
     * Starts on the named item (if it is enabled). Throws
     * `QuestionnaireSchemaError.UnknownItem` for an unknown name.
     */
    public function withCurrentItem(name:String):QuestionnaireState {
        final ix = itemIxOpt(name);
        if (ix == -1) throw QuestionnaireSchemaError.UnknownItem(name);
        if (!runtime[ix].disabled) {
            current = ix;
            initialCurrent = name;
        }
        return this;
    }

    public function withShortcuts(mode:QuestionnaireShortcutMode):QuestionnaireState {
        shortcutModeValue = mode;
        return this;
    }

    public function currentItem():Null<String> {
        final current = this.current;
        return current != null ? items[current].name() : null;
    }

    public function currentIx():Null<Int> {
        final current = this.current;
        if (current == null) return null;
        final enabled = enabledIndices();
        final position = enabled.indexOf(current);
        return position != -1 ? position : null;
    }

    public function total():Int {
        return enabledIndices().length;
    }

    public function progress():QuestionnaireProgressState {
        final ix = currentIx();
        return new QuestionnaireProgressState(ix != null ? ix + 1 : 0, total());
    }

    public function itemDefinition(name:String):Null<QuestionnaireItemDefinition> {
        for (item in items) {
            if (item.name() == name) return item;
        }
        return null;
    }

    public function choiceDefinition(item:String, value:String):Null<QuestionnaireChoiceDefinition> {
        final definition = itemDefinition(item);
        if (definition == null) return null;
        for (choice in definition.choices()) {
            if (choice.value() == value) return choice;
        }
        return null;
    }

    public function itemState(name:String):Null<QuestionnaireItemState> {
        final ix = itemIxOpt(name);
        if (ix == -1) return null;
        final definition = items[ix];
        return new QuestionnaireItemState(definition.name(), status(ix), definition.isRequired(), definition.isMultiple(), runtime[ix].disabled,
            errorAt(ix) != null, definition.input() != null);
    }

    public function choiceState(item:String, value:String):Null<QuestionnaireChoiceState> {
        final itemIx = itemIxOpt(item);
        if (itemIx == -1) return null;
        final choiceIx = choiceIxOpt(itemIx, value);
        if (choiceIx == -1) return null;
        final runtime = this.runtime[itemIx];
        final definition = items[itemIx].choices()[choiceIx];
        return new QuestionnaireChoiceState(definition.value(), runtime.answer.choiceValues.indexOf(definition.value()) != -1,
            runtime.disabled || runtime.choiceDisabled[choiceIx], errorAt(itemIx) != null, shortcutForChoice(item, value));
    }

    /**
     * One-based position of a choice among its item's enabled choices, with
     * the enabled total. Assistive technology announces the pair.
     */
    public function choicePosition(item:String, value:String):Null<{position:Int, total:Int}> {
        final definition = itemDefinition(item);
        if (definition == null) return null;
        final enabled = [
            for (choice in definition.choices()) {
                final state = choiceState(item, choice.value());
                if (state != null && !state.isDisabled()) choice;
            }
        ];
        for (position in 0...enabled.length) {
            if (enabled[position].value() == value) {
                return {position: position + 1, total: enabled.length};
            }
        }
        return null;
    }

    public function navigationState():QuestionnaireNavigationState {
        final ix = currentIx();
        if (ix == null) return new QuestionnaireNavigationState();
        final total = this.total();
        final itemIx:Int = current;
        return new QuestionnaireNavigationState(ix > 0, ix + 1 < total, !items[itemIx].isRequired(), ix + 1 == total, status(itemIx) != Unanswered);
    }

    public function answer(name:String):Null<QuestionnaireAnswer> {
        final ix = itemIxOpt(name);
        if (ix == -1) return null;
        return effectiveAnswer(ix);
    }

    public function answers():QuestionnaireAnswers {
        final enabled = enabledIndices();
        return new QuestionnaireAnswers([for (ix in enabled) items[ix].name()], [for (ix in enabled) effectiveAnswer(ix)]);
    }

    /**
     * The active validation failure for an item, if any. Base reports the
     * reason; the presentation layer turns a built-in reason into text.
     */
    public function error(name:String):Null<QuestionnaireValidationError> {
        final ix = itemIxOpt(name);
        return ix != -1 ? errorAt(ix) : null;
    }

    public function isComplete():Bool {
        return complete;
    }

    public function inputState(name:String):Null<Entity<InputState>> {
        final definition = itemDefinition(name);
        if (definition == null) return null;
        final input = definition.input();
        return input != null ? input.state() : null;
    }

    public inline function focusHandle():FocusHandle {
        return focusHandleValue;
    }

    public function itemFocusHandle(name:String):Null<FocusHandle> {
        final ix = itemIxOpt(name);
        return ix != -1 ? runtime[ix].focusHandle : null;
    }

    public function choiceFocusHandle(item:String, value:String):Null<FocusHandle> {
        final itemIx = itemIxOpt(item);
        if (itemIx == -1) return null;
        final choiceIx = choiceIxOpt(itemIx, value);
        if (choiceIx == -1) return null;
        return runtime[itemIx].choiceFocusHandles[choiceIx];
    }

    public function isCurrentInputFocused(window:Window):Bool {
        final ix = current;
        if (ix == null) return false;
        final handle = runtime[ix].inputFocusHandle;
        return handle != null && handle.isFocused(window);
    }

    /**
     * Whether the active item's freeform input currently holds text. The skin
     * needs it to decide whether an arrow key moves focus or edits the draft.
     */
    public function currentInputHasText(cx:AppContext):Bool {
        final itemIx = current;
        if (itemIx == null) return false;
        final input = items[itemIx].input();
        return input != null && !QuestionnaireAnswer.isWhitespaceOnly(input.state().read(cx).value());
    }

    public function focusedCurrentChoice(window:Window):Null<String> {
        final ix = current;
        if (ix == null) return null;
        final handles = runtime[ix].choiceFocusHandles;
        for (choiceIx in 0...handles.length) {
            if (handles[choiceIx].isFocused(window)) return items[ix].choices()[choiceIx].value();
        }
        return null;
    }

    public inline function shortcutMode():Null<QuestionnaireShortcutMode> {
        return shortcutModeValue;
    }

    public function shortcutForChoice(item:String, value:String):Null<String> {
        final mode = shortcutModeValue;
        if (mode == null) return null;
        final itemIx = itemIxOpt(item);
        if (itemIx == -1) return null;
        final choiceIx = choiceIxOpt(itemIx, value);
        if (choiceIx == -1) return null;
        if (runtime[itemIx].disabled || runtime[itemIx].choiceDisabled[choiceIx]) {
            return null;
        }
        var count = 0;
        for (ix in 0...choiceIx + 1) {
            if (!runtime[itemIx].choiceDisabled[ix]) count++;
        }
        if (count == 0) return null;
        final enabledPosition = count - 1;
        return switch mode {
            case Letters if (enabledPosition < 26): String.fromCharCode('A'.code + enabledPosition);
            case Numbers if (enabledPosition < 9): Std.string(enabledPosition + 1);
            case _: null;
        }
    }

    public function choiceForShortcut(item:String, key:String):Null<String> {
        final itemIx = itemIxOpt(item);
        if (itemIx == -1) return null;
        for (choice in items[itemIx].choices()) {
            final shortcut = shortcutForChoice(item, choice.value());
            if (shortcut != null && eqIgnoreAsciiCase(shortcut, key)) return choice.value();
        }
        return null;
    }

    public function activateShortcut(key:String, window:Window, cx:Context<QuestionnaireState>):Bool {
        final itemIx = current;
        if (itemIx == null) return false;
        final item = items[itemIx].name();
        final choice = choiceForShortcut(item, key);
        if (choice == null) return false;
        return choose(item, choice, window, cx) == null;
    }

    public function setCurrentItem(name:String, window:Window, cx:Context<QuestionnaireState>):Null<QuestionnaireSchemaError> {
        final ix = itemIxOpt(name);
        if (ix == -1) return UnknownItem(name);
        if (!runtime[ix].disabled) {
            dropPendingConfirm();
            current = ix;
            focusCurrentItem(window, cx);
            notify(cx);
        }
        return null;
    }

    public function setAnswer(item:String, answer:QuestionnaireAnswer, window:Window, cx:Context<QuestionnaireState>):Null<QuestionnaireSchemaError> {
        final itemIx = itemIxOpt(item);
        if (itemIx == -1) return UnknownItem(item);
        final before = effectiveAnswer(itemIx);
        final beforeStatus = status(itemIx);
        final answer = answer.clone();
        if (answer.freeformValue != null && QuestionnaireAnswer.isWhitespaceOnly(answer.freeformValue)) {
            answer.freeformValue = null;
        }
        final error = checkAnswer(itemIx, answer);
        if (error != null) return error;
        answer.choiceValues = [for (choice in items[itemIx].choices()) if (answer.choiceValues.indexOf(choice.value()) != -1) choice.value()];
        runtime[itemIx].answer = answer.clone();
        runtime[itemIx].skipped = false;
        final input = items[itemIx].input();
        final value = answer.freeform();
        if (input != null && value != null) {
            input.state().update(cx, (input, c) -> input.setValue(value, window, cast c));
        }
        if (!before.equals(effectiveAnswer(itemIx)) || beforeStatus != status(itemIx)) {
            answerDidChange(itemIx, false, cx);
        }
        return null;
    }

    public function setInputValue(item:String, value:String, window:Window, cx:Context<QuestionnaireState>):Null<QuestionnaireSchemaError> {
        final itemIx = itemIxOpt(item);
        if (itemIx == -1) return UnknownItem(item);
        final definition = items[itemIx].input();
        if (definition == null) {
            return AnswerDoesNotMatchItem(items[itemIx].name());
        }
        definition.state().update(cx, (input, c) -> input.setValue(value, window, cast c));
        syncInputAnswer(itemIx, false, cx);
        return null;
    }

    public function setItemDisabled(name:String, disabled:Bool, window:Window, cx:Context<QuestionnaireState>):Null<QuestionnaireSchemaError> {
        final ix = itemIxOpt(name);
        if (ix == -1) return UnknownItem(name);
        if (runtime[ix].disabled == disabled) {
            return null;
        }
        runtime[ix].disabled = disabled;
        dropPendingConfirm();
        final input = items[ix].input();
        if (input != null) {
            final inputDisabled = disabled || runtime[ix].inputDisabled;
            input.state().update(cx, (input, c) -> input.setDisabled(inputDisabled, cast c));
        }
        complete = false;
        if (current == ix && disabled) {
            final enabled = enabledIndices();
            var next:Null<Int> = null;
            for (candidate in enabled) {
                if (candidate > ix) {
                    next = candidate;
                    break;
                }
            }
            if (next == null) {
                var i = enabled.length - 1;
                while (i >= 0) {
                    if (enabled[i] < ix) {
                        next = enabled[i];
                        break;
                    }
                    i--;
                }
            }
            current = next;
            focusCurrentItem(window, cx);
        }
        else if (current == null && !disabled) {
            current = ix;
            focusCurrentItem(window, cx);
        }
        notify(cx);
        return null;
    }

    public function setChoiceDisabled(item:String, value:String, disabled:Bool, cx:Context<QuestionnaireState>):Null<QuestionnaireSchemaError> {
        final itemIx = itemIxOpt(item);
        if (itemIx == -1) return UnknownItem(item);
        final choiceIx = choiceIxOpt(itemIx, value);
        if (choiceIx == -1) return UnknownChoice(items[itemIx].name(), value);
        if (runtime[itemIx].choiceDisabled[choiceIx] == disabled) {
            return null;
        }
        runtime[itemIx].choiceDisabled[choiceIx] = disabled;
        answerDidChange(itemIx, false, cx);
        return null;
    }

    public function setExternalError(item:String, error:String, cx:Context<QuestionnaireState>):Null<QuestionnaireSchemaError> {
        final ix = itemIxOpt(item);
        if (ix == -1) return UnknownItem(item);
        runtime[ix].externalError = Message(error);
        complete = false;
        notify(cx);
        return null;
    }

    public function clearExternalError(item:String, cx:Context<QuestionnaireState>):Null<QuestionnaireSchemaError> {
        final ix = itemIxOpt(item);
        if (ix == -1) return UnknownItem(item);
        runtime[ix].externalError = null;
        notify(cx);
        return null;
    }

    public function reset(window:Window, cx:Context<QuestionnaireState>):Void {
        for (ix in 0...items.length) {
            final initial = runtime[ix].initialAnswer.clone();
            runtime[ix].answer = initial;
            runtime[ix].skipped = false;
            runtime[ix].validationAttempted = false;
            runtime[ix].internalError = null;
            final input = items[ix].input();
            if (input != null) {
                final initialValue = runtime[ix].initialInputValue;
                final value = initialValue != null ? initialValue : '';
                input.state().update(cx, (input, c) -> input.setValue(value, window, cast c));
            }
        }
        complete = false;
        dropPendingConfirm();
        final initialCurrent = this.initialCurrent;
        var current:Null<Int> = null;
        if (initialCurrent != null) {
            final ix = itemIxOpt(initialCurrent);
            if (ix != -1) current = ix;
        }
        if (current != null && runtime[current].disabled) {
            final enabled = enabledIndices();
            current = enabled.length > 0 ? enabled[0] : null;
        }
        this.current = current;
        focusCurrentItem(window, cx);
        notify(cx);
    }

    /**
     * Selects a choice, or toggles it on a multiple-answer item, without
     * confirming the item. Arrow-key movement inside a radio group uses this;
     * a person's click, Space, Enter or shortcut goes through `choose`.
     */
    public function activateChoice(item:String, value:String, cx:Context<QuestionnaireState>):Null<QuestionnaireSchemaError> {
        final itemIx = itemIxOpt(item);
        if (itemIx == -1) return UnknownItem(item);
        final choiceIx = choiceIxOpt(itemIx, value);
        if (choiceIx == -1) return UnknownChoice(items[itemIx].name(), value);
        if (runtime[itemIx].disabled || runtime[itemIx].choiceDisabled[choiceIx]) {
            return null;
        }
        final before = effectiveAnswer(itemIx);
        final beforeStatus = status(itemIx);

        final answer = runtime[itemIx].answer;
        if (items[itemIx].isMultiple()) {
            final selected = answer.choiceValues.indexOf(value);
            if (selected != -1) {
                answer.choiceValues.splice(selected, 1);
            }
            else {
                answer.choiceValues.push(value);
            }
        }
        else {
            answer.choiceValues = [value];
            answer.freeformValue = null;
        }
        runtime[itemIx].skipped = false;
        if (!before.equals(effectiveAnswer(itemIx)) || beforeStatus != status(itemIx)) {
            answerDidChange(itemIx, true, cx);
        }
        return null;
    }

    /**
     * Applies a person's activation of a choice: a click, Space or Enter on the
     * focused choice, or its shortcut.
     *
     * A multiple-answer item only toggles the choice. A single-answer item
     * selects it and then confirms the current item as `confirmCurrent` does:
     * it moves to the next enabled item, or submits on the last one, unless
     * validation fails. A choice that changes the answer stays selected on
     * screen for a moment before the confirm runs, so the person sees what
     * they picked; with reduced motion the confirm runs as soon as the answer
     * change has been delivered. Choosing the selected answer again confirms
     * at once. Disabled items and choices ignore activation.
     *
     * Arrow-key movement inside a radio group uses `activateChoice` and never
     * confirms.
     */
    public function choose(item:String, value:String, window:Window, cx:Context<QuestionnaireState>):Null<QuestionnaireSchemaError> {
        final itemIx = itemIxOpt(item);
        if (itemIx == -1) return UnknownItem(item);
        final choiceIx = choiceIxOpt(itemIx, value);
        if (choiceIx == -1) return UnknownChoice(items[itemIx].name(), value);
        if (runtime[itemIx].disabled || runtime[itemIx].choiceDisabled[choiceIx]) {
            return null;
        }
        final before = effectiveAnswer(itemIx);
        final error = activateChoice(item, value, cx);
        if (error != null) return error;
        focusChoice(item, value, window, cx);
        if (items[itemIx].isMultiple() || current != itemIx) {
            return null;
        }
        if (before.equals(effectiveAnswer(itemIx))) {
            confirmCurrent(window, cx);
        }
        else {
            scheduleConfirm(itemIx, window, cx);
        }
        return null;
    }

    /**
     * Confirms `itemIx` after the selection has had time to show. The task
     * runs on the next turn of the event loop at the earliest, after
     * `AnswerChanged` subscribers have reacted (a host enabling a follow-up
     * item, say), and does nothing if another item became current meanwhile.
     */
    function scheduleConfirm(itemIx:Int, window:Window, cx:Context<QuestionnaireState>):Void {
        final delay:Null<Float> = !cx.app.reduceMotion() ? CHOICE_CONFIRM_DELAY : null;
        dropPendingConfirm();
        pendingConfirm = cx.spawn((this_, acx) -> {
            final run = () -> {
                if (window.isDestroyed()) return;
                this_.tryUpdate(acx, (this_, cx) -> {
                    this_.pendingConfirm = null;
                    if (this_.current == itemIx) {
                        this_.confirmCurrent(window, cx);
                    }
                });
            };
            if (delay != null) {
                return cast acx.backgroundExecutor().timer(delay).then(_ -> run());
            }
            run();
            return null;
        });
    }

    /** Rust `self.pending_confirm = None`: dropping the task cancels it. */
    function dropPendingConfirm():Void {
        final task = pendingConfirm;
        pendingConfirm = null;
        if (task != null) task.cancel();
    }

    public function confirmCurrent(window:Window, cx:Context<QuestionnaireState>):Bool {
        final currentIx = this.currentIx();
        if (currentIx == null) return false;
        if (currentIx + 1 == total()) {
            return submit(window, cx);
        }
        else {
            return goNext(window, cx);
        }
    }

    public function goPrevious(window:Window, cx:Context<QuestionnaireState>):Bool {
        dropPendingConfirm();
        final ix = currentIx();
        if (ix == null) return false;
        final enabled = enabledIndices();
        if (ix == 0) {
            return false;
        }
        changeCurrent(enabled[ix - 1], true, window, cx);
        return true;
    }

    public function goNext(window:Window, cx:Context<QuestionnaireState>):Bool {
        dropPendingConfirm();
        final current = this.current;
        if (current == null) return false;
        if (!validateItem(current)) {
            focusInvalidItem(items[current].name(), window, cx);
            notify(cx);
            return false;
        }
        final ix = currentIx();
        if (ix == null) return false;
        final enabled = enabledIndices();
        if (ix + 1 >= enabled.length) {
            return false;
        }
        changeCurrent(enabled[ix + 1], true, window, cx);
        return true;
    }

    public function skipCurrent(window:Window, cx:Context<QuestionnaireState>):Bool {
        final ix = current;
        if (ix == null) return false;
        if (items[ix].isRequired()) {
            return false;
        }
        runtime[ix].answer = new QuestionnaireAnswer();
        runtime[ix].skipped = true;
        complete = false;
        emitAnswerChanged(ix, cx);
        final currentIx = this.currentIx();
        if (currentIx != null && currentIx + 1 == total()) {
            return submit(window, cx);
        }
        else {
            return goNext(window, cx);
        }
    }

    public function submit(window:Window, cx:Context<QuestionnaireState>):Bool {
        dropPendingConfirm();
        final enabled = enabledIndices();
        var firstInvalid:Null<Int> = null;
        for (ix in enabled) {
            if (!validateItem(ix) && firstInvalid == null) {
                firstInvalid = ix;
            }
        }
        if (firstInvalid != null) {
            changeCurrent(firstInvalid, true, window, cx);
            focusInvalidItem(items[firstInvalid].name(), window, cx);
            notify(cx);
            return false;
        }

        final submission = this.submission();
        if (!complete) {
            complete = true;
            cx.emit(QuestionnaireEvent.Completed(submission));
        }
        cx.emit(QuestionnaireEvent.Submit(submission));
        notify(cx);
        return true;
    }

    public function focusCurrentItem(window:Window, cx:AppContext):Bool {
        final ix = current;
        if (ix == null) return false;
        runtime[ix].focusHandle.focus(window, cx);
        return true;
    }

    public function focusInvalidItem(item:String, window:Window, cx:AppContext):Bool {
        final itemIx = itemIxOpt(item);
        if (itemIx == -1) return false;
        final runtime = this.runtime[itemIx];
        final inputFocusHandle = runtime.inputFocusHandle;
        if (runtime.answer.freeform() != null && !runtime.inputDisabled && inputFocusHandle != null) {
            inputFocusHandle.focus(window, cx);
            return true;
        }
        final choices = items[itemIx].choices();
        for (choiceIx in 0...choices.length) {
            if (runtime.answer.choiceValues.indexOf(choices[choiceIx].value()) != -1 && !runtime.choiceDisabled[choiceIx]) {
                runtime.choiceFocusHandles[choiceIx].focus(window, cx);
                return true;
            }
        }
        for (choiceIx in 0...runtime.choiceDisabled.length) {
            if (!runtime.choiceDisabled[choiceIx]) {
                runtime.choiceFocusHandles[choiceIx].focus(window, cx);
                return true;
            }
        }
        if (!runtime.inputDisabled && inputFocusHandle != null) {
            inputFocusHandle.focus(window, cx);
            return true;
        }
        runtime.focusHandle.focus(window, cx);
        return true;
    }

    public function focusChoice(item:String, value:String, window:Window, cx:AppContext):Bool {
        final itemIx = itemIxOpt(item);
        if (itemIx == -1) return false;
        final choiceIx = choiceIxOpt(itemIx, value);
        if (choiceIx == -1) return false;
        runtime[itemIx].choiceFocusHandles[choiceIx].focus(window, cx);
        return true;
    }

    public function focusInput(item:String, window:Window, cx:AppContext):Bool {
        final itemIx = itemIxOpt(item);
        if (itemIx == -1) return false;
        final focusHandle = runtime[itemIx].inputFocusHandle;
        if (focusHandle == null) return false;
        focusHandle.focus(window, cx);
        return true;
    }

    public function focusPreviousAnswer(window:Window, cx:Context<QuestionnaireState>):Bool {
        return focusAdjacentAnswer(-1, window, cx);
    }

    public function focusNextAnswer(window:Window, cx:Context<QuestionnaireState>):Bool {
        return focusAdjacentAnswer(1, window, cx);
    }

    public function moveCurrentRadio(direction:Int, window:Window, cx:Context<QuestionnaireState>):Bool {
        final itemIx = current;
        if (itemIx == null) return false;
        if (items[itemIx].isMultiple() || isCurrentInputFocused(window)) {
            return false;
        }
        final runtime = this.runtime[itemIx];
        final enabled = [for (ix in 0...runtime.choiceDisabled.length) if (!runtime.choiceDisabled[ix]) ix];
        if (enabled.length == 0) {
            return false;
        }
        var current:Null<Int> = null;
        for (position in 0...enabled.length) {
            if (runtime.choiceFocusHandles[enabled[position]].isFocused(window)) {
                current = position;
                break;
            }
        }
        if (current == null) {
            for (position in 0...enabled.length) {
                if (runtime.answer.choiceValues.indexOf(items[itemIx].choices()[enabled[position]].value()) != -1) {
                    current = position;
                    break;
                }
            }
        }
        final target = if (current != null) {
            direction < 0 ? (current == 0 ? enabled.length - 1 : current - 1) : (current + 1) % enabled.length;
        }
        else {
            direction < 0 ? enabled.length - 1 : 0;
        }
        final choiceIx = enabled[target];
        final item = items[itemIx].name();
        final choice = items[itemIx].choices()[choiceIx].value();
        activateChoice(item, choice, cx);
        runtime.choiceFocusHandles[choiceIx].focus(window, cx.app);
        return true;
    }

    function focusAdjacentAnswer(direction:Int, window:Window, cx:Context<QuestionnaireState>):Bool {
        final itemIx = current;
        if (itemIx == null) return false;
        if (isCurrentInputFocused(window) && currentInputHasText(cx)) {
            return false;
        }

        final runtime = this.runtime[itemIx];
        // A target is a choice index, or INPUT_TARGET for the freeform input.
        final targets:Array<Int> = [];
        for (choiceIx in 0...items[itemIx].choices().length) {
            if (!runtime.choiceDisabled[choiceIx]) {
                targets.push(choiceIx);
            }
        }
        if (items[itemIx].input() != null && !runtime.inputDisabled) {
            targets.push(INPUT_TARGET);
        }
        if (targets.length == 0) {
            return false;
        }

        var focused:Null<Int> = null;
        for (ix in 0...targets.length) {
            final target = targets[ix];
            final isFocused = target == INPUT_TARGET ? isCurrentInputFocused(window) : runtime.choiceFocusHandles[target].isFocused(window);
            if (isFocused) {
                focused = ix;
                break;
            }
        }

        if (focused == null && runtime.focusHandle.isFocused(window)) {
            final filled:Array<Int> = [];
            for (ix in 0...targets.length) {
                final target = targets[ix];
                if (target == INPUT_TARGET) {
                    if (runtime.answer.freeform() != null) filled.push(ix);
                }
                else if (runtime.answer.choiceValues.indexOf(items[itemIx].choices()[target].value()) != -1) {
                    filled.push(ix);
                }
            }
            final filledIx:Null<Int> = filled.length == 0 ? null : (direction < 0 ? filled[filled.length - 1] : filled[0]);
            if (filledIx != null) {
                final target = targets[filledIx];
                if (target == INPUT_TARGET) {
                    final focusHandle = runtime.inputFocusHandle;
                    if (focusHandle != null) focusHandle.focus(window, cx.app);
                }
                else {
                    runtime.choiceFocusHandles[target].focus(window, cx.app);
                }
                return true;
            }
        }

        final targetIx = if (focused != null) {
            direction < 0 ? (focused == 0 ? targets.length - 1 : focused - 1) : (focused + 1) % targets.length;
        }
        else {
            direction < 0 ? targets.length - 1 : 0;
        }

        // GPUI's Radio primitive intentionally leaves group arrow behavior to
        // its owner. Let the root emulate native radio movement only when both
        // adjacent answers are radios; crossing the boundary to an Input stays
        // in this schema-ordered answer sequence.
        if (!items[itemIx].isMultiple() && focused != null && targets[focused] != INPUT_TARGET && targets[targetIx] != INPUT_TARGET) {
            return false;
        }

        final target = targets[targetIx];
        if (target != INPUT_TARGET) {
            if (!items[itemIx].isMultiple()) {
                final item = items[itemIx].name();
                final choice = items[itemIx].choices()[target].value();
                activateChoice(item, choice, cx);
            }
            runtime.choiceFocusHandles[target].focus(window, cx.app);
        }
        else {
            final focusHandle = runtime.inputFocusHandle;
            if (focusHandle != null) focusHandle.focus(window, cx.app);
        }
        return true;
    }

    static inline final INPUT_TARGET:Int = -1;

    function onInputChange(input:Entity<InputState>, cx:Context<QuestionnaireState>):Void {
        final ix = inputItemIx(input);
        if (ix != -1) {
            syncInputAnswer(ix, true, cx);
        }
    }

    function syncInputAnswer(itemIx:Int, emit:Bool, cx:Context<QuestionnaireState>):Void {
        if (runtime[itemIx].disabled || runtime[itemIx].inputDisabled) {
            return;
        }
        final before = effectiveAnswer(itemIx);
        final beforeStatus = status(itemIx);
        final input = items[itemIx].input();
        if (input == null) return;
        final value = input.state().read(cx).value();
        if (QuestionnaireAnswer.isWhitespaceOnly(value)) {
            runtime[itemIx].answer.freeformValue = null;
        }
        else {
            if (!items[itemIx].isMultiple()) {
                runtime[itemIx].answer.choiceValues = [];
            }
            runtime[itemIx].answer.freeformValue = value;
            runtime[itemIx].skipped = false;
        }
        if (!before.equals(effectiveAnswer(itemIx)) || beforeStatus != status(itemIx)) {
            answerDidChange(itemIx, emit, cx);
        }
    }

    function answerDidChange(itemIx:Int, emit:Bool, cx:Context<QuestionnaireState>):Void {
        dropPendingConfirm();
        if (runtime[itemIx].validationAttempted) {
            validateItem(itemIx);
        }
        else {
            runtime[itemIx].internalError = null;
        }
        complete = false;
        if (emit) {
            emitAnswerChanged(itemIx, cx);
        }
        notify(cx);
    }

    function emitAnswerChanged(itemIx:Int, cx:Context<QuestionnaireState>):Void {
        cx.emit(QuestionnaireEvent.AnswerChanged(new QuestionnaireAnswerChange(items[itemIx].name(), effectiveAnswer(itemIx), status(itemIx))));
    }

    function validateItem(itemIx:Int):Bool {
        if (runtime[itemIx].disabled || runtime[itemIx].skipped) {
            return true;
        }
        runtime[itemIx].validationAttempted = true;
        final answer = effectiveAnswer(itemIx);
        final validator = items[itemIx].validator();
        final error:Null<QuestionnaireValidationError> = if (answer.isEmpty()) {
            items[itemIx].isRequired() ? Required : Unanswered;
        }
        else if (validator != null) {
            final message = validator(new QuestionnaireValidationContext(items[itemIx].name(), answer, answers()));
            message != null ? Message(message) : null;
        }
        else {
            null;
        }
        runtime[itemIx].internalError = error;
        return errorAt(itemIx) == null;
    }

    function submission():QuestionnaireSubmission {
        return new QuestionnaireSubmission([
            for (ix in enabledIndices()) new QuestionnaireSubmissionItem(items[ix].name(), status(ix), effectiveAnswer(ix))
        ]);
    }

    function status(itemIx:Int):QuestionnaireItemStatus {
        return if (runtime[itemIx].skipped) {
            Skipped;
        }
        else if (effectiveAnswer(itemIx).isEmpty()) {
            Unanswered;
        }
        else {
            Answered;
        }
    }

    function effectiveAnswer(itemIx:Int):QuestionnaireAnswer {
        final answer = new QuestionnaireAnswer();
        final runtime = this.runtime[itemIx];
        if (runtime.disabled) {
            return answer;
        }
        answer.choiceValues = [
            for (choice in items[itemIx].choices()) {
                if (runtime.answer.choiceValues.indexOf(choice.value()) != -1) {
                    final ix = choiceIxOpt(itemIx, choice.value());
                    if (ix != -1 && !runtime.choiceDisabled[ix]) choice.value();
                }
            }
        ];
        answer.freeformValue = !runtime.inputDisabled ? runtime.answer.freeformValue : null;
        return answer;
    }

    function errorAt(itemIx:Int):Null<QuestionnaireValidationError> {
        final runtime = this.runtime[itemIx];
        if (runtime.skipped || runtime.disabled) {
            return null;
        }
        if (runtime.externalError != null) return runtime.externalError;
        return runtime.validationAttempted ? runtime.internalError : null;
    }

    function checkAnswer(itemIx:Int, answer:QuestionnaireAnswer):Null<QuestionnaireSchemaError> {
        final item = items[itemIx];
        final sources = answer.choiceValues.length + (answer.freeformValue != null ? 1 : 0);
        if ((!item.isMultiple() && sources > 1) || (answer.freeformValue != null && item.input() == null)) {
            return AnswerDoesNotMatchItem(item.name());
        }
        for (choice in answer.choiceValues) {
            final choiceIx = choiceIxOpt(itemIx, choice);
            if (choiceIx == -1) return UnknownChoice(item.name(), choice);
            if (runtime[itemIx].choiceDisabled[choiceIx]) {
                return AnswerDoesNotMatchItem(item.name());
            }
        }
        return null;
    }

    function changeCurrent(next:Null<Int>, emit:Bool, window:Window, cx:Context<QuestionnaireState>):Void {
        if (current == next) {
            return;
        }
        dropPendingConfirm();
        final previousIx = current;
        final previous = previousIx != null ? items[previousIx].name() : null;
        current = next;
        focusCurrentItem(window, cx);
        if (emit) {
            cx.emit(QuestionnaireEvent.CurrentItemChanged(previous, next != null ? items[next].name() : null));
        }
        notify(cx);
    }

    /** Rust `cx.notify()`, plus the invalidation of the observed runtime. */
    function notify(cx:Context<QuestionnaireState>):Void {
        invalidateRuntime();
        cx.notify();
    }

    function enabledIndices():Array<Int> {
        final runtime = this.runtime;
        return [for (ix in 0...runtime.length) if (!runtime[ix].disabled) ix];
    }

    function itemIxOpt(name:String):Int {
        for (ix in 0...items.length) {
            if (items[ix].name() == name) return ix;
        }
        return -1;
    }

    function choiceIxOpt(itemIx:Int, value:String):Int {
        final choices = items[itemIx].choices();
        for (ix in 0...choices.length) {
            if (choices[ix].value() == value) return ix;
        }
        return -1;
    }

    function inputItemIx(input:Entity<InputState>):Int {
        for (ix in 0...items.length) {
            final definition = items[ix].input();
            if (definition != null && definition.state().entityId() == input.entityId()) return ix;
        }
        return -1;
    }

    /** Rust `str::eq_ignore_ascii_case`. */
    static function eqIgnoreAsciiCase(a:String, b:String):Bool {
        if (a.length != b.length) return false;
        for (i in 0...a.length) {
            var x = StringTools.fastCodeAt(a, i);
            var y = StringTools.fastCodeAt(b, i);
            if (x >= 'a'.code && x <= 'z'.code) x -= 32;
            if (y >= 'a'.code && y <= 'z'.code) y -= 32;
            if (x != y) return false;
        }
        return true;
    }

}
