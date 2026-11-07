// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.Bounds;
import gpui.HighlightStyle;
import gpui.ImageFormat;
import gpui.ImageSource;
import gpui.Point;
import gpui.Range;
import gpui.Resource;
import gpui.Size;
import gpui.base.input.Selection;
import gpui.base.input.StyledRange;
import gpui.base.text.BlockNode;
import gpui.base.text.BlockState;
import gpui.base.text.CodeBlock;
import gpui.base.text.ColumnumnAlign;
import gpui.base.text.ImageNode;
import gpui.base.text.InlineNode;
import gpui.base.text.LinkMark;
import gpui.base.text.MarkdownNode;
import gpui.base.text.Paragraph;
import gpui.base.text.Paragraph.MarkdownSource;
import gpui.base.text.ParsedDocument;
import gpui.base.text.RangedMark;
import gpui.base.text.SelectionFormat;
import gpui.base.text.Span;
import gpui.base.text.Table;
import gpui.base.text.Table.TableCell;
import gpui.base.text.Table.TableRow;
import gpui.base.text.TableData;
import gpui.base.text.TextMark;
import gpui.base.text.TextUtils;
import testing.TestCase;

import gpui.Prelude.*;

using gpui.base.text.BlockNode.BlockNodeTools;

/**
 * Tests of the document model of node.rs (selection, source
 * reconstruction, tables, code blocks, images). The measurement and render
 * tests are in `TextNodeRenderTest`.
 */
@:access(gpui.base.text)
class TextNodeTest extends TestCase {

    static inline function len(s:String):Int {
        return TextUtils.len(s);
    }

    static function mark(start:Int, end:Int, mark:TextMark):RangedMark {
        return new RangedMark(new Range(start, end), mark);
    }

    static function plain(text:String):InlineNode {
        return new InlineNode(text).marks([mark(0, len(text), new TextMark())]);
    }

    static function paragraphOf(children:Array<InlineNode>):Paragraph {
        final paragraph = new Paragraph();
        paragraph.children_ = children;
        return paragraph;
    }

    static function setStateSelection(node:InlineNode, text:String, start:Int, end:Int) {
        node.state.text = text;
        node.state.selection = new Selection(start, end);
    }

    function testBlockPluginSelectionCopiesBothFormatsAndClearsSynchronously() {
        final source = "$$\nx\n$$";
        final node = new MarkdownNode("math", null).text("x").markdown(source);
        node.setSpan(new Span(0, len(source)));
        final state = new BlockState();
        final sameContent = BlockNode.Custom(node.clone(), new BlockState());
        final block = BlockNode.Custom(node, state);
        final document = new ParsedDocument(source, [block.clone()]);
        assertFalse(block.hasSelection());
        state.setSelection(Full);
        // Runtime selection does not affect parsed content equality.
        assertTrue(block.equals(sameContent));
        for (blocks in [null, [0, 0]]) {
            assertEquals("x\n", document.selectedText(Plain, blocks));
            assertEquals(source, document.selectedText(Source, blocks));
        }
        assertTrue(new Range(0, len(source)).equals(document.selectedSourceRange()));

        // A clone shares the retained state, including clearing before repaint.
        block.clearSelection();
        assertFalse(document.blocks[0].hasSelection());
        assertEquals("", document.selectedText(Plain, [0, 0]));
        assertNull(document.selectedSourceRange());
    }

    function testBlockPluginEmptyEndpointSuppressesVirtualizedCopyFallback() {
        final state = new BlockState();
        final block = BlockNode.Custom(new MarkdownNode("math", null).text("formula").markdown("$$formula$$"), state);
        final after = gpui.base.text.CodeBlock.fromCode("after");
        after.setSelection(new Range(0, 5));
        final document = new ParsedDocument('', [block, BlockNode.CodeBlock(after)]);
        assertTrue(document.selectedText(Plain, [0, 1]).indexOf("formula") >= 0);
        state.setSelection(Empty);
        assertTrue(document.blocks[0].hasSelection());
        for (format in [SelectionFormat.Plain, SelectionFormat.Source]) {
            final text = document.selectedText(format, [0, 1]);
            assertTrue(text.indexOf("after") >= 0);
            assertFalse(text.indexOf("formula") >= 0);
        }
    }

