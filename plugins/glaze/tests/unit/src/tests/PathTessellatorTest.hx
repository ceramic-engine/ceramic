package tests;

import gpui.Path;
import gpui.Path.FillOptions;
import gpui.Path.StrokeOptions;
import gpui.PathBuilder;
import gpui.Point;
import gpui.SpringMath.f32;
import testing.TestCase;

import gpui.Prelude.*;

/**
 * The port of lyon (`gpui.PathTessellator`, used by `PathBuilder`) against
 * the vertices of GPUI's own tessellation, dumped by the reference harness
 * (`PathReference`, from the scene dumps of `paths` and `kit-scroll-masks`):
 * the same paths must give exactly the same vertex positions (bit for bit),
 * the same number of stroke vertices and the same bounds.
 */
class PathTessellatorTest extends TestCase {

    /** The paths of the `paths` scenario (`reference/src/path_scenes.rs`), in paint order. */
    static function scenarioPaths():Array<Null<Path>> {
        final result:Array<Null<Path>> = [];

        var b = PathBuilder.fill();
        b.moveTo(point(px(20.), px(100.)));
        b.lineTo(point(px(70.), px(20.)));
        b.lineTo(point(px(120.), px(100.)));
        b.close();
        result.push(b.build());

        final rules:Array<gpui.Path.FillRule> = [EvenOdd, NonZero];
        for (i in 0...rules.length) {
            final cx = f32(190. + i * 120.);
            final cy = 60.;
            b = PathBuilder.fill().withStyle(Fill(new FillOptions().withFillRule(rules[i])));
            for (k in 0...5) {
                final angle = f32(f32(-Math.PI / 2) + f32(f32(f32(k * 4.) * f32(Math.PI)) / 5.));
                final p = point(px(f32(cx + f32(45. * f32(Math.cos(angle))))), px(f32(cy + f32(45. * f32(Math.sin(angle))))));
                if (k == 0)
                    b.moveTo(p);
                else
                    b.lineTo(p);
            }
            b.close();
            result.push(b.build());
        }

        b = PathBuilder.fill();
        b.moveTo(point(px(400.), px(100.)));
        b.cubicBezierTo(point(px(480.), px(100.)), point(px(400.), px(10.)), point(px(500.), px(30.)));
        b.curveTo(point(px(400.), px(100.)), point(px(440.), px(140.)));
        b.close();
        result.push(b.build());

        b = PathBuilder.fill();
        b.moveTo(point(px(20.), px(190.)));
        b.arcTo(point(px(40.), px(40.)), px(0.), false, true, point(px(100.), px(190.)));
        b.arcTo(point(px(40.), px(40.)), px(0.), false, true, point(px(20.), px(190.)));
        b.close();
        result.push(b.build());

        b = PathBuilder.fill();
        b.moveTo(point(px(170.), px(190.)));
        b.lineTo(point(px(220.), px(190.)));
        b.arcTo(point(px(50.), px(50.)), px(0.), true, true, point(px(170.), px(140.)));
        b.close();
        result.push(b.build());

        b = PathBuilder.stroke(px(6.));
        b.moveTo(point(px(260.), px(220.)));
        b.lineTo(point(px(300.), px(150.)));
        b.lineTo(point(px(340.), px(220.)));
        b.lineTo(point(px(380.), px(160.)));
        result.push(b.build());

        b = PathBuilder.stroke(px(3.));
        b.addPolygon([
            point(px(410.), px(150.)),
            point(px(490.), px(150.)),
            point(px(490.), px(220.)),
            point(px(410.), px(220.))
        ], true);
        result.push(b.build());

        b = PathBuilder.stroke(px(4.)).dashArray([px(12.), px(6.)]);
        b.moveTo(point(px(20.), px(270.)));
        b.lineTo(point(px(490.), px(270.)));
        result.push(b.build());

        b = PathBuilder.stroke(px(10.)).withStyle(Stroke(new StrokeOptions().withLineWidth(10.).withMiterLimit(4.)));
        b.moveTo(point(px(30.), px(380.)));
        b.cubicBezierTo(point(px(230.), px(380.)), point(px(80.), px(290.)), point(px(180.), px(470.)));
        result.push(b.build());

        b = PathBuilder.fill();
        b.addPolygon([point(px(0.), px(0.)), point(px(60.), px(0.)), point(px(60.), px(30.)), point(px(0.), px(30.))], true);
        b.rotate(20.);
        b.translate(point(px(280.), px(320.)));
        result.push(b.build());

        // Raw path (not tessellated)
        result.push(null);

        b = PathBuilder.fill();
        b.addPolygon([point(px(250.), px(400.)), point(px(350.), px(380.)), point(px(330.), px(490.))], true);
        result.push(b.build());

        return result;
    }

    /** gpui-kit `ScrollableMask` corner notch (`cornerNotchPath`), as painted by `kit-scroll-masks`. */
    static function notch(cornerX:Float, cornerY:Float, xDir:Float, yDir:Float, radius:Float):Path {
        final builder = PathBuilder.fill();
        builder.moveTo(new Point(cornerX, cornerY));
        builder.lineTo(new Point(cornerX + radius * xDir, cornerY));
        builder.arcTo(new Point(radius, radius), 0., false, xDir * yDir < 0., new Point(cornerX, cornerY + radius * yDir));
        builder.close();
        return builder.build();
    }

