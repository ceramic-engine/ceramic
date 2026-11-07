// Ported from gpui-kit 0.8.1: crates/base/src/plot/appear.rs, axis.rs, grid.rs, hover.rs, path_cache.rs,
// shape/arc.rs, shape/line.rs, shape/pie.rs, shape/radial_line.rs, shape/stack.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.ElementId;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.Path;
import glaze.PathBuilder;
import glaze.Point;
import glaze.Render;
import glaze.Size;
import glaze.Window;
import glaze.kit.base.motion.Transition;
import glaze.kit.base.plot.Grid;
import glaze.kit.base.plot.PathCache;
import glaze.kit.base.plot.Plot;
import glaze.kit.base.plot.PlotAppear;
import glaze.kit.base.plot.PlotAxis;
import glaze.kit.base.plot.PlotHover;
import glaze.kit.base.plot.PlotLabel;
import glaze.kit.base.plot.PlotLabel.Text as PlotText;
import glaze.kit.base.plot.PlotAxis.AxisText;
import glaze.kit.base.plot.PathCache.ShapeKey;
import glaze.kit.base.plot.shape.Arc.ArcData;
import glaze.kit.base.plot.PlotAppear.PlotAppearScope;
import glaze.kit.base.plot.PlotMotion;
import glaze.kit.base.plot.TooltipState;
import glaze.kit.base.plot.shape.Arc;
import glaze.kit.base.plot.shape.Line;
import glaze.kit.base.plot.shape.Pie;
import glaze.kit.base.plot.shape.RadialLine;
import glaze.kit.base.plot.shape.Stack;
import glaze.kit.base.theme.PlotTheme;
import glaze.kit.base.theme.Theme;

import glaze.Prelude.*;

/** A plot that records the appear progress it is handed each frame (Rust `Recorder`). */
class AppearRecorder extends Plot {

    final samples:Array<Float>;

    final generation:Null<String>;

    public function new(samples:Array<Float>, generation:Null<String>) {
        super();
        this.samples = samples;
        this.generation = generation;
    }

    public function paint(bounds:Bounds, window:Window, cx:App):Void {}

    override public function plotId():Null<ElementId> {
        return ElementId.Name('recorder');
    }

    // Appear motion rides on the id alone, without the interactive layer.
    override public function isInteractive():Bool {
        return false;
    }

    override public function updateAppear(appear:PlotAppear, window:Window, cx:App):Void {
        samples.push(appear.progress());
    }

    override public function appearGeneration():Null<String> {
        return generation;
    }

}

class AppearRecorderView extends Model implements Render {

    public final samples:Array<Float> = [];

    public var generation:Null<String>;

    public function new(generation:Null<String>) {
        super();
        this.generation = generation;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new AppearRecorder(samples, generation);
    }

}

/** A recorder that can be taken out of the tree and put back, inside a scope or none. */
class ScopedAppearView extends Model implements Render {

    public final samples:Array<Float> = [];

    public var scope:Null<Int>;

    public var mounted:Bool = true;

    public var generation:Int = 0;

    public function new(scope:Null<Int>) {
        super();
        this.scope = scope;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final body = div().sizeFull();
        if (mounted) {
            body.child(new AppearRecorder(samples, Std.string(generation)));
        }
        if (scope != null) {
            return new PlotAppearScope(ElementId.NamedInteger('scope', scope), body);
        }
        return body;
    }

}

/**
 * Tests of gpui-base's plot module (Rust `plot/**` tests, except the scales
 * and the sankey layout, in `PlotScaleTest` and `PlotSankeyTest`).
 */
class PlotBaseTest extends KitTestCase {

/// appear.rs

    function setTheme():Void {
        app.update(cx -> {
            final theme = new Theme();
            theme.plot = new PlotTheme().withMotion(new PlotMotion().withAppear(new Transition(0.1).ease(t -> t)));
            cx.setGlobal(theme, Theme);
        });
    }

    function open(generation:Null<String>):{window:Window, view:AppearRecorderView} {
        setTheme();
        final opened = openWindow(_ -> new AppearRecorderView(generation));
        return {window: opened.window, view: opened.view};
    }

    function openScoped(scope:Null<Int>):{window:Window, view:ScopedAppearView} {
        setTheme();
        final opened = openWindow(_ -> new ScopedAppearView(scope));
        return {window: opened.window, view: opened.view};
    }

