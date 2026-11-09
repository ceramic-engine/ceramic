// Ported from vscode src/vs/editor/contrib/folding/browser/folding.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.folding.view;

import cityscape.Cityscape;
import cityscape.base.common.Async;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.RegExp;
import cityscape.base.common.Strings;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.Languages.FoldingRange;
import cityscape.common.Languages.FoldingRangeKind;
import cityscape.common.Languages.FoldingRangeProvider;
import cityscape.common.Model.IModelDecorationsChangeAccessor;
import cityscape.common.Model.ITextModel;
import cityscape.common.TextModelEvents.IModelContentChangedEvent;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.contrib.folding.view.FoldingDecorations;
import cityscape.contrib.folding.view.FoldingModel;
import cityscape.contrib.folding.view.FoldingRanges;
import cityscape.view.EditorBrowser;
import cityscape.view.StableEditorScroll;

/**
 * The part of Monaco's `ICodeEditor` the folding contribution uses (the
 * Cityscape view implements it). Monaco's events are methods taking a
 * listener; the services Monaco injects come from the editor's context.
 */
interface IFoldingEditor extends IScrollStateEditor {
    function getFoldingContext():Cityscape;
    function getContribution(id:String):Null<Any>;
    function getModel():Null<ITextModel>;
    function getOption<V>(id:EditorOption<V>):V;
    function getSelections():Null<Array<Selection>>;
    function getSelection():Null<Selection>;
    function setSelections(selections:Array<Selection>):Void;
    function setSelection(selection:Selection):Void;
    function changeDecorations<T>(callback:(changeAccessor:IModelDecorationsChangeAccessor) -> T):Null<T>;
    function removeDecorations(decorationIds:Array<String>):Void;
    function setHiddenAreas(ranges:Array<Range>, source:Any):Void;
    function revealPositionInCenterIfOutsideViewport(position:Position, ?scrollType:ScrollType):Void;
    function onDidChangeModel(listener:() -> Void):IDisposable;
    function onDidChangeConfiguration(listener:(e:ConfigurationChangedEvent) -> Void):IDisposable;
    function onDidChangeModelLanguageConfiguration(listener:() -> Void):IDisposable;
    function onDidChangeModelContent(listener:(e:IModelContentChangedEvent) -> Void):IDisposable;
    function onDidChangeCursorPosition(listener:() -> Void):IDisposable;
    function onMouseDown(listener:(e:EditorMouseEvent) -> Void):IDisposable;
    function onMouseUp(listener:(e:EditorMouseEvent) -> Void):IDisposable;
}

interface RangeProvider extends IDisposable {
    var id(default, null):String;
    /**
     * Monaco returns a promise; `resolve` gets the regions (null when
     * there are none), at once or later.
     */
    function compute(cancelationToken:CancellationToken, resolve:(regions:Null<FoldingRegions>) -> Void):Void;
}

typedef FoldingStateMemento = {
    @:optional var collapsedRegions:Null<CollapseMemento>;
    @:optional var lineCount:Null<Int>;
    @:optional var provider:Null<String>;
    @:optional var foldedImports:Null<Bool>;
}

interface FoldingLimitReporter {
    var limit(get, never):Int;
    /**
     * `limited` is null for Monaco's `false`.
     */
    function update(computed:Int, limited:Null<Int>):Void;
}

typedef FoldingRangeProviderSelector = (provider:Array<FoldingRangeProvider>, document:ITextModel) -> Null<Array<FoldingRangeProvider>>;

interface SelectedLines {
    function startsInside(startLine:Int, endLine:Int):Bool;
}

private class NoSelectedLines implements SelectedLines {
    public function new() {}
    public function startsInside(startLine:Int, endLine:Int):Bool {
        return false;
    }
}

private class SelectionsSelectedLines implements SelectedLines {
    final selections:Array<Selection>;
    public function new(selections:Array<Selection>) {
        this.selections = selections;
    }
    public function startsInside(startLine:Int, endLine:Int):Bool {
        for (s in selections) {
            final line = s.startLineNumber;
            if (line >= startLine && line <= endLine) {
                return true;
            }
        }
        return false;
    }
}

/**
 * The editor contribution of folding (Monaco's `editor.contrib.folding`):
 * one per editor, so that two editors on one model fold independently.
 */
class FoldingController extends Disposable {

    public static inline final ID = 'editor.contrib.folding';

    public static function get(editor:IFoldingEditor):Null<FoldingController> {
        final contribution = editor.getContribution(ID);
        return Std.isOfType(contribution, FoldingController) ? cast contribution : null;
    }

    public static function getFoldingRangeProviders(context:Cityscape, model:ITextModel):Array<FoldingRangeProvider> {
        final foldingRangeProviders = context.languageFeaturesService.foldingRangeProvider.ordered(model);
        final selector = context.languageFeaturesService.foldingRangeSelector;
        if (selector != null) {
            final selected = selector(foldingRangeProviders, model);
            if (selected != null) {
                return selected;
            }
        }
        return foldingRangeProviders;
    }

    /**
     * Monaco's selector is global; Cityscape's belongs to a context.
     */
    public static function setFoldingRangeProviderSelector(context:Cityscape, foldingRangeSelector:FoldingRangeProviderSelector):IDisposable {
        context.languageFeaturesService.foldingRangeSelector = foldingRangeSelector;
        return Lifecycle.toDisposable(() -> {
            context.languageFeaturesService.foldingRangeSelector = null;
        });
    }

    final editor:IFoldingEditor;
    final context:Cityscape;
    var _isEnabled:Bool;
    var _useFoldingProviders:Bool;
    var _unfoldOnClickAfterEndOfLine:Bool;
    var _restoringViewState:Bool;
    var _foldingImportsByDefault:Bool;
    var _currentModelHasFoldedImports:Bool;

    final foldingDecorationProvider:FoldingDecorationProvider;

    var foldingModel:Null<FoldingModel>;
    var hiddenRangeModel:Null<HiddenRangeModel>;

    var rangeProvider:Null<RangeProvider>;
    var foldingRegionRequest:Null<CancellationTokenSource>;

