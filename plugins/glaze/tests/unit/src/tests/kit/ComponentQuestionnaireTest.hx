// Ported from gpui-kit 0.8.1: crates/component/src/questionnaire/components.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Bounds;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.KeyDownEvent;
import gpui.KeyUpEvent;
import gpui.Keystroke;
import gpui.Model;
import gpui.OperatingSystem;
import gpui.Render;
import gpui.StyleRefinement;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.input.InputState;
import gpui.base.questionnaire.QuestionnaireChoiceDefinition;
import gpui.base.questionnaire.QuestionnaireEvent;
import gpui.base.questionnaire.QuestionnaireInputDefinition;
import gpui.base.questionnaire.QuestionnaireItemDefinition;
import gpui.base.questionnaire.QuestionnaireShortcutMode;
import gpui.base.questionnaire.QuestionnaireState;
import gpui.component.Component;
import gpui.component.Size;
import gpui.component.questionnaire.Questionnaire;
import gpui.component.theme.Theme;
import tests.kit.BaseOverlaysTest.OverlayProbe;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

/**
 * The `#[cfg(test)]` tests of gpui-component's questionnaire skin.
 *
 * Rust reads `debug_bounds` of the parts' `debug_selector`s; the port has no
 * debug selectors, so the harnesses wrap the same parts in `OverlayProbe`s
 * (which add no layout node of their own) under the same names. The
 * accesskit queries read the parts' `a11y` records.
 */
class ComponentQuestionnaireTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> {
            Component.init(cx);
            // The test fonts have no `Menlo` (the macOS monospace family of
            // the theme, used by the shortcut badges).
            Theme.globalMut(cx).monoFontFamily = 'JetBrains Mono';
            Theme.syncBase(cx);
        });
        OverlayProbe.reset();
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        OverlayProbe.reset();
        ceramic.App.app.flushImmediate();
    }

    function testCompoundPartsSupportBuilderCustomization() {
        final description = new QuestionnaireChoiceDescription().opacity(0.8).child('Description');
        assertEquals(0.8, description.style().opacity);
    }

/// Harnesses

    function open<V:Model & Render>(build:(Window, Context<V>) -> V):{view:Entity<V>, cx:VisualTestContext} {
        final opened = VisualTestContext.addWindowView(app, dispatcher, build);
        contexts.push(opened.cx);
        return opened;
    }

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
    }

    function visualHarness(items:Array<QuestionnaireItemDefinition>, shortcuts:Null<QuestionnaireShortcutMode>):{cx:VisualTestContext,
        state:Entity<QuestionnaireState>} {
        final opened = open((window, cx:Context<QuestionnaireHarness>) -> {
            final state = cx.newEntity((c:Context<QuestionnaireState>) -> {
                final state = new QuestionnaireState(items, c);
                shortcuts != null ? state.withShortcuts(shortcuts) : state;
            });
            new QuestionnaireHarness(state, false);
        });
        final cx = opened.cx;
        draw(cx);
        final state = opened.view.read(app).state;
        cx.update((window, app) -> state.read(app).focusHandle().focus(window, app));
        return {cx: cx, state: state};
    }

    function inputVisualHarness(multiple:Bool):{cx:VisualTestContext, state:Entity<QuestionnaireState>} {
        final opened = open((window, cx:Context<QuestionnaireHarness>) -> {
            final input = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
            final state = cx.newEntity((c:Context<QuestionnaireState>) -> new QuestionnaireState([
                new QuestionnaireItemDefinition('first', 'First')
                    .withRequired(true)
                    .withMultiple(multiple)
                    .withChoices([new QuestionnaireChoiceDefinition('alpha', 'Alpha'), new QuestionnaireChoiceDefinition('beta', 'Beta')])
                    .withInput(new QuestionnaireInputDefinition(input, 'Other')),
                new QuestionnaireItemDefinition('second', 'Second'),
            ], c));
            new QuestionnaireHarness(state, false);
        });
        final cx = opened.cx;
        draw(cx);
        return {cx: cx, state: opened.view.read(app).state};
    }

    function actionsVisualHarness(overrideSkipMargin:Bool):{cx:VisualTestContext, state:Entity<QuestionnaireState>} {
        final opened = open((window, cx:Context<QuestionnaireHarness>) -> {
            final state = cx.newEntity((c:Context<QuestionnaireState>) -> new QuestionnaireState([
                new QuestionnaireItemDefinition('first', 'First').withRequired(true),
                new QuestionnaireItemDefinition('second', 'Second'),
                new QuestionnaireItemDefinition('third', 'Third').withRequired(true),
            ], c).withCurrentItem('second'));
            new QuestionnaireHarness(state, overrideSkipMargin);
        });
        final cx = opened.cx;
        draw(cx);
        return {cx: cx, state: opened.view.read(app).state};
    }

    static function focusInput(cx:VisualTestContext, state:Entity<QuestionnaireState>, item:String):Void {
        cx.update((window, app) -> {
            final input = state.read(app).inputState(item);
            input.read(app).focusHandle.focus(window, app);
        });
    }

    static function simulateKey(cx:VisualTestContext, key:String, isHeld:Bool, simulateIme:Bool):Void {
        var keystroke = Keystroke.parseWithOs(key, OperatingSystem.current);
        if (simulateIme) {
            keystroke = keystroke.withSimulatedIme();
        }
        cx.simulateEvent(new KeyDownEvent(keystroke, isHeld, false));
    }

    static function bounds(cx:VisualTestContext, selector:String):Null<Bounds> {
        return OverlayProbe.debugBounds(cx.window, selector);
    }

