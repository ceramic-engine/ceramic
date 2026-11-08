// Ported from gpui-kit 0.8.1: crates/story/src/stories/questionnaire_story.rs
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
import glaze.Keystroke;
import glaze.OperatingSystem;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Subscription;
import glaze.kit.base.input.InputState;
import glaze.kit.base.questionnaire.QuestionnaireAnswer;
import glaze.kit.base.questionnaire.QuestionnaireChoiceDefinition;
import glaze.kit.base.questionnaire.QuestionnaireEvent;
import glaze.kit.base.questionnaire.QuestionnaireInputDefinition;
import glaze.kit.base.questionnaire.QuestionnaireItemDefinition;
import glaze.kit.base.questionnaire.QuestionnaireShortcutMode;
import glaze.kit.base.questionnaire.QuestionnaireState;
import glaze.kit.base.questionnaire.QuestionnaireSubmission;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.dialog.Dialog;
import glaze.kit.dialog.DialogDescription;
import glaze.kit.dialog.DialogFooter;
import glaze.kit.dialog.DialogFooter.DialogClose;
import glaze.kit.dialog.DialogHeader;
import glaze.kit.dialog.DialogTitle;
import glaze.kit.groupbox.GroupBox;
import glaze.kit.kbd.Kbd;
import glaze.kit.questionnaire.Questionnaire;
import glaze.kit.questionnaire.Questionnaire.QuestionnaireActions;
import glaze.kit.questionnaire.Questionnaire.QuestionnaireChoice;
import glaze.kit.questionnaire.Questionnaire.QuestionnaireChoiceDescription;
import glaze.kit.questionnaire.Questionnaire.QuestionnaireChoices;
import glaze.kit.questionnaire.Questionnaire.QuestionnaireDescription;
import glaze.kit.questionnaire.Questionnaire.QuestionnaireError;
import glaze.kit.questionnaire.Questionnaire.QuestionnaireInput;
import glaze.kit.questionnaire.Questionnaire.QuestionnaireItem;
import glaze.kit.questionnaire.Questionnaire.QuestionnaireNext;
import glaze.kit.questionnaire.Questionnaire.QuestionnairePrevious;
import glaze.kit.questionnaire.Questionnaire.QuestionnaireProgress;
import glaze.kit.questionnaire.Questionnaire.QuestionnaireSkip;
import glaze.kit.questionnaire.Questionnaire.QuestionnaireSubmit;
import glaze.kit.questionnaire.Questionnaire.QuestionnaireTitle;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;
using glaze.kit.WindowExt;

class QuestionnaireStory extends Model implements Story {

    public static function title():String {
        return 'Questionnaire';
    }

