// Ported from gpui-kit 0.8.1: crates/component/src/chart/radar_chart.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.chart;

import glaze.AnyElement;
import glaze.App;
import glaze.AvailableSpace;
import glaze.Background;
import glaze.Bounds;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Hsla;
import glaze.IntoBackground;
import glaze.IntoElement;
import glaze.IntoHsla;
import glaze.Point;
import glaze.SizeOf;
import glaze.SpringMath;
import glaze.TextAlign;
import glaze.Window;
import glaze.kit.base.plot.Plot;
import glaze.kit.base.plot.PlotAppear;
import glaze.kit.base.plot.PlotLabel;
import glaze.kit.base.plot.PlotLabel.Text;
import glaze.kit.base.plot.TooltipState;
import glaze.kit.base.plot.scale.ScaleLinear;
import glaze.kit.base.plot.shape.Arc;
import glaze.kit.base.plot.shape.RadialLine;
import glaze.kit.chart.Chart.ChartAppear;
import glaze.kit.chart.Chart.TooltipContent;
import glaze.kit.plot.Tooltip;
import glaze.kit.plot.Tooltip.Dot;
import glaze.kit.theme.Theme;

/**
 * The label of a radar dimension: text the chart draws, or an element it
 * lays out beside the ring.
 */
enum RadarLabelKind {
    Text(text:String);
    Element(element:AnyElement);
}

/**
 * A `RadarLabelKind` from a string or an element (Rust `RadarLabel` and its
 * `From` conversions).
 *
 * A null string or element converts to a null label. A null label (or a
 * `Text(null)` / `Element(null)` kind) is no label for that dimension: its
 * spoke and values are drawn as usual, no text is drawn and no element is
 * laid out, and its tooltip has no label title, exactly like a chart built
 * without `label()` (a convenience beyond Rust, like `child(null)`).
 */
abstract RadarLabel(RadarLabelKind) from RadarLabelKind to RadarLabelKind {

    @:from static inline function fromString(text:String):RadarLabel {
        return text != null ? Text(text) : null;
    }

    @:from static inline function fromElement(element:AnyElement):RadarLabel {
        return element != null ? Element(element) : null;
    }

    public inline function kind():RadarLabelKind {
        return this;
    }

}

/**
 * A radar chart: one or more series of `Float` values around the axes of
 * its data's dimensions (Rust `RadarChart<T, Y>`).
 */
class RadarChart<T> extends Plot {

    static inline final DEFAULT_LABEL_GAP:Float = 10.;

    static inline final DEFAULT_GRID_LEVELS:Int = 4;

    @:allow(tests) final data:Array<T>;

    @:allow(tests) final values:Array<(T) -> Float> = [];

    @:allow(tests) final strokes:Array<Hsla> = [];

    @:allow(tests) final fills:Array<Background> = [];

    @:allow(tests) final names:Array<String> = [];

    final tooltipContentValue:TooltipContent<T> = new TooltipContent();

    @:allow(tests) var labelFn:Null<(T) -> RadarLabel> = null;

    var labelTexts:Array<Null<String>> = [];

    var labelColorValue:Null<Hsla> = null;

    @:allow(tests) var labelGapValue:Float = DEFAULT_LABEL_GAP;

    @:allow(tests) var maxValueValue:Null<Float> = null;

    @:allow(tests) var outerRadiusValue:Float = 0.;

    @:allow(tests) var gridValue:Bool = true;

    @:allow(tests) var gridLevelsValue:Int = DEFAULT_GRID_LEVELS;

    @:allow(tests) var dotValue:Bool = false;

    @:allow(tests) var idValue:ElementId;

    var interactiveValue:Bool = true;

    final appearValue:ChartAppear = new ChartAppear();

    public function new(data:Iterable<T>, ?pos:haxe.PosInfos) {
        super();
        this.data = glaze.util.Iterables.toArray(data);
        idValue = Chart.callerId(pos);
    }

    /** Name this chart's `ElementId`, replacing the default taken from the construction site. */
    public function id(id:ElementIdArg):RadarChart<T> {
        idValue = id;
        return this;
    }

    /** Turn this chart's interactive layer on or off. On by default. */
    public function interactive(interactive:Bool):RadarChart<T> {
        interactiveValue = interactive;
        return this;
    }