    function testBlockPluginGeometrySelectsWholeBlocksInBothDragDirections() {
        final bounds = new Bounds(new Point(10., 20.), new Size(100., 40.));
        final inside = bounds.center();
        final above = new Point(0., 0.);
        final below = new Point(0., 80.);
        for (pair in [[above, inside], [inside, below], [above, below]]) {
            assertTrue(BlockState.customBlockIsSelected(bounds, pair[0], pair[1]));
            assertTrue(BlockState.customBlockIsSelected(bounds, pair[1], pair[0]));
        }
        assertFalse(BlockState.customBlockIsSelected(bounds, inside, inside));
        // Pointer travel during a click, and any drag that never leaves the
        // block, select nothing.
        for (pair in [
            [inside, inside.add(new Point(1., 0.))],
            [bounds.origin, bounds.bottomRight().sub(new Point(1., 1.))]
        ]) {
            assertFalse(BlockState.customBlockIsSelected(bounds, pair[0], pair[1]));
            assertFalse(BlockState.customBlockIsSelected(bounds, pair[1], pair[0]));
        }
        assertFalse(BlockState.customBlockIsSelected(bounds, new Point(150., 30.), new Point(160., 40.)));
    }

    function testSelectedInlineObjectsCoalesceSurroundingEmphasis() {
        for (item in [
            {objectMark: new TextMark().withItalic(), expected: "*fore $x$ aft*"},
            {objectMark: new TextMark().withItalic().withBold(), expected: "*fore **$x$** aft*"}
        ]) {
            final italic = new TextMark().withItalic();
            final before = new InlineNode("before ").marks([mark(0, 7, italic.clone())]);
            final formula = InlineNode.ofCustom(new MarkdownNode("math", null).text("x").markdown("$x$")).marks([mark(0, 1, item.objectMark)]);
            final after = new InlineNode(" after").marks([mark(0, 6, italic)]);
            setStateSelection(formula, "before ", 2, 7);
            formula.customSelection.value = true;
            final paragraph = paragraphOf([before, formula, after]);
            paragraph.state.text = " after";
            paragraph.state.selection = new Selection(0, 4);
            assertEquals(item.expected, paragraph.selectedSource());
        }
    }

    function testConsecutiveInlineObjectsCopyAtomicallyWithoutNeighboringText() {
        final first = InlineNode.ofCustom(new MarkdownNode("math", null).text("甲²").markdown("$甲^2$"));
        final second = InlineNode.ofCustom(new MarkdownNode("math", null).text("b").markdown("$b$"));
        first.customSelection.value = true;
        second.customSelection.value = true;
        final paragraph = paragraphOf([first, second]);
        assertEquals("甲²b", paragraph.selectedText());
        assertEquals("$甲^2$$b$", paragraph.selectedSource());
        assertTrue(paragraph.hasSelection());
        paragraph.clearSelection();
        assertEquals("", paragraph.selectedText());
        assertEquals("", paragraph.selectedSource());
        assertFalse(paragraph.hasSelection());
    }

    function testSelectedInlineObjectInterleavesRunsAndPreservesEnclosingMark() {
        final before = new InlineNode("中文 ");
        final formula = InlineNode.ofCustom(new MarkdownNode("math", null).text("x²").markdown("$x^2$")).marks([mark(0, 3, new TextMark().withBold())]);
        final after = new InlineNode(" English");
        setStateSelection(formula, "中文 ", 3, 7);
        formula.customSelection.value = true;
        final paragraph = paragraphOf([before, formula, after]);
        paragraph.state.text = " English";
        paragraph.state.selection = new Selection(0, 4);
        assertEquals("文 x² Eng", paragraph.selectedText());
        assertEquals("文 **$x^2$** Eng", paragraph.selectedSource());
    }

    function testCodeBlockHighlightsAreCachedByHighlighterIdentity() {
        var calls = 0;
        final highlighter = (_:CodeBlock) -> {
            calls++;
            return ([] : Array<StyledRange>);
        };
        final block = new gpui.base.text.CodeBlock("fn main() {}", "rust", null);

        block.highlightedStyles(highlighter);
        block.highlightedStyles(highlighter);
        assertEquals(1, calls);

        final replacement = (_:CodeBlock) -> ([] : Array<StyledRange>);
        block.highlightedStyles(replacement);
        assertTrue(Reflect.compareMethods(block.highlightCache.value.highlighter, replacement));
    }

