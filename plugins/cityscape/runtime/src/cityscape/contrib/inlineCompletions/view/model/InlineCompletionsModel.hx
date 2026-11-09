// Ported from vscode src/vs/editor/contrib/inlineCompletions/browser/model/inlineCompletionsModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlineCompletions.view.model;

import cityscape.Cityscape;
import cityscape.base.common.Errors;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Observable;
import cityscape.base.common.Promise;
import cityscape.base.common.RegExp;
import cityscape.base.common.Strings;
import cityscape.base.common.observableInternal.Base;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.Languages;
import cityscape.common.Model;
import cityscape.common.TextModelEvents.IModelContentChangedEvent;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.core.TextEdit;
import cityscape.common.core.TextLength;
import cityscape.common.services.LanguageFeatureDebounce.IFeatureDebounceInformation;
import cityscape.contrib.inlineCompletions.view.Utils;
import cityscape.contrib.inlineCompletions.view.model.GhostText;
import cityscape.contrib.inlineCompletions.view.model.InlineCompletionsSource;
import cityscape.contrib.inlineCompletions.view.model.SingleTextEdit.SingleTextEditUtils;
import cityscape.contrib.inlineCompletions.view.model.SuggestWidgetAdaptor.SuggestItemInfo;
import cityscape.contrib.snippet.view.SnippetController2;
import cityscape.view.EditorBrowser.ICodeEditor;

/**
 * The state of the model (Monaco's anonymous object type of `state`).
 */
class InlineCompletionsModelState {

    public final edits:Array<SingleTextEdit>;
    public final primaryGhostText:GhostTextOrReplacement;
    public final ghostTexts:Array<GhostTextOrReplacement>;
    public final suggestItem:Null<SuggestItemInfo>;
    public final inlineCompletion:Null<InlineCompletionWithUpdatedRange>;

    public function new(edits:Array<SingleTextEdit>, primaryGhostText:GhostTextOrReplacement, ghostTexts:Array<GhostTextOrReplacement>, inlineCompletion:Null<InlineCompletionWithUpdatedRange>, suggestItem:Null<SuggestItemInfo>) {
        this.edits = edits;
        this.primaryGhostText = primaryGhostText;
        this.ghostTexts = ghostTexts;
        this.inlineCompletion = inlineCompletion;
        this.suggestItem = suggestItem;
    }

}

private class FetchChangeSummary {

    public var preserveCurrentCompletion:Bool = false;
    public var inlineCompletionTriggerKind:InlineCompletionTriggerKind = InlineCompletionTriggerKind.Automatic;

    public function new() {}

}

enum abstract VersionIdChangeReason(Int) {
    var Undo = 0;
    var Redo = 1;
    var AcceptWord = 2;
    var Other = 3;
}

/**
 * The inline completions of an editor's model: when to fetch them, which
 * one is selected, the ghost texts they give, accepting them (Monaco's
 * `InlineCompletionsModel`, with Monaco's observables:
 * `cityscape.base.common.Observable`). The command service, the language
 * configurations and the language features are the services of the
 * `Cityscape` context. Monaco's `async` methods return a `Promise` settled
 * when their work is done.
 */
class InlineCompletionsModel extends Disposable {

    final _source:InlineCompletionsSource;
    final _isActive:ISettableObservable<Bool>;
    final _forceUpdateExplicitlySignal:cityscape.base.common.observableInternal.Utils.ObservableSignal;

    // We use a semantic id to keep the same inline completion selected even if the provider reorders the completions.
    final _selectedInlineCompletionId:ISettableObservable<Null<String>>;
    final _primaryPosition:IObservable<Position>;

    var _isAcceptingPartially:Bool = false;
    public var isAcceptingPartially(get, never):Bool;
    function get_isAcceptingPartially():Bool {
        return this._isAcceptingPartially;
    }

