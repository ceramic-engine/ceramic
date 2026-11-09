// Ported from vscode src/vs/editor/browser/widget/diffEditor/diffEditorViewModel.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.widget.diffEditor;

import cityscape.base.common.Arrays;
import cityscape.base.common.Assert;
import cityscape.base.common.Async.RunOnceScheduler;
import cityscape.base.common.Cancellation.CancellationTokenSource;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.Model;
import cityscape.common.core.LineRange;
import cityscape.common.diff.DocumentDiffProvider;
import cityscape.common.diff.LinesDiffComputer.MovedText;
import cityscape.common.diff.RangeMapping.DetailedLineRangeMapping;
import cityscape.common.diff.RangeMapping.LineRangeMapping;
import cityscape.common.diff.RangeMapping.RangeMapping;
import cityscape.view.widget.diffEditor.DiffProviderFactoryService;

/**
 * The two models of a diff editor (Monaco's `IDiffEditorModel`).
 */
typedef IDiffEditorModel = {
    /**
     * Original model.
     */
    final original:ITextModel;
    /**
     * Modified model.
     */
    final modified:ITextModel;
}

/**
 * The view model of a diff editor: the diff of its two models, computed
 * again after edits (with Monaco's 200 ms debounce) and when the options
 * change, and the unchanged regions that can be hidden.
 *
 * Monaco's observables are fields here, with events: `onDidChangeDiff`
 * (the diff or `isDiffUpToDate` changed) and `onDidChangeUnchangedRegions`
 * (the regions or what they show changed).
 */
class DiffEditorViewModel implements IDisposable {

    public final model:IDiffEditorModel;
    final _options:DiffEditorOptions;
    final _store = new DisposableStore();

    var _isDiffUpToDate:Bool = false;

    /**
     * Whether the diff is the one of the current text of the models.
     */
    public var isDiffUpToDate(get, never):Bool;
    inline function get_isDiffUpToDate():Bool return _isDiffUpToDate;

    var _lastDiff:Null<IDocumentDiff> = null;
    var _diff:Null<DiffState> = null;

    /**
     * The diff (null before the first computation).
     */
    public var diff(get, never):Null<DiffState>;
    inline function get_diff():Null<DiffState> return _diff;

    final _onDidChangeDiff = new VoidEmitter();
    public var onDidChangeDiff(get, never):VoidEvent;
    inline function get_onDidChangeDiff() return _onDidChangeDiff.event;

    final _onDidChangeUnchangedRegions = new VoidEmitter();
    public var onDidChangeUnchangedRegions(get, never):VoidEvent;
    inline function get_onDidChangeUnchangedRegions() return _onDidChangeUnchangedRegions.event;

    var _unchangedRegions:Null<{regions:Array<UnchangedRegion>, originalDecorationIds:Array<String>, modifiedDecorationIds:Array<String>}> = null;

    /**
     * The unchanged regions (empty unless `hideUnchangedRegions` is
     * enabled; disabling it collapses them all, like Monaco's derived value).
     */
    public var unchangedRegions(get, never):Array<UnchangedRegion>;
    function get_unchangedRegions():Array<UnchangedRegion> {
        if (this._options.hideUnchangedRegions) {
            return this._unchangedRegions != null ? this._unchangedRegions.regions : [];
        }
        else {
            // Reset state
            if (this._unchangedRegions != null) {
                _notifying = true;
                for (r in this._unchangedRegions.regions) {
                    r.collapseAll();
                }
                _notifying = false;
            }
            return [];
        }
    }

    public var movedTextToCompare:Null<MovedText> = null;

    var _activeMovedText:Null<MovedText> = null;
    var _hoveredMovedText:Null<MovedText> = null;

    public var activeMovedText(get, never):Null<MovedText>;
    function get_activeMovedText():Null<MovedText> {
        return this.movedTextToCompare != null ? this.movedTextToCompare : (this._hoveredMovedText != null ? this._hoveredMovedText : this._activeMovedText);
    }

