// Ported from gpui-kit 0.8.1: crates/component/src/chart/pie_chart.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.chart;

import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.IntoHsla;
import gpui.Point;
import gpui.SpringMath;
import gpui.TextAlign;
import gpui.Window;
import gpui.base.motion.Motion;
import gpui.base.plot.PathCache.PathCaches;
import gpui.base.plot.Plot;
import gpui.base.plot.PlotAppear;
import gpui.base.plot.PlotHover;
import gpui.base.plot.PlotLabel;
import gpui.base.plot.PlotLabel.Text;
import gpui.base.plot.TooltipState;
import gpui.base.plot.shape.Arc;
import gpui.base.plot.shape.Arc.ArcData;
import gpui.base.plot.shape.Pie;
import gpui.component.chart.Chart.ChartAppear;
import gpui.component.plot.Tooltip;
import gpui.component.theme.Theme;

private class PieHover {

    public final lift:Array<Float>;

    public final focus:Float;

    public function new(lift:Array<Float>, focus:Float) {
        this.lift = lift;
        this.focus = focus;
    }

}

/**
 * A leader-line label candidate of a slice.
 */
private class LabelLayout {

    public final arcX:Float;

    public final arcY:Float;

    public final labelX:Float;

    public var y:Float;

    public final text:String;

    public final lineColor:Hsla;

    public function new(arcX:Float, arcY:Float, labelX:Float, y:Float, text:String, lineColor:Hsla) {
        this.arcX = arcX;
        this.arcY = arcY;
        this.labelX = labelX;
        this.y = y;
        this.text = text;
        this.lineColor = lineColor;
    }

}

/**
 * A pie (or donut) chart: one slice per datum (Rust `PieChart<T>`).
 */
class PieChart<T> extends Plot {

    static inline final DEFAULT_LABEL_GAP:Float = 15.;

    /** How far the hovered slice lifts out of the ring, in pixels. */
    static inline final HOVER_LIFT:Float = 6.;

    /** How much the slices away from the hovered one fade. */
    static final HOVER_DIM:Float = SpringMath.f32(0.35);

    /** Where in the sweep the labels start fading in. */
    static final LABEL_APPEAR_START:Float = SpringMath.f32(0.7);

    final data:Array<T>;

    var innerRadiusValue:Float = 0.;

    var innerRadiusFnValue:Null<(ArcData<T>) -> Float> = null;

    var outerRadiusValue:Float = 0.;

    var outerRadiusFnValue:Null<(ArcData<T>) -> Float> = null;

    var padAngleValue:Float = 0.;

    var valueFn:Null<(T) -> Float> = null;

    var colorFn:Null<(T) -> Hsla> = null;

    @:allow(tests)
    var labelFn:Null<(T) -> String> = null;

    var labelLineColorFn:Null<(T) -> Hsla> = null;

    var labelColorValue:Null<Hsla> = null;

    var labelGapValue:Float = DEFAULT_LABEL_GAP;

    @:allow(tests)
    var tooltipNameFn:Null<(T) -> String> = null;

    var tooltipValueFn:Null<(T, Float, Float) -> String> = null;

    var idValue:ElementId;

    var interactiveValue:Bool = true;

    final appearValue:ChartAppear = new ChartAppear();

    var nameValue:Null<String> = null;

    var hover:Null<PieHover> = null;

    public function new(data:Iterable<T>, ?pos:haxe.PosInfos) {
        super();
        this.data = gpui.util.Iterables.toArray(data);
        idValue = Chart.callerId(pos);
    }

    /** Name this chart's `ElementId`, replacing the default taken from the construction site. */
    public function id(id:ElementIdArg):PieChart<T> {
        idValue = id;
        return this;
    }

    /** Turn this chart's interactive layer on or off. On by default. */
    public function interactive(interactive:Bool):PieChart<T> {
        interactiveValue = interactive;
        return this;
    }

    /** Draw the data in the first time this chart is painted. On by default. */
    public function appear(appear:Bool):PieChart<T> {
        appearValue.setEnabled(appear);
        return this;
    }

