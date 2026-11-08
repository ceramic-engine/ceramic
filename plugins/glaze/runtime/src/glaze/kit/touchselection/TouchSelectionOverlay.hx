// Ported from gpui-kit 0.8.1: crates/component/src/touch_selection/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.touchselection;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.ElementId;
import glaze.Point;
import glaze.TouchPhase;
import glaze.Window;
import glaze.kit.base.input.SelectionEdge;
import glaze.kit.base.input.TouchHandle;
import glaze.kit.touchselection.EditMenu.EditMenuItem;
import glaze.kit.touchselection.SelectionHandles.DragHandler;
import glaze.kit.touchselection.SelectionHandles.SnapshotSource;
import glaze.kit.touchselection.SelectionHandles.SurfaceHandler;

/**
 * Touch selection: the grab handles and the edit menu a long press leaves
 * behind, drawn over an `Input` or over the window text selection that
 * `TextView` takes part in. Base owns the gesture and the drag (see
 * `TouchSelectionSnapshot`); this draws what Base laid out: a handle at each
 * end of the selection, and a row of commands above it.
 *
 * The handles read the selection's geometry as they paint, so they follow
 * text that scrolls in the same frame. The menu is placed from the snapshot
 * read here; it steps aside while the text scrolls, so a frame's lag in its
 * anchor never shows.
 */
class TouchSelectionOverlay {

    final id:ElementId;

    final source:SnapshotSource;

    final itemList:Array<EditMenuItem> = [];

    var onDrag:Null<DragHandler> = null;

    var onPaintHandler:Null<SurfaceHandler> = null;

    public function new(id:ElementId, source:SnapshotSource) {
        this.id = id;
        this.source = source;
    }

    /**
     * Draws floating handles, dragged through `onDrag`. An owner whose text
     * paints its own handles in place leaves this unset.
     */
    public function handles(onDrag:(SelectionEdge, TouchPhase, Point, Window, App) -> Void):TouchSelectionOverlay {
        this.onDrag = onDrag;
        return this;
    }

    /** The commands the edit menu offers. With none, no menu is drawn. */
    public function items(items:Array<EditMenuItem>):TouchSelectionOverlay {
        for (item in items) itemList.push(item);
        return this;
    }

    /**
     * Called with every surface's bounds as it paints, for an owner whose
     * press handling must leave those surfaces alone.
     */
    public function onPaint(onPaint:(Bounds, Window, App) -> Void):TouchSelectionOverlay {
        this.onPaintHandler = onPaint;
        return this;
    }

    /**
     * The elements to add to the owner: the handles, and the menu when it is
     * open. Each floats in window coordinates.
     */
    public function intoElements(window:Window, cx:App):Array<AnyElement> {
        final snapshot = source(window, cx);
        if (snapshot == null) {
            return [];
        }
        final elements:Array<AnyElement> = [];
        if (onDrag != null) {
            final handles = SelectionHandles.component(source, onDrag);
            if (onPaintHandler != null) handles.onPaint(onPaintHandler);
            elements.push((handles : glaze.IntoElement).intoAnyElement());
        }

        final bounds = snapshot.bounds();
        if (bounds != null && snapshot.isMenuOpen() && itemList.length > 0) {
            var anchor = bounds;
            // Leave the knobs uncovered: the menu anchors to the selection
            // plus the room its handles take above and below.
            if (!snapshot.isEmpty()) {
                anchor = new Bounds(
                    new Point(anchor.origin.x, anchor.origin.y - TouchHandle.EXTENT),
                    new glaze.Size(anchor.size.width, anchor.size.height + TouchHandle.EXTENT * 2.)
                );
            }
            final menu = EditMenu.component(id, anchor).items(itemList);
            if (onPaintHandler != null) menu.onPaint(onPaintHandler);
            elements.push((menu : glaze.IntoElement).intoAnyElement());
        }
        return elements;
    }

}
