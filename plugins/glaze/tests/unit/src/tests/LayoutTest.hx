package tests;

import gpui.App;
import gpui.AvailableSpace;
import gpui.Edges;
import gpui.LayoutId;
import gpui.SizeOf;
import gpui.Style;
import gpui.TaffyLayoutEngine;
import gpui.TestDispatcher;
import gpui.Window;
import taffy.style.LengthPercentage;
import testing.TestCase;

import gpui.Prelude.*;

/**
 * Tests for the taffy glue (GPUI's `taffy.rs`): style conversion, pixel
 * snapping, layout bounds.
 */
class LayoutTest extends TestCase {

    var app:App;

    var window:Window;

    override function setup() {
        app = new App(new TestDispatcher());
        window = new Window(app, {width: 400, height: 300, scaleFactor: 2, autoDraw: false});
    }

    override function teardown() {
        window.destroy();
    }

    function testRoundHalfTowardZero() {
        // GPUI util.rs tests
        assertEquals(0.0, TaffyLayoutEngine.roundHalfTowardZero(0.5));
        assertEquals(1.0, TaffyLayoutEngine.roundHalfTowardZero(1.5));
        assertEquals(2.0, TaffyLayoutEngine.roundHalfTowardZero(2.5));
        assertEquals(-0.0, TaffyLayoutEngine.roundHalfTowardZero(-0.5));
        assertEquals(-1.0, TaffyLayoutEngine.roundHalfTowardZero(-1.5));
        assertEquals(1.0, TaffyLayoutEngine.roundHalfTowardZero(0.51));
        assertEquals(3.0, TaffyLayoutEngine.roundHalfTowardZero(2.6));
    }

    /**
     * GPUI's `(value.abs() - 0.5).ceil().copysign(value)` takes the sign of
     * the result from `value`: the ceil of a magnitude under 0.5 is `-0.0`,
     * so a plain sign test would turn `round_half_toward_zero(0.0)` into
     * `-0.0` (printed `-0px` by GPUI's `Display`).
     */
    function testRoundHalfTowardZeroKeepsTheSignOfZero() {
        assertTrue(isPositiveZero(TaffyLayoutEngine.roundHalfTowardZero(0.0)));
        assertTrue(isPositiveZero(TaffyLayoutEngine.roundHalfTowardZero(0.3)));
        assertTrue(isPositiveZero(TaffyLayoutEngine.roundHalfTowardZero(0.5)));
        // Built at run time: Haxe folds the sign test of an inlined `-0.0`
        // literal at compile time on cpp, as if it were `0.0`
        final negativeZero = Std.parseFloat("-0.0");
        assertTrue(isNegativeZero(negativeZero));
        assertTrue(isNegativeZero(TaffyLayoutEngine.roundHalfTowardZero(negativeZero)));
        assertTrue(isNegativeZero(TaffyLayoutEngine.roundHalfTowardZero(-0.3)));
        assertTrue(isNegativeZero(TaffyLayoutEngine.roundHalfTowardZero(-0.5)));
        assertTrue(isPositiveZero(gpui.TextPainter.roundHalfTowardZero(0.0)));
        assertTrue(isNegativeZero(gpui.TextPainter.roundHalfTowardZero(-0.3)));
    }

    /** `Pixels`, `Point` and `Size` order like `f32::total_cmp` in GPUI: `-0.0 < 0.0`. */
    function testPixelsOrderingTreatsNegativeZeroAsLess() {
        final pos:gpui.Pixels = 0.0;
        final neg:gpui.Pixels = -0.0;
        assertTrue(isPositiveZero(pos.max(neg)));
        assertTrue(isPositiveZero(neg.max(pos)));
        assertTrue(isNegativeZero(pos.min(neg)));
        assertTrue(isNegativeZero(neg.min(pos)));
        assertTrue(isPositiveZero(neg.clamp(pos, px(10))));
        assertTrue(isNegativeZero(pos.clamp(px(-10), neg)));
        assertTrue(isPositiveZero(point(px(-0.0), px(-0.0)).max(point(px(0), px(0))).x));
        assertTrue(isNegativeZero(point(px(0), px(0)).min(point(px(-0.0), px(-0.0))).y));
        assertTrue(isPositiveZero(size(px(-0.0), px(-0.0)).max(size(px(0), px(0))).width));
        assertTrue(isNegativeZero(size(px(0), px(0)).min(size(px(-0.0), px(-0.0))).height));
    }

    static function isPositiveZero(value:Float):Bool {
        return value == 0 && 1 / value > 0;
    }

    static function isNegativeZero(value:Float):Bool {
        return value == 0 && 1 / value < 0;
    }

    /**
     * Port of GPUI's `border_widths_to_taffy_use_stroke_snapping` (taffy.rs).
     */
    function testBorderWidthsUseStrokeSnapping() {
        final style = new Style();
        style.refine(div().borderT(px(0.0)).borderR(px(0.4)).borderB(px(0.5)).borderL(px(1.6)).style());
        final taffyStyle = TaffyLayoutEngine.toTaffy(style, 16.0, 1.0);
        assertTrue(taffyStyle.border.top.equals(LengthPercentage.length(0.0)));
        assertTrue(taffyStyle.border.right.equals(LengthPercentage.length(1.0)));
        assertTrue(taffyStyle.border.bottom.equals(LengthPercentage.length(1.0)));
        assertTrue(taffyStyle.border.left.equals(LengthPercentage.length(2.0)));
    }

