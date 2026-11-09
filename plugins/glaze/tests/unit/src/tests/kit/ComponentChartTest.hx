// Ported from gpui-kit 0.8.1: crates/component/src/chart/mod.rs, area_chart.rs, bar_chart.rs, line_chart.rs,
// pie_chart.rs, radar_chart.rs, sankey_chart.rs, crates/component/src/plot/tooltip.rs,
// crates/component/src/progress/progress_circle.rs, crates/component/src/button/button_icon.rs,
// crates/kit/tests/integration/exports.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.ElementId;
import glaze.Hsla;
import glaze.Point;
import glaze.Size;
import glaze.SpringMath;
import glaze.TextAlign;
import glaze.Window;
import glaze.kit.base.plot.Plot;
import glaze.kit.base.plot.PlotAxis.AxisLabelPlacement;
import glaze.kit.base.plot.scale.ScaleLinear;
import glaze.kit.base.plot.scale.ScalePoint;
import glaze.kit.base.plot.shape.Bar.BarAlignment;
import glaze.kit.base.plot.shape.Sankey;
import glaze.kit.button.ButtonIcon;
import glaze.kit.chart.AreaChart;
import glaze.kit.chart.BarChart;
import glaze.kit.chart.Chart;
import glaze.kit.chart.Chart.PointAxes;
import glaze.kit.chart.Chart.TooltipContent;
import glaze.kit.chart.ChartFormat;
import glaze.kit.chart.LineChart;
import glaze.kit.chart.PieChart;
import glaze.kit.chart.RadarChart;
import glaze.kit.chart.SankeyChart;
import glaze.kit.chart.SankeyChart.SankeyLabel;
import glaze.kit.plot.Tooltip;
import glaze.kit.progress.ProgressCircle;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

/** A hand-written plot through `Plot` (the exports test's `DerivedPlot`). */
class DerivedPlot extends Plot {

    public function paint(bounds:Bounds, window:Window, cx:App):Void {}

}

/**
 * Tests of gpui-component's charts, plot tooltip and progress circle.
 */
class ComponentChartTest extends KitTestCase {

    override function setup() {
        super.setup();
    }

/// chart/mod.rs

    static function sameSite():PieChart<Float> {
        return new PieChart([1., 2.]);
    }

    function testAChartIsInteractiveWithoutBeingGivenAnId() {
        assertTrue(sameSite().plotId() != null);
    }

    function testChartsBuiltAtDifferentSitesGetDifferentIds() {
        final a = new PieChart([1.]);
        final b = new PieChart([1.]);
        assertFalse(Type.enumEq(a.plotId(), b.plotId()));
    }

    function testChartsBuiltAtOneSiteShareAnId() {
        assertTrue(Type.enumEq(sameSite().plotId(), sameSite().plotId()));
    }

    function testAChartTurnedOffKeepsItsIdButNotItsHitbox() {
        final off = sameSite().interactive(false);
        assertFalse(off.isInteractive());
        assertTrue(off.plotId() != null);
        assertTrue(Type.enumEq(ElementId.Name('pie'), sameSite().id('pie').interactive(false).plotId()));
    }

    function testAnAppearKeyReplaysTheAppear() {
        assertEquals('0', sameSite().appearGeneration());
        assertEquals(null, sameSite().appear(false).appearGeneration());
        final a = sameSite().appearKey('AAPL.US').appearGeneration();
        final b = sameSite().appearKey('TSLA.US').appearGeneration();
        assertTrue(a != b);
        assertEquals(a, sameSite().appearKey('AAPL.US').appearGeneration());
    }

