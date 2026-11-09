// Ported from vscode src/vs/editor/contrib/stickyScroll/browser/stickyScrollModelProvider.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.stickyScroll.view;

import cityscape.base.common.Async;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Lifecycle;
import cityscape.common.config.EditorOptions;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.common.services.LanguageFeaturesService;
import cityscape.contrib.documentSymbols.view.OutlineModel;
import cityscape.contrib.folding.view.Folding;
import cityscape.contrib.folding.view.FoldingRanges.FoldingRegions;
import cityscape.contrib.folding.view.IndentRangeProvider;
import cityscape.contrib.folding.view.SyntaxRangeProvider;
import cityscape.contrib.stickyScroll.view.StickyScrollElement;
import cityscape.view.EditorBrowser.ICodeEditor;

/*
 * Monaco's promises are callbacks here: `update(token, done)`,
 * `computeStickyModel(token, done)`. The outline provider asks
 * `OutlineModel.create` directly (no `OutlineModelService` cache).
 */

enum abstract ModelProvider(String) from String to String {
    var OUTLINE_MODEL = 'outlineModel';
    var FOLDING_PROVIDER_MODEL = 'foldingProviderModel';
    var INDENTATION_MODEL = 'indentationModel';
}

enum abstract Status(Int) from Int to Int {
    var VALID = 0;
    var INVALID = 1;
    var CANCELED = 2;
}

interface IStickyModelProvider extends IDisposable {

    /**
     * Method which updates the sticky model; `done` receives the sticky
     * model (null when none), unless the update is replaced first.
     */
    function update(token:CancellationToken, done:(model:Null<StickyModel>) -> Void):Void;
}

class StickyModelProvider extends Disposable implements IStickyModelProvider {

    final _modelProviders:Array<StickyModelCandidateProvider> = [];
    final _updateScheduler:Delayer;
    final _updateOperation:DisposableStore;
    final _editor:ICodeEditor;

    /**
     * Monaco's `_modelPromise`: the computation in progress, replaced (and so
     * ignored) when a new update starts.
     */
    var _computation:Int = 0;

    public function new(editor:ICodeEditor, onProviderUpdate:() -> Void, languageConfigurationService:ILanguageConfigurationService, languageFeaturesService:LanguageFeaturesService) {
        super();
        this._editor = editor;
        this._updateScheduler = this._register(new Delayer(300));
        this._updateOperation = this._register(new DisposableStore());

        final defaultModel:String = this._editor.getOption(EditorOption.stickyScroll).defaultModel;
        // Monaco's switch falls through from the outline to the folding provider to the indentation
        if (defaultModel == ModelProvider.OUTLINE_MODEL) {
            this._modelProviders.push(new StickyModelFromCandidateOutlineProvider(this._editor, languageFeaturesService));
        }
        if (defaultModel == ModelProvider.OUTLINE_MODEL || defaultModel == ModelProvider.FOLDING_PROVIDER_MODEL) {
            this._modelProviders.push(new StickyModelFromCandidateSyntaxFoldingProvider(this._editor, onProviderUpdate, languageFeaturesService));
        }
        if (defaultModel == ModelProvider.OUTLINE_MODEL || defaultModel == ModelProvider.FOLDING_PROVIDER_MODEL || defaultModel == ModelProvider.INDENTATION_MODEL) {
            this._modelProviders.push(new StickyModelFromCandidateIndentationFoldingProvider(this._editor, languageConfigurationService));
        }
    }

    override public function dispose():Void {
        for (provider in this._modelProviders) {
            provider.dispose();
        }
        this._updateOperation.clear();
        this._cancelModelPromise();
        super.dispose();
    }

    function _cancelModelPromise():Void {
        this._computation++;
    }

    public function update(token:CancellationToken, done:(model:Null<StickyModel>) -> Void):Void {

        this._updateOperation.clear();
        this._updateOperation.add(Lifecycle.toDisposable(() -> {
            this._cancelModelPromise();
            this._updateScheduler.cancel();
        }));
        this._cancelModelPromise();

        this._updateScheduler.trigger(() -> {
            final computation = ++this._computation;
            var index = 0;
            function next():Void {
                if (index >= this._modelProviders.length) {
                    done(null);
                    return;
                }
                final modelProvider = this._modelProviders[index++];
                try {
                    modelProvider.computeStickyModel(token, (status) -> {
                        if (this._computation != computation) {
                            return;
                        }
                        switch (status) {
                            case Status.CANCELED:
                                this._updateOperation.clear();
                                done(null);
                            case Status.VALID:
                                done(modelProvider.stickyModel);
                            case _:
                                next();
                        }
                    });
                }
                catch (e:Dynamic) {
                    Errors.onUnexpectedError(e);
                    done(null);
                }
            }
            next();
        });
    }

    /**
     * Runs the pending update now (tests; Monaco waits 300 ms).
     */
    public function _flushPendingUpdate():Void {
        this._updateScheduler.flush();
    }

}

abstract class StickyModelCandidateProvider extends Disposable {

    var _stickyModel:Null<StickyModel> = null;
    final _editor:ICodeEditor;