    public function setActiveMovedText(movedText:Null<MovedText>):Void {
        this._activeMovedText = movedText;
        _onDidChangeDiff.fire();
    }

    public function setHoveredMovedText(movedText:Null<MovedText>):Void {
        this._hoveredMovedText = movedText;
        _onDidChangeDiff.fire();
    }

    final _cancellationTokenSource = new CancellationTokenSource();

    final _diffProvider:WorkerBasedDocumentDiffProvider;

    final debouncer:RunOnceScheduler;

    /**
     * Incremented by each computation: only the result of the last one is
     * applied (Monaco's worker answers in order).
     */
    var _computationId:Int = 0;

    var _disposed:Bool = false;

    var _notifying:Bool = false;

    /**
     * The options read by the last computation (the computation runs again
     * when one of them changes).
     */
    var _computedOptionsKey:String = '';

    public function new(model:IDiffEditorModel, options:DiffEditorOptions, ?mode:DiffComputationMode) {
        this.model = model;
        this._options = options;
        this._diffProvider = new WorkerBasedDocumentDiffProvider(options.diffAlgorithm, mode);

        this._store.add(Lifecycle.toDisposable(() -> this._cancellationTokenSource.cancel()));

        this.debouncer = new RunOnceScheduler(() -> this._computeDiff(), 200);
        this._store.add(this.debouncer);

        this._store.add(model.modified.onDidChangeContent((e) -> {
            this._isDiffUpToDate = false;
            debouncer.schedule();
            _onDidChangeDiff.fire();
        }));
        this._store.add(model.original.onDidChangeContent((e) -> {
            this._isDiffUpToDate = false;
            debouncer.schedule();
            _onDidChangeDiff.fire();
        }));

        this._store.add(this._diffProvider.onDidChange(() -> this._computeDiff()));

        this._store.add(options.onDidChange(() -> {
            this._diffProvider.setOptions(options.diffAlgorithm);
            if (this._optionsKey() != this._computedOptionsKey) {
                this._computeDiff();
            }
        }));

        this._computeDiff();
    }

    /**
     * Where the diff is computed (see `DiffComputationMode`).
     */
    public function setComputationMode(mode:DiffComputationMode):Void {
        this._diffProvider.mode = mode;
    }

    function _optionsKey():String {
        return this._options.hideUnchangedRegionsMinimumLineCount + '|' + this._options.hideUnchangedRegionsContextLineCount + '|'
            + this._options.ignoreTrimWhitespace + '|' + this._options.maxComputationTimeMs + '|' + this._options.showMoves + '|' + this._options.diffAlgorithm;
    }

    /**
     * Monaco's "compute diff" autorun.
     */
    function _computeDiff():Void {
        if (_disposed) {
            return;
        }
        debouncer.cancel();

        this._computedOptionsKey = this._optionsKey();
        this._isDiffUpToDate = false;

        final id = ++this._computationId;
        final options:IDocumentDiffProviderOptions = {
            ignoreTrimWhitespace: this._options.ignoreTrimWhitespace,
            maxComputationTimeMs: this._options.maxComputationTimeMs,
            computeMoves: this._options.showMoves,
        };
        this._diffProvider.computeDiff(model.original, model.modified, options, this._cancellationTokenSource.token, (result) -> {
            if (this._cancellationTokenSource.token.isCancellationRequested || _disposed) {
                return;
            }
            if (id != this._computationId) {
                // A newer computation was started
                return;
            }
            if (model.original.isDisposed() || model.modified.isDisposed()) {
                // TODO@hediet fishy?
                return;
            }
            result = normalizeDocumentDiff(result, model.original, model.modified);
            // Monaco's `applyOriginalEdits` and `applyModifiedEdits` return
            // undefined (TODO@hediet): the result is kept as it is

            /** @description write diff result */
            this._updateUnchangedRegions(result);

            this._lastDiff = result;
            final state = DiffState.fromDiffResult(result);
            this._diff = state;
            this._isDiffUpToDate = true;
            final currentSyncedMovedText = this.movedTextToCompare;
            this.movedTextToCompare = currentSyncedMovedText != null ? findMove(this._lastDiff.moves, currentSyncedMovedText) : null;
            _onDidChangeDiff.fire();
            _onDidChangeUnchangedRegions.fire();
        });
    }

