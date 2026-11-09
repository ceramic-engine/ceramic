// Ported from vscode src/vs/editor/contrib/suggest/browser/suggestModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.suggest.view;

import cityscape.base.common.Async.TimeoutTimer;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Event;
import cityscape.base.common.Filters;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Promise;
import cityscape.base.common.Strings;
import cityscape.common.CursorEvents;
import cityscape.common.Languages.CompletionContext;
import cityscape.common.Languages.CompletionItemProvider;
import cityscape.common.Languages.CompletionTriggerKind;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Selection;
import cityscape.common.core.WordHelper.IWordAtPosition;
import cityscape.contrib.snippet.view.SnippetController2;
import cityscape.contrib.suggest.view.CompletionModel;
import cityscape.contrib.suggest.view.Suggest;
import cityscape.view.EditorBrowser.ICodeEditor;

typedef ICancelEvent = {
    final retrigger:Bool;
}

typedef ITriggerEvent = {
    final auto:Bool;
    final shy:Bool;
    final position:IPosition;
}

typedef ISuggestEvent = {
    final completionModel:CompletionModel;
    final isFrozen:Bool;
    final triggerOptions:SuggestTriggerOptions;
}

/**
 * Monaco's `Partial<CompletionOptions>`.
 */
typedef PartialCompletionOptions = {
    @:optional var kindFilter:Array<cityscape.common.languages.CompletionItemKind>;
    @:optional var providerFilter:Array<CompletionItemProvider>;
    @:optional var providerItemsToReuse:Map<CompletionItemProvider, Array<CompletionItem>>;
}

typedef SuggestTriggerOptions = {
    final auto:Bool;
    @:optional final shy:Null<Bool>;
    @:optional final refilter:Null<Bool>;
    @:optional final retrigger:Null<Bool>;
    @:optional final triggerKind:Null<CompletionTriggerKind>;
    @:optional final triggerCharacter:Null<String>;
    @:optional final clipboardText:Null<String>;
    @:optional var completionOptions:Null<PartialCompletionOptions>;
}

/**
 * The line of the cursor when suggest was triggered (Monaco's
 * `LineContext` of suggestModel.ts).
 */
class SuggestLineContext {

    public static function shouldAutoTrigger(editor:ICodeEditor):Bool {
        if (!editor.hasModel()) {
            return false;
        }
        final model = editor.getModel();
        final pos = editor.getPosition();
        model.tokenization.tokenizeIfCheap(pos.lineNumber);

        final word = model.getWordAtPosition(pos);
        if (word == null) {
            return false;
        }
        if (word.endColumn != pos.column
            && word.startColumn + 1 != pos.column /* after typing a single character before a word */) {
            return false;
        }
        if (!Math.isNaN(JsValues.toNumber(word.word))) {
            return false;
        }
        return true;
    }

    public final lineNumber:Int;
    public final column:Int;
    public final leadingLineContent:String;
    public final leadingWord:IWordAtPosition;
    public final triggerOptions:SuggestTriggerOptions;

    public function new(model:ITextModel, position:Position, triggerOptions:SuggestTriggerOptions) {
        this.leadingLineContent = model.getLineContent(position.lineNumber).substr(0, position.column - 1);
        this.leadingWord = model.getWordUntilPosition(position);
        this.lineNumber = position.lineNumber;
        this.column = position.column;
        this.triggerOptions = triggerOptions;
    }
}

enum abstract SuggestState(Int) from Int to Int {
    var Idle = 0;
    var Manual = 1;
    var Auto = 2;
}

/**
 * Decides when to ask the providers for completions and filters them as
 * the user types (Monaco's `SuggestModel`).
 *
 * Telemetry and the log of invalid items are not ported.
 */
class SuggestModel implements IDisposable {

