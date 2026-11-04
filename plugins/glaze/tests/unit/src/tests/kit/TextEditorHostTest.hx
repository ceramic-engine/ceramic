// Ported from gpui-kit 0.8.1: crates/base/src/text/editor_host.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.Context;
import gpui.Element;
import gpui.Entity;
import gpui.GlobalElementId;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.LayoutId;
import gpui.Model;
import gpui.Point;
import gpui.Range;
import gpui.Render;
import gpui.TextLayout;
import gpui.Window;
import gpui.base.Base;
import gpui.base.text.BlockNode;
import gpui.base.text.CodeBlock;
import gpui.base.text.ColumnumnAlign;
import gpui.base.text.EditorHost;
import gpui.base.text.EditorSeam;
import gpui.base.text.ImageNode;
import gpui.base.text.InlineElement;
import gpui.base.text.InlineNode;
import gpui.base.text.MarkdownExtensions;
import gpui.base.text.MarkdownNode;
import gpui.base.text.NodeContext;
import gpui.base.text.Paragraph;
import gpui.base.text.RangedColor;
import gpui.base.text.RangedMark;
import gpui.base.text.Table;
import gpui.base.text.TextMark;
import gpui.base.text.format.MarkdownFormat;
import gpui.util.Utf8;
import testing.VisualTestContext;

import gpui.Prelude.*;

using gpui.base.text.EditorHost;
using unicode_segmentation.UnicodeSegmentation;

/**
 * Stands in for an editor's root element: prepaints its child inside a
 * `collectLeafGeometry` scope and keeps what the leaves reported.
 */
private class Probe extends Element {
    final child:AnyElement;
    final decorations:Map<Int, Array<RangedColor>>;
    final out:{value:Map<Int, LeafGeometry>};
    /** Replaces `collectLeafGeometry` with a custom sink. */
    final sink:Null<EditorSink>;

    public function new(child:AnyElement, decorations:Map<Int, Array<RangedColor>>, out:{value:Map<Int, LeafGeometry>}, sink:Null<EditorSink>) {
        this.child = child;
        this.decorations = decorations;
        this.out = out;
        this.sink = sink;
    }

    public function requestLayout(_:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(_:Null<GlobalElementId>, _:Bounds, window:Window, cx:App):Void {
        if (sink != null) {
            EditorSeam.withSink(sink, () -> {
                child.prepaint(window, cx);
                return true;
            });
            return;
        }
        final collected = EditorHost.collectLeafGeometry(decorations, () -> {
            child.prepaint(window, cx);
            return true;
        });
        out.value = collected.leaves;
    }

    public function paint(_:Null<GlobalElementId>, _:Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
    }
}

private class Host extends Model implements Render {
    public final blocks:Array<BlockNode>;
    public final extensions:MarkdownExtensions;
    public final decorations:Map<Int, Array<RangedColor>>;
    public final out:{value:Map<Int, LeafGeometry>};
    public var width:Float;
    public final sink:Null<EditorSink>;

    public function new(blocks, extensions, decorations, out, width, sink) {
        super();
        this.blocks = blocks;
        this.extensions = extensions;
        this.decorations = decorations;
        this.out = out;
        this.width = width;
        this.sink = sink;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final rcx = RenderContext.fromApp(cx.app)
            .withMarkdownExtensions(extensions)
            .withBodyFontSize(px(16.));
        final children:Array<IntoElement> = [];
        for (ix in 0...blocks.length) {
            final flow = FlowPosition.at(blocks, ix, ix + 1 == blocks.length);
            children.push(blocks[ix].render(ix, flow, rcx, window, cx.app));
        }
        return new Probe(div().w(px(width)).children(children).intoAnyElement(), decorations, out, sink);
    }
}

/** Records which leaves ask for backgrounds, to prove decorations are requested for keyed leaves only. */
private class Recorder implements EditorSink {
    public final asked:Array<Int> = [];