    public final textModel:ITextModel;
    public final selectedSuggestItem:IObservable<Null<SuggestItemInfo>>;
    public final _textModelVersionId:IObservable<Null<Int>>;
    final _positions:IObservable<Array<Position>>;
    final _debounceValue:IFeatureDebounceInformation;
    final _suggestPreviewEnabled:IObservable<Bool>;
    final _suggestPreviewMode:IObservable<String>;
    final _inlineSuggestMode:IObservable<String>;
    final _enabled:IObservable<Bool>;
    final _context:Cityscape;

    final _fetchInlineCompletionsPromise:IObservable<Null<Promise<Bool>>>;
    final _filteredInlineCompletionItems:IObservable<Array<InlineCompletionWithUpdatedRange>>;
    public final selectedInlineCompletionIndex:IObservable<Int>;
    public final selectedInlineCompletion:IObservable<Null<InlineCompletionWithUpdatedRange>>;
    public final activeCommands:IObservable<Array<Command>>;
    public final lastTriggerKind:IObservable<Null<InlineCompletionTriggerKind>>;
    public final inlineCompletionsCount:IObservable<Null<Int>>;
    public final state:IObservable<Null<InlineCompletionsModelState>>;
    public final ghostTexts:IObservable<Null<Array<GhostTextOrReplacement>>>;
    public final primaryGhostText:IObservable<Null<GhostTextOrReplacement>>;

