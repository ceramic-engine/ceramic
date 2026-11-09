// Ported from vscode src/vs/editor/contrib/semanticTokens/browser/documentSemanticTokens.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.semanticTokens.view;

import cityscape.base.common.Async.RunOnceScheduler;
import cityscape.base.common.Cancellation.CancellationTokenSource;
import cityscape.base.common.Errors;
import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Promise.CancellationError;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.DocumentSemanticTokensProvider;
import cityscape.common.Languages.SemanticTokens;
import cityscape.common.Languages.SemanticTokensEdits;
import cityscape.common.Model.ITextModel;
import cityscape.common.TextModelEvents.IModelContentChangedEvent;
import cityscape.common.services.LanguageFeaturesService;
import cityscape.common.services.SemanticTokensProviderStyling;
import cityscape.common.services.SemanticTokensStyling.ISemanticTokensStylingService;
import cityscape.contrib.semanticTokens.common.GetSemanticTokens;
import cityscape.contrib.semanticTokens.common.SemanticTokensConfig;
import cityscape.platform.configuration.common.Configuration.ConfigurationChangeEvent;
import cityscape.platform.configuration.common.Configuration.IConfigurationService;
import cityscape.platform.theme.common.ThemeService.IColorTheme;
import haxe.io.UInt32Array;

/**
 * What the semantic coloring reads from the theme service: the current
 * theme and its change event (Monaco's `IThemeService`; the theme service
 * of a `Cityscape` context gives one, `DocumentSemanticTokensFeature.themeSourceOf`).
 */
typedef ISemanticColoringThemeSource = {
    function getColorTheme():IColorTheme;
    final onDidColorThemeChange:VoidEvent;
}

/**
 * The semantic coloring of the models of a `Cityscape` context with the
 * document semantic tokens providers (Monaco's editor feature, created once
 * per set of services). A model is colored while the setting
 * `editor.semanticHighlighting.enabled` (or the theme) allows it.
 */
class DocumentSemanticTokensFeature extends Disposable {

    final _watchers:Map<String, ModelSemanticColoring> = new Map();

    public function new(semanticTokensStylingService:ISemanticTokensStylingService, modelService:cityscape.common.services.ModelService, themeService:ISemanticColoringThemeSource, configurationService:IConfigurationService, languageFeaturesService:LanguageFeaturesService) {
        super();

        final register = (model:ITextModel) -> {
            this._watchers.set(model.uri.toString(), new ModelSemanticColoring(model, semanticTokensStylingService, themeService, languageFeaturesService));
        };
        final deregister = (model:ITextModel, modelSemanticColoring:ModelSemanticColoring) -> {
            modelSemanticColoring.dispose();
            this._watchers.remove(model.uri.toString());
        };
        final handleSettingOrThemeChange = () -> {
            for (model in modelService.getModels()) {
                final curr = this._watchers.get(model.uri.toString());
                if (SemanticTokensConfig.isSemanticColoringEnabled(model, themeService.getColorTheme(), configurationService)) {
                    if (curr == null) {
                        register(model);
                    }
                }
                else {
                    if (curr != null) {
                        deregister(model, curr);
                    }
                }
            }
        };
        for (model in modelService.getModels()) {
            if (SemanticTokensConfig.isSemanticColoringEnabled(model, themeService.getColorTheme(), configurationService)) {
                register(model);
            }
        }
        this._register(modelService.onModelAdded((model) -> {
            if (SemanticTokensConfig.isSemanticColoringEnabled(model, themeService.getColorTheme(), configurationService)) {
                register(model);
            }
        }));
        this._register(modelService.onModelRemoved((model) -> {
            final curr = this._watchers.get(model.uri.toString());
            if (curr != null) {
                deregister(model, curr);
            }
        }));
        this._register(configurationService.onDidChangeConfiguration(e -> {
            if (e.affectsConfiguration(SemanticTokensConfig.SEMANTIC_HIGHLIGHTING_SETTING_ID)) {
                handleSettingOrThemeChange();
            }
        }));
        this._register(themeService.onDidColorThemeChange(handleSettingOrThemeChange));
    }

