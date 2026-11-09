// Ported from vscode src/vs/editor/browser/widget/diffEditor/components/diffEditorViewZones/diffEditorViewZones.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.widget.diffEditor;

import cityscape.base.common.Arrays;
import cityscape.base.common.Async.RunOnceScheduler;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.LineRange;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.diff.RangeMapping.DetailedLineRangeMapping;
import cityscape.view.EditorBrowser;
import cityscape.view.widget.codeEditor.CodeEditorWidget;
import cityscape.view.widget.diffEditor.DiffEditorViewModel;

/**
 * What the view zones of the diff editor paint (Monaco's DOM nodes of the
 * zones): given by the diff editor, which knows the theme and the views.
 */
interface IDiffEditorZonePainters {
    /**
     * The `diagonal-fill` of the empty side.
     */
    function diagonalFill():ViewZonePainter;
    /**
     * The `line-delete` lines of the original shown in the modified editor
     * (inline view, Monaco's `renderLines`): the lines of `originalRange`,
     * with the `char-delete` ranges of `diff`.
     */
    function deletedCode(originalRange:LineRange, diff:DetailedLineRangeMapping):ViewZonePainter;
    /**
     * The margin of the deleted code (`inline-deleted-margin-view-zone`),
     * with a `delete-sign` per line when `renderIndicators`.
     */
    function deletedCodeMargin(lineCount:Int, renderIndicators:Bool):ViewZonePainter;
    /**
     * The `gutter-delete` margin of the inline view's original editor.
     */
    function gutterDelete():ViewZonePainter;
}

typedef ILineRangeAlignment = {
    var originalRange:LineRange;
    var modifiedRange:LineRange;

    // accounts for foreign viewzones and line wrapping
    var originalHeightInPx:Float;
    var modifiedHeightInPx:Float;

    /**
     * If this range alignment is a direct result of a diff, then this is the diff's line mapping.
     * Only used for inline-view.
     */
    @:optional var diff:Null<DetailedLineRangeMapping>;
}

typedef AdditionalLineHeightInfo = {
    var lineNumber:Int;
    var heightInPx:Float;
}

/**
 * Ensures both editors have the same height by aligning unchanged lines.
 * In inline view mode, inserts viewzones to show deleted code from the original text model in the modified code editor.
 * Synchronizes scrolling.
 *
 * Make sure to add the view zones!
 *
 * Monaco's observables become `computeViewZones()`, called by the diff
 * editor when the diff, the options or the zones of other contributions
 * change (`onInvalidate` asks for it, like Monaco's `invalidateAlignmentsState`).
 * The scroll offsets of the moved code comparison are not ported (they are
 * 0 when no moved code is compared).
 */
class DiffEditorViewZones implements IDisposable {

    final _editors:{original:CodeEditorWidget, modified:CodeEditorWidget};
    final _diffModel:() -> Null<DiffEditorViewModel>;
    final _options:DiffEditorOptions;
    final _canIgnoreViewZoneUpdateEvent:() -> Bool;
    final _origViewZonesToIgnore:Map<String, Bool>;
    final _modViewZonesToIgnore:Map<String, Bool>;
    final _painters:IDiffEditorZonePainters;
    final _store = new DisposableStore();

    var _originalTopPadding:Float = 0;
    var _modifiedTopPadding:Float = 0;

    /**
     * Called when the alignments must be computed again (Monaco's
     * `invalidateAlignmentsState`, scheduled with a 0 ms timer).
     */
    public var onInvalidate:Null<() -> Void> = null;

    final updateImmediately:RunOnceScheduler;

