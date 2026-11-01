// Ported from gpui-kit 0.8.1: crates/base/src/plot/shape/sankey.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.base.plot.shape.Sankey;
import testing.TestCase;

/**
 * Tests of the sankey layout (Rust `plot/shape/sankey.rs`).
 */
class PlotSankeyTest extends TestCase {

    static inline final EPSILON:Float = 1e-3;

    static function links(list:Array<Array<Float>>):Array<SankeyLink> {
        return [for (l in list) new SankeyLink(Std.int(l[0]), Std.int(l[1]), l[2])];
    }

    function testSankeyBuilder() {
        var sankey = new Sankey();
        assertEquals(24., @:privateAccess sankey.nodeWidthValue);
        assertEquals(8., @:privateAccess sankey.nodePaddingValue);
        assertEquals(Justify, @:privateAccess sankey.align);
        assertEquals(6, @:privateAccess sankey.iterationsValue);
        assertEquals('0,0,1,1', @:privateAccess [sankey.x0, sankey.y0, sankey.x1, sankey.y1].join(','));

        sankey = new Sankey().nodeWidth(12.).nodePadding(10.).nodeAlign(Left).iterations(10).size(400., 300.);
        assertEquals(12., @:privateAccess sankey.nodeWidthValue);
        assertEquals(10., @:privateAccess sankey.nodePaddingValue);
        assertEquals(Left, @:privateAccess sankey.align);
        assertEquals(10, @:privateAccess sankey.iterationsValue);
        assertEquals('0,0,400,300', @:privateAccess [sankey.x0, sankey.y0, sankey.x1, sankey.y1].join(','));

        sankey = new Sankey().extent(10., 20., 30., 40.);
        assertEquals('10,20,30,40', @:privateAccess [sankey.x0, sankey.y0, sankey.x1, sankey.y1].join(','));
    }

    function testSankeyLayoutChain() {
        // A -> B -> C
        final graph = new Sankey().nodeWidth(10.).size(100., 100.).layout(3, links([[0, 1, 5.], [1, 2, 5.]]));

        assertEquals('0,1,2', [for (n in graph.nodes) n.depth].join(','));
        assertEquals('2,1,0', [for (n in graph.nodes) n.height].join(','));
        assertEquals('0,1,2', [for (n in graph.nodes) n.layer].join(','));
        assertEquals(3, graph.layerCount());

        assertEquals(0., graph.nodes[0].x0);
        assertEquals(45., graph.nodes[1].x0);
        assertEquals(90., graph.nodes[2].x0);
        for (node in graph.nodes) {
            assertEquals(10., node.x1 - node.x0);
            assertEquals(5., node.value);
            // Every node carries the full flow, so all span the full height.
            assertTrue(Math.abs(node.y1 - node.y0 - 100.) < EPSILON);
        }
        for (link in graph.links) {
            assertTrue(Math.abs(link.width - 100.) < EPSILON);
            // The chain is balanced, so both ribbon ends span the nodes.
            assertTrue(Math.abs(link.sourceWidth - 100.) < EPSILON);
            assertTrue(Math.abs(link.targetWidth - 100.) < EPSILON);
        }

        // `topology` agrees with `layout` on the topological fields.
        final topology = new Sankey().nodeWidth(10.).size(100., 100.).topology(3, links([[0, 1, 5.], [1, 2, 5.]]));
        assertEquals(3, topology.layerCount());
        for (i in 0...3) {
            final a = topology.nodes[i];
            final b = graph.nodes[i];
            assertEquals(b.depth, a.depth);
            assertEquals(b.height, a.height);
            assertEquals(b.layer, a.layer);
            assertEquals(b.value, a.value);
            assertEquals(b.x0, a.x0);
        }

        // Completing a unit-extent topology on the final extent matches a
        // direct layout on that extent.
        final unit = new Sankey().nodeWidth(10.).topology(3, links([[0, 1, 5.], [1, 2, 5.]]));
        final completed = new Sankey().nodeWidth(10.).size(100., 100.).layoutFrom(unit);
        for (i in 0...3) {
            final a = completed.nodes[i];
            final b = graph.nodes[i];
            assertEquals('${b.x0},${b.y0},${b.x1},${b.y1}', '${a.x0},${a.y0},${a.x1},${a.y1}');
        }
        for (i in 0...completed.links.length) {
            final a = completed.links[i];
            final b = graph.links[i];
            assertEquals('${b.y0},${b.y1},${b.width}', '${a.y0},${a.y1},${a.width}');
        }
    }

    function testSankeyTopologyLargeChain() {
        final count = 50000;
        final list = [for (source in 0...count - 1) new SankeyLink(source, source + 1, 1.)];
        final graph = new Sankey().topology(count, list);

        assertEquals(count - 1, graph.nodes[0].height);
        assertEquals(count - 1, graph.nodes[count - 1].depth);
    }