    static function findMove(moves:Array<MovedText>, current:MovedText):Null<MovedText> {
        for (m in moves) {
            if (m.lineRangeMapping.modified.intersect(current.lineRangeMapping.modified) != null) {
                return m;
            }
        }
        return null;
    }

    /**
     * Computes the diff now, on this thread, when a computation is pending
     * or running (tests; Monaco's tests wait for the worker).
     */
    public function _flushPendingDiff():Void {
        if (this._isDiffUpToDate && !this.debouncer.isScheduled()) {
            return;
        }
        final mode = this._diffProvider.mode;
        this._diffProvider.mode = DiffComputationMode.Synchronous;
        this._computeDiff();
        this._diffProvider.mode = mode;
    }

    /**
     * Calls `callback` once the diff is up to date (Monaco's `waitForDiff`
     * promise).
     */
    public function waitForDiff(callback:() -> Void):Void {
        if (this._isDiffUpToDate) {
            callback();
            return;
        }
        var listener:Null<IDisposable> = null;
        listener = this.onDidChangeDiff(() -> {
            if (this._isDiffUpToDate) {
                if (listener != null) {
                    listener.dispose();
                    listener = null;
                }
                callback();
            }
        });
    }

    function _decorationRanges(textModel:ITextModel, ids:Array<String>):Array<Null<LineRange>> {
        return ids.map(id -> {
            final r = textModel.getDecorationRange(id);
            return r != null ? LineRange.fromRangeInclusive(r) : null;
        });
    }

    function _updateUnchangedRegions(result:IDocumentDiff):Void {
        final model = this.model;
        final newUnchangedRegions = UnchangedRegion.fromDiffs(
            result.changes,
            model.original.getLineCount(),
            model.modified.getLineCount(),
            this._options.hideUnchangedRegionsMinimumLineCount,
            this._options.hideUnchangedRegionsContextLineCount
        );

        // Transfer state from cur state
        var visibleRegions:Null<Array<LineRangeMapping>> = null;

        final lastUnchangedRegions = this._unchangedRegions;
        if (lastUnchangedRegions != null) {
            final lastUnchangedRegionsOrigRanges = _decorationRanges(model.original, lastUnchangedRegions.originalDecorationIds);
            final lastUnchangedRegionsModRanges = _decorationRanges(model.modified, lastUnchangedRegions.modifiedDecorationIds);
            final mapped:Array<UnchangedRegion> = [];
            for (idx in 0...lastUnchangedRegions.regions.length) {
                final r = lastUnchangedRegions.regions[idx];
                final orig = lastUnchangedRegionsOrigRanges[idx];
                final mod = lastUnchangedRegionsModRanges[idx];
                if (orig == null || mod == null) {
                    continue;
                }
                final length = orig.length;
                mapped.push(new UnchangedRegion(
                    orig.startLineNumber,
                    mod.startLineNumber,
                    length,
                    // The visible area can shrink by edits -> we have to account for this
                    Std.int(Math.min(r.visibleLineCountTop, length)),
                    Std.int(Math.min(r.visibleLineCountBottom, length - r.visibleLineCountTop))
                ));
            }
            final updatedLastUnchangedRegions = DiffEditorUtils.filterWithPrevious(
                mapped,
                (cur, prev) -> prev == null || (cur.modifiedLineNumber >= prev.modifiedLineNumber + prev.lineCount && cur.originalLineNumber >= prev.originalLineNumber + prev.lineCount)
            );

            var hiddenRegions = updatedLastUnchangedRegions.map(r -> new LineRangeMapping(r.getHiddenOriginalRange(), r.getHiddenModifiedRange()));
            hiddenRegions = LineRangeMapping.clip(hiddenRegions, LineRange.ofLength(1, model.original.getLineCount()), LineRange.ofLength(1, model.modified.getLineCount()));
            visibleRegions = LineRangeMapping.inverse(hiddenRegions, model.original.getLineCount(), model.modified.getLineCount());
        }

        final newUnchangedRegions2:Array<UnchangedRegion> = [];
        if (visibleRegions != null) {
            for (r in newUnchangedRegions) {
                final intersecting = visibleRegions.filter(f -> f.original.intersectsStrict(r.originalUnchangedRange) && f.modified.intersectsStrict(r.modifiedUnchangedRange));
                Arrays.pushMany(newUnchangedRegions2, r.setVisibleRanges(intersecting));
            }
        }
        else {
            Arrays.pushMany(newUnchangedRegions2, newUnchangedRegions);
        }

        final originalDecorationIds = model.original.deltaDecorations(
            lastUnchangedRegions != null ? lastUnchangedRegions.originalDecorationIds : [],
            newUnchangedRegions2.map(r -> ({range: r.originalUnchangedRange.toInclusiveRange(), options: {description: 'unchanged'}} : IModelDeltaDecoration))
        );
        final modifiedDecorationIds = model.modified.deltaDecorations(
            lastUnchangedRegions != null ? lastUnchangedRegions.modifiedDecorationIds : [],
            newUnchangedRegions2.map(r -> ({range: r.modifiedUnchangedRange.toInclusiveRange(), options: {description: 'unchanged'}} : IModelDeltaDecoration))
        );

        this._setUnchangedRegions({
            regions: newUnchangedRegions2,
            originalDecorationIds: originalDecorationIds,
            modifiedDecorationIds: modifiedDecorationIds
        });
    }

