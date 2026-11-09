// Ported from vscode src/vs/editor/contrib/wordHighlighter/browser/wordHighlighter.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.wordHighlighter.view;

import cityscape.Cityscape;
import cityscape.base.common.Async;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.KeyCodes.KeyMod;
import cityscape.base.common.Lifecycle;
import cityscape.common.CursorEvents;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorCommon.IEditorDecorationsCollection;
import cityscape.common.EditorContextKeys;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.LanguageSelector.LanguageSelectorUtils;
import cityscape.common.Languages;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.core.WordHelper.IWordAtPosition;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/*
 * Differences with Monaco (see DEVIATIONS.md):
 * - Monaco keeps the query and the decoration ids of each model in statics
 *   of `WordHighlighter` (one per page); they belong to the `Cityscape`
 *   context here (`WordHighlighterState`, created by the registration).
 * - Providers give their result to a callback (at once or later), and are
 *   asked in order of score until one answers (Monaco's `first`).
 * - The aria alert of `moveNext`/`moveBack` is not ported (no screen
 *   reader support), neither are notebooks and diff editors (Cityscape has
 *   none).
 */

/**
 * The state Monaco keeps in statics of `WordHighlighter`, per context.
 */
class WordHighlighterState {

    /**
     * The decoration ids of each model (by `uri.toString()`).
     */
    public var storedDecorationIDs:Map<String, Array<String>> = new Map();

    public var query:Null<IWordHighlighterQuery> = null;

    public function new() {}

}

typedef IWordHighlighterQueryModelInfo = {
    var model:ITextModel;
    var selection:Selection;
}

typedef IWordHighlighterQuery = {
    var modelInfo:Null<IWordHighlighterQueryModelInfo>;
    final word:Null<IWordAtPosition>;
}

class WordHighlighterUtils {

    public static final ctxHasWordHighlights = new RawContextKey<Bool>('hasWordHighlights', false);

    /**
     * Monaco's `first`: runs the providers in order until one gives a
     * result accepted by `accept`, then calls `done` with it (null when none
     * did).
     */
    static function first<T>(providers:Array<(resolve:(value:Null<T>) -> Void) -> Void>, accept:(value:Null<T>) -> Bool, token:CancellationToken, done:(value:Null<T>) -> Void):Void {
        var index = 0;
        function loop():Void {
            if (token.isCancellationRequested) {
                return;
            }
            if (index >= providers.length) {
                done(null);
                return;
            }
            final provider = providers[index++];
            var answered = false;
            try {
                provider(value -> {
                    if (answered) {
                        return;
                    }
                    answered = true;
                    if (accept(value)) {
                        done(value);
                    }
                    else {
                        loop();
                    }
                });
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedExternalError(e);
                if (!answered) {
                    answered = true;
                    loop();
                }
            }
        }
        loop();
    }

    public static function getOccurrencesAtPosition(registry:LanguageFeatureRegistry<DocumentHighlightProvider>, model:ITextModel, position:Position, token:CancellationToken, done:(result:Map<String, Array<DocumentHighlight>>) -> Void):Void {
        final orderedByScore = registry.ordered(model);

        // in order of score ask the occurrences provider
        // until someone response with a good result
        // (good = non undefined and non null value)
        // (result of size == 0 is valid, no highlights is a valid/expected result -- not a signal to fall back to other providers)
        first([for (provider in orderedByScore) (resolve:(value:Null<Array<DocumentHighlight>>) -> Void) -> {
            provider.provideDocumentHighlights(model, position, token, resolve);
        }], result -> result != null, token, result -> {
            final map = new Map<String, Array<DocumentHighlight>>();
            if (result != null) {
                map.set(model.uri.toString(), result);
            }
            done(map);
        });
    }