    // Monaco's `foldingModelPromise` and `updateScheduler` (a `Delayer`):
    // the update runs after a delay; callers waiting for the folding model
    // are called when it ran
    var updateSchedulerActive:Bool = false;
    var updateDelay:Float = 0;
    var updateTimeout:Null<() -> Void> = null;
    var scheduledWaiters:Null<Array<(foldingModel:Null<FoldingModel>) -> Void>> = null;
    var computingWaiters:Null<Array<(foldingModel:Null<FoldingModel>) -> Void>> = null;
    var hasFoldingModelPromise:Bool = false;
    var resolvedFoldingModel:Null<FoldingModel> = null;
    final updateDebounceInfo:FoldingDebounceInformation;

    var cursorChangedScheduler:Null<RunOnceScheduler>;

    final localToDispose:DisposableStore = new DisposableStore();
    var mouseDownInfo:Null<{lineNumber:Int, iconClicked:Bool}>;

    public final _foldingLimitReporter:RangesLimitReporter;

    public function new(editor:IFoldingEditor) {
        super();
        _register(localToDispose);
        this.editor = editor;
        this.context = editor.getFoldingContext();

        _foldingLimitReporter = new RangesLimitReporter(editor);

        _isEnabled = editor.getOption(EditorOption.folding);
        _useFoldingProviders = editor.getOption(EditorOption.foldingStrategy) != 'indentation';
        _unfoldOnClickAfterEndOfLine = editor.getOption(EditorOption.unfoldOnClickAfterEndOfLine);
        _restoringViewState = false;
        _currentModelHasFoldedImports = false;
        _foldingImportsByDefault = editor.getOption(EditorOption.foldingImportsByDefault);
        updateDebounceInfo = new FoldingDebounceInformation(200);

        foldingModel = null;
        hiddenRangeModel = null;
        rangeProvider = null;
        foldingRegionRequest = null;
        cursorChangedScheduler = null;
        mouseDownInfo = null;

        FoldingColors.registerDecorationStyles(context.decorationStyles);
        foldingDecorationProvider = new FoldingDecorationProvider(editor);
        foldingDecorationProvider.showFoldingControls = editor.getOption(EditorOption.showFoldingControls);
        foldingDecorationProvider.showFoldingHighlights = editor.getOption(EditorOption.foldingHighlight);
        // TODO(step 3, context keys): CONTEXT_FOLDING_ENABLED (`foldingEnabled`)
        // is `isEnabled()` until the context key service lands

        _register(editor.onDidChangeModel(() -> onModelChanged()));

        _register(editor.onDidChangeConfiguration((e:ConfigurationChangedEvent) -> {
            if (e.hasChanged(EditorOption.folding)) {
                _isEnabled = editor.getOption(EditorOption.folding);
                onModelChanged();
            }
            if (e.hasChanged(EditorOption.foldingMaximumRegions)) {
                onModelChanged();
            }
            if (e.hasChanged(EditorOption.showFoldingControls) || e.hasChanged(EditorOption.foldingHighlight)) {
                foldingDecorationProvider.showFoldingControls = editor.getOption(EditorOption.showFoldingControls);
                foldingDecorationProvider.showFoldingHighlights = editor.getOption(EditorOption.foldingHighlight);
                triggerFoldingModelChanged();
            }
            if (e.hasChanged(EditorOption.foldingStrategy)) {
                _useFoldingProviders = editor.getOption(EditorOption.foldingStrategy) != 'indentation';
                onFoldingStrategyChanged();
            }
            if (e.hasChanged(EditorOption.unfoldOnClickAfterEndOfLine)) {
                _unfoldOnClickAfterEndOfLine = editor.getOption(EditorOption.unfoldOnClickAfterEndOfLine);
            }
            if (e.hasChanged(EditorOption.foldingImportsByDefault)) {
                _foldingImportsByDefault = editor.getOption(EditorOption.foldingImportsByDefault);
            }
        }));
        onModelChanged();
    }

    /**
     * The context key `foldingEnabled` (the precondition of the actions).
     */
    public function isEnabled():Bool {
        return _isEnabled;
    }

    public var limitReporter(get, never):RangesLimitReporter;
    inline function get_limitReporter():RangesLimitReporter {
        return _foldingLimitReporter;
    }

    /**
     * Store view state.
     */
    public function saveViewState():Null<FoldingStateMemento> {
        final model = editor.getModel();
        if (model == null || !_isEnabled || model.isTooLargeForTokenization()) {
            return {};
        }
        if (foldingModel != null) { // disposed ?
            final collapsedRegions = foldingModel.getMemento();
            final provider = rangeProvider != null ? rangeProvider.id : null;
            return {collapsedRegions: collapsedRegions, lineCount: model.getLineCount(), provider: provider, foldedImports: _currentModelHasFoldedImports};
        }
        return null;
    }

    /**
     * Restore view state.
     */
    public function restoreViewState(state:Null<FoldingStateMemento>):Void {
        final model = editor.getModel();
        if (model == null || !_isEnabled || model.isTooLargeForTokenization() || hiddenRangeModel == null) {
            return;
        }
        if (state == null) {
            return;
        }

        _currentModelHasFoldedImports = state.foldedImports == true;
        final collapsedRegions = state.collapsedRegions;
        if (collapsedRegions != null && collapsedRegions.length > 0 && foldingModel != null) {
            _restoringViewState = true;
            try {
                foldingModel.applyMemento(collapsedRegions);
            }
            catch (e:Dynamic) {
                _restoringViewState = false;
                throw e;
            }
            _restoringViewState = false;
        }
    }

