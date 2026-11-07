// Ported from gpui-kit 0.8.1: crates/base/src/plot/shape/sankey.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// @reference: https://github.com/d3/d3-sankey
package gpui.base.plot.shape;

import gpui.Path;
import gpui.PathBuilder;
import gpui.Point;
import gpui.SpringMath;
import gpui.base.plot.Plot;

/**
 * Horizontal alignment of nodes across layers. Mirrors d3-sankey's
 * `sankeyLeft` / `sankeyRight` / `sankeyCenter` / `sankeyJustify`.
 */
enum abstract SankeyAlign(Int) {
    var Left = 0;
    var Right = 1;
    var Center = 2;
    /** The default. */
    var Justify = 3;

    public inline function toInt():Int {
        return this;
    }
}

/**
 * How flow values map to node heights and ribbon widths.
 */
enum abstract SankeyValueScale(Int) {

    /** Height is proportional to the value (standard sankey semantics). The default. */
    var Linear = 0;

    /**
     * Height is proportional to the square root of the value, compressing a
     * wide value range so a dominant flow doesn't dwarf the small ones.
     */
    var Sqrt = 1;

    public inline function toInt():Int {
        return this;
    }

    @:allow(gpui.base.plot)
    function apply(value:Float):Float {
        return switch (cast this : SankeyValueScale) {
            case Linear: value;
            // Guard against tiny negatives from bad data.
            case Sqrt: Math.sqrt(Math.max(value, 0.));
        }
    }

}

/**
 * A reason a Sankey layout could not be computed (thrown by `topology` and
 * `layout`, Rust returns it in a `Result`).
 */
enum SankeyError {
    /** A link references a node index out of range. */
    MissingNode(index:Int);
    /** The graph contains a circular link. */
    CircularLink;
}

/**
 * An input link of a Sankey diagram: `source` and `target` are indices into
 * the node list, `value` is the flow amount (an `f64`).
 */
class SankeyLink {

    public final source:Int;

    public final target:Int;

    public final value:Float;

    public function new(source:Int, target:Int, value:Float) {
        this.source = source;
        this.target = target;
        this.value = value;
    }

}

/**
 * A node with computed layout (d3-sankey's computed node fields).
 */
class SankeyNodeLayout {

    public var index:Int = 0;

    /**
     * The node's throughput in the layout's value space: max(sum of
     * incoming, sum of outgoing). With a non-linear `SankeyValueScale` this
     * is in scaled units.
     */
    public var value:Float = 0.;

    /** Topological distance from any source node (longest path). */
    public var depth:Int = 0;

    /** Topological distance to any sink node (longest path). */
    public var height:Int = 0;

    /** Horizontal column index after alignment. */
    public var layer:Int = 0;

    public var x0:Float = 0.;

    public var x1:Float = 0.;

    public var y0:Float = 0.;

    public var y1:Float = 0.;

    /** Indices into `SankeyGraph.links` of the outgoing links. */
    public var sourceLinks:Array<Int> = [];

    /** Indices into `SankeyGraph.links` of the incoming links. */
    public var targetLinks:Array<Int> = [];

    public function new(index:Int) {
        this.index = index;
    }

}

/**
 * A link with computed layout. Like d3-sankey, `y0` and `y1` are the
 * vertical centers of the ribbon at the source and target end. Each end has
 * its own width: the links of a node's side share the node height in
 * proportion to their values.
 */
class SankeyLinkLayout {

    public var index:Int;

    public var source:Int;

    public var target:Int;

    /** The flow value in the layout's value space. */
    public var value:Float;

    public var y0:Float = 0.;

    public var y1:Float = 0.;

    /** The nominal width from the global value scale, used by the layout relaxation. */
    public var width:Float = 0.;

    /** The ribbon width at the source end. */
    public var sourceWidth:Float = 0.;

    /** The ribbon width at the target end. */
    public var targetWidth:Float = 0.;

    public function new(index:Int, source:Int, target:Int, value:Float) {
        this.index = index;
        this.source = source;
        this.target = target;
        this.value = value;
    }

}

/**
 * The computed Sankey layout.
 */
class SankeyGraph {

    public var nodes:Array<SankeyNodeLayout> = [];

    public var links:Array<SankeyLinkLayout> = [];

    public function new() {}