    // Inline completions (step 7, cs7-rest-inline): Monaco's module functions
    // `canShowQuickSuggest` and `canShowSuggestOnTriggerCharacters` (the same
    // check), reading the context keys of the inline completions.
    static function canShowQuickSuggest(editor:ICodeEditor):Bool {
        final contextKeyService = editor.contextKeyService;
        final visible:Null<Bool> = contextKeyService.getContextKeyValue('inlineSuggestionVisible');
        if (visible != true) {
            // Allow if there is no inline suggestion.
            return true;
        }
        final suppressSuggestions:Null<Bool> = contextKeyService.getContextKeyValue('inlineSuggestionSuppressSuggestions');
        if (suppressSuggestions != null) {
            return !suppressSuggestions;
        }
        return !editor.getOption(EditorOption.inlineSuggest).suppressSuggestions;
    }

    final _editor:ICodeEditor;

    final _toDispose = new DisposableStore();
    final _triggerCharacterListener = new DisposableStore();
    final _triggerQuickSuggest = new TimeoutTimer();

    var _triggerState:Null<SuggestTriggerOptions> = null;
    var _requestToken:Null<CancellationTokenSource> = null;
    var _context:Null<SuggestLineContext> = null;
    var _currentSelection:Selection;

    var _completionModel:Null<CompletionModel> = null;
    final _completionDisposables = new DisposableStore();
    final _onDidCancel = new Emitter<ICancelEvent>();
    final _onDidTrigger = new Emitter<ITriggerEvent>();
    final _onDidSuggest = new Emitter<ISuggestEvent>();

    public final onDidCancel:Event<ICancelEvent>;
    public final onDidTrigger:Event<ITriggerEvent>;
    public final onDidSuggest:Event<ISuggestEvent>;

    var _editorIsComposing = false;

    public function new(editor:ICodeEditor) {
        this._editor = editor;
        this.onDidCancel = _onDidCancel.event;
        this.onDidTrigger = _onDidTrigger.event;
        this.onDidSuggest = _onDidSuggest.event;

        final selection = this._editor.getSelection();
        this._currentSelection = selection != null ? selection : new Selection(1, 1, 1, 1);

        final languageFeaturesService = editor.context.languageFeaturesService;

        // wire up various listeners
        this._toDispose.add(this._editor.onDidChangeModel(_ -> {
            this._updateTriggerCharacters();
            this.cancel();
        }));
        this._toDispose.add(this._editor.onDidChangeModelLanguage(_ -> {
            this._updateTriggerCharacters();
            this.cancel();
        }));
        this._toDispose.add(this._editor.onDidChangeConfiguration(_ -> {
            this._updateTriggerCharacters();
        }));
        this._toDispose.add(languageFeaturesService.completionProvider.onDidChange(_ -> {
            this._updateTriggerCharacters();
            this._updateActiveSuggestSession();
        }));

        this._toDispose.add(this._editor.onDidCompositionStart(() -> {
            _editorIsComposing = true;
        }));
        this._toDispose.add(this._editor.onDidCompositionEnd(() -> {
            _editorIsComposing = false;
            this._onCompositionEnd();
        }));
        this._toDispose.add(this._editor.onDidChangeCursorSelection(e -> {
            // only trigger suggest when the editor isn't composing a character
            if (!_editorIsComposing) {
                this._onCursorChange(e);
            }
        }));
        this._toDispose.add(this._editor.onDidChangeModelContent(_ -> {
            // only filter completions when the editor isn't composing a character
            // e.g. ¨ + u makes ü but just ¨ cannot be used for filtering
            if (!_editorIsComposing && this._triggerState != null) {
                this._refilterCompletionItems();
            }
        }));

        this._updateTriggerCharacters();
    }

    public function dispose():Void {
        this._triggerCharacterListener.dispose();
        this._onDidCancel.dispose();
        this._onDidSuggest.dispose();
        this._onDidTrigger.dispose();
        this._triggerQuickSuggest.dispose();
        this._toDispose.dispose();
        this._completionDisposables.dispose();
        this.cancel();
    }

