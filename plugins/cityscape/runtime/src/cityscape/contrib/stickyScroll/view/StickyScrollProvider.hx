// Ported from vscode src/vs/editor/contrib/stickyScroll/browser/stickyScrollProvider.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.stickyScroll.view;

import cityscape.base.common.Arrays;
import cityscape.base.common.Async.RunOnceScheduler;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Range;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.common.services.LanguageFeaturesService;
import cityscape.contrib.stickyScroll.view.StickyScrollElement;
import cityscape.contrib.stickyScroll.view.StickyScrollModelProvider;
import cityscape.view.EditorBrowser.ICodeEditor;

class StickyLineCandidate {

    public final startLineNumber:Int;
    public final endLineNumber:Int;
    public final nestingDepth:Int;

    public function new(startLineNumber:Int, endLineNumber:Int, nestingDepth:Int) {
        this.startLineNumber = startLineNumber;
        this.endLineNumber = endLineNumber;
        this.nestingDepth = nestingDepth;
    }

    public function toString():String {
        return 'StickyLineCandidate(' + startLineNumber + ', ' + endLineNumber + ', ' + nestingDepth + ')';
    }

}

interface IStickyLineCandidateProvider extends IDisposable {

    function dispose():Void;
    function getVersionId():Null<Int>;
    /**
     * Monaco's `update(): Promise<void>`: `done` is called when the sticky
     * model is updated.
     */
    function update(?done:() -> Void):Void;
    function getCandidateStickyLinesIntersecting(range:StickyRange):Array<StickyLineCandidate>;
    var onDidChangeStickyScroll(get, never):VoidEvent;

}

class StickyLineCandidateProvider extends Disposable implements IStickyLineCandidateProvider {

    public static inline final ID = 'store.contrib.stickyScrollController';

    final _onDidChangeStickyScroll:VoidEmitter;
    public var onDidChangeStickyScroll(get, never):VoidEvent;
    inline function get_onDidChangeStickyScroll():VoidEvent {
        return _onDidChangeStickyScroll.event;
    }

    final _editor:ICodeEditor;
    final _updateSoon:RunOnceScheduler;
    final _sessionStore:DisposableStore;
    final _languageFeaturesService:LanguageFeaturesService;
    final _languageConfigurationService:ILanguageConfigurationService;

    var _model:Null<StickyModel> = null;
    var _cts:Null<CancellationTokenSource> = null;
    var _stickyModelProvider:Null<StickyModelProvider> = null;

    public function new(editor:ICodeEditor, languageFeaturesService:LanguageFeaturesService, languageConfigurationService:ILanguageConfigurationService) {
        super();
        this._onDidChangeStickyScroll = this._register(new VoidEmitter());
        this._languageFeaturesService = languageFeaturesService;
        this._languageConfigurationService = languageConfigurationService;
        this._editor = editor;
        this._sessionStore = this._register(new DisposableStore());
        this._updateSoon = this._register(new RunOnceScheduler(() -> this.update(), 50));

        this._register(this._editor.onDidChangeConfiguration(e -> {
            if (e.hasChanged(EditorOption.stickyScroll)) {
                this.readConfiguration();
            }
        }));
        this.readConfiguration();
    }

    function readConfiguration():Void {
        this._sessionStore.clear();

        final options = this._editor.getOption(EditorOption.stickyScroll);
        if (!options.enabled) {
            return;
        }

        this._sessionStore.add(this._editor.onDidChangeModel((_) -> {
            // We should not show an old model for a different file, it will always be wrong.
            // So we clear the model here immediately and then trigger an update.
            this._model = null;
            this.updateStickyModelProvider();
            this._onDidChangeStickyScroll.fire();

            this.update();
        }));
        this._sessionStore.add(this._editor.onDidChangeHiddenAreas(() -> this.update()));
        this._sessionStore.add(this._editor.onDidChangeModelContent((_) -> this._updateSoon.schedule()));
        this._sessionStore.add(this._languageFeaturesService.documentSymbolProvider.onDidChange((_) -> this.update()));
        this._sessionStore.add(Lifecycle.toDisposable(() -> {
            if (this._stickyModelProvider != null) {
                this._stickyModelProvider.dispose();
            }
            this._stickyModelProvider = null;
        }));
        this.updateStickyModelProvider();
        this.update();
    }

    public function getVersionId():Null<Int> {
        return this._model != null ? this._model.version : null;
    }

