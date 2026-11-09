// Ported from vscode src/vs/editor/contrib/suggest/browser/suggestController.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.suggest.view;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Promise;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.EditorContextKeys;
import cityscape.common.Languages.CompletionItemInsertTextRule;
import cityscape.common.Languages.CompletionItemProvider;
import cityscape.common.Languages.CompletionTriggerKind;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.contrib.snippet.view.SnippetController2;
import cityscape.contrib.snippet.view.SnippetParser;
import cityscape.contrib.suggest.view.Suggest;
import cityscape.contrib.suggest.view.SuggestModel;
import cityscape.contrib.suggest.view.SuggestOvertypingCapturer;
import cityscape.contrib.suggest.view.SuggestWidget;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/**
 * Watches the text right of the cursor while suggest shows (Monaco's
 * `LineSuffix`): the replace range of an accepted item grows with what was
 * typed after the trigger.
 */
private class LineSuffix implements IDisposable {

    static var _decorationOptions:Null<ModelDecorationOptions> = null;

    var _marker:Null<String> = null;

    final _model:ITextModel;
    final _position:IPosition;

    public function new(model:ITextModel, position:IPosition) {
        this._model = model;
        this._position = position;
        if (_decorationOptions == null) {
            _decorationOptions = ModelDecorationOptions.register({
                description: 'suggest-line-suffix',
                stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges
            });
        }
        // spy on what's happening right of the cursor. two cases:
        // 1. end of line -> check that it's still end of line
        // 2. mid of line -> add a marker and compute the delta
        final maxColumn = model.getLineMaxColumn(position.lineNumber);
        if (maxColumn != position.column) {
            final offset = model.getOffsetAt(position);
            final end = model.getPositionAt(offset + 1);
            model.changeDecorations(accessor -> {
                if (this._marker != null) {
                    accessor.removeDecoration(this._marker);
                }
                this._marker = accessor.addDecoration(Range.fromPositions(position, end), cast _decorationOptions);
                return null;
            });
        }
    }

    public function dispose():Void {
        if (this._marker != null && !this._model.isDisposed()) {
            this._model.changeDecorations(accessor -> {
                accessor.removeDecoration(this._marker);
                this._marker = null;
                return null;
            });
        }
    }

    public function delta(position:IPosition):Int {
        if (this._model.isDisposed() || this._position.lineNumber != position.lineNumber) {
            // bail out early if things seems fishy
            return 0;
        }
        // read the marker (in case suggest was triggered at line end) or compare
        // the cursor to the line end.
        if (this._marker != null) {
            final range = this._model.getDecorationRange(this._marker);
            final end = this._model.getOffsetAt(range.getStartPosition());
            return end - this._model.getOffsetAt(position);
        }
        else {
            return this._model.getLineMaxColumn(position.lineNumber) - position.column;
        }
    }

}

private enum abstract InsertFlags(Int) from Int to Int {
    var None = 0;
    var NoBeforeUndoStop = 1;
    var NoAfterUndoStop = 2;
    var KeepAlternativeSuggestions = 4;
    var AlternativeOverwriteConfig = 8;
}

/**
 * Accepts the focused item when a commit character of it is typed
 * (Monaco's `CommitCharacterController`, suggestCommitCharacters.ts).
 */
class CommitCharacterController implements IDisposable {

    final _disposables = new DisposableStore();

    var _active:Null<{acceptCharacters:Array<Int>, item:ISelectedSuggestion}> = null;

    public function new(editor:ICodeEditor, widget:SuggestWidget, model:SuggestModel, accept:(selected:ISelectedSuggestion) -> Void) {

        this._disposables.add(model.onDidSuggest(e -> {
            if (e.completionModel.items.length == 0) {
                this.reset();
            }
        }));
        this._disposables.add(model.onDidCancel(e -> {
            this.reset();
        }));

        this._disposables.add(widget.onDidShow(_ -> this._onItem(widget.getFocusedItem())));
        this._disposables.add(widget.onDidFocus(e -> this._onItem(e)));
        this._disposables.add(widget.onDidHide(_ -> this.reset()));

        this._disposables.add(editor.onWillType(text -> {
            if (this._active != null && !widget.isFrozen() && model.state != SuggestState.Idle) {
                final ch = StringTools.fastCodeAt(text, text.length - 1);
                if (this._active.acceptCharacters.indexOf(ch) >= 0 && editor.getOption(EditorOption.acceptSuggestionOnCommitCharacter)) {
                    accept(this._active.item);
                }
            }
        }));
    }