    public static function getOccurrencesAcrossMultipleModels(registry:LanguageFeatureRegistry<MultiDocumentHighlightProvider>, model:ITextModel, position:Position, wordSeparators:String, token:CancellationToken, otherModels:Array<ITextModel>, done:(result:Null<Map<String, Array<DocumentHighlight>>>) -> Void):Void {
        final orderedByScore = registry.ordered(model);

        // in order of score ask the occurrences provider
        // until someone response with a good result
        // (good = non undefined and non null ResourceMap)
        // (result of size == 0 is valid, no highlights is a valid/expected result -- not a signal to fall back to other providers)
        first([for (provider in orderedByScore) (resolve:(value:Null<Map<String, Array<DocumentHighlight>>>) -> Void) -> {
            final filteredModels = otherModels.filter(otherModel -> {
                return ModelUtils.shouldSynchronizeModel(otherModel);
            }).filter(otherModel -> {
                return LanguageSelectorUtils.score(provider.selector, otherModel.uri, otherModel.getLanguageId(), true, null, null) > 0;
            });
            provider.provideMultiDocumentHighlights(model, position, filteredModels, token, resolve);
        }], result -> result != null, token, done);
    }

}

/**
 * Monaco's `IOccurenceAtPositionRequest`: a request whose result arrives
 * through `onResult` (Monaco's `result` promise).
 */
abstract class OccurenceAtPositionRequest {

    final _model:ITextModel;
    final _selection:Selection;
    final _wordSeparators:String;
    final _wordRange:Null<Range>;
    var _started:Bool = false;
    final _source:CancellationTokenSource = new CancellationTokenSource();

    public function new(model:ITextModel, selection:Selection, wordSeparators:String) {
        this._model = model;
        this._selection = selection;
        this._wordSeparators = wordSeparators;
        this._wordRange = this._getCurrentWordRange(model, selection);
    }

    /**
     * Starts the computation (once) and gives the result to `callback`
     * unless the request is cancelled first.
     */
    public function onResult(callback:(result:Map<String, Array<DocumentHighlight>>) -> Void):Void {
        if (_started) {
            return;
        }
        _started = true;
        final token = _source.token;
        this._compute(this._model, this._selection, this._wordSeparators, token, result -> {
            if (!token.isCancellationRequested) {
                callback(result);
            }
        });
    }

    abstract function _compute(model:ITextModel, selection:Selection, wordSeparators:String, token:CancellationToken, done:(result:Map<String, Array<DocumentHighlight>>) -> Void):Void;

    function _getCurrentWordRange(model:ITextModel, selection:Selection):Null<Range> {
        final word = model.getWordAtPosition(selection.getPosition());
        if (word != null) {
            return new Range(selection.startLineNumber, word.startColumn, selection.startLineNumber, word.endColumn);
        }
        return null;
    }

    public function isValid(model:ITextModel, selection:Selection, decorations:IEditorDecorationsCollection):Bool {

        final lineNumber = selection.startLineNumber;
        final startColumn = selection.startColumn;
        final endColumn = selection.endColumn;
        final currentWordRange = this._getCurrentWordRange(model, selection);

        var requestIsValid = (this._wordRange != null && this._wordRange.equalsRange(currentWordRange));

        // Even if we are on a different word, if that word is in the decorations ranges, the request is still valid
        // (Same symbol)
        var i = 0;
        final len = decorations.length;
        while (!requestIsValid && i < len) {
            final range = decorations.getRange(i);
            if (range != null && range.startLineNumber == lineNumber) {
                if (range.startColumn <= startColumn && range.endColumn >= endColumn) {
                    requestIsValid = true;
                }
            }
            i++;
        }

        return requestIsValid;
    }

    public function cancel():Void {
        this._source.cancel();
    }

}

class SemanticOccurenceAtPositionRequest extends OccurenceAtPositionRequest {

    final _providers:LanguageFeatureRegistry<DocumentHighlightProvider>;

    public function new(model:ITextModel, selection:Selection, wordSeparators:String, providers:LanguageFeatureRegistry<DocumentHighlightProvider>) {
        super(model, selection, wordSeparators);
        this._providers = providers;
    }

    function _compute(model:ITextModel, selection:Selection, wordSeparators:String, token:CancellationToken, done:(result:Map<String, Array<DocumentHighlight>>) -> Void):Void {
        WordHighlighterUtils.getOccurrencesAtPosition(this._providers, model, selection.getPosition(), token, value -> {
            done(value != null ? value : new Map());
        });
    }

}