    /**
     * @param suggestPreviewMode, inlineSuggestMode: `'prefix'`, `'subword'` or `'subwordSmart'`
     */
    public function new(
        textModel:ITextModel,
        selectedSuggestItem:IObservable<Null<SuggestItemInfo>>,
        textModelVersionId:IObservable<Null<Int>>,
        positions:IObservable<Array<Position>>,
        debounceValue:IFeatureDebounceInformation,
        suggestPreviewEnabled:IObservable<Bool>,
        suggestPreviewMode:IObservable<String>,
        inlineSuggestMode:IObservable<String>,
        enabled:IObservable<Bool>,
        context:Cityscape
    ) {
        super();
        this.textModel = textModel;
        this.selectedSuggestItem = selectedSuggestItem;
        this._textModelVersionId = textModelVersionId;
        this._positions = positions;
        this._debounceValue = debounceValue;
        this._suggestPreviewEnabled = suggestPreviewEnabled;
        this._suggestPreviewMode = suggestPreviewMode;
        this._inlineSuggestMode = inlineSuggestMode;
        this._enabled = enabled;
        this._context = context;

        this._source = this._register(new InlineCompletionsSource(this.textModel, this._textModelVersionId, this._debounceValue, context));
        this._isActive = Observable.observableValue('isActive', false);
        this._forceUpdateExplicitlySignal = Observable.observableSignal('forceUpdateExplicitly');
        this._selectedInlineCompletionId = Observable.observableValue('selectedInlineCompletionId', (null : Null<String>));
        this._primaryPosition = Observable.derived(reader -> {
            final positions = this._positions.read(reader);
            return positions.length > 0 && positions[0] != null ? positions[0] : new Position(1, 1);
        });

        this._fetchInlineCompletionsPromise = Observable.derivedHandleChanges({
            createEmptyChangeSummary: () -> new FetchChangeSummary(),
            handleChange: (ctx, changeSummary) -> {
                /** @description fetch inline completions */
                if (ctx.didChange(this._textModelVersionId) && this._preserveCurrentCompletionReasons(this._getReason(ctx.change))) {
                    changeSummary.preserveCurrentCompletion = true;
                }
                else if (ctx.didChange(this._forceUpdateExplicitlySignal)) {
                    changeSummary.inlineCompletionTriggerKind = InlineCompletionTriggerKind.Explicit;
                }
                return true;
            },
        }, (reader, changeSummary:FetchChangeSummary) -> {
            this._forceUpdateExplicitlySignal.read(reader);
            final shouldUpdate = (this._enabled.read(reader) && this.selectedSuggestItem.read(reader) != null) || this._isActive.read(reader);
            if (!shouldUpdate) {
                this._source.cancelUpdate();
                return null;
            }

            this._textModelVersionId.read(reader); // Refetch on text change

            final suggestWidgetInlineCompletions = this._source.suggestWidgetInlineCompletions.get();
            final suggestItem = this.selectedSuggestItem.read(reader);
            if (suggestWidgetInlineCompletions != null && suggestItem == null) {
                final inlineCompletions = this._source.inlineCompletions.get();
                Observable.transaction(tx -> {
                    /** @description Seed inline completions with (newer) suggest widget inline completions */
                    if (inlineCompletions == null || suggestWidgetInlineCompletions.request.versionId > inlineCompletions.request.versionId) {
                        this._source.inlineCompletions.set(suggestWidgetInlineCompletions.clone(), tx);
                    }
                    this._source.clearSuggestWidgetInlineCompletions(tx);
                });
            }

            final cursorPosition = this._primaryPosition.read(reader);
            final context:InlineCompletionContext = {
                triggerKind: changeSummary.inlineCompletionTriggerKind,
                selectedSuggestionInfo: suggestItem != null ? suggestItem.toSelectedSuggestionInfo() : null,
            };
            final itemToPreserveCandidate = this.selectedInlineCompletion.get();
            final itemToPreserve = changeSummary.preserveCurrentCompletion || (itemToPreserveCandidate != null && itemToPreserveCandidate.forwardStable)
                ? itemToPreserveCandidate : null;
            return this._source.fetch(cursorPosition, context, itemToPreserve);
        });

        this._filteredInlineCompletionItems = Observable.derivedOpts({equalsFn: itemsEquals}, reader -> {
            final c = this._source.inlineCompletions.read(reader);
            if (c == null) {
                return [];
            }
            final cursorPosition = this._primaryPosition.read(reader);
            final filteredCompletions = c.inlineCompletions.filter(c -> c.isVisible(this.textModel, cursorPosition, reader));
            return filteredCompletions;
        });

        this.selectedInlineCompletionIndex = Observable.derived(reader -> {
            final selectedInlineCompletionId = this._selectedInlineCompletionId.read(reader);
            final filteredCompletions = this._filteredInlineCompletionItems.read(reader);
            var idx = -1;
            for (i in 0...filteredCompletions.length) {
                if (filteredCompletions[i].semanticId == selectedInlineCompletionId) {
                    idx = i;
                    break;
                }
            }
            if (idx == -1) {
                // Reset the selection so that the selection does not jump back when it appears again
                this._selectedInlineCompletionId.set(null, null);
                return 0;
            }
            return idx;
        });

        this.selectedInlineCompletion = Observable.derived(reader -> {
            final filteredCompletions = this._filteredInlineCompletionItems.read(reader);
            final idx = this.selectedInlineCompletionIndex.read(reader);
            return idx < filteredCompletions.length ? filteredCompletions[idx] : null;
        });

        this.activeCommands = Observable.derivedOpts({equalsFn: (a:Array<Command>, b:Array<Command>) -> {
            if (a.length != b.length) {
                return false;
            }
            for (i in 0...a.length) {
                if (a[i] != b[i]) {
                    return false;
                }
            }
            return true;
        }}, r -> {
            final c = this.selectedInlineCompletion.read(r);
            final commands = c != null ? c.inlineCompletion.source.inlineCompletions.commands : null;
            return commands != null ? commands : [];
        });

        this.lastTriggerKind = this._source.inlineCompletions.map((v, _) -> v != null ? (v.request.context.triggerKind : Null<InlineCompletionTriggerKind>) : null);

        this.inlineCompletionsCount = Observable.derived(reader -> {
            if (this.lastTriggerKind.read(reader) == InlineCompletionTriggerKind.Explicit) {
                return (this._filteredInlineCompletionItems.read(reader).length : Null<Int>);
            }
            else {
                return null;
            }
        });

        this.state = Observable.derivedOpts({
            equalsFn: (a:Null<InlineCompletionsModelState>, b:Null<InlineCompletionsModelState>) -> {
                if (a == null || b == null) {
                    return a == b;
                }
                return GhostTextOrReplacement.ghostTextsOrReplacementsEqual(a.ghostTexts, b.ghostTexts)
                    && a.inlineCompletion == b.inlineCompletion
                    && a.suggestItem == b.suggestItem;
            }
        }, (reader) -> {
            final model = this.textModel;

            final suggestItem = this.selectedSuggestItem.read(reader);
            if (suggestItem != null) {
                final suggestCompletionEdit = SingleTextEditUtils.singleTextRemoveCommonPrefix(suggestItem.toSingleTextEdit(), model);
                final augmentation = this._computeAugmentation(suggestCompletionEdit, reader);

                final isSuggestionPreviewEnabled = this._suggestPreviewEnabled.read(reader);
                if (!isSuggestionPreviewEnabled && augmentation == null) {
                    return null;
                }

                final fullEdit = augmentation != null ? augmentation.edit : suggestCompletionEdit;
                final fullEditPreviewLength = augmentation != null ? augmentation.edit.text.length - suggestCompletionEdit.text.length : 0;

                final mode = this._suggestPreviewMode.read(reader);
                final positions = this._positions.read(reader);
                final edits = [fullEdit].concat(getSecondaryEdits(this.textModel, positions, fullEdit));
                final ghostTexts:Array<GhostTextOrReplacement> = [];
                for (idx in 0...edits.length) {
                    final g = SingleTextEditUtils.computeGhostText(edits[idx], model, mode, positions[idx], fullEditPreviewLength);
                    if (g != null) {
                        ghostTexts.push(g);
                    }
                }
                final primaryGhostText:GhostTextOrReplacement = ghostTexts.length > 0 ? ghostTexts[0] : new GhostText(fullEdit.range.endLineNumber, []);
                return new InlineCompletionsModelState(edits, primaryGhostText, ghostTexts, augmentation != null ? augmentation.completion : null, suggestItem);
            }
            else {
                if (!this._isActive.read(reader)) {
                    return null;
                }
                final inlineCompletion = this.selectedInlineCompletion.read(reader);
                if (inlineCompletion == null) {
                    return null;
                }

                final replacement = inlineCompletion.toSingleTextEdit(reader);
                final mode = this._inlineSuggestMode.read(reader);
                final positions = this._positions.read(reader);
                final edits = [replacement].concat(getSecondaryEdits(this.textModel, positions, replacement));
                final ghostTexts:Array<GhostTextOrReplacement> = [];
                for (idx in 0...edits.length) {
                    final g = SingleTextEditUtils.computeGhostText(edits[idx], model, mode, positions[idx], 0);
                    if (g != null) {
                        ghostTexts.push(g);
                    }
                }
                if (ghostTexts.length == 0) {
                    return null;
                }
                return new InlineCompletionsModelState(edits, ghostTexts[0], ghostTexts, inlineCompletion, null);
            }
        });

        this.ghostTexts = Observable.derivedOpts({equalsFn: GhostTextOrReplacement.ghostTextsOrReplacementsEqual}, reader -> {
            final v = this.state.read(reader);
            if (v == null) {
                return null;
            }
            return v.ghostTexts;
        });

        this.primaryGhostText = Observable.derivedOpts({equalsFn: GhostTextOrReplacement.ghostTextOrReplacementEquals}, reader -> {
            final v = this.state.read(reader);
            if (v == null) {
                return null;
            }
            return v.primaryGhostText;
        });

        this._register(Observable.recomputeInitiallyAndOnChange(this._fetchInlineCompletionsPromise));

        var lastItem:Null<InlineCompletionWithUpdatedRange> = null;
        this._register(Observable.autorun(reader -> {
            /** @description call handleItemDidShow */
            final item = this.state.read(reader);
            final completion = item != null ? item.inlineCompletion : null;
            final completionId = completion != null ? completion.semanticId : null;
            final lastId = lastItem != null ? lastItem.semanticId : null;
            if (completionId != lastId) {
                lastItem = completion;
                if (completion != null) {
                    final i = completion.inlineCompletion;
                    final src = i.source;
                    if (src.provider.handleItemDidShow != null) {
                        src.provider.handleItemDidShow(src.inlineCompletions, i.sourceInlineCompletion, i.insertText);
                    }
                }
            }
        }));
    }