    /** Draw the data in the first time this chart is painted. On by default. */
    public function appear(appear:Bool):RadarChart<T> {
        appearValue.setEnabled(appear);
        return this;
    }

    /** Draw the data in again whenever `key` changes. */
    public function appearKey(key:String):RadarChart<T> {
        appearValue.setKey(key);
        return this;
    }

    /** Add the name of the next series, shown in its tooltip row. */
    public function name(name:String):RadarChart<T> {
        names.push(name);
        return this;
    }

    /** Set the hover tooltip's title for a datum, instead of its label. */
    public function tooltipTitle(title:(T) -> String):RadarChart<T> {
        tooltipContentValue.setTitle(title);
        return this;
    }

    /** Set the text of each tooltip row's value; the raw number by default. */
    public function tooltipValue(value:(T, Int, Float) -> String):RadarChart<T> {
        tooltipContentValue.setValue(value);
        return this;
    }

    /** Color each tooltip row's value; the tooltip's text color by default. */
    public function tooltipValueColor(color:(T, Int, Float) -> IntoHsla):RadarChart<T> {
        tooltipContentValue.setValueColor((d, ix, v) -> (color(d, ix, v) : Hsla));
        return this;
    }

    /** Draw the tooltip box's content for a datum yourself, in place of the title and rows. */
    public function tooltipContent(content:(T, Window, App) -> IntoElement):RadarChart<T> {
        tooltipContentValue.setContent(content);
        return this;
    }

    /** Add a series. */
    public function value(value:(T) -> Float):RadarChart<T> {
        values.push(value);
        return this;
    }

    public function stroke(stroke:IntoHsla):RadarChart<T> {
        strokes.push(stroke);
        return this;
    }

    public function fill(fill:IntoBackground):RadarChart<T> {
        fills.push(fill);
        return this;
    }

    /** Label each dimension with text or an element. */
    public function label(label:(T) -> RadarLabel):RadarChart<T> {
        labelFn = label;
        return this;
    }

    public function labelColor(color:IntoHsla):RadarChart<T> {
        labelColorValue = color;
        return this;
    }

    public function labelGap(gap:Float):RadarChart<T> {
        labelGapValue = f(gap);
        return this;
    }

    public function maxValue(maxValue:Float):RadarChart<T> {
        maxValueValue = maxValue;
        return this;
    }

    public function outerRadius(outerRadius:Float):RadarChart<T> {
        outerRadiusValue = f(outerRadius);
        return this;
    }

    public function grid(grid:Bool):RadarChart<T> {
        gridValue = grid;
        return this;
    }

    public function gridLevels(gridLevels:Int):RadarChart<T> {
        gridLevelsValue = gridLevels > 1 ? gridLevels : 1;
        return this;
    }

    public function dot():RadarChart<T> {
        dotValue = true;
        return this;
    }

    function seriesStroke(ix:Int, cx:App):Hsla {
        return seriesStrokeFrom(palette(cx), ix);
    }

    static function palette(cx:App):Array<Hsla> {
        final theme = Theme.global(cx);
        return [theme.chart1, theme.chart2, theme.chart3, theme.chart4, theme.chart5];
    }

    function seriesStrokeFrom(palette:Array<Hsla>, ix:Int):Hsla {
        return ix < strokes.length ? strokes[ix] : palette[ix % palette.length];
    }

    function resolveOuterRadius(bounds:Bounds):Float {
        return outerRadiusValue == 0. ? f(bounds.size.height * f(0.4)) : outerRadiusValue;
    }

    function labelAnchor(ix:Int, outerRadius:Float, bounds:Bounds):{anchor:Point, direction:Point} {
        final labelRadius = f(outerRadius + labelGapValue);
        final angle = f(f(f(ix * Arc.TAU) / data.length) - Arc.HALF_PI);
        final direction = new Point(Arc.cos(angle), Arc.sin(angle));

        final anchor = new Point(
            f(f(bounds.size.width / 2.) + f(labelRadius * direction.x)),
            f(f(bounds.size.height / 2.) + f(labelRadius * direction.y))
        );

        return {anchor: anchor, direction: direction};
    }

