// Ported from gpui-kit 0.8.1: crates/base/src/plot/mod.rs (Plot, origin_point, polygon),
// crates/component-macros/src/derive_into_plot.rs (IntoPlot)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.plot;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Component;
import glaze.ElementId;
import glaze.IntoElement;
import glaze.Path;
import glaze.PathBuilder;
import glaze.Point;
import glaze.SpringMath;
import glaze.Window;

/**
 * Unstyled plotting (Rust trait `Plot`): a plot paints itself into the
 * bounds of the `PlotElement` it becomes, which tracks its appear and hover.
 *
 * Extend this class and override `paint` (the trait's default methods are
 * the defaults here). A plot is an element through `render`, which wraps it
 * in a `PlotElement` (what Rust's `#[derive(IntoPlot)]` writes).
 *
 * Renamed trait methods, which clash with the builders of the charts:
 * `id` is `plotId`, `interactive` is `isInteractive`, `appear` is
 * `updateAppear` and `hover` is `updateHover`.
 */
abstract class Plot extends Component {

    public function new() {
        super();
    }

    /**
     * Lay out and place the child elements this plot hosts (e.g. element
     * labels). Called during the element's prepaint phase, before
     * `tooltipState` and `tooltip`. The returned elements are painted right
     * after `paint`, below the tooltip overlay. The default returns none.
     */
    public function prepaint(bounds:Bounds, window:Window, cx:App):Array<AnyElement> {
        return [];
    }

    public abstract function paint(bounds:Bounds, window:Window, cx:App):Void;

    /**
     * A stable element id that keeps this plot's state across frames (Rust
     * `Plot::id`). `null` (the default) leaves the plot a pure element that
     * neither appears nor tracks hover.
     */
    public function plotId():Null<ElementId> {
        return null;
    }

    /**
     * Whether a plot with a `plotId` tracks hover and shows its tooltip
     * (Rust `Plot::interactive`). The default is `true`.
     */
    public function isInteractive():Bool {
        return true;
    }

    /**
     * Receive how far the plot's data marks have appeared this frame, before
     * `updateHover` and `paint` run (Rust `Plot::appear`).
     */
    public function updateAppear(appear:PlotAppear, window:Window, cx:App):Void {}

    /**
     * Opt in to appear motion: non-null draws the plot in the first time its
     * id is painted, and again whenever the value changes. The default,
     * `null`, tracks no appear. Rust's `u64` generation is a string here.
     */
    public function appearGeneration():Null<String> {
        return null;
    }

    /**
     * Map the cursor (relative to the plot's origin) to the tooltip state to
     * display, or `null` to show nothing. Only called while the cursor is
     * inside `bounds`.
     */
    public function tooltipState(position:Point, bounds:Bounds, cx:App):Null<TooltipState> {
        return null;
    }

    /**
     * Receive the hovered datum this frame, before `tooltip` and `paint` run
     * (Rust `Plot::hover`). It lingers after the cursor leaves while its
     * progress eases back to zero; `null` means nothing is hovered and
     * nothing is fading.
     */
    public function updateHover(hover:Null<PlotHover>, window:Window, cx:App):Void {}

    /**
     * Render the tooltip overlay for the active `TooltipState`, painted above
     * the plot graphics. `cursor` is the live cursor position (relative to
     * the plot origin). The default returns `null`.
     */
    public function tooltip(state:TooltipState, cursor:Point, bounds:Bounds, window:Window, cx:App):Null<AnyElement> {
        return null;
    }

    /**
     * The `PlotElement` this plot paints in (Rust `#[derive(IntoPlot)]`).
     */
    public function render(window:Window, cx:App):IntoElement {
        return new PlotElement(this);
    }

    /**
     * `point(x, y) + origin` (Rust `origin_point`), in `f32`.
     */
    public static inline function originPoint(x:Float, y:Float, origin:Point):Point {
        return new Point(SpringMath.f32(x + origin.x), SpringMath.f32(y + origin.y));
    }

    /**
     * A 1px stroke through `points` (relative to the bounds origin), not
     * closed (Rust `polygon`).
     */
    public static function polygon(points:Array<Point>, bounds:Bounds):Null<Path> {
        final path = PathBuilder.stroke(1.);
        final moved = [
            for (p in points) new Point(SpringMath.f32(SpringMath.f32(p.x) + bounds.origin.x), SpringMath.f32(SpringMath.f32(p.y) + bounds.origin.y))
        ];
        path.addPolygon(moved, false);
        return buildPath(path);
    }

    /**
     * `builder.build().ok()`: the path, or `null` when it cannot be built.
     */
    public static function buildPath(builder:PathBuilder):Null<Path> {
        try {
            return builder.build();
        }
        catch (_:Dynamic) {
            return null;
        }
    }

}