    static function itemsEquals(a:Array<InlineCompletionWithUpdatedRange>, b:Array<InlineCompletionWithUpdatedRange>):Bool {
        if (a.length != b.length) {
            return false;
        }
        for (i in 0...a.length) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
    }

    function _preserveCurrentCompletionReasons(reason:VersionIdChangeReason):Bool {
        return reason == VersionIdChangeReason.Redo || reason == VersionIdChangeReason.Undo || reason == VersionIdChangeReason.AcceptWord;
    }

    function _getReason(change:Any):VersionIdChangeReason {
        final e:Null<IModelContentChangedEvent> = change;
        if (e != null && e.isUndoing) {
            return VersionIdChangeReason.Undo;
        }
        if (e != null && e.isRedoing) {
            return VersionIdChangeReason.Redo;
        }
        if (this.isAcceptingPartially) {
            return VersionIdChangeReason.AcceptWord;
        }
        return VersionIdChangeReason.Other;
    }

    static function settled(p:Null<Promise<Bool>>):Promise<Any> {
        if (p == null) {
            return Promise.resolve(null);
        }
        return p.then(_ -> (null : Any));
    }

    public function trigger(?tx:ITransaction):Promise<Any> {
        this._isActive.set(true, tx);
        return settled(this._fetchInlineCompletionsPromise.get());
    }