class MultiModelOccurenceRequest extends OccurenceAtPositionRequest {

    final _providers:LanguageFeatureRegistry<MultiDocumentHighlightProvider>;
    final _otherModels:Array<ITextModel>;

    public function new(model:ITextModel, selection:Selection, wordSeparators:String, providers:LanguageFeatureRegistry<MultiDocumentHighlightProvider>, otherModels:Array<ITextModel>) {
        super(model, selection, wordSeparators);
        this._providers = providers;
        this._otherModels = otherModels;
    }

    function _compute(model:ITextModel, selection:Selection, wordSeparators:String, token:CancellationToken, done:(result:Map<String, Array<DocumentHighlight>>) -> Void):Void {
        WordHighlighterUtils.getOccurrencesAcrossMultipleModels(this._providers, model, selection.getPosition(), wordSeparators, token, this._otherModels, value -> {
            done(value != null ? value : new Map());
        });
    }

}

class WordHighlighter {

    final editor:ICodeEditor;
    final providers:LanguageFeatureRegistry<DocumentHighlightProvider>;
    final multiDocumentProviders:LanguageFeatureRegistry<MultiDocumentHighlightProvider>;
    final model:ITextModel;
    public final decorations:IEditorDecorationsCollection;
    final toUnhook = new DisposableStore();
    final state:WordHighlighterState;
    var occurrencesHighlight:String;

    var workerRequestTokenId:Int = 0;
    public var workerRequest:Null<OccurenceAtPositionRequest>;
    var workerRequestCompleted:Bool = false;
    var workerRequestValue:Map<String, Array<DocumentHighlight>> = new Map();

    var lastCursorPositionChangeTime:Float = 0;
    var renderDecorationsTimer:Null<() -> Void> = null;

    public final _hasWordHighlights:IContextKey<Bool>;
    var _ignorePositionChangeEvent:Bool;

    final runDelayer:Delayer;

    public function new(editor:ICodeEditor, providers:LanguageFeatureRegistry<DocumentHighlightProvider>, multiProviders:LanguageFeatureRegistry<MultiDocumentHighlightProvider>, contextKeyService:IContextKeyService, state:WordHighlighterState) {
        this.runDelayer = this.toUnhook.add(new Delayer(50));
        this.editor = editor;
        this.providers = providers;
        this.multiDocumentProviders = multiProviders;
        this.state = state;
        this._hasWordHighlights = WordHighlighterUtils.ctxHasWordHighlights.bindTo(contextKeyService);
        this._ignorePositionChangeEvent = false;
        this.occurrencesHighlight = this.editor.getOption(EditorOption.occurrencesHighlight);
        this.model = this.editor.getModel();
        this.toUnhook.add(editor.onDidChangeCursorPosition((e:ICursorPositionChangedEvent) -> {
            if (this._ignorePositionChangeEvent) {
                // We are changing the position => ignore this event
                return;
            }

            if (this.occurrencesHighlight == 'off') {
                // Early exit if nothing needs to be done!
                // Leave some form of early exit check here if you wish to continue being a cursor position change listener ;)
                return;
            }

            this.runDelayer.trigger(() -> {
                this._onPositionChanged(e);
            });
        }));
        this.toUnhook.add(editor.onDidFocusEditorText(() -> {
            if (this.occurrencesHighlight == 'off') {
                // Early exit if nothing needs to be done
                return;
            }

            if (this.workerRequest == null) {
                this.runDelayer.trigger(() -> {
                    this._run();
                });
            }
        }));
        this.toUnhook.add(editor.onDidChangeModelContent((e) -> {
            if (this.model.uri.scheme != 'output') {
                this._stopAll();
            }
        }));
        this.toUnhook.add(editor.onDidChangeModel((e) -> {
            if (e.newModelUrl == null && e.oldModelUrl != null) {
                this._stopSingular();
            }
            else {
                if (state.query != null) {
                    this._run();
                }
            }
        }));
        this.toUnhook.add(editor.onDidChangeConfiguration((e) -> {
            final newValue = this.editor.getOption(EditorOption.occurrencesHighlight);
            if (this.occurrencesHighlight != newValue) {
                this.occurrencesHighlight = newValue;
                switch (newValue) {
                    case 'off':
                        this._stopAll();
                    case 'singleFile':
                        this._stopAll(state.query != null && state.query.modelInfo != null ? state.query.modelInfo.model : null);
                    case 'multiFile':
                        if (state.query != null) {
                            this._run(true);
                        }
                    default:
                        trace('Unknown occurrencesHighlight setting value: ' + newValue);
                }
            }
        }));

        this.decorations = this.editor.createDecorationsCollection();
        this.workerRequestTokenId = 0;
        this.workerRequest = null;
        this.workerRequestCompleted = false;

        this.lastCursorPositionChangeTime = 0;
        this.renderDecorationsTimer = null;

        // if there is a query already, highlight off that query
        if (state.query != null) {
            this._run();
        }
    }