    function _setUnchangedRegions(value:{regions:Array<UnchangedRegion>, originalDecorationIds:Array<String>, modifiedDecorationIds:Array<String>}):Void {
        if (this._unchangedRegions != null) {
            for (r in this._unchangedRegions.regions) {
                r.onDidChange = null;
            }
        }
        this._unchangedRegions = value;
        for (r in value.regions) {
            r.onDidChange = this._onRegionChanged;
        }
        this._collapseTouchingUnchangedRanges();
    }

    function _onRegionChanged():Void {
        if (_notifying) {
            return;
        }
        this._collapseTouchingUnchangedRanges();
        _onDidChangeUnchangedRegions.fire();
    }

    /**
     * Monaco's "collapse touching unchanged ranges" autorun.
     */
    function _collapseTouchingUnchangedRanges():Void {
        final lastUnchangedRegions = this._unchangedRegions;
        if (lastUnchangedRegions == null) {
            return;
        }
        for (r in lastUnchangedRegions.regions) {
            if (r.isDragged != null) {
                return;
            }
        }

        final model = this.model;
        final lastUnchangedRegionsOrigRanges = _decorationRanges(model.original, lastUnchangedRegions.originalDecorationIds);
        final lastUnchangedRegionsModRanges = _decorationRanges(model.modified, lastUnchangedRegions.modifiedDecorationIds);
        final updatedLastUnchangedRegions:Array<UnchangedRegion> = [];
        for (idx in 0...lastUnchangedRegions.regions.length) {
            final r = lastUnchangedRegions.regions[idx];
            final orig = lastUnchangedRegionsOrigRanges[idx];
            final mod = lastUnchangedRegionsModRanges[idx];
            if (orig == null || mod == null) {
                continue;
            }
            updatedLastUnchangedRegions.push(new UnchangedRegion(
                orig.startLineNumber,
                mod.startLineNumber,
                orig.length,
                r.visibleLineCountTop,
                r.visibleLineCountBottom
            ));
        }

        final newRanges:Array<UnchangedRegion> = [];

        var didChange = false;
        for (touching in Arrays.groupAdjacentBy(updatedLastUnchangedRegions, (a, b) -> a.getHiddenModifiedRange().endLineNumberExclusive == b.getHiddenModifiedRange().startLineNumber)) {
            if (touching.length > 1) {
                didChange = true;
                var sumLineCount = 0;
                for (r in touching) {
                    sumLineCount += r.lineCount;
                }
                final r = new UnchangedRegion(touching[0].originalLineNumber, touching[0].modifiedLineNumber, sumLineCount, touching[0].visibleLineCountTop, touching[touching.length - 1].visibleLineCountBottom);
                newRanges.push(r);
            }
            else {
                newRanges.push(touching[0]);
            }
        }

        if (didChange) {
            final originalDecorationIds = model.original.deltaDecorations(
                lastUnchangedRegions.originalDecorationIds,
                newRanges.map(r -> ({range: r.originalUnchangedRange.toInclusiveRange(), options: {description: 'unchanged'}} : IModelDeltaDecoration))
            );
            final modifiedDecorationIds = model.modified.deltaDecorations(
                lastUnchangedRegions.modifiedDecorationIds,
                newRanges.map(r -> ({range: r.modifiedUnchangedRange.toInclusiveRange(), options: {description: 'unchanged'}} : IModelDeltaDecoration))
            );

            this._setUnchangedRegions({
                regions: newRanges,
                originalDecorationIds: originalDecorationIds,
                modifiedDecorationIds: modifiedDecorationIds
            });
        }
    }

