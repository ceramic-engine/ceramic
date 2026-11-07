// Ported from gpui-kit 0.8.1: crates/base/src/questionnaire/state.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.Base;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputState;
import glaze.kit.base.questionnaire.QuestionnaireAnswer;
import glaze.kit.base.questionnaire.QuestionnaireChoiceDefinition;
import glaze.kit.base.questionnaire.QuestionnaireEvent;
import glaze.kit.base.questionnaire.QuestionnaireInputDefinition;
import glaze.kit.base.questionnaire.QuestionnaireItemDefinition;
import glaze.kit.base.questionnaire.QuestionnaireItemStatus;
import glaze.kit.base.questionnaire.QuestionnaireSchemaError;
import glaze.kit.base.questionnaire.QuestionnaireShortcutMode;
import glaze.kit.base.questionnaire.QuestionnaireState;
import glaze.kit.base.questionnaire.QuestionnaireValidationError;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The `#[cfg(test)]` tests of gpui-base's questionnaire state.
 */
class BaseQuestionnaireTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> Base.init(cx));
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    public static function eventName(event:QuestionnaireEvent):String {
        return switch event {
            case CurrentItemChanged(_, _): 'current';
            case AnswerChanged(_): 'answer';
            case Completed(_): 'completed';
            case Submit(_): 'submit';
        }
    }

    function harness():{harness:Entity<QuestionnaireHarness>, state:Entity<QuestionnaireState>, firstInput:Entity<InputState>, secondInput:Entity<InputState>,
        cx:VisualTestContext} {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<QuestionnaireHarness>) -> new QuestionnaireHarness(window, cx));
        contexts.push(opened.cx);
        final h = opened.view.read(app);
        return {harness: opened.view, state: h.state, firstInput: h.firstInput, secondInput: h.secondInput, cx: opened.cx};
    }

    static function update<R>(cx:VisualTestContext, state:Entity<QuestionnaireState>, f:(QuestionnaireState, Window, Context<QuestionnaireState>) -> R):R {
        return cx.update((window, app) -> state.update(app, (state, c) -> f(state, window, c)));
    }

    static function choiceList(answer:Null<QuestionnaireAnswer>):String {
        return answer == null ? 'null' : answer.choices().join(',');
    }

    function assertEnum(expected:Dynamic, actual:Dynamic, ?pos:haxe.PosInfos):Void {
        assertTrue(actual != null && Type.enumEq(expected, actual), pos);
    }

    function testSchemaRejectsDuplicateNamesAndInvalidSingleDefaults() {
        final duplicateItems = [new QuestionnaireItemDefinition('same', 'One'), new QuestionnaireItemDefinition('same', 'Two')];
        assertEnum(QuestionnaireSchemaError.DuplicateItem('same'), @:privateAccess QuestionnaireState.validateSchema(duplicateItems));

        final invalidDefault = [
            new QuestionnaireItemDefinition('single', 'Single').withChoices([
                new QuestionnaireChoiceDefinition('a', 'A').withDefaultSelected(true),
                new QuestionnaireChoiceDefinition('b', 'B').withDefaultSelected(true),
            ])
        ];
        assertEnum(QuestionnaireSchemaError.MultipleDefaultsForSingleItem('single'), @:privateAccess QuestionnaireState.validateSchema(invalidDefault));

        final duplicateChoice = [
            new QuestionnaireItemDefinition('item', 'Item').withChoices([
                new QuestionnaireChoiceDefinition('same', 'One'),
                new QuestionnaireChoiceDefinition('same', 'Two'),
            ])
        ];
        assertEnum(QuestionnaireSchemaError.DuplicateChoice('item', 'same'), @:privateAccess QuestionnaireState.validateSchema(duplicateChoice));
    }

    function testValidatesNavigatesSkipsAndEmitsCompletionBeforeSubmit() {
        final h = harness();
        final state = h.state;
        final cx = h.cx;

        assertEquals(1, state.read(app).progress().current());
        assertEquals(2, state.read(app).progress().total());
        assertEquals(QuestionnaireItemStatus.Unanswered, state.read(app).itemState('first').status());
        assertFalse(update(cx, state, (s, w, c) -> s.submit(w, c)));
        assertTrue(state.read(app).error('first') != null);
        assertEnum(QuestionnaireValidationError.Message('Use the valid answer'), state.read(app).error('second'));

        update(cx, state, (s, w, c) -> s.setInputValue('first', 'draft', w, c));
        assertTrue(state.read(app).error('first') == null);
        update(cx, state, (s, w, c) -> s.setInputValue('first', '', w, c));
        // once validation has been attempted, clearing an answer updates the error live
        assertTrue(state.read(app).error('first') != null);

        state.update(app, (s, c) -> s.activateChoice('first', 'a', c));
        assertTrue(update(cx, state, (s, w, c) -> s.goNext(w, c)));
        assertEquals('second', state.read(app).currentItem());
        assertTrue(update(cx, state, (s, w, c) -> s.skipCurrent(w, c)));

        assertTrue(state.read(app).isComplete());
        assertEquals(QuestionnaireItemStatus.Skipped, state.read(app).itemState('second').status());
        assertEquals('answer,current,answer,completed,submit', h.harness.read(app).events.join(','));
    }

    function testKeepsInputDraftSeparateAndSynchronizesSilentSettersAndReset() {
        final h = harness();
        final state = h.state;
        final cx = h.cx;
        final initialEvents = h.harness.read(app).events.length;

        assertNull(update(cx, state, (s, w, c) -> s.setAnswer('first', new QuestionnaireAnswer().withFreeform('  custom  '), w, c)));
        // programmatic setters are silent
        assertEquals(initialEvents, h.harness.read(app).events.length);
        assertEquals('  custom  ', h.firstInput.read(app).value());
        assertEquals('  custom  ', state.read(app).answer('first').freeform());

        assertNull(update(cx, state, (s, w, c) -> s.setAnswer('first', new QuestionnaireAnswer().withChoices(['a']), w, c)));
        assertEquals('  custom  ', h.firstInput.read(app).value());
        assertNull(state.read(app).answer('first').freeform());
        assertEquals('a', state.read(app).answer('first').choices()[0]);

        cx.update((window, app) -> h.firstInput.update(app, (input, c) -> input.replaceAll('', window, cast c)));
        cx.runUntilParked();
        // editing an unselected draft does not change the semantic answer
        assertEquals(initialEvents, h.harness.read(app).events.length);
        assertEquals('a', state.read(app).answer('first').choices()[0]);

        state.update(app, (s, c) -> s.activateChoice('first', 'b', c));

        update(cx, state, (s, w, c) -> {
            s.reset(w, c);
            return true;
        });
        assertEquals('', h.firstInput.read(app).value());
        assertEquals('initial draft', h.secondInput.read(app).value());
        assertTrue(state.read(app).answer('first').isEmpty());
        assertEquals('initial draft', state.read(app).answer('second').freeform());
        assertEquals(initialEvents + 1, h.harness.read(app).events.length);
    }

    function testValidatesAllItemsAndReturnsToTheFirstInvalidItem() {
        final h = harness();
        final state = h.state;
        final cx = h.cx;
        state.update(app, (s, c) -> s.activateChoice('first', 'a', c));

        assertFalse(update(cx, state, (s, w, c) -> s.submit(w, c)));
        assertEquals('second', state.read(app).currentItem());
        assertEnum(QuestionnaireValidationError.Message('Use the valid answer'), state.read(app).error('second'));

        state.update(app, (s, c) -> s.setExternalError('first', 'Server rejected it', c));
        assertFalse(update(cx, state, (s, w, c) -> s.submit(w, c)));
        assertEquals('first', state.read(app).currentItem());

        update(cx, state, (s, w, c) -> {
            s.clearExternalError('first', c);
            return s.setInputValue('second', 'valid', w, c);
        });
        assertTrue(update(cx, state, (s, w, c) -> s.submit(w, c)));
    }

    function testPreservesSchemaOrderAndTemporarilyExcludesDisabledAnswers() {
        final h = harness();
        final state = h.state;
        final cx = h.cx;

        assertNull(update(cx, state, (s, w, c) -> s.setAnswer('second', new QuestionnaireAnswer().withChoices(['y', 'x', 'y']).withFreeform('valid'), w, c)));
        assertEquals('x,y', choiceList(state.read(app).answer('second')));
        update(cx, state, (s, w, c) -> {
            s.setCurrentItem('second', w, c);
            s.focusCurrentItem(w, c);
            assertTrue(s.focusNextAnswer(w, c));
            return true;
        });
        // filled multiple choices are focused in schema order
        assertEquals('x', cx.update((window, app) -> state.read(app).focusedCurrentChoice(window)));
        // focusing a filled choice does not toggle it
        assertEquals('x,y', choiceList(state.read(app).answer('second')));

        state.update(app, (s, c) -> s.setChoiceDisabled('second', 'x', true, c));
        assertEquals('y', choiceList(state.read(app).answer('second')));
        state.update(app, (s, c) -> s.setChoiceDisabled('second', 'x', false, c));
        assertEquals('x,y', choiceList(state.read(app).answer('second')));

        final error = update(cx, state, (s, w, c) -> s.setAnswer('second', new QuestionnaireAnswer().withChoices(['unknown']), w, c));
        assertEnum(QuestionnaireSchemaError.UnknownChoice('second', 'unknown'), error);
    }

    function testShortcutsDisabledCurrentFallbackAndRecompletionAreDeterministic() {
        final h = harness();
        final state = h.state;
        final cx = h.cx;
        update(cx, state, (s, w, c) -> {
            s.setAnswer('first', new QuestionnaireAnswer().withChoices(['b']), w, c);
            s.focusCurrentItem(w, c);
            assertTrue(s.focusNextAnswer(w, c));
            return true;
        });
        // the first move from the item group focuses the existing answer
        assertEquals('b', cx.update((window, app) -> state.read(app).focusedCurrentChoice(window)));
        // focusing the filled radio does not replace the answer
        assertEquals('b', state.read(app).answer('first').choices()[0]);
        update(cx, state, (s, w, c) -> {
            s.reset(w, c);
            return true;
        });

        update(cx, state, (s, w, c) -> {
            s.focusInput('first', w, c);
            assertFalse(s.currentInputHasText(c));
            assertTrue(s.focusNextAnswer(w, c));
            return true;
        });
        // an empty focused input may move to and activate a radio
        assertEquals('a', state.read(app).answer('first').choices()[0]);
        update(cx, state, (s, w, c) -> {
            s.reset(w, c);
            return true;
        });

        update(cx, state, (s, w, c) -> {
            s.setInputValue('first', 'draft', w, c);
            s.focusInput('first', w, c);
            assertTrue(s.currentInputHasText(c));
            assertFalse(s.focusNextAnswer(w, c));
            return true;
        });
        assertTrue(cx.update((window, app) -> h.firstInput.read(app).focusHandle.isFocused(window)));
        update(cx, state, (s, w, c) -> {
            s.reset(w, c);
            return true;
        });

        assertTrue(update(cx, state, (s, w, c) -> {
            s.focusCurrentItem(w, c);
            return s.focusNextAnswer(w, c);
        }));
        // moving from the item group to a radio activates it
        assertEquals('a', state.read(app).answer('first').choices()[0]);
        update(cx, state, (s, w, c) -> {
            s.reset(w, c);
            return true;
        });

        assertEquals('A', state.read(app).shortcutForChoice('first', 'a'));
        state.update(app, (s, c) -> s.setChoiceDisabled('first', 'a', true, c));
        assertEquals('A', state.read(app).shortcutForChoice('first', 'b'));
        state.update(app, (s, c) -> s.setChoiceDisabled('first', 'a', false, c));
        update(cx, state, (s, w, c) -> {
            assertTrue(s.activateShortcut('a', w, c));
            s.focusChoice('first', 'a', w, c);
            assertTrue(s.moveCurrentRadio(1, w, c));
            assertTrue(s.goNext(w, c));
            assertTrue(s.skipCurrent(w, c));
            return true;
        });
        assertTrue(state.read(app).isComplete());

        update(cx, state, (s, w, c) -> {
            s.setInputValue('second', 'valid', w, c);
            return s.activateChoice('second', 'x', c);
        });
        assertFalse(state.read(app).isComplete());
        assertTrue(update(cx, state, (s, w, c) -> s.submit(w, c)));
        final events = h.harness.read(app).events.copy();
        assertEquals(2, events.filter(e -> e == 'completed').length);

        final beforeDisable = events.length;
        update(cx, state, (s, w, c) -> s.setItemDisabled('second', true, w, c));
        assertEquals('first', state.read(app).currentItem());
        // programmatic disable and fallback are silent
        assertEquals(beforeDisable, h.harness.read(app).events.length);
    }

