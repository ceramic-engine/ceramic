// Ported from gpui-kit 0.8.1: crates/base/src/text/range_highlight.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.Hsla;
import glaze.Range;
import glaze.kit.base.text.BlockNode;
import glaze.kit.base.text.CodeBlock;
import glaze.kit.base.text.LeafRemap;
import glaze.kit.base.text.MarkdownExtensions;
import glaze.kit.base.text.MarkdownNode;
import glaze.kit.base.text.NodeContext;
import glaze.kit.base.text.Paragraph;
import glaze.kit.base.text.ParsedDocument;
import glaze.kit.base.text.RangeHighlight;
import glaze.kit.base.text.RangeHighlightFrame;
import glaze.kit.base.text.RangedColor;
import glaze.kit.base.text.RenderedIndex.LeafSpan;
import glaze.kit.base.text.RenderedText;
import glaze.kit.base.text.TextLeafKey;
import glaze.kit.base.text.format.HtmlFormat;
import glaze.kit.base.text.format.MarkdownFormat;
import glaze.util.Utf8;
import testing.TestCase;

import glaze.Prelude.*;

/** A block whose text is a leaf, in the order of the rendered text (Rust `LeafNode`). */
private enum LeafNode {
    ParagraphLeaf(paragraph:Paragraph);
    CodeLeaf(codeBlock:CodeBlock);
}

/**
 * Tests of the range highlights and source conversion (Rust
 * `text/range_highlight.rs`).
 */
@:access(glaze.kit.base.text)
class TextRangeHighlightTest extends TestCase {

    static function parse(markdown:String):ParsedDocument {
        return MarkdownFormat.parse(markdown, new NodeContext());
    }

    static function rendered(document:ParsedDocument):RenderedText {
        return new RenderedText(1, 0, document, new glaze.kit.base.text.RenderedText.RenderedIndexCell());
    }

    /** Byte offset of the `nth` (zero-based) occurrence of `needle` in `text`. */
    static function find(text:String, needle:String, nth:Int = 0):Int {
        var from = 0;
        var count = 0;
        while (true) {
            final ix = text.indexOf(needle, from);
            if (ix == -1) throw '$needle occurs $nth times in $text';
            if (count == nth) return Utf8.byteLength(text.substr(0, ix));
            count++;
            from = ix + 1;
        }
    }

    /** The range of `markdown` holding the `nth` (zero-based) occurrence of `needle`. */
    static function nth(markdown:String, needle:String, nth:Int):Range {
        final start = find(markdown, needle, nth);
        return new Range(start, start + Utf8.byteLength(needle));
    }

    /** The text rendered from `source` of `markdown`. */
    static function converted(markdown:String, source:Range):Null<String> {
        final text = rendered(parse(markdown));
        final range = text.rangeForSource(source);
        if (range == null) return null;
        return Utf8.substring(text.asStr(), range.start, range.end);
    }

    /** The text rendered from the first occurrence of `needle` in `markdown`. */
    static function convertedNeedle(markdown:String, needle:String):Null<String> {
        return converted(markdown, nth(markdown, needle, 0));
    }

    static function str(range:Null<Range>):String {
        return range == null ? 'None' : '${range.start}..${range.end}';
    }

    function testTableRowIndexKeepsEmptyCellsInTheirRow() {
        final source = "| a | b |\n|---|---|\n| é |   |\n|   |   |\n| c | d |\n";
        final document = parse(source);
        final remap = new LeafRemap(document, document, false);
        assertEquals(4, remap.tableRows.length);
        final ends:Array<Null<String>> = ["b", "é", null, "d"];
        for (row in 0...ends.length) {
            final text = ends[row];
            final expected:Null<Int> = text != null ? find(source, text) + Utf8.byteLength(text) : null;
            for (column in 0...2) {
                final key = TextLeafKey.tableCell(0, row * 2 + column);
                assertEquals(expected, remap.rowSourceEnd(key), key.toString());
            }
        }
        assertEquals(null, remap.rowSourceEnd(TextLeafKey.tableCell(0, 8)));
    }

