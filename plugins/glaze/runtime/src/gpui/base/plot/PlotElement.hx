// Ported from gpui-kit 0.8.1: crates/base/src/plot/element.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.plot;

import gpui.AnyElement;
import gpui.App;
import gpui.AvailableSpace;
import gpui.Bounds;
import gpui.Element;
import gpui.ElementId;
import gpui.GlobalElementId;
import gpui.Hitbox;
import gpui.Length;
import gpui.LayoutId;
import gpui.MouseMoveEvent;
import gpui.Point;
import gpui.SizeOf;
import gpui.SpringMath;
import gpui.Style;
import gpui.Window;

import gpui.Prelude.relative;

/**
 * Paints a `Plot` filling its container, with appear tracking when the plot
 * has a `plotId`, and hover tracking and the plot's tooltip overlay when it
 * is also interactive.
 *
 * A plot becomes an element through this type (`Plot.render` makes one, like
 * Rust's `#[derive(IntoPlot)]`).
 *
 * Touch input (the long press of iOS and Android) is not ported, like the
 * rest of the port's touch gestures: the pointer hover path is used.
 */
class PlotElement extends Element {

    final plot:Plot;

    /** The occlusion-aware hitbox, carried from `prepaint` to `paint`. */
    var hitbox:Null<Hitbox> = null;

    /** The plot's prepainted children. */
    var children:Array<AnyElement> = [];

    /** The prepainted tooltip overlay. */
    var overlay:Null<AnyElement> = null;

    public function new(plot:Plot) {
        this.plot = plot;
    }

    /** The last cursor position (plot-relative), shared by `prepaint` and `paint`. */
    static function tooltipCursor(globalId:GlobalElementId, window:Window):CursorCell {
        return window.withElementState(globalId, CursorCell, (state, _) -> {
            if (state.value == null) {
                state.value = new CursorCell();
            }
            return state.value;
        });
    }

    override function elementId():Null<ElementId> {
        // Non-null gives the plot element state: appear motion and, when
        // interactive, tooltips.
        return plot.plotId();
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final style = new Style();
        style.sizeWidth = Length.Definite(relative(1.));
        style.sizeHeight = Length.Definite(relative(1.));
        return window.requestLayout(style, null, cx);
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        // Children are laid out here, where `layoutAsRoot` / `prepaintAt` are
        // legal, and before the early return so plots without an id still
        // get them.
        children = plot.prepaint(bounds, window, cx);
        hitbox = null;
        overlay = null;

        if (globalId == null) {
            return;
        }

        final generation = plot.appearGeneration();
        final appear = generation != null ? PlotAppear.trackAppear(globalId, generation, window, cx) : PlotAppear.complete();
        final appearing = appear.isAppearing();
        plot.updateAppear(appear, window, cx);

        if (!plot.isInteractive()) {
            return;
        }

        // `Hitbox.isHovered` is false while an open popup or modal covers the plot.
        hitbox = window.insertHitbox(bounds, Normal);

        // The cell only gates visibility; the position comes from the live
        // mouse and this frame's bounds so the tooltip does not lag a frame
        // while scrolling.
        var cursor:Null<Point> = null;
        if (tooltipCursor(globalId, window).value != null) {
            final mouse = window.mousePosition();
            if (bounds.contains(mouse)) {
                cursor = relativeTo(mouse, bounds.origin);
            }
        }
        // No tooltip while the marks draw in: its dots would land on data
        // not painted yet.
        final live = cursor != null && !appearing ? plot.tooltipState(cursor, bounds, cx) : null;

        // The datum under the cursor, or the last one while its hover fades out.
        final hover = PlotHover.trackHover(live, cursor, window, cx);
        plot.updateHover(hover != null ? hover.hover : null, window, cx);

        if (hover != null) {
            final element = plot.tooltip(hover.hover.state(), hover.cursor, bounds, window, cx);
            if (element != null) {
                element.prepaintAsRoot(bounds.origin, new SizeOf<AvailableSpace>(Definite(bounds.size.width), Definite(bounds.size.height)), window, cx);
                overlay = element;
            }
        }
    }

    public function paint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        plot.paint(bounds, window, cx);

        for (child in children) {
            child.paint(window, cx);
        }

        final hitbox = this.hitbox;
        if (globalId != null && hitbox != null) {
            final cell = tooltipCursor(globalId, window);
            // Notify only the view painting this plot: `window.refresh()`
            // would drop every sibling view's cache on each pixel of mouse
            // movement.
            final view = window.currentView();

            // Relayout can move the plot under a still cursor without a move
            // event, so re-derive hover each frame; only a visibility flip
            // needs a corrective frame.
            final next = hitbox.isHovered(window) ? relativeTo(window.mousePosition(), bounds.origin) : null;
            if (!samePoint(cell.value, next)) {
                final visibilityChanged = (cell.value != null) != (next != null);
                cell.value = next;
                if (visibilityChanged) {
                    window.requestAnimationFrame();
                }
            }

            window.onMouseEvent(MouseMove, (event, _, window, cx) -> {
                final event:MouseMoveEvent = cast event;
                final next = hitbox.isHovered(window) ? relativeTo(event.position, bounds.origin) : null;
                if (!samePoint(cell.value, next)) {
                    cell.value = next;
                    cx.notify(view);
                }
            });
        }

        // Crosshair and dots paint above the plot; the deferred box paints
        // above everything.
        if (overlay != null) {
            overlay.paint(window, cx);
        }
    }

    static inline function relativeTo(p:Point, origin:Point):Point {
        return new Point(SpringMath.f32(p.x - origin.x), SpringMath.f32(p.y - origin.y));
    }

    static function samePoint(a:Null<Point>, b:Null<Point>):Bool {
        if (a == null || b == null) {
            return a == null && b == null;
        }
        return a.x == b.x && a.y == b.y;
    }

}

/**
 * The last cursor position of a plot (Rust `Rc<Cell<Option<Point>>>`).
 */
@:keep
class CursorCell {

    public var value:Null<Point> = null;

    public function new() {}

}
