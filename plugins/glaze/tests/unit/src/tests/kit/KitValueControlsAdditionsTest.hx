// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.Bounds;
import glaze.Entity;
import glaze.MouseButton;
import glaze.Point;
import glaze.kit.base.Slider.SliderState;
import glaze.kit.curve.CurveEditor;
import glaze.kit.dial.AngleDial;
import glaze.kit.slider.Slider;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The controls of a value added to the kit without upstream equivalent: the
 * size of a slider (KIT-034), the angle dial (KIT-037) and the curve editor
 * (KIT-038).
 */
class KitValueControlsAdditionsTest extends KitAdditionsTestCase {

    /** A press, a drag through `path`, and a release at its last point, drawing after each event. */
    function dragThrough(cx:VisualTestContext, from:Point, path:Array<Point>):Void {
        cx.simulateMouseDown(from, MouseButton.Left);
        draw(cx);
        for (point in path) {
            cx.simulateMouseMove(point, MouseButton.Left);
            draw(cx);
        }
        cx.simulateMouseUp(path[path.length - 1], MouseButton.Left);
        draw(cx);
    }

/// Slider

    function testASmallSliderIsThinner() {
        var regular:Null<Entity<SliderState>> = null;
        var small:Null<Entity<SliderState>> = null;
        final cx = open((_, cx) -> {
            if (regular == null) regular = cx.newEntity(_ -> new SliderState().min(0.).max(1.).step(0.01).defaultValue(0.5));
            if (small == null) small = cx.newEntity(_ -> new SliderState().min(0.).max(1.).step(0.01).defaultValue(0.5));
            // Each slider in a row of its own: in a column it would stretch to share the height
            return div().p(px(20.)).w(px(240.)).flex().flexCol().itemsStart().gap(px(20.))
                .child(div().flex().wFull().child(probe('regular', Slider.component(regular))))
                .child(div().flex().wFull().child(probe('small', Slider.component(small).withSize(glaze.kit.Size.Small))));
        });
        // The track that takes the pointer gives the slider its height
        assertEquals(24., (boundsOf(cx, 'regular').size.height : Float));
        assertEquals(16., (boundsOf(cx, 'small').size.height : Float));
        assertEquals((boundsOf(cx, 'regular').size.width : Float), (boundsOf(cx, 'small').size.width : Float));
    }

/// Angle dial

    /** A 28 pixel dial at (20, 20), whose center is (34, 34). */
    function dialWindow(value:Float, step:Float, changes:Array<Float>, releases:Array<Float>, disabled:Bool = false):VisualTestContext {
        return open((_, _) -> div().p(px(20.)).child(probe('dial', AngleDial.component('dial').value(value).step(step).disabled(disabled)
            .onChange((degrees, _, _) -> changes.push(degrees))
            .onRelease((degrees, _, _) -> releases.push(degrees)))));
    }

    function testADialHasTheSizeOfItsSize() {
        final cx = dialWindow(0., 1., [], []);
        assertTrue(near(boundsOf(cx, 'dial'), new Bounds(new Point(20., 20.), new glaze.Size(28., 28.))), '${boundsOf(cx, 'dial')}');
    }

    function testAPressPointsTheNeedleAtThePointer() {
        final changes:Array<Float> = [];
        final releases:Array<Float> = [];
        final cx = dialWindow(0., 1., changes, releases);
        // Under the center: 90 degrees, clockwise from the right
        cx.simulateMouseDown(new Point(34., 44.), MouseButton.Left);
        draw(cx);
        assertEquals('[90]', Std.string(changes));
        cx.simulateMouseUp(new Point(34., 44.), MouseButton.Left);
        draw(cx);
        assertEquals('[90]', Std.string(releases));
    }

    function testAPressTakesTheShortestWayFromTheValue() {
        final changes:Array<Float> = [];
        final cx = dialWindow(350., 1., changes, []);
        // To the right of the center: the angle 0, which is 360 when coming from 350
        cx.simulateClick(new Point(44., 34.));
        draw(cx);
        assertEquals('[360]', Std.string(changes));
    }

    function testADragTurnsTheNeedleAndStopsOnTheStep() {
        final changes:Array<Float> = [];
        final releases:Array<Float> = [];
        final cx = dialWindow(0., 15., changes, releases);
        // From the right of the center, down, then to the left
        dragThrough(cx, new Point(44., 34.), [new Point(40., 44.), new Point(34., 44.), new Point(24., 34.)]);
        assertEquals(0., changes[0]);
        assertEquals(180., changes[changes.length - 1]);
        // Every value is a multiple of the step
        for (value in changes) assertEquals(0., value % 15.);
        assertEquals('[180]', Std.string(releases));
    }

