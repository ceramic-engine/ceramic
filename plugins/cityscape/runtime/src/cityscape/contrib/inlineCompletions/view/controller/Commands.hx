// Ported from vscode src/vs/editor/contrib/inlineCompletions/browser/controller/commands.ts and
// src/vs/editor/contrib/inlineCompletions/browser/inlineCompletions.contribution.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlineCompletions.view.controller;

import cityscape.Cityscape;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Observable;
import cityscape.common.EditorContextKeys;
import cityscape.contrib.suggest.view.Suggest.SuggestContext;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

class ShowNextInlineSuggestionAction extends EditorAction {
    public static inline final ID = CommandIds.showNextInlineSuggestionActionId;

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: ShowNextInlineSuggestionAction.ID,
            label: r.localize('action.inlineSuggest.showNext', "Show Next Inline Suggestion"),
            alias: 'Show Next Inline Suggestion',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, InlineCompletionContextKeys.inlineSuggestionVisible),
            kbOpts: {
                weight: 100,
                primary: KeyMod.Alt | KeyCode.BracketRight,
            },
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = InlineCompletionsController.get(editor);
        final model = controller != null ? controller.model.get() : null;
        if (model != null) {
            model.next();
        }
    }
}

class ShowPreviousInlineSuggestionAction extends EditorAction {
    public static inline final ID = CommandIds.showPreviousInlineSuggestionActionId;

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: ShowPreviousInlineSuggestionAction.ID,
            label: r.localize('action.inlineSuggest.showPrevious', "Show Previous Inline Suggestion"),
            alias: 'Show Previous Inline Suggestion',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, InlineCompletionContextKeys.inlineSuggestionVisible),
            kbOpts: {
                weight: 100,
                primary: KeyMod.Alt | KeyCode.BracketLeft,
            },
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = InlineCompletionsController.get(editor);
        final model = controller != null ? controller.model.get() : null;
        if (model != null) {
            model.previous();
        }
    }
}

/**
 * Monaco's `editor.action.inlineSuggest.trigger` has no keybinding (VS
 * Code binds Alt+\ in its workbench keybindings, not in the editor).
 */
class TriggerInlineSuggestionAction extends EditorAction {
    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.inlineSuggest.trigger',
            label: r.localize('action.inlineSuggest.trigger', "Trigger Inline Suggestion"),
            alias: 'Trigger Inline Suggestion',
            precondition: EditorContextKeys.writable
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = InlineCompletionsController.get(editor);
        // asyncTransaction: the accessibility signal is not ported
        final model = controller != null ? controller.model.get() : null;
        if (model != null) {
            model.triggerExplicitly();
        }
    }
}

class AcceptNextWordOfInlineCompletion extends EditorAction {
    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.inlineSuggest.acceptNextWord',
            label: r.localize('action.inlineSuggest.acceptNextWord', "Accept Next Word Of Inline Suggestion"),
            alias: 'Accept Next Word Of Inline Suggestion',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, InlineCompletionContextKeys.inlineSuggestionVisible),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 1,
                primary: KeyMod.CtrlCmd | KeyCode.RightArrow,
                kbExpr: ContextKeyExpr.and(EditorContextKeys.writable, InlineCompletionContextKeys.inlineSuggestionVisible),
            },
            menuOpts: [{
                menuId: 'InlineSuggestionToolbar',
                title: r.localize('acceptWord', 'Accept Word'),
                group: 'primary',
                order: 2,
            }],
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = InlineCompletionsController.get(editor);
        final model = controller != null ? controller.model.get() : null;
        if (model != null) {
            model.acceptNextWord(controller.editor);
        }
    }
}

class AcceptNextLineOfInlineCompletion extends EditorAction {
    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.inlineSuggest.acceptNextLine',
            label: r.localize('action.inlineSuggest.acceptNextLine', "Accept Next Line Of Inline Suggestion"),
            alias: 'Accept Next Line Of Inline Suggestion',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, InlineCompletionContextKeys.inlineSuggestionVisible),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 1,
            },
            menuOpts: [{
                menuId: 'InlineSuggestionToolbar',
                title: r.localize('acceptLine', 'Accept Line'),
                group: 'secondary',
                order: 2,
            }],
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = InlineCompletionsController.get(editor);
        final model = controller != null ? controller.model.get() : null;
        if (model != null) {
            model.acceptNextLine(controller.editor);
        }
    }
}

class AcceptInlineCompletion extends EditorAction {
    public function new(r:EditorExtensionsRegistry) {
        super({
            id: CommandIds.inlineSuggestCommitId,
            label: r.localize('action.inlineSuggest.accept', "Accept Inline Suggestion"),
            alias: 'Accept Inline Suggestion',
            precondition: InlineCompletionContextKeys.inlineSuggestionVisible,
            menuOpts: [{
                menuId: 'InlineSuggestionToolbar',
                title: r.localize('accept', "Accept"),
                group: 'primary',
                order: 1,
            }],
            kbOpts: {
                primary: KeyCode.Tab,
                weight: 200,
                kbExpr: ContextKeyExpr.and(
                    InlineCompletionContextKeys.inlineSuggestionVisible,
                    EditorContextKeys.tabMovesFocus.toNegated(),
                    InlineCompletionContextKeys.inlineSuggestionHasIndentationLessThanTabSize,
                    SuggestContext.Visible.toNegated(),
                    EditorContextKeys.hoverFocused.toNegated()
                ),
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = InlineCompletionsController.get(editor);
        if (controller != null) {
            final model = controller.model.get();
            if (model != null) {
                model.accept(controller.editor);
            }
            controller.editor.focus();
        }
    }
}

class HideInlineCompletion extends EditorAction {
    public static inline final ID = 'editor.action.inlineSuggest.hide';

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: HideInlineCompletion.ID,
            label: r.localize('action.inlineSuggest.hide', "Hide Inline Suggestion"),
            alias: 'Hide Inline Suggestion',
            precondition: InlineCompletionContextKeys.inlineSuggestionVisible,
            kbOpts: {
                weight: 100,
                primary: KeyCode.Escape,
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = InlineCompletionsController.get(editor);
        Observable.transaction(tx -> {
            final model = controller != null ? controller.model.get() : null;
            if (model != null) {
                model.stop(tx);
            }
        });
    }
}

/**
 * The registration of inlineCompletions.contribution.ts (its module level
 * code). Not registered: `ToggleAlwaysShowInlineSuggestionToolbar` (the
 * toolbar is not ported), the hover participant of the hints and the
 * accessible view.
 */
class InlineCompletionsRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        cityscape.contrib.inlineCompletions.view.view.GhostTextView.registerDecorationStyles(r.context);
        r.registerEditorContribution(InlineCompletionsController.ID, editor -> new InlineCompletionsController(editor), EditorContributionInstantiation.Eventually);

        r.registerEditorAction(new TriggerInlineSuggestionAction(r));
        r.registerEditorAction(new ShowNextInlineSuggestionAction(r));
        r.registerEditorAction(new ShowPreviousInlineSuggestionAction(r));
        r.registerEditorAction(new AcceptNextWordOfInlineCompletion(r));
        r.registerEditorAction(new AcceptNextLineOfInlineCompletion(r));
        r.registerEditorAction(new AcceptInlineCompletion(r));
        r.registerEditorAction(new HideInlineCompletion(r));
    }

}