    function scale(outerRadius:Float):ScaleLinear {
        final domain:Array<Float> = maxValueValue != null ? [0., maxValueValue] : {
            final list = [for (d in data) for (valueFn in values) valueFn(d)];
            list.push(0.);
            list;
        };
        return new ScaleLinear(domain, [0., outerRadius]);
    }

    @:allow(tests)
    function hoveredIndex(position:Point, bounds:Bounds):Null<Int> {
        final n = data.length;
        if (n == 0) {
            return null;
        }

        final outerRadius = resolveOuterRadius(bounds);
        final dx = f(position.x - f(bounds.size.width / 2.));
        final dy = f(position.y - f(bounds.size.height / 2.));
        if (Arc.hypot(dx, dy) > f(outerRadius + labelGapValue)) {
            return null;
        }

        // Screen angle -> chart angle (0 at 12 o'clock, clockwise).
        final angle = Arc.remEuclid(f(f(Math.atan2(dy, dx)) + Arc.HALF_PI), Arc.TAU);
        final rounded = glaze.util.MathUtil.round(f(f(angle * n) / Arc.TAU));
        return Std.int(rounded) % n;
    }

    override public function prepaint(bounds:Bounds, window:Window, cx:App):Array<AnyElement> {
        labelTexts = [];

        // Same guard as `paint`: without a series nothing is drawn at all.
        final n = data.length;
        if (n == 0 || values.length == 0) {
            return [];
        }
        if (labelFn == null) {
            return [];
        }
        final labelFn = this.labelFn;

        final outerRadius = resolveOuterRadius(bounds);
        final texts:Array<Null<String>> = [];
        final elements:Array<AnyElement> = [];

        for (ix in 0...data.length) {
            final label = labelFn(data[ix]);
            // A null label is no label: nothing drawn, no tooltip title.
            if (label == null) {
                texts.push(null);
                continue;
            }
            switch label.kind() {
                case Text(text):
                    texts.push(text);
                case Element(null):
                    texts.push(null);
                case Element(element):
                    texts.push(null);

                    // Only definite space makes text wrap, so this measures
                    // the label at its natural, unwrapped size.
                    final size = element.layoutAsRoot(new SizeOf<AvailableSpace>(MinContent, MinContent), window, cx);
                    final placed = labelAnchor(ix, outerRadius, bounds);
                    final anchor = placed.anchor;
                    final direction = placed.direction;

                    // Push the box radially outward until its inner edge
                    // meets the anchor, so a tall label clears the ring.
                    final origin = new Point(
                        f(bounds.origin.x + f(anchor.x + f(f(f(direction.x - 1.) * size.width) / 2.))),
                        f(bounds.origin.y + f(anchor.y + f(f(f(direction.y - 1.) * size.height) / 2.)))
                    );

                    element.prepaintAt(origin, window, cx);
                    elements.push(element);
            }
        }

        labelTexts = texts;

        return elements;
    }