    public function hasDecorations():Bool {
        return (this.decorations.length > 0);
    }

    public function restore():Void {
        if (this.occurrencesHighlight == 'off') {
            return;
        }

        this.runDelayer.cancel();
        this._run();
    }

    public function stop():Void {
        if (this.occurrencesHighlight == 'off') {
            return;
        }

        this._stopAll();
    }

    function _getSortedHighlights():Array<Range> {
        final ranges = this.decorations.getRanges();
        haxe.ds.ArraySort.sort(ranges, Range.compareRangesUsingStarts);
        return ranges;
    }

    public function moveNext():Void {
        final highlights = this._getSortedHighlights();
        var index = -1;
        for (i in 0...highlights.length) {
            if (highlights[i].containsPosition(this.editor.getPosition())) {
                index = i;
                break;
            }
        }
        final newIndex = ((index + 1) % highlights.length);
        final dest = highlights[newIndex];
        try {
            this._ignorePositionChangeEvent = true;
            this.editor.setPosition(dest.getStartPosition());
            this.editor.revealRangeInCenterIfOutsideViewport(dest);
        }
        catch (e:Dynamic) {
            this._ignorePositionChangeEvent = false;
            throw e;
        }
        this._ignorePositionChangeEvent = false;
    }

    public function moveBack():Void {
        final highlights = this._getSortedHighlights();
        var index = -1;
        for (i in 0...highlights.length) {
            if (highlights[i].containsPosition(this.editor.getPosition())) {
                index = i;
                break;
            }
        }
        final newIndex = ((index - 1 + highlights.length) % highlights.length);
        final dest = highlights[newIndex];
        try {
            this._ignorePositionChangeEvent = true;
            this.editor.setPosition(dest.getStartPosition());
            this.editor.revealRangeInCenterIfOutsideViewport(dest);
        }
        catch (e:Dynamic) {
            this._ignorePositionChangeEvent = false;
            throw e;
        }
        this._ignorePositionChangeEvent = false;
    }

    function _removeSingleDecorations():Void {
        // return if no model
        if (!this.editor.hasModel()) {
            return;
        }

        final uri = this.editor.getModel().uri.toString();
        final currentDecorationIDs = state.storedDecorationIDs.get(uri);
        if (currentDecorationIDs == null) {
            return;
        }

        this.editor.removeDecorations(currentDecorationIDs);
        state.storedDecorationIDs.remove(uri);

        if (this.decorations.length > 0) {
            this.decorations.clear();
            this._hasWordHighlights.set(false);
        }
    }