    function _onItem(selected:Null<ISelectedSuggestion>):Void {
        if (selected == null || selected.item.completion.commitCharacters == null || selected.item.completion.commitCharacters.length == 0) {
            // no item or no commit characters
            this.reset();
            return;
        }

        if (this._active != null && this._active.item.item == selected.item) {
            // still the same item
            return;
        }

        // keep item and its commit characters
        final acceptCharacters:Array<Int> = [];
        for (ch in selected.item.completion.commitCharacters) {
            if (ch.length > 0) {
                acceptCharacters.push(StringTools.fastCodeAt(ch, 0));
            }
        }
        this._active = {acceptCharacters: acceptCharacters, item: selected};
    }

    public function reset():Void {
        this._active = null;
    }

    public function dispose():Void {
        this._disposables.dispose();
    }

}

/**
 * The suggest contribution of an editor (Monaco's `SuggestController`):
 * triggers the model, shows its completions in the widget, and inserts the
 * accepted one (snippets, additional edits, commands, overwrite ranges).
 *
 * Not ported: the alternative suggestions of tab completion
 * (`insertNextSuggestion`, `insertPrevSuggestion`), the word context key of
 * `insertBestCompletion`, telemetry, aria alerts. The scroll position is not
 * restored around additional edits (`StableEditorScrollState`).
 */
class SuggestController implements IEditorContribution {

    public static inline final ID:String = 'editor.contrib.suggestController';

    public static function get(editor:ICodeEditor):Null<SuggestController> {
        return editor.getContribution(SuggestController.ID);
    }

    /**
     * Monaco's `showSimpleSuggestions` (suggest.ts): triggers suggest with
     * only `provider`.
     */
    public static function showSimpleSuggestions(editor:ICodeEditor, provider:CompletionItemProvider):Void {
        final controller = SuggestController.get(editor);
        if (controller != null) {
            controller.triggerSuggest([provider], null, true);
        }
    }

    public final editor:ICodeEditor;
    public final model:SuggestModel;

    var _widget:Null<SuggestWidget> = null;

    final _lineSuffix = new MutableDisposable<LineSuffix>();
    final _toDispose = new DisposableStore();
    var _overtypingCapturer:Null<OvertypingCapturer> = null;
    final _selectors:Array<ISuggestItemPreselector> = [];

    final _onWillInsertSuggestItem = new Emitter<{item:CompletionItem}>();
    public final onWillInsertSuggestItem:Event<{item:CompletionItem}>;