    public function new(
        editors:{original:CodeEditorWidget, modified:CodeEditorWidget},
        diffModel:() -> Null<DiffEditorViewModel>,
        options:DiffEditorOptions,
        canIgnoreViewZoneUpdateEvent:() -> Bool,
        origViewZonesToIgnore:Map<String, Bool>,
        modViewZonesToIgnore:Map<String, Bool>,
        painters:IDiffEditorZonePainters
    ) {
        this._editors = editors;
        this._diffModel = diffModel;
        this._options = options;
        this._canIgnoreViewZoneUpdateEvent = canIgnoreViewZoneUpdateEvent;
        this._origViewZonesToIgnore = origViewZonesToIgnore;
        this._modViewZonesToIgnore = modViewZonesToIgnore;
        this._painters = painters;

        this.updateImmediately = new RunOnceScheduler(() -> {
            final f = onInvalidate;
            if (f != null) {
                f();
            }
        }, 0);
        this._store.add(this.updateImmediately);

        this._store.add(this._editors.original.onDidChangeViewZones(() -> {
            if (!this._canIgnoreViewZoneUpdateEvent()) {
                updateImmediately.schedule();
            }
        }));
        this._store.add(this._editors.modified.onDidChangeViewZones(() -> {
            if (!this._canIgnoreViewZoneUpdateEvent()) {
                updateImmediately.schedule();
            }
        }));
        this._store.add(this._editors.original.onDidChangeConfiguration((args) -> {
            if (args.hasChanged(EditorOption.wrappingInfo) || args.hasChanged(EditorOption.lineHeight)) {
                updateImmediately.schedule();
            }
        }));
        this._store.add(this._editors.modified.onDidChangeConfiguration((args) -> {
            if (args.hasChanged(EditorOption.wrappingInfo) || args.hasChanged(EditorOption.lineHeight)) {
                updateImmediately.schedule();
            }
        }));

        // Scroll synchronization (Monaco's "update scroll modified" and
        // "update scroll original" autoruns; the moved code offsets are 0)
        var ignoreChange = false;
        this._store.add(this._editors.original.onDidScrollChange((e) -> {
            if (e.scrollLeftChanged && !ignoreChange) {
                ignoreChange = true;
                this._editors.modified.setScrollLeft(e.scrollLeft);
                ignoreChange = false;
            }
            if (e.scrollTopChanged && !ignoreChange) {
                ignoreChange = true;
                final newScrollTopModified = this._editors.original.getScrollTop() - (this._originalTopPadding - this._modifiedTopPadding);
                if (newScrollTopModified != this._editors.modified.getScrollTop()) {
                    this._editors.modified.setScrollTop(newScrollTopModified, ScrollType.Immediate);
                }
                ignoreChange = false;
            }
        }));
        this._store.add(this._editors.modified.onDidScrollChange((e) -> {
            if (e.scrollLeftChanged && !ignoreChange) {
                ignoreChange = true;
                this._editors.original.setScrollLeft(e.scrollLeft);
                ignoreChange = false;
            }
            if (e.scrollTopChanged && !ignoreChange) {
                ignoreChange = true;
                final newScrollTopOriginal = this._editors.modified.getScrollTop() - (this._modifiedTopPadding - this._originalTopPadding);
                if (newScrollTopOriginal != this._editors.original.getScrollTop()) {
                    this._editors.original.setScrollTop(newScrollTopOriginal, ScrollType.Immediate);
                }
                ignoreChange = false;
            }
        }));
    }

    public function dispose():Void {
        _store.dispose();
    }

    /**
     * Runs a pending invalidation now (tests).
     */
    public function _flush():Void {
        if (updateImmediately.isScheduled()) {
            updateImmediately.flush();
        }
    }

    /**
     * Monaco's `alignments` derived value.
     */
    public function alignments():Null<Array<ILineRangeAlignment>> {
        final diffModel = this._diffModel();
        final diff = diffModel != null ? diffModel.diff : null;
        if (diffModel == null || diff == null) {
            return null;
        }
        final renderSideBySide = this._options.renderSideBySide;
        final innerHunkAlignment = renderSideBySide;
        return computeRangeAlignment(
            this._editors.original,
            this._editors.modified,
            diff.mappings,
            this._origViewZonesToIgnore,
            this._modViewZonesToIgnore,
            innerHunkAlignment
        );
    }

    function alignmentsSyncedMovedText():Null<Array<ILineRangeAlignment>> {
        final diffModel = this._diffModel();
        final syncedMovedText = diffModel != null ? diffModel.movedTextToCompare : null;
        if (syncedMovedText == null) {
            return null;
        }
        final mappings = syncedMovedText.changes.map(c -> new DiffMapping(c));
        // TODO dont include alignments outside syncedMovedText
        return computeRangeAlignment(
            this._editors.original,
            this._editors.modified,
            mappings,
            this._origViewZonesToIgnore,
            this._modViewZonesToIgnore,
            true
        );
    }