    function onModelChanged():Void {
        localToDispose.clear();

        final model = editor.getModel();
        if (!_isEnabled || model == null || model.isTooLargeForTokenization()) {
            // huge files get no view model, so they cannot support hidden areas
            return;
        }

        _currentModelHasFoldedImports = false;
        final foldingModel = new FoldingModel(model, foldingDecorationProvider);
        this.foldingModel = foldingModel;
        localToDispose.add(foldingModel);

        final hiddenRangeModel = new HiddenRangeModel(foldingModel);
        this.hiddenRangeModel = hiddenRangeModel;
        localToDispose.add(hiddenRangeModel);
        localToDispose.add(hiddenRangeModel.onDidChange(hr -> onHiddenRangesChanges(hr)));

        updateSchedulerActive = true;
        updateDelay = updateDebounceInfo.get(model);

        final cursorChangedScheduler = new RunOnceScheduler(() -> revealCursor(), 200);
        this.cursorChangedScheduler = cursorChangedScheduler;
        localToDispose.add(cursorChangedScheduler);
        localToDispose.add(context.languageFeaturesService.foldingRangeProvider.onDidChange(_ -> onFoldingStrategyChanged()));
        localToDispose.add(editor.onDidChangeModelLanguageConfiguration(() -> onFoldingStrategyChanged())); // covers model language changes as well
        localToDispose.add(editor.onDidChangeModelContent(e -> onDidChangeModelContent(e)));
        localToDispose.add(editor.onDidChangeCursorPosition(() -> onCursorPositionChanged()));
        localToDispose.add(editor.onMouseDown(e -> onEditorMouseDown(e)));
        localToDispose.add(editor.onMouseUp(e -> onEditorMouseUp(e)));
        localToDispose.add(Lifecycle.toDisposable(() -> {
            cancelFoldingRegionRequest();
            cancelUpdateScheduler();
            updateSchedulerActive = false;
            this.foldingModel = null;
            hasFoldingModelPromise = false;
            resolvedFoldingModel = null;
            this.hiddenRangeModel = null;
            this.cursorChangedScheduler = null;
            if (rangeProvider != null) {
                rangeProvider.dispose();
            }
            rangeProvider = null;
        }));
        triggerFoldingModelChanged();
    }

    function onFoldingStrategyChanged():Void {
        if (rangeProvider != null) {
            rangeProvider.dispose();
        }
        rangeProvider = null;
        triggerFoldingModelChanged();
    }

    function getRangeProvider(editorModel:ITextModel):RangeProvider {
        if (rangeProvider != null) {
            return rangeProvider;
        }
        final indentRangeProvider = new IndentRangeProvider(editorModel, context.languageConfigurationService, _foldingLimitReporter);
        rangeProvider = indentRangeProvider; // fallback
        if (_useFoldingProviders && foldingModel != null) {
            final selectedProviders = getFoldingRangeProviders(context, editorModel);
            if (selectedProviders.length > 0) {
                rangeProvider = new SyntaxRangeProvider(editorModel, selectedProviders, () -> triggerFoldingModelChanged(), _foldingLimitReporter, indentRangeProvider);
            }
        }
        return rangeProvider;
    }

    /**
     * Calls `callback` with the folding model once the pending update ran
     * (Monaco returns the promise of the folding model). Returns false,
     * without calling `callback`, when folding is off or disposed (Monaco's
     * null).
     */
    public function getFoldingModel(callback:(foldingModel:Null<FoldingModel>) -> Void):Bool {
        if (!hasFoldingModelPromise) {
            return false;
        }
        if (scheduledWaiters != null) {
            scheduledWaiters.push(callback);
        }
        else if (computingWaiters != null) {
            computingWaiters.push(callback);
        }
        else {
            callback(resolvedFoldingModel);
        }
        return true;
    }

    /**
     * The current folding model, without waiting for a pending update.
     * @internal
     */
    public function _getCurrentFoldingModel():Null<FoldingModel> {
        return foldingModel;
    }

    /**
     * Runs the pending update now instead of after its delay (tests, and
     * hosts that need the folding ranges at once).
     * @internal
     */
    public function _flushPendingUpdate():Void {
        if (updateTimeout != null) {
            final cancel = updateTimeout;
            updateTimeout = null;
            cancel();
            runUpdate();
        }
    }

    function onDidChangeModelContent(e:IModelContentChangedEvent):Void {
        if (hiddenRangeModel != null) {
            hiddenRangeModel.notifyChangeModelContent(e);
        }
        triggerFoldingModelChanged();
    }

    function cancelFoldingRegionRequest():Void {
        if (foldingRegionRequest != null) {
            foldingRegionRequest.cancel();
            foldingRegionRequest = null;
            // Monaco: the cancelled request rejects, its waiters get null
            final waiters = computingWaiters;
            computingWaiters = null;
            resolveWaiters(waiters, null);
        }
    }

    function cancelUpdateScheduler():Void {
        if (updateTimeout != null) {
            final cancel = updateTimeout;
            updateTimeout = null;
            cancel();
        }
        scheduledWaiters = null;
    }

    static function resolveWaiters(waiters:Null<Array<(foldingModel:Null<FoldingModel>) -> Void>>, foldingModel:Null<FoldingModel>):Void {
        if (waiters == null) {
            return;
        }
        for (waiter in waiters) {
            try {
                waiter(foldingModel);
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedError(e);
            }
        }
    }

    public function triggerFoldingModelChanged():Void {
        if (updateSchedulerActive) {
            cancelFoldingRegionRequest();
            // Delayer.trigger: the last task wins, the waiters of the
            // pending trigger wait for it
            if (updateTimeout != null) {
                final cancel = updateTimeout;
                updateTimeout = null;
                cancel();
            }
            if (scheduledWaiters == null) {
                scheduledWaiters = [];
            }
            hasFoldingModelPromise = true;
            updateTimeout = Async.setTimeout(() -> {
                updateTimeout = null;
                runUpdate();
            }, updateDelay);
        }
    }