    function _removeAllDecorations(?preservedModel:ITextModel):Void {
        final currentEditors = this.editor.context.codeEditorService.listCodeEditors();
        final deleteURI = [];
        // iterate over editors and store models in currentModels
        for (editor in currentEditors) {
            if (!editor.hasModel() || (preservedModel != null && editor.getModel().uri.toString() == preservedModel.uri.toString())) {
                continue;
            }

            final uri = editor.getModel().uri.toString();
            final currentDecorationIDs = state.storedDecorationIDs.get(uri);
            if (currentDecorationIDs == null) {
                continue;
            }

            editor.removeDecorations(currentDecorationIDs);
            deleteURI.push(uri);

            final editorHighlighterContrib = WordHighlighterContribution.get(editor);
            if (editorHighlighterContrib == null || editorHighlighterContrib.wordHighlighter == null) {
                continue;
            }

            if (editorHighlighterContrib.wordHighlighter.decorations.length > 0) {
                editorHighlighterContrib.wordHighlighter.decorations.clear();
                editorHighlighterContrib.wordHighlighter.workerRequest = null;
                editorHighlighterContrib.wordHighlighter._hasWordHighlights.set(false);
            }
        }

        for (uri in deleteURI) {
            state.storedDecorationIDs.remove(uri);
        }
    }

    function _stopSingular():Void {
        // Remove any existing decorations + a possible query, and re - run to update decorations
        this._removeSingleDecorations();

        if (this.editor.hasTextFocus()) {
            // clear query if focused non-nb editor
            state.query = null;
            this._run(); // TODO: @Yoyokrazy -- investigate why we need a full rerun here. likely addressed a case/patch in the first iteration of this feature
        }

        // Cancel any renderDecorationsTimer
        this._cancelRenderDecorationsTimer();

        // Cancel any worker request
        if (this.workerRequest != null) {
            this.workerRequest.cancel();
            this.workerRequest = null;
        }

        // Invalidate any worker request callback
        if (!this.workerRequestCompleted) {
            this.workerRequestTokenId++;
            this.workerRequestCompleted = true;
        }
    }

    function _cancelRenderDecorationsTimer():Void {
        if (this.renderDecorationsTimer != null) {
            final cancel = this.renderDecorationsTimer;
            this.renderDecorationsTimer = null;
            cancel();
        }
    }

    function _stopAll(?preservedModel:ITextModel):Void {
        // Remove any existing decorations
        this._removeAllDecorations(preservedModel);

        // Cancel any renderDecorationsTimer
        this._cancelRenderDecorationsTimer();

        // Cancel any worker request
        if (this.workerRequest != null) {
            this.workerRequest.cancel();
            this.workerRequest = null;
        }

        // Invalidate any worker request callback
        if (!this.workerRequestCompleted) {
            this.workerRequestTokenId++;
            this.workerRequestCompleted = true;
        }
    }

    function _onPositionChanged(e:ICursorPositionChangedEvent):Void {

        // disabled
        if (this.occurrencesHighlight == 'off') {
            this._stopAll();
            return;
        }

        // ignore typing & other
        if (e.reason != CursorChangeReason.Explicit) {
            this._stopAll();
            return;
        }

        this._run();
    }

    function _getWord():Null<IWordAtPosition> {
        final editorSelection = this.editor.getSelection();
        final lineNumber = editorSelection.startLineNumber;
        final startColumn = editorSelection.startColumn;

        if (this.model.isDisposed()) {
            return null;
        }

        return this.model.getWordAtPosition({
            lineNumber: lineNumber,
            column: startColumn
        });
    }

    function getOtherModelsToHighlight(model:Null<ITextModel>):Array<ITextModel> {
        if (model == null) {
            return [];
        }

        // (notebooks and diff editors are not ported)
        final currentModels:Array<ITextModel> = [];
        final currentEditors = this.editor.context.codeEditorService.listCodeEditors();

        // multi-doc OFF
        if (this.occurrencesHighlight == 'singleFile') {
            return [];
        }

        // multi-doc ON
        for (editor in currentEditors) {
            final tempModel = editor.getModel();

            final isValidModel = tempModel != null && tempModel != model;

            if (isValidModel) {
                currentModels.push(tempModel);
            }
        }
        return currentModels;
    }