    /** Number of layers (max layer + 1), 0 for an empty graph. */
    public function layerCount():Int {
        var count = 0;
        for (node in nodes) {
            if (node.layer + 1 > count) {
                count = node.layer + 1;
            }
        }
        return count;
    }

}

/**
 * The Sankey layout generator.
 */
class Sankey {

    /**
     * Vertical offset, as a fraction of node height, applied to stagger runs
     * of equal-height single-node columns so their otherwise-flat ribbons
     * curve.
     */
    static final STAGGER_RATIO:Float = SpringMath.f32(0.15);

    static final EPS_6:Float = SpringMath.f32(1e-6);

    static final EPS_3:Float = SpringMath.f32(1e-3);

    @:allow(tests) var nodeWidthValue:Float = 24.;

    @:allow(tests) var nodePaddingValue:Float = 8.;

    @:allow(tests) var align:SankeyAlign = Justify;

    @:allow(tests) var iterationsValue:Int = 6;

    @:allow(tests) var valueScaleValue:SankeyValueScale = Linear;

    @:allow(tests) var x0:Float = 0.;

    @:allow(tests) var y0:Float = 0.;

    @:allow(tests) var x1:Float = 1.;

    @:allow(tests) var y1:Float = 1.;

    /** A generator with the d3-sankey defaults. */
    public function new() {}

    /** Set the node rectangle width. Defaults to 24. */
    public function nodeWidth(nodeWidth:Float):Sankey {
        nodeWidthValue = f(nodeWidth);
        return this;
    }

    /** Set the vertical gap between nodes in a column. Defaults to 8. */
    public function nodePadding(nodePadding:Float):Sankey {
        nodePaddingValue = f(nodePadding);
        return this;
    }

    /** Set the node alignment. Defaults to `Justify`. */
    public function nodeAlign(align:SankeyAlign):Sankey {
        this.align = align;
        return this;
    }

    /** Set the number of relaxation passes. Defaults to 6. */
    public function iterations(iterations:Int):Sankey {
        iterationsValue = iterations;
        return this;
    }

    /** Set how values map to heights. Defaults to `Linear`. */
    public function valueScale(valueScale:SankeyValueScale):Sankey {
        valueScaleValue = valueScale;
        return this;
    }

    /** Set the layout bounds as `[[x0, y0], [x1, y1]]`. Defaults to `[[0, 0], [1, 1]]`. */
    public function extent(x0:Float, y0:Float, x1:Float, y1:Float):Sankey {
        this.x0 = f(x0);
        this.y0 = f(y0);
        this.x1 = f(x1);
        this.y1 = f(y1);
        return this;
    }

    /** Equivalent to `extent(0., 0., width, height)`. */
    public function size(width:Float, height:Float):Sankey {
        return extent(0., 0., width, height);
    }

    /**
     * Compute the topology only: node `value`, `depth`, `height`, `layer`
     * and horizontal positions, without the vertical placement. Throws a
     * `SankeyError` if a link references a node out of range or the graph
     * contains a cycle.
     */
    public function topology(nodeCount:Int, links:Array<SankeyLink>):SankeyGraph {
        for (link in links) {
            if (link.source >= nodeCount) {
                throw MissingNode(link.source);
            }
            if (link.target >= nodeCount) {
                throw MissingNode(link.target);
            }
        }

        final graph = new SankeyGraph();
        graph.nodes = [for (index in 0...nodeCount) new SankeyNodeLayout(index)];
        // Layout works in scaled value space; all downstream math stays
        // coherent because it is additive in this space.
        graph.links = [
            for (index in 0...links.length)
                new SankeyLinkLayout(index, links[index].source, links[index].target, valueScaleValue.apply(links[index].value))
        ];
        if (nodeCount == 0) {
            return graph;
        }

        computeNodeLinks(graph);
        computeNodeValues(graph);
        computeNodeRanks(graph);
        computeNodeLayers(graph);

        return graph;
    }

    /**
     * Compute the full layout: `topology` plus the vertical node placement
     * and link breadths. Throws a `SankeyError` like `topology`.
     */
    public function layout(nodeCount:Int, links:Array<SankeyLink>):SankeyGraph {
        return layoutFrom(topology(nodeCount, links));
    }

