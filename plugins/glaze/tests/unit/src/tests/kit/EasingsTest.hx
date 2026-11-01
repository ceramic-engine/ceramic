// Ported from gpui-kit 0.8.1: crates/base/src/animation.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.SpringMath.f32;
import gpui.base.animation.Easings;
import testing.TestCase;

/**
 * Tests of `gpui.base.animation.Easings` (Rust `animation.rs`). The curve is
 * computed in `f32` like Rust, so Rust's tolerances are kept as they are.
 */
class EasingsTest extends TestCase {

    function testCubicBezierMatchesEnginePublishedValues() {
        // Reference values sampled from the CSS `ease` curve.
        final ease = Easings.cubicBezier(0.25, 0.1, 0.25, 1.);
        for (pair in [[0.0, 0.0], [0.2, 0.295], [0.5, 0.802], [0.8, 0.976], [1.0, 1.0]]) {
            final t = pair[0];
            final expected = pair[1];
            assertTrue(Math.abs(ease(t) - expected) < 1e-3, 'ease($t) = ${ease(t)}, expected $expected');
        }

        // Chromium's CubicBezier(0.25, 0, 0.75, 1) expectations, from
        // ui/gfx/geometry/cubic_bezier_unittest.cc (epsilon 0.00015 there;
        // widened for our f32 arithmetic).
        final curve = Easings.cubicBezier(0.25, 0., 0.75, 1.);
        for (pair in [
            [0.05, 0.01136], [0.1, 0.03978], [0.15, 0.07978], [0.2, 0.12803], [0.25, 0.18235],
            [0.3, 0.24115], [0.35, 0.30323], [0.4, 0.36761], [0.45, 0.43345], [0.5, 0.5],
            [0.6, 0.63238], [0.65, 0.69676], [0.7, 0.75884], [0.75, 0.81764], [0.8, 0.87196],
            [0.85, 0.92021], [0.9, 0.96021], [0.95, 0.98863]
        ]) {
            final t = pair[0];
            final expected = pair[1];
            assertTrue(Math.abs(curve(t) - expected) < 3e-4, 'curve($t) = ${curve(t)}, Chromium says $expected');
        }
    }

    function testCubicBezierWithThirdsXMapsTimeIdentically() {
        // x1 = 1/3, x2 = 2/3 collapse the x solve to the identity, making the
        // output the plain y polynomial; Dialog relies on this to keep the
        // trajectory it was tuned with before `cubic_bezier` solved for x.
        final ease = Easings.cubicBezier(1. / 3., 0.72, 2. / 3., 1.);
        for (step in 0...101) {
            final t = f32(step / 100.);
            final oneT = 1. - t;
            final expected = 3. * 0.72 * oneT * oneT * t + 3. * oneT * t * t + t * t * t;
            assertTrue(Math.abs(ease(t) - expected) < 1e-4, 'ease($t) = ${ease(t)}, expected $expected');
        }
    }

    function testCubicBezierMatchesTheCssDefinition() {
        // Reference solver written straight off the CSS Easing Functions
        // definition: solve `x(s) = t` by bisection in f64, then sample
        // `y(s)`, independent of the production Newton solver.
        function sample(p1:Float, p2:Float, s:Float):Float {
            return 3. * p1 * (1. - s) * (1. - s) * s + 3. * p2 * (1. - s) * s * s + s * s * s;
        }
        function cssReference(x1:Float, y1:Float, x2:Float, y2:Float, t:Float):Float {
            var low = 0.0;
            var high = 1.0;
            for (_ in 0...64) {
                final mid = (low + high) / 2.;
                if (sample(x1, x2, mid) < t) {
                    low = mid;
                }
                else {
                    high = mid;
                }
            }
            return sample(y1, y2, (low + high) / 2.);
        }

        final curves:Array<Array<Float>> = [
            // The runtime curves in this repo.
            [0.25, 0.1, 0.25, 1.],
            [1. / 3., 0.72, 2. / 3., 1.],
            // CSS keyword curves.
            [0.42, 0., 1., 1.],
            [0., 0., 0.58, 1.],
            [0.42, 0., 0.58, 1.],
            [0., 0., 1., 1.],
            // Degenerate x slopes: zero at s = 0.5, 0, and 1, forcing the
            // Newton solve to fall back to bisection.
            [1., 0., 0., 1.],
            [0., 0., 0., 1.],
            [1., 0.5, 1., 0.5],
        ];
        for (c in curves) {
            final x1 = f32(c[0]);
            final y1 = f32(c[1]);
            final x2 = f32(c[2]);
            final y2 = f32(c[3]);
            final ease = Easings.cubicBezier(x1, y1, x2, y2);
            var failures = 0;
            var outOfRange = 0;
            for (step in 0...1001) {
                final t = f32(step / 1000.);
                final y = ease(t);
                final expected = f32(cssReference(x1, y1, x2, y2, t));
                if (!(Math.abs(y - expected) < 5e-4)) {
                    failures++;
                    fail('cubicBezier($x1, $y1, $x2, $y2)($t) = $y, CSS = $expected');
                }
                // The public `cubicBezier` keeps its output in [0, 1].
                if (!(y >= 0.0 && y <= 1.0)) {
                    outOfRange++;
                    fail('ease($t) = $y out of range');
                }
            }
            assertEquals(0, failures);
            assertEquals(0, outOfRange);
        }
    }

    function testCubicBezierIsMonotonicAndClamped() {
        final ease = Easings.cubicBezier(0.32, 0.72, 0., 1.);
        assertEquals(0., ease(-1.));
        assertEquals(1., ease(2.));

        var previous = 0.;
        for (step in 0...101) {
            final current = ease(step / 100.);
            assertTrue(current >= previous - 1e-4, 'not monotonic at $step');
            previous = current;
        }
    }

}