    function testSankeyAlignment() {
        // A -> B -> C, plus a short branch A -> D.
        final list = links([[0, 1, 1.], [1, 2, 1.], [0, 3, 1.]]);
        final layers = (align:SankeyAlign) -> [for (n in new Sankey().nodeAlign(align).size(100., 100.).layout(4, list).nodes) n.layer].join(',');

        assertEquals('0,1,2,1', layers(Left));
        assertEquals('0,1,2,2', layers(Right));
        assertEquals('0,1,2,2', layers(Justify));
        assertEquals('0,1,2,1', layers(Center));
    }

    function testSankeyLinkOffsets() {
        // One source fanning out into two targets.
        final graph = new Sankey().nodeWidth(10.).size(100., 100.).layout(3, links([[0, 1, 30.], [0, 2, 10.]]));

        final source = graph.nodes[0];
        final sourceHeight = source.y1 - source.y0;
        var totalWidth = 0.;
        for (l in graph.links) totalWidth += l.width;
        assertTrue(Math.abs(totalWidth - sourceHeight) < EPSILON);

        // Widths are proportional to values.
        assertTrue(Math.abs(graph.links[0].width / graph.links[1].width - 3.) < EPSILON);

        // Outgoing ribbons stack contiguously within the source node.
        final first = graph.links[0].y0 < graph.links[1].y0 ? graph.links[0] : graph.links[1];
        final second = graph.links[0].y0 < graph.links[1].y0 ? graph.links[1] : graph.links[0];
        assertTrue(Math.abs(first.y0 - first.sourceWidth / 2. - source.y0) < EPSILON);
        assertTrue(Math.abs(first.y0 + first.sourceWidth / 2. - (second.y0 - second.sourceWidth / 2.)) < EPSILON);

        // Each target has a single incoming ribbon filling its full height.
        for (link in graph.links) {
            final target = graph.nodes[link.target];
            assertTrue(Math.abs(link.y1 - link.targetWidth / 2. - target.y0) < EPSILON);
            assertTrue(Math.abs(link.y1 + link.targetWidth / 2. - target.y1) < EPSILON);
        }
    }

    function testSankeyImbalancedLinkWidths() {
        // A -> B (10) but B -> C (7).
        final graph = new Sankey().size(100., 100.).layout(3, links([[0, 1, 10.], [1, 2, 7.]]));

        final nodeB = graph.nodes[1];
        final nodeC = graph.nodes[2];
        final outLink = graph.links[1];
        assertTrue(Math.abs(outLink.sourceWidth - (nodeB.y1 - nodeB.y0)) < EPSILON);
        assertTrue(Math.abs(outLink.targetWidth - (nodeC.y1 - nodeC.y0)) < EPSILON);
        // The two ends differ: B is taller (value 10) than C (value 7).
        assertTrue(outLink.sourceWidth > outLink.targetWidth);

        // Both ends stay centered on their nodes' filled ranges.
        assertTrue(Math.abs(outLink.y0 - (nodeB.y0 + nodeB.y1) / 2.) < EPSILON);
        assertTrue(Math.abs(outLink.y1 - (nodeC.y0 + nodeC.y1) / 2.) < EPSILON);
    }

    function testSankeySqrtScaleFillsNodes() {
        final list = links([[0, 1, 90.], [1, 2, 40.], [1, 3, 50.]]);
        final sqrt = new Sankey().valueScale(Sqrt).size(100., 100.).layout(4, list);

        for (node in sqrt.nodes) {
            final nodeHeight = node.y1 - node.y0;
            var incoming = 0.;
            for (l in node.targetLinks) incoming += sqrt.links[l].targetWidth;
            var outgoing = 0.;
            for (l in node.sourceLinks) outgoing += sqrt.links[l].sourceWidth;
            if (node.targetLinks.length != 0) {
                assertTrue(Math.abs(incoming - nodeHeight) < EPSILON);
            }
            if (node.sourceLinks.length != 0) {
                assertTrue(Math.abs(outgoing - nodeHeight) < EPSILON);
            }
        }

        // Two leaf nodes (50 and 40) show the sqrt compression directly.
        final ratio = (sqrt.nodes[3].y1 - sqrt.nodes[3].y0) / (sqrt.nodes[2].y1 - sqrt.nodes[2].y0);
        assertTrue(Math.abs(ratio - Math.sqrt(50. / 40.)) < 0.02);
    }

    function testSankeyValueConservation() {
        final graph = new Sankey().size(100., 100.).layout(3, links([[0, 1, 10.], [1, 2, 7.]]));

        assertEquals(10., graph.nodes[1].value);

        for (node in graph.nodes) {
            assertTrue(node.y0 <= node.y1);
            assertTrue(node.y0 >= -EPSILON);
            assertTrue(node.y1 <= 100. + EPSILON);
        }
    }