    function testANewHighlighterReplacesStylesInsteadOfReusingTheCache() {
        // Swapping the highlighter is how a theme change reaches a code block:
        // the parsed document is untouched, so the styles must come from the
        // new highlighter rather than from the styles cached for the old one.
        final light = (_:CodeBlock) -> [new StyledRange(new Range(0, 2), HighlightStyle.ofColor(rgb(0x0000ff).toHsla()))];
        final dark = (_:CodeBlock) -> [new StyledRange(new Range(0, 2), HighlightStyle.ofColor(rgb(0xffff00).toHsla()))];
        final block = gpui.base.text.CodeBlock.fromCode("42", "json");

        final lightStyles = block.highlightedStyles(light);
        final darkStyles = block.highlightedStyles(dark);

        assertTrue(lightStyles[0].style.color.equals(rgb(0x0000ff).toHsla()));
        assertTrue(darkStyles[0].style.color.equals(rgb(0xffff00).toHsla()));
        assertEquals("42", block.code(), "the document must survive the swap");
    }

    static function reconstruct(text:String, marks:Array<RangedMark>, start:Int, end:Int):String {
        return MarkdownSource.reconstructMarkdown(text, marks, new Range(start, end));
    }

    function testReconstructMarkdownWrapsMarkedRuns() {
        // "bold" fully covered by a bold mark.
        final marks = [mark(0, 4, new TextMark().withBold())];
        assertEquals("**bold**", reconstruct("bold", marks, 0, 4));
        // Partial selection inside the bold run still wraps the slice.
        assertEquals("**ol**", reconstruct("bold", marks, 1, 3));
    }

    function testReconstructMarkdownEmitsUnmarkedTextVerbatim() {
        // "a b c": plain, code, plain across three runs concatenated.
        final text = "a b c";
        final marks = [mark(2, 3, new TextMark().withCode())];
        assertEquals("a `b` c", reconstruct(text, marks, 0, 5));
        // Selecting only the plain tail.
        assertEquals(" c", reconstruct(text, marks, 3, 5));
    }

    function testReconstructMarkdownHandlesCodeItalicStrikeLink() {
        assertEquals("`x`", reconstruct("x", [mark(0, 1, new TextMark().withCode())], 0, 1));
        assertEquals("*x*", reconstruct("x", [mark(0, 1, new TextMark().withItalic())], 0, 1));
        assertEquals("~~x~~", reconstruct("x", [mark(0, 1, new TextMark().withStrikethrough())], 0, 1));
        final link = new TextMark().withLink(new LinkMark("https://example.com"));
        assertEquals("[x](https://example.com)", reconstruct("x", [mark(0, 1, link)], 0, 1));
    }

    function testReconstructMarkdownNestedBoldItalic() {
        // A single run marked both bold and italic (as produced by `**_x_**`).
        final m = new TextMark().withBold().withItalic();
        // Inner (italic) is applied first, then bold: `***x***`.
        assertEquals("***x***", reconstruct("x", [mark(0, 1, m)], 0, 1));
    }

    /**
     * Build a paragraph whose combined `state.text` is the concatenation of
     * its children (mirroring `Paragraph.render`), then set the paragraph
     * selection so `selectedSource` can be exercised without a real paint.
     */
    static function paragraphWithChildren(children:Array<InlineNode>):Paragraph {
        final combined = [for (c in children) c.text()].join('');
        final paragraph = paragraphOf(children);
        paragraph.state.setText(combined);
        return paragraph;
    }

    static function setParagraphSelection(paragraph:Paragraph, start:Int, end:Int) {
        paragraph.state.selection = new Selection(start, end);
    }

