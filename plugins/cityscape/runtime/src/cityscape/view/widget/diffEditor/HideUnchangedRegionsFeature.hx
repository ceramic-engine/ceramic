// Ported from vscode src/vs/editor/browser/widget/diffEditor/features/hideUnchangedRegionsFeature.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.widget.diffEditor;

import cityscape.base.common.Lifecycle;
import cityscape.common.CursorEvents.CursorChangeReason;
import cityscape.common.EditorCommon.IEditorDecorationsCollection;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.LineRange;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.view.EditorBrowser;
import cityscape.view.widget.codeEditor.CodeEditorWidget;
import cityscape.view.widget.diffEditor.DiffEditorViewModel;

/**
 * Paints the bar of a collapsed unchanged region (Monaco's
 * `CollapsedCodeOverlayWidget`, a DOM overlay over its placeholder view
 * zone): `margin` is the part over the gutter (the unfold icon), the
 * content part shows "N hidden lines". `hide`: the bar without its
 * content (the original editor of the inline view).
 */
interface ICollapsedCodeBarPainter {
    function collapsedCodeBar(region:UnchangedRegion, hide:Bool, margin:Bool):ViewZonePainter;
}

/**
 * A placeholder view zone of an unchanged region (Monaco's
 * `PlaceholderViewZone` and the overlay widget drawn over it).
 */
class CollapsedCodeZone {
    public final region:UnchangedRegion;
    public final editor:CodeEditorWidget;
    public final hide:Bool;
    public final zone:IViewZone;

    public function new(region:UnchangedRegion, editor:CodeEditorWidget, hide:Bool, zone:IViewZone) {
        this.region = region;
        this.editor = editor;
        this.hide = hide;
        this.zone = zone;
    }
}

/**
 * Monaco's `HideUnchangedRegionsFeature`: hides the unchanged regions of
 * both editors (`setHiddenAreas`) and shows a bar in their place. Its
 * observables become `update()`, called by the diff editor when the
 * unchanged regions change.
 *
 * The bar is clicked instead of dragged: a click on its top edge shows
 * `hideUnchangedRegions.revealLineCount` more lines above, on its bottom
 * edge more lines below, on the unfold icon or a double click on the text
 * all the lines (Monaco's drag of the edges is not ported). The breadcrumbs
 * of the bar are not ported (Monaco's standalone editor has none).
 */
class HideUnchangedRegionsFeature implements IDisposable {

    final _editors:{original:CodeEditorWidget, modified:CodeEditorWidget};
    final _diffModel:() -> Null<DiffEditorViewModel>;
    final _options:DiffEditorOptions;
    final _painter:ICollapsedCodeBarPainter;
    final _store = new DisposableStore();
    final _originalDecorations:IEditorDecorationsCollection;
    final _modifiedDecorations:IEditorDecorationsCollection;

    var _isUpdatingHiddenAreas:Bool = false;
    public var isUpdatingHiddenAreas(get, never):Bool;
    inline function get_isUpdatingHiddenAreas():Bool return _isUpdatingHiddenAreas;

    /**
     * The zones of the last `viewZones()`, to find the bar under the mouse.
     */
    public final zones:Array<CollapsedCodeZone> = [];

    public function new(
        editors:{original:CodeEditorWidget, modified:CodeEditorWidget},
        diffModel:() -> Null<DiffEditorViewModel>,
        options:DiffEditorOptions,
        painter:ICollapsedCodeBarPainter
    ) {
        this._editors = editors;
        this._diffModel = diffModel;
        this._options = options;
        this._painter = painter;
        this._originalDecorations = editors.original.createDecorationsCollection();
        this._modifiedDecorations = editors.modified.createDecorationsCollection();

        this._store.add(this._editors.original.onDidChangeCursorPosition((e) -> {
            if (e.reason == CursorChangeReason.ContentFlush) {
                return;
            }
            final m = this._diffModel();
            if (m == null) {
                return;
            }
            final selections = this._editors.original.getSelections();
            for (s in (selections != null ? selections : [])) {
                m.ensureOriginalLineIsVisible(s.getStartPosition().lineNumber, RevealPreference.FromCloserSide);
                m.ensureOriginalLineIsVisible(s.getEndPosition().lineNumber, RevealPreference.FromCloserSide);
            }
        }));

        this._store.add(this._editors.modified.onDidChangeCursorPosition((e) -> {
            if (e.reason == CursorChangeReason.ContentFlush) {
                return;
            }
            final m = this._diffModel();
            if (m == null) {
                return;
            }
            final selections = this._editors.modified.getSelections();
            for (s in (selections != null ? selections : [])) {
                m.ensureModifiedLineIsVisible(s.getStartPosition().lineNumber, RevealPreference.FromCloserSide);
                m.ensureModifiedLineIsVisible(s.getEndPosition().lineNumber, RevealPreference.FromCloserSide);
            }
        }));

        this._store.add(this._editors.original.onMouseUp((event) -> this._onMouseUp(event, this._editors.original)));
        this._store.add(this._editors.modified.onMouseUp((event) -> this._onMouseUp(event, this._editors.modified)));
    }