/// ChooseHarness: two single-answer items around a multiple-answer one;
/// `rejected` fails validation on the first item.

    function chooseHarness():{harness:Entity<ChooseHarness>, state:Entity<QuestionnaireState>, cx:VisualTestContext} {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<ChooseHarness>) -> new ChooseHarness(window, cx));
        contexts.push(opened.cx);
        return {harness: opened.view, state: opened.view.read(app).state, cx: opened.cx};
    }

    static function choose(cx:VisualTestContext, state:Entity<QuestionnaireState>, item:String, value:String):Void {
        final error = update(cx, state, (s, w, c) -> s.choose(item, value, w, c));
        if (error != null) throw error;
    }

    function current(state:Entity<QuestionnaireState>):String {
        return state.read(app).currentItem();
    }

    static function waitOutHold(cx:VisualTestContext):Void {
        cx.advanceClock(QuestionnaireState.CHOICE_CONFIRM_DELAY);
        cx.runUntilParked();
    }

    function count(harness:Entity<ChooseHarness>, name:String):Int {
        return harness.read(app).events.filter(e -> e == name).length;
    }

    function testChoosingASingleAnswerHoldsItThenConfirms() {
        final h = chooseHarness();
        final state = h.state;
        final cx = h.cx;

        choose(cx, state, 'first', 'a');
        cx.runUntilParked();
        // the choice is shown before moving
        assertEquals('first', current(state));
        assertEquals('a', choiceList(state.read(app).answer('first')));
        waitOutHold(cx);
        assertEquals('second', current(state));

        // Going back and choosing the selected answer again confirms at once.
        update(cx, state, (s, w, c) -> s.goPrevious(w, c));
        choose(cx, state, 'first', 'a');
        assertEquals('second', current(state));

        // The last item submits once, even when activated twice in a row.
        choose(cx, state, 'second', 'x');
        update(cx, state, (s, w, c) -> s.goNext(w, c));
        assertEquals('third', current(state));
        choose(cx, state, 'third', 'c');
        choose(cx, state, 'third', 'c');
        waitOutHold(cx);
        assertEquals(1, count(h.harness, 'submit'));
        assertEquals(1, count(h.harness, 'completed'));

        // A second answer replaces the pending confirm instead of adding one.
        choose(cx, state, 'third', 'd');
        choose(cx, state, 'third', 'c');
        waitOutHold(cx);
        assertEquals(2, count(h.harness, 'submit'));
    }

    function testArrowsMultipleChoicesAndTypingNeverConfirm() {
        final h = chooseHarness();
        final state = h.state;
        final cx = h.cx;

        update(cx, state, (s, w, c) -> {
            s.focusChoice('first', 'a', w, c);
            assertTrue(s.moveCurrentRadio(1, w, c));
            return true;
        });
        waitOutHold(cx);
        // an arrow moves the selection
        assertEquals('b', choiceList(state.read(app).answer('first')));
        // an arrow never confirms
        assertEquals('first', current(state));

        // Typing after choosing drops the pending confirm.
        choose(cx, state, 'first', 'a');
        final input = h.harness.read(app).input;
        cx.update((window, app) -> input.update(app, (input, c) -> input.replaceAll('draft', window, cast c)));
        waitOutHold(cx);
        assertEquals('first', current(state));
        assertTrue(state.read(app).answer('first').freeform() != null);

        // A disabled choice ignores activation.
        choose(cx, state, 'first', 'off');
        waitOutHold(cx);
        assertEquals('first', current(state));

        update(cx, state, (s, w, c) -> s.goNext(w, c));
        choose(cx, state, 'second', 'x');
        choose(cx, state, 'second', 'y');
        choose(cx, state, 'second', 'x');
        waitOutHold(cx);
        // a multiple-answer item only toggles
        assertEquals('second', current(state));
        assertEquals('y', choiceList(state.read(app).answer('second')));
    }

    function testARejectedChoiceStaysOnItsItem() {
        final h = chooseHarness();
        final state = h.state;
        final cx = h.cx;

        choose(cx, state, 'first', 'rejected');
        waitOutHold(cx);
        assertEquals('first', current(state));
        assertEnum(QuestionnaireValidationError.Message('Pick another answer'), state.read(app).error('first'));
        // the invalid answer keeps focus
        assertEquals('rejected', cx.update((window, app) -> state.read(app).focusedCurrentChoice(window)));
        assertEquals(0, count(h.harness, 'current'));
    }

    function testReducedMotionConfirmsWithoutTheHold() {
        final h = chooseHarness();
        final state = h.state;
        final cx = h.cx;
        cx.update((_, app) -> app.setReduceMotion(true));

        choose(cx, state, 'first', 'a');
        // the confirm waits for the answer change to be delivered
        assertEquals('first', current(state));
        cx.runUntilParked();
        assertEquals('second', current(state));
    }

}