    function testParagraphSelectedSourceMapsPartialSelectionAcrossRuns() {
        // "This has **bold** text." rendered as ["This has ", "bold", " text."].
        final paragraph = paragraphWithChildren([
            new InlineNode("This has ").marks([mark(0, 9, new TextMark())]),
            new InlineNode("bold").marks([mark(0, 4, new TextMark().withBold())]),
            new InlineNode(" text.").marks([mark(0, 6, new TextMark())])
        ]);

        // Select the whole paragraph: "This has bold text." -> source with **.
        setParagraphSelection(paragraph, 0, 9 + 4 + 6);
        assertEquals("This has **bold** text.", paragraph.selectedSource());

        // Select only across the boundary "has **bold** te".
        setParagraphSelection(paragraph, 5, 16);
        assertEquals("has **bold** te", paragraph.selectedSource());

        // Select entirely inside the bold run -> still wrapped.
        setParagraphSelection(paragraph, 10, 12);
        assertEquals("**ol**", paragraph.selectedSource());
    }

    function testParagraphSelectedSourceMatchesTextWhenNoMarks() {
        final paragraph = paragraphWithChildren([new InlineNode("plain words").marks([mark(0, 11, new TextMark())])]);
        setParagraphSelection(paragraph, 0, 11);
        assertEquals("plain words", paragraph.selectedSource());
        assertEquals("plain words", paragraph.selectedText());
    }

    /**
     * Copy `blocks` the way a view in `SelectionFormat.SourceAcrossStyles`
     * does, with every block painted.
     */
    static function copyAcrossStyles(blocks:Array<BlockNode>):String {
        return new ParsedDocument('', blocks).selectedText(SourceAcrossStyles, null);
    }

    function testSourceAcrossStylesCopiesPlainTextWithinOneStyle() {
        // "This has **bold** text." rendered as ["This has ", "bold", " text."].
        function paragraph() {
            return paragraphWithChildren([
                new InlineNode("This has ").marks([mark(0, 9, new TextMark())]),
                new InlineNode("bold").marks([mark(0, 4, new TextMark().withBold())]),
                new InlineNode(" text.").marks([mark(0, 6, new TextMark())])
            ]);
        }
        function copy(start:Int, end:Int) {
            final p = paragraph();
            setParagraphSelection(p, start, end);
            return copyAcrossStyles([BlockNode.Paragraph(p)]);
        }

        // Inside the bold run, and up to both of its boundaries.
        assertEquals("ol\n", copy(10, 12));
        assertEquals("bold\n", copy(9, 13));
        // Inside the plain text before it, up to the boundary.
        assertEquals("This has \n", copy(0, 9));
        // Across the boundary, the selection takes in two styles.
        assertEquals("has **bold** te", copy(5, 16));
        assertEquals(" **b**", copy(8, 10));
    }

    function testSourceAcrossStylesDropsTheUrlOfALinkSelectedAlone() {
        final link = new TextMark().withLink(new LinkMark("https://example.com"));
        final paragraph = paragraphWithChildren([
            new InlineNode("see ").marks([mark(0, 4, new TextMark())]),
            new InlineNode("the docs").marks([mark(0, 8, link)])
        ]);

        setParagraphSelection(paragraph, 4, 12);
        assertEquals("the docs\n", copyAcrossStyles([BlockNode.Paragraph(paragraph.clone())]));

        setParagraphSelection(paragraph, 0, 12);
        assertEquals("see [the docs](https://example.com)", copyAcrossStyles([BlockNode.Paragraph(paragraph)]));
    }

    function testSourceAcrossStylesDropsTheMarkupOfASingleBlock() {
        final heading = BlockNode.Heading(2, selectedParagraph("Title"), null);
        assertEquals("Title\n", copyAcrossStyles([heading]));

        final code = gpui.base.text.CodeBlock.fromCode("let a = 1;\nlet b = 2;", "rust");
        code.setSelection(new Range(0, 10));
        assertEquals("let a = 1;\n", copyAcrossStyles([BlockNode.CodeBlock(code)]));

        function item(text:String) {
            return BlockNode.ListItem([BlockNode.Paragraph(selectedParagraph(text))], false, null, null);
        }
        final unselectedItem = BlockNode.ListItem([BlockNode.Paragraph(paragraphWithChildren([new InlineNode("two")]))], false, null, null);
        final list = BlockNode.List([item("one"), unselectedItem], false, null, null);
        assertEquals("one\n", copyAcrossStyles([list]));
    }

