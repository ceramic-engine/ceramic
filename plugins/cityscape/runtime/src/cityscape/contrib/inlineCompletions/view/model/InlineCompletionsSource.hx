// Ported from vscode src/vs/editor/contrib/inlineCompletions/browser/model/inlineCompletionsSource.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlineCompletions.view.model;

import cityscape.Cityscape;
import cityscape.base.common.Async;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Filters;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Observable;
import cityscape.base.common.Promise;
import cityscape.base.common.observableInternal.Base;
import cityscape.common.Languages;
import cityscape.common.Model;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.TextEdit.SingleTextEdit;
import cityscape.common.core.TextLength;
import cityscape.common.diff.defaultLinesDiffComputer.Utils.Utils as DiffUtils;
import cityscape.common.services.LanguageFeatureDebounce.IFeatureDebounceInformation;
import cityscape.contrib.inlineCompletions.view.model.ProvideInlineCompletions;
import cityscape.contrib.inlineCompletions.view.model.SingleTextEdit.SingleTextEditUtils;

/**
 * Asks the providers for inline completions and keeps the last result
 * (Monaco's `InlineCompletionsSource`). The language features and the
 * language configurations are the services of the `Cityscape` context.
 */
class InlineCompletionsSource extends Disposable {

    final _updateOperation:MutableDisposable<UpdateOperation>;
    public final inlineCompletions:DisposableObservableValue<UpToDateInlineCompletions>;
    public final suggestWidgetInlineCompletions:DisposableObservableValue<UpToDateInlineCompletions>;

    final textModel:ITextModel;
    final versionId:IObservable<Null<Int>>;
    final _debounceValue:IFeatureDebounceInformation;
    final context:Cityscape;

    public function new(textModel:ITextModel, versionId:IObservable<Null<Int>>, debounceValue:IFeatureDebounceInformation, context:Cityscape) {
        super();
        this.textModel = textModel;
        this.versionId = versionId;
        this._debounceValue = debounceValue;
        this.context = context;
        this._updateOperation = this._register(new MutableDisposable<UpdateOperation>());
        this.inlineCompletions = Observable.disposableObservableValue('inlineCompletions', null);
        this.suggestWidgetInlineCompletions = Observable.disposableObservableValue('suggestWidgetInlineCompletions', null);

        this._register(this.textModel.onDidChangeContent(_ -> {
            this._updateOperation.clear();
        }));
    }

    public function fetch(position:Position, context:InlineCompletionContext, activeInlineCompletion:Null<InlineCompletionWithUpdatedRange>):Promise<Bool> {
        final request = new UpdateRequest(position, context, this.textModel.getVersionId());

        final target = context.selectedSuggestionInfo != null ? this.suggestWidgetInlineCompletions : this.inlineCompletions;

        final currentOperation = this._updateOperation.value;
        if (currentOperation != null && currentOperation.request.satisfies(request)) {
            return currentOperation.promise;
        }
        else {
            final current = target.get();
            if (current != null && current.request.satisfies(request)) {
                return Promise.resolve(true);
            }
        }

        final updateOngoing = this._updateOperation.value != null;
        this._updateOperation.clear();

        final source = new CancellationTokenSource();

        final isCancelled = () -> source.token.isCancellationRequested || this._store.isDisposed || this.textModel.getVersionId() != request.versionId;

        final promise = new Promise<Bool>((resolve, _) -> {
            function provide():Void {
                if (isCancelled()) {
                    resolve(false);
                    return;
                }

                final startTime = haxe.Timer.stamp();
                ProvideInlineCompletions.provideInlineCompletions(
                    this.context.languageFeaturesService.inlineCompletionsProvider,
                    position,
                    this.textModel,
                    context,
                    source.token,
                    this.context.languageConfigurationService
                ).done(updatedCompletions -> {
                    if (isCancelled()) {
                        resolve(false);
                        return;
                    }

                    final endTime = haxe.Timer.stamp();
                    this._debounceValue.update(this.textModel, (endTime - startTime) * 1000);

                    final completions = new UpToDateInlineCompletions(updatedCompletions, request, this.textModel, this.versionId);
                    if (activeInlineCompletion != null) {
                        final asInlineCompletion = activeInlineCompletion.toInlineCompletion(null);
                        if (activeInlineCompletion.canBeReused(this.textModel, position) && !updatedCompletions.has(asInlineCompletion)) {
                            completions.prepend(activeInlineCompletion.inlineCompletion, asInlineCompletion.range, true);
                        }
                    }

                    this._updateOperation.clear();
                    Observable.transaction(tx -> {
                        /** @description Update completions with provider result */
                        target.set(completions, tx);
                    });

                    resolve(true);
                }, e -> {
                    resolve(false);
                });
            }

            final shouldDebounce = updateOngoing || context.triggerKind == InlineCompletionTriggerKind.Automatic;
            if (shouldDebounce) {
                // This debounces the operation
                wait(this._debounceValue.get(this.textModel), source.token, provide);
            }
            else {
                provide();
            }
        });

        // The provider may have answered at once: the operation is then done
        // and must not be kept as the ongoing one.
        if (!promise.isSettled) {
            final updateOperation = new UpdateOperation(request, source, promise);
            this._updateOperation.value = updateOperation;
        }

        return promise;
    }

