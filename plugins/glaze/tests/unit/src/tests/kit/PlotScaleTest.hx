// Ported from gpui-kit 0.8.1: crates/base/src/plot/scale/linear.rs, band.rs, point.rs, ordinal.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.base.plot.scale.ScaleBand;
import gpui.base.plot.scale.ScaleLinear;
import gpui.base.plot.scale.ScaleOrdinal;
import gpui.base.plot.scale.ScalePoint;
import testing.TestCase;

/**
 * Tests of the plot scales (Rust `plot/scale/*.rs`).
 */
class PlotScaleTest extends TestCase {

/// linear.rs

    function testScaleLinear() {
        var scale = new ScaleLinear([1., 2., 3.], [0., 100.]);
        assertEquals(0., scale.tick(1.));
        assertEquals(50., scale.tick(2.));
        assertEquals(100., scale.tick(3.));

        scale = new ScaleLinear([1., 2., 3.], [100., 0.]);
        assertEquals(100., scale.tick(1.));
        assertEquals(50., scale.tick(2.));
        assertEquals(0., scale.tick(3.));
    }

    function testScaleLinearUnorderedDomain() {
        final scale = new ScaleLinear([3., 1., 2.], [0., 100.]);
        assertEquals(0., scale.tick(1.));
        assertEquals(100., scale.tick(3.));
    }

    function testScaleLinearF32() {
        final scale = new ScaleLinear([0., 4.], [0., 100.], true);
        assertEquals(25., scale.tick(1.));
        assertEquals(100., scale.tick(4.));
    }

    function testScaleLinearEmpty() {
        var scale = new ScaleLinear([], [0., 100.]);
        assertEquals(null, scale.tick(1.));
        assertEquals(null, scale.tick(2.));
        assertEquals(null, scale.tick(3.));

        scale = new ScaleLinear([1., 2., 3.], [0., 0.]);
        assertEquals(0., scale.tick(1.));
        assertEquals(0., scale.tick(2.));
        assertEquals(0., scale.tick(3.));
    }

/// band.rs

    function testScaleBand() {
        final scale = new ScaleBand([1, 2, 3], [0., 90.]);
        assertEquals(0., scale.tick(1));
        assertEquals(30., scale.tick(2));
        assertEquals(60., scale.tick(3));
        assertEquals(30., scale.bandWidth());
    }

    function testMaxBandWidthCapsTheWidthButNotTheTicks() {
        final wide = new ScaleBand([1, 2], [0., 200.]);
        final capped = new ScaleBand([1, 2], [0., 200.]).maxBandWidth(30.);
        assertEquals(100., wide.bandWidth());
        assertEquals(30., capped.bandWidth());
        assertEquals(wide.tick(2), capped.tick(2));
    }

    function testScaleBandDedup() {
        // Simulates grouped bar chart: 2 series x 3 categories = 6 entries, 3 unique.
        final scale = new ScaleBand([1, 2, 3, 1, 2, 3], [0., 90.]);
        assertEquals(3, @:privateAccess scale.len());
        assertEquals(0., scale.tick(1));
        assertEquals(30., scale.tick(2));
        assertEquals(60., scale.tick(3));
        assertEquals(30., scale.bandWidth());
    }

    function testScaleBandStep() {
        // Adjacent bands start one step apart, whatever the padding.
        final scale = new ScaleBand([1, 2, 3], [0., 90.]);
        assertEquals(scale.tick(2) - scale.tick(1), scale.step());

        final padded = new ScaleBand([1, 2, 3], [0., 90.]).paddingInner(0.4).paddingOuter(0.2);
        assertTrue(Math.abs(padded.step() - (padded.tick(2) - padded.tick(1))) < 1e-4);

        // A single band spans the range.
        assertEquals(90., new ScaleBand([1], [0., 90.]).step());
    }

    function testScaleBandCount() {
        final scale = (domain:Array<Int>) -> new ScaleBand(domain, [0., 100.]).bandCount(4).paddingInner(0.4).paddingOuter(0.2);

        // The domain takes the leading bands, each placed as if all were full.
        final short = scale([1, 2]);
        final full = scale([1, 2, 3, 4]);
        assertEquals(full.tick(2), short.tick(2));
        assertEquals(full.bandWidth(), short.bandWidth());
        assertEquals(full.step(), short.step());

        // An empty band resolves past the domain rather than to its last value.
        assertEquals(3, short.nearestIndex(full.tick(4)));

        // A single value sits in the first band instead of the center.
        assertEquals(full.tick(1), scale([1]).tick(1));

        // A count below the domain's length has no effect.
        final domain = new ScaleBand([1, 2, 3], [0., 90.]);
        assertEquals(60., domain.bandCount(2).tick(3));
    }

    function testScaleBandZero() {
        var scale = new ScaleBand([], [0., 90.]);
        assertEquals(null, scale.tick(1));
        assertEquals(null, scale.tick(2));
        assertEquals(null, scale.tick(3));
        assertEquals(0., scale.bandWidth());

        scale = new ScaleBand([1, 2, 3], [0., 0.]);
        assertEquals(0., scale.tick(1));
        assertEquals(0., scale.tick(2));
        assertEquals(0., scale.tick(3));
        assertEquals(0., scale.bandWidth());
    }

    function testScaleBandRangeStart() {
        final scale = new ScaleBand([1, 2, 3], [10., 100.]);
        assertEquals(10., scale.tick(1));
        assertEquals(40., scale.tick(2));
        assertEquals(1, scale.nearestIndex(41.));
        // The lower end leads whichever way the range is written.
        assertEquals(10., new ScaleBand([1, 2, 3], [100., 10.]).tick(1));
    }

/// point.rs