    public function paint(bounds:Bounds, window:Window, cx:App):Void {
        final n = data.length;
        if (n == 0 || values.length == 0) {
            return;
        }
        final theme = Theme.global(cx);

        final outerRadius = resolveOuterRadius(bounds);
        final angleStep = f(Arc.TAU / n);
        final centerX = f(bounds.size.width / 2.);
        final centerY = f(bounds.size.height / 2.);
        final scale = scale(outerRadius);

        // Draw grid rings and spokes
        if (gridValue) {
            final stroke = theme.chartGrid;

            for (level in 1...gridLevelsValue + 1) {
                final radius = f(f(outerRadius * level) / gridLevelsValue);
                new RadialLine<Int>()
                    .data([for (i in 0...n) i])
                    .angle((_, i) -> f(i * angleStep))
                    .radius((_, _) -> radius)
                    .closed()
                    .stroke(stroke)
                    .paint(bounds, window);
            }

            for (i in 0...n) {
                final angle = f(f(i * angleStep) - Arc.HALF_PI);
                final points = [
                    new Point(centerX, centerY),
                    new Point(f(centerX + f(outerRadius * Arc.cos(angle))), f(centerY + f(outerRadius * Arc.sin(angle)))),
                ];
                final path = Plot.polygon(points, bounds);
                if (path != null) {
                    window.paintPath(path, stroke);
                }
            }
        }

        // Draw series. They grow out of the center as the chart appears.
        final appear = appearValue.get().progress();
        for (i in 0...values.length) {
            final valueFn = values[i];
            final stroke = seriesStroke(i, cx);
            final fill = i < fills.length ? fills[i] : Background.fromHsla(stroke.opacity(0.3));

            var line = new RadialLine<T>()
                .data(data)
                .angle((_, i) -> f(i * angleStep))
                .radius((d, _) -> {
                    final r = scale.tick(valueFn(d));
                    r != null ? f(r * appear) : null;
                })
                .closed()
                .fill(fill)
                .stroke(stroke)
                .strokeWidth(2.);
            if (dotValue) {
                line = line.dot().dotSize(8.).dotFill(stroke);
            }
            line.paint(bounds, window);
        }

        // Draw the text labels outside the outer ring; `prepaint` resolved
        // them and already placed the element ones.
        final labelColor = labelColorValue != null ? labelColorValue : theme.mutedForeground;
        final labels:Array<Text> = [];
        for (ix in 0...labelTexts.length) {
            final text = labelTexts[ix];
            if (text == null) continue;
            final placed = labelAnchor(ix, outerRadius, bounds);
            final anchor = placed.anchor;
            final direction = placed.direction;

            // Labels on the right are left-aligned, on the left
            // right-aligned, and near the vertical axis centered.
            final align:TextAlign = direction.x > f(1e-3) ? Left : (direction.x < f(-1e-3) ? Right : Center);

            labels.push(new Text(text, new Point(anchor.x, f(anchor.y - PlotLabel.TEXT_SIZE / 2.)), labelColor).withAlign(align));
        }

        new PlotLabel(labels).paint(bounds, window, cx);
    }

    override public function plotId():Null<ElementId> {
        return idValue;
    }

    override public function isInteractive():Bool {
        return interactiveValue;
    }

    override public function updateAppear(appear:PlotAppear, window:Window, cx:App):Void {
        appearValue.update(appear);
    }

    override public function appearGeneration():Null<String> {
        return appearValue.generation();
    }

    override public function tooltipState(position:Point, bounds:Bounds, cx:App):Null<TooltipState> {
        if (values.length == 0) {
            return null;
        }
        final index = hoveredIndex(position, bounds);
        if (index == null || index >= data.length) {
            return null;
        }
        final d = data[index];

        final outerRadius = resolveOuterRadius(bounds);
        final scale = scale(outerRadius);
        final centerX = f(bounds.size.width / 2.);
        final centerY = f(bounds.size.height / 2.);
        final angle = f(f(f(index * Arc.TAU) / data.length) - Arc.HALF_PI);

        // One dot per series at the hovered dimension's vertex.
        final dots:Array<Point> = [];
        for (valueFn in values) {
            final radius = scale.tick(valueFn(d));
            if (radius == null) continue;
            dots.push(new Point(f(centerX + f(radius * Arc.cos(angle))), f(centerY + f(radius * Arc.sin(angle)))));
        }

        return new TooltipState(index, position, dots);
    }

    override public function tooltip(state:TooltipState, cursor:Point, bounds:Bounds, window:Window, cx:App):Null<AnyElement> {
        if (state.index >= data.length) {
            return null;
        }
        final d = data[state.index];
        final dotStroke = Theme.global(cx).background;

        // No crosshair: a radar has no cartesian axis to snap to; the dots
        // mark the hovered dimension's vertices instead.
        final tooltip = new Tooltip(cursor, bounds.size)
            .gap(8.)
            .dots([
                for (i in 0...state.dots.length)
                    new Dot(state.dots[i])
                        .size(Chart.HOVER_DOT_SIZE)
                        .halo(Chart.HOVER_HALO_SIZE)
                        .stroke(dotStroke)
                        .fill(seriesStroke(i, cx))
            ]);

        final palette = palette(cx);
        final result = tooltipContentValue.apply(
            tooltip,
            d,
            // Filled by `prepaint`, which runs first; element labels leave no title.
            () -> state.index < labelTexts.length ? labelTexts[state.index] : null,
            // One row per series: swatch + label + value.
            () -> [
                for (i in 0...values.length) {swatch: seriesStrokeFrom(palette, i), name: i < names.length ? names[i] : '', value: values[i](d)}
            ],
            window,
            cx
        );
        return result != null ? (result : IntoElement).intoAnyElement() : null;
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}