    /**
     * Complete the layout for a graph produced by `topology` (which it
     * updates and returns), avoiding a second topology pass when the extent
     * only becomes known after measuring against the column structure.
     */
    public function layoutFrom(graph:SankeyGraph):SankeyGraph {
        if (graph.nodes.length == 0) {
            return graph;
        }

        computeNodeLayers(graph);

        final columns:Array<Array<Int>> = [for (_ in 0...graph.layerCount()) []];
        for (node in graph.nodes) {
            columns[node.layer].push(node.index);
        }

        computeNodeBreadths(graph, columns);
        computeLinkBreadths(graph);
        centerColumns(graph);
        staggerFlatColumns(graph);

        return graph;
    }

    /**
     * Vertically center each column's stack of nodes within the extent,
     * translating it, so the relaxation's within-column arrangement and the
     * ribbon fits are preserved.
     */
    function centerColumns(graph:SankeyGraph):Void {
        final layers = graph.layerCount();
        if (layers == 0) {
            return;
        }

        final lo = [for (_ in 0...layers) Math.POSITIVE_INFINITY];
        final hi = [for (_ in 0...layers) Math.NEGATIVE_INFINITY];
        for (node in graph.nodes) {
            lo[node.layer] = Math.min(lo[node.layer], node.y0);
            hi[node.layer] = Math.max(hi[node.layer], node.y1);
        }
        final offsets = [
            for (l in 0...layers)
                Math.isFinite(lo[l]) && hi[l] > lo[l] ? f(f(f(f(y0 + y1) - lo[l]) - hi[l]) / 2.) : 0.
        ];

        applyLayerOffsets(graph, offsets);
    }

    /**
     * Nudge runs of adjacent single-node columns of (near-)equal height off
     * the shared center line, so the ribbon between them curves.
     */
    function staggerFlatColumns(graph:SankeyGraph):Void {
        final layers = graph.layerCount();
        if (layers < 2) {
            return;
        }

        final count = [for (_ in 0...layers) 0];
        final single = [for (_ in 0...layers) -1];
        for (node in graph.nodes) {
            count[node.layer] += 1;
            single[node.layer] = node.index;
        }
        final heights = [
            for (l in 0...layers) {
                if (count[l] == 1) {
                    final n = graph.nodes[single[l]];
                    f(n.y1 - n.y0);
                }
                else {
                    0.;
                }
            }
        ];

        // Offset the odd columns of each flat run, leaving the even ones on
        // the center line, so consecutive ribbons bend down then back up.
        final offsets = [for (_ in 0...layers) 0.];
        var run = 0;
        for (l in 1...layers) {
            final flat = count[l] == 1 && count[l - 1] == 1 && Math.abs(f(heights[l] - heights[l - 1])) < EPS_3;
            if (flat) {
                run += 1;
                if (run % 2 == 1) {
                    // Bound the nudge by the slack so the node stays inside
                    // the extent (a column that fills the height can't move).
                    final slack = Math.max(f(f(y1 - y0) - heights[l]), 0.);
                    offsets[l] = Math.min(f(heights[l] * STAGGER_RATIO), f(slack / 2.));
                }
            }
            else {
                run = 0;
            }
        }

        applyLayerOffsets(graph, offsets);
    }

    function alignLayer(graph:SankeyGraph, index:Int, n:Int):Int {
        final node = graph.nodes[index];
        return switch align {
            case Left: node.depth;
            case Right: n - 1 - node.height;
            case Justify: node.sourceLinks.length == 0 ? n - 1 : node.depth;
            case Center:
                if (node.targetLinks.length != 0) {
                    node.depth;
                }
                else if (node.sourceLinks.length != 0) {
                    var min:Null<Int> = null;
                    for (link in node.sourceLinks) {
                        final depth = graph.nodes[graph.links[link].target].depth;
                        if (min == null || depth < min) min = depth;
                    }
                    final value:Int = min == null ? 1 : min;
                    value > 0 ? value - 1 : 0;
                }
                else {
                    0;
                }
        }
    }

    function computeNodeLayers(graph:SankeyGraph):Void {
        var n = 0;
        for (node in graph.nodes) {
            if (node.depth + 1 > n) n = node.depth + 1;
        }
        final kx = n > 1 ? f(f(f(x1 - x0) - nodeWidthValue) / (n - 1)) : 0.;

        final layers = [
            for (index in 0...graph.nodes.length) {
                final layer = alignLayer(graph, index, n);
                layer < n - 1 ? layer : n - 1;
            }
        ];

        for (index in 0...layers.length) {
            final node = graph.nodes[index];
            final layer = layers[index];
            node.layer = layer;
            node.x0 = f(x0 + f(layer * kx));
            node.x1 = f(node.x0 + nodeWidthValue);
        }
    }