    function testSourceAcrossStylesKeepsTheSourceAcrossBlocks() {
        function item(text:String) {
            return BlockNode.ListItem([BlockNode.Paragraph(selectedParagraph(text))], false, null, null);
        }
        final list = BlockNode.List([item("one"), item("two")], false, null, null);
        assertEquals("- one\n- two", copyAcrossStyles([list]));

        assertEquals("start\n\nend", copyAcrossStyles([
            BlockNode.Paragraph(selectedParagraph("start")),
            BlockNode.Paragraph(selectedParagraph("end"))
        ]));
    }

    function testSourceAcrossStylesKeepsTheSourceOfAnInlineObject() {
        final formula = InlineNode.ofCustom(new MarkdownNode("math", null).text("x").markdown("$x$"));
        formula.customSelection.value = true;
        final paragraph = paragraphOf([formula]);
        assertEquals("$x$", copyAcrossStyles([BlockNode.Paragraph(paragraph)]));
    }

    static function selectedParagraph(text:String):Paragraph {
        final l = len(text);
        final paragraph = paragraphWithChildren([new InlineNode(text).marks([mark(0, l, new TextMark())])]);
        setParagraphSelection(paragraph, 0, l);
        return paragraph;
    }

    static function listItem(children:Array<BlockNode>, ?checked:Bool, spread:Bool = false):BlockNode {
        return BlockNode.ListItem(children, spread, checked, null);
    }

    function testHeadingSelectedSourcePrefixesHashes() {
        final heading = BlockNode.Heading(2, selectedParagraph("Title"), null);
        assertEquals("## Title\n", heading.selectedText(Source));
        // Rendered text keeps no marker.
        assertEquals("Title\n", heading.selectedText(Plain));
    }

    function testUnorderedListSelectedSourcePrefixesDash() {
        final list = BlockNode.List([
            listItem([BlockNode.Paragraph(selectedParagraph("one"))]),
            listItem([BlockNode.Paragraph(selectedParagraph("two"))])
        ], false, null, null);
        assertEquals("- one\n- two\n", list.selectedText(Source));
    }

    function testOrderedListSelectedSourcePreservesStart() {
        final list = BlockNode.List([
            listItem([BlockNode.Paragraph(selectedParagraph("three"))]),
            listItem([BlockNode.Paragraph(selectedParagraph("four"))])
        ], true, 3, null);
        assertEquals("3. three\n4. four", list.toMarkdown());
        assertEquals("3. three\n4. four\n", list.selectedText(Source));
    }

    function testOrderedListSelectedSourcePreservesNestedStartsAndContinuations() {
        final nested = BlockNode.List([
            listItem([BlockNode.Paragraph(selectedParagraph("nested"))]),
            listItem([BlockNode.Paragraph(selectedParagraph("again"))])
        ], true, 4, null);
        final nestedList = BlockNode.List([
            listItem([BlockNode.Paragraph(selectedParagraph("three")), nested]),
            listItem([BlockNode.Paragraph(selectedParagraph("four"))])
        ], true, 3, null);
        assertEquals("3. three\n   4. nested\n   5. again\n4. four\n", nestedList.selectedText(Source));

        final looseList = BlockNode.List([
            listItem([
                BlockNode.Paragraph(selectedParagraph("loose")),
                BlockNode.Paragraph(selectedParagraph("continuation"))
            ], null, true),
            listItem([BlockNode.Paragraph(selectedParagraph("four"))])
        ], true, 3, null);
        assertEquals("3. loose\n   continuation\n4. four\n", looseList.selectedText(Source));
    }

    function testNestedListSelectedSourceIndentsSublists() {
        // - one
        //   - nested
        // - two
        final nested = BlockNode.List([listItem([BlockNode.Paragraph(selectedParagraph("nested"))])], false, null, null);
        final list = BlockNode.List([
            listItem([BlockNode.Paragraph(selectedParagraph("one")), nested]),
            listItem([BlockNode.Paragraph(selectedParagraph("two"))])
        ], false, null, null);
        assertEquals("- one\n  - nested\n- two\n", list.selectedText(Source));
    }