    /** The distinct vertex positions of a path in device pixels (scale factor 2), sorted by y then x. */
    static function deviceVertices(path:Path):Array<Float> {
        final points:Array<Array<Float>> = [];
        final seen = new Map<String, Bool>();
        inline function add(x:Float, y:Float) {
            final dx = f32(x * 2);
            final dy = f32(y * 2);
            final key = dx + ',' + dy;
            if (!seen.exists(key)) {
                seen.set(key, true);
                points.push([dx, dy]);
            }
        }
        if (path.fillPolygons != null) {
            for (poly in path.fillPolygons) {
                var i = 0;
                while (i < poly.length) {
                    add(poly[i], poly[i + 1]);
                    i += 2;
                }
            }
        }
        else {
            for (v in path.vertices)
                add(v.xyPosition.x, v.xyPosition.y);
        }
        points.sort((a, b) -> a[1] < b[1] ? -1 : (a[1] > b[1] ? 1 : (a[0] < b[0] ? -1 : (a[0] > b[0] ? 1 : 0))));
        final result:Array<Float> = [];
        for (p in points) {
            result.push(p[0]);
            result.push(p[1]);
        }
        return result;
    }

    function assertSameVertices(expected:Array<Float>, actual:Array<Float>, name:String):Void {
        var same = expected.length == actual.length;
        if (same) {
            for (i in 0...expected.length) {
                if (expected[i] != actual[i]) {
                    same = false;
                    break;
                }
            }
        }
        if (!same) {
            final diffs:Array<String> = [];
            var i = 0;
            while (i < Std.int(Math.max(expected.length, actual.length)) && diffs.length < 6) {
                final ex = i < expected.length ? expected[i] + ',' + expected[i + 1] : '-';
                final ac = i < actual.length ? actual[i] + ',' + actual[i + 1] : '-';
                if (ex != ac)
                    diffs.push('#${i >> 1}: gpui $ex port $ac');
                i += 2;
            }
            assertTrue(false, '$name: ${expected.length >> 1} GPUI vertices, ${actual.length >> 1} port vertices; ' + diffs.join('; '));
        }
        else {
            assertTrue(true);
        }
    }

    function testScenarioPathVerticesMatchGpui() {
        final paths = scenarioPaths();
        assertEquals(PathReference.PATHS.length, paths.length);
        for (i in 0...paths.length) {
            final path = paths[i];
            if (path == null)
                continue;
            assertSameVertices(PathReference.PATHS[i], deviceVertices(path), 'paths[$i]');
        }
    }

    function testStrokeVertexCountsMatchGpui() {
        final paths = scenarioPaths();
        for (i in 6...10)
            assertEquals(PathReference.STROKE_VERTEX_COUNTS[i - 6], paths[i].vertices.length, 'paths[$i] vertex count');
    }

    function testScenarioPathBoundsMatchGpui() {
        final paths = scenarioPaths();
        for (i in 0...paths.length) {
            final path = paths[i];
            if (path == null)
                continue;
            final b = PathReference.PATH_BOUNDS[i];
            final actual = [f32(path.bounds.origin.x * 2), f32(path.bounds.origin.y * 2), f32(path.bounds.size.width * 2), f32(path.bounds.size.height * 2)];
            assertEquals(b.join(','), actual.join(','), 'paths[$i] bounds');
        }
    }

    function testScrollMaskNotchVerticesMatchGpui() {
        // Two scrollable areas: 12 px corners at (12, 12) - (312, 76) and
        // 16 px corners at (224, 88) - (424, 248); TL, TR, BR, BL each
        final notches = [
            notch(12, 12, 1, 1, 12), notch(312, 12, -1, 1, 12), notch(312, 76, -1, -1, 12), notch(12, 76, 1, -1, 12),
            notch(224, 88, 1, 1, 16), notch(424, 88, -1, 1, 16), notch(424, 248, -1, -1, 16), notch(224, 248, 1, -1, 16)
        ];
        assertEquals(PathReference.NOTCHES.length, notches.length);
        for (i in 0...notches.length)
            assertSameVertices(PathReference.NOTCHES[i], deviceVertices(notches[i]), 'notch[$i]');
    }

    function testFastAtan2() {
        // euclid's approximation, in f32 (about 2e-4 from atan2 at 45 degrees)
        assertEquals(0.0, gpui.PathTessellator.fastAtan2(0, 1));
        assertEquals(f32(Math.PI / 2), gpui.PathTessellator.fastAtan2(1, 0));
        final a = f32(f32(f32(f32(f32(f32(-0.0464964749) + f32(0.15931422)) - f32(0.327622764))) * 1) + 1);
        assertEquals(a, gpui.PathTessellator.fastAtan2(1, 1));
        assertEquals(-f32(f32(Math.PI) - a), gpui.PathTessellator.fastAtan2(-1, -1));
        assertTrue(Math.abs(gpui.PathTessellator.fastAtan2(1, 1) - Math.PI / 4) < 1e-3);
    }

}
