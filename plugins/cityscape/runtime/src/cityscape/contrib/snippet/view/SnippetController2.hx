// Ported from vscode src/vs/editor/contrib/snippet/browser/snippetController2.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.snippet.view;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Errors;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorContextKeys;
import cityscape.common.Languages.CompletionContext;
import cityscape.common.Languages.CompletionItemProvider;
import cityscape.common.Languages.CompletionList;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.snippet.view.SnippetParser.Choice;
import cityscape.contrib.snippet.view.SnippetSession;
import cityscape.contrib.suggest.view.SuggestOvertypingCapturer;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

typedef ISnippetInsertOptions = {
    @:optional var overwriteBefore:Int;
    @:optional var overwriteAfter:Int;
    @:optional var adjustWhitespace:Bool;
    @:optional var undoStopBefore:Bool;
    @:optional var undoStopAfter:Bool;
    @:optional var clipboardText:Null<String>;
    @:optional var overtypingCapturer:Null<OvertypingCapturer>;
}

/**
 * The completion provider of the choices of a snippet (Monaco's object
 * literal in `_doInsert`).
 */
private class SnippetChoiceCompletionProvider implements CompletionItemProvider {

    final controller:SnippetController2;

    public var _debugDisplayName(default, null):Null<String> = 'snippetChoiceCompletions';
    public var triggerCharacters(default, null):Null<Array<String>> = null;
    public var resolveCompletionItem(default, null):Null<(item:cityscape.common.Languages.CompletionItem, token:CancellationToken, resolve:(item:Null<cityscape.common.Languages.CompletionItem>) -> Void) -> Void> = null;

    public function new(controller:SnippetController2) {
        this.controller = controller;
    }

    public function provideCompletionItems(model:ITextModel, position:Position, context:CompletionContext, token:CancellationToken, resolve:(list:Null<CompletionList>) -> Void):Void {
        resolve(@:privateAccess controller._provideChoiceCompletions(model, position));
    }

}

/**
 * Inserts snippets and moves between their placeholders (Tab and Shift+Tab),
 * Monaco's `SnippetController2`.
 */
class SnippetController2 implements IEditorContribution {

    public static inline final ID = 'snippetController2';

    public static function get(editor:ICodeEditor):Null<SnippetController2> {
        return editor.getContribution(SnippetController2.ID);
    }

    public static final InSnippetMode = new RawContextKey<Bool>('inSnippetMode', false, 'Whether the editor in current in snippet mode');
    public static final HasNextTabstop = new RawContextKey<Bool>('hasNextTabstop', false, 'Whether there is a next tab stop when in snippet mode');
    public static final HasPrevTabstop = new RawContextKey<Bool>('hasPrevTabstop', false, 'Whether there is a previous tab stop when in snippet mode');

    static final _defaultOptions:ISnippetSessionInsertOptionsAll = {
        overwriteBefore: 0,
        overwriteAfter: 0,
        undoStopBefore: true,
        undoStopAfter: true,
        adjustWhitespace: true,
        clipboardText: null,
        overtypingCapturer: null
    };

    final _editor:ICodeEditor;
    final _inSnippet:IContextKey<Bool>;
    final _hasNextTabstop:IContextKey<Bool>;
    final _hasPrevTabstop:IContextKey<Bool>;

    var _session:Null<SnippetSession> = null;
    final _snippetListener = new DisposableStore();
    var _modelVersionId:Int = -1;
    var _currentChoice:Null<Choice> = null;

    var _choiceCompletions:Null<{provider:CompletionItemProvider, enable:() -> Void, disable:() -> Void}> = null;

