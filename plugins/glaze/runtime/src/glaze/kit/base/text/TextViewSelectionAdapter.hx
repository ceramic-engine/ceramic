// Ported from gpui-kit 0.8.1: crates/base/src/text/selection_adapter.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.App;
import glaze.Bounds;
import glaze.Hitbox;
import glaze.Hsla;
import glaze.Point;
import glaze.WeakEntity;
import glaze.Window;
import glaze.kit.base.GlobalState;
import glaze.kit.base.TextSelectionContentKey;
import glaze.kit.base.TextSelectionCoverage;
import glaze.kit.base.TextSelectionEndpoint;
import glaze.kit.base.TextSelectionEvent;
import glaze.kit.base.TextSelectionHandle;
import glaze.kit.base.TextSelectionRegistration;
import glaze.kit.base.TextSelectionRun;
import glaze.kit.base.TextSelectionSnapshot;
import glaze.kit.base.TouchHandleLayout;
import glaze.kit.base.TextSelectionRegistration.BoundsPair;
import glaze.util.Utf8;

using glaze.kit.base.text.CopyProjection.CopyProjectionTools;

private class CachedBlockEndpoint {
    public final endpoint:TextSelectionEndpoint;
    public final blockIx:Null<Int>;

    public inline function new(endpoint:TextSelectionEndpoint, blockIx:Null<Int>) {
        this.endpoint = endpoint;
        this.blockIx = blockIx;
    }

    public function equals(other:Null<CachedBlockEndpoint>):Bool {
        return other != null && endpoint.equals(other.endpoint) && blockIx == other.blockIx;
    }

    public static function eq(a:Null<CachedBlockEndpoint>, b:Null<CachedBlockEndpoint>):Bool {
        return a == null ? b == null : a.equals(b);
    }
}

/** Rust `VirtualBlockSelection`: the logical block range of the window selection in this view. */
private class VirtualBlockSelection {
    public var anchor:Null<CachedBlockEndpoint> = null;
    public var cursor:Null<CachedBlockEndpoint> = null;
    public var coverage:TextSelectionCoverage = Bounded;
    public var isSelecting:Bool = false;

    public function new() {}

    public function reset():Void {
        anchor = null;
        cursor = null;
        coverage = Bounded;
        isSelecting = false;
    }

    public function update(snapshot:Null<TextSelectionSnapshot>, entityId:Int):Bool {
        if (snapshot == null) {
            final changed = anchor != null || cursor != null;
            reset();
            return changed;
        }

        // Origin and scroll changes only alter the window projection. They
        // must not turn a held logical range back into a hit test in reflowed
        // text.
        final changed = !(anchor != null && anchor.endpoint.equals(snapshot.anchor()))
            || !(cursor != null && cursor.endpoint.equals(snapshot.cursor()))
            || coverage != snapshot.coverage()
            || isSelecting != snapshot.isSelecting();
        coverage = snapshot.coverage();
        isSelecting = snapshot.isSelecting();

        anchor = updateEndpoint(anchor, snapshot.anchor(), entityId);
        cursor = updateEndpoint(cursor, snapshot.cursor(), entityId);
        return changed;
    }

    static function updateEndpoint(cached:Null<CachedBlockEndpoint>, endpoint:TextSelectionEndpoint, entityId:Int):CachedBlockEndpoint {
        if (cached != null && cached.endpoint.equals(endpoint)) {
            return cached;
        }
        final key = endpoint.contentKey();
        final blockIx:Null<Int> = endpoint.entityId() == entityId && key != null ? key.value() : null;
        return new CachedBlockEndpoint(endpoint, blockIx);
    }

    /** The inclusive block range `[start, end]`, or `null`. */
    public function blockRange(entityId:Int, last:Int):Null<Array<Int>> {
        final anchor = this.anchor;
        if (anchor == null) return null;
        final cursor = this.cursor;
        if (cursor == null) return null;
        switch coverage {
            case Full:
                return [0, last];
            case FromStart:
                final ix = anchor.blockIx != null ? anchor.blockIx : cursor.blockIx;
                return ix != null ? [0, ix] : null;
            case ToEnd:
                final ix = anchor.blockIx != null ? anchor.blockIx : cursor.blockIx;
                return ix != null ? [ix, last] : null;
            case Bounded:
                if (anchor.endpoint.entityId() != entityId || cursor.endpoint.entityId() != entityId) {
                    return null;
                }
                final a = anchor.blockIx;
                final c = cursor.blockIx;
                if (a == null || c == null) return null;
                return [a < c ? a : c, a > c ? a : c];
        }
    }
}

/** What the view's text painted this frame (Rust `PaintedText`). */
private class PaintedText {
    public final textBounds:Array<Bounds> = [];
    public final textRuns:Array<TextSelectionRun> = [];
    /** Each with the table cell it painted in, if any. */
    public final copyProjections:Array<{projection:CopyProjection, cell:Null<Bounds>}> = [];
    /**
     * The caret boxes at the first and last selected character painted this
     * frame, where the touch handles go.
     */
    public var selectionEdges:Null<BoundsPair> = null;

