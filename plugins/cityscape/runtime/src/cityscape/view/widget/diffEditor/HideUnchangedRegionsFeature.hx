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
    /**
     * The mouse cursor over the bar of a zone `height` pixels high
     * (`HideUnchangedRegionsFeature.barMouseCursor`).
     */
    function collapsedCodeBarCursor(region:UnchangedRegion, hide:Bool, height:Float):ViewZoneMouseCursor;
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
 * The edges of the bar are Monaco's `.top` and `.bottom` nodes: a press
 * and a drag on the top edge reveals lines above as the mouse moves (one
 * line per line height), on the bottom edge lines below (the lines after
 * the bar kept in place), a click (no move beyond 2 px) shows
 * `hideUnchangedRegions.revealLineCount` more lines; the unfold icon or a
 * double click on the text shows all the lines. The breadcrumbs of the bar
 * are not ported (Monaco's standalone editor has none).
 */
class HideUnchangedRegionsFeature implements IDisposable {

    /**
     * How far the top edge of a bar reaches above its zone and the bottom
     * edge below it, in pixels (style.css: `.diff-hidden-lines` is
     * translated 10 px up; `.top` is a 10 px box (4 px top border, 4 px,
     * 2 px bottom border) translated 4 px down, so it covers 6 px above the
     * bar and its first 4 px; `.bottom` the same box translated 6 px up,
     * the last 6 px of the bar and 4 px below it). Measured on the real
     * Monaco 0.52.2: rows -6..3 and 18..27 of a 24 px bar.
     */
    public static inline final EDGE_REACH_ABOVE:Float = 6;
    public static inline final EDGE_REACH_BELOW:Float = 4;
    public static inline final TOP_EDGE_HEIGHT:Float = 4;
    public static inline final BOTTOM_EDGE_HEIGHT:Float = 6;

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
        this._store.add(this._editors.original.onMouseMove((event) -> this._onMouseMove(event, this._editors.original)));
        this._store.add(this._editors.modified.onMouseMove((event) -> this._onMouseMove(event, this._editors.modified)));
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
                    mouseCursor: this._painter.collapsedCodeBarCursor(r, !sideBySide, height),
                    mouseReachAbove: EDGE_REACH_ABOVE,
                    mouseReachBelow: EDGE_REACH_BELOW,
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
                    mouseCursor: this._painter.collapsedCodeBarCursor(r, false, height),
                    mouseReachAbove: EDGE_REACH_ABOVE,
                    mouseReachBelow: EDGE_REACH_BELOW,
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
        final drag = this._drag;
        if (drag != null && drag.editor == editor) {
            this._endDrag(drag, event);
            return;
        }
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
     * The mouse cursor over the bar of a collapsed region (style.css), at
     * `y` in its zone `height` pixels high: over its top edge (the `.top`
     * node, from `EDGE_REACH_ABOVE` pixels above the zone to its first
     * `TOP_EDGE_HEIGHT` pixels) `n-resize` when it can show more lines above
     * (`canMoveTop`: lines of the region shown at its top), `s-resize` when
     * it can hide more (`canMoveBottom`: not fully revealed), `ns-resize`
     * for both; over its bottom edge (the `.bottom` node, the last
     * `BOTTOM_EDGE_HEIGHT` pixels of the zone to `EDGE_REACH_BELOW` pixels
     * below it) the same with the lines shown at its bottom; else null (the
     * zone's own cursor). Measured on the real Monaco 0.52.2: `s-resize` on
     * rows -6..3 and `n-resize` on rows 18..27 of a 24 px bar shown
     * collapsed, at every column (the edges win over the text of the bar).
     */
    public static function barEdgeCursor(region:UnchangedRegion, y:Float, height:Float):Null<glaze.CursorStyle> {
        if (isTopEdge(y)) {
            return edgeCursor(region, true);
        }
        if (isBottomEdge(y, height)) {
            return edgeCursor(region, false);
        }
        return null;
    }

    public static inline function isTopEdge(y:Float):Bool {
        return y >= -EDGE_REACH_ABOVE && y < TOP_EDGE_HEIGHT;
    }

    public static inline function isBottomEdge(y:Float, height:Float):Bool {
        return y >= height - BOTTOM_EDGE_HEIGHT && y < height + EDGE_REACH_BELOW;
    }

    /**
     * The cursor of an edge (`canMoveTop` and `canMoveBottom` of the
     * `.top` or `.bottom` node, and of the editor while the edge is
     * dragged: `draggingUnchangedRegion`).
     */
    public static function edgeCursor(region:UnchangedRegion, top:Bool):Null<glaze.CursorStyle> {
        final fullyRevealed = region.visibleLineCountTop + region.visibleLineCountBottom == region.lineCount;
        final canMoveTop = top ? region.visibleLineCountTop > 0 : !fullyRevealed;
        final canMoveBottom = top ? !fullyRevealed : region.visibleLineCountBottom > 0;
        return canMoveTop ? (canMoveBottom ? glaze.CursorStyle.ResizeUpDown : glaze.CursorStyle.ResizeUp) : (canMoveBottom ? glaze.CursorStyle.ResizeDown : null);
    }

    /**
     * The drag of a bar edge in progress (Monaco's `mousedown` listeners
     * of `.top` and `.bottom`, and their window listeners).
     */
    var _drag:Null<BarEdgeDrag> = null;

    /**
     * The y of the top of the line after the region in the editor, or the
     * content height when the region ends the text (what the bottom edge
     * keeps in place: Monaco's `top` and `top2`).
     */
    function _rangeEndTop(editor:CodeEditorWidget, region:UnchangedRegion):Float {
        final model = editor.getModel();
        final rangeEnd = editor == this._editors.modified ? region.modifiedUnchangedRange.endLineNumberExclusive : region.originalUnchangedRange.endLineNumberExclusive;
        return (model != null && rangeEnd > model.getLineCount()) ? editor.getContentHeight() : editor.getTopForLineNumber(rangeEnd);
    }

    function _startDrag(region:UnchangedRegion, editor:CodeEditorWidget, top:Bool, posy:Float):Void {
        region.isDragged = top ? 'top' : 'bottom';
        final drag = new BarEdgeDrag(region, editor, top, posy, top ? region.visibleLineCountTop : region.visibleLineCountBottom);
        this._drag = drag;
        this._updateDragCursor(drag);
    }

    function _updateDragCursor(drag:BarEdgeDrag):Void {
        final view = cityscape.view.EditorWidgets.viewOf(drag.editor);
        if (view != null) {
            final cursor = edgeCursor(drag.region, drag.top);
            view.setZoneDragCursor(cursor != null ? cursor : glaze.CursorStyle.Arrow);
        }
    }

    /**
     * Monaco's `mousemove` listener of the drag: the lines revealed follow
     * the mouse, one per line height from the press (`Math.round`), within
     * 0 and the lines left; a move beyond 2 px makes the release no click.
     */
    function _onMouseMove(event:IEditorMouseEvent, editor:CodeEditorWidget):Void {
        final drag = this._drag;
        if (drag == null || drag.editor != editor) {
            return;
        }
        final region = drag.region;
        final delta = event.event.posy - drag.startY;
        drag.didMove = drag.didMove || Math.abs(delta) > 2;
        final lineHeight:Float = editor.getOption(EditorOption.lineHeight);
        final lineDelta = Math.round(delta / lineHeight);
        if (drag.top) {
            region.visibleLineCountTop = Std.int(Math.max(0, Math.min(drag.cur + lineDelta, region.getMaxVisibleLineCountTop())));
        }
        else {
            final newVal = Std.int(Math.max(0, Math.min(drag.cur - lineDelta, region.getMaxVisibleLineCountBottom())));
            final top = this._rangeEndTop(editor, region);
            region.visibleLineCountBottom = newVal;
            final top2 = this._rangeEndTop(editor, region);
            editor.setScrollTop(editor.getScrollTop() + (top2 - top));
        }
        this._updateDragCursor(drag);
    }

    /**
     * Monaco's `mouseup` listener of the drag: without a move, the click
     * shows `revealLineCount` more lines (the lines after the bar kept in
     * place for the bottom edge).
     */
    function _endDrag(drag:BarEdgeDrag, event:IEditorMouseEvent):Void {
        this._drag = null;
        final region = drag.region;
        final editor = drag.editor;
        if (drag.top) {
            if (!drag.didMove) {
                region.showMoreAbove(this._options.hideUnchangedRegionsRevealLineCount);
            }
            region.isDragged = null;
        }
        else {
            region.isDragged = null;
            if (!drag.didMove) {
                final top = this._rangeEndTop(editor, region);
                region.showMoreBelow(this._options.hideUnchangedRegionsRevealLineCount);
                final top2 = this._rangeEndTop(editor, region);
                editor.setScrollTop(editor.getScrollTop() + (top2 - top));
            }
        }
        final view = cityscape.view.EditorWidgets.viewOf(editor);
        if (view != null) {
            view.setZoneDragCursor(null);
        }
    }

    /**
     * A mouse down on the bar of a collapsed region (Monaco's listeners of
     * the overlay widget's top, bottom, unfold icon and text): returns true
     * when the bar handled it. `zoneY` is the y of the mouse in the zone
     * (outside 0..height within the reach of the edges), `inMargin` whether
     * it is over the gutter, `clickCount` the clicks, `posy` the y of the
     * mouse in the window (the origin of a drag), `leftButton` whether the
     * left button is pressed (the edges only react to it: `e.button !== 0`).
     */
    public function handleBarMouseDown(editor:CodeEditorWidget, viewZoneId:String, zoneY:Float, inMargin:Bool, clickCount:Int, posy:Float = 0, leftButton:Bool = true):Bool {
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
            if (isTopEdge(zoneY)) {
                // `.top`: a drag reveals lines above, a click shows more above
                if (leftButton && this._drag == null) {
                    this._startDrag(r, editor, true, posy);
                }
            }
            else if (isBottomEdge(zoneY, height)) {
                // `.bottom`: a drag reveals lines below, a click shows more below
                if (leftButton && this._drag == null) {
                    this._startDrag(r, editor, false, posy);
                }
            }
            else if (zoneY >= 0 && zoneY < height && !z.hide && (inMargin || clickCount >= 2)) {
                // the unfold icon (`Show Unchanged Region`), or a double click on the text
                r.showAll();
            }
            return true;
        }
        return false;
    }

}

/**
 * A drag of the top or bottom edge of a hidden region bar in progress
 * (the locals of Monaco's `mousedown` listeners: `startTop`, `didMove`,
 * `cur`).
 */
class BarEdgeDrag {
    public final region:UnchangedRegion;
    public final editor:CodeEditorWidget;
    public final top:Bool;
    public final startY:Float;
    public final cur:Int;
    public var didMove:Bool = false;

    public function new(region:UnchangedRegion, editor:CodeEditorWidget, top:Bool, startY:Float, cur:Int) {
        this.region = region;
        this.editor = editor;
        this.top = top;
        this.startY = startY;
        this.cur = cur;
    }
}
