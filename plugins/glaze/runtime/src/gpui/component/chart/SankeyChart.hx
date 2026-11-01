// Ported from gpui-kit 0.8.1: crates/component/src/chart/sankey_chart.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.chart;

import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.Corners;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.IntoHsla;
import gpui.Pixels;
import gpui.Point;
import gpui.SpringMath;
import gpui.TextAlign;
import gpui.Window;
import gpui.base.plot.PathCache.PathCaches;
import gpui.base.plot.PathCache.ShapeKey;
import gpui.base.plot.Plot;
import gpui.base.plot.PlotAppear;
import gpui.base.plot.PlotHover;
import gpui.base.plot.PlotLabel;
import gpui.base.plot.PlotLabel.Text;
import gpui.base.plot.TooltipState;
import gpui.base.plot.shape.Sankey;
import gpui.component.chart.Chart.ChartAppear;
import gpui.component.plot.Tooltip;
import gpui.component.theme.Theme;

import gpui.Prelude.fill;
import gpui.Prelude.linearColorStop;
import gpui.Prelude.linearGradient;

/**
 * The placed layout of a frame: the graph on the final extent, the label
 * lines of every node and the label margins.
 */
private class SankeyFrame {

    public final graph:SankeyGraph;

    public final layerCount:Int;

    public final nodeLabels:Array<Array<SankeyLabel>>;

    public final left:Float;

    public final right:Float;

    public function new(graph:SankeyGraph, layerCount:Int, nodeLabels:Array<Array<SankeyLabel>>, left:Float, right:Float) {
        this.graph = graph;
        this.layerCount = layerCount;
        this.nodeLabels = nodeLabels;
        this.left = left;
        this.right = right;
    }

}

/**
 * The frame of the last placement and its key, kept in element state.
 */
private class SankeyFrameCache {

    public var key:Null<String> = null;

    public var frame:Null<SankeyFrame> = null;

    public function new() {}

}

private class SankeyHover {

    public final node:Int;

    public final focus:Float;

    public function new(node:Int, focus:Float) {
        this.node = node;
        this.focus = focus;
    }

}

/**
 * One line of a node's label: its text, and optionally its color and font
 * size.
 */
class SankeyLabel {

    @:allow(gpui.component.chart) @:allow(tests) final text:String;

    @:allow(gpui.component.chart) @:allow(tests) var colorValue:Null<Hsla> = null;

    @:allow(gpui.component.chart) @:allow(tests) var fontSizeValue:Null<Float> = null;

    public function new(text:String) {
        this.text = text;
    }

    public function color(color:IntoHsla):SankeyLabel {
        colorValue = color;
        return this;
    }

    public function fontSize(fontSize:Float):SankeyLabel {
        fontSizeValue = SpringMath.f32(fontSize);
        return this;
    }

    @:allow(gpui.component.chart)
    @:allow(tests)
    function lineHeight():Float {
        return SpringMath.f32((fontSizeValue != null ? fontSizeValue : PlotLabel.TEXT_SIZE) + PlotLabel.TEXT_GAP);
    }

    @:allow(gpui.component.chart)
    @:allow(tests)
    static function blockHeight(lines:Array<SankeyLabel>):Float {
        var height = 0.;
        for (line in lines) {
            height = SpringMath.f32(height + line.lineHeight());
        }
        return height;
    }

}

/**
 * A sankey chart: nodes in columns joined by ribbons as wide as their flows
 * (Rust `SankeyChart<T>`).
 */
class SankeyChart<T> extends Plot {

    static inline final DEFAULT_NODE_WIDTH:Float = 10.;

    static inline final DEFAULT_NODE_PADDING:Float = 16.;

    static final DEFAULT_LINK_OPACITY:Float = SpringMath.f32(0.3);

    static inline final DEFAULT_MIN_LINK_WIDTH:Float = 1.;

    static inline final DEFAULT_LABEL_GAP:Float = 6.;

    static final MAX_LABEL_WIDTH_RATIO:Float = SpringMath.f32(0.2);

    static final MAX_LABEL_MARGIN_RATIO:Float = SpringMath.f32(0.6);

    static final HOVER_DIM:Float = SpringMath.f32(0.7);

    @:allow(tests) final nodes:Array<T>;

    @:allow(tests) final links:Array<SankeyLink>;

    @:allow(tests) var nodeWidthValue:Float = DEFAULT_NODE_WIDTH;

    @:allow(tests) var nodePaddingValue:Float = DEFAULT_NODE_PADDING;