    public function new() {}
}

/**
 * TextView's renderer-specific bridge to base-owned window selection.
 *
 * Rust clones share the painted frame (`Rc<RefCell<PaintedText>>`); here
 * the adapter itself is shared.
 */
class TextViewSelectionAdapter {

    @:allow(glaze.kit.base.text)
    final selection:TextSelectionHandle;

    /**
     * What the view's text painted this frame. Inlines report it as they
     * paint, through a read of the view's state: reporting it is not a change
     * of the view.
     */
    final frame:PaintedText;

    var layoutRevision:Null<Int> = null;

    public function new(view:WeakEntity<TextViewState>, cx:App) {
        final selection = TextSelectionHandle.create('', cx);
        final selectionId = selection.entityId();
        final virtualBlocks = new VirtualBlockSelection();
        final frame = new PaintedText();
        this.selection = selection;
        this.frame = frame;

        selection.subscribe((event, cx) -> {
            switch event {
                case SelectionChanged(snapshot):
                    view.tryUpdate(cx, (state, cx) -> {
                        final changed = virtualBlocks.update(snapshot, selectionId);
                        if (snapshot == null || changed) {
                            state.preserveInlineSelection = false;
                        }
                        state._isSelecting = snapshot != null && snapshot.isSelecting();
                        if (state._isSelecting) {
                            state.endMultiClickSelection(cx.app);
                        }
                        cx.notify();
                    });
                case AutoScroll(delta):
                    view.tryUpdate(cx, (state, cx) -> {
                        if (state.scrollable) {
                            state.setAutoScroll(delta, cx);
                        }
                        else if (delta == null) {
                            state.stopAutoScroll();
                        }
                    });
                case Cleared:
                case TouchSelectionChanged:
                    view.tryUpdate(cx, (_, cx) -> cx.notify());
            }
        }, cx);

        selection.clearWith(cx -> {
            virtualBlocks.reset();
            view.tryUpdate(cx, (state, cx) -> {
                state.resetSelection();
                cx.notify();
            });
        }, cx);

        selection.copyWith(cx -> {
            final view = view.upgrade();
            if (view == null) {
                return '';
            }
            final state = view.read(cx);
            if (!state.hasCurrentCopyDocument()) {
                return '';
            }
            // Read the handle itself: event subscribers may not have run yet
            // when input and Copy arrive in the same App update.
            final current = new VirtualBlockSelection();
            current.update(state.selectionAdapter.selection.snapshot(cx), selectionId);
            final rangeChanged = !CachedBlockEndpoint.eq(current.anchor, virtualBlocks.anchor)
                || !CachedBlockEndpoint.eq(current.cursor, virtualBlocks.cursor)
                || current.coverage != virtualBlocks.coverage;
            final anchorCell = state.selectionAdapter.selection.tableCellSelection(cx);
            // Gesture snapshots are current before paint. Refresh the rich
            // document's byte ranges from its retained native layouts before
            // its existing Plain/Source serializer reads them.
            if (!state.hasViewSelection() && (!state.preserveInlineSelection || rangeChanged)) {
                final points = state.selectionPoints(cx);
                if (points != null) {
                    // Only represented source states are refreshed. Offscreen
                    // AST selections retain their logical ends.
                    for (entry in frame.copyProjections) {
                        entry.projection.reset();
                    }
                    for (entry in frame.copyProjections) {
                        final confined = GlobalState.confineToCell(anchorCell != null ? points.start : null, anchorCell, entry.cell, points.start, points.end);
                        if (confined != null) {
                            entry.projection.project(confined[0], confined[1]);
                        }
                        else {
                            entry.projection.deselect();
                        }
                    }
                }
            }
            final blocksLen = state.parsedContent.document.blocks.length;
            final last = blocksLen > 0 ? blocksLen - 1 : 0;
            final blocks = if (anchorCell != null) {
                final anchor = current.anchor;
                if (anchor == null || anchor.endpoint.entityId() != selectionId) {
                    return '';
                }
                anchor.blockIx != null ? [anchor.blockIx, anchor.blockIx] : null;
            }
            else {
                current.blockRange(selectionId, last);
            }
            return state.selectedTextIn(blocks);
        }, cx);

        selection.resolveContentKeyWith((point, cx) -> {
            final view = view.upgrade();
            if (view == null) return null;
            final block = view.read(cx).blockIxAt(point.y);
            return block != null ? new TextSelectionContentKey(block) : null;
        }, cx);

        selection.focusWith((window, cx) -> {
            final view = view.upgrade();
            if (view == null) {
                return;
            }
            final focusHandle = view.read(cx).focusHandle;
            view.update(cx, (state, _) -> state._isSelecting = true);
            focusHandle.focus(window, cx);
        }, cx);
    }

    public function updateLayoutRevision(revision:Int, isSelecting:Bool):Bool {
        final changed = layoutRevision != null && layoutRevision != revision;
        if (!changed || !isSelecting) {
            layoutRevision = revision;
        }
        return changed && !isSelecting;
    }

    public function clearCopyProjections(cx:App):Void {
        selection.clearTableCellSelection(cx);
        frame.copyProjections.resize(0);
    }