    public function triggerExplicitly(?tx:ITransaction):Promise<Any> {
        Observable.subtransaction(tx, tx -> {
            this._isActive.set(true, tx);
            this._forceUpdateExplicitlySignal.trigger(tx);
        });
        return settled(this._fetchInlineCompletionsPromise.get());
    }

    public function stop(?tx:ITransaction):Void {
        Observable.subtransaction(tx, tx -> {
            this._isActive.set(false, tx);
            this._source.clear(tx);
        });
    }

    function _computeAugmentation(suggestCompletion:SingleTextEdit, reader:Null<IReader>):Null<{completion:InlineCompletionWithUpdatedRange, edit:SingleTextEdit}> {
        final model = this.textModel;
        final suggestWidgetInlineCompletions = this._source.suggestWidgetInlineCompletions.read(reader);
        final candidateInlineCompletions:Array<InlineCompletionWithUpdatedRange> = if (suggestWidgetInlineCompletions != null) {
            suggestWidgetInlineCompletions.inlineCompletions;
        }
        else {
            final s = this.selectedInlineCompletion.read(reader);
            s != null ? [s] : [];
        };

        for (completion in candidateInlineCompletions) {
            var r = completion.toSingleTextEdit(reader);
            r = SingleTextEditUtils.singleTextRemoveCommonPrefix(
                r,
                model,
                Range.fromPositions(r.range.getStartPosition(), suggestCompletion.range.getEndPosition())
            );
            if (SingleTextEditUtils.singleTextEditAugments(r, suggestCompletion)) {
                return {completion: completion, edit: r};
            }
        }

        return null;
    }

    function _deltaSelectedInlineCompletionIndex(delta:Int):Promise<Any> {
        return this.triggerExplicitly().then(_ -> {
            final completions = this._filteredInlineCompletionItems.get();
            if (completions.length > 0) {
                final newIdx = (this.selectedInlineCompletionIndex.get() + delta + completions.length) % completions.length;
                this._selectedInlineCompletionId.set(completions[newIdx].semanticId, null);
            }
            else {
                this._selectedInlineCompletionId.set(null, null);
            }
            return (null : Any);
        });
    }