    @:allow(tests) var align:SankeyAlign = Justify;

    @:allow(tests) var iterationsValue:Int = 6;

    @:allow(tests) var valueScaleValue:SankeyValueScale = Linear;

    @:allow(tests) var nodeCornerRadiusValue:Null<Float> = null;

    @:allow(tests) var nodeColorFn:Null<T->Hsla> = null;

    @:allow(tests) var nodeLabelFn:Null<T->String> = null;

    @:allow(tests) var valueLabelFn:Null<(T, Float) -> String> = null;

    @:allow(tests) var labelsFn:Null<(T, Float) -> Array<SankeyLabel>> = null;

    @:allow(tests) var linkOpacityValue:Float = DEFAULT_LINK_OPACITY;

    @:allow(tests) var minLinkWidthValue:Float = DEFAULT_MIN_LINK_WIDTH;

    @:allow(tests) var labelGapValue:Float = DEFAULT_LABEL_GAP;

    @:allow(tests) var tooltipNameFn:Null<T->String> = null;

    @:allow(tests) var tooltipValueFn:Null<(T, Float) -> String> = null;

    var idValue:ElementId;

    var interactiveValue:Bool = true;

    final appearValue:ChartAppear = new ChartAppear();

    var frame:Null<SankeyFrame> = null;

    var hover:Null<SankeyHover> = null;

    public function new(nodes:Iterable<T>, links:Iterable<SankeyLink>, ?pos:haxe.PosInfos) {
        super();
        this.nodes = [for (n in nodes) n];
        this.links = [for (l in links) l];
        idValue = Chart.callerId(pos);
    }

    /** Name this chart's `ElementId`, replacing the default taken from the construction site. */
    public function id(id:ElementIdArg):SankeyChart<T> {
        idValue = id;
        return this;
    }

    /** Turn this chart's interactive layer on or off. On by default. */
    public function interactive(interactive:Bool):SankeyChart<T> {
        interactiveValue = interactive;
        return this;
    }

    /** Draw the data in the first time this chart is painted. On by default. */
    public function appear(appear:Bool):SankeyChart<T> {
        appearValue.setEnabled(appear);
        return this;
    }

    /** Draw the data in again whenever `key` changes. */
    public function appearKey(key:String):SankeyChart<T> {
        appearValue.setKey(key);
        return this;
    }

    public function nodeWidth(nodeWidth:Float):SankeyChart<T> {
        nodeWidthValue = SpringMath.f32(nodeWidth);
        return this;
    }

    public function nodePadding(nodePadding:Float):SankeyChart<T> {
        nodePaddingValue = SpringMath.f32(nodePadding);
        return this;
    }

    public function nodeAlign(align:SankeyAlign):SankeyChart<T> {
        this.align = align;
        return this;
    }

    public function iterations(iterations:Int):SankeyChart<T> {
        iterationsValue = iterations;
        return this;
    }

    public function valueScale(valueScale:SankeyValueScale):SankeyChart<T> {
        valueScaleValue = valueScale;
        return this;
    }

    public function nodeCornerRadius(radius:Pixels):SankeyChart<T> {
        nodeCornerRadiusValue = SpringMath.f32(radius);
        return this;
    }

    public function nodeColor(color:T->IntoHsla):SankeyChart<T> {
        nodeColorFn = t -> (color(t) : Hsla);
        return this;
    }

    public function nodeLabel(label:T->String):SankeyChart<T> {
        nodeLabelFn = label;
        return this;
    }

    public function valueLabel(label:(T, Float) -> String):SankeyChart<T> {
        valueLabelFn = label;
        return this;
    }

    /** Set the label lines of each node from the datum and its raw throughput. */
    public function labels(labels:(T, Float) -> Array<SankeyLabel>):SankeyChart<T> {
        labelsFn = labels;
        return this;
    }

    public function tooltipName(name:T->String):SankeyChart<T> {
        tooltipNameFn = name;
        return this;
    }

    public function tooltipValue(value:(T, Float) -> String):SankeyChart<T> {
        tooltipValueFn = value;
        return this;
    }

    public function linkOpacity(opacity:Float):SankeyChart<T> {
        linkOpacityValue = SpringMath.f32(opacity);
        return this;
    }

    public function minLinkWidth(width:Float):SankeyChart<T> {
        minLinkWidthValue = SpringMath.f32(width);
        return this;
    }

    public function labelGap(gap:Float):SankeyChart<T> {
        labelGapValue = SpringMath.f32(gap);
        return this;
    }