    function _run(?multiFileConfigChange:Bool):Void {

        var workerRequestIsValid = false;
        final hasTextFocus = this.editor.hasTextFocus();

        if (!hasTextFocus) { // new nb cell scrolled in, didChangeModel fires
            if (state.query == null) { // no previous query, nothing to highlight off of
                this._stopAll();
                return;
            }
        }
        else { // has text focus
            final editorSelection = this.editor.getSelection();

            // ignore multiline selection
            if (editorSelection == null || editorSelection.startLineNumber != editorSelection.endLineNumber) {
                state.query = null;
                this._stopAll();
                return;
            }

            final startColumn = editorSelection.startColumn;
            final endColumn = editorSelection.endColumn;

            final word = this._getWord();

            // The selection must be inside a word or surround one word at most
            if (word == null || word.startColumn > startColumn || word.endColumn < endColumn) {
                // no previous query, nothing to highlight
                state.query = null;
                this._stopAll();
                return;
            }

            // All the effort below is trying to achieve this:
            // - when cursor is moved to a word, trigger immediately a findOccurrences request
            // - 250ms later after the last cursor move event, render the occurrences
            // - no flickering!
            workerRequestIsValid = (this.workerRequest != null && this.workerRequest.isValid(this.model, editorSelection, this.decorations));

            state.query = {
                modelInfo: {
                    model: this.model,
                    selection: editorSelection,
                },
                word: word
            };
        }

        // There are 4 cases:
        // a) old workerRequest is valid & completed, renderDecorationsTimer fired
        // b) old workerRequest is valid & completed, renderDecorationsTimer not fired
        // c) old workerRequest is valid, but not completed
        // d) old workerRequest is not valid

        // For a) no action is needed
        // For c), member 'lastCursorPositionChangeTime' will be used when installing the timer so no action is needed

        this.lastCursorPositionChangeTime = now();

        final query = state.query;
        if (workerRequestIsValid) {
            if (this.workerRequestCompleted && this.renderDecorationsTimer != null) {
                // case b)
                // Delay the firing of renderDecorationsTimer by an extra 250 ms
                this._cancelRenderDecorationsTimer();
                this._beginRenderDecorations();
            }
        }
        else if (query.modelInfo != null && this.editor.getModel().uri.toString() == query.modelInfo.model.uri.toString()) { // only trigger new worker requests from the primary model that initiated the query
            // case d)

            // check if the new queried word is contained in the range of a stored decoration for this model
            if (multiFileConfigChange != true) {
                final currentModelDecorationRanges = this.decorations.getRanges();
                for (storedRange in currentModelDecorationRanges) {
                    if (storedRange.containsPosition(this.editor.getPosition())) {
                        return;
                    }
                }
            }

            // stop all previous actions if new word is highlighted
            // if we trigger the run off a setting change -> multifile highlighting, we do not want to remove decorations from this model
            this._stopAll(multiFileConfigChange == true ? this.model : null);

            final myRequestId = ++this.workerRequestTokenId;
            this.workerRequestCompleted = false;

            final otherModelsToHighlight = this.getOtherModelsToHighlight(this.editor.getModel());

            // when reaching here, there are two possible states.
            // 		1) we have text focus, and a valid query was updated.
            // 		2) we do not have text focus, and a valid query is cached.
            // the query will ALWAYS have the correct data for the current highlight request, so it can always be passed to the workerRequest safely
            if (state.query == null || state.query.modelInfo == null || state.query.modelInfo.model.isDisposed()) {
                return;
            }
            final request = this.computeWithModel(state.query.modelInfo.model, state.query.modelInfo.selection, state.query.word, otherModelsToHighlight);
            this.workerRequest = request;

            if (request != null) {
                request.onResult(data -> {
                    if (myRequestId == this.workerRequestTokenId) {
                        this.workerRequestCompleted = true;
                        this.workerRequestValue = data != null ? data : new Map();
                        this._beginRenderDecorations();
                    }
                });
            }
        }
    }

    static inline function now():Float {
        return haxe.Timer.stamp() * 1000;
    }

    function computeWithModel(model:ITextModel, selection:Selection, word:Null<IWordAtPosition>, otherModels:Array<ITextModel>):Null<OccurenceAtPositionRequest> {
        if (otherModels.length == 0) {
            return new SemanticOccurenceAtPositionRequest(model, selection, this.editor.getOption(EditorOption.wordSeparators), this.providers);
        }
        else {
            return new MultiModelOccurenceRequest(model, selection, this.editor.getOption(EditorOption.wordSeparators), this.multiDocumentProviders, otherModels);
        }
    }

