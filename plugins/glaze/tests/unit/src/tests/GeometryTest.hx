package tests;

import gpui.*;
import gpui.Prelude.*;
import testing.TestCase;

/**
 * Tests of the geometry port (src/geometry.rs): the Rust unit test,
 * the behavioural doc examples, and extra checks.
 */
class GeometryTest extends TestCase {

    function b(x:Float, y:Float, w:Float, h:Float):Bounds {

        return bounds(point(x, y), size(w, h));

    }

    // Rust #[cfg(test)]

    function testBoundsIntersects() {

        final bounds1 = b(0, 0, 5, 5);
        final bounds2 = b(4, 4, 5, 5);
        final bounds3 = b(10, 10, 5, 5);

        assertTrue(bounds1.intersects(bounds2));
        assertFalse(bounds1.intersects(bounds3));
        assertTrue(bounds1.intersects(bounds1));

    }

    // Doc examples and extra checks

    function testAxis() {

        assertEquals(Axis.Horizontal, Axis.Vertical.invert());
        assertEquals(Axis.Vertical, Axis.Horizontal.invert());

    }

    function testPoint() {

        final p = point(3, 4);
        assertFloatEquals(5.0, p.magnitude());
        assertTrue(p.map(v -> v * 2).equals(point(6, 8)));
        assertTrue(p.scale(1.5).equals(point(4.5, 6)));
        assertTrue(point(3, 7).max(point(5, 2)).equals(point(5, 7)));
        assertTrue(point(3, 7).min(point(5, 2)).equals(point(3, 2)));

        final min = point(0, 5);
        final max = point(15, 25);
        assertTrue(point(10, 20).clamp(min, max).equals(point(10, 20)));
        assertTrue(point(-5, 30).clamp(min, max).equals(point(0, 25)));

        assertTrue(point(10, 20).relativeTo(point(4, 5)).equals(point(6, 15)));
        assertTrue(p.add(point(1, 1)).equals(point(4, 5)));
        assertTrue(p.sub(point(1, 1)).equals(point(2, 3)));
        assertTrue(p.mul(2).equals(point(6, 8)));
        assertTrue(p.div(2).equals(point(1.5, 2)));
        assertTrue(p.neg().equals(point(-3, -4)));

        assertEquals(3.0, p.along(Horizontal));
        assertEquals(4.0, p.along(Vertical));
        assertTrue(p.applyAlong(Vertical, v -> v + 1).equals(point(3, 5)));
        assertTrue(p.toSize().equals(size(3, 4)));
        assertTrue(point(0, 0).isZero());
        assertFalse(point(0, 1).isZero());
        assertFalse(p.equals(null));

        final generic = p.mapOf(v -> 'v$v');
        assertEquals('v3', generic.x);
        assertTrue(generic.equals(new PointOf('v3', 'v4')));

    }

    function testSize() {

        final s = size(10, 20);
        assertTrue(s.map(v -> v * 1.5).equals(size(15, 30)));
        assertTrue(s.center().equals(point(5, 10)));
        assertTrue(size(100, 50).scale(2).equals(size(200, 100)));
        assertTrue(size(30, 40).max(size(50, 20)).equals(size(50, 40)));
        assertTrue(size(30, 40).min(size(50, 20)).equals(size(30, 20)));
        assertEquals(10.0, s.along(Horizontal));
        assertTrue(s.applyAlong(Horizontal, v -> 0).equals(size(0, 20)));
        assertTrue(s.isZero() == false);
        assertTrue(size(0, 5).isZero());
        assertTrue(s.toPoint().equals(point(10, 20)));

        // Device pixels conversions
        assertTrue(size(10.25, 3.75).toDevicePixels(2).equals(size(21, 8)));
        assertTrue(size(21, 8).toPixels(2).equals(size(10.5, 4)));
        // Rust rounds half-way cases away from zero
        assertTrue(size(-1.25, 1.25).toDevicePixels(2).equals(size(-3, 3)));

        final definite = size(10, 20).toDefiniteLength();
        assertTrue(definite.width.equals(px(10).toDefiniteLength()));
        assertTrue(definite.height.equals(px(20).toDefiniteLength()));

        final full = SizeOfLength.full();
        assertTrue(full.equals(new SizeOf(relative(1).toLength(), relative(1).toLength()), LengthTools.equals));
        final autoSize = SizeOfLength.auto();
        assertTrue(autoSize.width.equals(Length.Auto));
        assertTrue(autoSize.height.equals(auto()));

    }