    function _updateTriggerCharacters():Void {
        this._triggerCharacterListener.clear();

        if (this._editor.getOption(EditorOption.readOnly)
            || !this._editor.hasModel()
            || !this._editor.getOption(EditorOption.suggestOnTriggerCharacters)) {

            return;
        }

        final supportsByTriggerCharacter = new Map<String, Array<CompletionItemProvider>>();
        for (support in this._editor.context.languageFeaturesService.completionProvider.all(this._editor.getModel())) {
            final chars = support.triggerCharacters;
            if (chars == null) {
                continue;
            }
            for (ch in chars) {
                var set = supportsByTriggerCharacter.get(ch);
                if (set == null) {
                    set = [];
                    final suggestSupport = this._editor.context.snippetSuggestSupport;
                    if (suggestSupport != null) {
                        set.push(suggestSupport);
                    }
                    supportsByTriggerCharacter.set(ch, set);
                }
                if (set.indexOf(support) < 0) {
                    set.push(support);
                }
            }
        }

        final checkTriggerCharacter = (text:Null<String>) -> {

            if (!canShowQuickSuggest(this._editor)) { // canShowSuggestOnTriggerCharacters (cs7-rest-inline)
                return;
            }

            if (SuggestLineContext.shouldAutoTrigger(this._editor)) {
                // don't trigger by trigger characters when this is a case for quick suggest
                return;
            }

            if (text == null) {
                // came here from the compositionEnd-event
                final position = this._editor.getPosition();
                final model = this._editor.getModel();
                text = model.getLineContent(position.lineNumber).substr(0, position.column - 1);
            }

            final t:String = text;
            var lastChar = '';
            if (t.length > 0 && Strings.isLowSurrogate(StringTools.fastCodeAt(t, t.length - 1))) {
                if (t.length > 1 && Strings.isHighSurrogate(StringTools.fastCodeAt(t, t.length - 2))) {
                    lastChar = t.substr(t.length - 2);
                }
            }
            else if (t.length > 0) {
                lastChar = t.charAt(t.length - 1);
            }

            final supports = supportsByTriggerCharacter.get(lastChar);
            if (supports != null) {

                // keep existing items that where not computed by the
                // supports/providers that want to trigger now
                final providerItemsToReuse = new Map<CompletionItemProvider, Array<CompletionItem>>();
                if (this._completionModel != null) {
                    final byProvider = this._completionModel.getItemsByProvider();
                    for (provider in this._completionModel.getProviders()) {
                        if (supports.indexOf(provider) < 0) {
                            providerItemsToReuse.set(provider, byProvider.get(provider));
                        }
                    }
                }

                this.trigger({
                    auto: true,
                    triggerKind: CompletionTriggerKind.TriggerCharacter,
                    triggerCharacter: lastChar,
                    retrigger: this._completionModel != null,
                    clipboardText: this._completionModel != null ? this._completionModel.clipboardText : null,
                    completionOptions: {providerFilter: supports, providerItemsToReuse: providerItemsToReuse}
                });
            }
        };

        this._triggerCharacterListener.add(this._editor.onDidType(text -> checkTriggerCharacter(text)));
        this._triggerCharacterListener.add(this._editor.onDidCompositionEnd(() -> checkTriggerCharacter(null)));
    }

    // --- trigger/retrigger/cancel suggest

    public var state(get, never):SuggestState;
    function get_state():SuggestState {
        if (this._triggerState == null) {
            return SuggestState.Idle;
        }
        else if (!this._triggerState.auto) {
            return SuggestState.Manual;
        }
        else {
            return SuggestState.Auto;
        }
    }

    public function cancel(retrigger:Bool = false):Void {
        if (this._triggerState != null) {
            this._triggerQuickSuggest.cancel();
            if (this._requestToken != null) {
                this._requestToken.cancel();
            }
            this._requestToken = null;
            this._triggerState = null;
            this._completionModel = null;
            this._context = null;
            this._onDidCancel.fire({retrigger: retrigger});
        }
    }

    public function clear():Void {
        this._completionDisposables.clear();
    }

    function _updateActiveSuggestSession():Void {
        if (this._triggerState != null) {
            if (!this._editor.hasModel() || !this._editor.context.languageFeaturesService.completionProvider.has(this._editor.getModel())) {
                this.cancel();
            }
            else {
                this.trigger({auto: this._triggerState.auto, retrigger: true});
            }
        }
    }