    /** Change the view, then return the progress the plot was handed on the frame that follows. */
    function updateScoped(view:ScopedAppearView, f:(ScopedAppearView) -> Void):Null<Float> {
        app.update(cx -> {
            f(view);
            view.samples.resize(0);
            cx.notify(view.entityId);
        });
        runUntilParked();
        return view.samples.length > 0 ? view.samples[view.samples.length - 1] : null;
    }

    function finishAppear(window:Window):Void {
        advanceClock(100);
        simulateNextFrame(window);
        runUntilParked();
    }

    static function last(samples:Array<Float>):Null<Float> {
        return samples.length > 0 ? samples[samples.length - 1] : null;
    }

    function testPlotAppearsOnceOverTheThemeDuration() {
        final opened = open('0');
        assertEquals(0., last(opened.view.samples));

        advanceClock(50);
        simulateNextFrame(opened.window);
        assertEquals(0.5, last(opened.view.samples));

        advanceClock(50);
        simulateNextFrame(opened.window);
        assertEquals(1., last(opened.view.samples));

        // Once whole, the plot stops asking for frames and stays whole.
        assertEquals(0, simulateNextFrame(opened.window));
        refresh(opened.window);
        assertEquals(1., last(opened.view.samples));
    }

    function testReducedMotionSkipsTheAppear() {
        app.update(cx -> cx.setReduceMotion(true));
        final opened = open('0');
        assertEquals(1., opened.view.samples[0]);
        assertEquals(0, simulateNextFrame(opened.window));
    }

    function testPlotWithoutAGenerationDoesNotAppear() {
        final opened = open(null);
        assertEquals(1., opened.view.samples[0]);
        assertEquals(0, simulateNextFrame(opened.window));
    }

    function testNewGenerationReplaysTheAppear() {
        final opened = open('0');
        advanceClock(100);
        simulateNextFrame(opened.window);
        assertEquals(1., last(opened.view.samples));

        app.update(cx -> {
            opened.view.generation = '1';
            cx.notify(opened.view.entityId);
        });
        runUntilParked();
        assertEquals(0., last(opened.view.samples));
    }

    function testScopeKeepsAFinishedAppearAcrossARemount() {
        final opened = openScoped(0);
        assertEquals(0., last(opened.view.samples));
        finishAppear(opened.window);
        assertEquals(1., last(opened.view.samples));

        assertEquals(null, updateScoped(opened.view, view -> view.mounted = false));
        assertEquals(1., updateScoped(opened.view, view -> view.mounted = true));
        assertEquals(0, simulateNextFrame(opened.window));

        // A new generation still replays.
        assertEquals(0., updateScoped(opened.view, view -> view.generation = 1));
    }

    function testScopeReplaysAnUnfinishedAppear() {
        final opened = openScoped(0);
        assertEquals(null, updateScoped(opened.view, view -> view.mounted = false));
        assertEquals(0., updateScoped(opened.view, view -> view.mounted = true));
    }

    function testScopeForgetsWhenItGoes() {
        final opened = openScoped(0);
        finishAppear(opened.window);
        assertEquals(0., updateScoped(opened.view, view -> view.scope = 1));

        finishAppear(opened.window);
        assertEquals(0., updateScoped(opened.view, view -> view.scope = null));
        finishAppear(opened.window);
        assertEquals(0., updateScoped(opened.view, view -> view.scope = 1));
    }

    function testWithoutAScopeARemountReplays() {
        final opened = openScoped(null);
        finishAppear(opened.window);
        assertEquals(null, updateScoped(opened.view, view -> view.mounted = false));
        assertEquals(0., updateScoped(opened.view, view -> view.mounted = true));
    }

    static function at(time:Float):PlotAppear {
        return @:privateAccess new PlotAppear(time, glaze.kit.base.motion.Easing.Linear);
    }

    function testCompleteAppear() {
        final appear = PlotAppear.complete();
        assertFalse(appear.isAppearing());
        assertEquals(1., appear.progress());
        assertEquals(1., appear.staggered(3, 10, 0.5));
    }

    function testStaggeredMarksShareTheAppear() {
        // The first mark starts at once, the last once the spread has passed.
        assertEquals(0., at(0.).staggered(0, 5, 0.5));
        assertEquals(0.5, at(0.25).staggered(0, 5, 0.5));
        assertEquals(0., at(0.5).staggered(4, 5, 0.5));
        assertEquals(0.5, at(0.75).staggered(4, 5, 0.5));
        // Every mark finishes with the appear.
        for (index in 0...5) {
            assertEquals(1., at(1.).staggered(index, 5, 0.5));
        }
    }