    function testScalePoint() {
        final scale = new ScalePoint([1, 2, 3], [0., 100.]);
        assertEquals(0., scale.tick(1));
        assertEquals(50., scale.tick(2));
        assertEquals(100., scale.tick(3));
    }

    function testScalePointRange() {
        final scale = new ScalePoint([1, 2, 3], [40., 80.]);
        assertEquals(40., scale.tick(1));
        assertEquals(60., scale.tick(2));
        assertEquals(80., scale.tick(3));
    }

    function testScalePointEmpty() {
        var scale = new ScalePoint([], [0., 100.]);
        assertEquals(null, scale.tick(1));
        assertEquals(null, scale.tick(2));
        assertEquals(null, scale.tick(3));

        scale = new ScalePoint([1, 2, 3], [0., 0.]);
        assertEquals(0., scale.tick(1));
        assertEquals(0., scale.tick(2));
        assertEquals(0., scale.tick(3));
    }

    function testScalePointSingle() {
        final scale = new ScalePoint([1], [0., 100.]);
        assertEquals(50., scale.tick(1));
    }

    function testTickAtMatchesTick() {
        for (domain in [[], [1], [1, 2, 3], [1, 2, 3, 4, 5]]) {
            final scale = new ScalePoint(domain, [40., 80.]);
            for (i in 0...domain.length) {
                assertEquals(scale.tick(domain[i]), scale.tickAt(i));
            }
            assertEquals(null, scale.tickAt(domain.length));
        }
    }

    function testNearestIndexBasic() {
        final scale = new ScalePoint([1, 2, 3], [0., 100.]);

        // Exact positions
        assertEquals(0, scale.nearestIndex(0.));
        assertEquals(1, scale.nearestIndex(50.));
        assertEquals(2, scale.nearestIndex(100.));

        // Between positions (should round to nearest)
        assertEquals(0, scale.nearestIndex(24.));
        assertEquals(1, scale.nearestIndex(25.));
        assertEquals(1, scale.nearestIndex(26.));
        assertEquals(1, scale.nearestIndex(74.));
        assertEquals(2, scale.nearestIndex(75.));
        assertEquals(2, scale.nearestIndex(76.));

        // Outside range
        assertEquals(0, scale.nearestIndex(-10.));
        assertEquals(2, scale.nearestIndex(150.));
    }

    function testNearestIndexWithOffset() {
        final scale = new ScalePoint([1, 2, 3], [40., 80.]);

        assertEquals(0, scale.nearestIndex(40.));
        assertEquals(1, scale.nearestIndex(60.));
        assertEquals(2, scale.nearestIndex(80.));

        assertEquals(0, scale.nearestIndex(49.));
        assertEquals(1, scale.nearestIndex(50.));
        assertEquals(1, scale.nearestIndex(51.));
        assertEquals(1, scale.nearestIndex(69.));
        assertEquals(2, scale.nearestIndex(70.));
        assertEquals(2, scale.nearestIndex(71.));

        assertEquals(0, scale.nearestIndex(30.));
        assertEquals(2, scale.nearestIndex(100.));
    }

    function testNearestIndexEmpty() {
        final scale = new ScalePoint(([] : Array<Int>), [0., 100.]);
        assertEquals(0, scale.nearestIndex(0.));
        assertEquals(0, scale.nearestIndex(50.));
        assertEquals(0, scale.nearestIndex(100.));
    }

    function testNearestIndexSingle() {
        final scale = new ScalePoint([1], [0., 100.]);
        assertEquals(0, scale.nearestIndex(0.));
        assertEquals(0, scale.nearestIndex(50.));
        assertEquals(0, scale.nearestIndex(100.));
    }

    function testNearestIndexEmptyRange() {
        final scale = new ScalePoint([1, 2, 3], [0., 0.]);
        assertEquals(0, scale.nearestIndex(0.));
        assertEquals(0, scale.nearestIndex(50.));
        assertEquals(0, scale.nearestIndex(100.));
    }

    function testReversedRange() {
        final scale = new ScalePoint([1, 2, 3], [100., 0.]);
        assertEquals(100., scale.tick(1));
        assertEquals(0., scale.tick(3));
        assertEquals(0, scale.nearestIndex(90.));
        assertEquals(2, scale.nearestIndex(10.));
    }

/// ordinal.rs

    function testScaleOrdinal() {
        final scale = new ScaleOrdinal(['a', 'b', 'c', 'd', 'e'], [10, 20, 30]);

        assertEquals(10, scale.map('a'));
        assertEquals(20, scale.map('b'));
        assertEquals(30, scale.map('c'));
        assertEquals(10, scale.map('d'));
        assertEquals(20, scale.map('e'));
        assertEquals(null, scale.map('f'));
    }

    function testScaleOrdinalUnknown() {
        final scale = new ScaleOrdinal(['a', 'b', 'c'], [10, 20, 30]).unknown(0);

        assertEquals(10, scale.map('a'));
        assertEquals(0, scale.map('f'));
    }

    function testScaleOrdinalColors() {
        final keys = ['a', 'b', 'c', 'd'];
        final colors = ['#1f77b4', '#ff7f0e', '#2ca02c'];

        final scale = new ScaleOrdinal(keys, colors);

        assertEquals('#1f77b4', scale.map('a'));
        assertEquals('#ff7f0e', scale.map('b'));
        assertEquals('#2ca02c', scale.map('c'));
        // Should cycle back to the first color
        assertEquals('#1f77b4', scale.map('d'));
    }

}