/// Tests

    function testProgressProjectsNumericAccessibility() {
        final opened = open((window, cx:Context<QuestionnaireHarness>) -> {
            final state = cx.newEntity((c:Context<QuestionnaireState>) -> new QuestionnaireState([
                new QuestionnaireItemDefinition('first', 'First'),
                new QuestionnaireItemDefinition('second', 'Second'),
            ], c));
            new QuestionnaireHarness(state, false);
        });
        final state = opened.view.read(app).state;
        opened.cx.update((window, cx) -> {
            final progress = new QuestionnaireProgress(state);
            progress.render(window, cx);
            assertEquals(1., progress.a11y.numericValue);
            assertEquals(0., progress.a11y.minNumericValue);
            assertEquals(2., progress.a11y.maxNumericValue);

            final root = new Questionnaire(state);
            root.render(window, cx);
            assertEquals(Role.Form, root.a11y.role);
        });
    }

    function testActionsStayInsideQuestionnaireWidth() {
        final h = actionsVisualHarness(false);
        final cx = h.cx;
        final state = h.state;
        final root = bounds(cx, 'root');
        final actions = bounds(cx, 'actions');
        final previous = bounds(cx, 'Previous');
        final skip = bounds(cx, 'Skip');
        final next = bounds(cx, 'Next');
        assertTrue(root != null && actions != null && previous != null && skip != null && next != null);

        assertTrue(actions.left() >= root.left());
        assertTrue(actions.right() <= root.right());
        assertEquals(actions.left(), previous.left());
        assertTrue(previous.right() <= skip.left());
        assertTrue(skip.right() <= next.left());
        assertEquals(actions.right(), next.right());

        cx.update((window, app) -> {
            state.update(app, (state, c) -> state.setCurrentItem('first', window, c));
            window.draw();
        });
        final firstActions = bounds(cx, 'actions');
        final firstNext = bounds(cx, 'Next');
        assertTrue(firstNext.left() >= firstActions.left());
        assertEquals(firstActions.right(), firstNext.right());

        cx.update((window, app) -> {
            state.update(app, (state, c) -> state.setCurrentItem('third', window, c));
            window.draw();
        });
        final lastActions = bounds(cx, 'actions');
        final lastPrevious = bounds(cx, 'Previous');
        final submit = bounds(cx, 'Submit');
        assertEquals(lastActions.left(), lastPrevious.left());
        assertTrue(lastPrevious.right() <= submit.left());
        assertEquals(lastActions.right(), submit.right());
    }

    function testActionInstanceStyleOverridesDefaultTrailingAnchor() {
        final h = actionsVisualHarness(true);
        final cx = h.cx;
        final actions = bounds(cx, 'actions');
        final previous = bounds(cx, 'Previous');
        final skip = bounds(cx, 'Skip');
        final next = bounds(cx, 'Next');

        assertEquals(actions.left(), previous.left());
        assertTrue(previous.right() <= skip.left());
        assertTrue(skip.right() <= next.left());
        assertTrue(next.right() < actions.right());
    }

    function scaleHarness(rootSize:Size, partSize:Null<Size>):Bounds {
        OverlayProbe.reset();
        final opened = open((window, cx:Context<ScaleHarness>) -> {
            final state = cx.newEntity((c:Context<QuestionnaireState>) -> new QuestionnaireState([
                new QuestionnaireItemDefinition('scale', 'Scale').withChoice(new QuestionnaireChoiceDefinition('alpha', 'Alpha')),
            ], c));
            new ScaleHarness(state, rootSize, partSize);
        });
        draw(opened.cx);
        return bounds(opened.cx, 'scale-choice');
    }

    function testPartsTakeTheirScaleFromTheRootAndAPartMayOverrideIt() {
        // A part left alone must land exactly where the same part told to use
        // the root's size lands: the root publishes the scale for all of them.
        final inherited = scaleHarness(Small, null);
        final explicit = scaleHarness(Small, Small);
        assertTrue(inherited.size.equals(explicit.size));

        // A different root scale has to move the part, or nothing was inherited.
        final largeRoot = scaleHarness(Large, null);
        assertTrue(largeRoot.size.height > inherited.size.height);

        // A part that names its own size keeps it whatever the root says.
        final overridden = scaleHarness(Large, Small);
        assertTrue(overridden.size.equals(inherited.size));
    }

    function testShortcutGuardsHeldKeysBeforeActivation() {
        final h = visualHarness([
            new QuestionnaireItemDefinition('choice', 'Choice').withChoice(new QuestionnaireChoiceDefinition('alpha', 'Alpha')),
            new QuestionnaireItemDefinition('second', 'Second'),
        ], Letters);
        final cx = h.cx;
        final state = h.state;

        simulateKey(cx, 'a', true, true);
        simulateKey(cx, 'a', false, false);
        simulateKey(cx, 'shift-a', false, true);
        assertTrue(state.read(app).answer('choice').isEmpty());

        simulateKey(cx, 'a', false, true);
        assertEquals('alpha', state.read(app).answer('choice').choices().join(','));
        assertEquals('alpha', cx.update((window, app) -> state.read(app).focusedCurrentChoice(window)));
        simulateKey(cx, 'enter', false, false);
        assertEquals('second', state.read(app).currentItem());
    }

    function testRootKeyboardPreservesNavigationAndRadioSemantics() {
        final h = visualHarness([
            new QuestionnaireItemDefinition('first', 'First')
                .withRequired(true)
                .withChoices([new QuestionnaireChoiceDefinition('alpha', 'Alpha'), new QuestionnaireChoiceDefinition('beta', 'Beta')]),
            new QuestionnaireItemDefinition('second', 'Second'),
        ], null);
        final cx = h.cx;
        final state = h.state;

        simulateKey(cx, 'right', false, false);
        assertEquals('first', state.read(app).currentItem());
        assertTrue(state.read(app).answer('first').isEmpty());

        cx.update((window, app) -> state.read(app).choiceFocusHandle('first', 'alpha').focus(window, app));
        simulateKey(cx, 'enter', false, false);
        assertEquals('first', state.read(app).currentItem());
        assertTrue(state.read(app).answer('first').isEmpty());

        simulateKey(cx, 'right', false, false);
        draw(cx);
        assertEquals('beta', state.read(app).answer('first').choices().join(','));
        assertEquals('first', state.read(app).currentItem());

        simulateKey(cx, 'enter', false, false);
        assertEquals('second', state.read(app).currentItem());
    }

    function testEmptyInputEnterStaysPutAndArrowsMoveToAnswers() {
        final h = inputVisualHarness(false);
        final cx = h.cx;
        final state = h.state;
        focusInput(cx, state, 'first');

        simulateKey(cx, 'enter', false, false);
        assertEquals('first', state.read(app).currentItem());
        assertTrue(state.read(app).answer('first').isEmpty());
        assertTrue(state.read(app).error('first') == null);

        simulateKey(cx, 'secondary-enter', false, false);
        assertEquals('first', state.read(app).currentItem());
        assertTrue(state.read(app).error('first') != null);

        focusInput(cx, state, 'first');
        simulateKey(cx, 'up', false, false);
        assertEquals('beta', cx.update((window, app) -> state.read(app).focusedCurrentChoice(window)));

        simulateKey(cx, 'down', false, false);
        assertTrue(cx.update((window, app) -> state.read(app).isCurrentInputFocused(window)));
        assertEquals('beta', state.read(app).answer('first').choices().join(','));

        simulateKey(cx, 'down', false, false);
        assertEquals('alpha', cx.update((window, app) -> state.read(app).focusedCurrentChoice(window)));
        assertEquals('alpha', state.read(app).answer('first').choices().join(','));

        simulateKey(cx, 'down', false, false);
        assertEquals('beta', cx.update((window, app) -> state.read(app).focusedCurrentChoice(window)));
        assertEquals('beta', state.read(app).answer('first').choices().join(','));

        cx.update((window, app) -> state.update(app, (state, c) -> {
            state.setInputValue('first', 'Preserved draft', window, c);
            state.activateChoice('first', 'alpha', c);
        }));
        focusInput(cx, state, 'first');
        simulateKey(cx, 'enter', false, false);
        final answer = state.read(app).answer('first');
        assertEquals('first', state.read(app).currentItem());
        assertEquals('alpha', answer.choices().join(','));
        assertNull(answer.freeform());
    }

    function testFilledGroupInputKeepsTextEditingDirections() {
        final h = inputVisualHarness(true);
        final cx = h.cx;
        final state = h.state;
        cx.update((window, app) -> state.update(app, (state, c) -> state.setInputValue('first', 'Freeform answer', window, c)));
        focusInput(cx, state, 'first');

        simulateKey(cx, 'down', false, false);
        assertTrue(cx.update((window, app) -> state.read(app).isCurrentInputFocused(window)));
        assertEquals('Freeform answer', state.read(app).answer('first').freeform());
        assertEquals(0, state.read(app).answer('first').choices().length);

        simulateKey(cx, 'up', false, false);
        assertTrue(cx.update((window, app) -> state.read(app).isCurrentInputFocused(window)));
        assertEquals('Freeform answer', state.read(app).answer('first').freeform());
        assertEquals(0, state.read(app).answer('first').choices().length);
    }