    public function new(editor:ICodeEditor) {
        this.editor = editor;
        this.onWillInsertSuggestItem = _onWillInsertSuggestItem.event;
        this.model = new SuggestModel(this.editor);

        final contextKeyService = editor.contextKeyService;
        final memoryService = editor.context.suggestMemoryService;

        // default selector
        this.registerSelector(new MemorySelector(memoryService, editor));

        // context key: update insert/replace mode
        final ctxInsertMode = SuggestContext.InsertMode.bindTo(contextKeyService);
        ctxInsertMode.set(editor.getOption(EditorOption.suggest).insertMode);
        this._toDispose.add(this.model.onDidTrigger(_ -> ctxInsertMode.set(editor.getOption(EditorOption.suggest).insertMode)));

        this._toDispose.add(this.model.onDidTrigger(e -> {
            this.widget.showTriggered(e.auto, e.shy ? 250 : 50);
            this._lineSuffix.value = new LineSuffix(this.editor.getModel(), e.position);
        }));
        this._toDispose.add(this.model.onDidSuggest(e -> {
            if (e.triggerOptions.shy == true) {
                return;
            }
            var index = -1;
            for (selector in this._selectors) {
                index = selector.select(this.editor.getModel(), this.editor.getPosition(), e.completionModel.items);
                if (index != -1) {
                    break;
                }
            }
            if (index == -1) {
                index = 0;
            }
            if (this.model.state == SuggestState.Idle) {
                // selecting an item can "pump" out selection/cursor change events
                // which can cancel suggest halfway through this function. therefore
                // we need to check again and bail if the session has been canceled
                return;
            }
            var noFocus = false;
            if (e.triggerOptions.auto) {
                // don't "focus" item when configured to do
                final options = this.editor.getOption(EditorOption.suggest);
                if (options.selectionMode == 'never' || options.selectionMode == 'always') {
                    // simple: always or never
                    noFocus = options.selectionMode == 'never';

                }
                else if (options.selectionMode == 'whenTriggerCharacter') {
                    // on with trigger character
                    noFocus = e.triggerOptions.triggerKind != CompletionTriggerKind.TriggerCharacter;

                }
                else if (options.selectionMode == 'whenQuickSuggestion') {
                    // without trigger character or when refiltering
                    noFocus = e.triggerOptions.triggerKind == CompletionTriggerKind.TriggerCharacter && e.triggerOptions.refilter != true;
                }

            }
            this.widget.showSuggestions(e.completionModel, index, e.isFrozen, e.triggerOptions.auto, noFocus);
        }));
        this._toDispose.add(this.model.onDidCancel(e -> {
            if (!e.retrigger && this._widget != null) {
                this._widget.hideWidget();
            }
        }));
        this._toDispose.add(this.editor.onDidBlurEditorWidget(() -> {
            this.model.cancel();
            this.model.clear();
        }));

        // Manage the acceptSuggestionsOnEnter context key
        final acceptSuggestionsOnEnter = SuggestContext.AcceptSuggestionsOnEnter.bindTo(contextKeyService);
        final updateFromConfig = () -> {
            final acceptSuggestionOnEnter = this.editor.getOption(EditorOption.acceptSuggestionOnEnter);
            acceptSuggestionsOnEnter.set(acceptSuggestionOnEnter == 'on' || acceptSuggestionOnEnter == 'smart');
        };
        this._toDispose.add(this.editor.onDidChangeConfiguration(_ -> updateFromConfig()));
        updateFromConfig();
    }

    /**
     * The widget, created on first use (Monaco's `WindowIdleValue`).
     */
    public var widget(get, never):SuggestWidget;
    function get_widget():SuggestWidget {
        if (_widget == null) {
            final widget = new SuggestWidget(this.editor);
            _widget = widget;

            this._toDispose.add(widget);
            this._toDispose.add(widget.onDidSelect(item -> this._insertSuggestion(item, InsertFlags.None)));

            // Wire up logic to accept a suggestion on certain characters
            final commitCharacterController = new CommitCharacterController(this.editor, widget, this.model, item -> this._insertSuggestion(item, InsertFlags.NoAfterUndoStop));
            this._toDispose.add(commitCharacterController);

            // Wire up makes text edit context key
            final contextKeyService = this.editor.contextKeyService;
            final ctxMakesTextEdit = SuggestContext.MakesTextEdit.bindTo(contextKeyService);
            final ctxHasInsertAndReplace = SuggestContext.HasInsertAndReplaceRange.bindTo(contextKeyService);
            final ctxCanResolve = SuggestContext.CanResolve.bindTo(contextKeyService);

            this._toDispose.add(Lifecycle.toDisposable(() -> {
                ctxMakesTextEdit.reset();
                ctxHasInsertAndReplace.reset();
                ctxCanResolve.reset();
            }));

            this._toDispose.add(widget.onDidFocus(e -> {
                final item = e.item;

                // (ctx: makesTextEdit)
                final position = this.editor.getPosition();
                final startColumn = item.editStart.column;
                final endColumn = position.column;
                var value = true;
                if (
                    this.editor.getOption(EditorOption.acceptSuggestionOnEnter) == 'smart'
                    && this.model.state == SuggestState.Auto
                    && item.completion.additionalTextEdits == null
                    && !isSnippet(item)
                    && endColumn - startColumn == item.completion.insertText.length
                ) {
                    final oldText = this.editor.getModel().getValueInRange({
                        startLineNumber: position.lineNumber,
                        startColumn: startColumn,
                        endLineNumber: position.lineNumber,
                        endColumn: endColumn
                    });
                    value = oldText != item.completion.insertText;
                }
                ctxMakesTextEdit.set(value);

                // (ctx: hasInsertAndReplaceRange)
                ctxHasInsertAndReplace.set(!Position.equalsStatic(item.editInsertEnd, item.editReplaceEnd));

                // (ctx: canResolve)
                ctxCanResolve.set(item.provider.resolveCompletionItem != null || item.completion.documentation != null || item.completion.detail != item.textLabel);
            }));
        }
        return _widget;
    }