    function testTaskListSelectedSourceRestoresCheckboxes() {
        final list = BlockNode.List([
            listItem([BlockNode.Paragraph(selectedParagraph("done"))], true),
            listItem([BlockNode.Paragraph(selectedParagraph("todo"))], false)
        ], false, null, null);
        assertEquals("- [x] done\n- [ ] todo\n", list.selectedText(Source));
    }

    function testBlockquoteSelectedSourcePrefixesGt() {
        final quote = BlockNode.Blockquote([BlockNode.Paragraph(selectedParagraph("quoted text"))], null);
        assertEquals("> quoted text\n", quote.selectedText(Source));
    }

    function testTableSelectedSourcePipesCellsWithAlignmentRow() {
        function cell(text:String) {
            return new TableCell(selectedParagraph(text));
        }
        final table = tableOf([[cell("Name"), cell("Age")], [cell("Alice"), cell("30")]], [Left, Right]);
        final block = BlockNode.Table(table);
        assertEquals("| Name | Age |\n| :-- | --: |\n| Alice | 30 |\n", block.selectedText(Source));
    }

    /**
     * A drag that starts in a table cell stays in it, so the copy is the
     * cell's text alone: no pipes, no delimiter row, no other cells or rows.
     */
    function testASelectionInOneTableCellCopiesOnlyThatCell() {
        final table = tableOf([
            [plainCell("Name"), plainCell("Age")],
            [new TableCell(selectedParagraph("Alice")), plainCell("30")]
        ], [Left, Right]);
        final block = BlockNode.Table(table);
        assertEquals("Alice", TextUtils.trim(block.selectedText(Plain)));
        assertEquals("Alice\n", block.selectedText(Source));
    }

    /**
     * A cell holding plain text, as `Table.toMarkdown` and `Table.tableData`
     * see it (neither needs a selection).
     */
    static function plainCell(text:String):TableCell {
        return new TableCell(gpui.base.text.Paragraph.ofText(text));
    }

    static function tableOf(rows:Array<Array<TableCell>>, columnAligns:Array<ColumnumnAlign>):Table {
        final table = new Table();
        table.children = [for (children in rows) new TableRow(children)];
        table.columnAligns_ = columnAligns;
        return table;
    }

    function testTableToMarkdownPipesCellsWithAlignmentRow() {
        final table = tableOf([
            [plainCell("Name"), plainCell("Age"), plainCell("Score")],
            [plainCell("Alice"), plainCell("30"), plainCell("9.5")]
        ], [Left, Center, Right]);

        assertEquals("| Name | Age | Score |\n| :-- | :-: | --: |\n| Alice | 30 | 9.5 |", table.toMarkdown());
        // The block arm delegates to it.
        assertEquals(table.toMarkdown(), BlockNode.Table(table.clone()).toMarkdown());
    }

    function testTableToMarkdownKeepsOuterPipesForASingleColumn() {
        final table = tableOf([[plainCell("Symbol")], [plainCell("TSLA.US")]], [Left]);

        assertEquals("| Symbol |\n| :-- |\n| TSLA.US |", table.toMarkdown());
    }

    function testTableToMarkdownEscapesPipesAndKeepsInlineMarks() {
        final bold = new TableCell(paragraphWithChildren([new InlineNode("bold").marks([mark(0, 4, new TextMark().withBold())])]));
        final table = tableOf([[plainCell("a | b"), plainCell("plain")], [plainCell("c"), bold]], [Left, Left]);

        assertEquals("| a \\| b | plain |\n| :-- | :-- |\n| c | **bold** |", table.toMarkdown());
    }

    function testTableDataSnapshotsPlainCellsAndMarkdown() {
        final table = tableOf([[plainCell("  Name  "), plainCell("Age")], [plainCell("Alice"), plainCell("30")]], [Left, Right]);
        table.span = new Span(4, 42);

        final data = table.tableData();
        assertEquals("Name,Age", data.headers.join(','));
        assertEquals(1, data.rows.length);
        assertEquals("Alice,30", data.rows[0].join(','));
        assertEquals(table.toMarkdown(), data.markdown);
        assertTrue(new Range(4, 42).equals(data.span));
    }