    function testOnlyTheLastPointRightAlignsItsLabel() {
        final data = ['a', 'b', 'c'];
        final align = (pointCount:Int) -> {
            final x = new ScalePoint(data, Chart.pointRange(0., 100., data.length, pointCount));
            [for (label in Chart.buildPointXLabels(data, d -> d, x, pointCount, [true, true, true], new Hsla())) label.align];
        };
        assertEquals(([TextAlign.Left, TextAlign.Center, TextAlign.Right] : Array<TextAlign>).join(','), align(3).join(','));
        assertEquals(([TextAlign.Left, TextAlign.Center, TextAlign.Center] : Array<TextAlign>).join(','), align(5).join(','));
    }

    function testANamedIdReplacesTheDefault() {
        assertTrue(Type.enumEq(ElementId.Name('pie'), sameSite().id('pie').plotId()));
    }

    function testTheDefaultTicksKeepTheGridInPlace() {
        final axes = new PointAxes();
        final rows = @:privateAccess axes.tickPositions(100.);
        rows.pop();
        assertEquals('0,25,50,75', rows.join(','));
    }

    function testALabelCountSpreadsLabelsFromTheFirstItemToTheLast() {
        final shown = (len:Int, count:Int) -> {
            final labeled = Chart.labeledItems(len, count, 1);
            [for (i in 0...labeled.length) if (labeled[i]) i].join(',');
        };
        assertEquals('0,5,10', shown(11, 3));
        assertEquals('0,9', shown(10, 2));
        assertEquals('0,1,2', shown(3, 5));
        assertEquals('0', shown(4, 1));
        assertEquals('', shown(4, 0));

        // Without a count the stride still decides.
        assertEquals('false,true,false,true', Chart.labeledItems(4, null, 2).join(','));
    }

    function testATickReadsTheValueAtItsHeight() {
        var extent = Chart.pointValueScale([10., 20.], null, 110., [10., 0.]).extent;
        assertEquals(0., extent.valueAt(110.));
        assertEquals(20., extent.valueAt(10.));
        assertTrue(Math.abs(extent.valueAt(0.) - 22.) < 1e-4);
        assertEquals(10., extent.positionOf(20.));

        extent = Chart.pointValueScale([0.], [100., 200.], 100., [0., 0.]).extent;
        assertEquals(200., extent.valueAt(0.));
        assertEquals(50., extent.positionOf(150.));
    }

    function testTooltipTextFallsBackToTheChartOwn() {
        final content = new TooltipContent<Float>();
        assertEquals('Jan', @:privateAccess content.titleText(1., 'Jan'));
        assertEquals(null, @:privateAccess content.titleText(1., null));
        assertEquals('1234.5', @:privateAccess content.valueText(1., 0, 1234.5));

        content.setTitle(d -> 'Day ${ChartFormat.display64(d)}');
        content.setValue((_, _, value) -> '$' + ChartFormat.fixed(value, 2));
        assertEquals('Day 3', @:privateAccess content.titleText(3., null));
        assertEquals('$1234.50', @:privateAccess content.valueText(3., 0, 1234.5));
    }

    function testTooltipFillWritesEachRowWithTheValueColor() {
        final content = new TooltipContent<Float>();
        content.setValue((_, ix, value) -> '$ix: ' + (value >= 0 ? '+' : '') + ChartFormat.display64(value));
        content.setValueColor((_, _, value) -> value >= 0. ? green() : red());
        final opened = openWindow(_ -> new ChartTestView());
        final tooltip = content.apply(
            Tooltip.component(new Point(0, 0), new Size(100, 100)),
            1.,
            () -> 'Jan',
            () -> [{swatch: blue(), name: 'Open', value: 2.}, {swatch: blue(), name: 'Close', value: -1.}],
            opened.window,
            app
        );
        assertTrue(tooltip != null);
        assertEquals('Jan', @:privateAccess tooltip.titleProp);
        final rows = @:privateAccess tooltip.rows;
        assertEquals('0: +2', rows[0].value);
        assertTrue(rows[0].valueColor.equals(green()));
        assertEquals('1: -1', rows[1].value);
        assertTrue(rows[1].valueColor.equals(red()));
    }