    /**
     * The coloring of a model (null when it is not colored).
     */
    public function getModelSemanticColoring(model:ITextModel):Null<ModelSemanticColoring> {
        return this._watchers.get(model.uri.toString());
    }

    /**
     * Runs the pending requests of every model now (tests: Monaco's tests
     * wait for the timers).
     */
    public function _flush():Void {
        for (watcher in [for (w in this._watchers) w]) {
            watcher._flush();
        }
    }

    override public function dispose():Void {
        // Dispose all watchers
        for (watcher in this._watchers) {
            watcher.dispose();
        }
        this._watchers.clear();
        super.dispose();
    }

    /**
     * The theme source of the theme service of a context.
     */
    public static function themeSourceOf(themeService:cityscape.standalone.StandaloneThemeService):ISemanticColoringThemeSource {
        return {
            getColorTheme: () -> (themeService.getColorTheme() : IColorTheme),
            onDidColorThemeChange: (listener:() -> Void) -> themeService.onDidColorThemeChange(_ -> listener())
        };
    }

}

/**
 * The semantic tokens of one model from the document semantic tokens
 * providers: asked at once, again after edits (debounced), when the
 * providers or the theme change, applying the edits of a provider's
 * `SemanticTokensEdits` to its last result, and adjusting tokens received
 * after edits made during the request.
 */
class ModelSemanticColoring extends Disposable {

    public static inline final REQUEST_MIN_DELAY = 300;
    public static inline final REQUEST_MAX_DELAY = 2000;

    var _isDisposed:Bool;
    final _model:ITextModel;
    final _provider:LanguageFeatureRegistry<DocumentSemanticTokensProvider>;
    final _semanticTokensStylingService:ISemanticTokensStylingService;
    final _debounceInformation:SemanticTokensDebounceInformation;
    final _fetchDocumentSemanticTokens:RunOnceScheduler;
    var _currentDocumentResponse:Null<SemanticTokensResponse>;
    var _currentDocumentRequestCancellationTokenSource:Null<CancellationTokenSource>;
    var _documentProvidersChangeListeners:Array<IDisposable>;
    var _providersChangedDuringRequest:Bool;

    public function new(model:ITextModel, semanticTokensStylingService:ISemanticTokensStylingService, themeService:ISemanticColoringThemeSource, languageFeaturesService:LanguageFeaturesService) {
        super();

        this._semanticTokensStylingService = semanticTokensStylingService;
        this._isDisposed = false;
        this._model = model;
        this._provider = languageFeaturesService.documentSemanticTokensProvider;
        this._debounceInformation = new SemanticTokensDebounceInformation(REQUEST_MIN_DELAY, REQUEST_MAX_DELAY);
        this._fetchDocumentSemanticTokens = this._register(new RunOnceScheduler(() -> this._fetchDocumentSemanticTokensNow(), REQUEST_MIN_DELAY));
        this._currentDocumentResponse = null;
        this._currentDocumentRequestCancellationTokenSource = null;
        this._documentProvidersChangeListeners = [];
        this._providersChangedDuringRequest = false;

        this._register(this._model.onDidChangeContent((_) -> {
            if (!this._fetchDocumentSemanticTokens.isScheduled()) {
                this._fetchDocumentSemanticTokens.schedule(this._debounceInformation.get(this._model));
            }
        }));
        this._register(this._model.onDidChangeAttached(() -> {
            if (!this._fetchDocumentSemanticTokens.isScheduled()) {
                this._fetchDocumentSemanticTokens.schedule(this._debounceInformation.get(this._model));
            }
        }));
        this._register(this._model.onDidChangeLanguage((_) -> {
            // clear any outstanding state
            if (this._currentDocumentResponse != null) {
                this._currentDocumentResponse.dispose();
                this._currentDocumentResponse = null;
            }
            if (this._currentDocumentRequestCancellationTokenSource != null) {
                this._currentDocumentRequestCancellationTokenSource.cancel();
                this._currentDocumentRequestCancellationTokenSource = null;
            }
            this._setDocumentSemanticTokens(null, null, null, []);
            this._fetchDocumentSemanticTokens.schedule(0);
        }));

        final bindDocumentChangeListeners = () -> {
            for (listener in this._documentProvidersChangeListeners) {
                listener.dispose();
            }
            this._documentProvidersChangeListeners = [];
            for (provider in this._provider.all(model)) {
                final onDidChange = provider.onDidChange;
                if (onDidChange != null) {
                    this._documentProvidersChangeListeners.push(onDidChange(() -> {
                        if (this._currentDocumentRequestCancellationTokenSource != null) {
                            // there is already a request running,
                            this._providersChangedDuringRequest = true;
                            return;
                        }
                        this._fetchDocumentSemanticTokens.schedule(0);
                    }));
                }
            }
        };
        bindDocumentChangeListeners();
        this._register(this._provider.onDidChange((_) -> {
            bindDocumentChangeListeners();
            this._fetchDocumentSemanticTokens.schedule(this._debounceInformation.get(this._model));
        }));

        this._register(themeService.onDidColorThemeChange(() -> {
            // clear out existing tokens
            this._setDocumentSemanticTokens(null, null, null, []);
            this._fetchDocumentSemanticTokens.schedule(this._debounceInformation.get(this._model));
        }));

        this._fetchDocumentSemanticTokens.schedule(0);
    }