    function testStaggeredWithoutSpreadMovesTogether() {
        final t = glaze.SpringMath.f32(0.4);
        assertEquals(t, at(t).staggered(0, 3, 0.));
        assertEquals(t, at(t).staggered(2, 3, 0.));
        // A lone mark ignores the spread.
        assertEquals(t, at(t).staggered(0, 1, 0.5));
    }

/// axis.rs

    static function labels():Array<AxisText> {
        return [
            new AxisText('a', 10., new Hsla()),
            new AxisText('b', 20., new Hsla()).withAlign(Right),
        ];
    }

    static function origins(texts:Array<PlotText>):String {
        return [for (t in texts) '${t.text}@${t.origin.x},${t.origin.y}'].join(';');
    }

    function testBuilderOrderDoesNotMoveLabels() {
        final labelsFirst = new PlotAxis()
            .xLabel(labels())
            .x(50.)
            .xLabelSide(Start)
            .yLabel(labels())
            .y(30.)
            .yLabelSide(Start);
        final labelsLast = new PlotAxis()
            .xLabelSide(Start)
            .x(50.)
            .xLabel(labels())
            .yLabelSide(Start)
            .y(30.)
            .yLabel(labels());

        assertEquals(origins(@:privateAccess labelsLast.xTexts(50.)), origins(@:privateAccess labelsFirst.xTexts(50.)));
        assertEquals(origins(@:privateAccess labelsLast.yTexts(30.)), origins(@:privateAccess labelsFirst.yTexts(30.)));
        // The side set after the labels still applies to them.
        assertEquals(50. - PlotLabel.TEXT_GAP - PlotLabel.TEXT_HEIGHT, (@:privateAccess labelsFirst.xTexts(50.))[0].origin.y);
    }

    function testAxisGutterFitsDefaultLabels() {
        assertEquals(18., PlotAxis.axisGutter(PlotLabel.TEXT_SIZE));
    }

/// grid.rs

    static function xs(segments:Array<Array<Point>>):String {
        return [for (s in segments) '${s[0].x}-${s[1].x}'].join(',');
    }

    function testSolidLineIsOneSegment() {
        var segments = @:privateAccess Grid.dashSegments(new Point(0, 5), new Point(10, 5), null);
        assertEquals('0-10', xs(segments));
        segments = @:privateAccess Grid.dashSegments(new Point(0, 5), new Point(10, 5), []);
        assertEquals('0-10', xs(segments));
    }

    function testDashesAlternateAndClipAtTheEnd() {
        final segments = @:privateAccess Grid.dashSegments(new Point(0, 5), new Point(11, 5), [4., 2.]);
        assertEquals('0-4,6-10', xs(segments));
    }

    function testOddDashArrayRepeatsLikeSvg() {
        // 5,3,2 is 5 on, 3 off, 2 on, 5 off, 3 on, 2 off.
        final segments = @:privateAccess Grid.dashSegments(new Point(0, 0), new Point(0, 20), [5., 3., 2.]);
        assertEquals('0-5,8-10,15-18', [for (s in segments) '${s[0].y}-${s[1].y}'].join(','));
    }

    function testLineBoxIsOnePixelCentredOnTheCoordinate() {
        final vertical = @:privateAccess Grid.lineBounds(new Point(10, 0), new Point(10, 40));
        assertTrue(vertical.origin.equals(new Point(9.5, 0)));
        assertTrue(vertical.size.equals(new Size(1, 40)));
        final horizontal = @:privateAccess Grid.lineBounds(new Point(40, 7), new Point(0, 7));
        assertTrue(horizontal.origin.equals(new Point(0, 6.5)));
        assertTrue(horizontal.size.equals(new Size(40, 1)));
    }

/// hover.rs

    function testPlotHoverReaders() {
        final state = new TooltipState(2, new Point(10, 20), []);
        final hover = @:privateAccess new PlotHover(state, 1., true);
        assertEquals(2, hover.state().index);
        assertTrue(hover.isHovered());
        // Fully faded in: a pointer keeps travelling rather than snapping.
        assertFalse(hover.isEntering());

        // The first hovered frame, before the fade has started.
        final entering = @:privateAccess new PlotHover(state, 0., true);
        assertTrue(entering.isEntering());

        // Fading out after the cursor left: neither hovered nor entering.
        final lingering = @:privateAccess new PlotHover(state, 0.4, false);
        assertFalse(lingering.isHovered());
        assertFalse(lingering.isEntering());
    }

/// path_cache.rs