    function testTooltipFillLeavesTheTitleOffWithoutOne() {
        final content = new TooltipContent<Float>();
        final opened = openWindow(_ -> new ChartTestView());
        final tooltip = content.apply(
            Tooltip.component(new Point(0, 0), new Size(100, 100)),
            1.,
            () -> null,
            () -> [{swatch: blue(), name: 'Alpha', value: 80.}],
            opened.window,
            app
        );
        assertTrue(tooltip != null);
        assertEquals(null, @:privateAccess tooltip.titleProp);
        final rows = @:privateAccess tooltip.rows;
        assertEquals(1, rows.length);
        assertEquals('80', rows[0].value);
        assertEquals(null, rows[0].valueColor);
    }

    function testTooltipFillRendersTheCallerContentWithoutBuildingRows() {
        final content = new TooltipContent<Float>();
        content.setTitle(_ -> 'Caller');
        content.setContent((_, _, _) -> div());
        var built = false;
        final opened = openWindow(_ -> new ChartTestView());
        final tooltip = content.apply(
            Tooltip.component(new Point(0, 0), new Size(100, 100)),
            1.,
            () -> {
                built = true;
                'Jan';
            },
            () -> {
                built = true;
                null;
            },
            opened.window,
            app
        );
        assertTrue(tooltip != null);
        assertFalse(built);
        assertEquals(null, @:privateAccess tooltip.titleProp);
        assertEquals(0, (@:privateAccess tooltip.rows).length);
    }

/// line_chart.rs

    function testF32ValuesScaleLikeF64() {
        final bounds = new Bounds(new Point(0, 0), new Size(100, 50));
        final chart = new LineChart<Float>([2., 4.]).x(v -> Std.string(v)).y(v -> v).xAxis(false);
        final y = @:privateAccess chart.scales(bounds).y;
        final y32 = new ScaleLinear([2., 4., 0.], [50., 10.], true);
        assertEquals(y32.tick(4.), y.tick(4.));
        assertEquals(y32.tick(0.), y.tick(0.));
    }

/// area_chart.rs

    static function areaBounds():Bounds {
        return new Bounds(new Point(0, 0), new Size(100, 50));
    }

    static function areaChart(data:Array<Float>):AreaChart<{i:Int, v:Float}> {
        return new AreaChart([for (i in 0...data.length) {i: i, v: data[i]}]).x(d -> Std.string(d.i)).y(d -> d.v).xAxis(false);
    }

    function testPointCountFillsTheLeadingPart() {
        var x = @:privateAccess areaChart([1., 2., 3.]).pointCount(5).scales(areaBounds()).x;
        assertEquals(0., x.tick('0'));
        assertEquals(50., x.tick('2'));

        x = @:privateAccess areaChart([1., 2., 3.]).pointCount(2).scales(areaBounds()).x;
        assertEquals(100., x.tick('2'));
    }

    function testYDomainReplacesTheFitFromZero() {
        var y = @:privateAccess areaChart([10., 20.]).yDomain(10., 20.).scales(areaBounds()).y;
        assertEquals(50., y.tick(10.));
        assertEquals(10., y.tick(20.));

        y = @:privateAccess areaChart([10., 20.]).scales(areaBounds()).y;
        assertEquals(50., y.tick(0.));
        assertEquals(10., y.tick(20.));
    }

/// bar_chart.rs

    function testLabelBelowZeroLine() {
        // Bottom-aligned: positive bars grow up, leaving the space below free.
        assertTrue(@:privateAccess BarChart.labelBelowZeroLine(5., Bottom));
        assertTrue(@:privateAccess BarChart.labelBelowZeroLine(0., Bottom));
        assertFalse(@:privateAccess BarChart.labelBelowZeroLine(-5., Bottom));

        // Top-aligned bars grow the other way, so the sides swap.
        assertFalse(@:privateAccess BarChart.labelBelowZeroLine(5., Top));
        assertFalse(@:privateAccess BarChart.labelBelowZeroLine(0., Top));
        assertTrue(@:privateAccess BarChart.labelBelowZeroLine(-5., Top));
    }