    override public function dispose():Void {
        if (this._currentDocumentResponse != null) {
            this._currentDocumentResponse.dispose();
            this._currentDocumentResponse = null;
        }
        if (this._currentDocumentRequestCancellationTokenSource != null) {
            this._currentDocumentRequestCancellationTokenSource.cancel();
            this._currentDocumentRequestCancellationTokenSource = null;
        }
        for (listener in this._documentProvidersChangeListeners) {
            listener.dispose();
        }
        this._documentProvidersChangeListeners = [];
        this._setDocumentSemanticTokens(null, null, null, []);
        this._isDisposed = true;

        super.dispose();
    }

    /**
     * Whether a request is scheduled (tests).
     */
    public function _isScheduled():Bool {
        return this._fetchDocumentSemanticTokens.isScheduled();
    }

    /**
     * Runs a scheduled request now (tests: Monaco's tests wait for the timer).
     */
    public function _flush():Void {
        this._fetchDocumentSemanticTokens.flush();
    }

    function _fetchDocumentSemanticTokensNow():Void {
        if (this._currentDocumentRequestCancellationTokenSource != null) {
            // there is already a request running, let it finish...
            return;
        }

        if (!GetSemanticTokens.hasDocumentSemanticTokensProvider(this._provider, this._model)) {
            // there is no provider
            if (this._currentDocumentResponse != null) {
                // there are semantic tokens set
                this._model.tokenization.setSemanticTokens(null, false);
            }
            return;
        }

        if (!this._model.isAttachedToEditor()) {
            // this document is not visible, there is no need to fetch semantic tokens for it
            return;
        }

        final cancellationTokenSource = new CancellationTokenSource();
        final lastProvider = this._currentDocumentResponse != null ? this._currentDocumentResponse.provider : null;
        final lastResultId:Null<String> = this._currentDocumentResponse != null ? this._currentDocumentResponse.resultId : null;
        this._currentDocumentRequestCancellationTokenSource = cancellationTokenSource;
        this._providersChangedDuringRequest = false;

        final pendingChanges:Array<IModelContentChangedEvent> = [];
        final contentChangeListener = this._model.onDidChangeContent((e) -> {
            pendingChanges.push(e);
        });

        final start = haxe.Timer.stamp();
        // Monaco starts the request before setting the token source; the
        // providers answering at once settle the promise here, so the
        // token source is set first
        final request = GetSemanticTokens.getDocumentSemanticTokens(this._provider, this._model, lastProvider, lastResultId, cancellationTokenSource.token);

        request.done((res) -> {
            this._debounceInformation.update(this._model, (haxe.Timer.stamp() - start) * 1000);
            this._currentDocumentRequestCancellationTokenSource = null;
            contentChangeListener.dispose();

            if (res == null) {
                this._setDocumentSemanticTokens(null, null, null, pendingChanges);
            }
            else {
                final provider = res.provider;
                final tokens = res.tokens;
                final styling = this._semanticTokensStylingService.getStyling(provider);
                this._setDocumentSemanticTokens(provider, tokens, styling, pendingChanges);
            }
        }, (err) -> {
            final isExpectedError = err != null && (CancellationError.isCancellationError(err) || isBusyError(err));
            if (!isExpectedError) {
                Errors.onUnexpectedError(err);
            }

            // Semantic tokens eats up all errors and considers errors to mean that the result is temporarily not available
            // The API does not have a special error kind to express this...
            this._currentDocumentRequestCancellationTokenSource = null;
            contentChangeListener.dispose();

            if (pendingChanges.length > 0 || this._providersChangedDuringRequest) {
                // More changes occurred while the request was running
                if (!this._fetchDocumentSemanticTokens.isScheduled()) {
                    this._fetchDocumentSemanticTokens.schedule(this._debounceInformation.get(this._model));
                }
            }
        });
    }