    static function diagonal():Null<Path> {
        final builder = PathBuilder.stroke(2.);
        builder.moveTo(new Point(0, 0));
        builder.lineTo(new Point(10, 10));
        return Plot.buildPath(builder);
    }

    function testBuildsOncePerKeyAndMovesToEachOrigin() {
        final cache = new PathCache();
        var builds = 0;
        final first = cache.get('1', new Point(100, 50), () -> {
            builds += 1;
            diagonal();
        });
        final second = cache.get('1', new Point(200, 50), () -> {
            builds += 1;
            diagonal();
        });
        assertEquals(1, builds);
        assertEquals(first.vertices.length, second.vertices.length);
        for (i in 0...first.vertices.length) {
            final a = first.vertices[i];
            final b = second.vertices[i];
            assertEquals(100., b.xyPosition.x - a.xyPosition.x);
            assertEquals(a.xyPosition.y, b.xyPosition.y);
            assertEquals(a.s, b.s);
            assertEquals(a.t, b.t);
        }
        assertEquals(100., second.bounds.origin.x - first.bounds.origin.x);
        assertTrue(first.bounds.size.equals(second.bounds.size));

        cache.get('2', new Point(0, 0), () -> {
            builds += 1;
            diagonal();
        });
        assertEquals(2, builds);
    }

    function testKeysFollowPointsAndExtras() {
        final a = new ShapeKey('linear:' + ShapeKey.bits(1.)).point(new Point(1, 2)).finish();
        final same = new ShapeKey('linear:' + ShapeKey.bits(1.)).point(new Point(1, 2)).finish();
        final moved = new ShapeKey('linear:' + ShapeKey.bits(1.)).point(new Point(1, 3)).finish();
        final thicker = new ShapeKey('linear:' + ShapeKey.bits(2.)).point(new Point(1, 2)).finish();
        assertEquals(same, a);
        assertTrue(a != moved);
        assertTrue(a != thicker);
    }

/// shape/line.rs

    function testLinePath() {
        final data = [1., 2., 3.];
        final line = new Line<Float>().data(data).x(v -> v).y(v -> v * 2.);

        final bounds = new Bounds(new Point(0, 0), new Size(100, 100));
        final result = @:privateAccess line.path(bounds);

        assertTrue(result.path != null);
        assertEquals(0, result.dots.length);

        final lineWithDots = new Line<Float>().data(data).x(v -> v).y(v -> v * 2.).dot();

        assertEquals(3, (@:privateAccess lineWithDots.path(bounds)).dots.length);
    }

/// shape/arc.rs

    function testArcDefault() {
        final arc = new Arc();
        assertEquals(0., @:privateAccess arc.innerRadiusValue);
        assertEquals(0., @:privateAccess arc.outerRadiusValue);
    }

    function testArcBuilder() {
        final arc = new Arc().innerRadius(10.).outerRadius(20.);
        assertEquals(10., @:privateAccess arc.innerRadiusValue);
        assertEquals(20., @:privateAccess arc.outerRadiusValue);
    }

    function testArcCentroid() {
        final arc = new Arc().innerRadius(10.).outerRadius(20.);
        final arcData = new ArcData(0, 0, 1., 0., Arc.PI);
        final centroid = arc.centroid(arcData);
        final f = glaze.SpringMath.f32;
        final expectedRadius = 15.;
        final expectedAngle = f(f(f(0. + Arc.PI) - f(2. * Arc.HALF_PI)) / 2.);
        assertEquals(f(expectedRadius * f(Math.cos(expectedAngle))), centroid.x);
        assertEquals(f(expectedRadius * f(Math.sin(expectedAngle))), centroid.y);
    }

    function testArcContains() {
        // A 100x100 plot: center (50, 50). The right half, 12 to 6 o'clock.
        final arc = new Arc().innerRadius(10.).outerRadius(40.);
        final rightHalf = new ArcData(0, 0, 1., 0., Arc.PI);
        final bounds = new Bounds(new Point(0, 0), new Size(100, 100));

        // 3 o'clock, between the radii.
        assertTrue(arc.contains(rightHalf, new Point(80, 50), bounds));
        // 9 o'clock is the other half.
        assertFalse(arc.contains(rightHalf, new Point(20, 50), bounds));
        // Inside the hole and past the rim.
        assertFalse(arc.contains(rightHalf, new Point(55, 50), bounds));
        assertFalse(arc.contains(rightHalf, new Point(95, 50), bounds));
        // A wider arc reaches the same point.
        final wider = new Arc().innerRadius(10.).outerRadius(50.);
        assertTrue(wider.contains(rightHalf, new Point(95, 50), bounds));
        // 12 o'clock is the start of this arc, 6 o'clock the start of the next.
        assertTrue(arc.contains(rightHalf, new Point(50, 20), bounds));
        assertFalse(arc.contains(rightHalf, new Point(50, 80), bounds));
    }

/// shape/pie.rs