    function testSankeyVerticalCentering() {
        final graph = new Sankey()
            .nodePadding(20.)
            .extent(0., 10., 100., 90.)
            .layout(5, links([[0, 2, 40.], [1, 2, 10.], [2, 3, 25.], [2, 4, 25.]]));

        final layers = graph.layerCount();
        final lo = [for (_ in 0...layers) Math.POSITIVE_INFINITY];
        final hi = [for (_ in 0...layers) Math.NEGATIVE_INFINITY];
        for (node in graph.nodes) {
            lo[node.layer] = Math.min(lo[node.layer], node.y0);
            hi[node.layer] = Math.max(hi[node.layer], node.y1);
        }
        // Extent is [10, 90], midpoint 50; every column's midpoint matches.
        for (l in 0...layers) {
            assertTrue(Math.abs((lo[l] + hi[l]) / 2. - 50.) < EPSILON);
        }
        // Centering keeps every node within the extent.
        for (node in graph.nodes) {
            assertTrue(node.y0 >= 10. - EPSILON);
            assertTrue(node.y1 <= 90. + EPSILON);
        }
    }

    function testSankeyStaggerFlatColumns() {
        final graph = new Sankey()
            .nodePadding(20.)
            .size(100., 100.)
            .layout(6, links([[0, 1, 100.], [1, 2, 40.], [1, 3, 30.], [1, 4, 20.], [1, 5, 10.]]));

        final c0 = (graph.nodes[0].y0 + graph.nodes[0].y1) / 2.;
        final c1 = (graph.nodes[1].y0 + graph.nodes[1].y1) / 2.;
        assertTrue(Math.abs(c0 - c1) > EPSILON);
        for (node in graph.nodes) {
            assertTrue(node.y0 >= -EPSILON);
            assertTrue(node.y1 <= 100. + EPSILON);
        }

        // Each ribbon end stays attached to its node after the stagger.
        for (node in graph.nodes) {
            var y = node.y0;
            for (l in node.sourceLinks) {
                final link = graph.links[l];
                assertTrue(Math.abs(link.y0 - (y + link.sourceWidth / 2.)) < EPSILON);
                y += link.sourceWidth;
            }
            y = node.y0;
            for (l in node.targetLinks) {
                final link = graph.links[l];
                assertTrue(Math.abs(link.y1 - (y + link.targetWidth / 2.)) < EPSILON);
                y += link.targetWidth;
            }
        }
    }

    static function error(f:() -> Dynamic):Null<SankeyError> {
        try {
            f();
        }
        catch (e:SankeyError) {
            return e;
        }
        return null;
    }

    function testSankeyCircularLink() {
        final sankey = new Sankey().size(100., 100.);

        assertTrue(Type.enumEq(CircularLink, error(() -> sankey.layout(2, links([[0, 1, 1.], [1, 0, 1.]])))));
        assertTrue(Type.enumEq(CircularLink, error(() -> sankey.layout(1, links([[0, 0, 1.]])))));
        assertTrue(Type.enumEq(MissingNode(5), error(() -> sankey.layout(2, links([[0, 5, 1.]])))));
    }

    function testSankeyDegenerate() {
        // Empty graph.
        var graph = new Sankey().size(100., 100.).layout(0, []);
        assertEquals(0, graph.nodes.length);
        assertEquals(0, graph.links.length);
        assertEquals(0, graph.layerCount());

        // All-zero link values must not produce NaN coordinates.
        graph = new Sankey().size(100., 100.).layout(2, links([[0, 1, 0.]]));
        for (node in graph.nodes) {
            assertTrue(Math.abs(node.y1 - node.y0) < EPSILON);
            assertTrue(Math.isFinite(node.x0) && Math.isFinite(node.x1));
            assertTrue(Math.isFinite(node.y0) && Math.isFinite(node.y1));
        }

        // Isolated nodes collapse into a single column without dividing by zero.
        graph = new Sankey().size(100., 100.).layout(2, []);
        assertEquals(1, graph.layerCount());
        for (node in graph.nodes) {
            assertEquals(0., node.x0);
            assertTrue(Math.isFinite(node.y0) && Math.isFinite(node.y1));
        }
    }

    function testPowiMatchesRepeatedSquaring() {
        final f = gpui.SpringMath.f32;
        assertEquals(1., @:privateAccess Sankey.powi(f(0.99), 0));
        assertEquals(f(0.99), @:privateAccess Sankey.powi(f(0.99), 1));
        assertEquals(f(f(0.99) * f(0.99)), @:privateAccess Sankey.powi(f(0.99), 2));
    }

}