    function testClonedTableKeepsCachedTableData() {
        // Streaming appends deep-clone every block; the clone must reuse the
        // cached snapshot instead of rebuilding it.
        final table = tableOf([[plainCell("Name")], [plainCell("Alice")]], [Left]);
        final data = table.cachedTableData();

        final cloned = table.clone();
        assertTrue(data == cloned.cachedTableData());
    }

    function testTableDataHandlesTablesWithoutRows() {
        // Header only: still a valid table, with no data rows.
        final headerOnly = tableOf([[plainCell("Name"), plainCell("Age")]], [Left, Left]);
        final data = headerOnly.tableData();
        assertEquals("Name,Age", data.headers.join(','));
        assertEquals(0, data.rows.length);
        assertEquals("| Name | Age |\n| :-- | :-- |", data.markdown);

        // No rows at all (a table still streaming in): an empty snapshot.
        assertTrue(new Table().tableData().equals(new TableData()));
    }

    function testImageNodeSource() {
        function imageNode(url:String):ImageNode {
            return new ImageNode(url);
        }

        // Document-provided values stay URI-backed, including `file://` and
        // scheme-less strings, so the document never gets implicit
        // filesystem access.
        function assertUri(url:String) {
            switch imageNode(url).source() {
                case Resource(Uri(uri)):
                    assertEquals(url, uri);
                case _:
                    assertTrue(false, 'expected Uri for $url');
            }
        }
        assertUri("https://example.com/logo.png");
        assertUri("http://example.com/logo.png");
        assertUri("website/public/logo.svg");
        assertUri("./images/a.png");
        assertUri("../images/a.png");
        assertUri("/absolute/path/logo.svg");
        assertUri("file:///absolute/path/logo.svg");
        assertUri("C:\\images\\logo.png");
        assertUri("docs/a:b.png");
        assertUri("data:text/plain;base64,aGVsbG8=");

        // A `data:` image is decoded once and the same decoded image is
        // handed to every render.
        final node = imageNode("data:image/png;base64,iVBORw0KGgo=");
        final first = switch node.source() {
            case Image(image): image;
            case _: null;
        }
        assertNotNull(first, "expected an embedded image");
        assertEquals(ImageFormat.Png, first.format);
        assertEquals("89504e470d0a1a0a", first.bytes.toHex());
        final second = switch node.source() {
            case Image(image): image;
            case _: null;
        }
        assertTrue(first == second);
    }

    static function imageParagraph(alt:String, url:String):Paragraph {
        final image = new ImageNode(url);
        image.alt = alt;
        return paragraphOf([InlineNode.ofImage(image)]);
    }

    /** Every mark round-trips, including the two Markdown has no plain syntax for. */
    function testMarksRoundTripThroughReconstruction() {
        function wrap(m:TextMark) {
            return reconstruct("x", [mark(0, 1, m)], 0, 1);
        }

        assertEquals("**x**", wrap(new TextMark().withBold()));
        assertEquals("*x*", wrap(new TextMark().withItalic()));
        assertEquals("`x`", wrap(new TextMark().withCode()));
        assertEquals("~~x~~", wrap(new TextMark().withStrikethrough()));
        assertEquals("==x==", wrap(new TextMark().withHighlight(rgb(0xfef08a).toHsla())));
        // No Markdown syntax for underline, so it keeps the tag it came from.
        assertEquals("<u>x</u>", wrap(new TextMark().withUnderline()));

        // A link keeps its title, which Markdown carries after the URL.
        assertEquals("[x](https://example.com \"Tip\")", wrap(new TextMark().withLink(new LinkMark("https://example.com", null, "Tip"))));
    }

    /**
     * A block the selection covers whole comes straight from the source, so
     * it keeps what the author wrote instead of a normalized reconstruction.
     */
    function testDocumentSelectedSourceSlicesCoveredBlocksFromTheSource() {
        // `_italic_`, the `3.` start and the column padding all survive only
        // because the block is copied, not rebuilt.
        final source = "start\n\n3. _one_\n4. two\n\n---\n\nend";
        final list = "3. _one_\n4. two";
        final listStart = source.indexOf(list);
        final ruleStart = source.indexOf("---");

        final document = new ParsedDocument(source, [
            BlockNode.Paragraph(selectedParagraph("start")),
            BlockNode.List([], true, 3, new Span(listStart, listStart + len(list))),
            BlockNode.HorizontalRule(new Span(ruleStart, ruleStart + 3)),
            BlockNode.Paragraph(selectedParagraph("end"))
        ]);

        assertEquals("start\n\n3. _one_\n4. two\n\n---\n\nend", document.selectedText(Source, null));
    }