    function _onCursorChange(e:ICursorSelectionChangedEvent):Void {

        if (!this._editor.hasModel()) {
            return;
        }

        final prevSelection = this._currentSelection;
        this._currentSelection = this._editor.getSelection();

        if (!e.selection.isEmpty()
            || (e.reason != CursorChangeReason.NotSet && e.reason != CursorChangeReason.Explicit)
            || (e.source != 'keyboard' && e.source != 'deleteLeft')
        ) {
            // Early exit if nothing needs to be done!
            // Leave some form of early exit check here if you wish to continue being a cursor position change listener ;)
            this.cancel();
            return;
        }

        if (this._triggerState == null && e.reason == CursorChangeReason.NotSet) {
            if (prevSelection.containsRange(this._currentSelection) || prevSelection.getEndPosition().isBeforeOrEqual(this._currentSelection.getPosition())) {
                // cursor did move RIGHT due to typing -> trigger quick suggest
                this._doTriggerQuickSuggest();
            }

        }
        else if (this._triggerState != null && e.reason == CursorChangeReason.Explicit) {
            // suggest is active and something like cursor keys are used to move
            // the cursor. this means we can refilter at the new position
            this._refilterCompletionItems();
        }
    }

    function _onCompositionEnd():Void {
        // trigger or refilter when composition ends
        if (this._triggerState == null) {
            this._doTriggerQuickSuggest();
        }
        else {
            this._refilterCompletionItems();
        }
    }

    function _doTriggerQuickSuggest():Void {

        if (QuickSuggestionsOptions.isAllOff(this._editor.getOption(EditorOption.quickSuggestions))) {
            // not enabled
            return;
        }

        if (this._editor.getOption(EditorOption.suggest).snippetsPreventQuickSuggestions) {
            final snippetController = SnippetController2.get(this._editor);
            if (snippetController != null && snippetController.isInSnippet()) {
                // no quick suggestion when in snippet mode
                return;
            }
        }

        this.cancel();

        this._triggerQuickSuggest.cancelAndSet(() -> {
            if (this._triggerState != null) {
                return;
            }
            if (!SuggestLineContext.shouldAutoTrigger(this._editor)) {
                return;
            }
            if (!this._editor.hasModel() || !this._editor.hasWidgetFocus()) {
                return;
            }
            final model = this._editor.getModel();
            final pos = this._editor.getPosition();
            // validate enabled now
            final config = this._editor.getOption(EditorOption.quickSuggestions);
            if (QuickSuggestionsOptions.isAllOff(config)) {
                return;
            }

            if (!QuickSuggestionsOptions.isAllOn(config)) {
                // Check the type of the token that triggered this
                model.tokenization.tokenizeIfCheap(pos.lineNumber);
                final lineTokens = model.tokenization.getLineTokens(pos.lineNumber);
                final tokenType = lineTokens.getStandardTokenType(lineTokens.findTokenIndexAtOffset(Std.int(Math.max(pos.column - 1 - 1, 0))));
                if (QuickSuggestionsOptions.valueFor(config, tokenType) != 'on') {
                    return;
                }
            }

            if (!canShowQuickSuggest(this._editor)) {
                // do not trigger quick suggestions if inline suggestions are shown (cs7-rest-inline)
                return;
            }

            if (!this._editor.context.languageFeaturesService.completionProvider.has(model)) {
                return;
            }

            // we made it till here -> trigger now
            this.trigger({auto: true});

        }, this._editor.getOption(EditorOption.quickSuggestionsDelay));
    }

    /**
     * Runs the pending quick suggest at once (tests; Monaco's tests wait for
     * the delay).
     * @internal
     */
    public function _flushQuickSuggest():Void {
        this._triggerQuickSuggest.flush();
    }

    function _refilterCompletionItems():Void {
        if (!this._editor.hasModel() || this._triggerState == null) {
            return;
        }

        final model = this._editor.getModel();
        final position = this._editor.getPosition();
        final ts = this._triggerState;
        final ctx = new SuggestLineContext(model, position, {
            auto: ts.auto,
            shy: ts.shy,
            refilter: true,
            retrigger: ts.retrigger,
            triggerKind: ts.triggerKind,
            triggerCharacter: ts.triggerCharacter,
            clipboardText: ts.clipboardText,
            completionOptions: ts.completionOptions
        });
        this._onNewContext(ctx);
    }