/// ChooseHarness: a single-answer item, a multiple-answer item, then a last
/// single-answer item with a freeform input; each choice sits in a wrapper the
/// test can click by its probe name.

    function chooseHarness():{cx:VisualTestContext, view:Entity<ComponentChooseHarness>, state:Entity<QuestionnaireState>} {
        final opened = open((window, cx:Context<ComponentChooseHarness>) -> new ComponentChooseHarness(window, cx));
        final cx = opened.cx;
        draw(cx);
        final state = opened.view.read(app).state;
        cx.update((window, app) -> state.read(app).focusHandle().focus(window, app));
        return {cx: cx, view: opened.view, state: state};
    }

    /** Past the hold a newly chosen single answer keeps before confirming. */
    static function waitOutHold(cx:VisualTestContext):Void {
        cx.advanceClock(0.2);
        cx.runUntilParked();
        draw(cx);
    }

    static function clickChoice(cx:VisualTestContext, item:String, value:String):Void {
        draw(cx);
        final bounds = OverlayProbe.debugBounds(cx.window, 'choice-' + item + '-' + value);
        cx.simulateClick(bounds.center());
    }

    static function press(cx:VisualTestContext, key:String):Void {
        final keystroke = Keystroke.parseWithOs(key, OperatingSystem.current);
        cx.simulateEvent(new KeyDownEvent(keystroke, false, false));
        cx.simulateEvent(new KeyUpEvent(keystroke));
    }

    /** Rust `simulate_input`: every character dispatched as a keystroke. */
    static function simulateInput(cx:VisualTestContext, text:String):Void {
        for (i in 0...text.length) {
            final keystroke = Keystroke.parse(text.charAt(i));
            cx.update((window, app) -> window.dispatchKeystroke(keystroke, app));
        }
        cx.runUntilParked();
    }

    static function focusChoice(cx:VisualTestContext, state:Entity<QuestionnaireState>, item:String, value:String):Void {
        cx.update((window, app) -> state.read(app).choiceFocusHandle(item, value).focus(window, app));
    }

    function current(state:Entity<QuestionnaireState>):String {
        return state.read(app).currentItem();
    }

    function choices(state:Entity<QuestionnaireState>, item:String):String {
        return state.read(app).answer(item).choices().join(',');
    }

    function testClickingASingleChoiceShowsItThenAdvances() {
        final h = chooseHarness();
        final cx = h.cx;
        final state = h.state;

        clickChoice(cx, 'first', 'alpha');
        cx.runUntilParked();
        assertEquals('alpha', choices(state, 'first'));
        // the selection paints first
        assertEquals('first', current(state));
        waitOutHold(cx);
        assertEquals('second', current(state));

        clickChoice(cx, 'second', 'x');
        waitOutHold(cx);
        // a checkbox only toggles
        assertEquals('second', current(state));
        assertEquals('x', choices(state, 'second'));

        cx.update((window, app) -> state.update(app, (state, c) -> state.goNext(window, c)));
        focusInput(cx, state, 'third');
        simulateInput(cx, 'draft');
        waitOutHold(cx);
        // typing never advances
        assertEquals('third', current(state));

        clickChoice(cx, 'third', 'omega');
        clickChoice(cx, 'third', 'omega');
        waitOutHold(cx);
        // a double click on the last item submits once
        assertEquals(1, h.view.read(app).submits);

        // Choosing the selected answer again after going back confirms it.
        cx.update((window, app) -> state.update(app, (state, c) -> state.setCurrentItem('first', window, c)));
        clickChoice(cx, 'first', 'alpha');
        assertEquals('second', current(state));
    }

    function testShortcutsAndSpaceAdvanceWhileArrowsOnlyMove() {
        final h = chooseHarness();
        final cx = h.cx;
        final state = h.state;

        focusChoice(cx, state, 'first', 'alpha');
        press(cx, 'down');
        waitOutHold(cx);
        assertEquals('beta', choices(state, 'first'));
        // an arrow moves the selection only
        assertEquals('first', current(state));

        simulateKey(cx, '1', false, true);
        cx.runUntilParked();
        assertEquals('alpha', choices(state, 'first'));
        assertEquals('first', current(state));
        waitOutHold(cx);
        assertEquals('second', current(state));

        simulateKey(cx, '2', false, true);
        waitOutHold(cx);
        // a multiple-answer shortcut toggles
        assertEquals('second', current(state));
        assertEquals('y', choices(state, 'second'));

        cx.update((window, app) -> state.update(app, (state, c) -> state.goPrevious(window, c)));
        focusChoice(cx, state, 'first', 'beta');
        press(cx, 'space');
        waitOutHold(cx);
        assertEquals('beta', choices(state, 'first'));
        // Space chooses and advances
        assertEquals('second', current(state));
    }

    function testInvalidErrorProjectsAlertRole() {
        final error = new QuestionnaireError(null, 'item');
        assertEquals(Role.Alert, error.a11y.role);
    }

}