    function testValueTickPositions() {
        // Both ends are included, so 5 ticks means 4 intervals.
        assertEquals('10,35,60,85,110', (@:privateAccess BarChart.valueTickPositions(10., 110., 5)).join(','));
        // Top-aligned charts have the baseline before the far edge.
        assertEquals('110,60,10', (@:privateAccess BarChart.valueTickPositions(110., 10., 3)).join(','));
        assertEquals('0,50', (@:privateAccess BarChart.valueTickPositions(0., 50., 2)).join(','));
    }

    function testMinLengthExtendsAwayFromZero() {
        // A zero or tiny bar grows the way a positive one would.
        assertEquals(98., @:privateAccess BarChart.extendToMinLength(100., 100., false, Bottom, 2.));
        assertEquals(12., @:privateAccess BarChart.extendToMinLength(10., 10., false, Top, 2.));
        assertEquals(12., @:privateAccess BarChart.extendToMinLength(10., 10., false, Left, 2.));
        assertEquals(88., @:privateAccess BarChart.extendToMinLength(90., 90., false, Right, 2.));

        // A small negative bar grows to the other side of the zero line.
        assertEquals(52., @:privateAccess BarChart.extendToMinLength(50.5, 50., true, Bottom, 2.));

        // A bar already long enough is left alone.
        assertEquals(40., @:privateAccess BarChart.extendToMinLength(40., 100., false, Bottom, 2.));
    }

    function testValueTickLabelsWalkTheDomainFromTheFarEnd() {
        final chart = new BarChart<Float>([10., 20.]).band(v -> ChartFormat.display64(v)).value(v -> v).valueTickCount(3);
        assertEquals('20,10,0', (@:privateAccess chart.valueTickLabels()).join(','));

        final money = chart.valueTickFormat(v -> '$' + ChartFormat.fixed(v, 0));
        assertEquals("$20,$10,$0", (@:privateAccess money.valueTickLabels()).join(','));

        // Labels spread over every band, so they stay put as the data grows.
        assertEquals(12, @:privateAccess money.bandCount(12).bandSlots());
    }

    function testABandCountKeepsEachBarInItsBand() {
        final bounds = new Bounds(new Point(0, 0), new Size(40, 100));
        final chart = (data:Array<Float>, count:Int) -> new BarChart<Float>(data).band(v -> ChartFormat.display64(v)).value(v -> v).bandCount(count);

        // Two bars laid out for four bands take the first half of the width.
        final wide = @:privateAccess chart([1., 2.], 2).bandScale(bounds);
        final narrow = @:privateAccess chart([1., 2.], 4).bandScale(bounds);
        assertEquals(wide.bandWidth(), narrow.bandWidth() * 2.);
        assertTrue(narrow.tick('2') < 20.);

        // A bar keeps its place as the data grows into the empty bands.
        final grown = @:privateAccess chart([1., 2., 3.], 4).bandScale(bounds);
        assertEquals(narrow.tick('2'), grown.tick('2'));
        assertEquals(narrow.bandWidth(), grown.bandWidth());

        // Labels inside the plot leave the bars their full width.
        final outside = chart([1., 2.], 2).valueAxis(true);
        final inside = chart([1., 2.], 2).valueAxis(true).valueAxisLabelPlacement(Inside);
        assertEquals(Chart.VALUE_AXIS_GAP, @:privateAccess outside.valueAxisGap());
        assertEquals(0., @:privateAccess inside.valueAxisGap());
    }