    public function next():Promise<Any> {
        return this._deltaSelectedInlineCompletionIndex(1);
    }

    public function previous():Promise<Any> {
        return this._deltaSelectedInlineCompletionIndex(-1);
    }

    public function accept(editor:ICodeEditor):Void {
        if (editor.getModel() != this.textModel) {
            throw 'BugIndicatingError';
        }

        final state = this.state.get();
        if (state == null || state.primaryGhostText.isEmpty() || state.inlineCompletion == null) {
            return;
        }
        final completion = state.inlineCompletion.toInlineCompletion(null);

        if (completion.command != null) {
            // Make sure the completion list will not be disposed.
            completion.source.addRef();
        }

        editor.pushUndoStop();
        if (completion.snippetInfo != null) {
            final ops:Array<IIdentifiedSingleEditOperation> = [EditOperation.replace(completion.range, '')];
            for (e in completion.additionalTextEdits) {
                ops.push(toIdentifiedOperation(e));
            }
            editor.executeEdits('inlineSuggestion.accept', ops);
            editor.setPosition(completion.snippetInfo.range.getStartPosition(), 'inlineCompletionAccept');
            final snippetController = SnippetController2.get(editor);
            if (snippetController != null) {
                snippetController.insert(completion.snippetInfo.snippet, {undoStopBefore: false});
            }
        }
        else {
            final edits = state.edits;
            final selections:Array<ISelection> = [for (p in getEndPositionsAfterApplying(edits)) Selection.fromPositions(p)];
            final ops:Array<IIdentifiedSingleEditOperation> = [for (edit in edits) EditOperation.replace(edit.range, edit.text)];
            for (e in completion.additionalTextEdits) {
                ops.push(toIdentifiedOperation(e));
            }
            editor.executeEdits('inlineSuggestion.accept', ops);
            editor.setSelections(selections, 'inlineCompletionAccept');
        }

        // Reset before invoking the command, as the command might cause a follow up trigger (which we don't want to reset).
        this.stop();

        if (completion.command != null) {
            try {
                this._context.commandService.executeCommand(completion.command.id, completion.command.arguments != null ? completion.command.arguments : []);
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedExternalError(e);
            }
            completion.source.removeRef();
        }
    }

    static function toIdentifiedOperation(e:ISingleEditOperation):IIdentifiedSingleEditOperation {
        return {range: e.range, text: e.text, forceMoveMarkers: e.forceMoveMarkers};
    }

    public function acceptNextWord(editor:ICodeEditor):Void {
        this._acceptNext(editor, (pos, text) -> {
            final langId = this.textModel.getLanguageIdAtPosition(pos.lineNumber, pos.column);
            final config = this._context.languageConfigurationService.getLanguageConfiguration(langId);
            final wordRegExp = new RegExp(config.wordDefinition.source, StringTools.replace(config.wordDefinition.flags, 'g', ''));

            final m1 = wordRegExp.exec(text);
            var acceptUntilIndexExclusive = 0;
            if (m1 != null) {
                if (m1.index == 0) {
                    acceptUntilIndexExclusive = m1[0].length;
                }
                else {
                    acceptUntilIndexExclusive = m1.index;
                }
            }
            else {
                acceptUntilIndexExclusive = text.length;
            }

            final wsRegExp = new RegExp('\\s+', 'g');
            final m2 = wsRegExp.exec(text);
            if (m2 != null) {
                if (m2.index + m2[0].length < acceptUntilIndexExclusive) {
                    acceptUntilIndexExclusive = m2.index + m2[0].length;
                }
            }
            return acceptUntilIndexExclusive;
        }, PartialAcceptTriggerKind.Word);
    }

    public function acceptNextLine(editor:ICodeEditor):Void {
        this._acceptNext(editor, (pos, text) -> {
            final index = text.indexOf('\n');
            if (index != -1) {
                return index + 1;
            }
            return text.length;
        }, PartialAcceptTriggerKind.Line);
    }