    function runUpdate():Void {
        final waiters = scheduledWaiters;
        scheduledWaiters = null;
        final foldingModel = this.foldingModel;
        if (foldingModel == null) { // null if editor has been disposed, or folding turned off
            resolvedFoldingModel = null;
            resolveWaiters(waiters, null);
            return;
        }
        final start = haxe.Timer.stamp();
        final provider = getRangeProvider(foldingModel.textModel);
        final request = new CancellationTokenSource();
        foldingRegionRequest = request;
        computingWaiters = waiters != null ? waiters : [];
        try {
            provider.compute(request.token, foldingRanges -> {
                if (foldingRegionRequest != request) { // new request or cancelled in the meantime?
                    return;
                }
                foldingRegionRequest = null;
                final waiters = computingWaiters;
                computingWaiters = null;
                try {
                    if (foldingRanges != null) {
                        var scrollState:Null<StableEditorScrollState> = null;

                        if (_foldingImportsByDefault && !_currentModelHasFoldedImports) {
                            final hasChanges = foldingRanges.setCollapsedAllOfType(FoldingRangeKind.Imports.value, true);
                            if (hasChanges) {
                                scrollState = StableEditorScrollState.capture(editor);
                                _currentModelHasFoldedImports = hasChanges;
                            }
                        }

                        // some cursors might have moved into hidden regions, make sure they are in expanded regions
                        final selections = editor.getSelections();
                        foldingModel.update(foldingRanges, toSelectedLines(selections));

                        if (scrollState != null) {
                            scrollState.restore(editor);
                        }

                        // update debounce info
                        final newValue = updateDebounceInfo.update(foldingModel.textModel, (haxe.Timer.stamp() - start) * 1000);
                        if (updateSchedulerActive) {
                            updateDelay = newValue;
                        }
                    }
                    resolvedFoldingModel = foldingModel;
                }
                catch (e:Dynamic) {
                    Errors.onUnexpectedError(e);
                    resolvedFoldingModel = null;
                    resolveWaiters(waiters, null);
                    return;
                }
                resolveWaiters(waiters, foldingModel);
            });
        }
        catch (e:Dynamic) {
            Errors.onUnexpectedError(e);
            if (foldingRegionRequest == request) {
                foldingRegionRequest = null;
                final waiters = computingWaiters;
                computingWaiters = null;
                resolvedFoldingModel = null;
                resolveWaiters(waiters, null);
            }
        }
    }

    function onHiddenRangesChanges(hiddenRanges:Array<Range>):Void {
        if (hiddenRangeModel != null && hiddenRanges.length > 0 && !_restoringViewState) {
            final selections = editor.getSelections();
            if (selections != null) {
                if (hiddenRangeModel.adjustSelections(selections)) {
                    editor.setSelections(selections);
                }
            }
        }
        editor.setHiddenAreas(hiddenRanges, this);
    }

    function onCursorPositionChanged():Void {
        if (hiddenRangeModel != null && hiddenRangeModel.hasRanges()) {
            cursorChangedScheduler.schedule();
        }
    }

    function revealCursor():Void {
        getFoldingModel(foldingModel -> { // null is returned if folding got disabled in the meantime
            if (foldingModel != null) {
                final selections = editor.getSelections();
                if (selections != null && selections.length > 0) {
                    final toToggle:Array<FoldingRegion> = [];
                    for (selection in selections) {
                        final lineNumber = selection.selectionStartLineNumber;
                        if (hiddenRangeModel != null && hiddenRangeModel.isHidden(lineNumber)) {
                            for (r in foldingModel.getAllRegionsAtLine(lineNumber, (r, _) -> r.isCollapsed && lineNumber > r.startLineNumber)) {
                                toToggle.push(r);
                            }
                        }
                    }
                    if (toToggle.length > 0) {
                        foldingModel.toggleCollapseState(toToggle);
                        reveal(selections[0].getPosition());
                    }
                }
            }
        });
    }

    /**
     * Runs the pending cursor reveal now (tests).
     * @internal
     */
    public function _flushCursorReveal():Void {
        if (cursorChangedScheduler != null) {
            cursorChangedScheduler.flush();
        }
    }

    function onEditorMouseDown(e:EditorMouseEvent):Void {
        mouseDownInfo = null;

        if (hiddenRangeModel == null || e.target == null || e.target.range == null) {
            return;
        }
        if (!e.event.leftButton && !e.event.middleButton) {
            return;
        }
        final range = e.target.range;
        var iconClicked = false;
        switch (e.target.type) {
            case MouseTargetType.GUTTER_LINE_DECORATIONS:
                final offsetLeftInGutter = e.target.elementOffsetLeft;
                final gutterOffsetX = e.target.offsetX - offsetLeftInGutter;

                // TODO@joao TODO@alex TODO@martin this is such that we don't collide with dirty diff
                if (gutterOffsetX < 4) { // the whitespace between the border and the real folding icon border is 4px
                    return;
                }

                iconClicked = true;
            case MouseTargetType.CONTENT_EMPTY:
                if (_unfoldOnClickAfterEndOfLine && hiddenRangeModel.hasRanges()) {
                    if (e.target.isAfterLines) {
                        return;
                    }
                }
                else {
                    return;
                }
            case MouseTargetType.CONTENT_TEXT:
                if (hiddenRangeModel.hasRanges()) {
                    final model = editor.getModel();
                    if (!(model != null && range.startColumn == model.getLineMaxColumn(range.startLineNumber))) {
                        return;
                    }
                }
                else {
                    return;
                }
            case _:
                return;
        }

        mouseDownInfo = {lineNumber: range.startLineNumber, iconClicked: iconClicked};
    }

    function onEditorMouseUp(e:EditorMouseEvent):Void {
        final foldingModel = this.foldingModel;
        if (foldingModel == null || mouseDownInfo == null || e.target == null) {
            return;
        }
        final lineNumber = mouseDownInfo.lineNumber;
        final iconClicked = mouseDownInfo.iconClicked;

        final range = e.target.range;
        if (range == null || range.startLineNumber != lineNumber) {
            return;
        }

        if (iconClicked) {
            if (e.target.type != MouseTargetType.GUTTER_LINE_DECORATIONS) {
                return;
            }
        }
        else {
            final model = editor.getModel();
            if (model == null || range.startColumn != model.getLineMaxColumn(lineNumber)) {
                return;
            }
        }

        final region = foldingModel.getRegionAtLine(lineNumber);
        if (region != null && region.startLineNumber == lineNumber) {
            final isCollapsed = region.isCollapsed;
            if (iconClicked || isCollapsed) {
                final surrounding = e.event.altKey;
                var toToggle:Array<FoldingRegion> = [];
                if (surrounding) {
                    final filter = (otherRegion:FoldingRegion) -> !otherRegion.containedBy(region) && !region.containedBy(otherRegion);
                    final toMaybeToggle = foldingModel.getRegionsInside(null, filter);
                    for (r in toMaybeToggle) {
                        if (r.isCollapsed) {
                            toToggle.push(r);
                        }
                    }
                    // if any surrounding regions are folded, unfold those. Otherwise, fold all surrounding
                    if (toToggle.length == 0) {
                        toToggle = toMaybeToggle;
                    }
                }
                else {
                    final recursive = e.event.middleButton || e.event.shiftKey;
                    if (recursive) {
                        for (r in foldingModel.getRegionsInside(region)) {
                            if (r.isCollapsed == isCollapsed) {
                                toToggle.push(r);
                            }
                        }
                    }
                    // when recursive, first only collapse all children. If all are already folded or there are no children, also fold parent.
                    if (isCollapsed || !recursive || toToggle.length == 0) {
                        toToggle.push(region);
                    }
                }
                foldingModel.toggleCollapseState(toToggle);
                reveal(new Position(lineNumber, 1));
            }
        }
    }