    function updateStickyModelProvider():Void {
        if (this._stickyModelProvider != null) {
            this._stickyModelProvider.dispose();
        }
        this._stickyModelProvider = null;

        final editor = this._editor;
        if (editor.hasModel()) {
            this._stickyModelProvider = new StickyModelProvider(
                editor,
                () -> this._updateSoon.schedule(),
                this._languageConfigurationService,
                this._languageFeaturesService
            );
        }
    }

    public function update(?done:() -> Void):Void {
        if (this._cts != null) {
            this._cts.dispose(true);
        }
        final cts = new CancellationTokenSource();
        this._cts = cts;
        this.updateStickyModel(cts.token, () -> {
            this._onDidChangeStickyScroll.fire();
            if (done != null) {
                done();
            }
        });
    }

    /**
     * Runs the pending updates now (tests; Monaco waits 50 ms after an
     * edit, then 300 ms in the model provider).
     */
    public function _flushPendingUpdate():Void {
        this._updateSoon.flush();
        if (this._stickyModelProvider != null) {
            this._stickyModelProvider._flushPendingUpdate();
        }
    }

    function updateStickyModel(token:CancellationToken, done:() -> Void):Void {

        if (!this._editor.hasModel() || this._stickyModelProvider == null || this._editor.getModel().isTooLargeForTokenization()) {
            this._model = null;
            done();
            return;
        }
        this._stickyModelProvider.update(token, (model) -> {
            if (token.isCancellationRequested) {
                // the computation was canceled, so do not overwrite the model
                done();
                return;
            }

            this._model = model;
            done();
        });
    }

    function updateIndex(index:Int):Int {
        if (index == -1) {
            index = 0;
        }
        else if (index < 0) {
            index = -index - 2;
        }
        return index;
    }

    public function getCandidateStickyLinesIntersectingFromStickyModel(
        range:StickyRange,
        outlineModel:StickyElement,
        result:Array<StickyLineCandidate>,
        depth:Int,
        lastStartLineNumber:Int
    ):Void {
        if (outlineModel.children.length == 0) {
            return;
        }
        var lastLine = lastStartLineNumber;
        final childrenStartLines:Array<Int> = [];

        for (i in 0...outlineModel.children.length) {
            final child = outlineModel.children[i];
            if (child.range != null) {
                childrenStartLines.push(child.range.startLineNumber);
            }
        }
        final lowerBound = this.updateIndex(Arrays.binarySearch(childrenStartLines, range.startLineNumber, (a:Int, b:Int) -> a - b));
        final upperBound = this.updateIndex(Arrays.binarySearch(childrenStartLines, range.startLineNumber + depth, (a:Int, b:Int) -> a - b));

        for (i in lowerBound...upperBound + 1) {
            final child = i < outlineModel.children.length ? outlineModel.children[i] : null;
            if (child == null) {
                return;
            }
            if (child.range != null) {
                final childStartLine = child.range.startLineNumber;
                final childEndLine = child.range.endLineNumber;
                if (range.startLineNumber <= childEndLine + 1 && childStartLine - 1 <= range.endLineNumber && childStartLine != lastLine) {
                    lastLine = childStartLine;
                    result.push(new StickyLineCandidate(childStartLine, childEndLine - 1, depth + 1));
                    this.getCandidateStickyLinesIntersectingFromStickyModel(range, child, result, depth + 1, childStartLine);
                }
            }
            else {
                this.getCandidateStickyLinesIntersectingFromStickyModel(range, child, result, depth, lastStartLineNumber);
            }
        }
    }

    public function getCandidateStickyLinesIntersecting(range:StickyRange):Array<StickyLineCandidate> {
        if (this._model == null || this._model.element == null) {
            return [];
        }
        var stickyLineCandidates:Array<StickyLineCandidate> = [];
        this.getCandidateStickyLinesIntersectingFromStickyModel(range, this._model.element, stickyLineCandidates, 0, -1);
        final viewModel = this._editor._getViewModel();
        final hiddenRanges:Null<Array<Range>> = viewModel != null ? viewModel.getHiddenAreas() : null;

        if (hiddenRanges != null) {
            for (hiddenRange in hiddenRanges) {
                stickyLineCandidates = stickyLineCandidates.filter(stickyLine -> !(stickyLine.startLineNumber >= hiddenRange.startLineNumber && stickyLine.endLineNumber <= hiddenRange.endLineNumber + 1));
            }
        }
        return stickyLineCandidates;
    }

}