    function computeNodeBreadths(graph:SankeyGraph, columns:Array<Array<Int>>):Void {
        var maxColumnLen = 0;
        for (column in columns) {
            if (column.length > maxColumnLen) maxColumnLen = column.length;
        }
        final py = maxColumnLen > 1 ? Math.min(nodePaddingValue, f(f(y1 - y0) / (maxColumnLen - 1))) : nodePaddingValue;

        initializeNodeBreadths(graph, columns, py);

        for (i in 0...iterationsValue) {
            final alpha = powi(f(0.99), i);
            final beta = Math.max(f(1. - alpha), f((i + 1) / iterationsValue));
            relaxRightToLeft(graph, columns, alpha, beta, py);
            relaxLeftToRight(graph, columns, alpha, beta, py);
        }
    }

    function initializeNodeBreadths(graph:SankeyGraph, columns:Array<Array<Int>>, py:Float):Void {
        // Scale factor between flow value and pixels. d3 lets an
        // over-crowded column produce a negative ky; clamp to zero so heights
        // never invert.
        var ky = Math.POSITIVE_INFINITY;
        for (column in columns) {
            var valueSum = 0.;
            for (index in column) {
                valueSum += graph.nodes[index].value;
            }
            if (valueSum > 0.) {
                final k = f(f(f(y1 - y0) - f((column.length - 1) * py)) / f(valueSum));
                ky = minF32(ky, k);
            }
        }
        if (!Math.isFinite(ky)) {
            ky = 0.;
        }
        ky = Math.max(ky, 0.);

        for (column in columns) {
            var y = y0;
            for (index in column) {
                final node = graph.nodes[index];
                final nodeHeight = f(f(node.value) * ky);
                node.y0 = y;
                node.y1 = f(y + nodeHeight);
                y = f(node.y1 + py);
            }

            // Distribute the leftover vertical space evenly (d3 keeps this
            // signed: an over-crowded column shifts nodes back up).
            final leftover = f(f(f(y1 - y) + py) / (column.length + 1));
            for (i in 0...column.length) {
                final node = graph.nodes[column[i]];
                final dy = f(leftover * (i + 1));
                node.y0 = f(node.y0 + dy);
                node.y1 = f(node.y1 + dy);
            }
        }

        for (link in graph.links) {
            link.width = f(f(link.value) * ky);
        }

        for (column in columns) {
            for (index in column) {
                sortSourceLinks(graph, index);
                sortTargetLinks(graph, index);
            }
        }
    }

    /** Reposition each node based on its incoming links. */
    function relaxLeftToRight(graph:SankeyGraph, columns:Array<Array<Int>>, alpha:Float, beta:Float, py:Float):Void {
        for (i in 1...columns.length) {
            for (target in columns[i]) {
                var y = 0.;
                var w = 0.;
                for (linkIndex in graph.nodes[target].targetLinks) {
                    final link = graph.links[linkIndex];
                    final v = f(f(link.value) * f(graph.nodes[target].layer - graph.nodes[link.source].layer));
                    y = f(y + f(targetTop(graph, link.source, target, py) * v));
                    w = f(w + v);
                }
                if (w <= 0.) {
                    continue;
                }
                final node = graph.nodes[target];
                final dy = f(f(f(y / w) - node.y0) * alpha);
                node.y0 = f(node.y0 + dy);
                node.y1 = f(node.y1 + dy);
                reorderNodeLinks(graph, target);
            }
            sortColumn(graph, columns[i]);
            resolveCollisions(graph, columns[i], beta, py);
        }
    }

