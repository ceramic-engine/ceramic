// Ported from gpui-kit 0.8.1: crates/base/src/plot/element.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.plot;

import glaze.AnyElement;
import glaze.App;
import glaze.AvailableSpace;
import glaze.Bounds;
import glaze.Element;
import glaze.ElementId;
import glaze.GlobalElementId;
import glaze.Hitbox;
import glaze.Length;
import glaze.LayoutId;
import glaze.MouseMoveEvent;
import glaze.Point;
import glaze.SizeOf;
import glaze.SpringMath;
import glaze.Style;
import glaze.Window;

import glaze.Prelude.relative;

/**
 * Paints a `Plot` filling its container, with appear tracking when the plot
 * has a `plotId`, and hover tracking and the plot's tooltip overlay when it
 * is also interactive.
 *
 * A plot becomes an element through this type (`Plot.render` makes one, like
 * Rust's `#[derive(IntoPlot)]`).
 *
 * On iOS and Android (Ceramic's `ios` and `android` targets, like the
 * original's `target_os`), a long press shows the tooltip instead of hover;
 * elsewhere, the web on a touch screen included, the pointer hover path is
 * used.
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

            #if (ios || android)
            // A finger has no hover: only a long press opens the tooltip,
            // drags the crosshair, and closes it on lift.
            window.onMouseEvent(LongPress, (e, phase, window, cx) -> {
                final e:glaze.LongPressEvent = cast e;
                if (!phase.bubble()) {
                    return;
                }
                final next:Null<Point> = switch e.phase {
                    case Started:
                        if (window.defaultPrevented() || !hitbox.isHovered(window)) {
                            return;
                        }
                        window.preventDefault();
                        relativeTo(e.startPosition, bounds.origin);
                    case Moved:
                        if (cell.value == null) {
                            return;
                        }
                        relativeTo(e.position, bounds.origin);
                    case Ended | Cancelled:
                        null;
                };
                if (!samePoint(cell.value, next)) {
                    cell.value = next;
                    cx.notify(view);
                }
            });
            #else
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
            #end
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