    function testPie() {
        final pie = new Pie<Float>().value(v -> v);
        final arcs = pie.arcs([1., 1., 1.]);

        assertEquals(3, arcs.length);
        assertEquals(1., arcs[0].value);
        assertEquals(1., arcs[1].value);
        assertEquals(1., arcs[2].value);

        assertEquals(0., arcs[0].startAngle);
        assertEquals(arcs[1].startAngle, arcs[0].endAngle);
        assertEquals(arcs[2].startAngle, arcs[1].endAngle);
        assertEquals(Arc.TAU, arcs[2].endAngle);
    }

    function testPieZeroValues() {
        final pie = new Pie<Float>().value(v -> v);
        final arcs = pie.arcs([0., 1., 0., 2.]);

        assertEquals(2, arcs.length);
        assertEquals(1., arcs[0].value);
        assertEquals(2., arcs[1].value);
        assertEquals(1, arcs[0].index);
        assertEquals(3, arcs[1].index);
    }

/// shape/radial_line.rs

    function testRadialLinePoints() {
        final line = new RadialLine<Float>()
            .data([1., 1., 1., 1.])
            .angle((_, i) -> i * Arc.TAU / 4.)
            .radius((v, _) -> v * 10.);

        final bounds = new Bounds(new Point(0, 0), new Size(100, 100));
        final points = @:privateAccess line.points(bounds);

        // 4 points around the center (50, 50), at 12, 3, 6 and 9 o'clock.
        assertEquals(4, points.length);
        final expected = [[50., 40.], [60., 50.], [50., 60.], [40., 50.]];
        for (i in 0...4) {
            assertTrue(Math.abs(points[i].x - expected[i][0]) < 1e-4);
            assertTrue(Math.abs(points[i].y - expected[i][1]) < 1e-4);
        }
    }

    function testRadialLinePath() {
        final data = [1., 2., 3.];
        final bounds = new Bounds(new Point(0, 0), new Size(100, 100));

        var line = new RadialLine<Float>()
            .data(data)
            .angle((_, i) -> i * Arc.TAU / 3.)
            .radius((v, _) -> v * 10.);

        var result = @:privateAccess line.path(bounds);
        assertEquals(null, result.fill);
        assertTrue(result.stroke != null);
        assertEquals(0, result.dots.length);

        line = new RadialLine<Float>()
            .data(data)
            .angle((_, i) -> i * Arc.TAU / 3.)
            .radius((v, _) -> v * 10.)
            .closed()
            .fill(black())
            .dot();

        result = @:privateAccess line.path(bounds);
        assertTrue(result.fill != null);
        assertTrue(result.stroke != null);
        assertEquals(3, result.dots.length);
    }

/// shape/stack.rs

    function testBasicStack() {
        final data = [
            {date: 'Jan', apples: 10.0, bananas: 20.0, cherries: 30.0},
            {date: 'Feb', apples: 15.0, bananas: 25.0, cherries: 35.0},
        ];

        final stack = new Stack<{date:String, apples:Float, bananas:Float, cherries:Float}>()
            .data(data)
            .keys(['apples', 'bananas', 'cherries'])
            .value((d, key) -> switch key {
                case 'apples': d.apples;
                case 'bananas': d.bananas;
                case 'cherries': d.cherries;
                case _: null;
            });

        final series = stack.series();

        assertEquals(3, series.length);
        assertEquals('apples', series[0].key);
        assertEquals(0.0, series[0].points[0].y0);
        assertEquals(10.0, series[0].points[0].y1);

        assertEquals('bananas', series[1].key);
        assertEquals(10.0, series[1].points[0].y0);
        assertEquals(30.0, series[1].points[0].y1);

        assertEquals('cherries', series[2].key);
        assertEquals(30.0, series[2].points[0].y0);
        assertEquals(60.0, series[2].points[0].y1);
    }

}