    function testBoundsBasics() {

        final bounds = b(0, 0, 10, 20);
        assertTrue(bounds.center().equals(point(5, 10)));
        assertEquals(30.0, bounds.halfPerimeter());
        assertTrue(bounds.topRight().equals(point(10, 0)));
        assertTrue(bounds.bottomRight().equals(point(10, 20)));
        assertTrue(bounds.bottomLeft().equals(point(0, 20)));
        assertTrue(bounds.corner(BottomLeft).equals(point(0, 20)));
        assertTrue(bounds.corner(TopCenter).equals(point(5, 0)));
        assertTrue(bounds.corner(BottomCenter).equals(point(5, 20)));
        assertTrue(bounds.corner(LeftCenter).equals(point(0, 10)));
        assertTrue(bounds.corner(RightCenter).equals(point(10, 10)));
        assertEquals(0.0, bounds.top());
        assertEquals(20.0, bounds.bottom());
        assertEquals(0.0, bounds.left());
        assertEquals(10.0, bounds.right());

        final fromCorners = Bounds.fromCorners(point(0, 0), point(10, 10));
        assertTrue(fromCorners.equals(b(0, 0, 10, 10)));

        assertTrue(Bounds.centeredAt(point(10, 10), size(4, 6)).equals(b(8, 7, 4, 6)));

    }

    function testBoundsFromAnchorAndSize() {

        final origin = point(100, 100);
        final s = size(20, 10);
        assertTrue(Bounds.fromAnchorAndSize(TopLeft, origin, s).equals(b(100, 100, 20, 10)));
        assertTrue(Bounds.fromAnchorAndSize(TopRight, origin, s).equals(b(80, 100, 20, 10)));
        assertTrue(Bounds.fromAnchorAndSize(BottomLeft, origin, s).equals(b(100, 90, 20, 10)));
        assertTrue(Bounds.fromAnchorAndSize(BottomRight, origin, s).equals(b(80, 90, 20, 10)));
        assertTrue(Bounds.fromAnchorAndSize(TopCenter, origin, s).equals(b(90, 100, 20, 10)));
        assertTrue(Bounds.fromAnchorAndSize(BottomCenter, origin, s).equals(b(90, 90, 20, 10)));
        assertTrue(Bounds.fromAnchorAndSize(LeftCenter, origin, s).equals(b(100, 95, 20, 10)));
        assertTrue(Bounds.fromAnchorAndSize(RightCenter, origin, s).equals(b(80, 95, 20, 10)));

        // The anchor of the result lands on the origin
        final anchors:Array<Anchor> = [TopLeft, TopRight, BottomLeft, BottomRight, TopCenter, BottomCenter, LeftCenter, RightCenter];
        for (anchor in anchors) {
            assertTrue(Bounds.fromAnchorAndSize(anchor, origin, s).corner(anchor).equals(origin), 'anchor $anchor');
        }

    }