    /** Reposition each node based on its outgoing links. */
    function relaxRightToLeft(graph:SankeyGraph, columns:Array<Array<Int>>, alpha:Float, beta:Float, py:Float):Void {
        var i = columns.length - 2;
        while (i >= 0) {
            for (source in columns[i]) {
                var y = 0.;
                var w = 0.;
                for (linkIndex in graph.nodes[source].sourceLinks) {
                    final link = graph.links[linkIndex];
                    final v = f(f(link.value) * f(graph.nodes[link.target].layer - graph.nodes[source].layer));
                    y = f(y + f(sourceTop(graph, source, link.target, py) * v));
                    w = f(w + v);
                }
                if (w <= 0.) {
                    continue;
                }
                final node = graph.nodes[source];
                final dy = f(f(f(y / w) - node.y0) * alpha);
                node.y0 = f(node.y0 + dy);
                node.y1 = f(node.y1 + dy);
                reorderNodeLinks(graph, source);
            }
            sortColumn(graph, columns[i]);
            resolveCollisions(graph, columns[i], beta, py);
            i--;
        }
    }

    /**
     * d3's middle-out collision resolution: push nodes away from the middle
     * node, then clamp the column against the extent edges.
     */
    function resolveCollisions(graph:SankeyGraph, column:Array<Int>, beta:Float, py:Float):Void {
        if (column.length == 0) {
            return;
        }

        final i = column.length >> 1;
        final subjectY0 = graph.nodes[column[i]].y0;
        final subjectY1 = graph.nodes[column[i]].y1;
        pushUp(graph, column.slice(0, i), f(subjectY0 - py), beta, py);
        pushDown(graph, column.slice(i + 1), f(subjectY1 + py), beta, py);
        pushUp(graph, column, y1, beta, py);
        pushDown(graph, column, y0, beta, py);
    }

    /** Shift every node (and its attached link ends) by its layer's offset. */
    static function applyLayerOffsets(graph:SankeyGraph, offsets:Array<Float>):Void {
        final nodeOffset = [for (n in graph.nodes) offsets[n.layer]];
        for (node in graph.nodes) {
            final dy = nodeOffset[node.index];
            node.y0 = f(node.y0 + dy);
            node.y1 = f(node.y1 + dy);
        }
        for (link in graph.links) {
            link.y0 = f(link.y0 + nodeOffset[link.source]);
            link.y1 = f(link.y1 + nodeOffset[link.target]);
        }
    }

    static function computeNodeLinks(graph:SankeyGraph):Void {
        for (index in 0...graph.links.length) {
            final link = graph.links[index];
            graph.nodes[link.source].sourceLinks.push(index);
            graph.nodes[link.target].targetLinks.push(index);
        }
    }

    static function computeNodeValues(graph:SankeyGraph):Void {
        for (node in graph.nodes) {
            var outgoing = 0.;
            for (link in node.sourceLinks) {
                outgoing += graph.links[link].value;
            }
            var incoming = 0.;
            for (link in node.targetLinks) {
                incoming += graph.links[link].value;
            }
            node.value = Math.max(outgoing, incoming);
        }
    }

    /**
     * Assign the longest-path `depth` (from any source) and `height` (to any
     * sink) from a single topological ordering. A node left unordered means
     * its incoming links never resolved, i.e. a cycle.
     */
    static function computeNodeRanks(graph:SankeyGraph):Void {
        final n = graph.nodes.length;
        final incoming = [for (node in graph.nodes) node.targetLinks.length];
        // Doubles as the traversal queue and, once drained, the topological order.
        final order = [for (index in 0...n) if (incoming[index] == 0) index];

        final depths = [for (_ in 0...n) 0];
        var visited = 0;
        while (visited < order.length) {
            final index = order[visited];
            visited += 1;
            final depth = depths[index] + 1;
            for (link in graph.nodes[index].sourceLinks) {
                final target = graph.links[link].target;
                if (depth > depths[target]) depths[target] = depth;
                incoming[target] -= 1;
                if (incoming[target] == 0) {
                    order.push(target);
                }
            }
        }
        if (order.length != n) {
            throw CircularLink;
        }

        // Walking the order backwards means every target's height is
        // already final when its sources are visited.
        final heights = [for (_ in 0...n) 0];
        var k = order.length - 1;
        while (k >= 0) {
            final index = order[k];
            for (link in graph.nodes[index].sourceLinks) {
                final h = heights[graph.links[link].target] + 1;
                if (h > heights[index]) heights[index] = h;
            }
            k--;
        }

        for (i in 0...n) {
            graph.nodes[i].depth = depths[i];
            graph.nodes[i].height = heights[i];
        }
    }