    public function ensureModifiedLineIsVisible(lineNumber:Int, preference:RevealPreference):Void {
        final diff = this._diff;
        if (diff != null && diff.mappings.length == 0) {
            return;
        }
        final unchangedRegions = this._unchangedRegions != null ? this._unchangedRegions.regions : [];
        for (r in unchangedRegions) {
            if (r.getHiddenModifiedRange().contains(lineNumber)) {
                r.showModifiedLine(lineNumber, preference);
                return;
            }
        }
    }

    public function ensureOriginalLineIsVisible(lineNumber:Int, preference:RevealPreference):Void {
        final diff = this._diff;
        if (diff != null && diff.mappings.length == 0) {
            return;
        }
        final unchangedRegions = this._unchangedRegions != null ? this._unchangedRegions.regions : [];
        for (r in unchangedRegions) {
            if (r.getHiddenOriginalRange().contains(lineNumber)) {
                r.showOriginalLine(lineNumber, preference);
                return;
            }
        }
    }

    /**
     * The hidden modified ranges of the unchanged regions (Monaco's
     * `SerializedState`, the ranges as `[start, endExclusive]`).
     */
    public function serializeState():{collapsedRegions:Null<Array<{range:Array<Int>}>>} {
        final regions = this._unchangedRegions;
        return {
            collapsedRegions: regions != null ? regions.regions.map(r -> {
                final range = r.getHiddenModifiedRange();
                return {range: [range.startLineNumber, range.endLineNumberExclusive]};
            }) : null
        };
    }

    public function restoreSerializedState(state:{collapsedRegions:Null<Array<{range:Array<Int>}>>}):Void {
        final ranges = state.collapsedRegions != null ? state.collapsedRegions.map(r -> new LineRange(r.range[0], r.range[1])) : null;
        final regions = this._unchangedRegions;
        if (regions == null || ranges == null) {
            return;
        }
        for (r in regions.regions) {
            for (range in ranges) {
                if (r.modifiedUnchangedRange.intersect(range) != null) {
                    r.setHiddenModifiedRange(range);
                    break;
                }
            }
        }
    }

    public function dispose():Void {
        if (_disposed) {
            return;
        }
        _disposed = true;
        _store.dispose();
        _diffProvider.dispose();
        _onDidChangeDiff.dispose();
        _onDidChangeUnchangedRegions.dispose();
    }

    static function normalizeDocumentDiff(diff:IDocumentDiff, original:ITextModel, modified:ITextModel):IDocumentDiff {
        return new IDocumentDiff(
            diff.changes.map(c -> new DetailedLineRangeMapping(
                c.original,
                c.modified,
                c.innerChanges != null ? c.innerChanges.map(i -> normalizeRangeMapping(i, original, modified)) : null
            )),
            diff.identical,
            diff.quitEarly,
            diff.moves
        );
    }