    static function isSnippet(item:CompletionItem):Bool {
        final rules:Null<CompletionItemInsertTextRule> = item.completion.insertTextRules;
        return rules != null && ((rules : Int) & (CompletionItemInsertTextRule.InsertAsSnippet : Int)) != 0;
    }

    function overtypingCapturer():OvertypingCapturer {
        if (_overtypingCapturer == null) {
            _overtypingCapturer = new OvertypingCapturer(this.editor, this.model);
            this._toDispose.add(_overtypingCapturer);
        }
        return _overtypingCapturer;
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    public function dispose():Void {
        this._toDispose.dispose();
        this.model.dispose();
        this._lineSuffix.dispose();
        this._onWillInsertSuggestItem.dispose();
    }

    function _insertSuggestion(event:Null<ISelectedSuggestion>, flags:Int):Void {
        if (event == null || event.item == null) {
            this.model.cancel();
            this.model.clear();
            return;
        }
        if (!this.editor.hasModel()) {
            return;
        }
        final snippetController = SnippetController2.get(this.editor);
        if (snippetController == null) {
            return;
        }

        this._onWillInsertSuggestItem.fire({item: event.item});

        final model = this.editor.getModel();
        final item = event.item;

        //
        final tasks:Array<Promise<Any>> = [];
        final cts = new CancellationTokenSource();

        // pushing undo stops *before* additional text edits and
        // *after* the main edit
        if ((flags & InsertFlags.NoBeforeUndoStop) == 0) {
            this.editor.pushUndoStop();
        }

        // compute overwrite[Before|After] deltas BEFORE applying extra edits
        final info = this.getOverwriteInfo(item, (flags & InsertFlags.AlternativeOverwriteConfig) != 0);

        // keep item in memory
        this.editor.context.suggestMemoryService.memorize(this.editor.getOption(EditorOption.suggestSelection), model, this.editor.getPosition(), item);

        final isResolved = item.isResolved;

        if (item.completion.additionalTextEdits != null) {

            // cancel -> stops all listening and closes widget
            this.model.cancel();

            // sync additional edits
            this.editor.executeEdits(
                'suggestController.additionalTextEdits.sync',
                [for (edit in item.completion.additionalTextEdits) {
                    var range = Range.lift(edit.range);
                    if (range.startLineNumber == item.position.lineNumber && range.startColumn > item.position.column) {
                        // shift additional edit when it is "after" the completion insertion position
                        final columnDelta = this.editor.getPosition().column - item.position.column;
                        final startColumnDelta = columnDelta;
                        final endColumnDelta = Range.spansMultipleLines(range) ? 0 : columnDelta;
                        range = new Range(range.startLineNumber, range.startColumn + startColumnDelta, range.endLineNumber, range.endColumn + endColumnDelta);
                    }
                    EditOperation.replaceMove(range, edit.text);
                }]
            );

        }
        else if (!isResolved) {
            // async additional edits
            var position:Null<Position> = null;

            var docListener:Null<IDisposable> = null;
            docListener = model.onDidChangeContent(e -> {
                if (e.isFlush) {
                    cts.cancel();
                    docListener.dispose();
                    return;
                }
                for (change in e.changes) {
                    final thisPosition = Range.getEndPositionStatic(change.range);
                    if (position == null || Position.isBeforeStatic(thisPosition, position)) {
                        position = thisPosition;
                    }
                }
            });

            final oldFlags = flags;
            flags |= InsertFlags.NoAfterUndoStop;
            var didType = false;
            var typeListener:Null<IDisposable> = null;
            typeListener = this.editor.onWillType(_ -> {
                typeListener.dispose();
                didType = true;
                if ((oldFlags & InsertFlags.NoAfterUndoStop) == 0) {
                    this.editor.pushUndoStop();
                }
            });

            tasks.push(item.resolve(cts.token).then(_ -> {
                final additionalTextEdits = item.completion.additionalTextEdits;
                if (additionalTextEdits == null || cts.token.isCancellationRequested) {
                    return null;
                }
                if (position != null) {
                    for (edit in additionalTextEdits) {
                        if (Position.isBeforeStatic(position, Range.getStartPositionStatic(edit.range))) {
                            return (false : Any);
                        }
                    }
                }
                if (didType) {
                    this.editor.pushUndoStop();
                }
                this.editor.executeEdits(
                    'suggestController.additionalTextEdits.async',
                    [for (edit in additionalTextEdits) EditOperation.replaceMove(Range.lift(edit.range), edit.text)]
                );
                if (didType || (oldFlags & InsertFlags.NoAfterUndoStop) == 0) {
                    this.editor.pushUndoStop();
                }
                return (true : Any);
            }).finally(() -> {
                docListener.dispose();
                typeListener.dispose();
            }));
        }

        var insertText = item.completion.insertText;
        if (!isSnippet(item)) {
            insertText = SnippetParser.escape(insertText);
        }

        // cancel -> stops all listening and closes widget
        this.model.cancel();

        final rules:Int = item.completion.insertTextRules != null ? (item.completion.insertTextRules : Int) : 0;
        snippetController.insert(insertText, {
            overwriteBefore: info.overwriteBefore,
            overwriteAfter: info.overwriteAfter,
            undoStopBefore: false,
            undoStopAfter: false,
            adjustWhitespace: (rules & (CompletionItemInsertTextRule.KeepWhitespace : Int)) == 0,
            clipboardText: event.model.clipboardText,
            overtypingCapturer: this.overtypingCapturer()
        });

        if ((flags & InsertFlags.NoAfterUndoStop) == 0) {
            this.editor.pushUndoStop();
        }

        final command = item.completion.command;
        if (command != null) {
            if (command.id == TriggerSuggestAction.ID) {
                // retigger
                this.model.trigger({auto: true, retrigger: true});
            }
            else {
                // exec command, done
                try {
                    this.editor.context.commandService.executeCommand(command.id, command.arguments != null ? command.arguments.copy() : []);
                }
                catch (e:Dynamic) {
                    Errors.onUnexpectedError(e);
                }
            }
        }

        // clear only now - after all tasks are done
        Promise.allSettled(tasks).done(_ -> {
            this.model.clear();
            cts.dispose();
        });
    }

    public function getOverwriteInfo(item:CompletionItem, toggleMode:Bool):{overwriteBefore:Int, overwriteAfter:Int} {

        var replace = this.editor.getOption(EditorOption.suggest).insertMode == 'replace';
        if (toggleMode) {
            replace = !replace;
        }
        final overwriteBefore = item.position.column - item.editStart.column;
        final overwriteAfter = (replace ? item.editReplaceEnd.column : item.editInsertEnd.column) - item.position.column;
        final columnDelta = this.editor.getPosition().column - item.position.column;
        final suffixDelta = this._lineSuffix.value != null ? this._lineSuffix.value.delta(this.editor.getPosition()) : 0;

        return {
            overwriteBefore: overwriteBefore + columnDelta,
            overwriteAfter: overwriteAfter + suffixDelta
        };
    }

    /**
     * Triggers suggest (Monaco's `triggerSuggest`): `onlyFrom` limits the
     * providers, `noFilter` shows every kind.
     */
    public function triggerSuggest(?onlyFrom:Array<CompletionItemProvider>, ?auto:Bool, ?noFilter:Bool):Void {
        if (this.editor.hasModel()) {
            this.model.trigger({
                auto: auto == true,
                completionOptions: {providerFilter: onlyFrom, kindFilter: noFilter == true ? [] : null}
            });
            this.editor.revealPosition(this.editor.getPosition(), ScrollType.Smooth);
            this.editor.focus();
        }
    }

    public function acceptSelectedSuggestion(keepAlternativeSuggestions:Bool, alternativeOverwriteConfig:Bool):Void {
        final item = this.widget.getFocusedItem();
        var flags = 0;
        if (keepAlternativeSuggestions) {
            flags |= InsertFlags.KeepAlternativeSuggestions;
        }
        if (alternativeOverwriteConfig) {
            flags |= InsertFlags.AlternativeOverwriteConfig;
        }
        this._insertSuggestion(item, flags);
    }

    public function cancelSuggestWidget():Void {
        this.model.cancel();
        this.model.clear();
        this.widget.hideWidget();
    }

    public function focusSuggestion():Void {
        this.widget.focusSelected();
    }

    public function selectNextSuggestion():Void {
        this.widget.selectNext();
    }

    public function selectNextPageSuggestion():Void {
        this.widget.selectNextPage();
    }

    public function selectLastSuggestion():Void {
        this.widget.selectLast();
    }

    public function selectPrevSuggestion():Void {
        this.widget.selectPrevious();
    }

    public function selectPrevPageSuggestion():Void {
        this.widget.selectPreviousPage();
    }

    public function selectFirstSuggestion():Void {
        this.widget.selectFirst();
    }

    public function toggleSuggestionDetails():Void {
        this.widget.toggleDetails();
    }

    public function toggleExplainMode():Void {
        this.widget.toggleExplainMode();
    }

    public function toggleSuggestionFocus():Void {
        this.widget.toggleDetailsFocus();
    }

    public function resetWidgetSize():Void {
        this.widget.resetPersistedSize();
    }

    public function registerSelector(selector:ISuggestItemPreselector):IDisposable {
        if (this._selectors.indexOf(selector) != -1) {
            throw 'Value is already registered';
        }
        this._selectors.push(selector);
        haxe.ds.ArraySort.sort(this._selectors, (s1, s2) -> s2.priority - s1.priority);
        return Lifecycle.toDisposable(() -> this._selectors.remove(selector));
    }

}

private class MemorySelector implements ISuggestItemPreselector {