    /**
     * Monaco's `viewZones` derived value: the zones of the original and of
     * the modified editor.
     */
    public function computeViewZones():{orig:Array<IViewZone>, mod:Array<IViewZone>} {
        final alignmentsVal:Array<ILineRangeAlignment> = {
            final a = alignments();
            a != null ? a : [];
        };

        final origViewZones:Array<IViewZone> = [];
        final modViewZones:Array<IViewZone> = [];

        final modifiedTopPaddingVal = this._modifiedTopPadding;
        if (modifiedTopPaddingVal > 0) {
            modViewZones.push({
                afterLineNumber: 0,
                heightInPx: modifiedTopPaddingVal,
                showInHiddenAreas: true,
                suppressMouseDown: true,
            });
        }
        final originalTopPaddingVal = this._originalTopPadding;
        if (originalTopPaddingVal > 0) {
            origViewZones.push({
                afterLineNumber: 0,
                heightInPx: originalTopPaddingVal,
                showInHiddenAreas: true,
                suppressMouseDown: true,
            });
        }

        final renderSideBySide = this._options.renderSideBySide;

        final modLineHeight:Float = this._editors.modified.getOption(EditorOption.lineHeight);

        final diffModel = this._diffModel();
        final syncedMovedText = diffModel != null ? diffModel.movedTextToCompare : null;

        final originalModel = this._editors.original.getModel();

        for (a in alignmentsVal) {
            if (a.diff != null && !renderSideBySide && (!this._options.useTrueInlineDiffRendering || !allowsTrueInlineDiffRendering(a.diff))) {
                if (!a.originalRange.isEmpty) {
                    // `a.originalRange` can be out of bound when the diff has not been updated yet.
                    // In this case, we do an early return.
                    // TODO@hediet: Fix this by applying the edit directly to the diff model, so that the diff is always valid.
                    if (originalModel == null || a.originalRange.endLineNumberExclusive - 1 > originalModel.getLineCount()) {
                        return {orig: origViewZones, mod: modViewZones};
                    }
                    // The deleted lines are not wrapped (one view line each,
                    // see DEVIATIONS.md): `renderLines` gives one line per
                    // original line, and no extra zone of the original editor
                    final heightInLines = a.originalRange.length;

                    modViewZones.push({
                        afterLineNumber: a.modifiedRange.startLineNumber - 1,
                        heightInPx: heightInLines * modLineHeight,
                        paint: this._painters.deletedCode(a.originalRange, a.diff),
                        paintMargin: this._painters.deletedCodeMargin(heightInLines, this._options.renderIndicators),
                        showInHiddenAreas: true,
                        suppressMouseDown: true,
                    });
                }

                origViewZones.push({
                    afterLineNumber: a.originalRange.endLineNumberExclusive - 1,
                    paint: this._painters.diagonalFill(),
                    heightInPx: a.modifiedHeightInPx,
                    paintMargin: this._painters.gutterDelete(),
                    showInHiddenAreas: true,
                    suppressMouseDown: true,
                });
            }
            else {
                final delta = a.modifiedHeightInPx - a.originalHeightInPx;
                if (delta > 0) {
                    if (syncedMovedText != null && syncedMovedText.lineRangeMapping.original.delta(-1).deltaLength(2).contains(a.originalRange.endLineNumberExclusive - 1)) {
                        continue;
                    }

                    origViewZones.push({
                        afterLineNumber: a.originalRange.endLineNumberExclusive - 1,
                        paint: this._painters.diagonalFill(),
                        heightInPx: delta,
                        showInHiddenAreas: true,
                        suppressMouseDown: true,
                    });
                }
                else {
                    if (syncedMovedText != null && syncedMovedText.lineRangeMapping.modified.delta(-1).deltaLength(2).contains(a.modifiedRange.endLineNumberExclusive - 1)) {
                        continue;
                    }

                    // The revert arrows of the margin (`shouldRenderOldRevertArrows`) are not ported yet
                    modViewZones.push({
                        afterLineNumber: a.modifiedRange.endLineNumberExclusive - 1,
                        paint: this._painters.diagonalFill(),
                        heightInPx: -delta,
                        showInHiddenAreas: true,
                        suppressMouseDown: true,
                    });
                }
            }
        }

        final synced = alignmentsSyncedMovedText();
        for (a in (synced != null ? synced : [])) {
            if (syncedMovedText.lineRangeMapping.original.intersect(a.originalRange) == null
                || syncedMovedText.lineRangeMapping.modified.intersect(a.modifiedRange) == null) {
                // ignore unrelated alignments outside the synced moved text
                continue;
            }

            final delta = a.modifiedHeightInPx - a.originalHeightInPx;
            if (delta > 0) {
                origViewZones.push({
                    afterLineNumber: a.originalRange.endLineNumberExclusive - 1,
                    paint: this._painters.diagonalFill(),
                    heightInPx: delta,
                    showInHiddenAreas: true,
                    suppressMouseDown: true,
                });
            }
            else {
                modViewZones.push({
                    afterLineNumber: a.modifiedRange.endLineNumberExclusive - 1,
                    paint: this._painters.diagonalFill(),
                    heightInPx: -delta,
                    showInHiddenAreas: true,
                    suppressMouseDown: true,
                });
            }
        }

        return {orig: origViewZones, mod: modViewZones};
    }