    static function normalizeRangeMapping(rangeMapping:RangeMapping, original:ITextModel, modified:ITextModel):RangeMapping {
        var originalRange = rangeMapping.originalRange;
        var modifiedRange = rangeMapping.modifiedRange;
        if (
            originalRange.startColumn == 1 && modifiedRange.startColumn == 1 &&
            (originalRange.endColumn != 1 || modifiedRange.endColumn != 1) &&
            originalRange.endLineNumber <= original.getLineCount() && modifiedRange.endLineNumber <= modified.getLineCount() &&
            originalRange.endColumn == original.getLineMaxColumn(originalRange.endLineNumber)
            && modifiedRange.endColumn == modified.getLineMaxColumn(modifiedRange.endLineNumber)
            && originalRange.endLineNumber < original.getLineCount()
            && modifiedRange.endLineNumber < modified.getLineCount()
        ) {
            originalRange = originalRange.setEndPosition(originalRange.endLineNumber + 1, 1);
            modifiedRange = modifiedRange.setEndPosition(modifiedRange.endLineNumber + 1, 1);
        }
        return new RangeMapping(originalRange, modifiedRange);
    }

}

class DiffState {

    public static function fromDiffResult(result:IDocumentDiff):DiffState {
        return new DiffState(
            result.changes.map(c -> new DiffMapping(c)),
            result.moves != null ? result.moves : [],
            result.identical,
            result.quitEarly
        );
    }

    public final mappings:Array<DiffMapping>;
    public final movedTexts:Array<MovedText>;
    public final identical:Bool;
    public final quitEarly:Bool;

    public function new(mappings:Array<DiffMapping>, movedTexts:Array<MovedText>, identical:Bool, quitEarly:Bool) {
        this.mappings = mappings;
        this.movedTexts = movedTexts;
        this.identical = identical;
        this.quitEarly = quitEarly;
    }

}

class DiffMapping {

    public final lineRangeMapping:DetailedLineRangeMapping;

    public function new(lineRangeMapping:DetailedLineRangeMapping) {
        this.lineRangeMapping = lineRangeMapping;
    }

}

/**
 * A region of unchanged lines that can be hidden, with the number of its
 * lines shown at its top and at its bottom. Monaco's observables are
 * fields; a change calls `onDidChange` (set by the view model).
 */
class UnchangedRegion {

    public static function fromDiffs(
        changes:Array<DetailedLineRangeMapping>,
        originalLineCount:Int,
        modifiedLineCount:Int,
        minHiddenLineCount:Int,
        minContext:Int
    ):Array<UnchangedRegion> {
        final inversedMappings = LineRangeMapping.inverse(cast changes, originalLineCount, modifiedLineCount);
        final result:Array<UnchangedRegion> = [];

        for (mapping in inversedMappings) {
            var origStart = mapping.original.startLineNumber;
            var modStart = mapping.modified.startLineNumber;
            var length = mapping.original.length;

            final atStart = origStart == 1 && modStart == 1;
            final atEnd = origStart + length == originalLineCount + 1 && modStart + length == modifiedLineCount + 1;

            if ((atStart || atEnd) && length >= minContext + minHiddenLineCount) {
                if (atStart && !atEnd) {
                    length -= minContext;
                }
                if (atEnd && !atStart) {
                    origStart += minContext;
                    modStart += minContext;
                    length -= minContext;
                }
                result.push(new UnchangedRegion(origStart, modStart, length, 0, 0));
            }
            else if (length >= minContext * 2 + minHiddenLineCount) {
                origStart += minContext;
                modStart += minContext;
                length -= minContext * 2;
                result.push(new UnchangedRegion(origStart, modStart, length, 0, 0));
            }
        }

        return result;
    }

