// Ported from vscode src/vs/editor/contrib/semanticTokens/browser/viewportSemanticTokens.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.semanticTokens.view;

import cityscape.Cityscape;
import cityscape.base.common.Async.RunOnceScheduler;
import cityscape.base.common.Cancellation.CancellationTokenSource;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.DocumentRangeSemanticTokensProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import cityscape.common.services.SemanticTokensProviderStyling;
import cityscape.contrib.semanticTokens.common.GetSemanticTokens;
import cityscape.contrib.semanticTokens.common.SemanticTokensConfig;
import cityscape.contrib.semanticTokens.view.DocumentSemanticTokens;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/**
 * A request of the visible ranges (Monaco's `CancelablePromise`): once
 * cancelled, its result is dropped.
 */
private class RangeRequest {

    public final cts = new CancellationTokenSource();
    public var cancelled(default, null) = false;

    public function new() {}

    public function cancel():Void {
        cancelled = true;
        cts.cancel();
    }

}

/**
 * The semantic tokens of the visible lines of an editor from the range
 * semantic tokens providers, while the model has no complete semantic
 * tokens (from a document provider): asked 100 ms (debounced) after a
 * scroll, an edit, a model, provider, setting or theme change.
 */
class ViewportSemanticTokensContribution extends Disposable implements IEditorContribution {

    public static inline final ID = 'editor.contrib.viewportSemanticTokens';

    public static function get(editor:ICodeEditor):Null<ViewportSemanticTokensContribution> {
        return editor.getContribution(ViewportSemanticTokensContribution.ID);
    }

    final _editor:ICodeEditor;
    final _context:Cityscape;
    final _provider:LanguageFeatureRegistry<DocumentRangeSemanticTokensProvider>;
    final _debounceInformation:SemanticTokensDebounceInformation;
    final _tokenizeViewport:RunOnceScheduler;
    var _outstandingRequests:Array<RangeRequest>;

    public function new(editor:ICodeEditor) {
        super();
        this._editor = editor;
        this._context = editor.context;
        this._provider = this._context.languageFeaturesService.documentRangeSemanticTokensProvider;
        this._debounceInformation = new SemanticTokensDebounceInformation(100, 500);
        this._tokenizeViewport = this._register(new RunOnceScheduler(() -> this._tokenizeViewportNow(), 100));
        this._outstandingRequests = [];
        final scheduleTokenizeViewport = () -> {
            if (this._editor.hasModel()) {
                this._tokenizeViewport.schedule(this._debounceInformation.get(this._editor.getModel()));
            }
        };
        this._register(this._editor.onDidScrollChange((_) -> {
            scheduleTokenizeViewport();
        }));
        this._register(this._editor.onDidChangeModel((_) -> {
            this._cancelAll();
            scheduleTokenizeViewport();
        }));
        this._register(this._editor.onDidChangeModelContent((e) -> {
            this._cancelAll();
            scheduleTokenizeViewport();
        }));
        this._register(this._provider.onDidChange((_) -> {
            this._cancelAll();
            scheduleTokenizeViewport();
        }));
        this._register(this._context.configurationService.onDidChangeConfiguration(e -> {
            if (e.affectsConfiguration(SemanticTokensConfig.SEMANTIC_HIGHLIGHTING_SETTING_ID)) {
                this._cancelAll();
                scheduleTokenizeViewport();
            }
        }));
        this._register(this._context.themeService.onDidColorThemeChange((_) -> {
            this._cancelAll();
            scheduleTokenizeViewport();
        }));
        scheduleTokenizeViewport();
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    /**
     * Runs a scheduled request now (tests: Monaco's tests wait for the timer).
     */
    public function _flush():Void {
        this._tokenizeViewport.flush();
    }

    /**
     * Whether a request is scheduled (tests).
     */
    public function _isScheduled():Bool {
        return this._tokenizeViewport.isScheduled();
    }

    function _cancelAll():Void {
        for (request in this._outstandingRequests) {
            request.cancel();
        }
        this._outstandingRequests = [];
    }

    function _removeOutstandingRequest(req:RangeRequest):Void {
        this._outstandingRequests.remove(req);
    }

    function _tokenizeViewportNow():Void {
        if (!this._editor.hasModel()) {
            return;
        }
        final model = this._editor.getModel();
        if (model.tokenization.hasCompleteSemanticTokens()) {
            return;
        }
        if (!SemanticTokensConfig.isSemanticColoringEnabled(model, this._context.themeService.getColorTheme(), this._context.configurationService)) {
            if (model.tokenization.hasSomeSemanticTokens()) {
                model.tokenization.setSemanticTokens(null, false);
            }
            return;
        }
        if (!GetSemanticTokens.hasDocumentRangeSemanticTokensProvider(this._provider, model)) {
            if (model.tokenization.hasSomeSemanticTokens()) {
                model.tokenization.setSemanticTokens(null, false);
            }
            return;
        }
        final widget = Std.downcast(this._editor, cityscape.view.widget.codeEditor.CodeEditorWidget);
        final visibleRanges = widget != null ? widget.getVisibleRangesPlusViewportAboveBelow() : this._editor.getVisibleRanges();

        for (range in visibleRanges) {
            this._requestRange(model, range);
        }
    }

    function _requestRange(model:ITextModel, range:Range):RangeRequest {
        final requestVersionId = model.getVersionId();
        final request = new RangeRequest();
        // added before it starts: a provider may answer at once
        this._outstandingRequests.push(request);
        final start = haxe.Timer.stamp();
        GetSemanticTokens.getDocumentRangeSemanticTokens(this._provider, model, range, request.cts.token).done((r) -> {
            if (request.cancelled) {
                this._removeOutstandingRequest(request);
                return;
            }
            this._debounceInformation.update(model, (haxe.Timer.stamp() - start) * 1000);
            if (r == null || r.tokens == null || model.isDisposed() || model.getVersionId() != requestVersionId) {
                this._removeOutstandingRequest(request);
                return;
            }
            final styling = this._context.semanticTokensStylingService.getStyling(r.provider);
            model.tokenization.setPartialSemanticTokens(range, SemanticTokensProviderStyling.toMultilineTokens2(r.tokens, styling, model.getLanguageId()));
            this._removeOutstandingRequest(request);
        }, (_) -> this._removeOutstandingRequest(request));
        return request;
    }

    /**
     * The registration of viewportSemanticTokens.ts (and the editor feature
     * of documentSemanticTokens.ts, created with the editor extensions of
     * the context).
     */
    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorContribution(ViewportSemanticTokensContribution.ID, editor -> new ViewportSemanticTokensContribution(editor), EditorContributionInstantiation.AfterFirstRender);
        // registerEditorFeature(DocumentSemanticTokensFeature)
        final feature:DocumentSemanticTokensFeature = r.context.documentSemanticTokensFeature;
    }

}