    function _acceptNext(editor:ICodeEditor, getAcceptUntilIndex:(position:Position, text:String) -> Int, kind:PartialAcceptTriggerKind):Void {
        if (editor.getModel() != this.textModel) {
            throw 'BugIndicatingError';
        }

        final state = this.state.get();
        if (state == null || state.primaryGhostText.isEmpty() || state.inlineCompletion == null) {
            return;
        }
        final ghostText = state.primaryGhostText;
        final completion = state.inlineCompletion.toInlineCompletion(null);

        if (completion.snippetInfo != null || completion.filterText != completion.insertText) {
            // not in WYSIWYG mode, partial commit might change completion, thus it is not supported
            this.accept(editor);
            return;
        }

        final firstPart = ghostText.parts[0];
        final ghostTextPos = new Position(ghostText.lineNumber, firstPart.column);
        final ghostTextVal = firstPart.text;
        final acceptUntilIndexExclusive = getAcceptUntilIndex(ghostTextPos, ghostTextVal);
        if (acceptUntilIndexExclusive == ghostTextVal.length && ghostText.parts.length == 1) {
            this.accept(editor);
            return;
        }
        final partialGhostTextVal = ghostTextVal.substring(0, acceptUntilIndexExclusive);

        final positions = this._positions.get();
        final cursorPosition = positions[0];

        // Executing the edit might free the completion, so we have to hold a reference on it.
        completion.source.addRef();
        var error:Null<haxe.Exception> = null;
        try {
            this._isAcceptingPartially = true;
            try {
                editor.pushUndoStop();
                final replaceRange = Range.fromPositions(cursorPosition, ghostTextPos);
                final newText = editor.getModel().getValueInRange(replaceRange) + partialGhostTextVal;
                final primaryEdit = new SingleTextEdit(replaceRange, newText);
                final edits = [primaryEdit].concat(getSecondaryEdits(this.textModel, positions, primaryEdit));
                final selections:Array<ISelection> = [for (p in getEndPositionsAfterApplying(edits)) Selection.fromPositions(p)];
                editor.executeEdits('inlineSuggestion.accept', [for (edit in edits) EditOperation.replace(edit.range, edit.text)]);
                editor.setSelections(selections, 'inlineCompletionPartialAccept');
                editor.revealPositionInCenterIfOutsideViewport(editor.getPosition(), ScrollType.Immediate);
            }
            catch (e:haxe.Exception) {
                this._isAcceptingPartially = false;
                throw e;
            }
            this._isAcceptingPartially = false;

            final handlePartialAccept = completion.source.provider.handlePartialAccept;
            if (handlePartialAccept != null) {
                final acceptedRange = Range.fromPositions(completion.range.getStartPosition(), TextLength.ofText(partialGhostTextVal).addToPosition(ghostTextPos));
                // This assumes that the inline completion and the model use the same EOL style.
                final text = editor.getModel().getValueInRange(acceptedRange, EndOfLinePreference.LF);
                handlePartialAccept(
                    completion.source.inlineCompletions,
                    completion.sourceInlineCompletion,
                    text.length,
                    {kind: kind}
                );
            }
        }
        catch (e:haxe.Exception) {
            error = e;
        }
        completion.source.removeRef();
        if (error != null) {
            throw error;
        }
    }

    public function handleSuggestAccepted(item:SuggestItemInfo):Void {
        final itemEdit = SingleTextEditUtils.singleTextRemoveCommonPrefix(item.toSingleTextEdit(), this.textModel);
        final augmentedCompletion = this._computeAugmentation(itemEdit, null);
        if (augmentedCompletion == null) {
            return;
        }

        final inlineCompletion = augmentedCompletion.completion.inlineCompletion;
        final handlePartialAccept = inlineCompletion.source.provider.handlePartialAccept;
        if (handlePartialAccept != null) {
            handlePartialAccept(
                inlineCompletion.source.inlineCompletions,
                inlineCompletion.sourceInlineCompletion,
                itemEdit.text.length,
                {
                    kind: PartialAcceptTriggerKind.Suggest,
                }
            );
        }
    }