    /** Draw the data in again whenever `key` changes. */
    public function appearKey(key:String):PieChart<T> {
        appearValue.setKey(key);
        return this;
    }

    /** Set the name shown in the tooltip row when no `tooltipName` is set. */
    public function name(name:String):PieChart<T> {
        nameValue = name;
        return this;
    }

    public function innerRadius(innerRadius:Float):PieChart<T> {
        innerRadiusValue = f(innerRadius);
        return this;
    }

    /** Set the inner radius of each slice from its arc. */
    public function innerRadiusFn(innerRadius:(ArcData<T>) -> Float):PieChart<T> {
        innerRadiusFnValue = innerRadius;
        return this;
    }

    function getInnerRadius(arc:ArcData<T>):Float {
        return innerRadiusFnValue != null ? f(innerRadiusFnValue(arc)) : innerRadiusValue;
    }

    public function outerRadius(outerRadius:Float):PieChart<T> {
        outerRadiusValue = f(outerRadius);
        return this;
    }

    /** Set the outer radius of each slice from its arc. */
    public function outerRadiusFn(outerRadius:(ArcData<T>) -> Float):PieChart<T> {
        outerRadiusFnValue = outerRadius;
        return this;
    }

    @:allow(tests)
    function getOuterRadius(arc:ArcData<T>, fallback:Float):Float {
        return outerRadiusFnValue != null ? f(outerRadiusFnValue(arc)) : fallback;
    }

    public function padAngle(padAngle:Float):PieChart<T> {
        padAngleValue = f(padAngle);
        return this;
    }

    public function value(value:(T) -> Float):PieChart<T> {
        valueFn = value;
        return this;
    }

    public function color(color:(T) -> IntoHsla):PieChart<T> {
        colorFn = t -> (color(t) : Hsla);
        return this;
    }

    /** Draw a leader-line label outside the ring for each slice. */
    public function label(label:(T) -> String):PieChart<T> {
        labelFn = label;
        return this;
    }

    public function labelLineColor(color:(T) -> Hsla):PieChart<T> {
        labelLineColorFn = color;
        return this;
    }

    public function labelColor(color:IntoHsla):PieChart<T> {
        labelColorValue = color;
        return this;
    }

    public function labelGap(gap:Float):PieChart<T> {
        labelGapValue = f(gap);
        return this;
    }

    /** Set the name of a slice's tooltip row. */
    public function tooltipName(name:(T) -> String):PieChart<T> {
        tooltipNameFn = name;
        return this;
    }

    /**
     * Set the text of a slice's tooltip value from the datum, its value and
     * its share in percent; `"{value} ({share:.1}%)"` by default.
     */
    public function tooltipValue(value:(T, Float, Float) -> String):PieChart<T> {
        tooltipValueFn = value;
        return this;
    }

    @:allow(tests)
    function resolveOuterRadius(bounds:Bounds):Float {
        return outerRadiusValue == 0. ? f(bounds.size.height * f(0.4)) : outerRadiusValue;
    }

    @:allow(tests)
    function arcs():Array<ArcData<T>> {
        if (valueFn == null) {
            return [];
        }
        final valueFn = this.valueFn;
        return new Pie<T>().value(d -> valueFn(d)).padAngle(padAngleValue).arcs(data);
    }

    function sliceColor(datum:T, cx:App):Hsla {
        return colorFn != null ? colorFn(datum) : Theme.global(cx).chart2;
    }

    function sliceEmphasis(index:Int):Array<Float> {
        if (hover == null) {
            return [0., 1.];
        }
        final lift = f((index < hover.lift.length ? hover.lift[index] : 0.) * hover.focus);
        return [lift, f(1. - f(f(HOVER_DIM * hover.focus) * f(1. - lift)))];
    }