    public function clear(tx:Null<ITransaction>):Void {
        this._updateOperation.clear();
        this.inlineCompletions.set(null, tx);
        this.suggestWidgetInlineCompletions.set(null, tx);
    }

    public function clearSuggestWidgetInlineCompletions(tx:Null<ITransaction>):Void {
        final op = this._updateOperation.value;
        if (op != null && op.request.context.selectedSuggestionInfo != null) {
            this._updateOperation.clear();
        }
        this.suggestWidgetInlineCompletions.set(null, tx);
    }

    public function cancelUpdate():Void {
        this._updateOperation.clear();
    }

    override public function dispose():Void {
        super.dispose();
        this.inlineCompletions.dispose();
        this.suggestWidgetInlineCompletions.dispose();
    }

    /**
     * Calls `done` after `ms` milliseconds, or at once when the token is
     * cancelled (Monaco's `wait`, which resolves a promise).
     */
    static function wait(ms:Float, cancellationToken:CancellationToken, done:() -> Void):Void {
        var d:Null<IDisposable> = null;
        var finished = false;
        final cancel = Async.setTimeout(() -> {
            if (d != null) {
                d.dispose();
            }
            if (!finished) {
                finished = true;
                done();
            }
        }, ms);
        d = cancellationToken.onCancellationRequested(() -> {
            cancel();
            if (d != null) {
                d.dispose();
            }
            if (!finished) {
                finished = true;
                done();
            }
        });
    }

}

class UpdateRequest {

    public final position:Position;
    public final context:InlineCompletionContext;
    public final versionId:Int;

    public function new(position:Position, context:InlineCompletionContext, versionId:Int) {
        this.position = position;
        this.context = context;
        this.versionId = versionId;
    }

    public function satisfies(other:UpdateRequest):Bool {
        return this.position.equals(other.position)
            && equalsIfDefined(this.context.selectedSuggestionInfo, other.context.selectedSuggestionInfo)
            && (other.context.triggerKind == InlineCompletionTriggerKind.Automatic
                || this.context.triggerKind == InlineCompletionTriggerKind.Explicit)
            && this.versionId == other.versionId;
    }

    /**
     * `equalsIfDefined(a, b, itemEquals())` of equals.ts.
     */
    static function equalsIfDefined(v1:Null<SelectedSuggestionInfo>, v2:Null<SelectedSuggestionInfo>):Bool {
        if (v1 == null || v2 == null) {
            return v2 == v1;
        }
        return v1.equals(v2);
    }

}