    /** Sort a node's outgoing links by the target node's `y0` (then link index). */
    static function sortSourceLinks(graph:SankeyGraph, index:Int):Void {
        graph.nodes[index].sourceLinks.sort((a, b) -> {
            final ya = graph.nodes[graph.links[a].target].y0;
            final yb = graph.nodes[graph.links[b].target].y0;
            final c = compareF32(ya, yb);
            c != 0 ? c : (a < b ? -1 : (a > b ? 1 : 0));
        });
    }

    /** Sort a node's incoming links by the source node's `y0` (then link index). */
    static function sortTargetLinks(graph:SankeyGraph, index:Int):Void {
        graph.nodes[index].targetLinks.sort((a, b) -> {
            final ya = graph.nodes[graph.links[a].source].y0;
            final yb = graph.nodes[graph.links[b].source].y0;
            final c = compareF32(ya, yb);
            c != 0 ? c : (a < b ? -1 : (a > b ? 1 : 0));
        });
    }

    /**
     * After a node moved, re-sort the link lists of its neighbors on the
     * opposite ends (d3's reorderNodeLinks).
     */
    static function reorderNodeLinks(graph:SankeyGraph, index:Int):Void {
        for (i in 0...graph.nodes[index].targetLinks.length) {
            final link = graph.nodes[index].targetLinks[i];
            sortSourceLinks(graph, graph.links[link].source);
        }
        for (i in 0...graph.nodes[index].sourceLinks.length) {
            final link = graph.nodes[index].sourceLinks[i];
            sortTargetLinks(graph, graph.links[link].target);
        }
    }

    /** A stable sort of the column by `y0` (Rust `sort_by`). */
    static function sortColumn(graph:SankeyGraph, column:Array<Int>):Void {
        haxe.ds.ArraySort.sort(column, (a, b) -> compareF32(graph.nodes[a].y0, graph.nodes[b].y0));
    }

    /** `partial_cmp`, NaN comparing equal. */
    static inline function compareF32(a:Float, b:Float):Int {
        return a < b ? -1 : (a > b ? 1 : 0);
    }

    /** Push overlapping nodes down (d3's resolveCollisionsTopToBottom). */
    static function pushDown(graph:SankeyGraph, column:Array<Int>, y:Float, alpha:Float, py:Float):Void {
        for (index in column) {
            final node = graph.nodes[index];
            final dy = f(f(y - node.y0) * alpha);
            if (dy > EPS_6) {
                node.y0 = f(node.y0 + dy);
                node.y1 = f(node.y1 + dy);
            }
            y = f(node.y1 + py);
        }
    }

    /** Push overlapping nodes up (d3's resolveCollisionsBottomToTop). */
    static function pushUp(graph:SankeyGraph, column:Array<Int>, y:Float, alpha:Float, py:Float):Void {
        var i = column.length - 1;
        while (i >= 0) {
            final node = graph.nodes[column[i]];
            final dy = f(f(node.y1 - y) * alpha);
            if (dy > EPS_6) {
                node.y0 = f(node.y0 - dy);
                node.y1 = f(node.y1 - dy);
            }
            y = f(node.y0 - py);
            i--;
        }
    }

    /**
     * The ideal `y0` for `target` so that its ribbon from `source` lines up
     * with the slot the ribbon occupies in the source's outgoing stack
     * (d3's targetTop).
     */
    static function targetTop(graph:SankeyGraph, source:Int, target:Int, py:Float):Float {
        final sourceNode = graph.nodes[source];
        final count = sourceNode.sourceLinks.length > 0 ? sourceNode.sourceLinks.length - 1 : 0;
        var y = f(sourceNode.y0 - f(f(count * py) / 2.));
        for (linkIndex in sourceNode.sourceLinks) {
            final link = graph.links[linkIndex];
            if (link.target == target) {
                break;
            }
            y = f(y + f(link.width + py));
        }
        for (linkIndex in graph.nodes[target].targetLinks) {
            final link = graph.links[linkIndex];
            if (link.source == source) {
                break;
            }
            y = f(y - link.width);
        }
        return y;
    }