    public function new(editor:ICodeEditor) {
        this._editor = editor;
        final contextKeyService = editor.contextKeyService;
        this._inSnippet = SnippetController2.InSnippetMode.bindTo(contextKeyService);
        this._hasNextTabstop = SnippetController2.HasNextTabstop.bindTo(contextKeyService);
        this._hasPrevTabstop = SnippetController2.HasPrevTabstop.bindTo(contextKeyService);
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    public function dispose():Void {
        this._inSnippet.reset();
        this._hasPrevTabstop.reset();
        this._hasNextTabstop.reset();
        if (this._session != null) {
            this._session.dispose();
        }
        this._snippetListener.dispose();
    }

    static function withDefaults(opts:Null<ISnippetInsertOptions>):ISnippetSessionInsertOptionsAll {
        if (opts == null) {
            return _defaultOptions;
        }
        return {
            overwriteBefore: opts.overwriteBefore != null ? opts.overwriteBefore : _defaultOptions.overwriteBefore,
            overwriteAfter: opts.overwriteAfter != null ? opts.overwriteAfter : _defaultOptions.overwriteAfter,
            undoStopBefore: opts.undoStopBefore != null ? opts.undoStopBefore : _defaultOptions.undoStopBefore,
            undoStopAfter: opts.undoStopAfter != null ? opts.undoStopAfter : _defaultOptions.undoStopAfter,
            adjustWhitespace: opts.adjustWhitespace != null ? opts.adjustWhitespace : _defaultOptions.adjustWhitespace,
            clipboardText: opts.clipboardText,
            overtypingCapturer: opts.overtypingCapturer
        };
    }

    /**
     * Inserts snippet edits (Monaco's `apply`).
     */
    public function apply(edits:Array<ISnippetEdit>, ?opts:ISnippetInsertOptions):Void {
        try {
            this._doInsert(null, edits, withDefaults(opts));
        }
        catch (e:Dynamic) {
            this.cancel();
            Errors.onUnexpectedError(e);
        }
    }

    /**
     * Inserts a snippet at every cursor (or merges it into the active
     * snippet).
     */
    public function insert(template:String, ?opts:ISnippetInsertOptions):Void {
        // this is here to find out more about the yet-not-understood
        // error that sometimes happens when we fail to inserted a nested
        // snippet
        try {
            this._doInsert(template, null, withDefaults(opts));
        }
        catch (e:Dynamic) {
            this.cancel();
            Errors.onUnexpectedError(e);
        }
    }

    function _doInsert(template:Null<String>, edits:Null<Array<ISnippetEdit>>, opts:ISnippetSessionInsertOptionsAll):Void {
        if (!this._editor.hasModel()) {
            return;
        }

        // don't listen while inserting the snippet
        // as that is the inflight state causing cancelation
        this._snippetListener.clear();

        if (opts.undoStopBefore) {
            this._editor.getModel().pushStackElement();
        }

        // don't merge
        if (this._session != null && template == null) {
            this.cancel();
        }

        final sessionOptions:ISnippetSessionInsertOptions = {
            overwriteBefore: opts.overwriteBefore,
            overwriteAfter: opts.overwriteAfter,
            adjustWhitespace: opts.adjustWhitespace,
            clipboardText: opts.clipboardText,
            overtypingCapturer: opts.overtypingCapturer
        };

        if (this._session == null) {
            this._modelVersionId = this._editor.getModel().getAlternativeVersionId();
            this._session = new SnippetSession(this._editor, template != null ? cast template : cast edits, sessionOptions, this._editor.context.languageConfigurationService);
            this._session.insert();
        }
        else {
            this._session.merge(template, sessionOptions);
        }

        if (opts.undoStopAfter) {
            this._editor.getModel().pushStackElement();
        }

        // regster completion item provider when there is any choice element
        if (this._session != null && this._session.hasChoice) {
            final provider = new SnippetChoiceCompletionProvider(this);

            final model = this._editor.getModel();

            var registration:Null<IDisposable> = null;
            var isRegistered = false;
            final disable = () -> {
                if (registration != null) {
                    registration.dispose();
                }
                isRegistered = false;
            };

            final enable = () -> {
                if (!isRegistered) {
                    registration = this._editor.context.languageFeaturesService.completionProvider.register(({
                        language: model.getLanguageId(),
                        pattern: model.uri.fsPath,
                        scheme: model.uri.scheme,
                        exclusive: true
                    } : cityscape.common.LanguageSelector.LanguageFilter), provider);
                    this._snippetListener.add(registration);
                    isRegistered = true;
                }
            };

            this._choiceCompletions = {provider: provider, enable: enable, disable: disable};
        }

        this._updateState();

        this._snippetListener.add(this._editor.onDidChangeModelContent(e -> {
            if (e.isFlush) {
                this.cancel();
            }
        }));
        this._snippetListener.add(this._editor.onDidChangeModel(_ -> this.cancel()));
        this._snippetListener.add(this._editor.onDidChangeCursorSelection(_ -> this._updateState()));
    }

    function _provideChoiceCompletions(model:ITextModel, position:Position):Null<CompletionList> {
        if (this._session == null || model != this._editor.getModel() || !Position.equalsStatic(this._editor.getPosition(), position)) {
            return null;
        }
        final activeChoice = this._session.activeChoice;
        if (activeChoice == null || activeChoice.choice.options.length == 0) {
            return null;
        }

        final word = model.getValueInRange(activeChoice.range);
        var isAnyOfOptions = false;
        for (o in activeChoice.choice.options) {
            if (o.value == word) {
                isAnyOfOptions = true;
                break;
            }
        }
        final suggestions:Array<cityscape.common.Languages.CompletionItem> = [];
        for (i in 0...activeChoice.choice.options.length) {
            final option = activeChoice.choice.options[i];
            suggestions.push({
                kind: cityscape.common.languages.CompletionItemKind.Value,
                label: option.value,
                insertText: option.value,
                sortText: StringTools.lpad('', 'a', i + 1),
                range: activeChoice.range,
                filterText: isAnyOfOptions ? word + '_' + option.value : null,
                command: {id: 'jumpToNextSnippetPlaceholder', title: this._editor.context.nls.localize('next', 'Go to next placeholder...')}
            });
        }
        return {suggestions: suggestions};
    }

    function _updateState():Void {
        if (this._session == null || !this._editor.hasModel()) {
            // canceled in the meanwhile
            return;
        }

        if (this._modelVersionId == this._editor.getModel().getAlternativeVersionId()) {
            // undo until the 'before' state happened
            // and makes use cancel snippet mode
            return this.cancel();
        }

        if (!this._session.hasPlaceholder) {
            // don't listen for selection changes and don't
            // update context keys when the snippet is plain text
            return this.cancel();
        }

        if (this._session.isAtLastPlaceholder || !this._session.isSelectionWithinPlaceholders()) {
            this._editor.getModel().pushStackElement();
            return this.cancel();
        }

        this._inSnippet.set(true);
        this._hasPrevTabstop.set(!this._session.isAtFirstPlaceholder);
        this._hasNextTabstop.set(!this._session.isAtLastPlaceholder);

        this._handleChoice();
    }

    function _handleChoice():Void {
        if (this._session == null || !this._editor.hasModel()) {
            this._currentChoice = null;
            return;
        }

        final activeChoice = this._session.activeChoice;
        if (activeChoice == null || this._choiceCompletions == null) {
            if (this._choiceCompletions != null) {
                this._choiceCompletions.disable();
            }
            this._currentChoice = null;
            return;
        }

        if (this._currentChoice != activeChoice.choice) {
            this._currentChoice = activeChoice.choice;

            this._choiceCompletions.enable();

            // trigger suggest with the special choice completion provider
            final provider = this._choiceCompletions.provider;
            cityscape.base.common.Async.setTimeout(() -> {
                cityscape.contrib.suggest.view.SuggestController.showSimpleSuggestions(this._editor, provider);
            }, 0);
        }
    }

    public function finish():Void {
        while (this._inSnippet.get() == true) {
            this.next();
        }
    }

    public function cancel(resetSelection:Bool = false):Void {
        this._inSnippet.reset();
        this._hasPrevTabstop.reset();
        this._hasNextTabstop.reset();
        this._snippetListener.clear();

        this._currentChoice = null;

        if (this._session != null) {
            this._session.dispose();
        }
        this._session = null;
        this._modelVersionId = -1;
        if (resetSelection) {
            // reset selection to the primary cursor when being asked
            // for. this happens when explicitly cancelling snippet mode,
            // e.g. when pressing ESC
            this._editor.setSelections([this._editor.getSelection()]);
        }
    }

    public function prev():Void {
        if (this._session != null) {
            this._session.prev();
        }
        this._updateState();
    }

    public function next():Void {
        if (this._session != null) {
            this._session.next();
        }
        this._updateState();
    }

    public function isInSnippet():Bool {
        return this._inSnippet.get() == true;
    }

    public function getSessionEnclosingRange():Null<Range> {
        if (this._session != null) {
            return this._session.getEnclosingRange();
        }
        return null;
    }

}

typedef ISnippetSessionInsertOptionsAll = {
    var overwriteBefore:Int;
    var overwriteAfter:Int;
    var adjustWhitespace:Bool;
    var undoStopBefore:Bool;
    var undoStopAfter:Bool;
    var clipboardText:Null<String>;
    var overtypingCapturer:Null<OvertypingCapturer>;
}

/**
 * The registration of snippetController2.ts (its module level code).
 */
class SnippetRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        if (r.context.decorationStyles.get('snippet-placeholder') == null) {
            // snippetSession.css: the placeholders in the theme colors
            r.context.registerDecorationStyle('snippet-placeholder', {
                background: {id: 'editor.snippetTabstopHighlightBackground'},
                border: {color: {id: 'editor.snippetTabstopHighlightBorder'}}
            });
        }
        if (r.context.decorationStyles.get('finish-snippet-placeholder') == null) {
            r.context.registerDecorationStyle('finish-snippet-placeholder', {
                background: {id: 'editor.snippetFinalTabstopHighlightBackground'},
                border: {color: {id: 'editor.snippetFinalTabstopHighlightBorder'}}
            });
        }