    public static function computeRangeAlignment(
        originalEditor:CodeEditorWidget,
        modifiedEditor:CodeEditorWidget,
        diffs:Array<DiffMapping>,
        originalEditorAlignmentViewZones:Map<String, Bool>,
        modifiedEditorAlignmentViewZones:Map<String, Bool>,
        innerHunkAlignment:Bool
    ):Array<ILineRangeAlignment> {
        final originalLineHeightOverrides = new ArrayQueue(getAdditionalLineHeights(originalEditor, originalEditorAlignmentViewZones));
        final modifiedLineHeightOverrides = new ArrayQueue(getAdditionalLineHeights(modifiedEditor, modifiedEditorAlignmentViewZones));

        final origLineHeight:Float = originalEditor.getOption(EditorOption.lineHeight);
        final modLineHeight:Float = modifiedEditor.getOption(EditorOption.lineHeight);

        final result:Array<ILineRangeAlignment> = [];

        var lastOriginalLineNumber = 0;
        var lastModifiedLineNumber = 0;

        function handleAlignmentsOutsideOfDiffs(untilOriginalLineNumberExclusive:Float, untilModifiedLineNumberExclusive:Float):Void {
            while (true) {
                var origNext = originalLineHeightOverrides.peek();
                var modNext = modifiedLineHeightOverrides.peek();
                if (origNext != null && origNext.lineNumber >= untilOriginalLineNumberExclusive) {
                    origNext = null;
                }
                if (modNext != null && modNext.lineNumber >= untilModifiedLineNumberExclusive) {
                    modNext = null;
                }
                if (origNext == null && modNext == null) {
                    break;
                }

                final distOrig:Float = origNext != null ? origNext.lineNumber - lastOriginalLineNumber : 1.7976931348623157e308;
                final distNext:Float = modNext != null ? modNext.lineNumber - lastModifiedLineNumber : 1.7976931348623157e308;

                if (distOrig < distNext) {
                    originalLineHeightOverrides.dequeue();
                    modNext = {
                        lineNumber: origNext.lineNumber - lastOriginalLineNumber + lastModifiedLineNumber,
                        heightInPx: 0,
                    };
                }
                else if (distOrig > distNext) {
                    modifiedLineHeightOverrides.dequeue();
                    origNext = {
                        lineNumber: modNext.lineNumber - lastModifiedLineNumber + lastOriginalLineNumber,
                        heightInPx: 0,
                    };
                }
                else {
                    originalLineHeightOverrides.dequeue();
                    modifiedLineHeightOverrides.dequeue();
                }

                result.push({
                    originalRange: LineRange.ofLength(origNext.lineNumber, 1),
                    modifiedRange: LineRange.ofLength(modNext.lineNumber, 1),
                    originalHeightInPx: origLineHeight + origNext.heightInPx,
                    modifiedHeightInPx: modLineHeight + modNext.heightInPx,
                    diff: null,
                });
            }
        }

        for (m in diffs) {
            final c = m.lineRangeMapping;
            handleAlignmentsOutsideOfDiffs(c.original.startLineNumber, c.modified.startLineNumber);

            var first = true;
            var lastModLineNumber = c.modified.startLineNumber;
            var lastOrigLineNumber = c.original.startLineNumber;

            function emitAlignment(origLineNumberExclusive:Int, modLineNumberExclusive:Int, forceAlignment:Bool = false):Void {
                if (origLineNumberExclusive < lastOrigLineNumber || modLineNumberExclusive < lastModLineNumber) {
                    return;
                }
                if (first) {
                    first = false;
                }
                else if (!forceAlignment && (origLineNumberExclusive == lastOrigLineNumber || modLineNumberExclusive == lastModLineNumber)) {
                    // This causes a re-alignment of an already aligned line.
                    // However, we don't care for the final alignment.
                    return;
                }
                final originalRange = new LineRange(lastOrigLineNumber, origLineNumberExclusive);
                final modifiedRange = new LineRange(lastModLineNumber, modLineNumberExclusive);
                if (originalRange.isEmpty && modifiedRange.isEmpty) {
                    return;
                }

                var originalAdditionalHeight:Float = 0;
                final origTaken = originalLineHeightOverrides.takeWhile(v -> v.lineNumber < origLineNumberExclusive);
                if (origTaken != null) {
                    for (v in origTaken) {
                        originalAdditionalHeight += v.heightInPx;
                    }
                }
                var modifiedAdditionalHeight:Float = 0;
                final modTaken = modifiedLineHeightOverrides.takeWhile(v -> v.lineNumber < modLineNumberExclusive);
                if (modTaken != null) {
                    for (v in modTaken) {
                        modifiedAdditionalHeight += v.heightInPx;
                    }
                }

                result.push({
                    originalRange: originalRange,
                    modifiedRange: modifiedRange,
                    originalHeightInPx: originalRange.length * origLineHeight + originalAdditionalHeight,
                    modifiedHeightInPx: modifiedRange.length * modLineHeight + modifiedAdditionalHeight,
                    diff: m.lineRangeMapping,
                });

                lastOrigLineNumber = origLineNumberExclusive;
                lastModLineNumber = modLineNumberExclusive;
            }

            if (innerHunkAlignment) {
                final innerChanges = c.innerChanges != null ? c.innerChanges : [];
                for (i in innerChanges) {
                    if (i.originalRange.startColumn > 1 && i.modifiedRange.startColumn > 1) {
                        // There is some unmodified text on this line before the diff
                        emitAlignment(i.originalRange.startLineNumber, i.modifiedRange.startLineNumber);
                    }
                    final originalModel = originalEditor.getModel();
                    // When the diff is invalid, the ranges might be out of bounds (this should be fixed in the diff model by applying edits directly).
                    final maxColumn = i.originalRange.endLineNumber <= originalModel.getLineCount() ? originalModel.getLineMaxColumn(i.originalRange.endLineNumber) : LineRangeMappingMaxColumn.value;
                    if (i.originalRange.endColumn < maxColumn) {
                        // // There is some unmodified text on this line after the diff
                        emitAlignment(i.originalRange.endLineNumber, i.modifiedRange.endLineNumber);
                    }
                }
            }

            emitAlignment(c.original.endLineNumberExclusive, c.modified.endLineNumberExclusive, true);

            lastOriginalLineNumber = c.original.endLineNumberExclusive;
            lastModifiedLineNumber = c.modified.endLineNumberExclusive;
        }
        handleAlignmentsOutsideOfDiffs(1.7976931348623157e308, 1.7976931348623157e308);

        return result;
    }