    function testTheTooltipSwatchFollowsTheBarColor() {
        final bars = () -> new BarChart<Float>([1., -2.]).band(d -> ChartFormat.display64(d)).value(d -> d);
        final frame = new Bounds();
        final bounds = new Bounds(new Point(0, 0), new Size(100, 100));
        final gain = green();
        final loss = red();
        final fallback = @:privateAccess bars().barColor(1., frame, bounds, app);
        final solid = @:privateAccess bars().fill((d, _, _, _) -> d >= 0. ? gain : loss).barColor(-2., frame, bounds, app);
        final gradient = @:privateAccess bars().fill((_, _, _, _) -> linearGradient(0., linearColorStop(gain, 0.), linearColorStop(loss, 1.))).barColor(1., frame, bounds, app);
        final stops = @:privateAccess bars().fillGradient((_, _, _, _) -> [linearColorStop(gain, 0.), linearColorStop(loss, 1.)]).barColor(1., frame, bounds, app);
        final chart2 = Theme.global(app).chart2;

        assertTrue(fallback.equals(chart2));
        assertTrue(solid.equals(red()));
        assertTrue(gradient.equals(chart2));
        assertTrue(stops.equals(green()));
    }

    function testTheTooltipReadsThePaintedBarFrame() {
        final bars = new BarChart<Float>([1., -2.]).band(d -> ChartFormat.display64(d)).value(d -> d);
        final bounds = new Bounds(new Point(0, 0), new Size(100, 100));
        final bandScale = @:privateAccess bars.bandScale(bounds);
        final up = @:privateAccess bars.barFrame(1., bandScale, bounds);
        final down = @:privateAccess bars.barFrame(-2., bandScale, bounds);

        // Both grow from zero: one up, one down twice as far.
        assertEquals(down.origin.y, up.origin.y + up.size.height);
        assertTrue(Math.abs(down.size.height - 2. * up.size.height) < 0.01);
        assertTrue(up.origin.x < down.origin.x);
        assertEquals(bandScale.bandWidth(), up.size.width);
    }

/// pie_chart.rs

    function testPieChartSliceRadiusFallsBackToTheRing() {
        final bounds = new Bounds(new Point(0, 0), new Size(200, 200));

        var chart = new PieChart<Float>([1., 3.]).value(d -> d);
        var ring = @:privateAccess chart.resolveOuterRadius(bounds);
        assertEquals(80., ring);
        assertEquals(ring, @:privateAccess chart.getOuterRadius(@:privateAccess chart.arcs()[0], ring));

        // An explicit radius, and a per-slice one, still win.
        chart = new PieChart<Float>([1., 3.]).value(d -> d).outerRadius(50.);
        ring = @:privateAccess chart.resolveOuterRadius(bounds);
        assertEquals(50., ring);
        assertEquals(50., @:privateAccess chart.getOuterRadius(@:privateAccess chart.arcs()[0], ring));

        chart = new PieChart<Float>([1., 3.]).value(d -> d).outerRadiusFn(a -> 10. + a.index);
        ring = @:privateAccess chart.resolveOuterRadius(bounds);
        final arcs = @:privateAccess chart.arcs();
        assertEquals(10., @:privateAccess chart.getOuterRadius(arcs[0], ring));
        assertEquals(11., @:privateAccess chart.getOuterRadius(arcs[1], ring));
    }

    function testTooltipNameDoesNotTurnOnLeaderLines() {
        final titled = new PieChart<Float>([1.]).tooltipName(_ -> 'Tech');
        assertTrue(@:privateAccess titled.tooltipNameProp != null);
        assertEquals(null, @:privateAccess titled.labelFn);

        // `label` still titles the tooltip when no title is set.
        final labelled = new PieChart<Float>([1.]).label(_ -> 'Tech');
        assertEquals(null, @:privateAccess labelled.tooltipNameProp);
        assertTrue(@:privateAccess labelled.labelFn != null);
    }

/// radar_chart.rs