    function testTableRowIndexFindsNestedTablesWithoutCrossingBetweenThem() {
        final source = "| a |\n|---|\n| b |\n\n" + "> | c |\n> |---|\n> | d |\n\n" + "- | e |\n  |---|\n  | f |\n";
        final document = parse(source);
        final remap = new LeafRemap(document, document, false);
        assertEquals(6, remap.tableRows.length);
        for (pair in [["a", "b"], ["c", "d"], ["e", "f"]]) {
            final start = find(source, '| ${pair[0]} |');
            for (cell in 0...2) {
                final text = pair[cell];
                final key = TextLeafKey.tableCell(start, cell);
                assertEquals(find(source, text) + Utf8.byteLength(text), remap.rowSourceEnd(key));
            }
            assertEquals(null, remap.rowSourceEnd(TextLeafKey.tableCell(start, 2)));
            assertEquals(null, remap.rowSourceEnd(TextLeafKey.tableCell(start + 1, 0)));
        }
    }

    function testLongAndWideTablesRemapHighlightsByWholeRows() {
        final color = hsla(0.15, 1., 0.5, 0.4);
        for (shape in [[4096, 1], [2, 1024], [64, 16]]) {
            final rows = shape[0];
            final columns = shape[1];
            final row = '|' + [for (_ in 0...columns) ' x |'].join('') + '\n';
            final separator = '|' + [for (_ in 0...columns) '---|'].join('') + '\n';
            final source = row + separator + [for (_ in 0...rows) row].join('');
            final old = parse(source);
            // Even unchanged cells earlier in the edited row must lose their
            // highlights, as must the unchanged rows that follow it.
            final edit = row.length + separator.length + row.lastIndexOf('x');
            final changed = source.substr(0, edit) + 'y' + source.substr(edit + 1);
            final next = parse(changed);
            final remap = new LeafRemap(old, next, false);
            assertEquals(rows + 1, remap.tableRows.length);
            final frame = new RangeHighlightFrame([
                for (leaf in remap.oldLeaves) new glaze.kit.base.text.RangeHighlightFrame.LeafBackgrounds(leaf.key, [new RangedColor(new Range(0, 1), color)])
            ]);
            assertEquals((rows + 1) * columns, frame.leaves.length);
            final kept = frame.remap(remap);
            assertEquals(columns, kept.leaves.length);
            for (column in 0...columns) {
                final backgrounds = kept.backgrounds(TextLeafKey.tableCell(0, column));
                assertEquals(1, backgrounds.length);
                assertEquals('0..1', str(backgrounds[0].range));
                assertTrue(backgrounds[0].color.equals(color));
            }
        }
    }

    function testAppendRemappingDoesNotBuildATableRowIndex() {
        final source = "| a |\n|---|\n| b |\n\n| c |\n|---|\n| d |\n";
        final old = parse(source);
        final next = parse(source + "| e |\n");
        final remap = new LeafRemap(old, next, true);
        assertEquals(0, remap.tableRows.length);
        final first = TextLeafKey.tableCell(0, 0);
        final found = remap.leaf(first);
        assertTrue(found.key.equals(first));
        assertEquals(0x7fffffff, found.unchanged);
        final lastStart = find(source, "| c |");
        for (cell in 0...2) {
            final key = TextLeafKey.tableCell(lastStart, cell);
            final found = remap.leaf(key);
            assertTrue(found.key.equals(key));
            assertEquals(1, found.unchanged);
        }
    }