    function _beginRenderDecorations():Void {
        final currentTime = now();
        final minimumRenderTime = this.lastCursorPositionChangeTime + 250;

        if (currentTime >= minimumRenderTime) {
            // Synchronous
            this.renderDecorationsTimer = null;
            this.renderDecorations();
        }
        else {
            // Asynchronous
            this.renderDecorationsTimer = Async.setTimeout(() -> {
                this.renderDecorations();
            }, (minimumRenderTime - currentTime));
        }
    }

    /**
     * Runs the pending work now (tests): the cursor change waiting in the
     * 50 ms delayer, then the rendering waiting for the 250 ms after the
     * last cursor change.
     */
    public function _flushPendingUpdate():Void {
        this.runDelayer.flush();
        if (this.renderDecorationsTimer != null) {
            this._cancelRenderDecorationsTimer();
            this.renderDecorations();
        }
    }

    function renderDecorations():Void {
        this.renderDecorationsTimer = null;
        // create new loop, iterate over current editors using this.codeEditorService.listCodeEditors(),
        // if the URI of that codeEditor is in the map, then add the decorations to the decorations array
        // then set the decorations for the editor
        final currentEditors = this.editor.context.codeEditorService.listCodeEditors();
        for (editor in currentEditors) {
            final editorHighlighterContrib = WordHighlighterContribution.get(editor);
            if (editorHighlighterContrib == null) {
                continue;
            }

            final newDecorations:Array<IModelDeltaDecoration> = [];
            final model = editor.getModel();
            final uri = model != null ? model.uri.toString() : null;
            if (uri != null && this.workerRequestValue.exists(uri)) {
                final oldDecorationIDs:Null<Array<String>> = state.storedDecorationIDs.get(uri);
                final newDocumentHighlights = this.workerRequestValue.get(uri);
                if (newDocumentHighlights != null) {
                    for (highlight in newDocumentHighlights) {
                        if (highlight.range == null) {
                            continue;
                        }
                        newDecorations.push({
                            range: highlight.range,
                            options: cast HighlightDecorations.getHighlightDecorationOptions(highlight.kind)
                        });
                    }
                }

                var newDecorationIDs:Array<String> = [];
                editor.changeDecorations((changeAccessor) -> {
                    newDecorationIDs = changeAccessor.deltaDecorations(oldDecorationIDs != null ? oldDecorationIDs : [], newDecorations);
                    return null;
                });
                state.storedDecorationIDs.set(uri, newDecorationIDs);

                if (newDecorations.length > 0) {
                    if (editorHighlighterContrib.wordHighlighter != null) {
                        editorHighlighterContrib.wordHighlighter.decorations.set(newDecorations);
                        editorHighlighterContrib.wordHighlighter._hasWordHighlights.set(true);
                    }
                }
            }
        }
    }

    public function dispose():Void {
        this._stopSingular();
        this.toUnhook.dispose();
    }

}

class WordHighlighterContribution extends Disposable implements IEditorContribution {

    public static inline final ID = 'editor.contrib.wordHighlighter';

    public static function get(editor:ICodeEditor):Null<WordHighlighterContribution> {
        return editor.getContribution(ID);
    }

    var _wordHighlighter:Null<WordHighlighter>;

    public function new(editor:ICodeEditor, state:WordHighlighterState) {
        super();
        this._wordHighlighter = null;
        final contextKeyService = editor.contextKeyService;
        final languageFeaturesService = editor.context.languageFeaturesService;
        function createWordHighlighterIfPossible() {
            if (editor.hasModel() && !editor.getModel().isTooLargeForTokenization()) {
                this._wordHighlighter = new WordHighlighter(editor, languageFeaturesService.documentHighlightProvider, languageFeaturesService.multiDocumentHighlightProvider, contextKeyService, state);
            }
        }
        this._register(editor.onDidChangeModel((e) -> {
            if (this._wordHighlighter != null) {
                this._wordHighlighter.dispose();
                this._wordHighlighter = null;
            }
            createWordHighlighterIfPossible();
        }));
        createWordHighlighterIfPossible();
    }