    public function new(editor:ICodeEditor) {
        super();
        this._editor = editor;
    }

    public var stickyModel(get, never):Null<StickyModel>;
    function get_stickyModel():Null<StickyModel> {
        return this._stickyModel;
    }

    function _invalid():Status {
        this._stickyModel = null;
        return Status.INVALID;
    }

    /**
     * Computes the sticky model and gives `done` a status saying whether it
     * was found.
     */
    public function computeStickyModel(token:CancellationToken, done:(status:Status) -> Void):Void {
        if (token.isCancellationRequested || !this.isProviderValid()) {
            done(this._invalid());
            return;
        }
        this.createModelFromProvider(token, (providerModel) -> {
            try {
                if (!this.isModelValid(providerModel)) {
                    done(this._invalid());
                    return;
                }
                if (token.isCancellationRequested) {
                    done(Status.CANCELED);
                    return;
                }
                this._stickyModel = this.createStickyModel(token, providerModel);
                done(Status.VALID);
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedError(e);
                done(Status.CANCELED);
            }
        });
    }

    /**
     * Method which checks whether the model returned by the provider is valid and can be used to compute a sticky model.
     * This method by default returns true.
     */
    function isModelValid(model:Any):Bool {
        return true;
    }

    /**
     * Method which checks whether the provider is valid before applying it to find the provider model.
     * This method by default returns true.
     */
    function isProviderValid():Bool {
        return true;
    }

    /**
     * Creates the model from the provider and gives it to `done`.
     */
    abstract function createModelFromProvider(token:CancellationToken, done:(model:Any) -> Void):Void;

    /**
     * Computes the sticky model from the model returned by the provider.
     */
    abstract function createStickyModel(token:CancellationToken, model:Any):StickyModel;

}

class StickyModelFromCandidateOutlineProvider extends StickyModelCandidateProvider {

    final _languageFeaturesService:LanguageFeaturesService;

    public function new(editor:ICodeEditor, languageFeaturesService:LanguageFeaturesService) {
        super(editor);
        this._languageFeaturesService = languageFeaturesService;
    }

    function createModelFromProvider(token:CancellationToken, done:(model:Any) -> Void):Void {
        OutlineModel.create(this._languageFeaturesService.documentSymbolProvider, this._editor.getModel(), token, (model) -> done(model));
    }

    function createStickyModel(token:CancellationToken, model:Any):StickyModel {
        final result = this._stickyModelFromOutlineModel(model, this._stickyModel != null ? this._stickyModel.outlineProviderId : null);
        final textModel = this._editor.getModel();
        return new StickyModel(textModel.uri, textModel.getVersionId(), result.stickyOutlineElement, result.providerID);
    }

    override function isModelValid(model:Any):Bool {
        final outline:Null<OutlineModel> = model;
        return outline != null && outline.children.size > 0;
    }

    function _stickyModelFromOutlineModel(outlineModel:OutlineModel, preferredProvider:Null<String>):{stickyOutlineElement:StickyElement, providerID:Null<String>} {

        var outlineElements:Array<OutlineElement>;
        // When several possible outline providers
        final first = outlineModel.children.values()[0];
        if (Std.isOfType(first, OutlineGroup)) {
            var provider:Null<OutlineGroup> = null;
            for (group in outlineModel.children.values()) {
                if (group.id == preferredProvider) {
                    provider = cast group;
                    break;
                }
            }
            if (provider != null) {
                outlineElements = provider.children.values();
            }
            else {
                var tempID = '';
                var maxTotalSumOfRanges = -1;
                var optimalOutlineGroup:Null<OutlineGroup> = null;
                for (child in outlineModel.children.values()) {
                    final outlineGroup:OutlineGroup = cast child;
                    final totalSumRanges = this._findSumOfRangesOfGroup(outlineGroup);
                    if (totalSumRanges > maxTotalSumOfRanges) {
                        optimalOutlineGroup = outlineGroup;
                        maxTotalSumOfRanges = totalSumRanges;
                        tempID = outlineGroup.id;
                    }
                }
                preferredProvider = tempID;
                outlineElements = optimalOutlineGroup.children.values();
            }
        }
        else {
            outlineElements = cast outlineModel.children.values();
        }
        final stickyChildren:Array<StickyElement> = [];
        final outlineElementsArray = outlineElements.copy();
        haxe.ds.ArraySort.sort(outlineElementsArray, (element1, element2) -> {
            final range1 = new StickyRange(element1.symbol.range.startLineNumber, element1.symbol.range.endLineNumber);
            final range2 = new StickyRange(element2.symbol.range.startLineNumber, element2.symbol.range.endLineNumber);
            return this._comparator(range1, range2);
        });
        for (outlineElement in outlineElementsArray) {
            stickyChildren.push(this._stickyModelFromOutlineElement(outlineElement, outlineElement.symbol.selectionRange.startLineNumber));
        }
        final stickyOutlineElement = new StickyElement(null, stickyChildren, null);

        return {
            stickyOutlineElement: stickyOutlineElement,
            providerID: preferredProvider
        };
    }