    public function trigger(options:SuggestTriggerOptions):Void {
        if (!this._editor.hasModel()) {
            return;
        }

        final model = this._editor.getModel();
        final ctx = new SuggestLineContext(model, this._editor.getPosition(), options);

        // Cancel previous requests, change state & update UI
        this.cancel(options.retrigger == true);
        this._triggerState = options;
        this._onDidTrigger.fire({auto: options.auto, shy: options.shy == true, position: this._editor.getPosition()});

        // Capture context when request was sent
        this._context = ctx;

        // Build context for request
        var suggestCtx:CompletionContext = {triggerKind: options.triggerKind != null ? options.triggerKind : CompletionTriggerKind.Invoke};
        if (options.triggerCharacter != null && options.triggerCharacter.length > 0) {
            suggestCtx = {
                triggerKind: CompletionTriggerKind.TriggerCharacter,
                triggerCharacter: options.triggerCharacter
            };
        }

        final requestToken = new CancellationTokenSource();
        this._requestToken = requestToken;

        // kind filter and snippet sort rules
        final snippetSuggestions = this._editor.getOption(EditorOption.snippetSuggestions);
        var snippetSortOrder = SnippetSortOrder.Inline;
        switch (snippetSuggestions) {
            case 'top':
                snippetSortOrder = SnippetSortOrder.Top;
            // 	↓ that's the default anyways...
            // case 'inline':
            // 	snippetSortOrder = SnippetSortOrder.Inline;
            case 'bottom':
                snippetSortOrder = SnippetSortOrder.Bottom;
            case _:
        }

        final filter = SuggestModel.createSuggestFilter(this._editor);
        final co = options.completionOptions;
        final completionOptions = new CompletionOptions(
            snippetSortOrder,
            co != null && co.kindFilter != null ? co.kindFilter : filter.itemKind,
            co != null ? co.providerFilter : null,
            co != null ? co.providerItemsToReuse : null,
            filter.showDeprecated
        );
        final wordDistance = WordDistance.create(this._editor);

        final completions = SuggestUtils.provideSuggestionItems(
            this._editor.context.languageFeaturesService.completionProvider,
            model,
            this._editor.getPosition(),
            completionOptions,
            suggestCtx,
            requestToken.token,
            this._editor.context.snippetSuggestSupport
        );

        completions.done(completions -> {

            if (this._requestToken != null) {
                this._requestToken.dispose();
            }

            if (!this._editor.hasModel()) {
                return;
            }

            var clipboardText = options.clipboardText;
            if (clipboardText == null && completions.needsClipboard) {
                final read = this._editor.context.readClipboardText;
                clipboardText = read != null ? read() : null;
            }

            if (this._triggerState == null) {
                return;
            }

            final model = this._editor.getModel();

            final ctx = new SuggestLineContext(model, this._editor.getPosition(), options);
            final fuzzySearchOptions:FuzzyScoreOptions = {
                boostFullMatch: FuzzyScoreOptions.defaultOptions.boostFullMatch,
                firstMatchCanBeWeak: !this._editor.getOption(EditorOption.suggest).matchOnWordStartOnly
            };
            this._completionModel = new CompletionModel(completions.items, this._context.column, {
                leadingLineContent: ctx.leadingLineContent,
                characterCountDelta: ctx.column - this._context.column
            },
                wordDistance,
                this._editor.getOption(EditorOption.suggest),
                this._editor.getOption(EditorOption.snippetSuggestions),
                fuzzySearchOptions,
                clipboardText
            );

            // store containers so that they can be disposed later
            this._completionDisposables.add(completions.disposable);

            this._onNewContext(ctx);

        }, err -> {
            if (!CancellationError.isCancellationError(err)) {
                Errors.onUnexpectedError(err);
            }
        });
    }