    @:allow(tests)
    function sankey():Sankey {
        return new Sankey()
            .nodeWidth(nodeWidthValue)
            .nodePadding(nodePaddingValue)
            .nodeAlign(align)
            .iterations(iterationsValue)
            .valueScale(valueScaleValue);
    }

    @:allow(tests)
    function rawThroughput():Array<Float> {
        final incoming = [for (_ in nodes) 0.];
        final outgoing = [for (_ in nodes) 0.];
        for (link in links) {
            if (link.source < outgoing.length && link.target < incoming.length) {
                outgoing[link.source] += link.value;
                incoming[link.target] += link.value;
            }
        }
        return [for (i in 0...nodes.length) Math.max(incoming[i], outgoing[i])];
    }

    function nodeLabels(cx:App):Array<Array<SankeyLabel>> {
        final rawValue = rawThroughput();
        final theme = Theme.global(cx);
        return [
            for (i in 0...nodes.length) {
                final datum = nodes[i];
                final value = rawValue[i];
                if (labelsFn != null) {
                    labelsFn(datum, value);
                }
                else {
                    final lines:Array<SankeyLabel> = [];
                    if (valueLabelFn != null) {
                        lines.push(new SankeyLabel(valueLabelFn(datum, value)));
                    }
                    if (nodeLabelFn != null) {
                        lines.push(new SankeyLabel(nodeLabelFn(datum)).color(theme.mutedForeground));
                    }
                    lines;
                }
            }
        ];
    }

    function frameKey(bounds:Bounds, nodeLabels:Array<Array<SankeyLabel>>):String {
        final buf = new StringBuf();
        final bits = ShapeKey.bits;
        buf.add(bits(bounds.size.width) + ',' + bits(bounds.size.height) + ',' + nodes.length);
        for (link in links) {
            buf.add(';' + link.source + ',' + link.target + ',' + Std.string(link.value));
        }
        buf.add('|' + bits(nodeWidthValue) + ',' + bits(nodePaddingValue) + ',' + align.toInt() + ',' + iterationsValue + ',' + valueScaleValue.toInt() + ',' + bits(labelGapValue));
        for (lines in nodeLabels) {
            buf.add('|' + lines.length);
            for (line in lines) {
                buf.add(';' + line.text.length + ':' + line.text + ',' + bits(line.fontSizeValue));
                final c = line.colorValue;
                buf.add(c == null ? ',none' : ',' + bits(c.h) + ',' + bits(c.s) + ',' + bits(c.l) + ',' + bits(c.a));
            }
        }
        return buf.toString();
    }

    function place(bounds:Bounds, nodeLabels:Array<Array<SankeyLabel>>, window:Window):Null<SankeyFrame> {
        final width = bounds.size.width;
        final height = bounds.size.height;

        // First pass: only the topology (each node's `layer`) is needed to
        // measure the label margins.
        var topology:SankeyGraph;
        try {
            topology = sankey().topology(nodes.length, links);
        }
        catch (_:SankeyError) {
            return null;
        }
        final layerCount = topology.layerCount();
        var hasLabels = false;
        for (lines in nodeLabels) {
            if (lines.length > 0) hasLabels = true;
        }

        // Reserve margins so the labels beside the first/last columns and
        // above the middle columns are not clipped.
        var left = 0.;
        var right = 0.;
        if (hasLabels) {
            for (node in topology.nodes) {
                if (node.layer != 0 && node.layer + 1 != layerCount) {
                    continue;
                }
                var labelWidth = 0.;
                for (line in nodeLabels[node.index]) {
                    labelWidth = Math.max(labelWidth, PlotLabel.measureTextWidth(line.text, line.fontSizeValue != null ? line.fontSizeValue : PlotLabel.TEXT_SIZE, window));
                }
                if (node.layer == 0) {
                    left = Math.max(left, f(labelWidth + labelGapValue));
                }
                else {
                    right = Math.max(right, f(labelWidth + labelGapValue));
                }
            }

            // Cap each side independently so one long label is truncated to
            // a modest column rather than eating into the flow area.
            final sideCap = f(width * MAX_LABEL_WIDTH_RATIO);
            left = Math.min(left, sideCap);
            right = Math.min(right, sideCap);
        }
        // Above-node labels are only emitted for middle columns, so reserve
        // the top band for the tallest such label block.
        var top = 0.;
        if (hasLabels && layerCount > 2) {
            for (node in topology.nodes) {
                if (node.layer == 0 || node.layer + 1 == layerCount) {
                    continue;
                }
                final block = SankeyLabel.blockHeight(nodeLabels[node.index]);
                if (block > 0.) {
                    top = Math.max(top, f(block + PlotLabel.TEXT_GAP));
                }
            }
        }
        var bottom = hasLabels ? PlotLabel.TEXT_GAP : 0.;
        final maxVertical = f(height * MAX_LABEL_MARGIN_RATIO);
        if (f(top + bottom) > maxVertical) {
            final k = f(maxVertical / f(top + bottom));
            top = f(top * k);
            bottom = f(bottom * k);
        }

        // Second pass: complete the placement on the final extent, reusing
        // the first pass's topology.
        final graph = sankey()
            .extent(left, top, Math.max(f(width - right), f(left + 1.)), Math.max(f(height - bottom), f(top + 1.)))
            .layoutFrom(topology);

        return new SankeyFrame(graph, layerCount, nodeLabels, left, right);
    }