    public var originalUnchangedRange(get, never):LineRange;
    function get_originalUnchangedRange():LineRange {
        return LineRange.ofLength(this.originalLineNumber, this.lineCount);
    }

    public var modifiedUnchangedRange(get, never):LineRange;
    function get_modifiedUnchangedRange():LineRange {
        return LineRange.ofLength(this.modifiedLineNumber, this.lineCount);
    }

    var _visibleLineCountTop:Int = 0;
    var _visibleLineCountBottom:Int = 0;

    public var visibleLineCountTop(get, set):Int;
    inline function get_visibleLineCountTop():Int return _visibleLineCountTop;
    function set_visibleLineCountTop(value:Int):Int {
        if (value != _visibleLineCountTop) {
            _visibleLineCountTop = value;
            _changed();
        }
        return value;
    }

    public var visibleLineCountBottom(get, set):Int;
    inline function get_visibleLineCountBottom():Int return _visibleLineCountBottom;
    function set_visibleLineCountBottom(value:Int):Int {
        if (value != _visibleLineCountBottom) {
            _visibleLineCountBottom = value;
            _changed();
        }
        return value;
    }

    /**
     * `null`, `'bottom'` or `'top'`.
     */
    public var isDragged(default, set):Null<String> = null;
    function set_isDragged(value:Null<String>):Null<String> {
        if (value != isDragged) {
            isDragged = value;
            _changed();
        }
        return value;
    }

    /**
     * Called when what the region shows changes (the view model's listener).
     */
    public var onDidChange:Null<() -> Void> = null;

    public final originalLineNumber:Int;
    public final modifiedLineNumber:Int;
    public final lineCount:Int;

    public function new(originalLineNumber:Int, modifiedLineNumber:Int, lineCount:Int, visibleLineCountTop:Int, visibleLineCountBottom:Int) {
        this.originalLineNumber = originalLineNumber;
        this.modifiedLineNumber = modifiedLineNumber;
        this.lineCount = lineCount;
        final visibleLineCountTop2 = Std.int(Math.max(Math.min(visibleLineCountTop, this.lineCount), 0));
        final visibleLineCountBottom2 = Std.int(Math.max(Math.min(visibleLineCountBottom, this.lineCount - visibleLineCountTop), 0));

        Assert.softAssert(visibleLineCountTop == visibleLineCountTop2);
        Assert.softAssert(visibleLineCountBottom == visibleLineCountBottom2);

        this._visibleLineCountTop = visibleLineCountTop2;
        this._visibleLineCountBottom = visibleLineCountBottom2;
    }

    function _changed():Void {
        final f = onDidChange;
        if (f != null) {
            f();
        }
    }

    public function setVisibleRanges(visibleRanges:Array<LineRangeMapping>):Array<UnchangedRegion> {
        final result:Array<UnchangedRegion> = [];

        final hiddenModified = new LineRangeSet(visibleRanges.map(r -> r.modified)).subtractFrom(this.modifiedUnchangedRange);

        var originalStartLineNumber = this.originalLineNumber;
        var modifiedStartLineNumber = this.modifiedLineNumber;
        final modifiedEndLineNumberEx = this.modifiedLineNumber + this.lineCount;
        if (hiddenModified.ranges.length == 0) {
            this.showAll();
            result.push(this);
        }
        else {
            var i = 0;
            for (r in hiddenModified.ranges) {
                final isLast = i == hiddenModified.ranges.length - 1;
                i++;

                final length = (isLast ? modifiedEndLineNumberEx : r.endLineNumberExclusive) - modifiedStartLineNumber;

                final newR = new UnchangedRegion(originalStartLineNumber, modifiedStartLineNumber, length, 0, 0);
                newR.setHiddenModifiedRange(r);
                result.push(newR);

                originalStartLineNumber = newR.originalUnchangedRange.endLineNumberExclusive;
                modifiedStartLineNumber = newR.modifiedUnchangedRange.endLineNumberExclusive;
            }
        }

        return result;
    }