    public function paint(bounds:Bounds, window:Window, cx:App):Void {
        if (valueFn == null) {
            return;
        }
        final theme = Theme.global(cx);

        final outerRadius = resolveOuterRadius(bounds);
        final arcs = arcs();

        // The ring sweeps clockwise from its first slice as the chart
        // appears. Every frame of the sweep is a new shape, so the slices
        // tessellate afresh until it ends rather than churn the cache.
        final appear = appearValue.get().progress();
        var slices = arcs;
        if (appear < 1.) {
            slices = this.arcs();
            final start = slices.length > 0 ? slices[0].startAngle : 0.;
            for (a in slices) {
                a.startAngle = f(start + f(f(a.startAngle - start) * appear));
                a.endAngle = f(start + f(f(a.endAngle - start) * appear));
            }
        }
        final caches = appear >= 1. ? PathCaches.forPaint('slices', window, cx) : null;
        for (ix in 0...slices.length) {
            final a = slices[ix];
            final innerRadius = getInnerRadius(a);
            // The hovered slice lifts out of the ring while the others fade behind it.
            final emphasis = sliceEmphasis(a.index);
            final sliceRadius = f(getOuterRadius(a, outerRadius) + f(HOVER_LIFT * emphasis[0]));
            final color = sliceColor(a.data, cx).opacity(emphasis[1]);
            final arc = new Arc().innerRadius(innerRadius).outerRadius(sliceRadius);
            if (caches != null) {
                arc.paintCached(a, color, bounds, caches.slot(ix), window);
            }
            else {
                arc.paint(a, color, bounds, window);
            }
        }

        // Draw leader-line labels outside the ring (only when `label` is set).
        if (labelFn == null) {
            return;
        }
        final labelFn = this.labelFn;

        final labelRadius = f(outerRadius + labelGapValue);
        final centerX = f(bounds.size.width / 2.);
        final centerY = f(bounds.size.height / 2.);
        final labelArc = new Arc().innerRadius(labelRadius).outerRadius(labelRadius);

        // Labels fade in over the end of the sweep, once their slices are
        // mostly drawn.
        final labelOpacity = Math.max(f(f(appear - LABEL_APPEAR_START) / f(1. - LABEL_APPEAR_START)), 0.);
        if (labelOpacity <= 0.) {
            return;
        }
        final labelColor = (labelColorValue != null ? labelColorValue : theme.foreground).opacity(labelOpacity);
        final defaultLineColor = theme.border;

        // First pass: collect a layout candidate per visible slice, split by
        // side.
        final right:Array<LabelLayout> = [];
        final left:Array<LabelLayout> = [];
        for (a in arcs) {
            // Skip tiny slices (< 0.5 degree) that are too thin to label.
            if (f(a.endAngle - a.startAngle) < f(Arc.PI / 360.)) {
                continue;
            }

            final centroid = labelArc.centroid(a);
            // Anchor the line on the edge the slice reaches this frame, so a
            // lifted slice never paints over its own leader line.
            final emphasis = sliceEmphasis(a.index);
            final edgeRadius = Math.min(f(outerRadius + f(HOVER_LIFT * emphasis[0])), labelRadius);
            final edge = new Arc().innerRadius(edgeRadius).outerRadius(edgeRadius).centroid(a);
            final isRight = centroid.x > 0.;
            final lineColor = (labelLineColorFn != null ? labelLineColorFn(a.data) : defaultLineColor).opacity(labelOpacity);

            final layout = new LabelLayout(edge.x, edge.y, centroid.x, centroid.y, labelFn(a.data), lineColor);
            (isRight ? right : left).push(layout);
        }

        // Second pass: spread labels on each side so neighbors keep at least
        // one text height apart, clamped within the vertical bounds.
        final top = f(-centerY + PlotLabel.TEXT_HEIGHT / 2.);
        final bottom = f(centerY - PlotLabel.TEXT_HEIGHT / 2.);
        spreadLabels(right, top, bottom);
        spreadLabels(left, top, bottom);

        // Third pass: paint leader lines first, then the text on top.
        final labels:Array<Text> = [];
        for (pass in [{side: 1., items: right}, {side: -1., items: left}]) {
            final side = pass.side;
            for (item in pass.items) {
                // Leader line: ring edge -> label anchor -> horizontal pull
                // to +/-labelRadius.
                final points = [
                    new Point(f(item.arcX + centerX), f(item.arcY + centerY)),
                    new Point(f(item.labelX + centerX), f(item.y + centerY)),
                    new Point(f(f(side * labelRadius) + centerX), f(item.y + centerY)),
                ];
                final path = Plot.polygon(points, bounds);
                if (path != null) {
                    window.paintPath(path, item.lineColor);
                }

                // Text sits 4px further out, aligned by side.
                final origin = new Point(f(f(side * f(labelRadius + 4.)) + centerX), f(f(item.y - PlotLabel.TEXT_SIZE / 2.) + centerY));
                final align:TextAlign = side > 0. ? Left : Right;
                labels.push(new Text(item.text, origin, labelColor).withAlign(align));
            }
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
        final outerRadius = resolveOuterRadius(bounds);
        final p = new Point(f(position.x), f(position.y));

        for (a in arcs()) {
            if (new Arc().innerRadius(getInnerRadius(a)).outerRadius(getOuterRadius(a, outerRadius)).contains(a, p, bounds)) {
                return new TooltipState(a.index, new Point(p.x, p.y), []);
            }
        }
        return null;
    }

    override public function updateHover(hover:Null<PlotHover>, window:Window, cx:App):Void {
        if (hover == null) {
            this.hover = null;
            return;
        }
        // Every slice springs toward lifted or resting, so the one the cursor
        // left settles back while the new one rises. On the first hovered
        // frame the target is rest, so the slice rises from the ring.
        final policy = Theme.global(cx).motionTokens().springControl;
        final lift = [
            for (ix in 0...data.length) {
                final lifted = hover.isHovered() && !hover.isEntering() && ix == hover.state().index;
                Motion.spring(ElementId.NamedInteger('pie-slice', ix), lifted ? 1. : 0., policy, window, cx);
            }
        ];
        this.hover = new PieHover(lift, hover.progress());
    }

    override public function tooltip(state:TooltipState, cursor:Point, bounds:Bounds, window:Window, cx:App):Null<AnyElement> {
        if (valueFn == null || state.index >= data.length) {
            return null;
        }
        final valueFn = this.valueFn;
        final d = data[state.index];
        final value = f(valueFn(d));
        var total = 0.;
        for (datum in data) {
            total = f(total + Math.max(f(valueFn(datum)), 0.));
        }
        final share = total > 0. ? f(f(value / total) * 100.) : 0.;
        final name = tooltipNameFn != null ? tooltipNameFn(d) : (nameValue != null ? nameValue : '');

        // Follow the cursor; the lifted slice marks the datum. One number per
        // slice fits one row, so there is no title.
        final text = tooltipValueFn != null ? tooltipValueFn(d, value, share) : '${ChartFormat.display32(value)} (${ChartFormat.fixed(share, 1)}%)';
        final tooltip = new Tooltip(cursor, bounds.size).gap(8.).row(sliceColor(d, cx), name, text);
        return (tooltip : IntoElement).intoAnyElement();
    }

    static function spreadLabels(items:Array<LabelLayout>, top:Float, bottom:Float):Void {
        final n = items.length;
        if (n == 0) {
            return;
        }

        // Sort by target position so neighbors in the slice are neighbors in y.
        haxe.ds.ArraySort.sort(items, (a, b) -> a.y < b.y ? -1 : (a.y > b.y ? 1 : 0));

        // Top-down: enforce the minimum gap by pushing labels down.
        for (i in 1...n) {
            final minY = f(items[i - 1].y + PlotLabel.TEXT_HEIGHT);
            if (items[i].y < minY) {
                items[i].y = minY;
            }
        }

        // Bottom-up: clamp the bottom-most label, then pull overflowing labels up.
        if (items[n - 1].y > bottom) {
            items[n - 1].y = bottom;
        }
        var i = n - 2;
        while (i >= 0) {
            final maxY = f(items[i + 1].y - PlotLabel.TEXT_HEIGHT);
            if (items[i].y > maxY) {
                items[i].y = maxY;
            }
            i--;
        }

        // Keep the top-most label within bounds.
        if (items[0].y < top) {
            items[0].y = top;
        }
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}