    static function isAttached(link:SankeyLinkLayout, node:Int):Bool {
        return link.source == node || link.target == node;
    }

    override public function prepaint(bounds:Bounds, window:Window, cx:App):Array<AnyElement> {
        frame = null;
        final width = bounds.size.width;
        final height = bounds.size.height;
        if (nodes.length == 0 || links.length == 0 || width <= 0. || height <= 0.) {
            return [];
        }

        final nodeLabels = nodeLabels(cx);

        final key = frameKey(bounds, nodeLabels);
        final state:gpui.Window.StateModel<SankeyFrameCache> = window.useKeyedState('sankey-frame', cx, _ -> new SankeyFrameCache());
        final cache = state.value;
        if (cache.key == key) {
            frame = cache.frame;
        }
        else {
            frame = place(bounds, nodeLabels, window);
            cache.key = key;
            cache.frame = frame;
        }

        return [];
    }

    public function paint(bounds:Bounds, window:Window, cx:App):Void {
        final frame = this.frame;
        if (frame == null) {
            return;
        }
        final graph = frame.graph;
        final layerCount = frame.layerCount;
        final nodeLabels = frame.nodeLabels;
        final left = frame.left;
        final right = frame.right;
        final width = bounds.size.width;
        final height = bounds.size.height;
        final theme = Theme.global(cx);

        final palette = [theme.chart1, theme.chart2, theme.chart3, theme.chart4, theme.chart5];
        final colors = [for (index in 0...nodes.length) nodeColorFn != null ? nodeColorFn(nodes[index]) : palette[index % palette.length]];

        // Links first, under the nodes. The links of the hovered node keep
        // their opacity while the rest fade behind them. Each tessellated
        // ribbon is kept, slotted by the link's index in the graph. Links
        // and nodes draw in from the left under a mask as the chart appears;
        // the labels fade in.
        final minWidth = minLinkWidthValue;
        final caches = PathCaches.forPaint('links', window, cx);
        final appear = appearValue.get().progress();
        final hover = this.hover;
        window.withContentMask(Chart.revealMask(bounds, 0., appear), window -> {
            for (ix in 0...graph.links.length) {
                final link = graph.links[ix];
                if (link.value <= 0.) {
                    continue;
                }
                final source = graph.nodes[link.source];
                final target = graph.nodes[link.target];
                final key = new ShapeKey('')
                    .f32(source.x1)
                    .f32(target.x0)
                    .f32(link.y0)
                    .f32(link.y1)
                    .f32(Math.max(link.sourceWidth, minWidth))
                    .f32(Math.max(link.targetWidth, minWidth))
                    .finish();
                final path = caches.slot(ix).get(key, bounds.origin, () -> Sankey.sankeyLinkPath(source, target, link, minWidth, new Point(0, 0)));
                if (path == null) {
                    continue;
                }
                final opacity = hover != null && !isAttached(link, hover.node)
                    ? f(linkOpacityValue * f(1. - f(HOVER_DIM * hover.focus)))
                    : linkOpacityValue;
                window.paintPath(path, linearGradient(
                    90.,
                    linearColorStop(colors[link.source].opacity(opacity), 0.),
                    linearColorStop(colors[link.target].opacity(opacity), 1.)
                ));
            }

            final cornerRadii = Corners.all(nodeCornerRadiusValue != null ? nodeCornerRadiusValue : 0.);
            for (node in graph.nodes) {
                final nodeBounds = Chart.fromCorners(
                    Plot.originPoint(node.x0, node.y0, bounds.origin),
                    // Keep tiny nodes visible with a minimum 1px height.
                    Plot.originPoint(node.x1, Math.max(node.y1, f(node.y0 + 1.)), bounds.origin)
                );
                final quad = fill(nodeBounds, colors[node.index]);
                quad.cornerRadii = cornerRadii;
                window.paintQuad(quad);
            }
            return true;
        });

        final texts:Array<Text> = [];
        for (node in graph.nodes) {
            final lines = nodeLabels[node.index];
            if (lines.length == 0) {
                continue;
            }

            final isFirst = node.layer == 0;
            final isLast = node.layer + 1 == layerCount;
            // `x`/`align` place the label beside (first/last) or centered
            // above (middle) the node, and `maxWidth` bounds it so a long
            // label is truncated with an ellipsis.
            var x:Float;
            var align:TextAlign;
            var maxWidth:Float;
            if (isFirst) {
                x = f(node.x0 - labelGapValue);
                align = Right;
                maxWidth = f(left - labelGapValue);
            }
            else if (isLast) {
                x = f(node.x1 + labelGapValue);
                align = Left;
                maxWidth = f(right - labelGapValue);
            }
            else {
                final center = f(f(node.x0 + node.x1) / 2.);
                x = center;
                align = Center;
                maxWidth = f(2. * Math.min(center, f(width - center)));
            }

            final block = SankeyLabel.blockHeight(lines);
            var y = isFirst || isLast
                // Block vertically centered beside the node, clamped into the plot area.
                ? Math.max(Math.min(f(f(f(node.y0 + node.y1) / 2.) - f(block / 2.)), f(height - block)), 0.)
                // Block above the node.
                : f(f(node.y0 - block) - PlotLabel.TEXT_GAP);

            for (line in lines) {
                final fontSize = line.fontSizeValue != null ? line.fontSizeValue : PlotLabel.TEXT_SIZE;
                final text = PlotLabel.truncateTextToWidth(line.text, fontSize, maxWidth, window);
                texts.push(new Text(text, new Point(x, y), (line.colorValue != null ? line.colorValue : theme.foreground).opacity(appear))
                    .withFontSize(fontSize)
                    .withAlign(align));
                y = f(y + line.lineHeight());
            }
        }
        new PlotLabel(texts).paint(bounds, window, cx);
    }