    function testAPositionInAnInlineObjectMovesOntoText() {
        // "ab" then two objects of 2 bytes each, then "cd".
        function leaf(len:Int):LeafSpan {
            return new LeafSpan(new Range(10, 10 + len), TextLeafKey.block(0), [new Range(2, 4), new Range(4, 6)]);
        }
        assertEquals(1, leaf(8).textOffsetNear(1));
        // Onto the text after the objects.
        assertEquals(6, leaf(8).textOffsetNear(3));
        assertEquals(6, leaf(8).textOffsetNear(5));
        // At the end of the leaf, onto the text before them.
        assertEquals(1, leaf(6).textOffsetNear(5));
    }

    function testRangeHighlightRequiresABackground() {
        final color = hsla(0.15, 1., 0.5, 0.4);
        final highlight = new RangeHighlight(new Range(2, 5), color);
        assertEquals('2..5', str(highlight.range()));
        assertTrue(highlight.background().equals(color));
    }

    function testSourceRenderingNothingConvertsToNone() {
        for (pair in [
            ["# Title", "# "],
            ["hello **world**", "**"],
            ["a ~~b~~ c", "~~"],
            ["- item", "- "],
            ["1. item", "1. "],
            ["- [x] done", "[x] "],
            ["> quote", "> "],
            ["```rust\nlet x\n```", "```rust\n"],
            ["```rust\nlet x\n```", "\n```"],
            ["| a | b |\n|---|---|\n| c | d |", "|---|---|"],
            ["| a | b |\n|---|---|\n| c | d |", " | "],
            ["see [docs](https://example.com) now", "(https://example.com)"],
            ["a ![alt](image.png) b", "![alt](image.png)"],
            ["a\n\n---\n\nb", "---"],
            ["para\n\n[ref]: https://example.com", "[ref]: https://example.com"],
        ]) {
            assertEquals(null, convertedNeedle(pair[0], pair[1]), '${pair[1]} of ${pair[0]}');
        }
    }

    function testDelimitersInARangeAddNothing() {
        final markdown = "hello **world** and `code`";
        assertEquals("hello world and code", converted(markdown, new Range(0, Utf8.byteLength(markdown))));
        assertEquals("world", convertedNeedle(markdown, "**world**"));
        assertEquals("o wor", convertedNeedle(markdown, "o **wor"));
        assertEquals("code", convertedNeedle(markdown, "`code`"));
        assertEquals("Title", convertedNeedle("# **Title**", "# **Title**"));
        assertEquals("the docs", convertedNeedle("see [the docs](https://x.y) now", "[the docs](https://x.y)"));
    }

    function testRepeatedTextConvertsToTheOccurrenceAddressed() {
        final markdown = "foo **foo** foo";
        final text = rendered(parse(markdown));
        assertEquals("foo foo foo\n", text.asStr());
        assertEquals('0..3', str(text.rangeForSource(nth(markdown, "foo", 0))));
        assertEquals('4..7', str(text.rangeForSource(nth(markdown, "foo", 1))));
        assertEquals('8..11', str(text.rangeForSource(nth(markdown, "foo", 2))));
    }

    function testFencedCodeBackslashesConvertIndividually() {
        final markdown = "```\na\\\\b\n```";
        final text = rendered(parse(markdown));
        assertEquals('1..2', str(text.rangeForSource(new Range(5, 6))));
        assertEquals('2..3', str(text.rangeForSource(new Range(6, 7))));
        assertEquals('1..3', str(text.rangeForSource(new Range(5, 7))));
    }