/** Rust `Harness` of the state tests. */
private class QuestionnaireHarness extends Model implements Render {

    public final state:Entity<QuestionnaireState>;

    public final firstInput:Entity<InputState>;

    public final secondInput:Entity<InputState>;

    public final events:Array<String> = [];

    public function new(window:Window, cx:Context<QuestionnaireHarness>) {
        super();
        firstInput = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
        secondInput = cx.newEntity((c:Context<InputState>) -> new InputState(window, c).defaultValue('initial draft'));
        final items = [
            new QuestionnaireItemDefinition('first', 'First question')
                .withRequired(true)
                .withChoices([new QuestionnaireChoiceDefinition('a', 'A'), new QuestionnaireChoiceDefinition('b', 'B')])
                .withInput(new QuestionnaireInputDefinition(firstInput, 'Another answer')),
            new QuestionnaireItemDefinition('second', 'Second question')
                .withMultiple(true)
                .withChoices([new QuestionnaireChoiceDefinition('x', 'X'), new QuestionnaireChoiceDefinition('y', 'Y')])
                .withInput(new QuestionnaireInputDefinition(secondInput, 'Another answer'))
                .withValidator(context -> context.answer().freeform() == 'valid' ? null : 'Use the valid answer'),
            new QuestionnaireItemDefinition('disabled', 'Disabled').withDisabled(true),
        ];
        state = cx.newEntity((c:Context<QuestionnaireState>) -> new QuestionnaireState(items, c).withShortcuts(Letters));
        cx.subscribe(state, QuestionnaireEvent, (this_, _, event, _) -> this_.events.push(BaseQuestionnaireTest.eventName(event)));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }

}