    public static function createSuggestFilter(editor:ICodeEditor):{itemKind:Array<cityscape.common.languages.CompletionItemKind>, showDeprecated:Bool} {
        // kind filter and snippet sort rules
        final result:Array<cityscape.common.languages.CompletionItemKind> = [];

        // snippet setting
        final snippetSuggestions = editor.getOption(EditorOption.snippetSuggestions);
        if (snippetSuggestions == 'none') {
            result.push(cityscape.common.languages.CompletionItemKind.Snippet);
        }

        // type setting
        final suggestOptions = editor.getOption(EditorOption.suggest);
        inline function add(kind:cityscape.common.languages.CompletionItemKind):Void {
            if (result.indexOf(kind) < 0) {
                result.push(kind);
            }
        }
        if (!suggestOptions.showMethods) { add(cityscape.common.languages.CompletionItemKind.Method); }
        if (!suggestOptions.showFunctions) { add(cityscape.common.languages.CompletionItemKind.Function); }
        if (!suggestOptions.showConstructors) { add(cityscape.common.languages.CompletionItemKind.Constructor); }
        if (!suggestOptions.showFields) { add(cityscape.common.languages.CompletionItemKind.Field); }
        if (!suggestOptions.showVariables) { add(cityscape.common.languages.CompletionItemKind.Variable); }
        if (!suggestOptions.showClasses) { add(cityscape.common.languages.CompletionItemKind.Class); }
        if (!suggestOptions.showStructs) { add(cityscape.common.languages.CompletionItemKind.Struct); }
        if (!suggestOptions.showInterfaces) { add(cityscape.common.languages.CompletionItemKind.Interface); }
        if (!suggestOptions.showModules) { add(cityscape.common.languages.CompletionItemKind.Module); }
        if (!suggestOptions.showProperties) { add(cityscape.common.languages.CompletionItemKind.Property); }
        if (!suggestOptions.showEvents) { add(cityscape.common.languages.CompletionItemKind.Event); }
        if (!suggestOptions.showOperators) { add(cityscape.common.languages.CompletionItemKind.Operator); }
        if (!suggestOptions.showUnits) { add(cityscape.common.languages.CompletionItemKind.Unit); }
        if (!suggestOptions.showValues) { add(cityscape.common.languages.CompletionItemKind.Value); }
        if (!suggestOptions.showConstants) { add(cityscape.common.languages.CompletionItemKind.Constant); }
        if (!suggestOptions.showEnums) { add(cityscape.common.languages.CompletionItemKind.Enum); }
        if (!suggestOptions.showEnumMembers) { add(cityscape.common.languages.CompletionItemKind.EnumMember); }
        if (!suggestOptions.showKeywords) { add(cityscape.common.languages.CompletionItemKind.Keyword); }
        if (!suggestOptions.showWords) { add(cityscape.common.languages.CompletionItemKind.Text); }
        if (!suggestOptions.showColors) { add(cityscape.common.languages.CompletionItemKind.Color); }
        if (!suggestOptions.showFiles) { add(cityscape.common.languages.CompletionItemKind.File); }
        if (!suggestOptions.showReferences) { add(cityscape.common.languages.CompletionItemKind.Reference); }
        if (!suggestOptions.showColors) { add(cityscape.common.languages.CompletionItemKind.Customcolor); }
        if (!suggestOptions.showFolders) { add(cityscape.common.languages.CompletionItemKind.Folder); }
        if (!suggestOptions.showTypeParameters) { add(cityscape.common.languages.CompletionItemKind.TypeParameter); }
        if (!suggestOptions.showSnippets) { add(cityscape.common.languages.CompletionItemKind.Snippet); }
        if (!suggestOptions.showUsers) { add(cityscape.common.languages.CompletionItemKind.User); }
        if (!suggestOptions.showIssues) { add(cityscape.common.languages.CompletionItemKind.Issue); }

        return {itemKind: result, showDeprecated: suggestOptions.showDeprecated};
    }