    /**
     * The ideal `y0` for `source` so that its ribbon to `target` lines up
     * with the slot the ribbon occupies in the target's incoming stack
     * (d3's sourceTop).
     */
    static function sourceTop(graph:SankeyGraph, source:Int, target:Int, py:Float):Float {
        final targetNode = graph.nodes[target];
        final count = targetNode.targetLinks.length > 0 ? targetNode.targetLinks.length - 1 : 0;
        var y = f(targetNode.y0 - f(f(count * py) / 2.));
        for (linkIndex in targetNode.targetLinks) {
            final link = graph.links[linkIndex];
            if (link.source == source) {
                break;
            }
            y = f(y + f(link.width + py));
        }
        for (linkIndex in graph.nodes[source].sourceLinks) {
            final link = graph.links[linkIndex];
            if (link.target == target) {
                break;
            }
            y = f(y - link.width);
        }
        return y;
    }

    /**
     * Assign each link's `y0`/`y1` (ribbon centers) and per-end widths by
     * stacking the sorted link lists within each node. Each side shares the
     * node height in proportion to the link values.
     */
    static function computeLinkBreadths(graph:SankeyGraph):Void {
        for (node in graph.nodes) {
            final nodeY0 = node.y0;
            final nodeHeight = f(node.y1 - node.y0);

            var outgoing = 0.;
            for (link in node.sourceLinks) {
                outgoing += graph.links[link].value;
            }
            var y0 = nodeY0;
            for (linkIndex in node.sourceLinks) {
                final link = graph.links[linkIndex];
                final width = outgoing > 0. ? f(f(link.value / outgoing) * nodeHeight) : 0.;
                link.sourceWidth = width;
                link.y0 = f(y0 + f(width / 2.));
                y0 = f(y0 + width);
            }

            var incoming = 0.;
            for (link in node.targetLinks) {
                incoming += graph.links[link].value;
            }
            var y1 = nodeY0;
            for (linkIndex in node.targetLinks) {
                final link = graph.links[linkIndex];
                final width = incoming > 0. ? f(f(link.value / incoming) * nodeHeight) : 0.;
                link.targetWidth = width;
                link.y1 = f(y1 + f(width / 2.));
                y1 = f(y1 + width);
            }
        }
    }

    /**
     * Build the filled ribbon path for a link, the equivalent of
     * d3-sankey's `sankeyLinkHorizontal()`: a horizontal cubic bezier with
     * control points at the horizontal midpoint, thickened to the per-end
     * link widths (clamped to `minWidth` so tiny flows stay visible).
     */
    public static function sankeyLinkPath(source:SankeyNodeLayout, target:SankeyNodeLayout, link:SankeyLinkLayout, minWidth:Float, origin:Point):Null<Path> {
        final sourceHalf = f(Math.max(link.sourceWidth, minWidth) / 2.);
        final targetHalf = f(Math.max(link.targetWidth, minWidth) / 2.);
        final sx = source.x1;
        final tx = target.x0;
        final mx = f(f(sx + tx) / 2.);

        final builder = PathBuilder.fill();
        builder.moveTo(Plot.originPoint(sx, f(link.y0 - sourceHalf), origin));
        builder.cubicBezierTo(
            Plot.originPoint(tx, f(link.y1 - targetHalf), origin),
            Plot.originPoint(mx, f(link.y0 - sourceHalf), origin),
            Plot.originPoint(mx, f(link.y1 - targetHalf), origin)
        );
        builder.lineTo(Plot.originPoint(tx, f(link.y1 + targetHalf), origin));
        builder.cubicBezierTo(
            Plot.originPoint(sx, f(link.y0 + sourceHalf), origin),
            Plot.originPoint(mx, f(link.y1 + targetHalf), origin),
            Plot.originPoint(mx, f(link.y0 + sourceHalf), origin)
        );
        builder.close();
        return Plot.buildPath(builder);
    }

    /** `f32::min`: the other value when one is NaN. */
    static inline function minF32(a:Float, b:Float):Float {
        return Math.isNaN(a) ? b : (Math.isNaN(b) ? a : Math.min(a, b));
    }

    /**
     * `f32::powi`, as compiler-rt's `__powisf2` computes it (repeated
     * squaring in `f32`).
     */
    @:allow(tests)
    static function powi(a:Float, b:Int):Float {
        final recip = b < 0;
        var r = 1.;
        var base = a;
        var e = b;
        while (true) {
            if ((e & 1) != 0) {
                r = f(r * base);
            }
            e = Std.int(e / 2);
            if (e == 0) {
                break;
            }
            base = f(base * base);
        }
        return recip ? f(1. / r) : r;
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}