    public var priority(default, null):Int = 0;

    final memoryService:cityscape.contrib.suggest.view.SuggestMemory.SuggestMemoryService;
    final editor:ICodeEditor;

    public function new(memoryService:cityscape.contrib.suggest.view.SuggestMemory.SuggestMemoryService, editor:ICodeEditor) {
        this.memoryService = memoryService;
        this.editor = editor;
    }

    public function select(model:ITextModel, pos:IPosition, items:Array<CompletionItem>):Int {
        return memoryService.select(editor.getOption(EditorOption.suggestSelection), model, pos, items);
    }

}

/**
 * `editor.action.triggerSuggest` (Ctrl+Space).
 */
class TriggerSuggestAction extends EditorAction {

    public static inline final ID = 'editor.action.triggerSuggest';

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: TriggerSuggestAction.ID,
            label: r.localize('suggest.trigger.label', "Trigger Suggest"),
            alias: 'Trigger Suggest',
            precondition: ContextKeyExpr.and(EditorContextKeys.writable, EditorContextKeys.hasCompletionItemProvider, SuggestContext.Visible.toNegated()),
            kbOpts: {
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyMod.CtrlCmd | KeyCode.Space,
                secondary: [KeyMod.CtrlCmd | KeyCode.KeyI],
                mac: {primary: KeyMod.WinCtrl | KeyCode.Space, secondary: [KeyMod.Alt | KeyCode.Escape, KeyMod.CtrlCmd | KeyCode.KeyI]},
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = SuggestController.get(editor);

        if (controller == null) {
            return;
        }

        var auto:Null<Bool> = null;
        if (args != null && JsValues.isObject(args)) {
            if (JsValues.field(args, 'auto') == true) {
                auto = true;
            }
        }

        controller.triggerSuggest(null, auto, null);
    }

}

/**
 * The registration of suggestController.ts (its module level code).
 */
class SuggestRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        // Monaco's editor worker service registers the word based completions
        // for every language when the first editor is created
        r.context.languageFeaturesService.completionProvider.register('*', new cityscape.common.services.WordBasedCompletions.WordBasedCompletionItemProvider(r.context));