    /**
     * `typeof err.message === 'string' && err.message.indexOf('busy') !== -1`
     */
    static function isBusyError(err:Any):Bool {
        var message:Any = null;
        if (Std.isOfType(err, haxe.Exception)) {
            message = (err : haxe.Exception).message;
        }
        else {
            message = JsValues.field(err, 'message');
        }
        return JsValues.isString(message) && (message : String).indexOf('busy') != -1;
    }

    static function _copy(src:UInt32Array, srcOffset:Int, dest:UInt32Array, destOffset:Int, length:Int):Void {
        // protect against overflows
        length = Std.int(Math.min(length, Math.min(dest.length - destOffset, src.length - srcOffset)));
        for (i in 0...length) {
            dest[destOffset + i] = src[srcOffset + i];
        }
    }

    function _setDocumentSemanticTokens(provider:Null<DocumentSemanticTokensProvider>, tokens:Null<SemanticTokensOrEdits>, styling:Null<SemanticTokensProviderStyling>, pendingChanges:Array<IModelContentChangedEvent>):Void {
        final currentResponse = this._currentDocumentResponse;
        final rescheduleIfNeeded = () -> {
            if ((pendingChanges.length > 0 || this._providersChangedDuringRequest) && !this._fetchDocumentSemanticTokens.isScheduled()) {
                this._fetchDocumentSemanticTokens.schedule(this._debounceInformation.get(this._model));
            }
        };

        if (this._currentDocumentResponse != null) {
            this._currentDocumentResponse.dispose();
            this._currentDocumentResponse = null;
        }
        if (this._isDisposed) {
            // disposed!
            if (provider != null && tokens != null) {
                provider.releaseDocumentSemanticTokens(JsValues.field(tokens, 'resultId'));
            }
            return;
        }
        if (provider == null || styling == null) {
            this._model.tokenization.setSemanticTokens(null, false);
            return;
        }
        if (tokens == null) {
            this._model.tokenization.setSemanticTokens(null, true);
            rescheduleIfNeeded();
            return;
        }

        if (GetSemanticTokens.isSemanticTokensEdits(tokens)) {
            final edits:SemanticTokensEdits = cast tokens;
            if (currentResponse == null) {
                // not possible!
                this._model.tokenization.setSemanticTokens(null, true);
                return;
            }
            if (edits.edits.length == 0) {
                // nothing to do!
                final full:SemanticTokens = {
                    resultId: edits.resultId,
                    data: currentResponse.data
                };
                tokens = full;
            }
            else {
                var deltaLength = 0;
                for (edit in edits.edits) {
                    deltaLength += (edit.data != null ? edit.data.length : 0) - edit.deleteCount;
                }

                final srcData = currentResponse.data;
                final destData = new UInt32Array(srcData.length + deltaLength);

                var srcLastStart = srcData.length;
                var destLastStart = destData.length;
                var i = edits.edits.length - 1;
                while (i >= 0) {
                    final edit = edits.edits[i];

                    // `start` is a uint32 in Monaco: a negative Int here is
                    // a number above 2^31 there, out of the data too
                    if (edit.start < 0 || edit.start > srcData.length) {
                        styling.warnInvalidEditStart(currentResponse.resultId, edits.resultId, i, edit.start, srcData.length);
                        // The edits are invalid and there's no way to recover
                        this._model.tokenization.setSemanticTokens(null, true);
                        return;
                    }

                    final copyCount = srcLastStart - (edit.start + edit.deleteCount);
                    if (copyCount > 0) {
                        _copy(srcData, srcLastStart - copyCount, destData, destLastStart - copyCount, copyCount);
                        destLastStart -= copyCount;
                    }

                    final editData = edit.data;
                    if (editData != null) {
                        _copy(editData, 0, destData, destLastStart - editData.length, editData.length);
                        destLastStart -= editData.length;
                    }

                    srcLastStart = edit.start;
                    i--;
                }

                if (srcLastStart > 0) {
                    _copy(srcData, 0, destData, 0, srcLastStart);
                }

                final full:SemanticTokens = {
                    resultId: edits.resultId,
                    data: destData
                };
                tokens = full;
            }
        }

        if (GetSemanticTokens.isSemanticTokens(tokens)) {
            final full:SemanticTokens = cast tokens;

            this._currentDocumentResponse = new SemanticTokensResponse(provider, full.resultId, full.data);

            final result = SemanticTokensProviderStyling.toMultilineTokens2(full, styling, this._model.getLanguageId());

            // Adjust incoming semantic tokens
            if (pendingChanges.length > 0) {
                // More changes occurred while the request was running
                // We need to:
                // 1. Adjust incoming semantic tokens
                // 2. Request them again
                for (change in pendingChanges) {
                    for (area in result) {
                        for (singleChange in change.changes) {
                            area.applyEdit(singleChange.range, singleChange.text);
                        }
                    }
                }
            }

            this._model.tokenization.setSemanticTokens(result, true);
        }
        else {
            this._model.tokenization.setSemanticTokens(null, true);
        }

        rescheduleIfNeeded();
    }

}