    function testDocumentSelectedSourceIncludesEnclosedImage() {
        // A standalone image between two selected paragraphs is covered by
        // the selection, so it is copied whole even though it holds no
        // selection of its own, straight out of the source the parser
        // located it in.
        final source = "before\n\n![alt](https://example.com/i.png)\n\nafter";
        final imageMarkdown = "![alt](https://example.com/i.png)";
        final start = source.indexOf(imageMarkdown);
        final image = imageParagraph("alt", "https://example.com/i.png");
        image.span = new Span(start, start + len(imageMarkdown));

        final document = new ParsedDocument(source, [
            BlockNode.Paragraph(selectedParagraph("before")),
            BlockNode.Paragraph(image),
            BlockNode.Paragraph(selectedParagraph("after"))
        ]);
        assertEquals("before\n\n![alt](https://example.com/i.png)\n\nafter", document.selectedText(Source, null));
    }

    function testDocumentSelectedSourceDropsUnenclosedImage() {
        // An image after the only selected block, with nothing selected after
        // it, is not enclosed and is dropped.
        final document = new ParsedDocument('', [
            BlockNode.Paragraph(selectedParagraph("before")),
            BlockNode.Paragraph(imageParagraph("alt", "u"))
        ]);
        assertEquals("before", document.selectedText(Source, null));
    }

    static function selectedCodeBlock(code:String, ?lang:String):BlockNode {
        final block = new gpui.base.text.CodeBlock(code, lang, null);
        block.state.selection = new Selection(0, len(block.state.text));
        return BlockNode.CodeBlock(block);
    }

    function testCodeBlockSelectedSourceWrapsInFenceWithLang() {
        final block = selectedCodeBlock("let x = 1;\n", "rust");
        final code = block.selectedText(Plain);
        final codeTrimmed = TextUtils.trimEndMatches(code, '\n');
        // The source wraps the (trailing-newline-trimmed) selected code in a
        // fenced block carrying the language; the block arm adds one trailing
        // newline.
        assertEquals('```rust\n$codeTrimmed\n```\n', block.selectedText(Source));
        assertTrue(StringTools.startsWith(block.selectedText(Source), "```rust\n"));
        assertTrue(StringTools.endsWith(TextUtils.trimEnd(block.selectedText(Source)), "\n```"));
    }

    function testCodeBlockSelectedSourceWithoutLang() {
        final block = selectedCodeBlock("plain\n", null);
        final codeTrimmed = TextUtils.trimEndMatches(block.selectedText(Plain), '\n');
        assertEquals('```\n$codeTrimmed\n```\n', block.selectedText(Source));
    }

    function testDocumentSelectedSourceJoinsBlocksWithBlankLine() {
        // A heading, a paragraph, and a two-item ordered list, each fully
        // selected. Top-level blocks must be separated by a blank line so the
        // copied Markdown re-renders with the same structure.
        final document = new ParsedDocument('', [
            BlockNode.Heading(1, selectedParagraph("Title"), null),
            BlockNode.Paragraph(selectedParagraph("A paragraph.")),
            selectedCodeBlock("let x = 1;\n", "rust"),
            BlockNode.List([
                listItem([BlockNode.Paragraph(selectedParagraph("one"))]),
                listItem([BlockNode.Paragraph(selectedParagraph("two"))])
            ], true, 1, null)
        ]);

        assertEquals("# Title\n\nA paragraph.\n\n```rust\nlet x = 1;\n```\n\n1. one\n2. two", document.selectedText(Source, null));
    }

    function testCodeBlockEqualityIncludesCodeContent() {
        final first = new gpui.base.text.CodeBlock("let value = 1;", "rust", null);
        final second = new gpui.base.text.CodeBlock("let value = 2;", "rust", null);

        assertFalse(first.equals(second));
    }

}