    function testLiteralCodeEscapesConvertIndividually() {
        final cases:Array<{markdown:String, first:Int, second:Int, start:Int}> = [
            {markdown: "`a\\\\b`", first: 2, second: 3, start: 1},
            {markdown: "`a\\*b`", first: 2, second: 3, start: 1},
            {markdown: "    one\n    a\\\\b", first: 13, second: 14, start: 5},
            {markdown: "- ```\n  a\\\\b\n  ```", first: 9, second: 10, start: 1},
            {markdown: "> ```\n> a\\\\b\n> ```", first: 9, second: 10, start: 1},
            {markdown: "```\na\\*b\n```", first: 5, second: 6, start: 1},
            {markdown: "```\na\\\\b\r\n```", first: 5, second: 6, start: 1},
            {markdown: "```\na\\\\\nb\n```", first: 5, second: 6, start: 1},
        ];
        for (c in cases) {
            final text = rendered(parse(c.markdown));
            assertEquals('${c.start}..${c.start + 1}', str(text.rangeForSource(new Range(c.first, c.first + 1))), c.markdown);
            assertEquals('${c.start + 1}..${c.start + 2}', str(text.rangeForSource(new Range(c.second, c.second + 1))), c.markdown);
        }
        var text = rendered(parse("a\\*b"));
        assertEquals('1..2', str(text.rangeForSource(new Range(1, 2))));
        assertEquals('1..2', str(text.rangeForSource(new Range(2, 3))));
        text = rendered(parse("```\na\\\\\nb\n```"));
        assertEquals('3..4', str(text.rangeForSource(new Range(7, 8))));
        assertEquals('4..5', str(text.rangeForSource(new Range(8, 9))));
    }

    function testACharacterConvertsWhenAnyOfItsSourceIsInTheRange() {
        // `&amp;` renders `&`: its name alone still renders that `&`.
        assertEquals("&", convertedNeedle("a &amp; b", "amp"));
        assertEquals("&", convertedNeedle("a &amp; b", "&amp;"));
        assertEquals("B", convertedNeedle("&#65;&#x42;", "&#x42;"));
        // `\*` renders `*`, from either of its characters.
        assertEquals("*", convertedNeedle("a \\* b", "\\"));
        assertEquals("*", convertedNeedle("a \\* b", "*"));
        // Text after an escape that starts a text node still converts
        // character for character.
        assertEquals("b", convertedNeedle("\\*abc", "b"));
        assertEquals("*a", convertedNeedle("**\\*abc**", "*a"));
        // A soft line break renders a space from the newline.
        assertEquals(" ", convertedNeedle("soft\nbreak", "\n"));
        assertEquals(" ", convertedNeedle("soft\r\nbreak", "\r\n"));
        assertEquals(" ", convertedNeedle("soft\r\nbreak", "\n"));
    }

    function testADecodedEntityConvertsOnlyAsAWhole() {
        // `&acE;` decodes to `∾̳`, whose two characters take as many bytes as
        // the entity's source, but not character for character.
        final markdown = "a &acE; b";
        final text = rendered(parse(markdown));
        assertEquals("a ∾̳ b\n", text.asStr());
        assertEquals("a", convertedNeedle(markdown, "a"));
        assertEquals("b", convertedNeedle(markdown, "b"));
        assertEquals("∾̳", convertedNeedle(markdown, "cE"));
        assertEquals("∾̳", convertedNeedle(markdown, "&acE;"));
        assertEquals("a ∾̳", convertedNeedle(markdown, "a &a"));
    }

    function testMultibyteTextConvertsOnCharacterBoundaries() {
        final markdown = "中文 **粗体** 🎉 é";
        assertEquals("粗", convertedNeedle(markdown, "粗"));
        assertEquals("文 粗", convertedNeedle(markdown, "文 **粗"));
        assertEquals("🎉", convertedNeedle(markdown, "🎉"));
        assertEquals("é", convertedNeedle(markdown, "é"));
        // A range splitting a character is not a range of the source.
        final split = nth(markdown, "粗", 0);
        assertEquals(null, converted(markdown, new Range(split.start, split.start + 1)));
        assertEquals(null, converted(markdown, new Range(split.start + 1, split.end)));
    }

    function testRangesThatAreNotRangesOfTheSourceConvertToNone() {
        final text = rendered(parse("hello world"));
        assertEquals(null, text.rangeForSource(new Range(3, 3)));
        assertEquals(null, text.rangeForSource(new Range(5, 3)));
        assertEquals(null, text.rangeForSource(new Range(0, 12)));
        assertEquals(null, text.rangeForSource(new Range(20, 30)));
        assertEquals('0..11', str(text.rangeForSource(new Range(0, 11))));

        final empty = rendered(parse(""));
        assertEquals("", empty.source());
        assertEquals(null, empty.rangeForSource(new Range(0, 0)));
    }