    function testBoundsIntersectAndUnion() {

        assertTrue(b(0, 0, 10, 10).intersects(b(5, 5, 10, 10)));
        assertFalse(b(0, 0, 10, 10).intersects(b(20, 20, 10, 10)));
        // Touching edges do not intersect
        assertFalse(b(0, 0, 10, 10).intersects(b(10, 0, 10, 10)));

        assertTrue(b(0, 0, 10, 10).intersect(b(5, 5, 10, 10)).equals(b(5, 5, 5, 5)));
        assertTrue(b(0, 0, 10, 10).union(b(5, 5, 15, 15)).equals(b(0, 0, 20, 20)));

        // Contained bounds
        assertTrue(b(0, 0, 100, 100).intersect(b(10, 20, 30, 40)).equals(b(10, 20, 30, 40)));

        // Disjoint bounds give an empty intersection, anchored at the max origin
        final disjoint = b(0, 0, 10, 10).intersect(b(20, 30, 5, 5));
        assertTrue(disjoint.equals(b(20, 30, 0, 0)), '$disjoint');
        assertTrue(disjoint.isEmpty());

        // Disjoint on one axis only
        final partial = b(0, 0, 10, 10).intersect(b(5, 20, 10, 10));
        assertEquals(5.0, partial.size.width);
        assertEquals(0.0, partial.size.height);
        assertTrue(partial.isEmpty());

        // Union with negative coordinates
        assertTrue(b(-10, -5, 5, 5).union(b(3, 4, 2, 2)).equals(b(-10, -5, 15, 11)));

        // Intersection is commutative
        final x = b(1, 2, 30, 7);
        final y = b(-4, 5, 12, 40);
        assertTrue(x.intersect(y).equals(y.intersect(x)));
        assertTrue(x.union(y).equals(y.union(x)));

    }

    function testBoundsDilateInsetExtend() {

        assertTrue(b(10, 10, 10, 10).dilate(5).equals(b(5, 5, 20, 20)));
        assertTrue(b(10, 10, 10, 10).inset(2).equals(b(12, 12, 6, 6)));
        assertTrue(b(10, 10, 10, 10).extend(new Edges(1, 2, 3, 4)).equals(b(6, 9, 16, 14)));

        final inner = b(10, 20, 30, 40);
        final outer = b(0, 0, 100, 100);
        assertTrue(inner.spaceWithin(outer).equals(new Edges(20, 60, 40, 10)));

    }

    function testBoundsContains() {

        final bounds = b(0, 0, 10, 10);
        assertTrue(bounds.contains(point(5, 5)));
        assertFalse(bounds.contains(point(15, 15)));
        // Left / top inclusive, right / bottom exclusive
        assertTrue(bounds.contains(point(0, 0)));
        assertFalse(bounds.contains(point(10, 5)));
        assertFalse(bounds.contains(point(5, 10)));

        final outer = b(0, 0, 20, 20);
        assertTrue(b(5, 5, 10, 10).isContainedWithin(outer));
        assertFalse(b(15, 15, 10, 10).isContainedWithin(outer));

        assertTrue(b(10, 10, 10, 10).localize(point(15, 12)).equals(point(5, 2)));
        assertNull(b(10, 10, 10, 10).localize(point(5, 12)));

    }

    function testBoundsMapAndScale() {

        final bounds = b(10, 10, 10, 20);
        assertTrue(bounds.map(v -> v * 1.5).equals(b(15, 15, 15, 30)));
        assertTrue(bounds.mapOrigin(v -> v * 1.5).equals(b(15, 15, 10, 20)));
        assertTrue(bounds.mapSize(v -> v * 1.5).equals(b(10, 10, 15, 30)));

        assertTrue(b(10, 20, 30, 40).scale(2).equals(b(20, 40, 60, 80)));
        assertTrue(b(10, 20, 30, 40).mul(2).equals(b(20, 40, 60, 80)));
        assertTrue(b(10, 20, 30, 40).div(2).equals(b(5, 10, 15, 20)));
        assertTrue(b(10, 20, 30, 40).add(point(1, 2)).equals(b(11, 22, 30, 40)));
        assertTrue(b(10, 20, 30, 40).sub(point(1, 2)).equals(b(9, 18, 30, 40)));

        assertTrue(b(1.25, 2.5, 10.2, 3.3).toDevicePixels(2).equals(b(3, 5, 20, 7)));
        assertTrue(b(3, 5, 20, 7).toPixels(2).equals(b(1.5, 2.5, 10, 3.5)));

        assertTrue(b(0, 0, 0, 10).isEmpty());
        assertTrue(b(0, 0, 10, -1).isEmpty());
        assertFalse(b(0, 0, 1, 1).isEmpty());
        assertTrue(b(0, 0, 0, 10).isZero());

        final generic = bounds.mapOf(v -> Std.int(v));
        assertEquals(10, generic.origin.x);
        assertTrue(generic.mapToBounds(v -> v * 2.0).equals(b(20, 20, 20, 40)));

    }