    function testToTaffyConvertsToDevicePixels() {
        final style = new Style();
        style.refine(div().flex().w(px(10.25)).h4().p(rems(0.5)).gap(relative(0.5)).mlAuto().style());
        final t = TaffyLayoutEngine.toTaffy(style, 16.0, 2.0);
        assertEquals(taffy.style.Display.Flex, t.display);
        // 10.25 * 2 = 20.5, rounded half toward zero
        assertEquals(20.0, t.size.width.value());
        // h4 = 1rem = 16px = 32 device pixels
        assertEquals(32.0, t.size.height.value());
        assertTrue(t.padding.left.equals(LengthPercentage.length(16.0)));
        assertTrue(t.gap.width.equals(LengthPercentage.percent(0.5)));
        assertTrue(t.margin.left.isAuto());
        assertTrue(t.alignItems == taffy.style.AlignItems.NORMAL);
        assertTrue(t.alignSelf == null);
    }

    function testLayoutBoundsAreSnappedInAbsoluteCoordinates() {
        final engine = new TaffyLayoutEngine();
        inline function leaf(width:Float):LayoutId {
            final style = new Style();
            style.refine(div().w(px(width)).h(px(10)).style());
            return engine.requestLayout(style, 16, 1.0, null);
        }
        final a = leaf(10.4);
        final b = leaf(10.4);
        final c = leaf(10.4);
        final rootStyle = new Style();
        rootStyle.refine(div().flex().w(relative(1.0)).style());
        final root = engine.requestLayout(rootStyle, 16, 1.0, [a, b, c]);

        // Authored lengths are rounded before layout (10.4 -> 10)
        engine.computeLayout(root, new SizeOf<AvailableSpace>(Definite(100), Definite(100)), window, app);
        assertEquals(10.0, engine.layoutBounds(b, 1.0).origin.x);
        assertEquals(10.0, engine.layoutBounds(b, 1.0).size.width);
        assertEquals(20.0, engine.layoutBounds(c, 1.0).origin.x);
    }

    function testMeasuredLeafSizeIsCeiledToDevicePixels() {
        final engine = new TaffyLayoutEngine();
        final measured = engine.requestMeasuredLayout(new Style(), 16, 2.0, (known, available, window, cx) -> size(10.1, 5.3));
        final rootStyle = new Style();
        rootStyle.refine(div().flex().style());
        final root = engine.requestLayout(rootStyle, 16, 2.0, [measured]);
        engine.computeLayout(root, new SizeOf<AvailableSpace>(Definite(100), Definite(100)), window, app);
        final bounds = engine.layoutBounds(measured, 2.0);
        // ceil(10.1 * 2) = 21, ceil(5.3 * 2) = 11 device pixels
        assertEquals(10.5, bounds.size.width);
        assertEquals(5.5, bounds.size.height);
    }

    function testStretchAutoSizeToFill() {
        final engine = new TaffyLayoutEngine();
        final root = engine.requestLayout(new Style(), 16, 2.0, null);
        engine.stretchAutoSizeToFill(root, size(400, 300), 2.0);
        engine.computeLayout(root, new SizeOf<AvailableSpace>(Definite(400), Definite(300)), window, app);
        final bounds = engine.layoutBounds(root, 2.0);
        assertEquals(400.0, bounds.size.width);
        assertEquals(300.0, bounds.size.height);
    }

    /**
     * The per node layout bounds of a frame (dense arrays stamped with the
     * frame) are dropped when their root is laid out again in the same
     * frame, and when the frame ends, including for reused node ids.
     */
    function testLayoutBoundsCacheFollowsLayoutsAndFrames() {
        final engine = new TaffyLayoutEngine();
        function leaf(width:Float):LayoutId {
            final style = new Style();
            style.refine(div().w(px(width)).h(px(10)).style());
            return engine.requestLayout(style, 16, 1.0, null);
        }
        function row(children:Array<LayoutId>, width:Float):LayoutId {
            final style = new Style();
            style.refine(div().flex().w(px(width)).style());
            return engine.requestLayout(style, 16, 1.0, children);
        }
        final a = leaf(10);
        final b = leaf(20);
        final root = row([a, b], 100);
        engine.computeLayout(root, new SizeOf<AvailableSpace>(Definite(100), Definite(100)), window, app);
        final first = engine.layoutBounds(b, 1.0);
        assertEquals(10.0, first.origin.x);
        // Cached during the frame
        assertTrue(first == engine.layoutBounds(b, 1.0));

        // Laid out again in the same frame with another style: recomputed
        engine.stretchAutoSizeToFill(root, size(100, 100), 1.0);
        final style = engine.taffyStyle(a);
        style.size = new taffy.geometry.SizeOf<taffy.style.Dimension>(taffy.style.Dimension.length(30), style.size.height);
        @:privateAccess engine.tree.setStyle(a, style);
        engine.computeLayout(root, new SizeOf<AvailableSpace>(Definite(100), Definite(100)), window, app);
        final second = engine.layoutBounds(b, 1.0);
        assertTrue(first != second);
        assertEquals(30.0, second.origin.x);

        // Next frame: the nodes of the previous frame are freed after one
        // more frame, their ids reused by new nodes with other bounds
        engine.finishFrame();
        engine.finishFrame();
        final c = leaf(40);
        final d = leaf(50);
        final root2 = row([c, d], 200);
        engine.computeLayout(root2, new SizeOf<AvailableSpace>(Definite(200), Definite(100)), window, app);
        assertEquals(40.0, engine.layoutBounds(d, 1.0).origin.x);
        assertEquals(50.0, engine.layoutBounds(d, 1.0).size.width);
        assertEquals(0.0, engine.layoutBounds(c, 1.0).origin.x);
        assertEquals(200.0, engine.layoutBounds(root2, 1.0).size.width);
    }

}