    function _stickyModelFromOutlineElement(outlineElement:OutlineElement, previousStartLine:Int):StickyElement {
        final children:Array<StickyElement> = [];
        for (child in outlineElement.children.values()) {
            if (child.symbol.selectionRange.startLineNumber != child.symbol.range.endLineNumber) {
                if (child.symbol.selectionRange.startLineNumber != previousStartLine) {
                    children.push(this._stickyModelFromOutlineElement(child, child.symbol.selectionRange.startLineNumber));
                }
                else {
                    for (subchild in child.children.values()) {
                        children.push(this._stickyModelFromOutlineElement(subchild, child.symbol.selectionRange.startLineNumber));
                    }
                }
            }
        }
        haxe.ds.ArraySort.sort(children, (child1, child2) -> this._comparator(child1.range, child2.range));
        final range = new StickyRange(outlineElement.symbol.selectionRange.startLineNumber, outlineElement.symbol.range.endLineNumber);
        return new StickyElement(range, children, null);
    }

    function _comparator(range1:StickyRange, range2:StickyRange):Int {
        if (range1.startLineNumber != range2.startLineNumber) {
            return range1.startLineNumber - range2.startLineNumber;
        }
        else {
            return range2.endLineNumber - range1.endLineNumber;
        }
    }

    function _findSumOfRangesOfGroup(outline:TreeElement):Int {
        var res = 0;
        for (child in outline.childElements()) {
            res += this._findSumOfRangesOfGroup(child);
        }
        if (Std.isOfType(outline, OutlineElement)) {
            final element:OutlineElement = cast outline;
            return res + element.symbol.range.endLineNumber - element.symbol.selectionRange.startLineNumber;
        }
        else {
            return res;
        }
    }

}

abstract class StickyModelFromCandidateFoldingProvider extends StickyModelCandidateProvider {

    final _foldingLimitReporter:RangesLimitReporter;

    public function new(editor:ICodeEditor) {
        super(editor);
        this._foldingLimitReporter = new RangesLimitReporter(new CodeEditorFoldingAdapter(editor));
    }

    function createStickyModel(token:CancellationToken, model:Any):StickyModel {
        final foldingElement = this._fromFoldingRegions(model);
        final textModel = this._editor.getModel();
        return new StickyModel(textModel.uri, textModel.getVersionId(), foldingElement, null);
    }

    override function isModelValid(model:Any):Bool {
        return model != null;
    }

    function _fromFoldingRegions(foldingRegions:FoldingRegions):StickyElement {
        final length = foldingRegions.length;
        final orderedStickyElements:Array<StickyElement> = [];

        // The root sticky outline element
        final stickyOutlineElement = new StickyElement(
            null,
            [],
            null
        );

        for (i in 0...length) {
            // Finding the parent index of the current range
            final parentIndex = foldingRegions.getParentIndex(i);

            var parentNode:StickyElement;
            if (parentIndex != -1) {
                // Access the reference of the parent node
                parentNode = orderedStickyElements[parentIndex];
            }
            else {
                // In that case the parent node is the root node
                parentNode = stickyOutlineElement;
            }

            final child = new StickyElement(
                new StickyRange(foldingRegions.getStartLineNumber(i), foldingRegions.getEndLineNumber(i) + 1),
                [],
                parentNode
            );
            parentNode.children.push(child);
            orderedStickyElements.push(child);
        }
        return stickyOutlineElement;
    }

}

class StickyModelFromCandidateIndentationFoldingProvider extends StickyModelFromCandidateFoldingProvider {

    final provider:IndentRangeProvider;

    public function new(editor:ICodeEditor, languageConfigurationService:ILanguageConfigurationService) {
        super(editor);
        this.provider = new IndentRangeProvider(editor.getModel(), languageConfigurationService, this._foldingLimitReporter);
        this._register(Lifecycle.toDisposable(() -> this.provider.dispose()));
    }

    function createModelFromProvider(token:CancellationToken, done:(model:Any) -> Void):Void {
        this.provider.compute(token, (regions) -> done(regions));
    }

}

class StickyModelFromCandidateSyntaxFoldingProvider extends StickyModelFromCandidateFoldingProvider {

    final provider:Null<SyntaxRangeProvider>;

    public function new(editor:ICodeEditor, onProviderUpdate:() -> Void, languageFeaturesService:LanguageFeaturesService) {
        super(editor);
        final selectedProviders = FoldingController.getFoldingRangeProviders(editor.context, editor.getModel());
        if (selectedProviders.length > 0) {
            final p = new SyntaxRangeProvider(editor.getModel(), selectedProviders, onProviderUpdate, this._foldingLimitReporter, null);
            this.provider = p;
            this._register(Lifecycle.toDisposable(() -> p.dispose()));
        }
        else {
            this.provider = null;
        }
    }

    override function isProviderValid():Bool {
        return this.provider != null;
    }

    function createModelFromProvider(token:CancellationToken, done:(model:Any) -> Void):Void {
        if (this.provider == null) {
            done(null);
            return;
        }
        this.provider.compute(token, (regions) -> done(regions));
    }

}