    /** Registers `projection` as it paints, with the table cell it is in. */
    public function registerCopyProjection(projection:CopyProjection, cx:App):Void {
        final cell = GlobalState.global(cx).tableCell();
        frame.copyProjections.push({projection: projection, cell: cell});
    }

    public function beginFrame():Void {
        frame.textBounds.resize(0);
        frame.textRuns.resize(0);
        frame.copyProjections.resize(0);
        frame.selectionEdges = null;
    }

    /**
     * Records one inline's painted selection ends. Inlines paint in document
     * order, so the first start and the last end are the view's.
     */
    public function registerSelectionEdges(start:Bounds, end:Bounds):Void {
        final first = frame.selectionEdges != null ? frame.selectionEdges.start : start;
        frame.selectionEdges = new BoundsPair(first, end);
    }

    public function registerTextRun(run:TextSelectionRun):Void {
        frame.textRuns.push(run);
    }

    public function registerInline(bounds:Array<Bounds>):Void {
        for (b in bounds) frame.textBounds.push(b);
    }

    public function register(hitbox:Hitbox, bounds:Bounds, scrollOffset:Point, selfScroll:Bool, window:Window, cx:App):Void {
        selection.setHitTestRuns(frame.textRuns, cx);
        var registration = new TextSelectionRegistration(hitbox, bounds)
            .withScrollOffset(scrollOffset)
            .inPaintOrder()
            .withTextBounds(frame.textBounds.copy())
            .withSelfScroll(selfScroll)
            .withRenderedElement(selection, window, cx);
        final edges = frame.selectionEdges;
        if (edges != null) {
            registration = registration.withSelectionEdges(edges.start, edges.end);
        }
        selection.register(registration, window, cx);
    }

    /** Lays out the touch handles this view owns; see `TextSelectionHandle.prepaintTouchHandles`. */
    public function prepaintTouchHandles(window:Window, cx:App):TouchHandleLayout {
        return selection.prepaintTouchHandles(window, cx);
    }

    /**
     * Paints the touch handles this view owns, after its content for the
     * frame; see `TextSelectionHandle.paintTouchHandles`.
     */
    public function paintTouchHandles(layout:TouchHandleLayout, color:Hsla, window:Window, cx:App):Void {
        selection.paintTouchHandles(layout, color, window, cx);
    }

    public function recordTableCell(bounds:Bounds, cx:App):Void {
        selection.recordTableCell(bounds, cx);
    }

    public function paintedSelectionPoints(cx:App):Null<BoundsPoints> {
        final points = selectionPoints(cx);
        if (points == null) return null;
        final anchorCell = selection.tableCellSelection(cx);
        final confined = GlobalState.confineToCell(anchorCell != null ? points.start : null, anchorCell, GlobalState.global(cx).tableCell(), points.start, points.end);
        return confined != null ? new BoundsPoints(confined[0], confined[1]) : null;
    }

    public function selectionPoints(cx:App):Null<BoundsPoints> {
        final snapshot = selection.snapshot(cx);
        if (snapshot == null) return null;
        final points = snapshot.windowPoints();
        if (points == null) return null;
        return new BoundsPoints(points.anchor(), points.cursor());
    }

    public function setLocalSelection(active:Bool, cx:App):Void {
        selection.setLocalSelection(active, cx);
    }

    /** See `TextSelectionHandle.holdMultiClick`. */
    public function holdMultiClick(start:Bounds, end:Bounds, clickCount:Int, cx:App):Void {
        selection.holdMultiClick(start, end, clickCount, cx);
    }

    public function isPartOfWindowSelection(cx:App):Bool {
        final id = selection.entityId();
        final snapshot = selection.snapshot(cx);
        return snapshot != null && (snapshot.anchor().entityId() == id || snapshot.cursor().entityId() == id);
    }

    public function hasSelectionSnapshot(cx:App):Bool {
        return selection.snapshot(cx) != null;
    }

    /** Test helper (Rust `#[cfg(test)]`). */
    public function textBounds():Array<Bounds> {
        return frame.textBounds.copy();
    }

    /**
     * Just inside the character at `index` of the text run painted this frame
     * with `text`, in the middle of its row (test helper).
     */
    public function textPosition(text:String, index:Int):Point {
        var layout:Null<glaze.TextLayout> = null;
        for (run in frame.textRuns) {
            if (run.text() == text) {
                layout = run.layout();
                break;
            }
        }
        return layout.positionForIndex(index).add(new Point(1., layout.lineHeight() / 2.));
    }

    /** Test helper. */
    public function firstTextPosition(index:Int):Point {
        final layout = frame.textRuns[0].layout();
        return layout.positionForIndex(index).add(new Point(0, layout.lineHeight() / 2.));
    }

}

/** Rust `(Point<Pixels>, Point<Pixels>)`: an anchor (`start`) and a cursor (`end`). */
class BoundsPoints {
    public final start:Point;
    public final end:Point;

    public inline function new(start:Point, end:Point) {
        this.start = start;
        this.end = end;
    }
}