/** Rust `QuestionnaireHarness` of the skin tests (parts probed by name). */
private class QuestionnaireHarness extends Model implements Render {

    public final state:Entity<QuestionnaireState>;

    final overrideSkipMargin:Bool;

    public function new(state:Entity<QuestionnaireState>, overrideSkipMargin:Bool) {
        super();
        this.state = state;
        this.overrideSkipMargin = overrideSkipMargin;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final state = this.state;
        final skip = new QuestionnaireSkip(state);
        if (overrideSkipMargin) skip.ml(px(0.));
        return new OverlayProbe('root', new Questionnaire(state)
            .size(px(480.))
            .child(new QuestionnaireItem(state, 'choice')
                .child(new QuestionnaireChoices(state, 'choice').child(new QuestionnaireChoice(state, 'choice', 'alpha')))
                .child(new QuestionnaireInput(state, 'choice')))
            .child(new QuestionnaireItem(state, 'first')
                .child(new QuestionnaireChoices(state, 'first')
                    .child(new QuestionnaireChoice(state, 'first', 'alpha'))
                    .child(new QuestionnaireChoice(state, 'first', 'beta')))
                .child(new QuestionnaireInput(state, 'first')))
            .child(new QuestionnaireItem(state, 'second').child(new QuestionnaireInput(state, 'second')))
            .child(new OverlayProbe('actions', new QuestionnaireActions(state)
                .child(new OverlayProbe('Previous', new QuestionnairePrevious(state)))
                .child(new OverlayProbe('Skip', skip))
                .child(new OverlayProbe('Next', new QuestionnaireNext(state)))
                .child(new OverlayProbe('Submit', new QuestionnaireSubmit(state))))));
    }

}