    public function reveal(position:Position):Void {
        editor.revealPositionInCenterIfOutsideViewport(position, ScrollType.Smooth);
    }

    public static function toSelectedLines(selections:Null<Array<Selection>>):SelectedLines {
        if (selections == null || selections.length == 0) {
            return new NoSelectedLines();
        }
        return new SelectionsSelectedLines(selections);
    }
}

class RangesLimitReporter implements FoldingLimitReporter {

    final editor:IFoldingEditor;

    public function new(editor:IFoldingEditor) {
        this.editor = editor;
    }

    public var limit(get, never):Int;
    function get_limit():Int {
        return editor.getOption(EditorOption.foldingMaximumRegions);
    }

    final _onDidChange = new VoidEmitter();
    public var onDidChange(get, never):VoidEvent;
    inline function get_onDidChange():VoidEvent {
        return _onDidChange.event;
    }

    var _computed:Int = 0;
    var _limited:Null<Int> = null;

    public var computed(get, never):Int;
    inline function get_computed():Int {
        return _computed;
    }

    /**
     * Null for Monaco's `false`.
     */
    public var limited(get, never):Null<Int>;
    inline function get_limited():Null<Int> {
        return _limited;
    }

    public function update(computed:Int, limited:Null<Int>):Void {
        if (computed != _computed || limited != _limited) {
            _computed = computed;
            _limited = limited;
            _onDidChange.fire();
        }
    }
}

/**
 * Monaco's debounce of the folding update (`ILanguageFeatureDebounceService.for(
 * foldingRangeProvider, 'Folding', {min: 200})`): the delay follows the
 * time the last updates took (a sliding average of 6), between 200 ms and
 * 40 s, 300 ms at first. Kept per controller (Monaco keeps it per model and
 * providers in a global service).
 */
private class FoldingDebounceInformation {

    final _min:Float;
    final _max:Float;
    final _default:Float;
    final _values:Array<Float> = [];
    var _sum:Float = 0;
    var _modelId:Null<String> = null;