    static function getAdditionalLineHeights(editor:CodeEditorWidget, viewZonesToIgnore:Map<String, Bool>):Array<AdditionalLineHeightInfo> {
        final viewZoneHeights:Array<AdditionalLineHeightInfo> = [];
        final wrappingZoneHeights:Array<AdditionalLineHeightInfo> = [];

        final viewModel = editor._getViewModel();
        final model = editor.getModel();
        if (viewModel == null || model == null) {
            return [];
        }
        final hasWrapping = editor.getOption(EditorOption.wrappingInfo).wrappingColumn != -1;
        final coordinatesConverter = viewModel.coordinatesConverter;
        final editorLineHeight:Float = editor.getOption(EditorOption.lineHeight);
        if (hasWrapping) {
            for (i in 1...model.getLineCount() + 1) {
                final lineCount = coordinatesConverter.getModelLineViewLineCount(i);
                if (lineCount > 1) {
                    wrappingZoneHeights.push({lineNumber: i, heightInPx: editorLineHeight * (lineCount - 1)});
                }
            }
        }

        for (w in editor.getWhitespaces()) {
            if (viewZonesToIgnore.exists(w.id)) {
                continue;
            }
            final modelLineNumber = w.afterLineNumber == 0 ? 0 : coordinatesConverter.convertViewPositionToModelPosition(
                new Position(w.afterLineNumber, 1)
            ).lineNumber;
            viewZoneHeights.push({lineNumber: modelLineNumber, heightInPx: w.height});
        }

        final result = DiffEditorUtils.joinCombine(
            viewZoneHeights,
            wrappingZoneHeights,
            v -> v.lineNumber,
            (v1, v2) -> ({lineNumber: v1.lineNumber, heightInPx: v1.heightInPx + v2.heightInPx})
        );

        return result;
    }

    public static function allowsTrueInlineDiffRendering(mapping:DetailedLineRangeMapping):Bool {
        if (mapping.innerChanges == null) {
            return false;
        }
        for (c in mapping.innerChanges) {
            if (!((rangeIsSingleLine(c.modifiedRange) && rangeIsSingleLine(c.originalRange))
                || c.originalRange.equalsRange(new Range(1, 1, 1, 1)))) {
                return false;
            }
        }
        return true;
    }

    static function rangeIsSingleLine(range:Range):Bool {
        return range.startLineNumber == range.endLineNumber;
    }

}

private class LineRangeMappingMaxColumn {
    /**
     * Monaco's `Number.MAX_SAFE_INTEGER` column.
     */
    public static inline final value:Int = cityscape.common.diff.RangeMapping.LineRangeMapping.MAX_COLUMN;
}