    function testRadarChartBuilder() {
        final data = [{subject: 'Sales', a: 80., b: 60.}, {subject: 'Marketing', a: 50., b: 90.}];

        final chart = new RadarChart(data)
            .label(d -> d.subject)
            .value(d -> d.a)
            .stroke(red())
            .fill(red())
            .name('A')
            .value(d -> d.b)
            .maxValue(100.)
            .outerRadius(120.)
            .labelGap(8.)
            .grid(false)
            .gridLevels(5)
            .dot()
            .id('radar');

        assertEquals(2, @:privateAccess chart.data.length);
        assertEquals(2, @:privateAccess chart.values.length);
        assertEquals(1, @:privateAccess chart.strokes.length);
        assertEquals(1, @:privateAccess chart.fills.length);
        assertEquals(1, @:privateAccess chart.names.length);
        assertTrue(@:privateAccess chart.labelFn != null);
        assertEquals(100., @:privateAccess chart.maxValueProp);
        assertEquals(120., @:privateAccess chart.outerRadiusValue);
        assertEquals(8., @:privateAccess chart.labelGapValue);
        assertFalse(@:privateAccess chart.gridProp);
        assertEquals(5, @:privateAccess chart.gridLevelsValue);
        assertTrue(@:privateAccess chart.dotValue);
        assertTrue(Type.enumEq(ElementId.Name('radar'), @:privateAccess chart.idProp));

        final values = @:privateAccess chart.values;
        assertEquals('80,60', [values[0](data[0]), values[1](data[0])].join(','));
    }

    function testRadarLabelFromText() {
        final label:glaze.kit.chart.RadarChart.RadarLabel = 'Sales';
        switch label.kind() {
            case Text(text): assertEquals('Sales', text);
            case _: assertTrue(false);
        }
    }

    function testRadarChartGridLevelsMin() {
        final chart = new RadarChart<Float>([]).gridLevels(0);
        assertEquals(1, @:privateAccess chart.gridLevelsValue);
    }

    function testRadarChartHoveredIndex() {
        final data = [for (i in 0...4) {subject: 'S$i', a: 50.}];
        // Bounds 200x200: center (100, 100), default outer radius 80, hover
        // region 80 + 10 (label gap) = 90.
        final chart = new RadarChart(data).value(d -> d.a);
        final bounds = new Bounds(new Point(0, 0), new Size(200, 200));

        // The four spokes point at 12, 3, 6 and 9 o'clock.
        assertEquals(0, @:privateAccess chart.hoveredIndex(new Point(100, 30), bounds));
        assertEquals(1, @:privateAccess chart.hoveredIndex(new Point(170, 100), bounds));
        assertEquals(2, @:privateAccess chart.hoveredIndex(new Point(100, 170), bounds));
        assertEquals(3, @:privateAccess chart.hoveredIndex(new Point(30, 100), bounds));

        // Nearest spoke wins between two spokes.
        assertEquals(0, @:privateAccess chart.hoveredIndex(new Point(110, 40), bounds));
        assertEquals(1, @:privateAccess chart.hoveredIndex(new Point(160, 90), bounds));

        // Outside the radar.
        assertEquals(null, @:privateAccess chart.hoveredIndex(new Point(100, 5), bounds));
        assertEquals(null, @:privateAccess chart.hoveredIndex(new Point(5, 5), bounds));
    }

/// sankey_chart.rs