/** Rust `ChooseHarness` of the state tests. */
private class ChooseHarness extends Model implements Render {

    public final state:Entity<QuestionnaireState>;

    public final input:Entity<InputState>;

    public final events:Array<String> = [];

    public function new(window:Window, cx:Context<ChooseHarness>) {
        super();
        input = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
        final items = [
            new QuestionnaireItemDefinition('first', 'First')
                .withChoices([
                    new QuestionnaireChoiceDefinition('a', 'A'),
                    new QuestionnaireChoiceDefinition('b', 'B'),
                    new QuestionnaireChoiceDefinition('rejected', 'Rejected'),
                    new QuestionnaireChoiceDefinition('off', 'Off').withDisabled(true),
                ])
                .withInput(new QuestionnaireInputDefinition(input, 'Other'))
                .withValidator(context -> context.answer().choices().indexOf('rejected') == -1 ? null : 'Pick another answer'),
            new QuestionnaireItemDefinition('second', 'Second')
                .withMultiple(true)
                .withChoices([new QuestionnaireChoiceDefinition('x', 'X'), new QuestionnaireChoiceDefinition('y', 'Y')]),
            new QuestionnaireItemDefinition('third', 'Third').withChoices([new QuestionnaireChoiceDefinition('c', 'C'), new QuestionnaireChoiceDefinition('d', 'D')]),
        ];
        state = cx.newEntity((c:Context<QuestionnaireState>) -> new QuestionnaireState(items, c));
        cx.subscribe(state, QuestionnaireEvent, (this_, _, event, _) -> this_.events.push(BaseQuestionnaireTest.eventName(event)));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }

}