        r.registerEditorContribution(SnippetController2.ID, editor -> new SnippetController2(editor), EditorContributionInstantiation.Lazy);

        r.registerEditorCommand(new ContributionCommand<SnippetController2>(SnippetController2.get, {
            id: 'jumpToNextSnippetPlaceholder',
            precondition: ContextKeyExpr.and(SnippetController2.InSnippetMode, SnippetController2.HasNextTabstop),
            handler: (ctrl, _) -> ctrl.next(),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 30,
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyCode.Tab
            }
        }));
        r.registerEditorCommand(new ContributionCommand<SnippetController2>(SnippetController2.get, {
            id: 'jumpToPrevSnippetPlaceholder',
            precondition: ContextKeyExpr.and(SnippetController2.InSnippetMode, SnippetController2.HasPrevTabstop),
            handler: (ctrl, _) -> ctrl.prev(),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 30,
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyMod.Shift | KeyCode.Tab
            }
        }));
        r.registerEditorCommand(new ContributionCommand<SnippetController2>(SnippetController2.get, {
            id: 'leaveSnippet',
            precondition: SnippetController2.InSnippetMode,
            handler: (ctrl, _) -> ctrl.cancel(true),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 30,
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyCode.Escape,
                secondary: [KeyMod.Shift | KeyCode.Escape]
            }
        }));
        r.registerEditorCommand(new ContributionCommand<SnippetController2>(SnippetController2.get, {
            id: 'acceptSnippet',
            precondition: SnippetController2.InSnippetMode,
            handler: (ctrl, _) -> ctrl.finish()
        }));
    }

}