    function testSankeyChartBuilder() {
        var chart = new SankeyChart(['a', 'b'], [new SankeyLink(0, 1, 5.)]);
        assertEquals(2, @:privateAccess chart.nodes.length);
        assertEquals(1, @:privateAccess chart.links.length);
        assertEquals(10., @:privateAccess chart.nodeWidthValue);
        assertEquals(16., @:privateAccess chart.nodePaddingValue);
        assertEquals(Justify, @:privateAccess chart.nodeAlignProp);
        assertEquals(6, @:privateAccess chart.iterationsProp);
        assertEquals(null, @:privateAccess chart.nodeCornerRadiusValue);
        assertEquals(SpringMath.f32(0.3), @:privateAccess chart.linkOpacityValue);
        assertEquals(1., @:privateAccess chart.minLinkWidthValue);
        assertEquals(6., @:privateAccess chart.labelGapValue);
        assertEquals(null, @:privateAccess chart.nodeColorFn);
        assertEquals(null, @:privateAccess chart.nodeLabelProp);
        assertEquals(null, @:privateAccess chart.valueLabelProp);
        assertEquals(null, @:privateAccess chart.labelsProp);

        chart = chart
            .nodeWidth(8.)
            .nodePadding(20.)
            .nodeAlign(Left)
            .iterations(10)
            .nodeCornerRadius(2.)
            .nodeColor(_ -> red())
            .nodeLabel(d -> d)
            .valueLabel((_, value) -> ChartFormat.display64(value))
            .labels((d, value) -> [new SankeyLabel(ChartFormat.display64(value)), new SankeyLabel(d)])
            .linkOpacity(0.5)
            .minLinkWidth(2.)
            .labelGap(10.);
        assertEquals(8., @:privateAccess chart.nodeWidthValue);
        assertEquals(20., @:privateAccess chart.nodePaddingValue);
        assertEquals(Left, @:privateAccess chart.nodeAlignProp);
        assertEquals(10, @:privateAccess chart.iterationsProp);
        assertEquals(2., @:privateAccess chart.nodeCornerRadiusValue);
        assertEquals(0.5, @:privateAccess chart.linkOpacityValue);
        assertEquals(2., @:privateAccess chart.minLinkWidthValue);
        assertEquals(10., @:privateAccess chart.labelGapValue);
        assertTrue(@:privateAccess chart.nodeColorFn != null);
        assertTrue(@:privateAccess chart.nodeLabelProp != null);
        assertTrue(@:privateAccess chart.valueLabelProp != null);
        assertTrue(@:privateAccess chart.labelsProp != null);
    }

    function testSankeyLabelBuilder() {
        var label = new SankeyLabel('a');
        assertEquals('a', @:privateAccess label.text);
        assertEquals(null, @:privateAccess label.colorValue);
        assertEquals(null, @:privateAccess label.fontSizeValue);
        assertEquals(12., @:privateAccess label.lineHeight());

        label = new SankeyLabel('b').color(red()).fontSize(14.);
        assertTrue((@:privateAccess label.colorValue).equals(red()));
        assertEquals(14., @:privateAccess label.fontSizeValue);
        assertEquals(16., @:privateAccess label.lineHeight());

        assertEquals(28., @:privateAccess SankeyLabel.blockHeight([new SankeyLabel('a'), new SankeyLabel('b').fontSize(14.)]));
        assertEquals(0., @:privateAccess SankeyLabel.blockHeight([]));
    }

    static function chartLinks():Array<SankeyLink> {
        return [new SankeyLink(0, 1, 30.), new SankeyLink(1, 2, 20.), new SankeyLink(1, 3, 10.)];
    }

    function testSankeyChartRawThroughput() {
        // A(out 30) -> B, B -> C(20) + D(10): B's throughput is max(in, out).
        final chart = new SankeyChart(['a', 'b', 'c', 'd'], chartLinks());
        final raw = @:privateAccess chart.rawThroughput();
        assertEquals('30,30,20,10', raw.join(','));

        // Under Sqrt the layout's node value is scaled, but the raw
        // throughput (used for labels) stays in raw units.
        final sqrt = @:privateAccess chart.valueScale(Sqrt).sankey().layout(4, chartLinks());
        assertTrue(Math.abs(sqrt.nodes[0].value - Math.sqrt(30.)) < 1e-6);
        assertTrue(Math.abs(raw[0] - 30.) < 1e-6);
        assertTrue(raw[0] != sqrt.nodes[0].value);
    }

    function testTooltipTextIsSettableWithoutDrawingLabels() {
        final chart = new SankeyChart(['Revenue'], [])
            .tooltipName(_ -> 'Revenue')
            .tooltipValue((_, value) -> ChartFormat.fixed(value, 0) + 'M');
        assertTrue(@:privateAccess chart.tooltipNameProp != null);
        assertTrue(@:privateAccess chart.tooltipValueProp != null);
        assertEquals(null, @:privateAccess chart.nodeLabelProp);
        assertEquals(null, @:privateAccess chart.valueLabelProp);
    }

/// plot/tooltip.rs