        r.registerEditorContribution(SuggestController.ID, editor -> new SuggestController(editor), EditorContributionInstantiation.BeforeFirstInteraction);
        r.registerEditorAction(new TriggerSuggestAction(r));

        final weight = KeybindingWeight.EditorContrib + 90;

        function command(opts:IContributionCommandOptions<SuggestController>):Void {
            r.registerEditorCommand(new ContributionCommand<SuggestController>(SuggestController.get, opts));
        }

        command({
            id: 'acceptSelectedSuggestion',
            precondition: ContextKeyExpr.and(SuggestContext.Visible, SuggestContext.HasFocusedSuggestion),
            handler: (x, _) -> x.acceptSelectedSuggestion(true, false),
            kbOpts: [{
                // normal tab
                primary: KeyCode.Tab,
                kbExpr: ContextKeyExpr.and(SuggestContext.Visible, EditorContextKeys.textInputFocus),
                weight: weight,
            }, {
                // accept on enter has special rules
                primary: KeyCode.Enter,
                kbExpr: ContextKeyExpr.and(SuggestContext.Visible, EditorContextKeys.textInputFocus, SuggestContext.AcceptSuggestionsOnEnter, SuggestContext.MakesTextEdit),
                weight: weight,
            }]
        });

        command({
            id: 'acceptAlternativeSelectedSuggestion',
            precondition: ContextKeyExpr.and(SuggestContext.Visible, EditorContextKeys.textInputFocus, SuggestContext.HasFocusedSuggestion),
            kbOpts: {
                weight: weight,
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyMod.Shift | KeyCode.Enter,
                secondary: [KeyMod.Shift | KeyCode.Tab],
            },
            handler: (x, _) -> x.acceptSelectedSuggestion(false, true)
        });