    public function dispose():Void {
        _store.dispose();
        _originalDecorations.clear();
        _modifiedDecorations.clear();
    }

    /**
     * Monaco's `unchangedRegions` derived value.
     */
    function unchangedRegions():Array<UnchangedRegion> {
        final m = this._diffModel();
        final regions = m != null ? m.unchangedRegions : [];
        final modifiedModel = this._editors.modified.getModel();
        if (regions.length == 1 && regions[0].modifiedLineNumber == 1 && modifiedModel != null && regions[0].lineCount == modifiedModel.getLineCount()) {
            return [];
        }
        return regions;
    }

    /**
     * Monaco's `viewZones` derived value: the placeholder zones of the
     * regions that hide lines.
     */
    public function viewZones():{origViewZones:Array<IViewZone>, modViewZones:Array<IViewZone>} {
        this.zones.resize(0);
        final origViewZones:Array<IViewZone> = [];
        final modViewZones:Array<IViewZone> = [];
        final sideBySide = this._options.renderSideBySide;

        final compactMode = this._options.compactMode;

        final curUnchangedRegions = unchangedRegions();
        for (i in 0...curUnchangedRegions.length) {
            final r = curUnchangedRegions[i];
            if (r.shouldHideControls()) {
                continue;
            }

            if (compactMode && (i == 0 || i == curUnchangedRegions.length - 1)) {
                continue;
            }

            final height = compactMode ? 12 : 24;
            {
                final origVz:IViewZone = {
                    afterLineNumber: r.getHiddenOriginalRange().startLineNumber - 1,
                    heightInPx: height,
                    showInHiddenAreas: true,
                    suppressMouseDown: true,
                    paint: this._painter.collapsedCodeBar(r, !sideBySide, false),
                    paintMargin: this._painter.collapsedCodeBar(r, !sideBySide, true),
                };
                origViewZones.push(origVz);
                this.zones.push(new CollapsedCodeZone(r, this._editors.original, !sideBySide, origVz));
            }
            {
                final modViewZone:IViewZone = {
                    afterLineNumber: r.getHiddenModifiedRange().startLineNumber - 1,
                    heightInPx: height,
                    showInHiddenAreas: true,
                    suppressMouseDown: true,
                    paint: this._painter.collapsedCodeBar(r, false, false),
                    paintMargin: this._painter.collapsedCodeBar(r, false, true),
                };
                modViewZones.push(modViewZone);
                this.zones.push(new CollapsedCodeZone(r, this._editors.modified, false, modViewZone));
            }
        }

        return {origViewZones: origViewZones, modViewZones: modViewZones};
    }