    public function shouldHideControls():Bool {
        return this._visibleLineCountTop + this._visibleLineCountBottom == this.lineCount && this.isDragged == null;
    }

    public function getHiddenOriginalRange():LineRange {
        return LineRange.ofLength(
            this.originalLineNumber + this._visibleLineCountTop,
            this.lineCount - this._visibleLineCountTop - this._visibleLineCountBottom
        );
    }

    public function getHiddenModifiedRange():LineRange {
        return LineRange.ofLength(
            this.modifiedLineNumber + this._visibleLineCountTop,
            this.lineCount - this._visibleLineCountTop - this._visibleLineCountBottom
        );
    }

    public function setHiddenModifiedRange(range:LineRange):Void {
        final visibleLineCountTop = range.startLineNumber - this.modifiedLineNumber;
        final visibleLineCountBottom = (this.modifiedLineNumber + this.lineCount) - range.endLineNumberExclusive;
        this.setState(visibleLineCountTop, visibleLineCountBottom);
    }

    public function getMaxVisibleLineCountTop():Int {
        return this.lineCount - this._visibleLineCountBottom;
    }

    public function getMaxVisibleLineCountBottom():Int {
        return this.lineCount - this._visibleLineCountTop;
    }

    public function showMoreAbove(count:Int = 10):Void {
        final maxVisibleLineCountTop = this.getMaxVisibleLineCountTop();
        this.visibleLineCountTop = Std.int(Math.min(this._visibleLineCountTop + count, maxVisibleLineCountTop));
    }

    public function showMoreBelow(count:Int = 10):Void {
        final maxVisibleLineCountBottom = this.lineCount - this._visibleLineCountTop;
        this.visibleLineCountBottom = Std.int(Math.min(this._visibleLineCountBottom + count, maxVisibleLineCountBottom));
    }

    public function showAll():Void {
        this.visibleLineCountBottom = this.lineCount - this._visibleLineCountTop;
    }

    public function showModifiedLine(lineNumber:Int, preference:RevealPreference):Void {
        final top = lineNumber + 1 - (this.modifiedLineNumber + this._visibleLineCountTop);
        final bottom = (this.modifiedLineNumber - this._visibleLineCountBottom + this.lineCount) - lineNumber;
        if (preference == RevealPreference.FromCloserSide && top < bottom || preference == RevealPreference.FromTop) {
            this.visibleLineCountTop = this._visibleLineCountTop + top;
        }
        else {
            this.visibleLineCountBottom = this._visibleLineCountBottom + bottom;
        }
    }

    public function showOriginalLine(lineNumber:Int, preference:RevealPreference):Void {
        final top = lineNumber - this.originalLineNumber;
        final bottom = (this.originalLineNumber + this.lineCount) - lineNumber;
        if (preference == RevealPreference.FromCloserSide && top < bottom || preference == RevealPreference.FromTop) {
            this.visibleLineCountTop = Std.int(Math.min(this._visibleLineCountTop + bottom - top, this.getMaxVisibleLineCountTop()));
        }
        else {
            this.visibleLineCountBottom = Std.int(Math.min(this._visibleLineCountBottom + top - bottom, this.getMaxVisibleLineCountBottom()));
        }
    }

    public function collapseAll():Void {
        this.visibleLineCountTop = 0;
        this.visibleLineCountBottom = 0;
    }

    public function setState(visibleLineCountTop:Int, visibleLineCountBottom:Int):Void {
        visibleLineCountTop = Std.int(Math.max(Math.min(visibleLineCountTop, this.lineCount), 0));
        visibleLineCountBottom = Std.int(Math.max(Math.min(visibleLineCountBottom, this.lineCount - visibleLineCountTop), 0));

        this.visibleLineCountTop = visibleLineCountTop;
        this.visibleLineCountBottom = visibleLineCountBottom;
    }

}

enum abstract RevealPreference(Int) from Int to Int {
    var FromCloserSide = 0;
    var FromTop = 1;
    var FromBottom = 2;
}