    function testARangeAcrossBlocksHoldsTheSeparatorsBetweenThem() {
        final markdown = "ab\n\ncd\n\n# ef";
        // "ab\ncd\nef\n"
        assertEquals("b\ncd\ne", convertedNeedle(markdown, "b\n\ncd\n\n# e"));

        final table = "| a | b |\n|---|---|\n| c | d |";
        assertEquals("b\nc", convertedNeedle(table, "b |\n|---|---|\n| c"));
        assertEquals("c d", convertedNeedle(table, "c | d"));

        final list = "- one\n- two\n  - three";
        assertEquals("ne\ntwo\nth", convertedNeedle(list, "ne\n- two\n  - th"));
    }

    function testCodeBlocksConvertTheirBody() {
        final fenced = "```rust\nlet x = 1;\nlet y = 2;\n```";
        assertEquals("x = 1;\nlet y", convertedNeedle(fenced, "x = 1;\nlet y"));
        assertEquals("let x = 1;\nlet y = 2;", converted(fenced, new Range(0, Utf8.byteLength(fenced))));
        final indented = "    let x = 1;\n    let y = 2;";
        assertEquals("x = 1", convertedNeedle(indented, "x = 1"));
        final tilde = "~~~\nwavy\n~~~";
        assertEquals("wavy", converted(tilde, new Range(0, Utf8.byteLength(tilde))));
    }

    function testAnImageBetweenTextsKeepsTheRangeContiguous() {
        final markdown = "a ![alt](image.png) b";
        final text = rendered(parse(markdown));
        final range = text.rangeForSource(new Range(0, Utf8.byteLength(markdown)));
        assertEquals("a  b", Utf8.substring(text.asStr(), range.start, range.end));
    }

    function testHtmlTextConvertsNothing() {
        final html = "<p>one <b>two</b></p>";
        final document = HtmlFormat.parse(html, new NodeContext());
        final text = rendered(document);
        assertEquals(html, text.source());
        assertFalse(text.isEmpty());
        for (start in 0...html.length) {
            for (end in start + 1...html.length + 1) {
                assertEquals(null, text.rangeForSource(new Range(start, end)), '$start..$end');
            }
        }
    }

    function testCustomBlocksConvertWhole() {
        final extensions = new MarkdownExtensions().blockParser((node, cx) -> {
            switch node {
                case Paragraph(paragraph) if (paragraph.children.length == 1):
                    switch paragraph.children[0] {
                        case Text(text) if (StringTools.startsWith(text.value, '$')):
                            final source = cx.nodeSource(node);
                            return new MarkdownNode("ticker", null).text(text.value).markdown(source != null ? source : '');
                        case _:
                    }
                case _:
            }
            return null;
        });
        final markdown = "before\n\n$TSLA.US\n\nafter";
        final cx = new NodeContext();
        cx.markdownExtensions = extensions;
        final text = rendered(MarkdownFormat.parse(markdown, cx));

        assertEquals("before\n$TSLA.US\nafter\n", text.asStr());
        final ticker = nth(markdown, "$TSLA.US", 0);
        assertEquals('7..15', str(text.rangeForSource(ticker)));
        // Part of the block's source converts the whole block.
        assertEquals('7..15', str(text.rangeForSource(new Range(ticker.start + 1, ticker.start + 3))));
        assertEquals('4..15', str(text.rangeForSource(nth(markdown, "re\n\n$T", 0))));
    }

    static function leafText(leaf:LeafNode):String {
        return switch leaf {
            case ParagraphLeaf(paragraph): [for (child in paragraph.children_) child.text_].join('');
            case CodeLeaf(codeBlock): codeBlock.code();
        }
    }