    function testAValueColorColorsOnlyTheRowAddedLast() {
        final tooltip = Tooltip.component(new Point(0, 0), new Size(100, 100))
            .valueColor(red())
            .row(blue(), 'Open', '1')
            .row(blue(), 'Close', '2')
            .valueColor(green());
        final rows = @:privateAccess tooltip.rows;
        assertEquals(null, rows[0].valueColor);
        assertTrue(rows[1].valueColor.equals(green()));
    }

    function testAPlainRowHasNoSwatchAndTakesAValueColor() {
        final tooltip = Tooltip.component(new Point(0, 0), new Size(100, 100))
            .row(blue(), 'Call', '1')
            .plainRow('Total', '3')
            .valueColor(red());
        final rows = @:privateAccess tooltip.rows;
        assertTrue(rows[0].color.equals(blue()));
        assertEquals(null, rows[0].valueColor);
        assertEquals(null, rows[1].color);
        assertTrue(rows[1].valueColor.equals(red()));
    }

    function testPlainRowsKeepASwatchSlotOnlyBesideSeriesRows() {
        final tooltip = () -> Tooltip.component(new Point(0, 0), new Size(100, 100));
        final mixed = tooltip().row(blue(), 'Call', '1').plainRow('Total', '3');
        final plain = tooltip().plainRow('Total', '3').plainRow('Ratio', '0.5');
        assertTrue(@:privateAccess Tooltip.hasSwatches(@:privateAccess mixed.rows));
        assertFalse(@:privateAccess Tooltip.hasSwatches(@:privateAccess plain.rows));
    }

/// progress/progress_circle.rs, button/button_icon.rs

    function testStoresAnExplicitAccessibilityLabel() {
        final plain = ProgressCircle.component('upload');
        assertEquals(null, @:privateAccess plain.accessibilityLabelProp);

        final named = ProgressCircle.component('upload').accessibilityLabel('Upload progress');
        assertEquals('Upload progress', @:privateAccess named.accessibilityLabelProp);
    }

    function testButtonIconProgressVariant() {
        final progress = Progress(ProgressCircle.component(75));
        assertFalse(@:privateAccess ButtonIcon.isSpinner(progress));
        assertTrue(@:privateAccess ButtonIcon.isProgress(progress));
        assertFalse(@:privateAccess ButtonIcon.isProgress(Icon(glaze.kit.Icon.component(glaze.kit.IconName.Plus))));
    }

/// kit/tests/integration/exports.rs

    function testAHandWrittenPlotIsAnElement() {
        final element:glaze.IntoElement = new DerivedPlot();
        assertTrue(element != null);
    }

/// Rust number formatting used by the charts

    function testChartFormat() {
        assertEquals('0.2', ChartFormat.fixed(0.25, 1));
        assertEquals('0.1', ChartFormat.fixed(0.15, 1));
        assertEquals('2', ChartFormat.fixed(2.5, 0));
        assertEquals('-1.4', ChartFormat.fixed(-1.45, 1));
        assertEquals('-1.6', ChartFormat.fixed(-1.55, 1));
        assertEquals('1234.5', ChartFormat.display64(1234.5));
        assertEquals('0.30000000000000004', ChartFormat.display64(0.1 + 0.2));
        assertEquals('-0', ChartFormat.display64(-0.));
        assertEquals('0.1', ChartFormat.display32(SpringMath.f32(0.1)));
        assertEquals('33.333332', ChartFormat.display32(SpringMath.f32(100. / 3.)));
    }

}

class ChartTestView extends glaze.Model implements glaze.Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:glaze.Context<Dynamic>):glaze.IntoElement {
        return div();
    }

}