class SemanticTokensResponse {

    public final provider:DocumentSemanticTokensProvider;
    public final resultId:Null<String>;
    public final data:UInt32Array;

    public function new(provider:DocumentSemanticTokensProvider, resultId:Null<String>, data:UInt32Array) {
        this.provider = provider;
        this.resultId = resultId;
        this.data = data;
    }

    public function dispose():Void {
        this.provider.releaseDocumentSemanticTokens(this.resultId);
    }

}

/**
 * Monaco's debounce of a language feature (`ILanguageFeatureDebounceService.for(
 * provider, name, {min, max})`): the delay follows the time the last
 * requests of a model took (a sliding average of 6), between `min` and
 * `max`, the average of all the models (else `min * 1.5`) before a first
 * request. Kept per coloring here (Monaco keeps it per model and providers
 * in a global service).
 */
class SemanticTokensDebounceInformation {

    final _min:Float;
    final _max:Float;
    final _default:Float;
    final _values:Array<Float> = [];
    var _sum:Float = 0;
    var _modelId:Null<String> = null;

    public function new(min:Float, max:Float) {
        _min = min;
        _max = max;
        _default = Std.int(min * 1.5);
    }

    function clamp(value:Float):Float {
        return Math.min(_max, Math.max(_min, value));
    }

    public function get(model:ITextModel):Float {
        if (_modelId != model.id || _values.length == 0) {
            return clamp(_default);
        }
        return clamp(_sum / _values.length);
    }

    public function update(model:ITextModel, value:Float):Float {
        if (_modelId != model.id) {
            _modelId = model.id;
            _values.resize(0);
            _sum = 0;
        }
        _values.push(value);
        _sum += value;
        if (_values.length > 6) {
            _sum -= _values.shift();
        }
        return clamp(_sum / _values.length);
    }

}