    function testEdges() {

        final uniform = Edges.all(10);
        assertEquals(10.0, uniform.top);
        assertEquals(10.0, uniform.right);
        assertEquals(10.0, uniform.bottom);
        assertEquals(10.0, uniform.left);

        final edges = new Edges(10, 20, 30, 40);
        assertTrue(edges.map(v -> v * 1.5).equals(new Edges(15, 30, 45, 60)));
        assertTrue(edges.scale(2).equals(new Edges(20, 40, 60, 80)));
        assertEquals(40.0, edges.max());
        assertTrue(edges.mul(new Edges(1, 2, 3, 4)).equals(new Edges(10, 40, 90, 160)));

        final sparse = new Edges(10, 0, 5, 0);
        assertTrue(sparse.any(v -> v == 0));
        assertTrue(sparse.any(v -> v > 0));
        assertFalse(sparse.any(v -> v > 10));

        final autoEdges = EdgesOfLength.auto();
        assertTrue(autoEdges.top.equals(Length.Auto));
        assertTrue(autoEdges.left.equals(Length.Auto));

        final zeroLength = EdgesOfLength.zero();
        assertTrue(zeroLength.top.equals(Length.Definite(Pixels.ZERO.toDefiniteLength())));
        assertTrue(zeroLength.bottom.equals(px(0).toLength()));

        final zeroDefinite = EdgesOfDefiniteLength.zero();
        assertTrue(zeroDefinite.right.equals(px(0).toDefiniteLength()));

        final zeroAbsolute = EdgesOfAbsoluteLength.zero();
        assertTrue(zeroAbsolute.left.equals(AbsoluteLength.Pixels(Pixels.ZERO)));

        final definite = new EdgesOf<DefiniteLength>(
            DefiniteLength.Absolute(AbsoluteLength.Pixels(px(10))),
            DefiniteLength.Fraction(0.5),
            DefiniteLength.Absolute(AbsoluteLength.Rems(rems(2))),
            DefiniteLength.Fraction(0.25)
        );
        final parentSize = new SizeOf<AbsoluteLength>(AbsoluteLength.Pixels(px(200)), AbsoluteLength.Pixels(px(100)));
        assertTrue(definite.toPixels(parentSize, px(16)).equals(new Edges(10, 100, 32, 50)));

        final absolute = new EdgesOf<AbsoluteLength>(
            AbsoluteLength.Pixels(px(10)),
            AbsoluteLength.Rems(rems(1)),
            AbsoluteLength.Pixels(px(20)),
            AbsoluteLength.Rems(rems(2))
        );
        assertTrue(absolute.toPixels(px(16)).equals(new Edges(10, 16, 20, 32)));
        assertTrue(absolute.equals(absolute.map(v -> v), AbsoluteLengthTools.equals));
        assertTrue(absolute.any(v -> v.isZero()) == false);

    }

    function testAnchor() {

        assertEquals(Anchor.BottomRight, Anchor.TopLeft.opposite());
        assertEquals(Anchor.LeftCenter, Anchor.RightCenter.opposite());
        assertEquals(Anchor.TopRight, Anchor.TopLeft.otherSideAlong(Horizontal));
        assertEquals(Anchor.BottomLeft, Anchor.TopLeft.otherSideAlong(Vertical));
        assertEquals(Anchor.LeftCenter, Anchor.LeftCenter.otherSideAlong(Vertical));
        assertTrue(Anchor.TopCenter.isCenter());
        assertFalse(Anchor.TopLeft.isCenter());
        assertTrue(Anchor.BottomCenter.isBottom());
        assertFalse(Anchor.RightCenter.isBottom());

    }