        // continue to support the old command
        r.context.commandsRegistry.registerCommandAlias('acceptSelectedSuggestionOnEnter', 'acceptSelectedSuggestion');

        command({
            id: 'hideSuggestWidget',
            precondition: SuggestContext.Visible,
            handler: (x, _) -> x.cancelSuggestWidget(),
            kbOpts: {
                weight: weight,
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyCode.Escape,
                secondary: [KeyMod.Shift | KeyCode.Escape]
            }
        });

        final multipleOrNoFocus = ContextKeyExpr.and(SuggestContext.Visible, ContextKeyExpr.or(SuggestContext.MultipleSuggestions, SuggestContext.HasFocusedSuggestion.negate()));

        command({
            id: 'selectNextSuggestion',
            precondition: multipleOrNoFocus,
            handler: (c, _) -> c.selectNextSuggestion(),
            kbOpts: {
                weight: weight,
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyCode.DownArrow,
                secondary: [KeyMod.CtrlCmd | KeyCode.DownArrow],
                mac: {primary: KeyCode.DownArrow, secondary: [KeyMod.CtrlCmd | KeyCode.DownArrow, KeyMod.WinCtrl | KeyCode.KeyN]}
            }
        });

        command({
            id: 'selectNextPageSuggestion',
            precondition: multipleOrNoFocus,
            handler: (c, _) -> c.selectNextPageSuggestion(),
            kbOpts: {
                weight: weight,
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyCode.PageDown,
                secondary: [KeyMod.CtrlCmd | KeyCode.PageDown]
            }
        });