    public function new(min:Float) {
        _min = min;
        _max = min * min;
        _default = min * 1.5;
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

/**
 * The arguments of `editor.fold` and `editor.unfold`.
 */
typedef FoldingArguments = {
    @:optional var levels:Null<Int>;
    /**
     * `'up'` or `'down'`.
     */
    @:optional var direction:Null<String>;
    /**
     * 0 based line numbers.
     */
    @:optional var selectionLines:Null<Array<Int>>;
}

/**
 * A key of a keybinding: Monaco's `KeyMod.CtrlCmd` (Cmd on macOS, Ctrl
 * elsewhere), `KeyMod.Shift`, `KeyMod.Alt`, `KeyMod.WinCtrl` (Ctrl on
 * macOS) and a key, named like Glaze's keystrokes (`'['`, `'0'`, `'l'`).
 */
class FoldingKeybindingPart {

    public final ctrlCmd:Bool;
    public final shift:Bool;
    public final alt:Bool;
    public final winCtrl:Bool;
    public final key:String;

    public function new(key:String, ctrlCmd:Bool = false, shift:Bool = false, alt:Bool = false, winCtrl:Bool = false) {
        this.key = key;
        this.ctrlCmd = ctrlCmd;
        this.shift = shift;
        this.alt = alt;
        this.winCtrl = winCtrl;
    }

    public function matches(keystroke:glaze.Keystroke, isMac:Bool):Bool {
        final mods = keystroke.modifiers;
        if (keystroke.key != key || mods.shift != shift || mods.alt != alt) {
            return false;
        }
        if (isMac) {
            return mods.platform == ctrlCmd && mods.control == winCtrl;
        }
        return !mods.platform && mods.control == (ctrlCmd || winCtrl);
    }

}

/**
 * A keybinding: one key, or a chord of two.
 */
class FoldingKeybinding {

    public final first:FoldingKeybindingPart;
    public final second:Null<FoldingKeybindingPart>;

    public function new(first:FoldingKeybindingPart, ?second:FoldingKeybindingPart) {
        this.first = first;
        this.second = second;
    }

}

/**
 * Monaco's `FoldingAction` (an `EditorAction` with its id, label, alias,
 * precondition `foldingEnabled` and keybindings for `editorTextFocus`).
 */
abstract class FoldingAction {

    public final id:String;
    public final label:String;
    public final alias:String;
    /**
     * `kbOpts.primary`, null when the action has no default key.
     */
    public final primary:Null<FoldingKeybinding>;
    /**
     * `kbOpts.mac.primary` when it differs from `primary`.
     */
    public final mac:Null<FoldingKeybinding>;

    function new(id:String, label:String, alias:String, primary:Null<FoldingKeybinding>, ?mac:FoldingKeybinding) {
        this.id = id;
        this.label = label;
        this.alias = alias;
        this.primary = primary;
        this.mac = mac;
    }

    /**
     * The keybinding on the given platform.
     */
    public function keybinding(isMac:Bool):Null<FoldingKeybinding> {
        return (isMac && mac != null) ? mac : primary;
    }

    abstract public function invoke(foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, args:Null<FoldingArguments>, context:Cityscape):Void;

    /**
     * Monaco's `runEditorCommand`: runs once the folding model is up to
     * date, then reveals the start of the selection.
     */
    public function runEditorCommand(context:Cityscape, editor:IFoldingEditor, args:Null<FoldingArguments>):Void {
        final foldingController = FoldingController.get(editor);
        if (foldingController == null || !foldingController.isEnabled()) {
            return;
        }
        foldingController.getFoldingModel(foldingModel -> {
            if (foldingModel != null) {
                invoke(foldingController, foldingModel, editor, args, context);
                final selection = editor.getSelection();
                if (selection != null) {
                    foldingController.reveal(selection.getStartPosition());
                }
            }
        });
    }

    function getSelectedLines(editor:IFoldingEditor):Array<Int> {
        final selections = editor.getSelections();
        return selections != null ? [for (s in selections) s.startLineNumber] : [];
    }

    function getLineNumbers(args:Null<FoldingArguments>, editor:IFoldingEditor):Array<Int> {
        if (args != null && args.selectionLines != null) {
            return [for (l in args.selectionLines) l + 1]; // to 0-bases line numbers
        }
        return getSelectedLines(editor);
    }

    /**
     * The argument constraint of `editor.fold` and `editor.unfold`.
     */
    public static function foldingArgumentsConstraint(args:Any):Bool {
        if (args != null) {
            if (!JsValues.isObject(args)) {
                return false;
            }
            final levels = JsValues.field(args, 'levels');
            if (levels != null && !JsValues.isNumber(levels)) {
                return false;
            }
            final direction = JsValues.field(args, 'direction');
            if (direction != null && !JsValues.isString(direction)) {
                return false;
            }
            final selectionLines = JsValues.field(args, 'selectionLines');
            if (selectionLines != null) {
                if (!JsValues.isArray(selectionLines)) {
                    return false;
                }
                final lines:Array<Any> = cast selectionLines;
                for (l in lines) {
                    if (!JsValues.isNumber(l)) {
                        return false;
                    }
                }
            }
        }
        return true;
    }

}

private class K {
    public static inline function k(key:String, ctrlCmd:Bool = false, shift:Bool = false, alt:Bool = false):FoldingKeybindingPart {
        return new FoldingKeybindingPart(key, ctrlCmd, shift, alt);
    }
    /**
     * `KeyChord(KeyMod.CtrlCmd | KeyCode.KeyK, second)`.
     */
    public static inline function chordK(second:FoldingKeybindingPart):FoldingKeybinding {
        return new FoldingKeybinding(new FoldingKeybindingPart('k', true), second);
    }
}

class UnfoldAction extends FoldingAction {

    public function new() {
        super('editor.unfold', 'Unfold', 'Unfold',
            new FoldingKeybinding(K.k(']', true, true)),
            new FoldingKeybinding(K.k(']', true, false, true)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, args:Null<FoldingArguments>, context:Cityscape):Void {
        final argLevels:Null<Int> = args != null ? args.levels : null;
        final levels = (argLevels != null && argLevels != 0) ? argLevels : 1;
        final lineNumbers = getLineNumbers(args, editor);
        if (args != null && args.direction == 'up') {
            FoldingModelUtils.setCollapseStateLevelsUp(foldingModel, false, levels, lineNumbers);
        }
        else {
            FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, false, levels, lineNumbers);
        }
    }
}

class UnFoldRecursivelyAction extends FoldingAction {

    public function new() {
        super('editor.unfoldRecursively', 'Unfold Recursively', 'Unfold Recursively',
            K.chordK(K.k(']', true)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, false, FoldingModelUtils.MAX_LEVELS, getSelectedLines(editor));
    }
}

class FoldAction extends FoldingAction {

    public function new() {
        super('editor.fold', 'Fold', 'Fold',
            new FoldingKeybinding(K.k('[', true, true)),
            new FoldingKeybinding(K.k('[', true, false, true)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, args:Null<FoldingArguments>, context:Cityscape):Void {
        final lineNumbers = getLineNumbers(args, editor);

        final levels:Null<Int> = args != null ? args.levels : null;
        final direction:Null<String> = args != null ? args.direction : null;

        if (levels == null && direction == null) {
            // fold the region at the location or if already collapsed, the first uncollapsed parent instead.
            FoldingModelUtils.setCollapseStateUp(foldingModel, true, lineNumbers);
        }
        else {
            final l = (levels != null && levels != 0) ? levels : 1;
            if (direction == 'up') {
                FoldingModelUtils.setCollapseStateLevelsUp(foldingModel, true, l, lineNumbers);
            }
            else {
                FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, true, l, lineNumbers);
            }
        }
    }
}

class ToggleFoldAction extends FoldingAction {

    public function new() {
        super('editor.toggleFold', 'Toggle Fold', 'Toggle Fold',
            K.chordK(K.k('l', true)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        final selectedLines = getSelectedLines(editor);
        FoldingModelUtils.toggleCollapseState(foldingModel, 1, selectedLines);
    }
}

class FoldRecursivelyAction extends FoldingAction {

    public function new() {
        super('editor.foldRecursively', 'Fold Recursively', 'Fold Recursively',
            K.chordK(K.k('[', true)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        final selectedLines = getSelectedLines(editor);
        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, true, FoldingModelUtils.MAX_LEVELS, selectedLines);
    }
}

class ToggleFoldRecursivelyAction extends FoldingAction {

    public function new() {
        super('editor.toggleFoldRecursively', 'Toggle Fold Recursively', 'Toggle Fold Recursively',
            K.chordK(K.k('l', true, true)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        final selectedLines = getSelectedLines(editor);
        FoldingModelUtils.toggleCollapseState(foldingModel, FoldingModelUtils.MAX_LEVELS, selectedLines);
    }
}

class FoldAllBlockCommentsAction extends FoldingAction {

    public function new() {
        super('editor.foldAllBlockComments', 'Fold All Block Comments', 'Fold All Block Comments',
            K.chordK(K.k('/', true)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        if (foldingModel.regions.hasTypes()) {
            FoldingModelUtils.setCollapseStateForType(foldingModel, FoldingRangeKind.Comment.value, true);
        }
        else {
            final editorModel = editor.getModel();
            if (editorModel == null) {
                return;
            }
            final comments = context.languageConfigurationService.getLanguageConfiguration(editorModel.getLanguageId()).comments;
            if (comments != null && comments.blockCommentStartToken != null && comments.blockCommentStartToken.length > 0) {
                final regExp = new RegExp('^\\s*' + Strings.escapeRegExpCharacters(comments.blockCommentStartToken));
                FoldingModelUtils.setCollapseStateForMatchingLines(foldingModel, regExp, true);
            }
        }
    }
}

class FoldAllRegionsAction extends FoldingAction {

    public function new() {
        super('editor.foldAllMarkerRegions', 'Fold All Regions', 'Fold All Regions',
            K.chordK(K.k('8', true)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        if (foldingModel.regions.hasTypes()) {
            FoldingModelUtils.setCollapseStateForType(foldingModel, FoldingRangeKind.Region.value, true);
        }
        else {
            final editorModel = editor.getModel();
            if (editorModel == null) {
                return;
            }
            final foldingRules = context.languageConfigurationService.getLanguageConfiguration(editorModel.getLanguageId()).foldingRules;
            if (foldingRules != null && foldingRules.markers != null && foldingRules.markers.start != null) {
                // `new RegExp(markers.start)` copies the regular expression
                final regExp = new RegExp(foldingRules.markers.start.source, foldingRules.markers.start.flags);
                FoldingModelUtils.setCollapseStateForMatchingLines(foldingModel, regExp, true);
            }
        }
    }
}

class UnfoldAllRegionsAction extends FoldingAction {

    public function new() {
        super('editor.unfoldAllMarkerRegions', 'Unfold All Regions', 'Unfold All Regions',
            K.chordK(K.k('9', true)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        if (foldingModel.regions.hasTypes()) {
            FoldingModelUtils.setCollapseStateForType(foldingModel, FoldingRangeKind.Region.value, false);
        }
        else {
            final editorModel = editor.getModel();
            if (editorModel == null) {
                return;
            }
            final foldingRules = context.languageConfigurationService.getLanguageConfiguration(editorModel.getLanguageId()).foldingRules;
            if (foldingRules != null && foldingRules.markers != null && foldingRules.markers.start != null) {
                final regExp = new RegExp(foldingRules.markers.start.source, foldingRules.markers.start.flags);
                FoldingModelUtils.setCollapseStateForMatchingLines(foldingModel, regExp, false);
            }
        }
    }
}

class FoldAllExceptAction extends FoldingAction {

    public function new() {
        super('editor.foldAllExcept', 'Fold All Except Selected', 'Fold All Except Selected',
            K.chordK(K.k('-', true)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        final selectedLines = getSelectedLines(editor);
        FoldingModelUtils.setCollapseStateForRest(foldingModel, true, selectedLines);
    }
}

class UnfoldAllExceptAction extends FoldingAction {

    public function new() {
        super('editor.unfoldAllExcept', 'Unfold All Except Selected', 'Unfold All Except Selected',
            K.chordK(K.k('=', true)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        final selectedLines = getSelectedLines(editor);
        FoldingModelUtils.setCollapseStateForRest(foldingModel, false, selectedLines);
    }
}

class FoldAllAction extends FoldingAction {

    public function new() {
        super('editor.foldAll', 'Fold All', 'Fold All',
            K.chordK(K.k('0', true)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, _editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, true);
    }
}

class UnfoldAllAction extends FoldingAction {

    public function new() {
        super('editor.unfoldAll', 'Unfold All', 'Unfold All',
            K.chordK(K.k('j', true)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, _editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        FoldingModelUtils.setCollapseStateLevelsDown(foldingModel, false);
    }
}

class FoldLevelAction extends FoldingAction {

    static inline final ID_PREFIX = 'editor.foldLevel';

    public static function ID(level:Int):String {
        return ID_PREFIX + level;
    }

    public function new(level:Int) {
        super(ID(level), 'Fold Level ' + level, 'Fold Level ' + level,
            K.chordK(K.k('' + level, true)));
    }

    function getFoldingLevel():Int {
        return Std.int(JsValues.parseInt(id.substr(ID_PREFIX.length)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        FoldingModelUtils.setCollapseStateAtLevel(foldingModel, getFoldingLevel(), true, getSelectedLines(editor));
    }
}

/** Action to go to the parent fold of current line */
class GotoParentFoldAction extends FoldingAction {
    public function new() {
        super('editor.gotoParentFold', 'Go to Parent Fold', 'Go to Parent Fold', null);
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        final selectedLines = getSelectedLines(editor);
        if (selectedLines.length > 0) {
            final startLineNumber = FoldingModelUtils.getParentFoldLine(selectedLines[0], foldingModel);
            if (startLineNumber != null) {
                editor.setSelection(new Selection(startLineNumber, 1, startLineNumber, 1));
            }
        }
    }
}

/** Action to go to the previous fold of current line */
class GotoPreviousFoldAction extends FoldingAction {
    public function new() {
        super('editor.gotoPreviousFold', 'Go to Previous Folding Range', 'Go to Previous Folding Range', null);
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        final selectedLines = getSelectedLines(editor);
        if (selectedLines.length > 0) {
            final startLineNumber = FoldingModelUtils.getPreviousFoldLine(selectedLines[0], foldingModel);
            if (startLineNumber != null) {
                editor.setSelection(new Selection(startLineNumber, 1, startLineNumber, 1));
            }
        }
    }
}

/** Action to go to the next fold of current line */
class GotoNextFoldAction extends FoldingAction {
    public function new() {
        super('editor.gotoNextFold', 'Go to Next Folding Range', 'Go to Next Folding Range', null);
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        final selectedLines = getSelectedLines(editor);
        if (selectedLines.length > 0) {
            final startLineNumber = FoldingModelUtils.getNextFoldLine(selectedLines[0], foldingModel);
            if (startLineNumber != null) {
                editor.setSelection(new Selection(startLineNumber, 1, startLineNumber, 1));
            }
        }
    }
}

class FoldRangeFromSelectionAction extends FoldingAction {

    public function new() {
        super('editor.createFoldingRangeFromSelection', 'Create Folding Range from Selection', 'Create Folding Range from Selection',
            K.chordK(K.k(',', true)));
    }

    public function invoke(_foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        final collapseRanges:Array<FoldRange> = [];
        final selections = editor.getSelections();
        if (selections != null) {
            for (selection in selections) {
                var endLineNumber = selection.endLineNumber;
                if (selection.endColumn == 1) {
                    --endLineNumber;
                }
                if (endLineNumber > selection.startLineNumber) {
                    collapseRanges.push(new FoldRange(
                        selection.startLineNumber,
                        endLineNumber,
                        null,
                        true,
                        FoldSource.userDefined
                    ));
                    editor.setSelection(new Selection(selection.startLineNumber, 1, selection.startLineNumber, 1));
                }
            }
            if (collapseRanges.length > 0) {
                haxe.ds.ArraySort.sort(collapseRanges, (a, b) -> {
                    return a.startLineNumber - b.startLineNumber;
                });
                final model = editor.getModel();
                final newRanges = FoldingRegions.sanitizeAndMerge(foldingModel.regions, collapseRanges, model != null ? model.getLineCount() : null);
                foldingModel.updatePost(FoldingRegions.fromFoldRanges(newRanges));
            }
        }
    }
}

class RemoveFoldRangeFromSelectionAction extends FoldingAction {

    public function new() {
        super('editor.removeManualFoldingRanges', 'Remove Manual Folding Ranges', 'Remove Manual Folding Ranges',
            K.chordK(K.k('.', true)));
    }

    public function invoke(foldingController:FoldingController, foldingModel:FoldingModel, editor:IFoldingEditor, _args:Null<FoldingArguments>, context:Cityscape):Void {
        final selections = editor.getSelections();
        if (selections != null) {
            final ranges:Array<ILineRange> = [];
            for (selection in selections) {
                final startLineNumber = selection.startLineNumber;
                final endLineNumber = selection.endLineNumber;
                ranges.push(endLineNumber >= startLineNumber ? {startLineNumber: startLineNumber, endLineNumber: endLineNumber} : {endLineNumber: endLineNumber, startLineNumber: startLineNumber});
            }
            foldingModel.removeManualRanges(ranges);
            foldingController.triggerFoldingModelChanged();
        }
    }
}

/**
 * The folding actions by Monaco command id, and their default keybindings.
 *
 * TODO(step 3, commands and keybindings): a local adapter until the
 * command and keybinding registry of the editor lands; then the actions
 * are registered there (`registerEditorAction`) with these ids and keys.
 */
class FoldingCommands {

    static var _all:Null<Array<FoldingAction>> = null;

    /**
     * Every folding action (immutable, shared by all the editors), in
     * Monaco's registration order.
     */
    public static function all():Array<FoldingAction> {
        if (_all == null) {
            final actions:Array<FoldingAction> = [
                new UnfoldAction(),
                new UnFoldRecursivelyAction(),
                new FoldAction(),
                new FoldRecursivelyAction(),
                new ToggleFoldRecursivelyAction(),
                new FoldAllAction(),
                new UnfoldAllAction(),
                new FoldAllBlockCommentsAction(),
                new FoldAllRegionsAction(),
                new UnfoldAllRegionsAction(),
                new FoldAllExceptAction(),
                new UnfoldAllExceptAction(),
                new ToggleFoldAction(),
                new GotoParentFoldAction(),
                new GotoPreviousFoldAction(),
                new GotoNextFoldAction(),
                new FoldRangeFromSelectionAction(),
                new RemoveFoldRangeFromSelectionAction(),
            ];
            for (i in 1...8) {
                actions.push(new FoldLevelAction(i));
            }
            _all = actions;
        }
        return _all;
    }

    public static function get(id:String):Null<FoldingAction> {
        for (action in all()) {
            if (action.id == id) {
                return action;
            }
        }
        return null;
    }

    /**
     * Runs a folding command by id. Returns false when there is no such
     * command or its arguments are invalid.
     */
    public static function run(editor:IFoldingEditor, id:String, ?args:FoldingArguments):Bool {
        final action = get(id);
        if (action == null) {
            return false;
        }
        if ((id == 'editor.fold' || id == 'editor.unfold') && !FoldingAction.foldingArgumentsConstraint(args)) {
            return false;
        }
        action.runEditorCommand(editor.getFoldingContext(), editor, args);
        return true;
    }

}

/**
 * The keys of the folding actions for one editor (the second key of a
 * chord is waited for here).
 *
 * TODO(step 3, commands and keybindings): replaced by the keybinding
 * service of the editor.
 */
class FoldingKeybindings {

    var pendingChord:Null<FoldingKeybindingPart> = null;

    public function new() {}

    /**
     * Handles a key down of the editor (with text focus). Returns true when
     * the key was used: a folding action ran, or a chord started or ended.
     */
    public function handleKeyDown(editor:IFoldingEditor, keystroke:glaze.Keystroke):Bool {
        final isMac = cityscape.base.common.Platform.isMacintosh;
        final controller = FoldingController.get(editor);
        final enabled = controller != null && controller.isEnabled();
        final chord = pendingChord;
        if (chord != null) {
            pendingChord = null;
            if (enabled) {
                for (action in FoldingCommands.all()) {
                    final kb = action.keybinding(isMac);
                    if (kb != null && kb.second != null && sameParts(kb.first, chord) && kb.second.matches(keystroke, isMac)) {
                        action.runEditorCommand(editor.getFoldingContext(), editor, null);
                        return true;
                    }
                }
            }
            // Monaco: the chord did not match a command, the key is used
            return true;
        }
        if (!enabled) {
            return false;
        }
        for (action in FoldingCommands.all()) {
            final kb = action.keybinding(isMac);
            if (kb != null && kb.second == null && kb.first.matches(keystroke, isMac)) {
                action.runEditorCommand(editor.getFoldingContext(), editor, null);
                return true;
            }
        }
        for (action in FoldingCommands.all()) {
            final kb = action.keybinding(isMac);
            if (kb != null && kb.second != null && kb.first.matches(keystroke, isMac)) {
                pendingChord = kb.first;
                return true;
            }
        }
        return false;
    }

    static function sameParts(a:FoldingKeybindingPart, b:FoldingKeybindingPart):Bool {
        return a.key == b.key && a.ctrlCmd == b.ctrlCmd && a.shift == b.shift && a.alt == b.alt && a.winCtrl == b.winCtrl;
    }

}