    function testCorners() {

        final uniform = Corners.all(5);
        assertEquals(5.0, uniform.topLeft);
        assertEquals(5.0, uniform.bottomLeft);

        final corners = new Corners(10, 20, 40, 30);
        assertEquals(10.0, corners.corner(TopLeft));
        assertEquals(40.0, corners.corner(BottomRight));
        assertEquals(15.0, corners.corner(TopCenter));
        assertEquals(35.0, corners.corner(BottomCenter));
        assertEquals(20.0, corners.corner(LeftCenter));
        assertEquals(30.0, corners.corner(RightCenter));

        final scaled = new Corners(10, 20, 30, 40).scale(2);
        assertTrue(scaled.equals(new Corners(20, 40, 60, 80)));
        assertEquals(40.0, new Corners(10, 20, 30, 40).max());

        final inRems = new Corners(10, 20, 30, 40).map(v -> v / 16.0);
        assertTrue(inRems.equals(new Corners(0.625, 1.25, 1.875, 2.5)));

        final absolute = new CornersOf<AbsoluteLength>(
            AbsoluteLength.Pixels(px(15)),
            AbsoluteLength.Rems(rems(1)),
            AbsoluteLength.Pixels(px(30)),
            AbsoluteLength.Rems(rems(2))
        );
        assertTrue(absolute.toPixels(px(16)).equals(new Corners(15, 16, 30, 32)));

        assertTrue(Corners.all(0).isZero());
        assertFalse(new Corners(0, 0, 0, 1).isZero());

    }

    function testClampRadiiForQuadSize() {

        final corners = new Corners(5, 50, 100, 0);
        // Half of the shortest side is 20
        assertTrue(corners.clampRadiiForQuadSize(size(40, 80)).equals(new Corners(5, 20, 20, 0)));
        assertTrue(corners.clampRadiiForQuadSize(size(300, 250)).equals(corners));
        assertTrue(corners.clampRadiiForQuadSize(size(0, 10)).equals(Corners.all(0)));

    }

    function testUnits() {

        assertEquals('10px', px(10).toString());
        assertEquals('2rem', rems(2).toString());
        assertTrue(px(1) < px(2));
        assertTrue(px(2) >= px(2));
        final sum:Pixels = px(1) + px(2) * 3 - px(0.5);
        assertEquals(6.5, (sum:Float));
        assertEquals(-4.0, (-px(4):Float));
        assertEquals(2.0, (px(2.4).round():Float));
        assertEquals(-3.0, (px(-2.5).round():Float));
        assertEquals(3.0, (px(2.5).round():Float));
        assertEquals(2.0, (px(2.9).floor():Float));
        assertEquals(3.0, (px(2.1).ceil():Float));
        assertEquals(5.0, (px(-5).abs():Float));
        assertEquals(-1.0, px(-5).signum());
        assertEquals(1.0, px(0).signum());
        assertEquals(9.0, (px(3).pow(2):Float));
        assertEquals(20.0, (px(10).scale(2):Float));
        assertEquals(10.0, (Pixels.sum([px(1), px(2), px(3), px(4)]):Float));
        assertEquals(4.0, (px(4).max(px(1)):Float));
        assertEquals(1.0, (px(4).min(px(1)):Float));
        assertTrue(Pixels.MAX > px(1e30));

        assertEquals(32.0, (rems(2).toPixels(px(16)):Float));
        assertEquals(3, new ScaledPixels(2.1).toDevicePixels());
        assertEquals(2.0, (new DevicePixels(2).toScaledPixels():Float));
        assertEquals(400, new DevicePixels(100).toBytes(4));
        assertEquals(3, (new DevicePixels(7).half():Int));
        assertFloatEquals(Math.PI, (percentage(0.5).toRadians():Float));
        // `impl Into<Radians>` arguments take a percentage of a full circle
        final quarter:gpui.Radians = percentage(0.25);
        assertFloatEquals(Math.PI / 2, (quarter:Float));
        assertFloatEquals(Math.PI, (gpui.Svg.Transformation.rotated(percentage(0.5)).rotate:Float));
        assertEquals(1.5, (radians(1.5):Float));

        assertEquals(12.5, (Pixels.parse('12.5px'):Float));
        assertEquals(-3.0, (Pixels.parse('-3px'):Float));
        assertEquals(1.5, (Rems.parse('1.5rem'):Float));
        assertNull(Pixels.tryParse('12'));
        assertNull(Pixels.tryParse('px'));
        assertNull(Pixels.tryParse('12abcpx'));
        assertRaises(() -> Pixels.parse('12rem'));

    }