    public static function description():String {
        return 'Composable multi-step questions with answers, validation, progress, and navigation.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<QuestionnaireStory> {
        return cx.newEntity((c:Context<QuestionnaireStory>) -> new QuestionnaireStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var size:Size = glaze.kit.Size.Medium;

    final state:Entity<QuestionnaireState>;

    final validationState:Entity<QuestionnaireState>;

    final externalState:Entity<QuestionnaireState>;

    final controlState:Entity<QuestionnaireState>;

    final lettersState:Entity<QuestionnaireState>;

    final numbersState:Entity<QuestionnaireState>;

    final cardState:Entity<QuestionnaireState>;

    final customChoiceState:Entity<QuestionnaireState>;

    final dialogState:Entity<QuestionnaireState>;

    var eventLog:Array<String> = [];

    var keyboardEventLog:Array<String> = [];

    final subscriptions:Array<Subscription>;

    static function input(window:Window, cx:Context<QuestionnaireStory>, placeholder:String, defaultValue:Null<String>):Entity<InputState> {
        return cx.newEntity((cx:Context<InputState>) -> {
            final input = new InputState(window, cx).withPlaceholder(placeholder);
            return defaultValue != null ? input.defaultValue(defaultValue) : input;
        });
    }

    static function makeState(items:Array<QuestionnaireItemDefinition>, cx:Context<QuestionnaireStory>):Entity<QuestionnaireState> {
        return cx.newEntity((cx:Context<QuestionnaireState>) -> new QuestionnaireState(items, cx));
    }

    static function shortcutState(items:Array<QuestionnaireItemDefinition>, mode:QuestionnaireShortcutMode, cx:Context<QuestionnaireStory>):Entity<QuestionnaireState> {
        return cx.newEntity((cx:Context<QuestionnaireState>) -> new QuestionnaireState(items, cx).withShortcuts(mode));
    }

    static function singleItem(name:String, label:String):Array<QuestionnaireItemDefinition> {
        return [new QuestionnaireItemDefinition(name, label).withChoices([
            new QuestionnaireChoiceDefinition('first', 'First choice'),
            new QuestionnaireChoiceDefinition('second', 'Second choice'),
            new QuestionnaireChoiceDefinition('third', 'Third choice'),
        ])];
    }

    static function keyboardItems(window:Window, cx:Context<QuestionnaireStory>):Array<QuestionnaireItemDefinition> {
        final input = input(window, cx, 'Type without triggering A, B, or C…', null);
        return [
            new QuestionnaireItemDefinition('shortcut', 'Choose an answer or type your own')
                .withDescription('Use Up/Down to include the freeform input in the answer focus order.')
                .withChoices([
                    new QuestionnaireChoiceDefinition('first', 'First choice'),
                    new QuestionnaireChoiceDefinition('second', 'Second choice'),
                    new QuestionnaireChoiceDefinition('third', 'Third choice'),
                ])
                .withInput(new QuestionnaireInputDefinition(input, 'Custom answer')),
            new QuestionnaireItemDefinition('keyboard_review', 'Confirm the keyboard result').withChoices([
                new QuestionnaireChoiceDefinition('keep', 'Keep it'),
                new QuestionnaireChoiceDefinition('change', 'Change it'),
            ]),
        ];
    }

    static function mainItems(window:Window, cx:Context<QuestionnaireStory>):Array<QuestionnaireItemDefinition> {
        final directionInput = input(window, cx, 'Type another direction…', null);
        final toolsInput = input(window, cx, 'Add another tool…', 'Terminal');
        return [
            new QuestionnaireItemDefinition('direction', 'What should we prototype next?')
                .withRequired(true)
                .withDescription('Choose one direction or write your own.')
                .withChoices([
                    new QuestionnaireChoiceDefinition('delegation', 'Delegation')
                        .withDescription('Show how work moves to a specialist.')
                        .withDefaultSelected(true),
                    new QuestionnaireChoiceDefinition('questions', 'Question prompts').withDescription('Show choices while the interface waits.'),
                    new QuestionnaireChoiceDefinition('both', 'Both together'),
                ])
                .withInput(new QuestionnaireInputDefinition(directionInput, 'Another direction')),
            new QuestionnaireItemDefinition('tools', 'Which tools do you use?')
                .withMultiple(true)
                .withDescription('Choose any that belong in the prototype.')
                .withChoices([
                    new QuestionnaireChoiceDefinition('editor', 'Editor'),
                    new QuestionnaireChoiceDefinition('terminal', 'Terminal'),
                    new QuestionnaireChoiceDefinition('browser', 'Browser').withDisabled(true),
                ])
                .withInput(new QuestionnaireInputDefinition(toolsInput, 'Another tool')),
            new QuestionnaireItemDefinition('tone', 'What tone should the interface use?')
                .withDescription('This optional question can be intentionally skipped.')
                .withChoices([
                    new QuestionnaireChoiceDefinition('direct', 'Direct'),
                    new QuestionnaireChoiceDefinition('warm', 'Warm'),
                ]),
            new QuestionnaireItemDefinition('advanced', 'Advanced preferences')
                .withDisabled(true)
                .withChoices([new QuestionnaireChoiceDefinition('enabled', 'Enable advanced options')]),
        ];
    }

    static function validationItems(window:Window, cx:Context<QuestionnaireStory>):Array<QuestionnaireItemDefinition> {
        final handleInput = input(window, cx, 'At least three characters', null);
        return [
            new QuestionnaireItemDefinition('handle', 'Choose a public handle')
                .withRequired(true)
                .withDescription('The validator rejects short handles.')
                .withInput(new QuestionnaireInputDefinition(handleInput, 'Public handle'))
                .withValidator(context -> {
                    final value = context.answer().freeform();
                    // Rust `value.len() >= 3`: UTF-8 bytes
                    return value != null && haxe.io.Bytes.ofString(value).length >= 3 ? null : 'Use at least three characters.';
                }),
            new QuestionnaireItemDefinition('summary', 'How should we summarize it?').withChoices([
                new QuestionnaireChoiceDefinition('short', 'Short'),
                new QuestionnaireChoiceDefinition('detailed', 'Detailed'),
            ]),
        ];
    }

    static function itemView(state:Entity<QuestionnaireState>, item:String, choices:Array<String>):QuestionnaireItem {
        final result = QuestionnaireItem.component(state, item)
            .child(QuestionnaireTitle.component(state, item))
            .child(QuestionnaireDescription.component(state, item));
        final choiceParts = QuestionnaireChoices.component(state, item);
        for (value in choices) {
            choiceParts.child(QuestionnaireChoice.component(state, item, value));
        }
        // Keep the freeform answer in the same answer group as fixed choices,
        // matching the ReUI questionnaire composition and spacing.
        choiceParts.child(QuestionnaireInput.component(state, item));
        return result.child(choiceParts).child(QuestionnaireError.component(state, item));
    }

    static function questionnaireView(state:Entity<QuestionnaireState>, size:Size, items:Array<{name:String, choices:Array<String>}>):Questionnaire {
        // The root is the only place the scale is named; every part follows it.
        final questionnaire = Questionnaire.component(state).withSize(size).child(QuestionnaireProgress.component(state));
        for (item in items) {
            questionnaire.child(itemView(state, item.name, item.choices));
        }
        return questionnaire.child(QuestionnaireActions.component(state)
            .child(QuestionnairePrevious.component(state))
            .child(QuestionnaireSkip.component(state))
            .child(QuestionnaireNext.component(state))
            .child(QuestionnaireSubmit.component(state)));
    }

    /** Rust `{:?}` of a string. */
    static function debugString(value:String):String {
        return '"' + value.split('\\').join('\\\\').split('"').join('\\"').split('\n').join('\\n') + '"';
    }

    static function submissionSummary(submission:QuestionnaireSubmission):String {
        return [for (item in submission.items()) '${item.name()}:${item.status().toString()}=${item.answer().toString()}'].join(' · ');
    }

    function onControlEvent(state:Entity<QuestionnaireState>, event:QuestionnaireEvent, window:Window, cx:Context<QuestionnaireStory>):Void {
        final change = switch event {
            case AnswerChanged(change): change;
            case _: return;
        }
        if (change.item() != 'runtime') {
            return;
        }
        final answer = state.read(cx.app).answer('runtime');
        final cloud = answer != null && answer.choices().indexOf('cloud') >= 0;
        final item = state.read(cx.app).itemState('environment');
        final environmentDisabled = item != null && item.isDisabled();
        final shouldDisableEnvironment = !cloud;
        if (environmentDisabled != shouldDisableEnvironment) {
            state.update(cx, (state, cx) -> state.setItemDisabled('environment', shouldDisableEnvironment, window, cx));
        }
    }

    function onKeyboardEvent(state:Entity<QuestionnaireState>, event:QuestionnaireEvent, _:Window, cx:Context<QuestionnaireStory>):Void {
        final mode = state == lettersState ? 'Letters' : 'Numbers';
        final message = switch event {
            case CurrentItemChanged(_, current): '$mode: current=${current != null ? current : 'none'}';
            case AnswerChanged(change): '$mode: answer=${change.answer().toString()}';
            case Completed(_): '$mode: completed';
            case Submit(_): '$mode: submitted';
        }
        keyboardEventLog.push(message);
        if (keyboardEventLog.length > 4) {
            keyboardEventLog.shift();
        }
        cx.notify();
    }

    function new(window:Window, cx:Context<QuestionnaireStory>) {
        super();
        final mainState = shortcutState(mainItems(window, cx), QuestionnaireShortcutMode.Letters, cx);
        validationState = makeState(validationItems(window, cx), cx);
        externalState = makeState([
            new QuestionnaireItemDefinition('server', 'Which workspace should we connect?')
                .withRequired(true)
                .withChoices([
                    new QuestionnaireChoiceDefinition('personal', 'Personal'),
                    new QuestionnaireChoiceDefinition('team', 'Team'),
                ]),
        ], cx);
        externalState.update(cx, (state, cx) -> state.setExternalError('server', 'This workspace is not available.', cx));
        controlState = makeState([
            new QuestionnaireItemDefinition('runtime', 'Where will this workflow run?')
                .withRequired(true)
                .withDescription('Selecting Cloud enables the Environment question.')
                .withChoices([
                    new QuestionnaireChoiceDefinition('local', 'Local').withDefaultSelected(true),
                    new QuestionnaireChoiceDefinition('cloud', 'Cloud'),
                ]),
            new QuestionnaireItemDefinition('delivery', 'How should updates be delivered?').withChoices([
                new QuestionnaireChoiceDefinition('guided', 'Guided'),
                new QuestionnaireChoiceDefinition('automatic', 'Automatic'),
            ]),
            new QuestionnaireItemDefinition('environment', 'Which cloud environment?')
                .withDisabled(true)
                .withChoices([
                    new QuestionnaireChoiceDefinition('staging', 'Staging'),
                    new QuestionnaireChoiceDefinition('production', 'Production'),
                ]),
        ], cx);
        lettersState = shortcutState(keyboardItems(window, cx), QuestionnaireShortcutMode.Letters, cx);
        numbersState = shortcutState(singleItem('shortcut', 'Choose an answer with a number'), QuestionnaireShortcutMode.Numbers, cx);
        cardState = makeState([
            new QuestionnaireItemDefinition('card_scope', 'Who can use this workspace?')
                .withRequired(true)
                .withChoices([
                    new QuestionnaireChoiceDefinition('team', 'Team members'),
                    new QuestionnaireChoiceDefinition('everyone', 'Everyone'),
                ]),
            new QuestionnaireItemDefinition('card_updates', 'Send setup updates?').withChoices([
                new QuestionnaireChoiceDefinition('yes', 'Yes'),
                new QuestionnaireChoiceDefinition('no', 'No'),
            ]),
        ], cx);
        customChoiceState = shortcutState([
            new QuestionnaireItemDefinition('custom', 'Choose a presentation').withChoices([
                new QuestionnaireChoiceDefinition('compact', 'Compact').withDescription('Use a custom indicator and composed description.'),
                new QuestionnaireChoiceDefinition('comfortable', 'Comfortable'),
            ]),
        ], QuestionnaireShortcutMode.Letters, cx);
        dialogState = makeState([
            new QuestionnaireItemDefinition('dialog', 'Which workspace should we open?')
                .withRequired(true)
                .withChoices([
                    new QuestionnaireChoiceDefinition('first', 'Personal'),
                    new QuestionnaireChoiceDefinition('second', 'Team'),
                ]),
            new QuestionnaireItemDefinition('dialog_verification', 'How should we verify the setup?')
                .withRequired(true)
                .withChoices([
                    new QuestionnaireChoiceDefinition('targeted', 'Targeted checks'),
                    new QuestionnaireChoiceDefinition('full', 'Full verification'),
                ]),
        ], cx);
        subscriptions = [
            cx.subscribe(mainState, QuestionnaireEvent, (this_, _, event, cx) -> {
                final message = switch event {
                    case CurrentItemChanged(_, current): 'Current item: ${current != null ? current : 'none'}';
                    case AnswerChanged(change): 'Answer changed: ${change.item()} (${change.status().toString()})';
                    case Completed(submission): 'Completed: ${submissionSummary(submission)}';
                    case Submit(submission): 'Submitted: ${submissionSummary(submission)}';
                }
                this_.eventLog.push(message);
                if (this_.eventLog.length > 4) {
                    this_.eventLog.shift();
                }
                cx.notify();
            }),
            cx.subscribeIn(controlState, QuestionnaireEvent, window, (this_, state, event, window, cx) -> this_.onControlEvent(state, event, window, cx)),
            cx.subscribeIn(lettersState, QuestionnaireEvent, window, (this_, state, event, window, cx) -> this_.onKeyboardEvent(state, event, window, cx)),
            cx.subscribeIn(numbersState, QuestionnaireEvent, window, (this_, state, event, window, cx) -> this_.onKeyboardEvent(state, event, window, cx)),
            cx.subscribeIn(dialogState, QuestionnaireEvent, window, (_, _, event, window, cx) -> switch event {
                case Submit(_): window.closeDialog(cx.app);
                case _:
            }),
        ];
        focusHandle_ = cx.focusHandle();
        state = mainState;
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    static function style(f:(StyleBuilder) -> StyleBuilder):StyleRefinement {
        return f(new StyleBuilder(new StyleRefinement())).style();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final app = cx.app;
        final main = questionnaireView(state, size, [
            {name: 'direction', choices: ['delegation', 'questions', 'both']},
            {name: 'tools', choices: ['editor', 'terminal', 'browser']},
            {name: 'tone', choices: ['direct', 'warm']},
            {name: 'advanced', choices: ['enabled']},
        ]);
        final validation = questionnaireView(validationState, size, [
            {name: 'handle', choices: []},
            {name: 'summary', choices: ['short', 'detailed']},
        ]);
        final external = questionnaireView(externalState, size, [{name: 'server', choices: ['personal', 'team']}]);
        final eventLog = this.eventLog.copy();
        final stateSnapshot = state.read(app);
        final navigation = stateSnapshot.navigationState();
        final navigationSummary = 'Navigation: previous=${navigation.isPreviousVisible()} · next=${navigation.isNextVisible()} · skip=${navigation.isSkipVisible()} · submit=${navigation.isSubmitVisible()} · can_confirm=${navigation.isConfirmable()}';
        final statusSummary = [for (name in ['direction', 'tools', 'tone', 'advanced']) {
            final item = stateSnapshot.itemState(name);
            if (item != null) '$name: ${item.status().toString()}';
        }].filter(s -> s != null).join(' · ');
        final answerSummary = [for (entry in stateSnapshot.answers().iter()) '${entry.name}=${entry.answer.toString()}'].join(' · ');
        final letters = questionnaireView(lettersState, size, [
            {name: 'shortcut', choices: ['first', 'second', 'third']},
            {name: 'keyboard_review', choices: ['keep', 'change']},
        ]);
        final numbers = questionnaireView(numbersState, size, [{name: 'shortcut', choices: ['first', 'second', 'third']}]);
        final lettersSnapshot = lettersState.read(app);
        final focusedChoice = lettersSnapshot.focusedCurrentChoice(window);
        final keyboardFocus = if (lettersSnapshot.isCurrentInputFocused(window)) {
            'freeform input';
        } else if (focusedChoice != null) {
            'choice $focusedChoice';
        } else {
            'item group or none';
        }
        final lettersAnswerValue = lettersSnapshot.answer('shortcut');
        final lettersAnswer = lettersAnswerValue != null ? lettersAnswerValue : new QuestionnaireAnswer();
        final lettersInput = lettersSnapshot.inputState('shortcut');
        final lettersDraft = lettersInput != null ? lettersInput.read(app).value() : '';
        final keyboardEventLog = this.keyboardEventLog.copy();
        final externalErrorValue = externalState.read(app).error('server');
        final externalErrorMessage = externalErrorValue != null ? externalErrorValue.message() : null;
        final externalError = externalErrorMessage != null ? externalErrorMessage : 'none';
        final controlState = this.controlState;
        final controlNavigation = controlState.read(app).navigationState();
        final controlPreviousVisible = controlNavigation.isPreviousVisible();
        final controlSkipVisible = controlNavigation.isSkipVisible();
        final controlNextVisible = controlNavigation.isNextVisible();
        final controlSubmitVisible = controlNavigation.isSubmitVisible();
        final environmentItem = controlState.read(app).itemState('environment');
        final environmentEnabled = environmentItem != null && !environmentItem.isDisabled();
        final customActions = QuestionnaireActions.component(controlState);
        if (controlPreviousVisible) {
            customActions.child(Button.component('questionnaire-custom-previous')
                .outline()
                .label('Back')
                .onClick((_, window, cx) -> controlState.update(cx, (state, cx) -> state.goPrevious(window, cx))));
        }
        if (controlSkipVisible) {
            customActions.child(Button.component('questionnaire-custom-skip')
                .outline()
                .mlAuto()
                .label('Not now')
                .onClick((_, window, cx) -> controlState.update(cx, (state, cx) -> state.skipCurrent(window, cx))));
        }
        if (controlNextVisible) {
            final next = Button.component('questionnaire-custom-next').primary();
            if (!controlSkipVisible) next.mlAuto();
            customActions.child(next
                .label('Continue')
                .onClick((_, window, cx) -> controlState.update(cx, (state, cx) -> state.goNext(window, cx))));
        }
        if (controlSubmitVisible) {
            final submit = Button.component('questionnaire-custom-submit').primary();
            if (!controlSkipVisible) submit.mlAuto();
            customActions.child(submit
                .label('Finish')
                .onClick((_, window, cx) -> controlState.update(cx, (state, cx) -> state.submit(window, cx))));
        }
        final customControl = Questionnaire.component(controlState)
            .withSize(size)
            .child(QuestionnaireProgress.component(controlState))
            .child(itemView(controlState, 'runtime', ['local', 'cloud']))
            .child(itemView(controlState, 'delivery', ['guided', 'automatic']))
            .child(itemView(controlState, 'environment', ['staging', 'production']))
            .child(customActions);
        final card = GroupBox.component()
            .outline()
            .title('Workspace access')
            .child(questionnaireView(cardState, size, [
                {name: 'card_scope', choices: ['team', 'everyone']},
                {name: 'card_updates', choices: ['yes', 'no']},
            ]));
        final customChoiceState = this.customChoiceState;
        final customChoice = Questionnaire.component(customChoiceState)
            .withSize(size)
            .child(QuestionnaireItem.component(customChoiceState, 'custom')
                .child(QuestionnaireTitle.component(customChoiceState, 'custom'))
                .child(QuestionnaireChoices.component(customChoiceState, 'custom')
                    .child(QuestionnaireChoice.component(customChoiceState, 'custom', 'compact')
                        .contentStyle(style(s -> s.gap2()))
                        .renderIndicator((choice, _, cx) -> div()
                            .size4()
                            .roundedFull()
                            .bg(choice.isSelected() ? Theme.global(cx).primary : Theme.global(cx).muted))
                        .renderShortcut((choice, _, _) -> {
                            final shortcut = choice.shortcut();
                            if (shortcut == null) {
                                return div();
                            }
                            final keystroke = try Keystroke.parseWithOs(shortcut.toLowerCase(), OperatingSystem.current) catch (_:Dynamic) null;
                            if (keystroke == null) {
                                return div();
                            }
                            return Kbd.component(keystroke).outline();
                        })
                        .child(vFlex()
                            .gap1()
                            .child(div().fontMedium().child('Compact'))
                            .child(QuestionnaireChoiceDescription.component().child('A custom indicator and composed description.'))))
                    .child(QuestionnaireChoice.component(customChoiceState, 'custom', 'comfortable')
                        .indicatorStyle(style(s -> s.opacity(0.65)))
                        .shortcutStyle(style(s -> s.opacity(0.65)))))
                .child(QuestionnaireError.component(customChoiceState, 'custom')))
            .child(QuestionnaireActions.component(customChoiceState).child(QuestionnaireSubmit.component(customChoiceState)));
        final dialogContentState = dialogState;
        final dialog = Dialog.component(app)
            .trigger(Button.component('questionnaire-dialog-trigger').outline().label('Open Questionnaire Dialog'))
            .p0()
            .content((content, _, _) -> content
                .child(DialogHeader.component()
                    .p4()
                    .child(DialogTitle.component().child('Workspace setup'))
                    .child(DialogDescription.component().child('Questionnaire validates the answer; the Dialog host owns close and cancel.')))
                .child(Questionnaire.component(dialogContentState)
                    .withSize(glaze.kit.Size.Small)
                    .child(QuestionnaireProgress.component(dialogContentState))
                    .child(itemView(dialogContentState, 'dialog', ['first', 'second']))
                    .child(itemView(dialogContentState, 'dialog_verification', ['targeted', 'full']))
                    .child(DialogFooter.component()
                        .child(DialogClose.component().child(Button.component('questionnaire-dialog-cancel').outline().label('Cancel')))
                        .child(QuestionnaireActions.component(dialogContentState)
                            .child(QuestionnairePrevious.component(dialogContentState))
                            .child(QuestionnaireNext.component(dialogContentState))
                            .child(QuestionnaireSubmit.component(dialogContentState))))
                    .px4()
                    .pb4()));
        final externalStateForError = externalState;
        final currentItem = stateSnapshot.currentItem();
        return vFlex()
            .id('questionnaire-story')
            .trackFocus(focusHandle_)
            .wFull()
            .gap4()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .child(storyToolbar(size))
            .child(section('Complete flow')
                .description('Required single choice, multiple choice, freeform input, skip, disabled item, and submit events.')
                .w(px(448.))
                .child(main))
            .child(section('Validation and external errors')
                .description('Next validates the active item; external errors remain host-owned until cleared or fixed.')
                .w(px(600.))
                .child(div().fontMedium().child('Internal validation'))
                .child(validation)
                .child(div().fontMedium().child('External error lifecycle'))
                .child(external)
                .child(hFlex()
                    .gap2()
                    .child(Button.component('questionnaire-external-reapply')
                        .outline()
                        .label('Apply server error')
                        .onClick((_, _, cx) -> externalStateForError.update(cx, (state, cx) -> state.setExternalError('server', 'This workspace is not available.', cx))))
                    .child(Button.component('questionnaire-external-clear')
                        .outline()
                        .label('Clear error')
                        .onClick((_, _, cx) -> externalStateForError.update(cx, (state, cx) -> state.clearExternalError('server', cx))))
                    .child(Button.component('questionnaire-external-fix-submit')
                        .primary()
                        .label('Fix and submit again')
                        .onClick((_, window, cx) -> externalStateForError.update(cx, (state, cx) -> {
                            state.setAnswer('server', new QuestionnaireAnswer().withChoices(['team']), window, cx);
                            state.clearExternalError('server', cx);
                            state.submit(window, cx);
                        }))))
                .child(div().textXs().textColor(theme.mutedForeground).child('External error: $externalError')))
            .child(section('Navigation state')
                .description('The host can inspect current item, answers, status, available actions, and events.')
                .w(px(600.))
                .child(Button.component('questionnaire-reset')
                    .outline()
                    .label('Reset complete flow')
                    .onClick((_, window, cx) -> state.update(cx, (state, cx) -> state.reset(window, cx))))
                .child(div()
                    .textSm()
                    .textColor(theme.mutedForeground)
                    .child('Current: ${currentItem != null ? currentItem : 'none'} · enabled items: ${stateSnapshot.total()} · complete: ${stateSnapshot.isComplete()}'))
                .child(div().textXs().textColor(theme.mutedForeground).child(statusSummary))
                .child(div().textXs().textColor(theme.mutedForeground).child(navigationSummary))
                .child(div().textXs().textColor(theme.mutedForeground).child(answerSummary == '' ? 'Answers: none' : 'Answers: $answerSummary'))
                .children([for (event in eventLog) (div().textXs().textColor(theme.mutedForeground).child(event) : IntoElement)]))
            .child(section('Shortcuts and keyboard')
                .description('The fixture exposes focus, answers, drafts, and events while testing the full keyboard contract.')
                .w(px(600.))
                .child(vFlex()
                    .gap1()
                    .textSm()
                    .textColor(theme.mutedForeground)
                    .child('Up/Down: move through choices and the freeform input; text editing keeps native arrow behavior.')
                    .child('Left/Right: switch items outside text input and radio focus; Right requires an answer.')
                    .child('Enter: confirm a filled answer. Command/Ctrl+Enter: confirm the current item.')
                    .child('A\u2013Z or 1\u20139: activate enabled choices. While input is focused, typed characters edit the draft and are not intercepted.'))
                .child(hFlex()
                    .wFull()
                    .gap4()
                    .child(vFlex().flex1().gap2().child(div().fontMedium().child('Letters')).child(letters))
                    .child(vFlex().flex1().gap2().child(div().fontMedium().child('Numbers')).child(numbers)))
                .child(div()
                    .textXs()
                    .textColor(theme.mutedForeground)
                    .child('Letters focus: $keyboardFocus · answer=${lettersAnswer.toString()} · draft=${debugString(lettersDraft)}'))
                .children([for (event in keyboardEventLog) (div().textXs().textColor(theme.mutedForeground).child(event) : IntoElement)]))
            .child(section('Controlled current, conditional items, and custom actions')
                .description('The host synchronizes Environment from the Runtime answer; custom actions use NavigationState visibility.')
                .w(px(600.))
                .child(hFlex()
                    .gap2()
                    .child(Button.component('questionnaire-controlled-current')
                        .outline()
                        .label('Jump to runtime question')
                        .onClick((_, window, cx) -> controlState.update(cx, (state, cx) -> state.setCurrentItem('runtime', window, cx))))
                    .child(div()
                        .textXs()
                        .textColor(theme.mutedForeground)
                        .child(environmentEnabled ? 'Environment enabled: Runtime is Cloud' : 'Environment disabled: choose Cloud on Runtime')))
                .child(customControl))
            .child(section('Card and Dialog composition')
                .description('GroupBox or Dialog owns the surface and its close behavior; the questionnaire keeps progress, items, and actions together.')
                .w(px(600.))
                .child(card)
                .child(dialog))
            .child(section('Custom choice composition')
                .description('Customize indicator, content, shortcut renderers, and style seams while preserving Questionnaire state and behavior.')
                .w(px(600.))
                .child(customChoice));
    }

}