    function _onNewContext(ctx:SuggestLineContext):Void {

        if (this._context == null) {
            // happens when 24x7 IntelliSense is enabled and still in its delay
            return;
        }

        if (ctx.lineNumber != this._context.lineNumber) {
            // e.g. happens when pressing Enter while IntelliSense is computed
            this.cancel();
            return;
        }

        if (Strings.getLeadingWhitespace(ctx.leadingLineContent) != Strings.getLeadingWhitespace(this._context.leadingLineContent)) {
            // cancel IntelliSense when line start changes
            // happens when the current word gets outdented
            this.cancel();
            return;
        }

        if (ctx.column < this._context.column) {
            // typed -> moved cursor LEFT -> retrigger if still on a word
            if (ctx.leadingWord.word.length > 0) {
                this.trigger({auto: this._context.triggerOptions.auto, retrigger: true});
            }
            else {
                this.cancel();
            }
            return;
        }

        if (this._completionModel == null) {
            // happens when IntelliSense is not yet computed
            return;
        }

        if (ctx.leadingWord.word.length != 0 && ctx.leadingWord.startColumn > this._context.leadingWord.startColumn) {
            // started a new word while IntelliSense shows -> retrigger but reuse all items that we currently have
            final shouldAutoTrigger = SuggestLineContext.shouldAutoTrigger(this._editor);
            if (shouldAutoTrigger && this._context != null) {
                // shouldAutoTrigger forces tokenization, which can cause pending cursor change events to be emitted, which can cause
                // suggestions to be cancelled, which causes `this._context` to be undefined
                final map = this._completionModel.getItemsByProvider();
                this.trigger({
                    auto: this._context.triggerOptions.auto,
                    retrigger: true,
                    clipboardText: this._completionModel.clipboardText,
                    completionOptions: {providerItemsToReuse: map}
                });
            }
            return;
        }

        if (ctx.column > this._context.column && this._completionModel.getIncompleteProvider().length > 0 && ctx.leadingWord.word.length != 0) {
            // typed -> moved cursor RIGHT & incomple model & still on a word -> retrigger

            final providerItemsToReuse = new Map<CompletionItemProvider, Array<CompletionItem>>();
            final providerFilter:Array<CompletionItemProvider> = [];
            final byProvider = this._completionModel.getItemsByProvider();
            for (provider in this._completionModel.getProviders()) {
                final items = byProvider.get(provider);
                if (items.length > 0 && items[0].container.incomplete == true) {
                    providerFilter.push(provider);
                }
                else {
                    providerItemsToReuse.set(provider, items);
                }
            }

            this.trigger({
                auto: this._context.triggerOptions.auto,
                triggerKind: CompletionTriggerKind.TriggerForIncompleteCompletions,
                retrigger: true,
                clipboardText: this._completionModel.clipboardText,
                completionOptions: {providerFilter: providerFilter, providerItemsToReuse: providerItemsToReuse}
            });

        }
        else {
            // typed -> moved cursor RIGHT -> update UI
            final oldLineContext = this._completionModel.lineContext;
            var isFrozen = false;

            this._completionModel.lineContext = {
                leadingLineContent: ctx.leadingLineContent,
                characterCountDelta: ctx.column - this._context.column
            };

            if (this._completionModel.items.length == 0) {

                final shouldAutoTrigger = SuggestLineContext.shouldAutoTrigger(this._editor);
                if (this._context == null) {
                    // shouldAutoTrigger forces tokenization, which can cause pending cursor change events to be emitted, which can cause
                    // suggestions to be cancelled, which causes `this._context` to be undefined
                    this.cancel();
                    return;
                }

                if (shouldAutoTrigger && this._context.leadingWord.endColumn < ctx.leadingWord.startColumn) {
                    // retrigger when heading into a new word
                    this.trigger({auto: this._context.triggerOptions.auto, retrigger: true});
                    return;
                }

                if (!this._context.triggerOptions.auto) {
                    // freeze when IntelliSense was manually requested
                    this._completionModel.lineContext = oldLineContext;
                    isFrozen = this._completionModel.items.length > 0;

                    if (isFrozen && ctx.leadingWord.word.length == 0) {
                        // there were results before but now there aren't
                        // and also we are not on a word anymore -> cancel
                        this.cancel();
                        return;
                    }

                }
                else {
                    // nothing left
                    this.cancel();
                    return;
                }
            }

            this._onDidSuggest.fire({
                completionModel: this._completionModel,
                triggerOptions: ctx.triggerOptions,
                isFrozen: isFrozen,
            });
        }
    }

}