    public static function getSecondaryEdits(textModel:ITextModel, positions:Array<Position>, primaryEdit:SingleTextEdit):Array<SingleTextEdit> {
        if (positions.length == 1) {
            // No secondary cursor positions
            return [];
        }
        final primaryPosition = positions[0];
        final secondaryPositions = positions.slice(1);
        final primaryEditStartPosition = primaryEdit.range.getStartPosition();
        final primaryEditEndPosition = primaryEdit.range.getEndPosition();
        final replacedTextAfterPrimaryCursor = textModel.getValueInRange(
            Range.fromPositions(primaryPosition, primaryEditEndPosition)
        );
        final positionWithinTextEdit = Utils.subtractPositions(primaryPosition, primaryEditStartPosition);
        if (positionWithinTextEdit.lineNumber < 1) {
            Errors.onUnexpectedError('BugIndicatingError: positionWithinTextEdit line number should be bigger than 0.\n'
                + '\t\t\tInvalid subtraction between ' + primaryPosition.toString() + ' and ' + primaryEditStartPosition.toString());
            return [];
        }
        final secondaryEditText = substringPos(primaryEdit.text, positionWithinTextEdit);
        return [for (pos in secondaryPositions) {
            final posEnd = Utils.addPositions(Utils.subtractPositions(pos, primaryEditStartPosition), primaryEditEndPosition);
            final textAfterSecondaryCursor = textModel.getValueInRange(
                Range.fromPositions(pos, posEnd)
            );
            final l = Strings.commonPrefixLength(replacedTextAfterPrimaryCursor, textAfterSecondaryCursor);
            final range = Range.fromPositions(pos, pos.delta(0, l));
            new SingleTextEdit(range, secondaryEditText);
        }];
    }

    static function substringPos(text:String, pos:Position):String {
        var subtext = '';
        final lines = splitLinesIncludeSeparators(text);
        for (i in pos.lineNumber - 1...lines.length) {
            subtext += lines[i].substring(i == pos.lineNumber - 1 ? pos.column - 1 : 0);
        }
        return subtext;
    }

    /**
     * `splitLinesIncludeSeparators` of strings.ts: the lines of `str`, each
     * with its line break (`\r\n`, `\r` or `\n`).
     */
    static function splitLinesIncludeSeparators(str:String):Array<String> {
        final result:Array<String> = [];
        var start = 0;
        var i = 0;
        final len = str.length;
        while (i < len) {
            final c = StringTools.fastCodeAt(str, i);
            if (c == '\r'.code) {
                if (i + 1 < len && StringTools.fastCodeAt(str, i + 1) == '\n'.code) {
                    i++;
                }
                result.push(str.substring(start, i + 1));
                start = i + 1;
            }
            else if (c == '\n'.code) {
                result.push(str.substring(start, i + 1));
                start = i + 1;
            }
            i++;
        }
        result.push(str.substring(start, len));
        return result;
    }

    static function getEndPositionsAfterApplying(edits:Array<SingleTextEdit>):Array<Position> {
        // Permutation.createSortPermutation(edits, compareBy(e => e.range, Range.compareRangesUsingStarts))
        final sortPerm = [for (i in 0...edits.length) i];
        haxe.ds.ArraySort.sort(sortPerm, (a, b) -> Range.compareRangesUsingStarts(edits[a].range, edits[b].range));
        final edit = new TextEdit([for (i in sortPerm) edits[i]]);
        final sortedNewRanges = edit.getNewRanges();
        final newRanges:Array<Range> = [for (_ in 0...edits.length) null];
        for (k in 0...sortPerm.length) {
            newRanges[sortPerm[k]] = sortedNewRanges[k];
        }
        return [for (range in newRanges) range.getEndPosition()];
    }

}