    public var wordHighlighter(get, never):Null<WordHighlighter>;
    inline function get_wordHighlighter():Null<WordHighlighter> {
        return this._wordHighlighter;
    }

    public function saveViewState():Any {
        if (this._wordHighlighter != null && this._wordHighlighter.hasDecorations()) {
            return true;
        }
        return false;
    }

    public function moveNext():Void {
        if (this._wordHighlighter != null) {
            this._wordHighlighter.moveNext();
        }
    }

    public function moveBack():Void {
        if (this._wordHighlighter != null) {
            this._wordHighlighter.moveBack();
        }
    }

    public function restoreViewState(state:Any):Void {
        if (this._wordHighlighter != null && state == true) {
            this._wordHighlighter.restore();
        }
    }

    public function stopHighlighting():Void {
        if (this._wordHighlighter != null) {
            this._wordHighlighter.stop();
        }
    }

    /**
     * Runs the pending update now (tests; Monaco waits 50 ms after a cursor
     * change, then renders 250 ms after it).
     */
    public function _flushPendingUpdate():Void {
        if (this._wordHighlighter != null) {
            this._wordHighlighter._flushPendingUpdate();
        }
    }

    override public function dispose():Void {
        if (this._wordHighlighter != null) {
            this._wordHighlighter.dispose();
            this._wordHighlighter = null;
        }
        super.dispose();
    }

}

class WordHighlightNavigationAction extends EditorAction {

    final _isNext:Bool;

    public function new(next:Bool, opts:IActionOptions) {
        super(opts);
        this._isNext = next;
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = WordHighlighterContribution.get(editor);
        if (controller == null) {
            return;
        }

        if (this._isNext) {
            controller.moveNext();
        }
        else {
            controller.moveBack();
        }
    }

}

class NextWordHighlightAction extends WordHighlightNavigationAction {

    public function new(r:EditorExtensionsRegistry) {
        super(true, {
            id: 'editor.action.wordHighlight.next',
            label: r.localize('wordHighlight.next.label', "Go to Next Symbol Highlight"),
            alias: 'Go to Next Symbol Highlight',
            precondition: WordHighlighterUtils.ctxHasWordHighlights,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyCode.F7,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

}

class PrevWordHighlightAction extends WordHighlightNavigationAction {

    public function new(r:EditorExtensionsRegistry) {
        super(false, {
            id: 'editor.action.wordHighlight.prev',
            label: r.localize('wordHighlight.previous.label', "Go to Previous Symbol Highlight"),
            alias: 'Go to Previous Symbol Highlight',
            precondition: WordHighlighterUtils.ctxHasWordHighlights,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.Shift | KeyCode.F7,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

}

class TriggerWordHighlightAction extends EditorAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.wordHighlight.trigger',
            label: r.localize('wordHighlight.trigger.label', "Trigger Symbol Highlight"),
            alias: 'Trigger Symbol Highlight',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: 0,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = WordHighlighterContribution.get(editor);
        if (controller == null) {
            return;
        }

        controller.restoreViewState(true);
    }

}

/**
 * The module level code of wordHighlighter.ts: the contribution (with the
 * state of the context), its actions, the textual provider (an editor
 * feature in Monaco), the colors and styles of highlightDecorations.ts.
 */
class WordHighlighterRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        HighlightDecorations.registerColors(r.context);
        HighlightDecorations.registerStyles(r.context);
        final state = new WordHighlighterState();
        r.registerEditorContribution(WordHighlighterContribution.ID, editor -> new WordHighlighterContribution(editor, state), EditorContributionInstantiation.Eager); // eager because it uses `saveViewState`/`restoreViewState`
        r.registerEditorAction(new NextWordHighlightAction(r));
        r.registerEditorAction(new PrevWordHighlightAction(r));
        r.registerEditorAction(new TriggerWordHighlightAction(r));
        new TextualHighlightProvider.TextualMultiDocumentHighlightFeature(r.context);
    }

}