    /**
     * The decorations and the hidden areas of the regions (Monaco's
     * "decorations" and "update folded unchanged regions" autoruns).
     */
    public function update():Void {
        final unchangedLinesDecoration:IModelDecorationOptions = {
            description: 'unchanged lines',
            className: 'diff-unchanged-lines',
            isWholeLine: true,
        };
        final unchangedLinesDecorationShow:IModelDecorationOptions = {
            description: 'Fold Unchanged',
            glyphMarginClassName: 'fold-unchanged codicon codicon-fold',
            zIndex: 10001,
        };

        final curUnchangedRegions = unchangedRegions();

        final originalResult:Array<IModelDeltaDecoration> = curUnchangedRegions.map(r -> ({
            range: r.originalUnchangedRange.toInclusiveRange(),
            options: unchangedLinesDecoration,
        } : IModelDeltaDecoration));
        for (r in curUnchangedRegions) {
            if (r.shouldHideControls()) {
                originalResult.push({
                    range: Range.fromPositions(new Position(r.originalLineNumber, 1)),
                    options: unchangedLinesDecorationShow,
                });
            }
        }
        this._originalDecorations.set(originalResult);

        final modifiedResult:Array<IModelDeltaDecoration> = curUnchangedRegions.map(r -> ({
            range: r.modifiedUnchangedRange.toInclusiveRange(),
            options: unchangedLinesDecoration,
        } : IModelDeltaDecoration));
        for (r in curUnchangedRegions) {
            if (r.shouldHideControls()) {
                modifiedResult.push({
                    range: LineRange.ofLength(r.modifiedLineNumber, 1).toInclusiveRange(),
                    options: unchangedLinesDecorationShow,
                });
            }
        }
        this._modifiedDecorations.set(modifiedResult);

        /** @description update folded unchanged regions */
        this._isUpdatingHiddenAreas = true;
        try {
            this._editors.original.setHiddenAreas([for (r in curUnchangedRegions) { final range = r.getHiddenOriginalRange().toInclusiveRange(); if (range != null) (range : IRange); }]);
            this._editors.modified.setHiddenAreas([for (r in curUnchangedRegions) { final range = r.getHiddenModifiedRange().toInclusiveRange(); if (range != null) (range : IRange); }]);
        }
        catch (e:Dynamic) {
            this._isUpdatingHiddenAreas = false;
            throw e;
        }
        this._isUpdatingHiddenAreas = false;
    }

    function _onMouseUp(event:IEditorMouseEvent, editor:CodeEditorWidget):Void {
        final target = event.target;
        final m = this._diffModel();
        if (m == null) {
            return;
        }
        // The `fold-unchanged` glyph of a revealed region collapses it
        if (target.type == MouseTargetType.GUTTER_GLYPH_MARGIN && target.position != null) {
            final lineNumber = target.position.lineNumber;
            final regions = m.unchangedRegions;
            for (r in regions) {
                final range = editor == this._editors.modified ? r.modifiedUnchangedRange : r.originalUnchangedRange;
                final firstLine = editor == this._editors.modified ? r.modifiedLineNumber : r.originalLineNumber;
                if (range.includes(lineNumber) && r.shouldHideControls() && lineNumber == firstLine) {
                    r.collapseAll();
                    return;
                }
            }
        }
    }

    /**
     * A mouse down on the bar of a collapsed region (Monaco's listeners of
     * the overlay widget's top, bottom, unfold icon and text): returns true
     * when the bar handled it. `zoneY` is the y of the mouse in the zone,
     * `inMargin` whether it is over the gutter, `clickCount` the clicks.
     */
    public function handleBarMouseDown(editor:CodeEditorWidget, viewZoneId:String, zoneY:Float, inMargin:Bool, clickCount:Int):Bool {
        final viewZones = editor.getViewZones();
        final myZone = viewZones != null ? viewZones.getZone(viewZoneId) : null;
        if (myZone == null) {
            return false;
        }
        for (i in 0...this.zones.length) {
            final z = this.zones[i];
            if (z.editor != editor || z.zone != myZone.delegate) {
                continue;
            }
            final r = z.region;
            final height:Float = z.zone.heightInPx;
            if (zoneY < 4) {
                // `.top`: show more above
                r.showMoreAbove(this._options.hideUnchangedRegionsRevealLineCount);
            }
            else if (zoneY >= height - 6) {
                // `.bottom`: show more below, keeping the lines below in place
                final model = editor.getModel();
                final rangeEnd = editor == this._editors.modified ? r.modifiedUnchangedRange.endLineNumberExclusive : r.originalUnchangedRange.endLineNumberExclusive;
                final topBefore = (model != null && rangeEnd > model.getLineCount()) ? editor.getContentHeight() : editor.getTopForLineNumber(rangeEnd);
                r.showMoreBelow(this._options.hideUnchangedRegionsRevealLineCount);
                final topAfter = (model != null && rangeEnd > model.getLineCount()) ? editor.getContentHeight() : editor.getTopForLineNumber(rangeEnd);
                editor.setScrollTop(editor.getScrollTop() + (topAfter - topBefore));
            }
            else if (!z.hide && (inMargin || clickCount >= 2)) {
                // the unfold icon (`Show Unchanged Region`), or a double click on the text
                r.showAll();
            }
            return true;
        }
        return false;
    }

}