class UpdateOperation implements IDisposable {

    public final request:UpdateRequest;
    public final cancellationTokenSource:CancellationTokenSource;
    public final promise:Promise<Bool>;

    public function new(request:UpdateRequest, cancellationTokenSource:CancellationTokenSource, promise:Promise<Bool>) {
        this.request = request;
        this.cancellationTokenSource = cancellationTokenSource;
        this.promise = promise;
    }

    public function dispose():Void {
        this.cancellationTokenSource.cancel();
    }

}

class UpToDateInlineCompletions implements IDisposable {

    final _inlineCompletions:Array<InlineCompletionWithUpdatedRange>;
    public var inlineCompletions(get, never):Array<InlineCompletionWithUpdatedRange>;
    function get_inlineCompletions():Array<InlineCompletionWithUpdatedRange> {
        return this._inlineCompletions;
    }

    var _refCount:Int = 1;
    final _prependedInlineCompletionItems:Array<InlineCompletionItem> = [];

    final inlineCompletionProviderResult:InlineCompletionProviderResult;
    public final request:UpdateRequest;
    final _textModel:ITextModel;
    final _versionId:IObservable<Null<Int>>;

    public function new(inlineCompletionProviderResult:InlineCompletionProviderResult, request:UpdateRequest, textModel:ITextModel, versionId:IObservable<Null<Int>>) {
        this.inlineCompletionProviderResult = inlineCompletionProviderResult;
        this.request = request;
        this._textModel = textModel;
        this._versionId = versionId;
        final ids = textModel.deltaDecorations([], [for (i in inlineCompletionProviderResult.completions) {
            range: i.range,
            options: {
                description: 'inline-completion-tracking-range'
            },
        }]);

        this._inlineCompletions = [for (index in 0...inlineCompletionProviderResult.completions.length)
            new InlineCompletionWithUpdatedRange(inlineCompletionProviderResult.completions[index], ids[index], this._textModel, this._versionId)
        ];
    }

    public function clone():UpToDateInlineCompletions {
        this._refCount++;
        return this;
    }

    public function dispose():Void {
        this._refCount--;
        if (this._refCount == 0) {
            Async.setTimeout(() -> {
                // To fix https://github.com/microsoft/vscode/issues/188348
                if (!this._textModel.isDisposed()) {
                    // This is just cleanup. It's ok if it happens with a delay.
                    this._textModel.deltaDecorations([for (i in this._inlineCompletions) i.decorationId], []);
                }
            }, 0);
            this.inlineCompletionProviderResult.dispose();
            for (i in this._prependedInlineCompletionItems) {
                i.source.removeRef();
            }
        }
    }

    public function prepend(inlineCompletion:InlineCompletionItem, range:Range, addRefToSource:Bool):Void {
        if (addRefToSource) {
            inlineCompletion.source.addRef();
        }

        final id = this._textModel.deltaDecorations([], [{
            range: range,
            options: {
                description: 'inline-completion-tracking-range'
            },
        }])[0];
        this._inlineCompletions.unshift(new InlineCompletionWithUpdatedRange(inlineCompletion, id, this._textModel, this._versionId));
        this._prependedInlineCompletionItems.push(inlineCompletion);
    }

}

class InlineCompletionWithUpdatedRange {

    public final semanticId:String;

    public var forwardStable(get, never):Bool;
    function get_forwardStable():Bool {
        return this.inlineCompletion.source.inlineCompletions.enableForwardStability == true;
    }

    final _updatedRange:IObservable<Null<Range>>;

    public final inlineCompletion:InlineCompletionItem;
    public final decorationId:String;
    final _textModel:ITextModel;
    final _modelVersion:IObservable<Null<Int>>;