    /**
     * Selects `range` of its text, as painting a selection does. A paragraph
     * paints the run of text before each inline image in that image's state
     * and the rest in its own.
     */
    static function selectLeaf(leaf:LeafNode, range:Null<Range>):Void {
        switch leaf {
            case ParagraphLeaf(paragraph):
                final text = leafText(leaf);
                function selectRun(state:glaze.kit.base.text.InlineState, runStart:Int, runEnd:Int) {
                    state.setText(Utf8.substring(text, runStart, runEnd));
                    if (range == null) {
                        state.selection = null;
                    }
                    else {
                        final start = range.start > runStart ? range.start : runStart;
                        final end = range.end < runEnd ? range.end : runEnd;
                        state.selection = start < end ? new glaze.kit.base.input.Selection(start - runStart, end - runStart) : null;
                    }
                }
                var runStart = 0;
                var offset = 0;
                for (child in paragraph.children_) {
                    if (child.custom != null) throw 'inline objects select on their own';
                    if (child.image != null) {
                        selectRun(child.state, runStart, offset);
                        runStart = offset;
                    }
                    offset += Utf8.byteLength(child.text_);
                }
                selectRun(paragraph.state, runStart, offset);
            case CodeLeaf(codeBlock):
                if (range != null) codeBlock.setSelection(range) else codeBlock.clearSelection();
        }
    }

    /** The blocks holding text, the way `IndexBuilder` walks them. */
    static function leafNodes(blocks:Array<BlockNode>, leaves:Array<LeafNode>):Void {
        for (block in blocks) {
            switch block {
                case Root(children, _) | Blockquote(children, _) | List(children, _, _, _) | ListItem(children, _, _, _):
                    leafNodes(children, leaves);
                case Paragraph(paragraph):
                    leaves.push(ParagraphLeaf(paragraph));
                case Heading(_, children, _):
                    leaves.push(ParagraphLeaf(children));
                case Table(table):
                    for (row in table.children) for (cell in row.children) leaves.push(ParagraphLeaf(cell.children));
                case CodeBlock(codeBlock):
                    leaves.push(CodeLeaf(codeBlock));
                case _:
            }
        }
        var i = leaves.length - 1;
        while (i >= 0) {
            if (leafText(leaves[i]).length == 0) leaves.splice(i, 1);
            i--;
        }
    }