    function testADisabledDialTellsNothing() {
        final changes:Array<Float> = [];
        final releases:Array<Float> = [];
        final cx = dialWindow(0., 1., changes, releases, true);
        cx.simulateClick(new Point(34., 44.));
        draw(cx);
        assertEquals(0, changes.length);
        assertEquals(0, releases.length);
    }

/// Curve editor

    function testTheValueOfABezierCurve() {
        // The straight line
        for (time in [0., 0.25, 0.5, 0.75, 1.]) {
            assertTrue(Math.abs(CurveEditor.valueAt([0., 0., 1., 1.], time) - time) < 0.001, 'at $time');
        }
        // An ease: it starts and ends where every curve does, slower than the line at first
        final ease = [0.42, 0., 0.58, 1.];
        assertTrue(Math.abs(CurveEditor.valueAt(ease, 0.)) < 0.001);
        assertTrue(Math.abs(CurveEditor.valueAt(ease, 1.) - 1.) < 0.001);
        assertTrue(Math.abs(CurveEditor.valueAt(ease, 0.5) - 0.5) < 0.001);
        assertTrue(CurveEditor.valueAt(ease, 0.2) < 0.2);
        assertTrue(CurveEditor.valueAt(ease, 0.8) > 0.8);
        // A curve that overshoots goes past 1
        assertTrue(CurveEditor.valueAt([0.3, 1.6, 0.6, 1.], 0.4) > 1.);
    }

    /**
     * A 236 x 176 editor at (20, 20). Its plot is 160 pixels high (16 for the
     * pace points), so the square of 0 to 1 is 200 wide from x 38, and
     * 160 / 1.68 high from y 20 + that height * 0.34.
     */
    function curveWindow(bezier:Null<Array<Float>>, changes:Array<String>, releases:Array<String>):VisualTestContext {
        return open((_, _) -> div().p(px(20.)).child(probe('curve', CurveEditor.component('curve').bezier(bezier).w(px(236.)).h(px(176.))
            .onChange((next, _, _) -> changes.push(next.join(',')))
            .onRelease((next, _, _) -> releases.push(next.join(','))))));
    }

    static inline final UNIT_HEIGHT:Float = 160. / 1.68;

    /** Where a point of the square of 0 to 1 is in the window of `curveWindow`. */
    static function plotted(x:Float, y:Float):Point {
        return new Point(38. + 200. * x, 20. + UNIT_HEIGHT * 0.34 + UNIT_HEIGHT * (1. - y));
    }

    function testACurveEditorKeepsItsSize() {
        final cx = curveWindow([0.25, 0.1, 0.25, 1.], [], []);
        assertTrue(near(boundsOf(cx, 'curve'), new Bounds(new Point(20., 20.), new glaze.Size(236., 176.))), '${boundsOf(cx, 'curve')}');
    }

    function testDraggingAHandleChangesItsTwoNumbers() {
        final changes:Array<String> = [];
        final releases:Array<String> = [];
        final cx = curveWindow([0.25, 0.1, 0.25, 1.], changes, releases);
        // The handle that leaves the start, dragged to the middle of the square
        dragThrough(cx, plotted(0.25, 0.1), [plotted(0.3, 0.2), plotted(0.5, 0.5)]);
        assertTrue(changes.length > 0);
        assertEquals('0.5,0.5,0.25,1', changes[changes.length - 1]);
        assertEquals('[0.5,0.5,0.25,1]', Std.string(releases));
    }

    function testAHandleStaysInTimeAndMayOvershootInValue() {
        final changes:Array<String> = [];
        final cx = curveWindow([0.25, 0.1, 0.25, 1.], changes, []);
        // Far to the left and far above: time stops at 0, the value at 1.34
        dragThrough(cx, plotted(0.25, 0.1), [plotted(0.2, 0.3), new Point(0., 0.)]);
        assertEquals('0,1.34,0.25,1', changes[changes.length - 1]);
    }

    function testACurveWithoutNumbersHasNoHandle() {
        final changes:Array<String> = [];
        final cx = curveWindow(null, changes, []);
        dragThrough(cx, plotted(0.25, 0.1), [plotted(0.3, 0.2), plotted(0.5, 0.5)]);
        assertEquals(0, changes.length);
    }

}