    function testLengths() {

        final remSize = px(16);
        assertEquals(42.0, (AbsoluteLength.Pixels(px(42)).toPixels(remSize):Float));
        assertEquals(32.0, (AbsoluteLength.Rems(rems(2)).toPixels(remSize):Float));
        assertEquals(2.0, (AbsoluteLength.Pixels(px(32)).toRems(remSize):Float));
        assertTrue(AbsoluteLength.Rems(0).isZero());
        assertTrue(AbsoluteLengthTools.defaultValue().equals(AbsoluteLength.Pixels(0)));

        final baseSize = AbsoluteLength.Pixels(px(100));
        assertEquals(42.0, (DefiniteLength.Absolute(AbsoluteLength.Pixels(px(42))).toPixels(baseSize, remSize):Float));
        assertEquals(32.0, (DefiniteLength.Absolute(AbsoluteLength.Rems(rems(2))).toPixels(baseSize, remSize):Float));
        assertEquals(50.0, (DefiniteLength.Fraction(0.5).toPixels(baseSize, remSize):Float));
        assertEquals(16.0, (DefiniteLength.Fraction(0.5).toPixels(AbsoluteLength.Rems(2), remSize):Float));
        assertTrue(relative(0).isZero());
        assertTrue(phi().equals(DefiniteLength.Fraction(1.618034)));

        assertFalse(Length.Auto.isZero());
        assertTrue(px(0).toLength().isZero());
        assertTrue(LengthTools.defaultValue().equals(px(0).toLength()));
        assertTrue(rems(1).toLength().equals(Length.Definite(DefiniteLength.Absolute(AbsoluteLength.Rems(1)))));
        assertFalse(px(1).toLength().equals(rems(1).toLength()));
        assertTrue(px(2).toAbsoluteLength().neg().equals(AbsoluteLength.Pixels(-2)));

        assertEquals('12px', px(12).toLength().toString());
        assertEquals('50%', relative(0.5).toString());
        assertEquals('auto', auto().toString());

        assertTrue(AbsoluteLengthTools.parse('3rem').equals(AbsoluteLength.Rems(3)));
        assertTrue(DefiniteLengthTools.parse('25%').equals(DefiniteLength.Fraction(0.25)));
        assertTrue(DefiniteLengthTools.parse('4px').equals(px(4).toDefiniteLength()));
        assertTrue(LengthTools.parse('auto').equals(Length.Auto));
        assertTrue(LengthTools.parse('1.5rem').equals(rems(1.5).toLength()));
        assertNull(LengthTools.tryParse('12'));
        assertNull(DefiniteLengthTools.tryParse('x%'));
        assertRaises(() -> LengthTools.parse('big'));

        // Pattern matching on nested enums
        final kind = switch px(3).toLength() {
            case Definite(Absolute(Pixels(v))): 'px ' + (v:Float);
            case Definite(Absolute(Rems(_))): 'rems';
            case Definite(Fraction(_)): 'fraction';
            case Auto: 'auto';
        }
        assertEquals('px 3', kind);

    }

}