    /**
     * Checks that selecting any range of `markdown`'s rendered text that
     * starts and ends inside text, and converting the source range the
     * selection reports, gives the selected range back.
     */
    function assertSelectionsRoundTrip(markdown:String):Void {
        final document = parse(markdown);
        final text = rendered(document);
        final textStr = text.asStr();
        // Only a character maps as a whole, or the characters one entity
        // decodes to: a longer piece would widen every range inside it.
        for (segment in text.index().sourceMap) {
            if (segment.linear) continue;
            final renderedPiece = Utf8.substring(textStr, segment.rendered.start, segment.rendered.end);
            final source = Utf8.substring(markdown, segment.source.start, segment.source.end);
            final chars = [for (c in new haxe.iterators.StringIteratorUnicode(renderedPiece)) c].length;
            assertTrue(chars == 1 || (StringTools.startsWith(source, '&') && StringTools.endsWith(source, ';')),
                '$markdown: $renderedPiece maps from $source only as a whole');
        }
        final leafList:Array<LeafNode> = [];
        leafNodes(document.blocks, leafList);
        final spans = text.index().leaves;
        assertEquals(spans.length, leafList.length, 'leaves of $markdown');
        final leaves = [for (i in 0...leafList.length) {leaf: leafList[i], range: spans[i].range}];

        // Every character boundary inside a leaf, as (leaf, offset in text).
        final boundaries:Array<{ix:Int, offset:Int}> = [];
        for (ix in 0...leaves.length) {
            final range = leaves[ix].range;
            final leafStr = Utf8.substring(textStr, range.start, range.end);
            var offset = 0;
            for (c in new haxe.iterators.StringIteratorUnicode(leafStr)) {
                boundaries.push({ix: ix, offset: range.start + offset});
                offset += Utf8.codePointLength(c);
            }
            boundaries.push({ix: ix, offset: range.start + offset});
        }

        for (startIx in 0...boundaries.length) {
            final first = boundaries[startIx].ix;
            final start = boundaries[startIx].offset;
            if (start == leaves[first].range.end) continue;
            for (b in startIx + 1...boundaries.length) {
                final last = boundaries[b].ix;
                final end = boundaries[b].offset;
                if (end == leaves[last].range.start || end <= start) continue;
                for (ix in 0...leaves.length) {
                    final range = leaves[ix].range;
                    final selected = ix >= first && ix <= last
                        ? new Range((start > range.start ? start : range.start) - range.start, (end < range.end ? end : range.end) - range.start)
                        : null;
                    selectLeaf(leaves[ix].leaf, selected);
                }
                final source = document.selectedSourceRange();
                if (source == null) {
                    fail('$markdown: selecting $start..$end maps to no source');
                    return;
                }
                // Characters that share their source are only selected together.
                var expectedStart = start;
                var expectedEnd = end;
                for (segment in text.index().sourceMap) {
                    if (!segment.linear && segment.rendered.start < end && segment.rendered.end > start) {
                        if (segment.rendered.start < expectedStart) expectedStart = segment.rendered.start;
                        if (segment.rendered.end > expectedEnd) expectedEnd = segment.rendered.end;
                    }
                }
                final actual = text.rangeForSource(source);
                if (actual == null || actual.start != expectedStart || actual.end != expectedEnd) {
                    fail('$markdown: selecting $start..$end reports source ${source.start}..${source.end}, converted ${str(actual)}, expected $expectedStart..$expectedEnd');
                    return;
                }
            }
        }
        for (leaf in leaves) {
            selectLeaf(leaf.leaf, null);
        }
    }

    static final ROUND_TRIP_CORPUS:Array<String> = [
        "plain text",
        "hello **world** and *em* and ~~del~~ and `code`",
        "nested **bold *and italic* text** and ***both***",
        "`` code with ` backtick `` then text",
        "# Heading with **bold**",
        "Setext heading\n===",
        "> quoted **text**\n> continued\n>\n> second paragraph",
        "- item one\n- item **two**\n  - nested *item*\n\n  continued item",
        "3. third\n4. fourth",
        "- [x] done\n- [ ] todo",
        "| a | **b** |\n|---|:---:|\n| c `d` | e |\n| | f |",
        "```rust\nlet x = 1;\n\nlet y = 2;\n```",
        "    indented code\n    more",
        "~~~\ntilde fence\n~~~",
        "a [link](https://example.com \"title\") b",
        "a [reference] b\n\n[reference]: https://example.com",
        "<https://auto.example> and https://gfm.example",
        "soft\nbreak\nlines",
        "hard  \nbreak\\\nagain",
        "trailing spaces   \nnext line",
        "escapes \\* \\_ \\` \\\\ and \\[not a link\\]",
        "\\*starts escaped and **\\*bold** and *\\_em*",
        "entity &acE; as long as its characters",
        "entities &amp; &lt; &#65; &#x42; &copy; end",
        "中文 **粗体** 和 `代码` 🎉 é and é",
        "crlf\r\nlines\r\n\r\nnext paragraph",
        "image ![alt](image.png) between",
        "one\n\ntwo\n\n---\n\nthree",
        "# Title\n\nIntro with **bold**.\n\n- first\n- second\n\n| a | b |\n|---|---|\n| c | d |\n\n```\ncode\n```\n\n> quote",
    ];

    function testSelectionsRoundTripThroughSourceRanges() {
        for (markdown in ROUND_TRIP_CORPUS) {
            assertSelectionsRoundTrip(markdown);
        }
    }

}