    public function new(inlineCompletion:InlineCompletionItem, decorationId:String, textModel:ITextModel, modelVersion:IObservable<Null<Int>>) {
        this.inlineCompletion = inlineCompletion;
        this.decorationId = decorationId;
        this._textModel = textModel;
        this._modelVersion = modelVersion;
        // JSON.stringify([filterText, insertText, start position])
        this.semanticId = '[' + haxe.Json.stringify(inlineCompletion.filterText) + ',' + haxe.Json.stringify(inlineCompletion.insertText) + ','
            + haxe.Json.stringify(inlineCompletion.range.getStartPosition().toString()) + ']';
        this._updatedRange = Observable.derivedOpts({equalsFn: (a:Null<Range>, b:Null<Range>) -> Range.equalsRangeStatic(a, b)}, reader -> {
            this._modelVersion.read(reader);
            return this._textModel.getDecorationRange(this.decorationId);
        });
    }

    public function toInlineCompletion(reader:Null<IReader>):InlineCompletionItem {
        final r = this._updatedRange.read(reader);
        return this.inlineCompletion.withRange(r != null ? r : emptyRange);
    }

    public function toSingleTextEdit(reader:Null<IReader>):SingleTextEdit {
        final r = this._updatedRange.read(reader);
        return new SingleTextEdit(r != null ? r : emptyRange, this.inlineCompletion.insertText);
    }

    public function isVisible(model:ITextModel, cursorPosition:Position, reader:Null<IReader>):Bool {
        final minimizedReplacement = SingleTextEditUtils.singleTextRemoveCommonPrefix(this._toFilterTextReplacement(reader), model);
        final updatedRange = this._updatedRange.read(reader);
        if (
            updatedRange == null
            || !this.inlineCompletion.range.getStartPosition().equals(updatedRange.getStartPosition())
            || cursorPosition.lineNumber != minimizedReplacement.range.startLineNumber
        ) {
            return false;
        }

        // We might consider comparing by .toLowerText, but this requires GhostTextReplacement
        final originalValue = model.getValueInRange(minimizedReplacement.range, EndOfLinePreference.LF);
        final filterText = minimizedReplacement.text;

        final cursorPosIndex = Std.int(Math.max(0, cursorPosition.column - minimizedReplacement.range.startColumn));

        var filterTextBefore = filterText.substring(0, cursorPosIndex);
        var filterTextAfter = filterText.substring(cursorPosIndex);

        var originalValueBefore = originalValue.substring(0, cursorPosIndex);
        var originalValueAfter = originalValue.substring(cursorPosIndex);

        final originalValueIndent = model.getLineIndentColumn(minimizedReplacement.range.startLineNumber);
        if (minimizedReplacement.range.startColumn <= originalValueIndent) {
            // Remove indentation
            originalValueBefore = DiffUtils.jsTrimStart(originalValueBefore);
            if (originalValueBefore.length == 0) {
                originalValueAfter = DiffUtils.jsTrimStart(originalValueAfter);
            }
            filterTextBefore = DiffUtils.jsTrimStart(filterTextBefore);
            if (filterTextBefore.length == 0) {
                filterTextAfter = DiffUtils.jsTrimStart(filterTextAfter);
            }
        }

        return StringTools.startsWith(filterTextBefore, originalValueBefore)
            && Filters.matchesSubString(originalValueAfter, filterTextAfter) != null;
    }

    public function canBeReused(model:ITextModel, position:Position):Bool {
        final updatedRange = this._updatedRange.read(null);
        final result = updatedRange != null
            && updatedRange.containsPosition(position)
            && this.isVisible(model, position, null)
            && TextLength.ofRange(updatedRange).isGreaterThanOrEqualTo(TextLength.ofRange(this.inlineCompletion.range));
        return result;
    }

    function _toFilterTextReplacement(reader:Null<IReader>):SingleTextEdit {
        final r = this._updatedRange.read(reader);
        return new SingleTextEdit(r != null ? r : emptyRange, this.inlineCompletion.filterText);
    }

    static final emptyRange = new Range(1, 1, 1, 1);

}