    override public function plotId():Null<ElementId> {
        return idValue;
    }

    override public function isInteractive():Bool {
        return interactiveValue;
    }

    override public function updateAppear(appear:PlotAppear, window:Window, cx:App):Void {
        appearValue.update(appear);
    }

    override public function appearGeneration():Null<String> {
        return appearValue.generation();
    }

    override public function tooltipState(position:Point, bounds:Bounds, cx:App):Null<TooltipState> {
        final frame = this.frame;
        if (frame == null) {
            return null;
        }
        final x = position.x;
        final y = position.y;
        for (node in frame.graph.nodes) {
            if (x >= node.x0 && x <= node.x1 && y >= node.y0 && y <= Math.max(node.y1, f(node.y0 + 1.))) {
                return new TooltipState(node.index, position, []);
            }
        }
        return null;
    }

    override public function updateHover(hover:Null<PlotHover>, window:Window, cx:App):Void {
        this.hover = hover != null ? new SankeyHover(hover.state().index, hover.progress()) : null;
    }

    override public function tooltip(state:TooltipState, cursor:Point, bounds:Bounds, window:Window, cx:App):Null<AnyElement> {
        if (state.index >= nodes.length) {
            return null;
        }
        final datum = nodes[state.index];
        final throughput = rawThroughput();
        if (state.index >= throughput.length) {
            return null;
        }
        final value = throughput[state.index];
        final theme = Theme.global(cx);
        final palette = [theme.chart1, theme.chart2, theme.chart3, theme.chart4, theme.chart5];
        final color = nodeColorFn != null ? nodeColorFn(datum) : palette[state.index % palette.length];
        final valueText = tooltipValueFn != null ? tooltipValueFn(datum, value) : (valueLabelFn != null ? valueLabelFn(datum, value) : ChartFormat.display64(value));

        // Follow the cursor; the node's links mark it.
        var tooltip = new Tooltip(cursor, bounds.size).gap(8.);
        if (nodeLabelFn != null) {
            tooltip = tooltip.title(nodeLabelFn(datum));
        }
        tooltip = tooltip.row(color, tooltipNameFn != null ? tooltipNameFn(datum) : '', valueText);
        return (tooltip : IntoElement).intoAnyElement();
    }

    static inline function f(v:Float):Float {
        return SpringMath.f32(v);
    }

}