/** Rust `ScaleHarness`. */
private class ScaleHarness extends Model implements Render {

    final state:Entity<QuestionnaireState>;

    final rootSize:Size;

    final partSize:Null<Size>;

    public function new(state:Entity<QuestionnaireState>, rootSize:Size, partSize:Null<Size>) {
        super();
        this.state = state;
        this.rootSize = rootSize;
        this.partSize = partSize;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final item = new QuestionnaireItem(state, 'scale');
        final choices = new QuestionnaireChoices(state, 'scale');
        final choice = new QuestionnaireChoice(state, 'scale', 'alpha');
        if (partSize != null) {
            item.withSize(partSize);
            choices.withSize(partSize);
            choice.withSize(partSize);
        }
        return new Questionnaire(state)
            .withSize(rootSize)
            .size(px(480.))
            .child(item.child(choices.child(new OverlayProbe('scale-choice', div().id('scale-choice').child(choice)))));
    }

}

/** Rust `ChooseHarness` of the skin tests. */
private class ComponentChooseHarness extends Model implements Render {

    public final state:Entity<QuestionnaireState>;

    public var submits:Int = 0;

    public function new(window:Window, cx:Context<ComponentChooseHarness>) {
        super();
        final input = cx.newEntity((c:Context<InputState>) -> new InputState(window, c));
        state = cx.newEntity((c:Context<QuestionnaireState>) -> new QuestionnaireState([
            new QuestionnaireItemDefinition('first', 'First')
                .withChoices([new QuestionnaireChoiceDefinition('alpha', 'Alpha'), new QuestionnaireChoiceDefinition('beta', 'Beta')]),
            new QuestionnaireItemDefinition('second', 'Second')
                .withMultiple(true)
                .withChoices([new QuestionnaireChoiceDefinition('x', 'X'), new QuestionnaireChoiceDefinition('y', 'Y')]),
            new QuestionnaireItemDefinition('third', 'Third')
                .withChoice(new QuestionnaireChoiceDefinition('omega', 'Omega'))
                .withInput(new QuestionnaireInputDefinition(input, 'Other')),
        ], c).withShortcuts(Numbers));
        cx.subscribe(state, QuestionnaireEvent, (this_, _, event, _) -> {
            switch event {
                case Submit(_): this_.submits += 1;
                case _:
            }
        });
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final state = this.state;
        final choice = (item:String, value:String) -> new OverlayProbe('choice-' + item + '-' + value,
            div().id('choice-' + item + '-' + value).child(new QuestionnaireChoice(state, item, value)));
        return new Questionnaire(state)
            .size(px(480.))
            .child(new QuestionnaireItem(state, 'first').child(new QuestionnaireChoices(state, 'first')
                .child(choice('first', 'alpha'))
                .child(choice('first', 'beta'))))
            .child(new QuestionnaireItem(state, 'second').child(new QuestionnaireChoices(state, 'second')
                .child(choice('second', 'x'))
                .child(choice('second', 'y'))))
            .child(new QuestionnaireItem(state, 'third')
                .child(new QuestionnaireChoices(state, 'third').child(choice('third', 'omega')))
                .child(new QuestionnaireInput(state, 'third')));
    }

}