        command({
            id: 'selectLastSuggestion',
            precondition: multipleOrNoFocus,
            handler: (c, _) -> c.selectLastSuggestion()
        });

        command({
            id: 'selectPrevSuggestion',
            precondition: multipleOrNoFocus,
            handler: (c, _) -> c.selectPrevSuggestion(),
            kbOpts: {
                weight: weight,
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyCode.UpArrow,
                secondary: [KeyMod.CtrlCmd | KeyCode.UpArrow],
                mac: {primary: KeyCode.UpArrow, secondary: [KeyMod.CtrlCmd | KeyCode.UpArrow, KeyMod.WinCtrl | KeyCode.KeyP]}
            }
        });

        command({
            id: 'selectPrevPageSuggestion',
            precondition: multipleOrNoFocus,
            handler: (c, _) -> c.selectPrevPageSuggestion(),
            kbOpts: {
                weight: weight,
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyCode.PageUp,
                secondary: [KeyMod.CtrlCmd | KeyCode.PageUp]
            }
        });

        command({
            id: 'selectFirstSuggestion',
            precondition: multipleOrNoFocus,
            handler: (c, _) -> c.selectFirstSuggestion()
        });

        command({
            id: 'focusSuggestion',
            precondition: ContextKeyExpr.and(SuggestContext.Visible, SuggestContext.HasFocusedSuggestion.negate()),
            handler: (x, _) -> x.focusSuggestion(),
            kbOpts: {
                weight: weight,
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyMod.CtrlCmd | KeyCode.Space,
                secondary: [KeyMod.CtrlCmd | KeyCode.KeyI],
                mac: {primary: KeyMod.WinCtrl | KeyCode.Space, secondary: [KeyMod.CtrlCmd | KeyCode.KeyI]}
            }
        });

        command({
            id: 'focusAndAcceptSuggestion',
            precondition: ContextKeyExpr.and(SuggestContext.Visible, SuggestContext.HasFocusedSuggestion.negate()),
            handler: (c, _) -> {
                c.focusSuggestion();
                c.acceptSelectedSuggestion(true, false);
            }
        });

        command({
            id: 'toggleSuggestionDetails',
            precondition: ContextKeyExpr.and(SuggestContext.Visible, SuggestContext.HasFocusedSuggestion),
            handler: (x, _) -> x.toggleSuggestionDetails(),
            kbOpts: {
                weight: weight,
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyMod.CtrlCmd | KeyCode.Space,
                secondary: [KeyMod.CtrlCmd | KeyCode.KeyI],
                mac: {primary: KeyMod.WinCtrl | KeyCode.Space, secondary: [KeyMod.CtrlCmd | KeyCode.KeyI]}
            }
        });

        command({
            id: 'toggleExplainMode',
            precondition: SuggestContext.Visible,
            handler: (x, _) -> x.toggleExplainMode(),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib,
                primary: KeyMod.CtrlCmd | KeyCode.Slash,
            }
        });

        command({
            id: 'toggleSuggestionFocus',
            precondition: SuggestContext.Visible,
            handler: (x, _) -> x.toggleSuggestionFocus(),
            kbOpts: {
                weight: weight,
                kbExpr: EditorContextKeys.textInputFocus,
                primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.Space,
                mac: {primary: KeyMod.WinCtrl | KeyMod.Alt | KeyCode.Space}
            }
        });

        r.registerEditorAction(new ResetSuggestSizeAction(r));
    }

}

private class ResetSuggestSizeAction extends EditorAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.resetSuggestSize',
            label: r.localize('suggest.reset.label', "Reset Suggest Widget Size"),
            alias: 'Reset Suggest Widget Size',
            precondition: null
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = SuggestController.get(editor);
        if (controller != null) {
            controller.resetWidgetSize();
        }
    }

}