    public function new() {}
    public function report(_:Int, _:TextLayout):Void {}
    public function beginPieces(_:Int):Void {}
    public function reportTextPiece(_:Int, _:Int, _:TextLayout):Void {}
    public function reportBoxPiece(_:Int, _:Range, _:Bounds):Void {}
    public function reportEmptyPiece(_:Int, _:Int, _:Bounds):Void {}
    public function backgrounds(key:Int):Array<RangedColor> {
        asked.push(key);
        return [new RangedColor(new Range(0, 1), rgb(0xff0000).toHsla())];
    }
}

/**
 * Tests of the editor host API (Rust `text/editor_host.rs`).
 */
@:access(gpui.base.text)
class TextEditorHostTest extends KitTestCase {

    final contexts:Array<VisualTestContext> = [];

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        super.teardown();
    }

    static function initBase(cx:App):Void {
        Base.init(cx);
        gpui.base.theme.Theme.globalMut(cx).tokens.typography.mono = 'JetBrains Mono';
    }

    function addHost(host:Host):{view:Entity<Host>, cx:VisualTestContext} {
        app.update(cx -> initBase(cx));
        final result = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> host);
        contexts.push(result.cx);
        return result;
    }

    function draw(blocks:Array<BlockNode>, decorations:Map<Int, Array<RangedColor>>, extensions:MarkdownExtensions, width:Float):Map<Int, LeafGeometry> {
        return drawAndInspect(blocks, decorations, extensions, width, _ -> null).geometries;
    }

    function drawAndInspect<R>(blocks:Array<BlockNode>, decorations:Map<Int, Array<RangedColor>>, extensions:MarkdownExtensions, width:Float, inspect:(Window) -> R):{geometries:Map<Int, LeafGeometry>, inspected:R} {
        final out = {value: new Map<Int, LeafGeometry>()};
        final result = addHost(new Host(blocks, extensions, decorations, out, width, null));
        settle(result.cx);
        final inspected = result.cx.update((window, _) -> inspect(window));
        return {geometries: out.value, inspected: inspected};
    }

    static function settle(cx:VisualTestContext):Void {
        cx.runUntilParked();
        cx.update((window, _) -> {
            window.draw();
            return true;
        });
        cx.runUntilParked();
    }

    static function plain(text:String):Paragraph {
        final paragraph = new Paragraph();
        paragraph.push(new InlineNode(text));
        return paragraph;
    }

    static function atomPlugin():MarkdownExtensions {
        return new MarkdownExtensions().plugin(new TextTestInlinePlugin("atom").renderWith((_, _, _, _) -> {
            return new InlineElement(div().w(px(24.)).h(px(16.))).withBaseline(px(12.));
        }));
    }

    static function atom():InlineNode {
        return InlineNode.ofCustom(new MarkdownNode("atom", null).text("\u{FFFC}"));
    }

    static function keys(map:Map<Int, LeafGeometry>):Array<Int> {
        final keys = [for (key in map.keys()) key];
        keys.sort((a, b) -> a - b);
        return keys;
    }

    static function svgImage():ImageNode {
        final image = new ImageNode("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='20' height='20'/>");
        image.width = gpui.DefiniteLength.Absolute(gpui.AbsoluteLength.Pixels(20.));
        image.height = gpui.DefiniteLength.Absolute(gpui.AbsoluteLength.Pixels(20.));
        return image;
    }

    function testKeyedLeavesReportGeometryAndUnkeyedLeavesDoNot() {
        final blocks:Array<BlockNode> = [
            Heading(1, plain("Title").withLeafKey(1), null),
            Paragraph(plain("first").withLeafKey(2)),
            Paragraph(plain("not an editor leaf")),
            CodeBlock(new CodeBlock("let x = 1;", "rust", null).withLeafKey(3)),
            Table(gpui.base.text.Table.of([
                [plain("a").withLeafKey(4), plain("b").withLeafKey(5)],
                [plain("c").withLeafKey(6), plain("d").withLeafKey(7)],
            ], [ColumnumnAlign.None, ColumnumnAlign.Right])),
            List([ListItem([Paragraph(plain("item").withLeafKey(8))], false, null, null)], false, null, null),
        ];
        final geometries = draw(blocks, new Map(), new MarkdownExtensions(), 300.);
        assertEquals('1,2,3,4,5,6,7,8', keys(geometries).join(','));
        for (key in [1, 2, 3, 8]) {
            assertTrue(geometries.get(key).bounds().size.height > 0., 'leaf $key');
        }
        assertEquals(5, geometries.get(1).len());
        assertEquals(10, geometries.get(3).len());
        // Document order is top to bottom.
        function top(key:Int):Float return geometries.get(key).bounds().top();
        assertTrue(top(1) < top(2) && top(2) < top(3) && top(3) < top(4) && top(7) < top(8));
        // Cells of one row share a line; the second column sits to the right.
        assertEquals(top(4), top(5));
        assertTrue(geometries.get(5).bounds().left() > geometries.get(4).bounds().right() - 1.);
    }

    function testWrappedLeafMapsIndicesAndPositions() {
        final text = "the quick brown fox jumps over the lazy dog and keeps running far away";
        final geometries = draw([Paragraph(plain(text).withLeafKey(1))], new Map(), new MarkdownExtensions(), 120.);
        final leaf = geometries.get(1);
        assertEquals(text.length, leaf.len());
        assertFalse(leaf.isEmpty());
        final line = leaf.lineHeight();
        assertTrue(line > 0. && leaf.caretHeight() <= line);
        var lastY = -1.;
        final lines = new Map<Int, Bool>();
        for (index in 0...text.length + 1) {
            final caret = leaf.positionForIndex(index);
            assertTrue(caret.y >= lastY, 'carets never move up');
            lastY = caret.y;
            lines.set(Std.int(caret.y * 100.), true);
            // Hit-testing at a caret lands on that caret (at a soft wrap the
            // end of a line and the start of the next share a caret index).
            final hit = leaf.indexForPosition(new Point(caret.x, caret.y + line / 2.));
            assertTrue(leaf.positionForIndex(hit).equals(caret), 'index $index hit $hit');
        }
        assertTrue([for (k in lines.keys()) k].length >= 3, 'the text wraps onto several lines');
        // Far outside the leaf clamps to its ends.
        assertEquals(0, leaf.indexForPosition(new Point(-500., -500.)));
        assertEquals(text.length, leaf.indexForPosition(new Point(5000., 5000.)));
    }

    function testMixedTextAndAtomsReportBoxes() {
        final paragraph = new Paragraph();
        paragraph.push(new InlineNode("ab"));
        paragraph.push(atom());
        paragraph.push(new InlineNode("cd"));
        final atomLen = 3;
        final geometries = draw([Paragraph(paragraph.withLeafKey(1))], new Map(), atomPlugin(), 300.);
        final leaf = geometries.get(1);
        assertEquals(2 + atomLen + 2, leaf.len());
        // The box is hit-testable, and only the box.
        final before = leaf.positionForIndex(2);
        final after = leaf.positionForIndex(2 + atomLen);
        assertTrue(after.x > before.x, 'the caret moves across the atom');
        final inside = new Point((before.x + after.x) / 2., before.y + leaf.lineHeight() / 2.);
        final range = leaf.atomAt(inside);
        assertTrue(range != null && range.start == 2 && range.end == 2 + atomLen);
        assertEquals(null, leaf.atomAt(new Point(before.x - 8., inside.y)));
        // Clicking either half of the atom puts the caret on its near edge.
        function quarter(t:Float):Point return new Point(before.x + (after.x - before.x) * t, inside.y);
        assertEquals(2, leaf.indexForPosition(quarter(0.25)));
        assertEquals(2 + atomLen, leaf.indexForPosition(quarter(0.75)));
        // Text on both sides keeps its own indices.
        final end = leaf.positionForIndex(leaf.len());
        assertEquals(leaf.len(), leaf.indexForPosition(new Point(end.x + 40., inside.y)));
        assertEquals(0, leaf.indexForPosition(new Point(-40., inside.y)));
    }

    function testMixedFlowHitsLandOnGraphemeBoundaries() {
        // Accented, CJK and emoji text (a skin-tone sequence is one grapheme of
        // two chars) on both sides of atoms, so the leaf is a mixed flow.
        final parts = ["éa", "\u{FFFC}", "中文", "\u{FFFC}", "👍🏽x"];
        final paragraph = new Paragraph();
        for (part in parts) {
            paragraph.push(part == "\u{FFFC}" ? atom() : new InlineNode(part));
        }
        final text = parts.join('');
        final geometries = draw([Paragraph(paragraph.withLeafKey(1))], new Map(), atomPlugin(), 400.);
        final leaf = geometries.get(1);
        assertEquals(Utf8.byteLength(text), leaf.len());
        final boundaries:Array<Int> = [];
        final iter = text.graphemeIndices(true);
        while (iter.nextRange()) boundaries.push(iter.index);
        boundaries.push(Utf8.byteLength(text));

        // Sweep the whole line: every hit is a grapheme boundary.
        final bounds = leaf.bounds();
        final y = bounds.top() + leaf.lineHeight() / 2.;
        var x = bounds.left() - 4.;
        while (x <= bounds.right() + 4.) {
            final index = leaf.indexForPosition(new Point(x, y));
            assertTrue(boundaries.indexOf(index) != -1, 'hit at $x returned $index, inside a grapheme of $text');
            x += 0.5;
        }

        // The caret x of each boundary hits that boundary.
        for (index in boundaries) {
            final at = leaf.positionForIndex(index);
            assertEquals(index, leaf.indexForPosition(new Point(at.x, y)), 'caret position of $index in $text');
        }
    }

    function testMixedFlowKeepsEmptyLinesAndTrailingBreaks() {
        final paragraph = new Paragraph();
        paragraph.push(atom());
        paragraph.push(new InlineNode("a\n\n"));
        final breaks = new Paragraph();
        breaks.push(atom());
        breaks.push(new InlineNode("\n\n"));
        final leaves = draw([Paragraph(paragraph.withLeafKey(1)), Paragraph(breaks.withLeafKey(2))], new Map(), atomPlugin(), 300.);
        final leaf = leaves.get(1);
        assertEquals(6, leaf.len());
        final a = leaf.positionForIndex(3);
        final empty = leaf.positionForIndex(5);
        final end = leaf.positionForIndex(6);
        assertTrue(a.y < empty.y && empty.y < end.y);
        for (index in [5, 6]) {
            final caret = leaf.positionForIndex(index);
            assertEquals(index, leaf.indexForPosition(new Point(caret.x + 20., caret.y + leaf.lineHeight() / 2.)));
        }
        assertTrue(leaf.bounds().bottom() >= end.y + leaf.lineHeight());
        final breaksLeaf = leaves.get(2);
        assertEquals(5, breaksLeaf.len());
        assertTrue(breaksLeaf.lineHeight() < breaksLeaf.bounds().size.height);
        assertTrue(breaksLeaf.positionForIndex(5).y > breaksLeaf.positionForIndex(4).y);
    }

    function testAtomDecorationsArePaintedForCustomNodesAndImages() {
        final color:Hsla = rgba(0x12345680).toHsla();
        final custom = new Paragraph();
        custom.push(atom());
        final image = new Paragraph();
        image.push(InlineNode.ofImage(svgImage()));
        final blocks:Array<BlockNode> = [Paragraph(custom.withLeafKey(1)), Paragraph(image.withLeafKey(2))];
        final decorations:Map<Int, Array<RangedColor>> = [
            1 => [new RangedColor(new Range(0, 3), color), new RangedColor(new Range(1, 1), color)],
            2 => [new RangedColor(new Range(0, 3), color), new RangedColor(new Range(3, 6), color)],
        ];
        final painted = drawAndInspect(blocks, decorations, atomPlugin(), 300., window -> {
            var count = 0;
            for (quad in window.renderedScene().quads) {
                if (quad.backgroundTag == 0 && quad.backgroundSolidH == color.h && quad.backgroundSolidS == color.s
                    && quad.backgroundSolidL == color.l && quad.backgroundSolidA == color.a) count++;
            }
            return count;
        }).inspected;
        assertEquals(2, painted, 'one overlay per atom; empty and adjacent ranges paint nothing');
    }

    function testRekeyingClonedLeavesPreservesEachIdentity() {
        final original = plain("shared source").withLeafKey(1);
        final copy = original.clone().withLeafKey(2);
        final code = new CodeBlock("let x = 1;", null, null).withLeafKey(3);
        final copyCode = code.clone().withLeafKey(4);
        final leaves = draw([Paragraph(original), Paragraph(copy), CodeBlock(code), CodeBlock(copyCode)], new Map(), new MarkdownExtensions(), 300.);
        assertEquals(4, keys(leaves).length);
        assertEquals(13, leaves.get(1).len());
        assertEquals(10, leaves.get(3).len());
        assertTrue(leaves.get(1).bounds().top() < leaves.get(2).bounds().top());
        assertTrue(leaves.get(3).bounds().top() < leaves.get(4).bounds().top());
    }

    function testGeometryIsAnImmutableSnapshot() {
        final out = {value: new Map<Int, LeafGeometry>()};
        final result = addHost(new Host([Paragraph(plain("a long sentence that wraps when the viewport gets narrower").withLeafKey(1))],
            new MarkdownExtensions(), new Map(), out, 600., null));
        settle(result.cx);
        final old = out.value.get(1);
        final before = old.bounds();
        result.cx.update((_, cx) -> result.view.update(cx, (host, cx) -> {
            host.width = 80.;
            cx.notify();
        }));
        settle(result.cx);
        assertTrue(out.value.get(1).bounds().size.height > before.size.height);
        assertTrue(old.bounds().equals(before));
        assertTrue(old.positionForIndex(0).equals(before.origin));
    }

    function testEmptyKeyedLeafHasALineBoxAndEmptyUnkeyedLeafStaysEmpty() {
        final geometries = draw([Paragraph(new Paragraph()), Paragraph(new Paragraph().withLeafKey(9))], new Map(), new MarkdownExtensions(), 300.);
        assertEquals(1, keys(geometries).length);
        final leaf = geometries.get(9);
        assertTrue(leaf.isEmpty());
        assertTrue(leaf.bounds().size.height > 0.);
        assertEquals(leaf.bounds().left(), leaf.positionForIndex(0).x);
        assertEquals(0, leaf.indexForPosition(new Point(50., leaf.bounds().top())));
    }

    function testImageOnlyLeafReportsItsBox() {
        final paragraph = new Paragraph();
        paragraph.push(InlineNode.ofImage(svgImage()));
        final geometries = draw([Paragraph(paragraph.withLeafKey(1))], new Map(), new MarkdownExtensions(), 300.);
        final leaf = geometries.get(1);
        assertEquals(3, leaf.len());
        final range = leaf.atomAt(leaf.bounds().center());
        assertTrue(range != null && range.start == 0 && range.end == 3);
    }

    function testDecorationsAreRequestedPerKeyedLeaf() {
        final recorder = new Recorder();
        final mixed = new Paragraph();
        mixed.push(new InlineNode("ab"));
        mixed.push(atom());
        final blocks:Array<BlockNode> = [
            Paragraph(plain("one").withLeafKey(1)),
            Paragraph(plain("unkeyed")),
            Paragraph(mixed.withLeafKey(2)),
        ];
        final result = addHost(new Host(blocks, atomPlugin(), new Map(), {value: new Map()}, 300., recorder));
        settle(result.cx);
        final asked = recorder.asked;
        assertTrue(asked.indexOf(1) != -1 && asked.indexOf(2) != -1, asked.join(','));
        for (key in asked) assertTrue(key == 1 || key == 2, asked.join(','));
    }

    function testDecoratedLeavesStillReportGeometry() {
        final blocks:Array<BlockNode> = [Paragraph(plain("hello world").withLeafKey(1))];
        final decorations:Map<Int, Array<RangedColor>> = [
            1 => [new RangedColor(new Range(0, 5), rgba(0x3366ff80).toHsla()), new RangedColor(new Range(6, 11), rgb(0xffcc00).toHsla())],
        ];
        final plainGeometry = draw([for (b in blocks) b.clone()], new Map(), new MarkdownExtensions(), 300.);
        final decorated = draw(blocks, decorations, new MarkdownExtensions(), 300.);
        assertTrue(decorated.get(1).bounds().size.equals(plainGeometry.get(1).bounds().size), 'decorations paint behind the text and never change layout');
    }

    function testCollectLeafGeometryNestsAndRestoresOnPanic() {
        var seen = 0;
        final outer = EditorHost.collectLeafGeometry(new Map(), () -> {
            assertTrue(EditorSeam.current() != null);
            final outerSink = EditorSeam.current();
            EditorHost.collectLeafGeometry(new Map(), () -> {
                seen++;
                return true;
            });
            final after = EditorSeam.current();
            assertTrue(outerSink == after, 'the outer scope is restored');
            return true;
        });
        assertTrue(outer.result && keys(outer.leaves).length == 0 && seen == 1);
        assertTrue(EditorSeam.current() == null);

        var failed = false;
        try {
            EditorHost.collectLeafGeometry(new Map(), () -> {
                throw 'boom';
                return true;
            });
        }
        catch (e:Dynamic) {
            failed = true;
        }
        assertTrue(failed);
        assertTrue(EditorSeam.current() == null, 'cleared after a panic');
    }

    function testParseMarkdownReadsWhatAnEditorRoundTrips() {
        final source = "```rust title=\"x\"\nfn main() {}\n```\n\n"
            + "| a | b | c | d |\n|---|:--|:-:|--:|\n| 1 | 2 | 3 | 4 |\n\n"
            + "[ref]: https://example.com \"Title\"\n";
        final blocks = EditorHost.parseMarkdown(source, new MarkdownExtensions());
        var code:Null<CodeBlock> = null;
        var table:Null<Table> = null;
        var definition = false;
        for (block in blocks) {
            switch block {
                case CodeBlock(c) if (code == null): code = c;
                case Table(t) if (table == null): table = t;
                case Definition(identifier, _, _, _) if (identifier == "ref"): definition = true;
                case _:
            }
        }
        assertEquals("rust", code.lang());
        assertEquals("title=\"x\"", code.meta());
        assertEquals([ColumnumnAlign.None, ColumnumnAlign.Left, ColumnumnAlign.Center, ColumnumnAlign.Right].join(','), table.columnAligns().join(','));
        final cells = [for (row in table.rows()) [for (cell in row) [for (c in cell.children()) c.text()].join('')].join(',')].join('|');
        assertEquals('a,b,c,d|1,2,3,4', cells);
        assertTrue(definition);
        for (block in blocks) {
            assertTrue(block.span() != null || block.match(Unknown));
        }
    }

    function testParseMarkdownMatchesTextViewParse() {
        final source = "# Title\n\nSome **bold** and `code` and ==mark==.\n\n- one\n- two\n";
        final expected = MarkdownFormat.parse(source, new NodeContext());
        final blocks = EditorHost.parseMarkdown(source, new MarkdownExtensions());
        assertTrue(gpui.base.text.BlockNode.BlockNodeTools.arrayEquals(blocks, expected.blocks));
    }

    function testTableAndParagraphBuildersReadBack() {
        final paragraph = new Paragraph();
        paragraph.push(new InlineNode("hi").marks([new RangedMark(new Range(0, 2), new TextMark().withBold())]));
        assertEquals("hi", paragraph.children()[0].text());
        assertTrue(paragraph.children()[0].markRuns()[0].mark.bold);
        assertTrue(paragraph.children()[0].asImage() == null);
        assertTrue(paragraph.children()[0].asCustom() == null);
        final table = gpui.base.text.Table.of([[paragraph]], [ColumnumnAlign.Center]);
        assertEquals(1, table.rows().length);
        assertEquals(ColumnumnAlign.Center, table.columnAligns()[0]);
    }

}
